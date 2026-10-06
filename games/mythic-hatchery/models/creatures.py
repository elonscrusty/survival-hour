"""Chunky collectible mythical toys. Front -Z; feet on ground; 5–7 stud adults.
Body/Accent/Shade/Face/Glow are independently recoloured by the runtime.
"""
from lib import box, wedge, cyl, T, tri
BODY=0x73BCA0
ACCENT=0xF9CD78
SHADE=0x386878
CREAM=0xFFF0D3
INK=0x242535

def block(size,pos,tag='Body',r=None,mat='P'):
    return box(size,pos,{'Body':BODY,'Accent':ACCENT,'Shade':SHADE,'Face':CREAM,'Glow':0xFFE5A0,'Head':BODY}[tag],mat,r=r,tag=tag)

def eyes(p,x,y,z,w,scale=1,bird=False):
    # Eyes sit on the actual head surface. A protruding muzzle has its own smile.
    for s in (-1,1):
        ex=x+s*w*.25
        p.append(cyl(.67*scale,.065,(ex,y+.25*scale,z),INK,r=(90,0,0),tag='Eye'))
        p.append(cyl(.22*scale,.035,(ex+.09*scale,y+.38*scale,z-.055),0xFFFFFF,r=(90,0,0),tag='Eye'))
        p.append(cyl(.1*scale,.035,(ex-.12*scale,y+.12*scale,z-.055),0xFFFFFF,r=(90,0,0),tag='Eye'))
        if not bird:
            p.append(cyl(.26*scale,.04,(x+s*w*.36,y-.15*scale,z-.02),0xF6A2A8,r=(90,0,0),tag='Eye'))

def head(p,pos=(0,4.25,-1.65),size=(3.05,2.3,2.5),kind='dragon'):
    x,y,z=pos; w,h,d=size; front=z-d/2-.035
    p.append(block(size,pos,'Head'))
    eyes(p,x,y,front,w,w/3,bird=kind=='bird')
    if kind=='bird':
        p.append(wedge((1.05,.65,1),(x,y-.43,front-.38),0xFFC75A,tag='Beak'))
        p.append(block((.85,.16,.68),(x,y-.7,front-.3),'Shade'))
    else:
        mw=1.8 if kind=='horse' else w*.65
        p.append(block((mw,.76,.66),(x,y-.65,front-.27),'Face'))
        if kind=='horse':
            for s in (-1,1): p.append(box((.12,.11,.035),(x+s*.46,y-.53,front-.62),INK,tag='Eye'))
        else:
            p.append(box((.32,.19,.06),(x,y-.43,front-.62),INK,tag='Eye'))
        if kind=='lion':
            p.append(cyl(.42,.055,(x,y-.78,front-.62),INK,r=(90,0,0),tag='Eye'))
            p.append(cyl(.2,.025,(x,y-.88,front-.665),0xF28B9C,r=(90,0,0),tag='Eye'))
        else:
            # Two gently raised mouth corners form a grin on the muzzle itself.
            for s in (-1,1):
                p.append(box((.25,.06,.045),(x+s*.105,y-.8,front-.62),INK,r=(0,0,s*18),tag='Eye'))
    return y+h/2

def legs(p,horse=False,lion=False,back_only=False):
    for x in (-1.03,1.03):
        for z in ((1.35,) if back_only else (-.7,1.75)):
            p.append(block((.75,1.42 if horse else 1.6 if back_only else 1.1,.86),(x,.91 if horse else 1.0 if back_only else .75,z)))
            p.append(block((.94,.44,1.04),(x,.22,z-.12),'Shade' if horse else 'Accent'))
            if lion: p.append(block((.64,.11,.14),(x,.34,z-.67),'Face'))

def feather_wings(p,y=3.1,fire=False):
    for s in (-1,1):
        p.append(block((1.85,.48,.75),(s*1.85,y+.45,.65),'Shade',r=(0,0,s*25)))
        # Layered upright quills read as a feather fan from the gameplay camera.
        for i in range(3):
            p.append(block((.85,1.75-i*.2,.43),(s*(2.15+i*.56),y+.72+i*.24,.85+i*.22),'Accent',r=(0,0,s*-28)))
        p.append(block((.48,1.35,.22),(s*3.4,y+1.38,1.2),'Glow' if fire else 'Face',r=(0,0,s*-28),mat='N' if fire else 'P'))

def bat_wings(p,y=3.15):
    for s in (-1,1):
        p.append(block((2.6,.3,.42),(s*2.3,y+.7,.65),'Shade',r=(0,0,s*32)))
        p.extend(T(tri((0,0,0),2.65,1.9,.3,ACCENT,tag='Accent'),(s*2.65,y-.1,.85),r=(0,0,s*-18)))
        p.append(block((.23,1.8,.36),(s*2.85,y+.6,.62),'Shade',r=(0,0,s*-18)))
        p.append(wedge((.5,.65,.48),(s*3.6,y+1.45,.7),ACCENT,tag='Accent'))

def tail(p,plume=False,tuft=False):
    for i in range(3):
        p.append(block((.95-i*.18,.7-i*.12,1.25),(0,2.45+i*.22,2.4+i*.8),'Body' if not plume else 'Accent',r=(i*-12,0,0)))
    if plume:
        for i in range(5): p.append(block((.55,.3,2.1),( (i-2)*.78,3.15+abs(i-2)*.2,3.75),'Glow' if i==2 else 'Accent',r=(-16,(i-2)*15,0),mat='N' if i==2 else 'P'))
    elif tuft: p.append(block((1.35,1.05,1.15),(0,3.1,4.7),'Shade',r=(0,0,15)))
    else: p.append(wedge((.9,.8,1.3),(0,3.15,4.45),ACCENT,tag='Accent'))

def horns(p,x=0,y=5.6,z=-1.1,w=1):
    for s in (-1,1):
        p.append(block((.46,.85,.52),(x+s*w,y,z),'Face',r=(-18,0,s*-14)))
        p.append(wedge((.32,.62,.42),(x+s*w*1.08,y+.62,z+.15),ACCENT,tag='Accent'))

def horse(p,species):
    p.append(block((2.45,1.8,3.75),(0,2.7,.65)))
    legs(p,horse=True)
    p.append(block((1.5,1.95,1.3),(0,3.5,-.9),r=(-15,0,0)))
    top=head(p,(0,4.4,-1.8),(2.65,2.05,2.25),'horse')
    for s in (-1,1): p.append(block((.48,.85,.62),(s*.86,top+.3,-1.28),r=(0,0,s*-12)))
    for i in range(4): p.append(block((.7,.72,.75),(0,4.6-i*.33,-.6+i*.43),'Glow' if species=='Solaris' else 'Accent',r=(-20,0,0),mat='N' if species=='Solaris' and i%2==0 else 'P'))
    p.append(block((.55,.85,.55),(0,top+.4,-2.25),'Face'))
    p.append(wedge((.36,.7,.4),(0,top+1.08,-2.25),ACCENT,tag='Glow'))
    for i in range(3): p.append(block((.8,.85,1.05),(0,2.7-i*.38,2.6+i*.4),'Accent',r=(25,0,0)))
    if species=='Solaris':
        for s in (-1,1):
            p.append(wedge((.55,1.5,1.0),(s*1.2,4.2,-.6),ACCENT,r=(-20,0,s*12),tag='Glow'))
        # Sun horse has a radiating flame fan rather than the Pegasus's swept tail.
        for i in range(3):
            p.append(wedge((.55,.85,1.3),((i-1)*.6,2.75,3.8),ACCENT,r=(-20,(i-1)*25,0),tag='Glow'))
    if species!='Unicorn': feather_wings(p,3.35,species=='Solaris')

def build(species):
    p=[]
    if species in ('Unicorn','Pegasus','Solaris'): horse(p,species)
    elif species=='Phoenix':
        p.append(block((2.6,2.5,3),(0,2.6,.55)))
        p.append(block((1.85,1.65,.2),(0,2.6,-1),'Face'))
        for s in (-1,1):
            p.append(block((.42,1.1,.45),(s*.65,.83,.1),'Shade'))
            p.append(block((.85,.3,1.25),(s*.65,.15,-.25),'Accent'))
        head(p,(0,4.35,-1),(2.45,2.5,2.15),'bird')
        feather_wings(p,3.1,True); tail(p,plume=True)
        for i in range(3): p.append(block((.48,1-i*.14,.65),((i-1)*.58,6.0,-.65),'Glow' if i==1 else 'Accent',r=(-15,0,(i-1)*-12),mat='N' if i==1 else 'P'))
    elif species in ('Hydra','Leviathan'):
        p.append(block((3.2,1.75,3.65),(0,1.6,.7)))
        p.append(block((2.7,.5,2.8),(0,.25,.5),'Shade'))
        tail(p)
        if species=='Hydra':
            for x,y,z in [(-1.8,4,-1.3),(0,4.7,-1.5),(1.8,4,-1.3)]:
                p.append(block((.95,2.6,1.05),(x,y-1.35,z+.4),r=(0,0,-x*10)))
                head(p,(x,y,z),(1.95,1.8,1.8),'dragon')
                p.append(wedge((.55,.8,.65),(x,y+1.2,z+.3),ACCENT,tag='Accent'))
        else:
            p.append(block((1.8,2.1,1.65),(0,3,-.9),r=(-18,0,0)))
            head(p,(0,4.25,-1.9),(3.3,2.4,2.7)); horns(p,y=5.9,z=-1.4)
            for s in (-1,1):
                for i in range(2): p.append(wedge((1.8,.35,1.7),(s*(1.9+i*.6),2.3,.3+i*.7),ACCENT,r=(0,s*20,s*20),tag='Accent'))
        for i in range(3): p.append(wedge((.48,.8,.7),(0,2.85,1+i*.8),ACCENT,tag='Accent'))
    else:
        lion=species in ('Griffin','Chimera','Wyvern')
        p.append(block((2.8,1.9,3.65),(0,2.35,.65)))
        p.append(block((1.65,1.35,.22),(0,2.35,-1.28),'Face'))
        legs(p,lion=lion,back_only=species=='Wyvern')
        if species=='Griffin':
            p.append(block((2.6,1.8,1.1),(0,3.05,-.95),'Face'))
            head(p,(0,4,-1.65),(3.1,2.25,2.4),'bird')
            for s in (-1,1): p.append(block((.55,.75,.65),(s*1.05,5.35,-1.05),'Face',r=(0,0,s*-15)))
            feather_wings(p); tail(p,tuft=True)
        elif species=='Chimera':
            p.append(block((3.4,2.9,1.25),(0,3.8,-1.05),'Shade'))
            head(p,(0,4,-1.85),(2.8,2.35,2.25),'lion')
            for s in (-1,1): p.append(block((.65,.65,.65),(s*1.05,5.3,-1.7),'Accent'))
            feather_wings(p)
            p.append(block((.72,1.9,.85),(0,3.05,2.7),r=(20,0,0)))
            # Tail face looks rearward, distinct from the lion's main face.
            tailhead=[]; head(tailhead,(0,4.1,-2.9),(1.45,1.3,1.5),'dragon')
            p.extend(T(tailhead,r=(0,180,0)))
        else:
            if species=='Wyvern': head(p,(0,4.3,-1.75),(2.7,2.15,2.9))
            else: head(p)
            horns(p)
            if species=='Dragon': bat_wings(p); tail(p)
            elif species=='Wyvern': feather_wings(p); tail(p)
            else:
                bat_wings(p,3.35); tail(p,plume=True)
                for i in range(3): p.append(block((.45,.75,.7),((i-1)*.65,5.65,-1.3),'Accent',r=(0,0,(i-1)*-15)))
            for i in range(3): p.append(wedge((.48,.65,.65),(0,3.55,.2+i*.8),ACCENT,tag='Accent'))
    assert len(p)<=80, (species,len(p))
    return p

def cosmetic(id):
    if 'Saddle' in id:
        return [box((2.8,.35,2.4),(0,.175,0),0x825136 if id=='LeatherSaddle' else 0x914FD0),box((2.8,.8,.35),(0,.65,.95),0xFFC955)]
    if 'Aura' in id:
        col={'FlameAura':0xFF8030,'FrostAura':0xAEEDFF,'StormAura':0xFBE855,'ShadowAura':0xB35EFF}.get(id,0xFFD56E)
        return [box((.3,1+i%3*.25,.3),((i%4-1.5)*1.5,1,(i//4-.5)*5),col,'N',tag='Glow') for i in range(8)]
    col=0xFFCF55 if id=='Crown' else 0x5C3896 if id=='WizardHat' else 0x222635 if id=='TopHat' else 0xFF72BD
    p=[box((2.8,.25,2.8),(0,.125,0),col)]
    if id=='Crown': p += [box((.45,1.1,.45),(x,.65,z),col,'M') for x,z in [(-1,-1),(1,-1),(-1,1),(1,1)]]
    else: p.append(wedge((1.8,2.4,1.8),(0,1.45,0),col) if id in ('WizardHat','PartyHat') else box((1.9,1.8,1.9),(0,1.15,0),col))
    return p
