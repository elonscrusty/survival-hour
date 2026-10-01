"""Creatures (chickens, fox, eggs) and workers (farmhand, robo picker). Units: studs, front = -Y."""

import math
import random

from mathutils import Vector

from lib import deform


# ---------------------------------------------------------------- chickens
def chicken(b, body="White", wing=None, tail=None):
    wing = wing or body
    tail = tail or body
    o = -0.12  # body drop: keeps the legs short and stubby
    # legs + feet
    for sx in (-1, 1):
        b.cylb(0.06, 0.3, (sx * 0.16, 0.02, 0), "Beak", segs=6)
        b.boxb((0.2, 0.24, 0.06), (sx * 0.16, -0.06, 0), "Beak")
    # body (plump ellipsoid) and chest
    b.sphere(0.5, (0, 0.05, 0.78 + o), body, scale=(0.82, 1.08, 0.86), u=12, v=8)
    b.sphere(0.36, (0, -0.32, 0.86 + o), body, scale=(0.9, 0.8, 1.0), u=10, v=6)
    # wings
    for sx in (-1, 1):
        b.sphere(0.32, (sx * 0.42, 0.1, 0.84 + o), wing, scale=(0.35, 1.05, 0.7), u=8, v=6)
    # tail fan (three tilted cones)
    for i, tx in enumerate((-0.12, 0, 0.12)):
        b.cyl(0.17, 0.42, (tx, 0.6, 1.02 + o + (0.05 if i == 1 else 0)), tail, segs=6, r2=0.04,
              rot=(-58, tx * 140, 0))
    # head
    b.sphere(0.26, (0, -0.46, 1.22 + o), body, u=10, v=6)
    # beak (cone pointing -Y) and wattle
    b.cyl(0.085, 0.22, (0, -0.76, 1.19 + o), "Beak", segs=6, r2=0.0, rot=(90, 0, 0))
    b.sphere(0.07, (0, -0.68, 1.06 + o), "Comb", scale=(0.8, 0.8, 1.3), u=6, v=4)
    # comb (three bumps)
    for y, z, r in ((-0.58, 1.47, 0.08), (-0.46, 1.52, 0.1), (-0.33, 1.47, 0.08)):
        b.sphere(r, (0, y, z + o), "Comb", scale=(0.6, 1, 1.1), u=6, v=4)
    # eyes
    for sx in (-1, 1):
        b.sphere(0.05, (sx * 0.2, -0.6, 1.28 + o), "Black", u=6, v=4)


def chicken_white(b):
    chicken(b, "White", tail="Cream")


def chicken_brown(b):
    chicken(b, "BrownLight", wing="Brown", tail="WoodDark")


# ---------------------------------------------------------------- fox
def fox(b):
    # legs (dark socks)
    for sx in (-1, 1):
        for y in (-0.55, 0.55):
            b.cylb(0.09, 0.3, (sx * 0.28, y, 0), "Black", segs=6)
            b.cylb(0.1, 0.45, (sx * 0.28, y, 0.28), "Fox", segs=6, r2=0.15)
    # body
    b.sphere(0.5, (0, 0, 0.92), "Fox", scale=(0.9, 1.55, 0.72), u=12, v=8)
    b.sphere(0.34, (0, -0.55, 0.85), "White", scale=(0.8, 0.6, 0.8), u=8, v=6)  # chest
    # head
    b.sphere(0.36, (0, -0.95, 1.35), "Fox", scale=(1.0, 0.95, 0.85), u=10, v=6)
    b.cyl(0.22, 0.5, (0, -1.35, 1.27), "White", segs=8, r2=0.06, rot=(90, 0, 0), scale=(1.0, 0.8, 1))
    b.sphere(0.07, (0, -1.6, 1.29), "Black", u=6, v=4)  # nose
    for sx in (-1, 1):
        b.cyl(0.14, 0.42, (sx * 0.2, -0.88, 1.72), "Fox", segs=4, r2=0.0, rot=(0, sx * 12, 45))  # ears
        b.cyl(0.07, 0.26, (sx * 0.2, -0.92, 1.68), "Black", segs=4, r2=0.0, rot=(0, sx * 12, 45))
        b.sphere(0.055, (sx * 0.17, -1.22, 1.45), "Black", u=6, v=4)  # eyes
    # tail: big bushy cone with a white tip
    b.cyl(0.24, 1.1, (0, 1.2, 1.0), "Fox", segs=8, r2=0.34, rot=(-74, 0, 0))
    b.cyl(0.34, 0.4, (0, 1.9, 1.2), "White", segs=8, r2=0.04, rot=(-74, 0, 0))


# ---------------------------------------------------------------- eggs
EGG_VARIANTS = {
    # id (src/shared/Data/Eggs.luau): (shell rgb, spot rgb, spot emission)
    "farm": ((250, 240, 222), (214, 186, 132), 0),
    "clover": ((122, 204, 120), (255, 255, 255), 0),
    "honey": ((255, 204, 64), (160, 100, 52), 0),
    "seashell": ((255, 204, 192), (54, 170, 196), 0),
    "frost": ((204, 236, 255), (255, 255, 255), 0),
    "cactus": ((120, 182, 100), (226, 168, 104), 0),
    "magma": ((82, 72, 72), (255, 140, 40), 3.0),
    "crystal": ((192, 152, 255), (80, 200, 220), 0),
    "nebula": ((60, 62, 124), (120, 240, 255), 3.0),
    "sunburst": ((255, 212, 72), (255, 255, 255), 0),
}

EGG_R = 0.5  # 1 stud wide, ~1.3 studs tall


def egg_shape(co):
    # input: unit-ish sphere centred at origin (radius EGG_R); stretch up and taper the top
    z = co.z / EGG_R  # -1..1
    taper = 1.0 - 0.16 * max(0.0, z) - 0.03 * max(0.0, -z)
    return Vector((co.x * taper, co.y * taper, co.z * 1.3 + EGG_R * 1.3))


def egg(b, shell="White", spots=None, seed=1):
    faces = b.sphere(EGG_R, (0, 0, 0), shell, u=18, v=14)
    if spots:
        # paint round patches of shell faces (flat "speckles", no extra geometry)
        rnd = random.Random(seed)
        centres = []
        for i in range(9):
            az = i * 2.4 + rnd.uniform(-0.3, 0.3)
            el = rnd.uniform(-0.5, 0.8)
            centres.append((Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el))),
                            rnd.uniform(0.2, 0.32)))
        idx = b.mi(spots)
        for f in faces:
            n = f.calc_center_median().normalized()
            if any(n.angle(c) < r for c, r in centres):
                f.material_index = idx
    deform(faces, egg_shape)


def egg_plain(b):
    egg(b, "White")


def egg_variant(eid):
    shell, spot, emit = EGG_VARIANTS[eid]

    def fn(b):
        sk = "Egg_" + eid + "_Shell"
        pk = "Egg_" + eid + "_Spots"
        b.mi(sk, shell, rough=0.5)
        b.mi(pk, spot, emission=emit, rough=0.5)
        egg(b, sk, pk, seed=sum(map(ord, eid)))

    return fn


# ---------------------------------------------------------------- workers
def farmhand(b):
    """Blocky Roblox-proportioned farmer: 2-stud legs, 2-stud torso, ~1.1-stud head, straw hat."""
    # legs (denim) + boots
    for sx in (-0.5, 0.5):
        b.boxb((0.95, 1.0, 2.0), (sx, 0, 0), "Denim")
        b.boxb((1.0, 1.15, 0.4), (sx, -0.05, 0), "WoodDark")
    # torso: shirt with denim overall bib and straps
    b.boxb((2.0, 1.0, 2.0), (0, 0, 2.0), "Shirt")
    b.boxb((1.5, 1.04, 1.1), (0, 0, 2.0), "Denim")
    for sx in (-0.55, 0.55):
        b.boxb((0.28, 1.06, 0.9), (sx, 0, 3.1), "Denim")
        b.box((0.16, 0.06, 0.16), (sx, -0.54, 3.1), "Accent")  # buttons
    b.box((0.6, 0.06, 0.4), (0, -0.53, 2.65), "Denim")  # pocket
    # arms: shirt sleeves + skin hands
    for sx in (-1.5, 1.5):
        b.boxb((0.95, 0.95, 1.4), (sx, 0, 2.6), "Shirt")
        b.boxb((0.9, 0.9, 0.62), (sx, 0, 2.0), "Skin")
    # head
    b.boxb((1.15, 1.1, 1.15), (0, 0, 4.0), "Skin")
    for sx in (-0.24, 0.24):
        b.box((0.16, 0.05, 0.22), (sx, -0.56, 4.68), "Black")
    b.box((0.4, 0.05, 0.08), (0, -0.56, 4.33), "Black")  # smile
    b.boxb((1.2, 0.3, 0.35), (0, 0.42, 4.75), "Hair")
    # straw hat: wide brim + crown + red band
    b.cylb(1.2, 0.12, (0, 0, 5.05), "Straw", segs=14)
    b.cylb(0.62, 0.55, (0, 0, 5.15), "Straw", segs=12, r2=0.55)
    b.cylb(0.64, 0.14, (0, 0, 5.17), "Roof", segs=12)


def robo_picker(b):
    """Friendly egg-collecting robot on tank treads, with a basket arm."""
    # treads
    for sx in (-1, 1):
        b.boxb((0.7, 2.6, 0.7), (sx * 0.95, 0, 0), "GreyDark")
        for y in (-1.0, 0, 1.0):
            b.cyl(0.36, 0.74, (sx * 0.95, y, 0.36), "Black", segs=10, rot=(0, 90, 0))
    b.boxb((1.4, 2.0, 0.4), (0, 0, 0.45), "GreyDark")
    # body
    b.boxb((2.2, 1.8, 1.6), (0, 0, 0.8), "Metal")
    b.boxb((2.3, 1.9, 0.25), (0, 0, 2.4), "Accent")
    b.box((1.2, 0.1, 0.7), (0, -0.92, 1.55), "Accent")  # chest panel
    b.cyl(0.18, 0.1, (0, -0.98, 1.55), "Comb", segs=10, rot=(90, 0, 0))
    # neck + head with a glowing visor
    b.cylb(0.25, 0.35, (0, 0, 2.65), "GreyDark", segs=8)
    b.boxb((1.6, 1.3, 1.0), (0, 0, 2.95), "Metal")
    b.box((1.25, 0.1, 0.45), (0, -0.66, 3.5), "Black")
    b.mi("RoboEye", (120, 240, 255), emission=3.0)
    for sx in (-0.3, 0.3):
        b.box((0.24, 0.06, 0.24), (sx, -0.72, 3.5), "RoboEye")
    # antenna
    b.cylb(0.05, 0.6, (0, 0, 3.95), "GreyDark", segs=6)
    b.sphere(0.15, (0, 0, 4.6), "Accent", u=8, v=6)
    # arms: one holds a basket
    for sx in (-1, 1):
        b.cyl(0.25, 0.3, (sx * 1.25, 0, 2.0), "GreyDark", segs=8, rot=(0, 90, 0))
        b.box((0.35, 0.35, 1.2), (sx * 1.42, -0.2, 1.45), "Metal", rot=(30, 0, 0))
    # basket in front of the left arm
    b.cylb(0.55, 0.5, (-1.42, -0.85, 0.75), "Straw", segs=10, r2=0.65)
    b.cylb(0.5, 0.05, (-1.42, -0.85, 1.2), "Cream", segs=10)
    for dx, dy in ((-0.18, 0.05), (0.18, -0.05), (0, 0.18)):
        b.sphere(0.17, (-1.42 + dx, -0.85 + dy, 1.32), "White", scale=(1, 1, 1.3), u=8, v=6)


ASSETS = {
    "Creatures": [
        ("Chicken", chicken_white),
        ("ChickenBrown", chicken_brown),
        ("Fox", fox),
        ("Egg", egg_plain),
    ] + [("Egg_" + k, egg_variant(k)) for k in EGG_VARIANTS],
    "Workers": [
        ("Farmhand", farmhand),
        ("RoboPicker", robo_picker),
    ],
}
