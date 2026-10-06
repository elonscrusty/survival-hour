"""Render actual first-join HUD geometry from Hatchery.luau. Not a Studio capture.
Transparent SVGs are intended to overlay world previews. Gotham is approximated
by Arial on hosts where Roblox's font is unavailable.
"""
from pathlib import Path
import re
from html import escape
ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT/'src/client/Controllers/Hatchery.luau').read_text()
COLORS = {name:'#%02x%02x%02x'%tuple(map(int, rgb)) for name,*rgb in re.findall(r'local (ink|plum|cardColor|gold|mint) = Color3.fromRGB\((\d+), (\d+), (\d+)\)', SOURCE)}

def render(width, height):
    out=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<title>First-join HUD layout preview from implemented client geometry; not a Studio screenshot</title>']
    def rect(x,y,w,h,color,r=14):
        out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{COLORS[color]}"/>')
    def text(x,y,t,size=14,bold=False,anchor='start'):
        out.append(f'<text x="{x}" y="{y}" fill="{COLORS["ink"]}" font-family="Gotham,Arial,sans-serif" font-size="{size}" font-weight="{700 if bold else 400}" text-anchor="{anchor}">{escape(t)}</text>')
    rect(width-248,12,236,40,'plum'); text(width-236,38,'250 coins  ·  0 gems',16,True)
    ow=min(346,width-24)
    rect(12,60,ow,128,'plum',16); rect(12,72,4,104,'gold',2)
    text(26,89,'Hatch your first creature',18,True)
    text(26,110,'Buy a Meadow egg, incubate it, then',14)
    text(26,127,'hatch it.',14)
    rect(26,140,ow-28,38,'mint',10); text(12+ow/2,164,'Go to eggs',15,True,'middle')
    ry=198 if width<600 else 62
    rect(width-168,ry,156,44,'cardColor',10); text(width-90,ry+28,'Ride / fly starter',14,True,'middle')
    dw=min(500,width-24); dx=(width-dw)/2; dy=height-76
    rect(dx,dy,dw,62,'plum',18)
    bw=(dw-40)/5
    for index,title in enumerate(['Creatures','Eggs','Habitat','Battle','More']):
        x=dx+8+index*(bw+6)
        rect(x,dy+8,bw,46,'cardColor',10)
        text(x+bw/2,dy+37,title,12 if width<420 else 14,True,'middle')
    out.append('</svg>'); return '\n'.join(out)

if __name__=='__main__':
    dest=ROOT/'renders/ui'; dest.mkdir(parents=True,exist_ok=True)
    for name,w,h in [('desktop_hud',1280,720),('phone_hud',390,844)]:
        (dest/f'{name}.svg').write_text(render(w,h))
        try:
            import cairosvg
            cairosvg.svg2png(bytestring=render(w,h).encode(),write_to=str(dest/f'{name}.png'))
        except ImportError:
            pass
    print(dest)
