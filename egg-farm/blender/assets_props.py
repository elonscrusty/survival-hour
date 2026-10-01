"""Small farm props. Units: studs, front = -Y."""

import random

from mathutils import Vector

from lib import deform


def jitter(faces, amount, seed, scale=(1, 1, 1)):
    rnd = random.Random(seed)

    def fn(co):
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * amount
        out = co + d
        out = Vector((out.x * scale[0], out.y * scale[1], out.z * scale[2]))
        return out

    deform(faces, fn)


def fence(b):  # 8 long (X) x 3.5 tall
    for x in (-3.75, 3.75):
        b.boxb((0.55, 0.55, 3.1), (x, 0, 0), "WoodDark")
        b.prism([(-0.275, 0), (0.275, 0), (0, 0.4)], 0.55, (x, 0, 3.1), "WoodDark")
    for z in (1.1, 2.4):
        b.box((8.0, 0.3, 0.55), (0, -0.3, z), "White")
    # middle picket
    b.boxb((0.4, 0.25, 2.8), (0, -0.3, 0), "White")


def tree(b):  # ~9 wide, ~14 tall
    b.cylb(0.75, 6.0, (0, 0, 0), "Trunk", segs=7, r2=0.5)
    b.box((2.2, 0.5, 0.5), (0.9, 0, 4.2), "Trunk", rot=(0, -40, 0))
    blobs = [((0, 0, 7.6), 3.9, "Leaf"), ((1.6, 0.6, 9.6), 2.9, "LeafDark"), ((-1.4, -0.4, 10.4), 2.7, "Leaf"),
             ((0.2, 0.2, 12.0), 2.0, "LeafDark"), ((-2.1, 1.2, 8.0), 2.4, "LeafDark")]
    for i, (c, r, m) in enumerate(blobs):
        f = b.ico(r, c, m, sub=1)
        jitter(f, r * 0.12, 11 + i)
    # a few fruit
    for p in ((2.6, -2.2, 7.4), (-2.8, -1.6, 8.6), (0.8, -3.2, 9.4)):
        b.sphere(0.35, p, "Comb", u=6, v=4)


def bush(b):  # ~4.5 wide x 3 tall
    for i, (c, r) in enumerate((((0, 0, 1.3), 1.6), ((1.3, 0.3, 1.0), 1.2), ((-1.3, 0.2, 1.0), 1.25),
                                ((0.3, 0.9, 1.9), 1.0))):
        f = b.ico(r, c, "Leaf" if i % 2 == 0 else "LeafDark", sub=1)
        jitter(f, r * 0.1, 30 + i)
    for p in ((0.7, -1.4, 1.6), (-0.9, -1.2, 1.2), (-0.1, -1.5, 2.2), (1.7, -0.7, 1.0)):
        b.sphere(0.22, p, "Accent" if p[0] > 0 else "White", u=6, v=4)


def rock(b):  # ~3.5 wide
    f = b.ico(1.5, (0, 0, 0.9), "Rock", sub=2, scale=(1.25, 1.0, 0.75))
    jitter(f, 0.18, 7)
    f = b.ico(0.7, (1.6, -0.6, 0.4), "RockDark", sub=1, scale=(1.2, 1.0, 0.8))
    jitter(f, 0.1, 8)
    # flatten the base so it sits on the ground
    deform([fc for fc in b.bm.faces], lambda co: Vector((co.x, co.y, max(co.z, 0.0))))


def egg_crate(b):  # 3 x 2 x 2 wooden crate full of eggs
    w, d, h = 3.0, 2.0, 1.4
    b.boxb((w, d, 0.2), (0, 0, 0), "WoodDark")
    for z in (0.25, 0.85):
        for sy in (-1, 1):
            b.boxb((w, 0.16, 0.45), (0, sy * (d / 2 - 0.08), z), "Wood")
        for sx in (-1, 1):
            b.boxb((0.16, d, 0.45), (sx * (w / 2 - 0.08), 0, z), "Wood")
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.boxb((0.28, 0.28, h), (sx * (w / 2 - 0.1), sy * (d / 2 - 0.1), 0), "WoodDark")
    b.boxb((w - 0.3, d - 0.3, 0.5), (0, 0, 0.2), "Straw")
    for ix in range(3):
        for iy in range(2):
            b.sphere(0.36, (-0.85 + ix * 0.85, -0.42 + iy * 0.84, 1.05), "Cream" if (ix + iy) % 2 else "White",
                     scale=(1, 1, 1.3), u=10, v=6)


def signboard(b):  # ~8 wide x 7 tall
    for x in (-3.4, 3.4):
        b.boxb((0.5, 0.5, 6.0), (x, 0, 0), "WoodDark")
    b.box((7.6, 0.4, 3.2), (0, -0.3, 4.2), "Wood")
    b.box((7.0, 0.42, 2.6), (0, -0.35, 4.2), "Cream")
    b.prism([(-4.2, 0), (4.2, 0), (0, 1.0)], 1.2, (0, -0.2, 5.8), "Roof")
    b.sphere(0.9, (-2.2, -0.6, 4.2), "Accent", scale=(0.8, 0.3, 1.05), u=10, v=6)
    for i, x in enumerate((-0.6, 0.6, 1.8, 3.0)):  # abstract "lettering" blocks
        b.box((0.9, 0.12, 0.3), (x, -0.6, 4.7), "Roof")
        b.box((0.9 if i % 2 else 0.6, 0.12, 0.3), (x, -0.6, 3.9), "WoodDark")
    b.boxb((1.2, 0.8, 0.2), (0, 0, 0), "Path")


ASSETS = {
    "Props": [
        ("Fence", fence),
        ("Tree", tree),
        ("Bush", bush),
        ("Rock", rock),
        ("EggCrate", egg_crate),
        ("Signboard", signboard),
    ],
}
