"""One continuous six-region landscape with hub, habitats and optional PvP."""
from lib import box, cyl
SPACING=240
COLORS=[0x77C953,0x8B62BE,0xECF6FF,0xE9CF94,0x55434B,0x9F8ADF]
def build(areas,props):
    parts={}; place=[]; interact=[]; zones={}; spawns={}; bounds={}
    def item(kind,prop,area,pos,attrs={}):
        interact.append(dict(kind=kind,prop=prop,area=area,pos=pos,yaw=90 if kind=='Gate' else 0,attrs=attrs))
    aliases={'Shadow':'Grove','Storm':'Coral','Sky':'Starfall'}
    for i,a in enumerate(areas):
        x=i*SPACING
        parts[a]=[box((240,16,300),(x,-8,0),COLORS[i],['E','E','S','A','B','E'][i]),box((240,.2,20),(x,.1,0),0xDAC5A0,'U')]
        # Solid cliff ridges seal north/south shores and each regional seam.
        # Only an 18-stud ground passage remains at each gate.
        for z in (-150,150):
            parts[a].append(box((240,100,8),(x,50,z),0x817480,'R',tag='BorderRidge'))
        if i:
            for side in (-1,1):
                parts[a].append(box((8,100,141),(x-118,50,side*79.5),0x817480,'R',tag='RegionRidge'))
            parts[a].append(box((8,84,18),(x-118,58,0),0x817480,'R',tag='GateLintel'))
        if i == 0 or i == len(areas)-1:
            edge=x-120 if i==0 else x+120
            parts[a].append(box((8,100,300),(edge,50,0),0x817480,'R',tag='EndRidge'))
        bounds[a]=((x-120,-1,-150),(x+120,80,150))
        spawns[a]=(x-85,4,0); zones[a]=[dict(center=(x+35,0,55),size=(110,0,80))]
        old=aliases.get(a,a)
        item('EggStand','EggStand_'+old,a,(x-30,0,-35),{'EggId':a+'Egg'})
        if i: item('Gate','Gate_'+old,a,(x-118,0,0),{'AreaId':a})
        decor={'Meadow':'VoxTree','Shadow':'GlowShroom','Frost':'VoxPine','Storm':'VoxPalm','Volcano':'FireCrystal','Sky':'FloatCrystal'}[a]
        for j in range(18):
            if a == 'Meadow' and j >= 6 and j < 12: continue
            place.append((decor,x-105+(j%6)*40,0,105 if j<6 else -110 if j<12 else 135,0,1.4,a))
    item('SpawnLocation','PawPlaza','Meadow',(-70,0,0))
    for kind,prop,pos in [('Hatchery','EggStand_Meadow',(-100,0,-20)),('FusionAltar','CraftMachine',(-70,0,42)),('CosmeticShop','IndexBook',(-105,0,40))]: item(kind,prop,'Meadow',pos)
    for i,eid in enumerate(['MythicEgg','FrostfireEgg']): item('EggStand','PrismStand','Meadow',(20+i*45,0,-25),{'EggId':eid})
    # Eight visible personal plots, each displaying eight unlockable creature pads.
    for i in range(8):
        x=-90+(i%4)*50; z=-120+(i//4)*55
        item('HabitatPlot','PawPlaza','Meadow',(x,0,z),{'PlotIndex':i+1})
        parts['Meadow'].append(box((42,.25,50),(x,.125,z),0xB2D582,'E',tag='HabitatGround'))
        for j in range(8): parts['Meadow'].append(cyl(9,.3,(x+(j%4-1.5)*10,.4,z+(j//4-.5)*18),0xDDEEC5,'U',tag='HabitatSlot'))
    center=(35,0,112);radius=30
    parts['Meadow'].append(cyl(60,.5,(35,.25,112),0xE5C993,'A',tag='BattleFloor'))
    for team in (-1,1):
        for slot in range(3): parts['Meadow'].append(cyl(7,.4,(35+team*18,.7,112+(slot-1)*15),0xFFB894 if team<0 else 0xA3DFFF,'N',tag='BattleSpot'))
    item('BattleArena','RingArch','Meadow',(35,0,142))
    return dict(arena=dict(center=center,radius=radius),spacing=SPACING,centers={a:i*SPACING for i,a in enumerate(areas)},radius={a:120 for a in areas},parts=parts,place=place,interact=interact,zones=zones,spawns=spawns,bounds=bounds,water=dict(level=-16,minx=-250,maxx=1500,minz=-300,maxz=300),spawn_location=(-70,4,0))
def count_parts(w,props,eggs):
    return sum(len(p) for p in w['parts'].values())+sum(len(props[p[0]]['parts']) for p in w['place'])+sum(len(props[i['prop']]['parts']) for i in w['interact'])
