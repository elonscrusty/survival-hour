"""Ride-sized voxel mythical creatures. Shared tags drive element palettes."""
from lib import box, wedge, cyl
from pets import face
BODY=0x64D25A
ACCENT=0xC8FF8C

def build(species):
    bird=species=='Phoenix'
    horse=species in ('Unicorn','Pegasus','Solaris')
    serpent=species in ('Hydra','Leviathan')
    p=[box((3.8,2.3,5.4 if serpent else 4.2),(0,2.6,0.6),BODY,tag='Body')]
    for x in (-1.4,1.4):
        for z in (-0.8,2):
            p.append(box((1,1.7,1.1),(x,0.85,z),BODY,tag='Body'))
            p.append(box((1.3,.45,1.5),(x,.225,z-.2),ACCENT,tag='Accent'))
    heads=[(-2.2,4.7,-2),(0,5,-2.2),(2.2,4.7,-2)] if species=='Hydra' else [(0,4.4,-2)]
    for x,y,z in heads:
        p.append(box((1.2,2.2,1.2),(x,y-1,z+.5),BODY,tag='Body'))
        p.append(box((3.2,2.5,2.7),(x,y,z),BODY,tag='Body'))
        p.extend(face((x,y,z-1.4),s=1.25,eye_dx=.8,eye=.85,muzzle_w=1.3))
        if species in ('Dragon','Wyvern','Emberwyrm','Leviathan','Hydra'):
            for sx in (-1,1): p.append(wedge((.6,1.2,.8),(x+sx,y+1.7,z+.5),ACCENT,tag='Accent'))
        if horse:
            p.append(wedge((.65,2,.7),(x,y+2,z-.7),ACCENT,'N',tag='Glow'))
            for i in range(4): p.append(box((.8,.9,.8),(0,4.5-i*.35,-.4+i*.5),ACCENT,tag='Accent'))
        if bird or species=='Emberwyrm':
            for i in range(3): p.append(wedge((.55,1.5,.8),(x+(i-1)*.65,y+1.65,z),ACCENT,tag='Accent'))
        if species in ('Griffin','Phoenix','Chimera'):
            p.append(wedge((1.1,.8,1.3),(x,y-.35,z-1.9),0xFFD45A,tag='Beak'))
    if species not in ('Hydra','Unicorn'):
        for sx in (-1,1):
            for i in range(3):
                p.append(wedge((2.6,.55,3-i*.6),(sx*(2.2+i*1.05),3.25+i*.35,.6+i*.55),ACCENT,tag='Accent'))
    for i in range(3 if not bird else 5):
        p.append(box((1.25 if not bird else .65,.65,1.7),(0 if not bird else (i-2)*.65,2.5+i*.2,3.1+i*.7),BODY if not bird else ACCENT,tag='Body' if not bird else 'Accent'))
    if species=='Solaris':
        for i in range(4): p.append(wedge((.65,1.4,.8),(0,4.4-i*.25,-.2+i*.55),ACCENT,'N',tag='Glow'))
    if species=='Wyvern':
        for sx in (-1,1):
            for i in range(3): p.append(box((.65,.4,1.8),(sx*(3+i),3.7,.6+i*.5),ACCENT,tag='Accent'))
    if species=='Griffin': p.append(box((1.6,1.2,1.4),(0,3.2,5.2),ACCENT,tag='Accent'))
    if species=='Chimera':
        p.append(box((1.5,1.4,1.6),(0,4,5.4),BODY,tag='Body'))
        p.extend(face((0,4,4.55),s=.6,eye_dx=.35,eye=.4))
    if serpent:
        for i in range(4): p.append(wedge((.65,1.2,1),(0,4,1+i),ACCENT,tag='Accent'))
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
