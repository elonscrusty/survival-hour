"""Render the exact authored Roblox primitive geometry without Blender.

This is a geometry preview, not a Roblox Studio screenshot. Uses the same
Part.native() shapes, transforms and colours as the runtime data generator.
"""
import argparse
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import gen_models as G

PALETTES={
 'Fire':[0xDF7652,0xFFD18A,0x793C46,0xFFF0D3,0xFFE6A4],
 'Ice':[0x79B9D5,0xD9F0EA,0x3E668B,0xF3FAEE,0xB9F7FF],
 'Storm':[0x8F87C9,0xF6D67D,0x49436C,0xFFF0D9,0xFFF1A7],
 'Nature':[0x73BCA0,0xF9CD78,0x386878,0xFFF0D3,0xD7FFA4],
 'Shadow':[0x9B81BC,0xE3B5D9,0x493E6C,0xF2E8E9,0xD7BEFF]}
def mesh(shape):
 if shape=='B':
  v=np.array([(x,y,z) for x in (-.5,.5) for y in (-.5,.5) for z in (-.5,.5)])
  return v,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
 if shape=='W':
  return np.array([(-.5,-.5,-.5),(.5,-.5,-.5),(.5,-.5,.5),(-.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)]),[(0,1,2,3),(3,2,5,4),(0,4,5,1),(0,3,4),(1,5,2)]
 n=16
 if shape=='C':
  v=np.array([(x,.5*math.cos(i*math.tau/n),.5*math.sin(i*math.tau/n)) for x in (-.5,.5) for i in range(n)])
  return v,[tuple(range(n)),tuple(range(n,2*n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]
 v=np.array([(.5*math.sin(j*math.pi/8)*math.cos(i*math.tau/n),.5*math.cos(j*math.pi/8),.5*math.sin(j*math.pi/8)*math.sin(i*math.tau/n)) for j in range(9) for i in range(n)])
 return v,[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(8) for i in range(n)]
MESHES={shape:mesh(shape) for shape in 'BWCS'}
def unit(a):
 a=np.array(a,dtype=float);return a/np.linalg.norm(a)
def render(parts,eye,look,width=1280,height=720,fov=55):
 forward=unit(np.array(look)-eye);right=unit(np.cross(forward,[0,1,0]));up=np.cross(right,forward)
 axes=np.array([right,up,forward]);light=unit([-1,2,-1]);focal=height/(2*math.tan(math.radians(fov)/2))
 top=np.array([193,229,239]);bottom=np.array([239,245,230]);grad=np.linspace(0,1,height)[:,None,None]
 pixels=np.broadcast_to(top[None,None,:]*(1-grad)+bottom[None,None,:]*grad,(height,width,3)).copy()
 depth=np.full((height,width),np.inf)
 def project(v):
  c=(v-np.array(eye))@axes.T
  return np.column_stack((width/2+c[:,0]*focal/c[:,2],height/2-c[:,1]*focal/c[:,2],c[:,2]))
 def triangle(v,color):
  if np.min(v[:,2])<.05:return
  x0=max(0,int(np.min(v[:,0])));x1=min(width-1,int(np.max(v[:,0]))+1)
  y0=max(0,int(np.min(v[:,1])));y1=min(height-1,int(np.max(v[:,1]))+1)
  if x1<x0 or y1<y0:return
  a,b,c=v;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
  if abs(den)<1e-9:return
  xx,yy=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
  u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
  vv=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den
  w=1-u-vv
  inv=u/a[2]+vv/b[2]+w/c[2]
  z=np.divide(1,inv,out=np.full_like(inv,np.inf),where=inv>0)
  old=depth[y0:y1+1,x0:x1+1];mask=(u>=-1e-8)&(vv>=-1e-8)&(w>=-1e-8)&(z<old)
  old[mask]=z[mask];pixels[y0:y1+1,x0:x1+1][mask]=color
 for p in parts:
  if p.tr>=.8:continue
  shape,size,pos,R=p.native();verts,faces=MESHES[shape]
  world=(verts*np.array(size))@np.array(R).T+pos
  projected=project(world)
  if np.max(projected[:,0])<0 or np.min(projected[:,0])>width or np.max(projected[:,1])<0 or np.min(projected[:,1])>height:continue
  for face in faces:
   points=world[list(face)];normal=np.cross(points[1]-points[0],points[2]-points[0]);length=np.linalg.norm(normal)
   if length<1e-9:continue
   normal/=length
   if np.dot(normal,points.mean(axis=0)-pos)<0:normal=-normal
   if np.dot(normal,np.array(eye)-points.mean(axis=0))<0:continue
   shade=.7+.3*max(0,np.dot(normal,light)) if p.mat!='N' else 1.05
   color=np.clip(np.array(G.L.hexc(p.col))*shade,0,255)
   for j in range(1,len(face)-1):triangle(projected[[face[0],face[j],face[j+1]]],color)
 return Image.fromarray(pixels.astype('uint8'))
def creature(parts,element):
 palette=PALETTES[element];tags={'Body':0,'Head':0,'Accent':1,'Shade':2,'Face':3,'Glow':4}
 return [p.copy(col=palette[tags[p.tag]]) if p.tag in tags else p for p in parts]
def world_parts(data):
 w=data['world'];out=[p for a,ps in w['parts'].items() for p in ps if a=='Meadow']
 for name,x,y,z,yaw,scale,area in w['place']:
  if area=='Meadow':out+=G.L.T(data['props'][name]['parts'],(x,y,z),r=(0,yaw,0),s=scale)
 for it in w['interact']:
  if it['area']!='Meadow':continue
  spec=data['props'][it['prop']]['parts'];out+=G.L.T(spec,it['pos'],r=(0,it['yaw'],0))
  if it['kind']=='EggStand':
   egg=G.L.T(data['eggs'][it['attrs']['EggId']],G.egg_spot(spec),s=G.EGG_STAND_SCALE)
   out+=G.L.T(egg,it['pos'],r=(0,it['yaw'],0))
 return out

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--only',default='creatures,world');a=ap.parse_args()
 out=Path(__file__).resolve().parent.parent/'renders/revision';out.mkdir(parents=True,exist_ok=True)
 data=G.build_all()
 if 'creatures' in a.only:
  canvas=Image.new('RGB',(4*360,3*330),(247,249,243));draw=ImageDraw.Draw(canvas)
  font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
  for i,(name,parts) in enumerate(data['pets'].items()):
   element=list(PALETTES)[i%5];parts=creature(parts,element)
   image=render(parts,[10,8,-15],[0,2.7,0],360,290,42)
   canvas.paste(image,((i%4)*360,(i//4)*330));draw.text(((i%4)*360+18,(i//4)*330+298),name+' · '+element,fill=(30,50,70),font=font)
   image.save(out/(name+'.png'))
  canvas.save(out/'creatures.png');print(out/'creatures.png',flush=True)
 if 'world' in a.only:
  parts=world_parts(data)
  for name,eye,look,fov in [('hub',[60,95,225],[-35,0,0],55),('spawn',[-96,18,38],[-27,4,-2],65)]:
   render(parts,eye,look,1280,720,fov).save(out/(name+'.png'));print(out/(name+'.png'),flush=True)
if __name__=='__main__':main()
