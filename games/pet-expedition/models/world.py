"""World layout: six round islands along +X joined by bridges, the Meadow
hub, gates, egg stands, decorations, zones, spawns and bounds.

Everything here is data; Models/World.luau builds it in Roblox and render.py
draws the same layout. Ground top is y = 0, the sea surface is y = -16.
Style: blocky islands with stepped stone cliffs (reference/islands.jpg).
"""
import math
import random
from lib import box, cyl, ball, T, shade

WHITE_FOAM = 0xF4FBFF

SPACING = 320
RADIUS = {"Meadow": 150}
DEFAULT_RADIUS = 125
WATER_LEVEL = -16
BRIDGE_W = 18
WALL_H = 40

GROUND = {
    #           top colour, mat, rim colour, cliff colour, cliff mat, path colour, path mat
    "Meadow": (0x6CC24A, "E", 0x5AAE3C, 0x9A7450, "g", 0xD9B07A, "g"),
    "Grove": (0x8A6AD8, "E", 0x7A5AD0, 0x5A4A5E, "T", 0xE08AD8, "g"),
    "Frost": (0xF2F7FF, "S", 0xDDE8F5, 0x8FA3B8, "T", 0xBFE0F5, "I"),
    "Coral": (0xF2DCA2, "A", 0xE8CC8A, 0xD9B98A, "V", 0xC9A27C, "K"),
    "Volcano": (0x4A3E3E, "B", 0x3A3034, 0x2A2226, "B", 0x6E5A50, "T"),
    "Starfall": (0x8E7CE0, "E", 0x7A68CC, 0x3B2E6E, "T", 0xE8D8FF, "Y"),
}

DECOR = {
    # prop, weight, (min scale, max scale), footprint radius
    "Meadow": [("VoxTree", 4, (0.9, 1.25), 6), ("VoxBush", 3, (0.8, 1.2), 3), ("Daisies", 5, (1.0, 1.4), 3),
               ("HayCrate", 1.5, (1.0, 1.1), 3), ("Rock", 1.5, (0.7, 1.2), 4), ("GrassTuft", 3, (1.0, 1.4), 1.5)],
    "Grove": [("GlowShroom", 3, (0.8, 1.2), 5), ("GlowShroomBlue", 2, (0.8, 1.1), 5), ("GlowCluster", 4, (1.0, 1.5), 3),
              ("PurpleCrystal", 2, (0.8, 1.2), 3), ("VoxLog", 1.5, (1.0, 1.2), 5), ("GroveTree", 2, (0.9, 1.2), 6),
              ("PurpleTuft", 3, (1.0, 1.4), 1.5)],
    "Frost": [("VoxPine", 6, (0.9, 1.4), 5), ("IceCrystal", 3, (0.7, 1.2), 4), ("SnowRock", 2, (0.8, 1.2), 4),
              ("Snowman", 1, (1.0, 1.0), 3)],
    "Coral": [("VoxPalm", 5, (0.9, 1.2), 5), ("Coral", 3, (1.0, 1.5), 3), ("CoralPurple", 2, (1.0, 1.4), 3), ("Shell", 2, (0.8, 1.2), 3),
              ("Starfish", 3, (1.0, 1.5), 2), ("BeachRock", 2, (0.7, 1.1), 4)],
    "Volcano": [("LavaRock", 4, (0.9, 1.3), 4), ("LavaPool", 2, (1.0, 1.3), 7), ("DeadTree", 2, (0.9, 1.3), 3),
                ("FireCrystal", 3, (0.8, 1.3), 3)],
    "Starfall": [("FloatCrystal", 3, (0.9, 1.3), 4), ("FloatCrystalCyan", 2, (0.9, 1.3), 4), ("Planet", 2, (0.9, 1.2), 5),
                 ("PlanetBlue", 1, (0.9, 1.1), 5), ("MoonRock", 2, (0.8, 1.2), 4), ("StarProp", 3, (0.9, 1.2), 3)],
}
DECOR_COUNT = {"Meadow": 75, "Grove": 70, "Frost": 70, "Coral": 70, "Volcano": 60, "Starfall": 60}
DECOR_SCALE = 1.7  # decorations read better a bit oversized next to 5-stud avatars
LAMP = {"Meadow": "LanternPost", "Grove": "LanternPost", "Frost": "LanternPost", "Coral": "LanternPost", "Volcano": "StoneLantern",
        "Starfall": "StoneLantern"}
LANDMARK = {
    # prop, offset from island centre (x, z), footprint radius; all north of the breakable zones
    # prop, offset, footprint radius, yaw, scale
    "Grove": ("LandmarkGrove", (0, -100), 28, 0, 1.5),
    "Frost": ("LandmarkFrost", (0, -102), 26, 0, 1.6),
    "Coral": ("LandmarkCoral", (0, -100), 26, 0, 1.2),
    "Volcano": ("LandmarkVolcano", (0, -106), 32, 90, 1.4),
    "Starfall": ("LandmarkStarfall", (0, -100), 22, 0, 1.6),
}
CLIFF = {
    #           grass lip, stone, dark stone, stone material
    "Meadow": (0x5DBB46, 0xA9A6A0, 0x8A8680, "R"),
    "Grove": (0x7A5AD0, 0x6A5A8A, 0x54486E, "T"),
    "Frost": (0xFFFFFF, 0xB8C6D6, 0x8FA3B8, "T"),
    "Coral": (0xF2DCA2, 0xB8ABA0, 0x958A80, "V"),
    "Volcano": (0x4A3E3E, 0x3A3034, 0x2A2226, "B"),
    "Starfall": (0xA08CF0, 0x5B4B9E, 0x3B2E6E, "T"),
}
WATERFALLS = {"Meadow": (60, 120)}
HUB = (-88.0, 0.0, 0.0)
ARENA = (-60.0, 0.0, -86.0)  # Pet Ring: walk in and your equipped pets fight everyone else inside
ARENA_R = 26.0


def yaw_towards(pos, target):
    """Yaw (degrees) that turns a prop's front (-Z) towards target."""
    dx, dz = target[0] - pos[0], target[2] - pos[2]
    return math.degrees(math.atan2(-dx, -dz))


def radius(a):
    return RADIUS.get(a, DEFAULT_RADIUS)


def build(areas, props):
    rnd = random.Random(20261005)
    centers = {a: i * SPACING for i, a in enumerate(areas)}
    parts = {a: [] for a in areas}
    parts["Bridges"] = []
    place = []
    interact = []
    zones, spawns, bounds = {}, {}, {}

    for i, a in enumerate(areas):
        x, R = centers[a], radius(a)
        top, top_m, rim, cliff, cliff_m, path, path_m = GROUND[a]
        P = parts[a]
        P.append(cyl(2 * R, 4, (x, -2, 0), top, top_m, tag="Ground"))
        P.append(cyl(2 * R - 6, 44, (x, -26, 0), CLIFF[a][2], CLIFF[a][3]))
        island_edge(P, rnd, a, x, R, east=i < len(areas) - 1, west=i > 0)
        # main path from bridge to bridge
        P.append(box((2 * R - 8, 0.3, 14), (x, 0.12, 0), path, path_m))
        # invisible boundary walls: arcs of chords that stop exactly at the bridge corridors
        half = BRIDGE_W / 2 + 1.2
        th0 = math.degrees(math.asin(half / (R - 1)))
        east, west = i < len(areas) - 1, i > 0
        arcs = []
        if east and west:
            arcs = [(th0, 180 - th0), (180 + th0, 360 - th0)]
        elif east:
            arcs = [(th0, 360 - th0)]
        else:
            arcs = [(180 + th0 - 360, 180 - th0)]
        for a0, a1 in arcs:
            m = max(2, int(math.radians(a1 - a0) * (R - 1) / 20) + 1)
            for k in range(m):
                t0 = math.radians(a0 + (a1 - a0) * k / m)
                t1 = math.radians(a0 + (a1 - a0) * (k + 1) / m)
                p0 = (x + math.cos(t0) * (R - 1), math.sin(t0) * (R - 1))
                p1 = (x + math.cos(t1) * (R - 1), math.sin(t1) * (R - 1))
                L = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) + 1.5
                ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
                P.append(box((L, WALL_H, 2), ((p0[0] + p1[0]) / 2, WALL_H / 2, (p0[1] + p1[1]) / 2), 0xFFFFFF, "P",
                             r=(0, -ang, 0), tag="Wall", t=1.0))
        # corridor walls joining the ring to the bridge rails
        for side, on in ((1, east), (-1, west)):
            if not on:
                continue
            for sz in (-1, 1):
                P.append(box((16, WALL_H, 1), (x + side * (R - 9), WALL_H / 2, sz * half), 0xFFFFFF, "P", tag="Wall", t=1.0))

        # zones (flat, clear rectangles for breakables)
        if a == "Meadow":
            zones[a] = [{"center": (x + 45, 0, -46), "size": (120, 0, 50)}, {"center": (x + 45, 0, 46), "size": (120, 0, 50)}]
        else:
            zones[a] = [{"center": (x + 5, 0, -45), "size": (150, 0, 50)}, {"center": (x + 5, 0, 45), "size": (150, 0, 50)}]
        bounds[a] = ((x - R - 2, -40, -R - 2), (x + R + 2, 160, R + 2))

        blocked = []  # (x, z, r) circles that decorations must avoid
        if a == "Meadow":
            spawns[a] = (HUB[0], 3, HUB[2])
            P.append(cyl(58, 0.3, (HUB[0], 0.14, HUB[2]), 0xCFCAC0, "U"))
            for ang in (0, 90, 180, 270, 35, -35, 145, -145):
                ar = math.radians(ang)
                L_ = 16
                P.append(box((L_, 0.28, 7), (HUB[0] + math.cos(ar) * (29 + L_ / 2 - 3), 0.13, HUB[2] + math.sin(ar) * (29 + L_ / 2 - 3)), 0xC2BDB2, "U",
                             r=(0, -ang, 0)))
            hub_items = [
                ("SpawnLocation", "PawPlaza", (HUB[0], 0, HUB[2]), 0, {}),
                ("EggStand", "EggStand_Meadow", (HUB[0] + 30, 0, -17), None, {"EggId": "MeadowEgg"}),
                ("EggStand", "PrismStand", (HUB[0] + 30, 0, 17), None, {"EggId": "PrismEgg"}),
                ("ExpeditionBoard", "ExpeditionBoard", (HUB[0] - 2, 0, -33), None, {}),
                ("CraftMachine", "CraftMachine", (HUB[0] - 2, 0, 33), None, {}),
                ("RebirthStatue", "RebirthStatue", (HUB[0] - 30, 0, -19), None, {}),
                ("IndexBook", "IndexBook", (HUB[0] - 30, 0, 19), None, {}),
                ("Sign", "IslandSign", (HUB[0] + 46, 0, -14), None, {"Text": "Sunny Meadow"}),
            ]
            for kind, prop, pos, yaw, attrs in hub_items:
                if yaw is None:
                    yaw = yaw_towards(pos, HUB)
                interact.append({"kind": kind, "prop": prop, "area": a, "pos": pos, "yaw": yaw, "attrs": attrs})
            blocked.append((HUB[0], HUB[2], 50))
            place.append(("Windmill", -10, 0, -118, 20, 1.0, a))
            blocked.append((-10, -118, 12))
            build_arena(P, interact, place, a)
            hub_dressing(place, a)
            blocked.append((ARENA[0], ARENA[2], ARENA_R + 10))
            blocked.append(((HUB[0] + ARENA[0]) / 2, (HUB[2] + ARENA[2]) / 2, 9))  # the path to the ring
            for bx, bz in ((HUB[0] + 12, 46), (HUB[0] - 16, 46)):
                place.append(("Bench", bx, 0, bz, yaw_towards((bx, 0, bz), HUB), 1.0, a))
            blocked.append((HUB[0], HUB[2], 58))
        else:
            spawns[a] = (x - R + 18, 3, 0)
            stand = (x - R + 38, 0, 18)
            interact.append({"kind": "EggStand", "prop": f"EggStand_{a}", "area": a, "pos": stand, "yaw": 0.0,
                             "attrs": {"EggId": EGG_FOR[a]}})
            sign = (x - R + 30, 0, -17)
            interact.append({"kind": "Sign", "prop": "IslandSign", "area": a, "pos": sign,
                             "yaw": yaw_towards(sign, (x - R - 40, 0, 0)), "attrs": {"Text": AREA_NAME[a]}})
            blocked += [(stand[0], stand[2], 12), (sign[0], sign[2], 9)]
            # gate on the bridge just before this island
            gpos = (x - R - 12, 0, 0)
            interact.append({"kind": "Gate", "prop": f"Gate_{a}", "area": a, "pos": gpos, "yaw": 90.0, "attrs": {"AreaId": a}})
        if a in LANDMARK:
            name, (ox, oz), lr, lyaw, ls = LANDMARK[a]
            place.append((name, x + ox, 0, oz, lyaw, ls, a))
            blocked.append((x + ox, oz, lr))
        for ang in WATERFALLS.get(a, (60, 240)):
            ar = math.radians(ang)
            blocked.append((x + math.cos(ar) * (R - 8), math.sin(ar) * (R - 8), 9))

        # lamps along the path
        for k in range(-3, 4):
            lx = x + k * 34
            if abs(lx - x) > R - 20 or (a == "Meadow" and lx < HUB[0] + 46):
                continue
            for sz in (-1, 1):
                place.append((LAMP[a], lx + (8 if sz > 0 else 0), 0, sz * 10.5, 0, 1.0, a))

        # scattered decorations
        opts = DECOR[a]
        total_w = sum(o[1] for o in opts)
        placed = []
        tries = 0
        target = DECOR_COUNT[a]
        while len(placed) < target and tries < 6000:
            tries += 1
            pick = rnd.random() * total_w
            for o in opts:
                pick -= o[1]
                if pick <= 0:
                    break
            name, _, (s0, s1), fr = o
            s = rnd.uniform(s0, s1) * DECOR_SCALE
            r = fr * s
            # bias towards the outer ring of the island
            ang = rnd.random() * 2 * math.pi
            dist = (R - 10 - r) * math.sqrt(rnd.uniform(0.15, 1.0))
            px, pz = x + math.cos(ang) * dist, math.sin(ang) * dist
            if abs(pz) < 9 + r:
                continue
            if any(abs(px - z["center"][0]) < z["size"][0] / 2 + 5 + r and abs(pz - z["center"][2]) < z["size"][2] / 2 + 5 + r
                   for z in zones[a]):
                continue
            if any(math.hypot(px - bx, pz - bz) < br + r for bx, bz, br in blocked):
                continue
            if any(math.hypot(px - qx, pz - qz) < qr + r + 1.5 for qx, qz, qr in placed):
                continue
            if abs(px - x) > R - 30 and abs(pz) < 24:
                continue  # keep bridge mouths open
            placed.append((px, pz, r))
            place.append((name, round(px, 2), 0, round(pz, 2), round(rnd.uniform(0, 360), 1), round(s, 2), a))

    # bridges between consecutive islands
    B = parts["Bridges"]
    for i in range(1, len(areas)):
        a0, a1 = areas[i - 1], areas[i]
        x0 = centers[a0] + radius(a0) - 8
        x1 = centers[a1] - radius(a1) + 8
        L, cx = x1 - x0, (x0 + x1) / 2
        deck, beam, rope = 0xB0804A, 0x7E5230, 0xE8D8B0
        B.append(box((L, 1.2, BRIDGE_W), (cx, -0.6, 0), deck, "K"))
        # plank seams so the deck reads as boards
        for k in range(int(L // 4)):
            B.append(box((0.25, 1.22, BRIDGE_W - 1), (x0 + 2 + k * 4, -0.6, 0), shade(deck, 0.8), "K"))
        B.append(box((26, 1.2, BRIDGE_W + 10), (centers[a1] - radius(a1) - 12, -0.62, 0), deck, "K"))
        for sz in (-1, 1):
            zz = sz * (BRIDGE_W / 2 + 0.4)
            B.append(box((L, 1.0, 1.0), (cx, -0.5, zz), beam, "W"))
            B.append(box((L, WALL_H, 1), (cx, WALL_H / 2, sz * (BRIDGE_W / 2 + 1.2)), 0xFFFFFF, "P", tag="Wall", t=1.0))
            # sagging rope rail between stone pillars, short wooden posts
            n = 6
            for k in range(n):
                t0, t1 = k / n, (k + 1) / n
                y0, y1 = 4.2 - 1.6 * math.sin(math.pi * t0), 4.2 - 1.6 * math.sin(math.pi * t1)
                xa, xb = x0 + L * t0, x0 + L * t1
                ang = math.degrees(math.atan2(y1 - y0, xb - xa))
                B.append(box((math.hypot(xb - xa, y1 - y0) + 0.2, 0.3, 0.3), ((xa + xb) / 2, (y0 + y1) / 2, zz), rope, "X", r=(0, 0, ang)))
                if k:
                    hp = 3.6 - 1.6 * math.sin(math.pi * t0)
                    B.append(box((0.6, hp, 0.6), (xa, hp / 2, zz), beam, "W"))
            for px in (x0 + 1.5, x1 - 1.5):
                B.append(box((2.6, 6.5, 2.6), (px, 3.25, sz * (BRIDGE_W / 2 + 1.5)), 0xA9A6A0, "U"))
                B.append(box((3.0, 0.6, 3.0), (px, 6.8, sz * (BRIDGE_W / 2 + 1.5)), 0x8A8680, "U"))
                B.append(box((1.3, 1.3, 1.3), (px, 7.75, sz * (BRIDGE_W / 2 + 1.5)), 0xFFE27A, "N", tag="Glow"))
        for k in range(1, max(2, int(L // 24)) + 1):
            px = x0 + L * k / (max(2, int(L // 24)) + 1)
            for sz in (-1, 1):
                B.append(box((2.4, 20, 2.4), (px, -11, sz * (BRIDGE_W / 2 - 1)), beam, "W"))

    last = areas[-1]
    water = {"level": WATER_LEVEL, "minx": -radius(areas[0]) - 260, "maxx": centers[last] + radius(last) + 260,
             "minz": -480, "maxz": 480}
    spawn_location = (HUB[0], 0, HUB[2])
    arena = {"center": ARENA, "radius": ARENA_R}
    return {"arena": arena, "spacing": SPACING, "centers": centers, "radius": {a: radius(a) for a in areas}, "parts": parts, "place": place,
            "interact": interact, "zones": zones, "spawns": spawns, "bounds": bounds, "water": water,
            "spawn_location": spawn_location}


def island_edge(P, rnd, a, x, R, east, west):
    """Stepped blocky cliffs, a grass lip, waterfalls, a carved stair and rocks in the water."""
    lip, stone, dark, mat = CLIFF[a]
    corridor = BRIDGE_W / 2 + 3

    def in_corridor(ang, rad):
        cz = math.sin(ang) * rad
        cxr = math.cos(ang)
        return abs(cz) < corridor and ((cxr > 0 and east) or (cxr < 0 and west))

    lip_mat = "E" if a in ("Meadow", "Grove", "Starfall") else ("S" if a == "Frost" else mat)
    n = int(2 * math.pi * R / 15)
    for k in range(n):
        ang = 2 * math.pi * (k + 0.5) / n
        chord = 2 * math.pi * R / n * 1.12
        yaw = -math.degrees(ang) + 90
        # upper tier: stone just under the grass, slightly uneven tops
        top = -rnd.uniform(0.6, 3.0)
        r1 = R - 2
        P.append(box((chord, 40 + top, 9), (x + math.cos(ang) * r1, (top - 40) / 2, math.sin(ang) * r1),
                     stone if k % 3 else shade(stone, 1.08), mat, r=(0, yaw, 0)))
        # lower tier: a ledge stepping out towards the water
        top2 = -rnd.uniform(6, 11)
        r2 = R + 5 + rnd.uniform(-1.5, 1.5)
        P.append(box((chord * 1.05, 40 + top2, 7), (x + math.cos(ang) * r2, (top2 - 40) / 2, math.sin(ang) * r2), dark, mat, r=(0, yaw, 0)))
        # grass lip blocks on the rim
        if not in_corridor(ang, R) and k % 2 == 0:
            h = rnd.uniform(0.5, 1.4)
            P.append(box((chord * 2.05, h + 2, 4), (x + math.cos(ang) * (R - 0.5), h / 2 - 1, math.sin(ang) * (R - 0.5)), lip, lip_mat,
                         r=(0, yaw, 0)))
    # waterfalls pouring off the rim into the sea
    water_c = 0xBFEAFF if a == "Frost" else 0x7FD8FF
    for ang_d in WATERFALLS.get(a, (60, 240)):
        ang = math.radians(ang_d)
        yaw = -ang_d + 90
        ex, ez = x + math.cos(ang) * (R + 0.5), math.sin(ang) * (R + 0.5)
        P.append(box((7, 0.3, 14), (x + math.cos(ang) * (R - 7), 0.16, math.sin(ang) * (R - 7)), water_c, "G", r=(0, yaw + 90, 0), t=0.2))
        P.append(box((7, 1.0, 11), (x + math.cos(ang) * (R + 4.5), 0.0, math.sin(ang) * (R + 4.5)), water_c, "G", r=(0, yaw + 90, 0), t=0.2))
        P.append(box((9, -WATER_LEVEL + 1.0, 1.6), (ex + math.cos(ang) * 9.5, (WATER_LEVEL + 1.0) / 2, ez + math.sin(ang) * 9.5), water_c,
                     "G", r=(0, yaw, 0), t=0.15))
        P.append(box((13, 1.6, 7), (ex + math.cos(ang) * 11.5, WATER_LEVEL + 0.4, ez + math.sin(ang) * 11.5), WHITE_FOAM, "P",
                     r=(0, yaw, 0), t=0.2))
    # stair carved down the cliff
    ang = math.radians(150)
    for k in range(5):
        rr = R + 3 + k * 2.2
        P.append(box((6, 1.2, 2.4), (x + math.cos(ang) * rr, -2.0 - k * 2.0, math.sin(ang) * rr), shade(stone, 1.12), mat,
                     r=(0, -150 + 90, 0)))
    # rocks in the water
    for k in range(9):
        ang = 2 * math.pi * (k + rnd.random() * 0.6) / 9
        if in_corridor(ang, R + 20) or abs(math.sin(ang)) < 0.2:
            continue
        rr = R + rnd.uniform(16, 30)
        sz = rnd.uniform(4, 9)
        P.append(box((sz, sz * 1.1, sz * 0.9), (x + math.cos(ang) * rr, WATER_LEVEL + sz * 0.25, math.sin(ang) * rr), dark, mat,
                     r=(0, rnd.uniform(0, 90), rnd.uniform(-8, 8))))


def hub_dressing(place, area):
    """Lantern posts, fences, hay crates and a dock around the Meadow hub (reference/hub.jpg)."""
    hx, _, hz = HUB
    for ang in (-170, -120, -45, 45, 120, 170):
        ar = math.radians(ang)
        place.append(("LanternPost", round(hx + math.cos(ar) * 44, 2), 0, round(hz + math.sin(ar) * 44, 2), 0, 1.0, area))
    for ang in (-160, -140, 140, 160, 100, -100, 25, -25):
        ar = math.radians(ang)
        px, pz = hx + math.cos(ar) * 54, hz + math.sin(ar) * 54
        place.append(("Fence", round(px, 2), 0, round(pz, 2), round(-ang + 90, 1), 1.0, area))
    for px, pz in ((hx - 48, -30), (hx - 50, 26), (hx + 40, 44), (hx + 52, -40)):
        place.append(("HayCrate", px, 0, pz, 15, 1.0, area))
    place.append(("Dock", -150 - 10, WATER_LEVEL + 2.5, 40, 90, 1.0, area))


def build_arena(P, interact, place, area):
    """The Pet Ring: a raised sand floor with a glowing edge, corner posts and ropes,
    an opening facing the hub, and a sign. Walking inside starts fights (RingService)."""
    cx, _, cz = ARENA
    R = ARENA_R
    P.append(cyl(2 * R + 6, 0.5, (cx, 0.25, cz), 0x8A5A3C, "K"))
    P.append(cyl(2 * R, 0.8, (cx, 0.4, cz), 0xE9C98B, "A"))
    for k, (rr, ang) in enumerate(((0, 0), (9, 20), (9, 100), (9, 190), (9, 280), (17, 60), (17, 150), (17, 240), (17, 330), (15, 10))):
        ar = math.radians(ang)
        P.append(cyl(3.6 if k else 5, 0.84, (cx + math.cos(ar) * rr, 0.42, cz + math.sin(ar) * rr), 0xD2AE78, "A"))
    # gap in the ropes facing the hub
    gx, gz = HUB[0] - cx, HUB[2] - cz
    gap = math.atan2(gz, gx)
    n = 32
    for k in range(n):
        t0, t1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        p0 = (cx + math.cos(t0) * R, cz + math.sin(t0) * R)
        p1 = (cx + math.cos(t1) * R, cz + math.sin(t1) * R)
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) + 0.3
        ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
        P.append(box((L, 0.15, 1.0), (mid[0], 0.86, mid[1]), 0xFF4D4D, "N", r=(0, -ang, 0)))
    posts = 12
    for k in range(posts):
        t = 2 * math.pi * k / posts + math.pi / posts
        px, pz = cx + math.cos(t) * (R + 1.5), cz + math.sin(t) * (R + 1.5)
        P.append(cyl(1.6, 6, (px, 3, pz), 0xC0392B, "P"))
        P.append(ball(2.0, (px, 6.2, pz), 0xFFD54A, "N"))
        t2 = t + 2 * math.pi / posts
        mid_t = (t + t2) / 2
        d = abs((mid_t - gap + math.pi) % (2 * math.pi) - math.pi)
        if d < math.pi / posts * 1.6:
            continue  # entrance: no ropes here
        qx, qz = cx + math.cos(t2) * (R + 1.5), cz + math.sin(t2) * (R + 1.5)
        L = math.hypot(qx - px, qz - pz)
        ang = math.degrees(math.atan2(qz - pz, qx - px))
        for y in (2.6, 4.4):
            P.append(box((L, 0.35, 0.35), ((px + qx) / 2, y, (pz + qz) / 2), 0xF5F5F5, "P", r=(0, -ang, 0)))
    # path from the hub plaza to the entrance
    ex, ez = cx + math.cos(gap) * (R + 2), cz + math.sin(gap) * (R + 2)
    hx, hz = HUB[0] + math.cos(gap + math.pi) * 40, HUB[2] + math.sin(gap + math.pi) * 40
    L = math.hypot(ex - hx, ez - hz)
    ang = math.degrees(math.atan2(ez - hz, ex - hx))
    P.append(box((L, 0.3, 10), ((ex + hx) / 2, 0.13, (ez + hz) / 2), 0xE8DCC0, "U", r=(0, -ang, 0)))
    # "PET RING" arch sign at the back, facing the entrance
    sx, sz = cx - math.cos(gap) * (R + 4), cz - math.sin(gap) * (R + 4)
    interact.append({"kind": "Sign", "prop": "RingArch", "area": area, "pos": (sx, 0, sz),
                     "yaw": yaw_towards((sx, 0, sz), (cx, 0, cz)), "attrs": {"Text": "PET RING"}})
    # grass tufts and grey rocks around the outside
    for k in range(14):
        t = gap + math.pi * 0.25 + (2 * math.pi - math.pi * 0.5) * k / 13
        rr = R + 6 + (k % 3) * 2.5
        name = "Rock" if k % 3 == 1 else "GrassTuft"
        place.append((name, round(cx + math.cos(t) * rr, 2), 0, round(cz + math.sin(t) * rr, 2), (k * 47) % 360,
                      0.55 if name == "Rock" else 1.4, area))


EGG_FOR = {"Meadow": "MeadowEgg", "Grove": "GroveEgg", "Frost": "FrostEgg", "Coral": "CoralEgg", "Volcano": "VolcanoEgg",
           "Starfall": "StarEgg"}
AREA_NAME = {"Meadow": "Sunny Meadow", "Grove": "Mushroom Grove", "Frost": "Frostbite Peaks", "Coral": "Coral Cove",
             "Volcano": "Ember Volcano", "Starfall": "Starfall Isles"}


def count_parts(w, props, eggs):
    n = sum(len(v) for v in w["parts"].values())
    for pl in w["place"]:
        n += len(props[pl[0]]["parts"])
    for it in w["interact"]:
        n += len(props[it["prop"]]["parts"])
        if it["kind"] == "EggStand":
            n += len(eggs.get(it["attrs"]["EggId"], []))
    return n
