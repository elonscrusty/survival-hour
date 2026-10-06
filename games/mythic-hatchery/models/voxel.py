"""Blocky (voxel-toy) world props after reference/islands.jpg, hub.jpg and
pet_ring.jpg: cube trees, glowing mushrooms, stacked pines, segmented palms,
blocky rocks, island landmarks, the Meadow hub set pieces and Pet Ring
dressing. Everything faces -Z and sits on y = 0.
"""
import math
from lib import box, cyl, ball, wedge, T, sym, tri, crystal, rot, mmul, rx, ry, rz, shade, RAINBOW, WHITE

GOLD, GOLD_DK = 0xFFC93C, 0xD99A1E
STONE, STONE_DK, STONE_LT = 0xA9A6A0, 0x8A8680, 0xC9C6BE
WOOD, WOOD_DK = 0x9A6235, 0x6E4426
LANTERN = 0xFFE27A


def cube(s, pos, col, mat="P", r=None, tag=None, t=0.0):
    if isinstance(s, (int, float)):
        s = (s, s, s)
    return box(s, pos, col, mat, r=r, tag=tag, t=t)


# ---------------------------------------------------------------- shared small pieces
def lantern_post(h=6.0, glow=LANTERN, post=WOOD_DK):
    return [cube((0.7, h, 0.7), (0, h / 2, 0), post, "W"), cube((1.4, 0.3, 1.4), (0, h + 0.15, 0), post, "W"),
            cube(1.1, (0, h + 0.85, 0), glow, "N", tag="Glow"), cube((1.5, 0.35, 1.5), (0, h + 1.55, 0), post, "W")]


def stone_lantern(glow=LANTERN):
    return [cube((1.6, 1.6, 1.6), (0, 0.8, 0), STONE_LT, "U"), cube(1.0, (0, 2.1, 0), glow, "N", tag="Glow"),
            cube((1.5, 0.4, 1.5), (0, 2.8, 0), STONE, "U")]


def grass_tuft(c=0x5DBB46):
    return [cube((0.5, 1.6, 0.5), (0, 0.8, 0), c, r=(0, 20, 8)), cube((0.45, 1.2, 0.45), (0.6, 0.6, 0.2), shade(c, 1.1), r=(0, -15, -12)),
            cube((0.45, 1.0, 0.45), (-0.5, 0.5, -0.3), shade(c, 0.9), r=(0, 40, 10))]


def vox_rock(c=STONE, mat="R", s=1.0):
    return T([cube((4.2, 3.0, 3.6), (0, 1.3, 0), c, mat, r=(0, 15, 4)), cube((2.6, 2.2, 2.4), (1.9, 0.9, 0.9), shade(c, 0.9), mat, r=(0, 40, -6)),
              cube((2.0, 1.5, 2.0), (-1.9, 0.6, -0.6), shade(c, 1.1), mat, r=(0, -20, 0))], s=s)


def fence(c=WOOD):
    return [cube((0.6, 3.0, 0.6), (-3, 1.5, 0), c, "W"), cube((0.6, 3.0, 0.6), (3, 1.5, 0), c, "W"),
            cube((6.6, 0.45, 0.35), (0, 2.3, 0), shade(c, 1.1), "W"), cube((6.6, 0.45, 0.35), (0, 1.2, 0), shade(c, 1.1), "W")]


def hay_crate():
    return [cube((3.2, 2.6, 3.2), (0, 1.3, 0), 0xF2C94C, "X"), cube((3.3, 0.4, 3.3), (0, 1.3, 0), 0xC9962E, "X"),
            cube((0.4, 2.7, 3.3), (0, 1.3, 0), 0xC9962E, "X")]


def daisies():
    p = [cube((4.0, 0.3, 3.4), (0, 0.15, 0), 0x5DBB46, "E")]
    for i, (x, z, h) in enumerate(((-1.1, -0.6, 1.2), (0.9, -0.9, 1.6), (0.2, 0.8, 1.4), (-1.3, 1.0, 1.0), (1.4, 0.7, 1.1))):
        p += [cube((0.16, h, 0.16), (x, h / 2, z), 0x3E8F35), cube((0.9, 0.18, 0.3), (x, h, z), WHITE), cube((0.3, 0.18, 0.9), (x, h, z), WHITE),
              cube((0.34, 0.24, 0.34), (x, h + 0.05, z), 0xFFD23A)]
    return p


def bench():
    w = 0xA0703F
    return [cube((6, 0.4, 1.8), (0, 1.6, 0), w, "K"), cube((6, 1.6, 0.3), (0, 2.6, 0.8), w, "K", r=(-10, 0, 0)),
            cube((0.4, 1.5, 1.6), (-2.6, 0.75, 0), 0x4A4A50, "M"), cube((0.4, 1.5, 1.6), (2.6, 0.75, 0), 0x4A4A50, "M")]


# ---------------------------------------------------------------- Meadow
def vox_tree(leaf=0x5DBB46, leaf2=0x7ED35A, trunk=0x8A5A36):
    return [cube((1.8, 7, 1.8), (0, 3.5, 0), trunk, "W"), cube((7.5, 5.5, 7.5), (0, 9.0, 0), leaf, r=(0, 10, 0)),
            cube((5.5, 4.5, 5.5), (0.6, 12.5, -0.4), leaf2, r=(0, 35, 0)), cube((4.0, 3.5, 4.0), (3.2, 8.2, 1.5), leaf2, r=(0, 20, 0)),
            cube((3.6, 3.2, 3.6), (-3.0, 8.6, -1.2), shade(leaf, 0.92), r=(0, 50, 0))]


def vox_bush(c=0x4FA83A, c2=0x6CC24A):
    return [cube((3.8, 2.8, 3.4), (0, 1.4, 0), c, r=(0, 15, 0)), cube((2.6, 2.2, 2.4), (1.6, 1.1, 0.8), c2, r=(0, 40, 0)),
            cube((2.2, 1.8, 2.2), (-1.6, 0.9, -0.5), c2, r=(0, -10, 0))]


def windmill():
    wall, roof, sail = 0xF4EEE2, 0xD8483A, 0xFFF8EE
    p = [cube((10, 1.4, 10), (0, 0.7, 0), STONE, "U"), cube((8, 10, 8), (0, 6.4, 0), wall), cube((7, 7, 7), (0, 14.9, 0), wall),
         wedge((7.8, 4.5, 4.0), (0, 20.65, -1.95), roof), wedge((7.8, 4.5, 4.0), (0, 20.65, 1.95), roof, r=(0, 180, 0)),
         cube((2.0, 3.2, 0.3), (0, 2.9, -4.1), WOOD_DK, "W"), cube((1.6, 1.6, 0.3), (0, 9.5, -4.05), 0x7EC8F0, "G", t=0.2),
         cube((1.4, 1.4, 0.3), (0, 15.5, -3.55), 0xFFE27A, "N", tag="Glow")]
    hub = (0, 16, -4.3)
    p.append(cyl(1.6, 1.0, hub, GOLD, "F", r=(90, 0, 0)))
    for i in range(4):
        a = 45 + i * 90
        p += T([cube((0.6, 10, 0.3), (0, 5.4, 0), WOOD, "W"), cube((2.8, 7.5, 0.15), (1.6, 6.0, 0.1), sail, "X")], hub, r=(0, 0, a))
    return p


# ---------------------------------------------------------------- Grove
def glow_shroom(cap=0xFF6AD5, s=1.0, dots=WHITE):
    p = [cube((1.6, 6, 1.6), (0, 3, 0), 0xF6EEDC), cube((7, 1.6, 7), (0, 6.6, 0), cap, "N", tag="Glow"),
         cube((5, 1.2, 5), (0, 7.9, 0), cap, "N", tag="Glow"), cube((5.6, 0.4, 5.6), (0, 5.7, 0), 0xF0D2E8)]
    p += [cube((0.9, 0.2, 0.9), (1.4, 8.55, 0.8), dots, "N"), cube((0.8, 0.2, 0.8), (-1.2, 8.55, -1.0), dots, "N"),
          cube((0.2, 0.8, 0.8), (3.55, 6.7, 0.5), dots, "N"), cube((0.8, 0.8, 0.2), (-0.6, 6.7, -3.55), dots, "N")]
    return T(p, s=s)


def glow_cluster():
    p = []
    for (x, z, h, c) in ((0, 0, 2.2, 0x6AE8FF), (1.6, 0.8, 1.4, 0xFF6AD5), (-1.3, 0.9, 1.6, 0xB06CFF)):
        p += [cube((0.45, h, 0.45), (x, h / 2, z), 0xF6EEDC), cube((1.6, 0.6, 1.6), (x, h + 0.2, z), c, "N", tag="Glow")]
    return p


def purple_crystal(c=0xB06CFF, c2=0x7A4FC9):
    return (crystal((0, 0, 0), 1.2, 4.5, c, "G", t=0.1) + crystal((1.2, 0, 0.5), 0.8, 2.8, c2, "G", r=(0, 0, -20), t=0.1)
            + crystal((-1.0, 0, -0.4), 0.7, 2.2, c, "G", r=(0, 0, 25), t=0.1))


def vox_log(c=0x6E4A34):
    return [cube((7, 2.0, 2.0), (0, 1.0, 0), c, "W"), cube((0.2, 1.6, 1.6), (3.55, 1.0, 0), 0xC9A27C, "W"),
            cube((1.4, 0.4, 1.0), (1.0, 2.2, 0), 0x5FA84A, "E"), cube((0.35, 0.8, 0.35), (-1.5, 2.4, 0.2), 0xF6EEDC),
            cube((1.0, 0.4, 1.0), (-1.5, 2.95, 0.2), 0xFF6AD5, "N", tag="Glow")]


def grove_tree():
    return vox_tree(0x5A3E9A, 0x7A5AC0, 0x4A3040)


# ---------------------------------------------------------------- Frost
def vox_pine(g=0x2F6E5A, snow=WHITE):
    p = [cube((1.4, 3, 1.4), (0, 1.5, 0), 0x6A4A34, "W")]
    for y, w, h in ((3.0, 7.5, 3.0), (6.0, 5.5, 2.8), (8.8, 3.6, 2.6), (11.2, 1.8, 1.8)):
        p += [cube((w, h, w), (0, y + h / 2, 0), g), cube((w * 0.85, 0.5, w * 0.85), (0, y + h + 0.2, 0), snow, "S")]
    return p


def ice_crystal():
    return (crystal((0, 0, 0), 2.2, 9, 0xA8E4FF, "G", t=0.15) + crystal((1.8, 0, 0.8), 1.4, 5.5, 0xC8F0FF, "G", r=(0, 0, -18), t=0.15)
            + crystal((-1.6, 0, -0.6), 1.2, 4.5, 0x8FD3FF, "G", r=(0, 0, 20), t=0.15))


def snow_rock():
    return vox_rock(0x8FA3B8, "T") + [cube((4.0, 0.8, 3.4), (0.2, 3.0, 0.1), WHITE, "S", r=(0, 15, 4))]


def snowman():
    w = WHITE
    p = [cube(3.6, (0, 1.8, 0), w, "S"), cube(2.8, (0, 5.0, 0), w, "S"), cube(2.2, (0, 7.5, 0), w, "S"),
         cube((0.4, 0.4, 1.2), (0, 7.4, -1.6), 0xFF8A2A), cube((2.6, 0.3, 2.6), (0, 8.75, 0), 0x2A2A3A), cube((1.7, 1.4, 1.7), (0, 9.6, 0), 0x2A2A3A),
         cube((3.0, 0.6, 3.0), (0, 6.3, 0), 0xE0353F, "X")]
    p += sym([cube(0.35, (0.45, 7.8, -1.12), 0x1C1A2B, tag="Eye"), cube((0.25, 2.6, 0.25), (2.2, 5.4, 0), 0x6A4A34, r=(0, 0, 60))])
    return p


# ---------------------------------------------------------------- Coral
def vox_palm(trunk=0xB08A5A, leaf=0x4FB06A):
    p = []
    for i in range(6):
        p.append(cube((1.5 - i * 0.08, 2.5, 1.5 - i * 0.08), (i * 0.4, 1.25 + i * 2.4, 0), trunk if i % 2 == 0 else shade(trunk, 0.86), "W",
                      r=(0, 0, -7)))
    top = (2.3, 15.0, 0)
    for k in range(6):
        a = 360 * k / 6
        p += T([cube((1.6, 0.4, 4.0), (0, 0.3, -2.0), leaf, r=(-15, 0, 0)), cube((1.3, 0.35, 3.0), (0, -0.6, -5.0), shade(leaf, 0.85), r=(-35, 0, 0))],
               top, r=(0, a, 0))
    p += [cube(1.0, (2.8, 14.3, -0.6), 0x7A5A34), cube(1.0, (1.8, 14.2, 0.7), 0x7A5A34)]
    return p


def vox_coral(c=0xFF6F7F):
    p = [cube((3.0, 0.8, 2.8), (0, 0.4, 0), 0xE8C090, "V")]
    for x, z, h, a in ((0, 0, 4.5, 0), (1.0, 0.3, 3.2, -25), (-1.0, -0.2, 3.4, 28)):
        p += [cube((0.7, h, 0.7), (x + math.sin(math.radians(-a)) * h / 2, h / 2, z), c, r=(0, 0, a))]
    p += [cube((0.5, 1.4, 0.5), (0.6, 3.2, 0), c, r=(0, 0, -40)), cube((0.5, 1.2, 0.5), (-0.6, 3.6, 0), c, r=(0, 0, 40))]
    return p


def shell():
    c = 0xFFD8C8
    p = [ball((3.4, 1.6, 3.0), (0, 0.8, 0), c)]
    for i in range(5):
        a = -50 + i * 25
        p.append(cube((0.45, 1.7, 2.8), (math.sin(math.radians(a)) * 1.2, 0.85, 0), shade(c, 0.92), r=(0, 0, -a * 0.8)))
    return p


def starfish(c=0xFF8A5A):
    p = [cube((1.0, 0.4, 1.0), (0, 0.2, 0), c, r=(0, 36, 0))]
    for i in range(5):
        p += T([cube((0.6, 0.35, 1.6), (0, 0.18, -0.9), c)], r=(0, 72 * i, 0))
    return p


# ---------------------------------------------------------------- Volcano
def lava_rock():
    p = vox_rock(0x3A3034, "B", 1.1)
    p += [cube((3.0, 0.18, 0.18), (0.2, 1.6, -2.0), 0xFF6A1A, "N", r=(0, 15, 20), tag="Glow"),
          cube((2.0, 0.18, 0.18), (-1.0, 1.0, -1.7), 0xFF6A1A, "N", r=(0, -20, -30), tag="Glow")]
    return p


def lava_pool():
    p = [cube((9, 0.6, 9), (0, 0.3, 0), 0x2A2228, "B", r=(0, 10, 0)), cube((7.4, 0.66, 7.4), (0, 0.33, 0), 0xFF6A1A, "N", r=(0, 10, 0), tag="Glow")]
    for i in range(6):
        a = 2 * math.pi * i / 6
        p.append(cube((2.2, 1.2, 1.6), (math.sin(a) * 4.4, 0.6, -math.cos(a) * 4.4), 0x3A3034, "B", r=(0, math.degrees(a), 0)))
    return p


def dead_tree():
    c = 0x2E2626
    return [cube((1.4, 9, 1.4), (0, 4.5, 0), c, "B"), cube((0.7, 4, 0.7), (1.3, 7.5, 0), c, "B", r=(0, 0, -45)),
            cube((0.6, 3.5, 0.6), (-1.2, 8.5, 0.3), c, "B", r=(0, 0, 40)), cube((0.14, 3.0, 0.14), (0, 3.0, -0.72), 0xFF6A1A, "N", tag="Glow")]


def fire_crystal():
    return (crystal((0, 0, 0), 1.3, 5, 0xFF5A3A, "G", t=0.1) + crystal((1.1, 0, 0.5), 0.9, 3.2, 0xFFB02E, "G", r=(0, 0, -22), t=0.1)
            + [cube((2.4, 0.8, 2.0), (0, 0.4, 0), 0x3A3034, "B")])


# ---------------------------------------------------------------- Starfall
def float_crystal(c=0xB06CFF, c2=0x6AF2FF):
    vtx = mmul(rx(-35.264), rz(45))
    return ([cube((4.0, 1.6, 3.6), (0, 0.8, 0), 0x4A3C7A, "T", r=(0, 20, 0))] + crystal((0, 1.2, 0), 1.4, 5, c, "G", t=0.1)
            + [box((1.4, 1.4, 1.4), (0, 9.0, 0), c2, "N", R=vtx, tag="Glow"), box((0.8, 0.8, 0.8), (1.8, 7.6, 0.6), c, "N", R=mmul(ry(30), vtx), tag="Glow")])


def planet(c=0xFF9AD5, ringc=0xFFE66B, h=12):
    return [cube((0.4, h - 2.5, 0.4), (0, (h - 2.5) / 2, 0), 0x4A3C7A, "T", t=1.0), ball(5, (0, h, 0), c),
            cyl(9, 0.25, (0, h, 0), ringc, "N", r=(20, 0, 15), tag="Glow"), cube((3, 1.0, 2.6), (0, 0.5, 0), 0x4A3C7A, "T")]


def star_prop(c=0xFFE66B):
    from eggs import star5
    return [cube((2.4, 0.8, 2.4), (0, 0.4, 0), 0x4A3C7A, "T"), cube((0.5, 5, 0.5), (0, 3.3, 0), 0xE8D8FF, "M")] + T(star5(1.6, c, "N", th=0.5, tag="Glow"), (0, 7.2, 0))


def moon_rock():
    return vox_rock(0x6A5CA0, "T", 1.0) + [cube((1.0, 0.2, 1.0), (0.6, 2.85, -0.6), 0x4A3C7A, "T")]


# ---------------------------------------------------------------- island landmarks (north edge)
def landmark_coral():
    p = [cyl(40, 0.6, (0, 0.3, 0), 0xF2DCA2, "A"), cyl(34, 0.66, (0, 0.33, 0), 0x3FD0E0, "G", t=0.15)]
    p += T(vox_palm(), (-18, 0, 4)) + T(vox_palm(), (19, 0, 2), r=(0, 140, 0)) + T(vox_coral(), (10, 0, -16)) + T(vox_coral(0xC77CFF), (-12, 0, -15))
    return p


def paw_plaza():
    """The spawn: a big grey paw print in the middle of the plaza."""
    p = [cyl(24, 0.5, (0, 0.25, 0), 0xD6D2CA, "U"), cyl(18, 0.56, (0, 0.28, 0), 0xC2BEB6, "U")]
    p.append(cyl(8.4, 0.62, (0, 0.31, 1.4), 0x8F8C88, "U"))
    for x, z in ((-4.4, -2.6), (-1.6, -4.8), (1.6, -4.8), (4.4, -2.6)):
        p.append(cyl(3.2, 0.62, (x, 0.31, z), 0x8F8C88, "U"))
    return p


def map_board():
    frame, legs = WOOD, WOOD_DK
    W, H, y0 = 15.0, 9.0, 3.5
    p = [cube((1.0, y0 + H + 1.0, 1.0), (-W / 2 - 0.5, (y0 + H + 1.0) / 2, 0), legs, "W"),
         cube((1.0, y0 + H + 1.0, 1.0), (W / 2 + 0.5, (y0 + H + 1.0) / 2, 0), legs, "W"),
         cube((W + 2.2, 1.0, 1.2), (0, y0 + H + 0.5, 0), frame, "W"), cube((W + 2.2, 1.0, 1.2), (0, y0 - 0.5, 0), frame, "W"),
         cube((W, H, 0.4), (0, y0 + H / 2, 0.2), 0x6FC8F0)]
    # map: blue sea with green islands, a snowy mountain and a dotted route
    z = -0.05
    for x, y, w, h, c in ((-4.5, 6.2, 4.0, 3.0, 0x7CD35A), (0.5, 9.5, 4.5, 3.2, 0x7CD35A), (4.6, 5.8, 3.6, 2.8, 0xF2DCA2),
                          (-1.5, 4.6, 2.6, 1.6, 0x5A4AA0), (5.0, 10.0, 2.6, 2.0, 0x4A3E3E)):
        p.append(cube((w, h, 0.2), (x, y0 - 3.5 + y, z), c))
    p += T(tri((0, 0, 0), 2.6, 2.2, 0.25, 0x8FA3B8), (0.5, y0 + 6.4, z - 0.12)) + T(tri((0, 0, 0), 1.2, 0.9, 0.3, WHITE), (0.5, y0 + 7.7, z - 0.16))
    for k in range(7):
        p.append(cube((0.45, 0.45, 0.1), (-4.0 + k * 1.4, y0 + 3.4 + math.sin(k * 0.9) * 1.6, z - 0.15), 0xE0353F))
    p += [cube(1.0, (-W / 2 - 0.5, y0 + H + 1.6, 0), LANTERN, "N", tag="Glow"), cube(1.0, (W / 2 + 0.5, y0 + H + 1.6, 0), LANTERN, "N", tag="Glow"),
          cube((1.4, 0.3, 1.4), (-W / 2 - 0.5, y0 + H + 2.25, 0), legs, "W"), cube((1.4, 0.3, 1.4), (W / 2 + 0.5, y0 + H + 2.25, 0), legs, "W")]
    p.append(cube((7.0, 1.4, 0.1), (0, y0 - 1.6, -0.15), 0xFFFFFF, tag="SignFace", t=1.0))
    p.append(cube((7.4, 1.6, 0.3), (0, y0 - 1.6, 0.05), frame, "W"))
    p.append(cube(1.0, (0, 3, -2.5), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def gear(d, teeth, col, mat="F"):
    p = [cyl(d, 0.5, (0, 0, 0), col, mat, r=(90, 0, 0)), cyl(d * 0.35, 0.6, (0, 0, -0.05), shade(col, 0.8), mat, r=(90, 0, 0))]
    for i in range(teeth):
        a = 360 * i / teeth
        p += T([cube((d * 0.18, d * 0.2, 0.5), (0, d / 2 + d * 0.05, 0), col, mat)], r=(0, 0, a))
    return p


def gear_machine():
    g, dk = GOLD, GOLD_DK
    p = [cyl(14, 0.6, (0, 0.3, 0), 0xC2BEB6, "U"), cube((10, 1.0, 7), (0, 1.1, 0), dk, "F"),
         cube((9, 5.5, 6), (0, 4.35, 0.3), g, "F", tag="Body"), cube((9.6, 0.7, 6.6), (0, 7.45, 0.3), dk, "F"),
         cube((6.4, 4.0, 0.3), (0, 4.3, -2.75), 0x3A3036, "M")]
    p += T(gear(3.2, 8, 0xD8D8E0, "M"), (-1.4, 4.4, -2.95)) + T(gear(2.2, 6, GOLD, "F"), (1.6, 3.6, -2.95))
    p += [cube((3.0, 1.2, 3.0), (0, 8.4, 0.3), dk, "F"), cyl(3.4, 3.2, (0, 10.6, 0.3), 0xE8F6FF, "G", t=0.55),
          cube((3.6, 0.5, 3.6), (0, 12.4, 0.3), dk, "F")]
    p += crystal((0, 9.1, 0.3), 1.2, 2.4, 0xE65AE0, "G", t=0.05)
    p += sym([cube((1.2, 1.2, 1.2), (4.6, 2.6, -2.6), LANTERN, "N", tag="Glow")])
    p.append(cube((5.0, 1.0, 0.1), (0, 1.1, -3.56), 0xFFFFFF, tag="SignFace", t=1.0))
    p.append(cube(1.0, (0, 3, -4.5), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def paw_badge(d=2.4):
    p = [cyl(d, 0.2, (0, 0, 0), GOLD, "F", r=(90, 0, 0)), cyl(d * 0.38, 0.1, (0, -d * 0.1, -0.12), 0xB06A1E, r=(90, 0, 0))]
    for x, y in ((-0.26, 0.12), (-0.09, 0.27), (0.09, 0.27), (0.26, 0.12)):
        p.append(cyl(d * 0.14, 0.1, (x * d, y * d, -0.12), 0xB06A1E, r=(90, 0, 0)))
    return p


def dog_statue(puppy_parts):
    stone, stone_dk = 0xE6E3DE, 0xC9C6BE
    p = [cube((12, 1.0, 12), (0, 0.5, 0), STONE, "U"), cube((10, 1.0, 10), (0, 1.5, 0), STONE_LT, "U"),
         cube((7, 4.0, 7), (0, 4.0, 0), stone_dk, "U"), cube((7.6, 0.6, 7.6), (0, 6.3, 0), STONE_LT, "U")]
    p += T(paw_badge(2.6), (0, 4.2, -3.55))
    keep = []
    for q in puppy_parts:
        if q.tag == "Eye":
            keep.append(q)
        else:
            keep.append(q.copy(col=0xF2F0EC if q.tag != "Face" else 0xFFFFFF, mat="Y"))
    p += T(keep, (0, 6.6, 0))
    p += sym([cube((1.6, 1.6, 1.6), (5.2, 2.8, -5.2), STONE_LT, "U"), cube(1.0, (5.2, 4.1, -5.2), LANTERN, "N", tag="Glow")])
    p.append(cube((5.0, 1.0, 0.1), (0, 2.6, -3.56), 0xFFFFFF, tag="SignFace", t=1.0))
    p.append(cube(1.0, (0, 3, -6.5), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def giant_book():
    red, page = 0xD03A3A, 0xFFF6E2
    p = [cube((12, 1.0, 9), (0, 0.5, 0), STONE, "U"), cube((10, 1.0, 7.5), (0, 1.5, 0), STONE_LT, "U"),
         cube((8.8, 3.0, 5.2), (0, 3.5, 0), red), cube((9.2, 0.4, 5.6), (0, 5.2, 0), GOLD, "F"),
         cube((9.2, 0.4, 5.6), (0, 2.1, 0), GOLD, "F")]
    for s in (-1, 1):
        p += T([cube((4.4, 0.35, 5.6), (s * 2.2, 0, 0), red), cube((4.1, 0.8, 5.2), (s * 2.1, 0.55, 0), page),
                cube((0.25, 0.5, 5.4), (s * 4.35, 0.3, 0), GOLD, "F")], (0, 6.0, 0.3), r=(-18, 0, s * -7))
    p += T(paw_badge(1.8), (0, 3.6, -2.7))
    p += sym([cube((1.0, 2.2, 0.2), (3.2, 3.2, -2.75), 0x3A7AE0, "X"), cube((1.4, 1.4, 1.4), (5.8, 2.7, -3.6), STONE_LT, "U"),
              cube(0.9, (5.8, 3.85, -3.6), LANTERN, "N", tag="Glow")])
    p += [cube((0.2, 0.05, 2.0), (0.3, 6.95, -1.0), 0x3A7AE0, "X", r=(-18, 0, 0))]
    p.append(cube((4.0, 0.8, 0.1), (0, 4.6, -2.65), 0xFFFFFF, tag="SignFace", t=1.0))
    p.append(cube(1.0, (0, 3, -5.0), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def dock():
    p = [cube((8, 0.8, 30), (0, 0, 0), 0xB0804A, "K")]
    for z in (-13, -4, 5, 13):
        p += sym([cube((1.0, 5, 1.0), (3.6, -2.4, z), WOOD_DK, "W")])
    p += sym([cube((0.8, 2.2, 0.8), (3.6, 1.4, 14), WOOD_DK, "W")])
    return p


# ---------------------------------------------------------------- Pet Ring dressing
def ring_arch():
    """'PET RING' sign at the back of the ring (SignFace gets the text)."""
    return [cube((1.4, 14, 1.4), (-8.5, 7, 0), WOOD, "W"), cube((1.4, 14, 1.4), (8.5, 7, 0), WOOD, "W"),
            cube((1.8, 0.6, 1.8), (-8.5, 14.3, 0), WOOD_DK, "W"), cube((1.8, 0.6, 1.8), (8.5, 14.3, 0), WOOD_DK, "W"),
            cube((16, 4.6, 0.8), (0, 11.4, 0), 0x8A5A36, "K"), cube((16.8, 0.5, 1.0), (0, 13.9, 0), WOOD_DK, "W"),
            cube((16.8, 0.5, 1.0), (0, 8.9, 0), WOOD_DK, "W"), cube((15, 3.8, 0.1), (0, 11.4, -0.46), 0xFFFFFF, tag="SignFace", t=1.0)]


def stepping_stone(c=0xD9B98A):
    return [cyl(3.2, 0.2, (0, 0.1, 0), c, "A")]


# ---------------------------------------------------------------- clusters (richer islands)
def tree_cluster():
    return (T(vox_tree(), (0, 0, 0), s=1.25) + T(vox_tree(0x4FA83A, 0x6CC24A), (7, 0, 4), r=(0, 40, 0), s=0.9)
            + T(vox_tree(), (-6, 0, 5), r=(0, 75, 0), s=0.75) + T(vox_bush(), (3, 0, -6)) + T(vox_bush(), (-5, 0, -4), r=(0, 30, 0), s=0.8))


def shroom_cluster():
    return (T(glow_shroom(0xD86AFF), s=1.3) + T(glow_shroom(0x6AE8FF), (7, 0, 3), s=0.75) + T(glow_shroom(0xFF6AD5), (-6, 0, 4), s=0.6)
            + T(glow_cluster(), (2, 0, -6)))


def pine_cluster():
    return T(vox_pine(), s=1.3) + T(vox_pine(), (6.5, 0, 3), s=0.95) + T(vox_pine(), (-5.5, 0, 4), s=0.8) + T(snow_rock(), (2, 0, -6), s=0.6)


def palm_cluster():
    return T(vox_palm(), s=1.15) + T(vox_palm(), (5, 0, 4), r=(0, 130, 0), s=0.85) + T(vox_bush(0x3E9A57, 0x4FB06A), (-4, 0, -2), s=0.8)


def crystal_field():
    return (float_crystal() + T(purple_crystal(0x6AF2FF, 0x4A9ACF), (6, 0, 3), s=0.9) + T(purple_crystal(), (-5, 0, 4), s=0.8)
            + T(moon_rock(), (1, 0, -6), s=0.6))


def flower_bed():
    p = [cube((9, 0.4, 7), (0, 0.2, 0), 0x5DBB46, "E")]
    cols = [0xFF6F9A, 0xFFD23A, 0xB07CFF, WHITE, 0xFF8A3C]
    for i in range(10):
        x, z = -3.5 + (i % 5) * 1.75, -2.2 + (i // 5) * 3.6 + (i % 2) * 0.6
        h = 1.0 + (i % 3) * 0.35
        c = cols[i % len(cols)]
        p += [cube((0.16, h, 0.16), (x, h / 2, z), 0x3E8F35), cube((0.8, 0.2, 0.8), (x, h, z), c, r=(0, 45, 0)),
              cube((0.3, 0.26, 0.3), (x, h + 0.05, z), 0xFFD23A if c != 0xFFD23A else 0xC0662A)]
    return p


# ---------------------------------------------------------------- taller landmarks (replace the earlier versions)
def _frustum(B, Tt, H, y0, col, mat):
    """Octagonal truncated pyramid: two cores 45 deg apart, each with four wedge slopes."""
    p = []
    run = B - Tt
    for rot45 in (0, 45):
        p.append(cube((2 * Tt, H, 2 * Tt), (0, y0 + H / 2, 0), col, mat, r=(0, rot45, 0)))
        for k in range(4):
            p += T([wedge((2 * Tt, H, run), (0, y0 + H / 2, -(Tt + run / 2)), col, mat)], r=(0, rot45 + 90 * k, 0))
    return p


def volcano():
    rock, dk = 0x4A3A36, 0x3A2E2C
    tiers = ((30, 20, 13), (20, 11, 15), (11, 6.5, 13))
    p = []
    y = 0.0
    for i, (B, Tt, H) in enumerate(tiers):
        p += _frustum(B, Tt, H, y, rock if i % 2 == 0 else dk, "B")
        # lava streams down two slopes
        for side in (0, 90):
            run = B - Tt
            p += T([wedge((3.6, H + 0.25, run + 0.25), (0, y + H / 2, -(Tt + run / 2) - 0.12), 0xFF6A1A, "N", tag="Glow")],
                   r=(0, side + (8 if i % 2 else -8), 0))
        y += H
    p += [cyl(12, 0.8, (0, y + 0.1, 0), 0xFF7A1A, "N", tag="Glow"), cyl(14.5, 1.6, (0, y + 0.3, 0), dk, "B"),
          cube((5, 4, 5), (0, y + 3.5, 0), 0xFFB02E, "N", t=0.35, tag="Glow")]
    for k, (dx, dz, s) in enumerate(((0, 0, 6), (2, 1, 5), (-1, -2, 4))):
        p.append(cube(s, (dx, y + 9 + k * 5, dz), 0x8A8480, "P", r=(0, 20 * k, 10), t=0.35))
    return p


def landmark_volcano():
    p = volcano()
    p += T(fire_crystal(), (26, 0, -6)) + T(fire_crystal(), (-26, 0, -4), r=(0, 60, 0)) + T(lava_rock(), (18, 0, 22), s=1.2)
    return p


def landmark_grove():
    return (T(glow_shroom(0xD86AFF, 1.0, 0xFFFFFF), s=3.6) + T(glow_shroom(0x6AE8FF), (14, 0, 6), s=2.2)
            + T(glow_shroom(0xFF6AD5), (-13, 0, 5), s=2.5) + T(glow_cluster(), (6, 0, -12), s=1.5))


def landmark_frost():
    p = []
    for x, z, w, h in ((0, 0, 30, 50), (-15, 6, 20, 32), (15, 4, 22, 36)):
        steps = 5
        for k in range(steps):
            f = 1 - k / steps
            col = 0x8FA3B8 if k < steps - 2 else WHITE
            p.append(cube((w * f, h / steps, w * f * 0.9), (x, h / steps * (k + 0.5), z), col, "T" if k < steps - 2 else "S", r=(0, 10 * k, 0)))
        p.append(cube((w * 0.22, 1.2, w * 0.2), (x, h + 0.6, z), WHITE, "S"))
    p += [cube((5, 30, 1.2), (2, 15, -13.6), 0xBFEAFF, "G", t=0.2), cube((9, 1.2, 6), (2, 0.6, -16), 0xDDF4FF, "I")]
    return p


def landmark_starfall():
    p = [cyl(26, 1.0, (0, 0.5, 0), 0x5B4B9E, "T"), cyl(22, 1.2, (0, 0.6, 0), 0x3B2E6E, "T")]
    cols = [0xFF6AD5, 0xB06CFF, 0x6AE8FF, 0xFF9AD5, 0x8E7CE0]
    for i, d in enumerate((18, 14.5, 11, 7.5, 4)):
        p.append(cyl(d, 1.25 + 0.06 * i, (0, 0.6, 0), cols[i], "N", tag="Glow"))
    for i in range(8):
        a = 2 * math.pi * i / 8
        p.append(cube((2.2, 3.0 + (i % 2) * 2, 2.2), (math.sin(a) * 12.5, 1.5 + (i % 2), -math.cos(a) * 12.5), 0x4A3C8A, "T", r=(0, math.degrees(a), 0)))
    p += crystal((-9, 0, 9), 3.2, 26, 0xB06CFF, "G", t=0.1) + crystal((10, 0, 9), 2.4, 18, 0x6AE8FF, "G", t=0.1)
    p += [ball(9, (8, 30, 6), 0xC9A8F0), cyl(16, 0.4, (8, 30, 6), 0xFFE66B, "N", r=(20, 0, 15), tag="Glow"), ball(4, (-10, 26, 2), 0xFF6AD5)]
    return p
