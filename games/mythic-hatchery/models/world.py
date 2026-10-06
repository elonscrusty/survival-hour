"""Authored continuous toy landscape: readable hub and six stepped biomes."""
import math
from lib import box, cyl, wedge, shade, crystal
SPACING = 240
HUB = (-70, 0, 0)
ARENA = (48, 0, 100)
COLORS = [0x79CC57, 0xA88AD4, 0xECF6FF, 0xF1D59D, 0x725760, 0xAC9CEB]

def build(areas, props):
    parts, place, interact, zones, spawns, bounds = {}, [], [], {}, {}, {}
    def item(kind, prop, area, pos, attrs=None, yaw=0):
        interact.append(dict(kind=kind, prop=prop, area=area, pos=pos,
                             yaw=90 if kind == 'Gate' else yaw, attrs=attrs or {}))
    def deco(prop, x, z, area, scale=1, y=0, yaw=0):
        place.append((prop, x, y, z, yaw, scale, area))
    def path(rows, size, pos):
        rows.append(box(size, pos, 0xF3DCB5, 'U', tag='Path'))
    aliases = {'Shadow': 'Grove', 'Storm': 'Coral', 'Sky': 'Starfall'}
    for i, a in enumerate(areas):
        x, col = i * SPACING, COLORS[i]
        stone = [0xA89980, 0x9B85AF, 0x9EBCD3, 0xD8BA84, 0x645461, 0x9085B8][i]
        mat = ['E', 'E', 'S', 'A', 'B', 'E'][i]
        # A seamless playable top with a scalloped, layered coastline.
        rows = [box((240, 10, 270), (x, -5, 0), col, mat, tag='Ground')]
        for j in range(8):
            cx = x - 105 + j * 30
            for side in (-1, 1):
                reach = (154 if a == 'Meadow' else 138) + [0, 6, 12, 4, 8, 14, 5, 2][(j + i) % 8]
                rows.extend([
                    box((30, 8, reach*2), (cx, -9, 0), stone, 'R', tag='CliffLayer'),
                    box((30, 6, (reach+5)*2), (cx, -16, 0), shade(stone, .8), 'R', tag='CliffLayer'),
                ] if side == -1 else [])
                # Scattered raised turf and rock shoulders, never tall prison walls.
                h = 12 + ((j * 5 + i * 3) % 13)
                rows.append(box((31, h, 10), (cx, h/2, side*(reach-4)), stone, 'R', tag='BorderRidge'))
                rows.append(box((31, 1.5, 12), (cx, h+.75, side*(reach-4)), col, mat, tag='RidgeCrown'))
        path(rows, (240, .16, 18), (x, .08, 0))
        # Gate valleys: the centre lane is clear; low uneven cliffs frame the arch.
        if i:
            for side in (-1, 1):
                for j in range(5):
                    z = side*(23 + 27*j)
                    h = 14 + (j % 3)*5
                    rows.append(box((14, h, 28), (x-118, h/2, z), stone, 'R', tag='RegionRidge'))
                    rows.append(box((16, 1, 28), (x-118, h+.5, z), col, mat))
            item('Gate', 'Gate_'+aliases.get(a, a), a, (x-118, 0, 0), {'AreaId': a})
            for z in (-14, 14): deco('LanternPost', x-110, z, a, 1.3)
        bounds[a] = ((x-120, -1, -150), (x+120, 80, 150))
        spawns[a] = (x-85, 4, 0)
        zones[a] = [dict(center=(x+36, 0, 58), size=(108, 0, 70))]
        if i:
            item('EggStand', 'EggStand_'+aliases.get(a, a), a, (x-48, 0, -28), {'EggId': a+'Egg'})
            path(rows, (30, .16, 30), (x-48, .08, -24))
            item('Sign', 'IslandSign', a, (x-74, 0, 21), {'Text': ['','SHADOW GROVE','FROST PEAKS','STORM COAST','VOLCANO','SKY SANCTUARY'][i]}, yaw=90)
        decor = ['VoxTree', 'GlowShroom', 'VoxPine', 'VoxPalm', 'FireCrystal', 'FloatCrystal'][i]
        if i:
            for j, (dx, dz) in enumerate([(-92,-100),(-58,-118),(-10,-105),(30,-112),(91,-103),(-89,95),(-42,116),(8,119),(82,112)]):
                deco(decor, x+dx, dz, a, 1.4+(j%3)*.4, yaw=j*31)
                deco(['Daisies','GlowCluster','SnowRock','Coral','LavaRock','StarProp'][i],x+dx+10,dz+7,a,1.2)
            landmark = 'Landmark'+aliases.get(a,a)
            deco(landmark,x+42,-85,a,1.15)
            # Small contrasting paths and natural interest around the landmark.
            for j in range(5): deco('SteppingStone', x+15+j*5, -20-j*10, a, 1.8)
            if a in ('Frost', 'Storm'):
                rows.append(box((14, 22, 1), (x+94,-7,-141), 0x74DDF5, 'I' if a=='Frost' else 'N', tag='Waterfall', t=.2))
                rows.append(box((28,.2,17),(x+94,-15.6,-154),0x76DDED,'N',tag='WaterfallPool'))
        parts[a] = rows
    zones['Meadow'] = [dict(center=(-22,0,105),size=(48,0,50))]
    rows = parts['Meadow']
    # Hub reads from spawn along +X: egg counter ahead-left, hatchery ahead-right.
    rows.append(cyl(64,.24,(-65,.12,0),0xF6E8CA,'U',tag='HubPlaza'))
    item('SpawnLocation','SteppingStone','Meadow',HUB)
    # An eight-point elemental sigil replaces the old pet-era paw imprint.
    rows.append(cyl(23,.3,(-70,.28,0),0xEED59A,'P',tag='SpawnSigilRing'))
    rows.append(cyl(20,.35,(-70,.3,0),0x527A91,'P'))
    for yaw in (0,45):
        rows.append(box((11,.12,11),(-70,.54,0),0xFFE4A0,'P',r=(0,yaw,0),tag='SpawnSigil'))
        rows.append(box((8,.14,8),(-70,.63,0),0x99D9DD,'P',r=(0,yaw,0)))
    # A crystal fountain stands to the side, leaving the spawn and travel lane clear.
    rows.extend([cyl(18,.8,(-66,.4,21),0xE5C88C,'P',tag='CrystalFountain'),
                 cyl(15,.7,(-66,.9,21),0xF9EDC9,'P'),
                 cyl(12,.2,(-66,1.32,21),0x65DCEB,'N'),
                 cyl(5,2,(-66,2.1,21),0xB2D8DD,'P')])
    rows.extend(crystal((-66,3.1,21),3.8,8,0x86F1F5,'P',tag='MythicCrystal'))
    for dx,dz,col in [(-6,0,0xBEA2FF),(6,0,0xFFC8C9),(0,-6,0xA5E6A6),(0,6,0xFFE3A0)]:
        rows.extend(crystal((-66+dx,1.3,21+dz),1.5,3,col,'P',tag='ElementCrystal'))
    # Chunky striped bunting announces the first egg from the spawn plaza.
    for dx in (-15,15): rows.append(box((1,13,1),(-30+dx,6.5,-30),0xF6D17A,'W',tag='EggBuntingPost'))
    rows.append(box((31,.25,.25),(-30,12,-30),0xFFF1CC,'P'))
    for j in range(7): rows.append(box((3,2,.3),(-42+j*4,11,-30),[0xFFB1AE,0xFFF099,0xA9E3DA][j%3],'P',r=(0,0,8 if j%2 else -8),tag='EggBunting'))
    item('EggStand','EggStand_Meadow','Meadow',(-30,0,-23),{'EggId':'MeadowEgg'},yaw=90)
    item('Hatchery','IslandSign','Meadow',(-28,0,32),yaw=90)
    # Open pavilion keeps the interaction visible and reachable.
    for dx in (-12,12):
        for dz in (-11,11):
            rows.append(box((2,18,2),(-18+dx,9,38+dz),0xFFF2D4,'P',tag='HatcheryPillar'))
            rows.append(box((3,1,3),(-18+dx,1,38+dz),0xF8BA58,'P'))
    # Teal pitched roof, gold ridge and egg crest mark the incubator building.
    rows.append(box((33,1,31),(-18,18.8,38),0xEECF8C,'P',tag='HatcheryEaves'))
    rows.append(wedge((32,7,16),(-18,22.8,30),0x55A7B3,'P',tag='HatcheryRoof'))
    rows.append(wedge((32,7,16),(-18,22.8,46),0x6ABDC3,'P',r=(0,180,0),tag='HatcheryRoof'))
    rows.append(box((34,1.1,1.5),(-18,26.8,38),0xF3D187,'P',tag='HatcheryRoofRidge'))
    for x in (-34,-2):
        rows.append(wedge((.8,7,16),(x,22.8,30),0xEFCF87,'P',tag='HatcheryRoofTrim'))
        rows.append(wedge((.8,7,16),(x,22.8,46),0xEFCF87,'P',r=(0,180,0),tag='HatcheryRoofTrim'))
    rows.extend(crystal((-18,27.4,38),2.8,4,0xFFE6A1,'P',tag='HatcheryCrest'))
    rows.append(box((.5,6,9),(-31.5,14,38),0xDBF2DD,'P',tag='HatcheryBanner'))
    rows.append(box((.7,1,10),(-31.5,17.3,38),0xF0CC78,'P'))
    for dx in (-7,7):
        rows.append(cyl(7,1,(-18+dx,.5,42),0xFFDA7B,'P',tag='IncubatorBase'))
        rows.append(cyl(5.6,5,(-18+dx,3.5,42),0x9DE6F4,'G',tag='IncubatorGlass',t=.35))
        rows.append(cyl(6.4,.8,(-18+dx,6.4,42),0xFFF4DB,'P'))
    path(rows,(18,.18,42),(-32,.09,24))
    item('FusionAltar','CraftMachine','Meadow',(-83,0,37))
    item('CosmeticShop','IndexBook','Meadow',(-103,0,26),yaw=90)
    item('Sign','IslandSign','Meadow',(-48,0,-42),{'Text':'YOUR HABITATS'},yaw=180)
    item('Sign','IslandSign','Meadow',(88,0,-16),{'Text':'NEXT WORLD →'},yaw=90)
    path(rows,(14,.18,38),(-25,.09,66))
    item('Sign','IslandSign','Meadow',(22,0,68),{'Text':'TRAINER ARENA'},yaw=90)
    for i,eid in enumerate(['MythicEgg','FrostfireEgg']):
        item('EggStand','PrismStand','Meadow',(30+i*38,0,-27),{'EggId':eid},yaw=90)
    # Personal habitat gardens. Sign models carry prompts; slots live on this grass.
    path(rows,(208,.18,10),(-15,.09,-86))
    path(rows,(10,.18,82),(-15,.09,-45))
    for i in range(8):
        x,z = -90+(i%4)*50, -116+(i//4)*55
        item('HabitatPlot','IslandSign','Meadow',(x,0,z),{'PlotIndex':i+1},yaw=180)
        rows.append(box((44,.35,44),(x,.175,z),0xA9D976,'E',tag='HabitatGround'))
        # Low cream fence: open six-stud entrance on south edge.
        for dx in (-22,22):
            rows.append(box((.8,2,44),(x+dx,2,z),0xFFF0CE,'W',tag='HabitatFence'))
        rows.append(box((44,2,.8),(x,2,z-22),0xFFF0CE,'W',tag='HabitatFence'))
        for dx in (-13,13): rows.append(box((18,2,.8),(x+dx,2,z+22),0xFFF0CE,'W',tag='HabitatFence'))
        for dx in (-22,22):
            for dz in (-22,22): rows.append(box((1.6,4,1.6),(x+dx,2,z+dz),0xFFF6DE,'P',tag='HabitatFencePost'))
        for j in range(8):
            rows.append(cyl(8,.25,(x+(j%4-1.5)*10,.48,z+(j//4-.5)*18),0xE8F3CD,'U',tag='HabitatSlot'))
        deco('Daisies',x+17,z+17,'Meadow',1.2)
    # Arena has bright team spots and a proper rope boundary with an open entry.
    ax,_,az = ARENA
    rows.extend([cyl(64,.3,(ax,.15,az),0xCBAB7B,'A',tag='BattleRim'),cyl(60,.5,(ax,.25,az),0xF5D99F,'A',tag='BattleFloor')])
    for team in (-1,1):
        for slot in range(3): rows.append(cyl(8,.4,(ax+team*18,.7,az+(slot-1)*15),0xFFB79C if team<0 else 0xA3DFFF,'P',tag='BattleSpot'))
    for j in range(12):
        angle=j*math.tau/12
        if j in (7,8): continue
        px,pz=ax+31*math.cos(angle),az+31*math.sin(angle)
        rows.append(box((1.3,5,1.3),(px,2.5,pz),0xE77D68,'P',tag='ArenaPost'))
        rows.append(cyl(2,.8,(px,5.1,pz),0xFFE793,'N'))
    # Segmented ropes stop at the entry instead of blocking the route.
    for j in range(12):
        if j in (6,7,8): continue
        angle=(j+.5)*math.tau/12
        for y in (2.2,3.8):
            rows.append(box((16.2,.25,.25),(ax+30*math.cos(angle),y,az+30*math.sin(angle)),0xFFF3DA,'P',r=(0,-math.degrees(angle)-90,0),tag='ArenaRope'))
    item('BattleArena','RingArch','Meadow',(ax,0,az+29))
    path(rows,(26,.18,50),(ax,.09,49))
    for prop,x,z,s in [('Windmill',-93,105,1.8),('VoxTree',-103,69,1.7),('VoxTree',96,-81,2),('VoxTree',100,110,1.8),('TreeCluster',-75,135,1.2),('FlowerBed',-84,17,1.3),('FlowerBed',-52,-23,1.4),('Bench',-54,34,1.1),('Dock',-10,142,1.5)]: deco(prop,x,z,'Meadow',s)
    for x,z in [(-94,-16),(-48,17),(0,-16),(78,17),(102,56),(-40,-86),(-90,-86),(60,-86)]: deco('LanternPost',x,z,'Meadow',1.15)
    for x,z in [(-95,15),(-55,26),(-10,-26),(82,-47),(4,66),(90,84)]: deco('Daisies',x,z,'Meadow',1.5)
    return dict(arena=dict(center=ARENA,radius=30),spacing=SPACING,centers={a:i*SPACING for i,a in enumerate(areas)},radius={a:120 for a in areas},parts=parts,place=place,interact=interact,zones=zones,spawns=spawns,bounds=bounds,water=dict(level=-20,minx=-250,maxx=1500,minz=-300,maxz=300),spawn_location=(-70,4,0))

def count_parts(w,props,eggs):
    return sum(len(p) for p in w['parts'].values())+sum(len(props[p[0]]['parts']) for p in w['place'])+sum(len(props[i['prop']]['parts']) for i in w['interact'])
