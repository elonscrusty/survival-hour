"""World layout: six round islands along +X joined by bridges, the Meadow
hub, gates, egg stands, decorations, zones, spawns and bounds.

Everything here is data; Models/World.luau builds it in Roblox and render.py
draws the same layout. Ground top is y = 0, the sea surface is y = -8.
"""
import math
import random
from lib import box, cyl, ball, T

SPACING = 320
RADIUS = {"Meadow": 150}
DEFAULT_RADIUS = 125
WATER_LEVEL = -8
BRIDGE_W = 18
WALL_H = 40

GROUND = {
    #           top colour, mat, rim colour, cliff colour, cliff mat, path colour, path mat
    "Meadow": (0x6CC24A, "E", 0x5AAE3C, 0x9A7450, "g", 0xE3CC92, "A"),
    "Grove": (0x3F8A4E, "E", 0x357A42, 0x5A4A5E, "T", 0x8A6E5A, "g"),
    "Frost": (0xF2F7FF, "S", 0xDDE8F5, 0x8FA3B8, "T", 0xBFE0F5, "I"),
    "Coral": (0xF2DCA2, "A", 0xE8CC8A, 0xD9B98A, "V", 0xC9A27C, "K"),
    "Volcano": (0x4A3E3E, "B", 0x3A3034, 0x2A2226, "B", 0x6E5A50, "T"),
    "Starfall": (0x8E7CE0, "E", 0x7A68CC, 0x3B2E6E, "T", 0xE8D8FF, "Y"),
}

DECOR = {
    # prop, weight, (min scale, max scale), footprint radius
    "Meadow": [("TreeRound", 3, (0.9, 1.25), 7), ("Bush", 3, (0.8, 1.2), 4), ("Flowers", 5, (1.0, 1.5), 3),
               ("HayBale", 2, (1.0, 1.1), 3), ("Rock", 1.5, (0.8, 1.3), 4)],
    "Grove": [("GiantMushroom", 3, (0.9, 1.3), 7), ("GlowMushroom", 2, (0.9, 1.2), 5), ("MushroomCluster", 4, (1.0, 1.5), 3),
              ("Log", 2, (1.0, 1.2), 5), ("GroveTree", 3, (0.9, 1.2), 7), ("GroveBush", 2, (0.9, 1.2), 4)],
    "Frost": [("PineSnow", 6, (0.9, 1.4), 5), ("IceSpire", 2, (0.8, 1.3), 5), ("SnowRock", 2, (0.8, 1.2), 4),
              ("Snowman", 1, (1.0, 1.0), 3)],
    "Coral": [("Palm", 4, (0.9, 1.25), 5), ("Coral", 3, (1.0, 1.5), 3), ("CoralPurple", 2, (1.0, 1.4), 3), ("Shell", 2, (0.8, 1.2), 3),
              ("Starfish", 3, (1.0, 1.5), 2), ("Umbrella", 1, (1.0, 1.0), 5), ("BeachRock", 2, (0.8, 1.2), 4)],
    "Volcano": [("LavaRock", 4, (0.9, 1.4), 4), ("LavaPool", 2, (1.0, 1.4), 7), ("DeadTree", 3, (0.9, 1.3), 4),
                ("ObsidianSpike", 3, (0.8, 1.3), 4)],
    "Starfall": [("FloatCrystal", 3, (0.9, 1.3), 4), ("FloatCrystalCyan", 2, (0.9, 1.3), 4), ("Planet", 2, (0.9, 1.2), 5),
                 ("PlanetBlue", 1, (0.9, 1.1), 5), ("MoonRock", 2, (0.8, 1.2), 4), ("StarTree", 3, (0.9, 1.2), 4)],
}
DECOR_COUNT = {"Meadow": 85, "Grove": 75, "Frost": 75, "Coral": 75, "Volcano": 70, "Starfall": 70}
DECOR_SCALE = 1.4  # decorations read better a bit oversized next to 5-stud avatars
LAMP = {"Meadow": "Lamp", "Grove": "GroveLamp", "Frost": "FrostLamp", "Coral": "CoralLamp", "Volcano": "VolcanoLamp",
        "Starfall": "StarLamp"}
BACKDROP = {
    # prop, offset from island centre (x, y, z), yaw, scale
    "Grove": ("GiantMushroomBackdrop", (20, WATER_LEVEL - 2, -190), 0, 2.4),
    "Frost": ("Mountain", (0, WATER_LEVEL - 2, -215), 0, 1.6),
    "Coral": ("Lighthouse", (95, WATER_LEVEL - 2, -120), 0, 1.0),
    "Volcano": ("VolcanoPeak", (0, WATER_LEVEL - 2, -220), 0, 1.0),
    "Starfall": ("BigPlanet", (60, 110, -230), 0, 1.0),
}
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
        P.append(cyl(2 * R + 4, 3, (x, -3.2, 0), rim, top_m))
        P.append(cyl(2 * R - 4, 34, (x, -21, 0), cliff, cliff_m))
        # a few lumps on the cliff so the outline is not a perfect cylinder
        for k in range(10):
            ang = 2 * math.pi * (k + 0.5) / 10 + 0.2
            if abs(math.cos(ang)) > 0.93:
                continue  # leave the bridge ends clear
            d = rnd.uniform(26, 40)
            P.append(ball((d, rnd.uniform(18, 26), d), (x + math.cos(ang) * (R - 6), -14, math.sin(ang) * (R - 6)), cliff, cliff_m))
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
            P.append(cyl(84, 0.3, (HUB[0], 0.14, HUB[2]), 0xE8DCC0, "U"))
            hub_items = [
                ("SpawnLocation", "SpawnPad", (HUB[0], 0, HUB[2]), 0, {}),
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
            build_arena(P, interact, a)
            blocked.append((ARENA[0], ARENA[2], ARENA_R + 10))
            blocked.append(((HUB[0] + ARENA[0]) / 2, (HUB[2] + ARENA[2]) / 2, 9))  # the path to the ring
            for bx, bz in ((HUB[0] + 12, 40), (HUB[0] - 16, 40)):
                place.append(("Bench", bx, 0, bz, yaw_towards((bx, 0, bz), HUB), 1.0, a))
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
        if a in BACKDROP:
            name, off, yaw, s = BACKDROP[a]
            place.append((name, x + off[0], off[1], off[2], yaw, s, a))

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
        deck, beam = 0xB0804A, 0x7E5230
        B.append(box((L, 1.2, BRIDGE_W), (cx, -0.6, 0), deck, "K"))
        B.append(box((26, 1.2, BRIDGE_W + 10), (centers[a1] - radius(a1) - 12, -0.62, 0), deck, "K"))
        for sz in (-1, 1):
            B.append(box((L, 1.8, 1.2), (cx, -0.3, sz * (BRIDGE_W / 2 + 0.4)), beam, "W"))
            B.append(box((L, 0.5, 0.7), (cx, 3.4, sz * (BRIDGE_W / 2 + 0.4)), beam, "W"))
            B.append(box((L, WALL_H, 1), (cx, WALL_H / 2, sz * (BRIDGE_W / 2 + 1.2)), 0xFFFFFF, "P", tag="Wall", t=1.0))
            n = max(2, int(L // 10))
            for k in range(n + 1):
                px = x0 + L * k / n
                B.append(box((0.9, 4.2, 0.9), (px, 1.5, sz * (BRIDGE_W / 2 + 0.4)), beam, "W"))
        for k in range(1, max(2, int(L // 24)) + 1):
            px = x0 + L * k / (max(2, int(L // 24)) + 1)
            for sz in (-1, 1):
                B.append(cyl(2.4, 16, (px, -8.6, sz * (BRIDGE_W / 2 - 1)), beam, "W"))
        for px in (x0 + 4, x1 - 4):
            for sz in (-1, 1):
                place.append(("BridgeLantern", round(px, 2), 0, sz * (BRIDGE_W / 2 + 0.4), 0, 1.0, "Bridges"))

    last = areas[-1]
    water = {"level": WATER_LEVEL, "minx": -radius(areas[0]) - 260, "maxx": centers[last] + radius(last) + 260,
             "minz": -480, "maxz": 480}
    spawn_location = (HUB[0], 0, HUB[2])
    arena = {"center": ARENA, "radius": ARENA_R}
    return {"arena": arena, "spacing": SPACING, "centers": centers, "radius": {a: radius(a) for a in areas}, "parts": parts, "place": place,
            "interact": interact, "zones": zones, "spawns": spawns, "bounds": bounds, "water": water,
            "spawn_location": spawn_location}


def build_arena(P, interact, area):
    """The Pet Ring: a raised sand floor with a glowing edge, corner posts and ropes,
    an opening facing the hub, and a sign. Walking inside starts fights (RingService)."""
    cx, _, cz = ARENA
    R = ARENA_R
    P.append(cyl(2 * R + 6, 0.5, (cx, 0.25, cz), 0x8A5A3C, "K"))
    P.append(cyl(2 * R, 0.8, (cx, 0.4, cz), 0xE9C98B, "A"))
    P.append(cyl(10, 0.82, (cx, 0.41, cz), 0xD9534F, "P"))
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
    sx, sz = ex + math.cos(gap + math.pi / 2) * 9, ez + math.sin(gap + math.pi / 2) * 9
    interact.append({"kind": "Sign", "prop": "IslandSign", "area": area, "pos": (sx, 0, sz),
                     "yaw": yaw_towards((sx, 0, sz), HUB), "attrs": {"Text": "PET RING"}})


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
