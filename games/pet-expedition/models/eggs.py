"""Eggs and their themed pedestals, after reference/eggs.jpg:
meadow (cream, green patches, daisies), grove (purple, pink spots, glowing
mushrooms), frost (icy blue, big snowflake, crystal spikes), coral (sand,
teal waves, shell, coral), volcano (dark rock with glowing cracks), star
(deep purple galaxy, coloured stars), prism (faceted rainbow crystal).
"""
import math
from lib import (ball, box, cyl, T, sym, tri, crystal, ell_point, rot, mmul, rx, ry, rz, face_rot, shade, RAINBOW, WHITE)

GOLD = 0xFFC93C
EC_UP, ER_UP = (0, 1.5, 0), (1.15, 1.5, 1.15)
EC_LO, ER_LO = (0, 1.2, 0), (1.15, 1.2, 1.15)


# ---------------------------------------------------------------- egg surface helpers
def egg_shape(col, mat="P"):
    return [ball((2.3, 3.0, 2.3), EC_UP, col, mat, tag="Body"), ball((2.3, 2.4, 2.3), EC_LO, col, mat, tag="Body")]


def egg_radius(y):
    a = 1 - ((y - 1.5) / 1.5) ** 2
    b = 1 - ((y - 1.2) / 1.2) ** 2
    return max(1.15 * math.sqrt(max(0, a)), 1.15 * math.sqrt(max(0, b)))


def egg_surface(yaw, pitch, inset=0.0):
    pu, nu = ell_point(EC_UP, ER_UP, yaw, pitch, inset)
    pl, nl = ell_point(EC_LO, ER_LO, yaw, pitch, inset)
    return (pu, nu) if pu[1] > 1.35 else (pl, nl)


def on_egg(parts, yaw, pitch, lift=0.0, spin=0.0):
    """Place a flat decoration (authored facing -Z around the origin) on the egg surface."""
    pos, n = egg_surface(yaw, pitch, inset=-lift)
    return T(parts, pos, R=mmul(rot(face_rot(n)), rz(spin)))


def patch(s, col, mat="P", depth=0.14, tag=None):
    return [ball((s, s * 0.85, depth), (0, 0, 0), col, mat, tag=tag)]


def band(y, h, col, mat="P", grow=0.06, tag=None):
    return cyl(2 * egg_radius(y) + grow, h, (0, y, 0), col, mat, tag=tag)


def daisy(s=1.0):
    p = [cyl(0.24 * s, 0.1, (0, 0, -0.06), 0xFFD23A, r=(90, 0, 0))]
    for i in range(5):
        a = 2 * math.pi * i / 5
        p.append(ball((0.22 * s, 0.34 * s, 0.08), (math.sin(a) * 0.22 * s, math.cos(a) * 0.22 * s, -0.02), WHITE,
                      r=(0, 0, -math.degrees(a))))
    return p


def star5(r, col, mat="P", th=0.14, tag=None):
    """Five-pointed star in the XY plane facing -Z."""
    p = [cyl(r * 0.95, th, (0, 0, 0), col, mat, r=(90, 0, 0), tag=tag)]
    for i in range(5):
        a = 72 * i
        p += T(tri((0, 0, 0), r * 0.75, r * 0.85, th, col, mat, tag=tag), (0, 0, 0), r=(0, 0, -a))
        p[-2:] = T(p[-2:], (math.sin(math.radians(a)) * r * 0.35, math.cos(math.radians(a)) * r * 0.35, 0))
    return p


def mushroom(cap, s=1.0):
    return T([box((0.32, 0.6, 0.32), (0, 0.3, 0), 0xF6EEDC), ball((1.0, 0.75, 1.0), (0, 0.7, 0), cap, "N", tag="Glow")], (0, 0, 0), s=s)


# ---------------------------------------------------------------- eggs
def meadow_egg():
    p = egg_shape(0xFFF4DC)
    for yaw, pitch, s in ((-35, 20, 1.0), (60, -5, 0.9), (150, 30, 0.9), (-130, -10, 1.0), (100, 55, 0.7), (-70, 60, 0.6), (20, -40, 0.8)):
        p += on_egg(patch(s, 0x7CC45A), yaw, pitch)
    for yaw, pitch, s in ((25, 25, 1.4), (-60, -15, 1.2), (85, 40, 1.0), (200, 10, 1.2)):
        p += on_egg(daisy(s), yaw, pitch, lift=0.02)
    return p


def grove_egg():
    p = egg_shape(0x9C78E0)
    for yaw, pitch, s in ((10, 10, 0.6), (-50, 35, 0.45), (120, -10, 0.55), (-140, 20, 0.5), (60, -35, 0.5), (200, 50, 0.4)):
        p += on_egg(patch(s, 0xF2A6E0), yaw, pitch)
    p += T(mushroom(0xFF6AD5, 1.9), (0, 2.8, 0))
    for yaw, pitch, cap in ((70, 15, 0x6AE8FF), (-75, 5, 0xB06CFF), (160, 25, 0x6AE8FF)):
        pos, n = egg_surface(yaw, pitch, inset=0.05)
        from lib import up_rot
        p += T(mushroom(cap, 1.2), pos, R=up_rot((n[0], n[1] + 1.0, n[2])))
    return p


def frost_egg():
    p = egg_shape(0x9ED8FF)
    flake = []
    for a in (0, 60, 120):
        flake.append(box((1.5, 0.14, 0.1), (0, 0, 0), WHITE, r=(0, 0, a)))
    for a in range(0, 360, 60):
        ar = math.radians(a)
        for sgn in (-1, 1):
            flake.append(box((0.32, 0.09, 0.1), (math.cos(ar) * 0.5 + math.cos(ar + sgn * 0.9) * 0.12,
                                                 math.sin(ar) * 0.5 + math.sin(ar + sgn * 0.9) * 0.12, 0), WHITE,
                             r=(0, 0, a + sgn * 50)))
    p += on_egg(flake[:3] + flake[3::2], 0, 12, lift=0.03)
    for yaw, pitch, h in ((0, 85, 0.9), (55, 50, 0.7), (-55, 45, 0.7), (130, 30, 0.6), (-130, 30, 0.6), (90, -20, 0.5),
                          (-90, -20, 0.5)):
        pos, n = egg_surface(yaw, pitch, inset=0.15)
        from lib import up_rot
        p += crystal(pos, 0.42, h * 1.5, 0xC8F0FF, "G", R=up_rot(n), t=0.1)
    return p


def coral_egg():
    p = egg_shape(0xF8E2C0)
    p.append(band(1.15, 0.36, 0x4FC8C8))
    p.append(band(2.05, 0.2, 0x7FDCD8))
    for i in range(9):
        a = 2 * math.pi * i / 9
        r = egg_radius(1.38)
        p.append(ball(0.22, (math.sin(a) * r, 1.38 + 0.08 * (i % 2), -math.cos(a) * r), 0x9FE8E6))
    shell = [ball((0.95, 0.75, 0.16), (0, 0, 0), 0xFFB8C0)]
    for k in range(5):
        a = -50 + k * 25
        shell.append(box((0.08, 0.7, 0.08), (math.sin(math.radians(a)) * 0.2, 0.05, -0.08), 0xF59AA8, r=(0, 0, -a)))
    p += on_egg(shell, 0, 5, lift=0.03)
    for yaw in (70, -75):
        pos, n = egg_surface(yaw, 30, inset=0.1)
        br = [box((0.18, 0.8, 0.18), (0, 0.4, 0), 0xFF7F7F), box((0.14, 0.45, 0.14), (0.18, 0.6, 0), 0xFF7F7F, r=(0, 0, -35)),
              box((0.14, 0.4, 0.14), (-0.16, 0.5, 0), 0xFF7F7F, r=(0, 0, 35))]
        from lib import up_rot
        p += T(br, pos, R=up_rot((n[0] * 0.6, n[1] + 1.2, n[2] * 0.6)))
    return p


def volcano_egg():
    p = egg_shape(0x4A3A3A, "B")
    lava = 0xFF7A1A
    # crack network: a ring of short glowing dashes around rock "plates"
    for pitch in (-35, 0, 32, 62):
        n = 6 if abs(pitch) < 40 else 4
        for i in range(n):
            yaw = 360 * i / n + pitch * 1.3
            pos, nn = egg_surface(yaw, pitch, inset=0.0)
            p.append(box((0.9 if abs(pitch) < 40 else 0.6, 0.12, 0.1), pos, lava, "N", R=mmul(rot(face_rot(nn)), rz(10 + (i % 2) * 20)), tag="Glow"))
            pos2, n2 = egg_surface(yaw + 180 / n, pitch + 16, inset=0.0)
            p.append(box((0.12, 0.7, 0.1), pos2, lava, "N", R=mmul(rot(face_rot(n2)), rz(15)), tag="Glow"))
    p.append(band(0.25, 0.18, lava, "N", grow=0.08, tag="Glow"))
    return p


def star_egg():
    p = egg_shape(0x3A2A8A)
    for yaw, pitch, s in ((-40, 20, 1.2), (190, 30, 1.0)):
        p += on_egg(patch(s, 0x6A3AB0), yaw, pitch)
    for yaw, pitch, r, c in ((-25, 35, 0.42, 0xFFE27A), (40, 0, 0.45, 0xFF7FD8), (-70, -15, 0.32, 0x5AB8FF)):
        p += on_egg(star5(r, c), yaw, pitch, lift=0.05)
    for yaw, pitch in ((10, 60), (80, 30), (-120, 45), (120, -20), (160, 10), (-160, -30), (60, -40)):
        p.append(ball(0.18, egg_surface(yaw, pitch, inset=-0.02)[0], 0xF6E8FF, "N"))
    return p


def prism_egg():
    """A faceted crystal egg: octagonal prism (two boxes 45 deg apart) with
    pointed ends (cubes stood on a vertex), pastel glass, glowing core."""
    cols = [0xFFB3D9, 0xC9B3FF, 0xB3E6FF, 0xB3FFD9, 0xFFF0B3, 0xFFC9A8]
    vtx = mmul(rx(-35.264), rz(45))
    p = [box((1.9, 1.7, 1.9), (0, 1.55, 0), cols[0], "G", t=0.12, tag="Body"),
         box((1.9, 1.7, 1.9), (0, 1.55, 0), cols[2], "G", r=(0, 45, 0), t=0.12, tag="Body"),
         box((1.6, 1.6, 1.6), (0, 2.45, 0), cols[3], "G", R=mmul(ry(22.5), vtx), t=0.12),
         box((1.6, 1.6, 1.6), (0, 0.7, 0), cols[1], "G", R=mmul(ry(22.5), vtx), t=0.12),
         box((1.0, 1.9, 1.0), (0, 1.6, 0), 0xFFFFFF, "N", r=(0, 22, 0), t=0.4, tag="Glow")]
    for i, c in enumerate(cols):
        a = 2 * math.pi * i / 6
        p += crystal((math.sin(a) * 1.05, 0.0, -math.cos(a) * 1.05), 0.45, 1.1 + 0.4 * (i % 2), c, "G",
                     r=(math.cos(a) * 25, 0, math.sin(a) * 25), t=0.1)
    return p


EGGS = {"MeadowEgg": meadow_egg, "GroveEgg": grove_egg, "FrostEgg": frost_egg, "CoralEgg": coral_egg,
        "VolcanoEgg": volcano_egg, "StarEgg": star_egg, "PrismEgg": prism_egg}


# ---------------------------------------------------------------- pedestals
def _drum(base, mid, rim, mat="P", h=1.6, d=4.4):
    """Stepped round pedestal: base plate, drum, top rim. Returns (parts, top_y)."""
    p = [cyl(d + 1.6, 0.6, (0, 0.3, 0), base, mat), cyl(d, h, (0, 0.6 + h / 2, 0), mid, mat),
         cyl(d + 0.5, 0.5, (0, 0.6 + h + 0.25, 0), rim, mat)]
    return p, 0.6 + h + 0.5


def _sign(p, z, board, post, mat="W"):
    p += [box((0.4, 2.2, 0.4), (-2.3, 1.1, z), post, mat), box((0.4, 2.2, 0.4), (2.3, 1.1, z), post, mat),
          box((5.6, 1.8, 0.4), (0, 2.6, z), board, mat), box((5.2, 1.5, 0.1), (0, 2.6, z - 0.25), 0xFFFFFF, tag="SignFace", t=1.0)]
    p.append(box((1, 1, 1), (0, 3, z + 1.2), 0xFFFFFF, tag="Prompt", t=1.0))


def _around(n, r, y, fn):
    out = []
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        out += T(fn(i), (math.sin(a) * r, y, -math.cos(a) * r), r=(0, -math.degrees(a), 0))
    return out


def stand_meadow():
    """Hub egg stand: gold star pedestal on stone steps with bunting (reference/hub.jpg)."""
    p = [box((8.4, 0.6, 8.4), (0, 0.3, 0), 0xC9C2B4, "U"), box((7.0, 0.6, 7.0), (0, 0.9, 0), 0xDAD4C8, "U")]
    d, h = 5.0, 1.6
    p += [cyl(d, h, (0, 1.2 + h / 2, 0), GOLD, "F"), cyl(d + 0.5, 0.45, (0, 1.2 + h + 0.2, 0), 0xFFDF6A, "F"),
          cyl(d * 0.75, 0.3, (0, 1.2 + h + 0.55, 0), 0xFFF0B0, "F")]
    top = 1.2 + h + 0.7
    p += _around(6, d / 2 + 0.05, 1.2 + h / 2, lambda i: [box((0.5, 0.5, 0.12), (0, 0, -0.04), 0xFFF3A0, "N", r=(0, 0, 45), tag="Glow")])
    p.append(box((0.5, 0.5, 0.5), (0, top, 0), 0xFFFFFF, tag="EggSpot", t=1.0))
    # bunting between two posts behind the egg
    for x in (-4.4, 4.4):
        p += [box((0.5, 7.5, 0.5), (x, 3.75, 3.6), 0x8A5A36, "W"), box((0.8, 0.8, 0.8), (x, 7.7, 3.6), 0xFFE27A, "N", tag="Glow")]
    p.append(box((8.8, 0.12, 0.12), (0, 6.8, 3.6), WHITE))
    for i, c in enumerate((0xFF6F9A, 0xFFD23A, 0x5AB8FF, 0x7CD35A, 0xB07CFF)):
        p += T(tri((0, 0, 0), 1.1, 1.2, 0.08, c), (-3.2 + i * 1.6, 6.75, 3.55), r=(0, 0, 180))
    _sign(p, -5.2, 0xA0703F, 0x7E5230)
    return p


def stand_grove():
    p, top = _drum(0x6A4AB0, 0x8A6AD8, 0xA88AF0)
    p += _around(5, 2.5, 0.6, lambda i: mushroom([0xFF6AD5, 0x6AE8FF][i % 2], 1.1))
    p += _around(6, 2.22, 1.4, lambda i: [ball((0.7, 0.55, 0.12), (0, 0, 0), 0xF2A6E0)])
    p.append(box((0.5, 0.5, 0.5), (0, top, 0), 0xFFFFFF, tag="EggSpot", t=1.0))
    _sign(p, -5.0, 0x7A5468, 0x4A3040)
    return p


def stand_frost():
    p, top = _drum(0xA8DCF8, 0xD8F0FF, 0xBFE6FF, "P")
    p += _around(8, 2.35, 0.6, lambda i: crystal((0, 0, 0), 0.5, 1.6 + 0.5 * (i % 2), 0x9FE0FF, "G", r=(-10, 0, 0), t=0.1))
    p.append(box((0.5, 0.5, 0.5), (0, top, 0), 0xFFFFFF, tag="EggSpot", t=1.0))
    _sign(p, -5.0, 0x7AA9D6, 0x5A88B8)
    return p


def stand_coral():
    p, top = _drum(0x4FC8C8, 0xF8E2C0, 0xF0D2A8)
    p.append(cyl(4.48, 0.4, (0, 1.4, 0), 0x7FDCD8))
    p += _around(4, 2.45, 0.6, lambda i: [box((0.26, 1.4, 0.26), (0, 0.7, 0), 0xFF7F7F), box((0.2, 0.7, 0.2), (0.3, 0.95, 0), 0xFF7F7F, r=(0, 0, -35)),
                                         box((0.2, 0.6, 0.2), (-0.26, 0.85, 0), 0xFF7F7F, r=(0, 0, 35))])
    p += _around(6, 2.25, 1.9, lambda i: [ball(0.3, (0, 0, 0), 0xBFF0EE)])
    p.append(box((0.5, 0.5, 0.5), (0, top, 0), 0xFFFFFF, tag="EggSpot", t=1.0))
    _sign(p, -5.0, 0xCFAE84, 0x8C6E52)
    return p


def stand_volcano():
    p = []
    for i in range(8):
        a = 360 * i / 8
        p += T([box((2.4, 0.8, 1.6), (0, 0.4, -2.5), 0x3A3034, "B")], r=(0, a, 0))
    p += [cyl(4.4, 1.6, (0, 1.6, 0), 0x4A3E3E, "B"), cyl(4.9, 0.5, (0, 2.65, 0), 0x2E2626, "B")]
    top = 2.9
    p += _around(6, 2.22, 1.6, lambda i: [box((1.0, 0.14, 0.1), (0, 0, 0), 0xFF7A1A, "N", r=(0, 0, 20 if i % 2 else -20), tag="Glow")])
    p.append(cyl(5.0, 0.12, (0, 0.85, 0), 0xFF7A1A, "N", tag="Glow"))
    p.append(box((0.5, 0.5, 0.5), (0, top, 0), 0xFFFFFF, tag="EggSpot", t=1.0))
    _sign(p, -5.4, 0x2E262A, 0x1A1518, "B")
    return p


def stand_starfall():
    p, top = _drum(0x2A2070, 0x3A2A8A, 0x4A3AA8)
    cols = [0xFFE27A, 0xFF7FD8, 0x5AB8FF]
    p += _around(5, 2.25, 1.4, lambda i: star5(0.4, cols[i % 3], "N", th=0.1, tag="Glow"))
    p.append(box((0.5, 0.5, 0.5), (0, top, 0), 0xFFFFFF, tag="EggSpot", t=1.0))
    _sign(p, -5.0, 0x4A3C8A, 0x2A2058, "T")
    return p


def stand_prism():
    p, top = _drum(0xE8E0FF, 0xFBF8FF, 0xF0EAFF)
    cols = [0xFFB3D9, 0xC9B3FF, 0xB3E6FF, 0xB3FFD9, 0xFFF0B3, 0xFFC9A8]
    p += _around(6, 2.45, 0.6, lambda i: crystal((0, 0, 0), 0.55, 1.9 + 0.5 * (i % 2), cols[i], "G", r=(-12, 0, 0), t=0.1))
    p.append(box((0.5, 0.5, 0.5), (0, top, 0), 0xFFFFFF, tag="EggSpot", t=1.0))
    _sign(p, -5.2, 0xC79BFF, 0xA07AE0, "P")
    return p


STANDS = {"Meadow": stand_meadow, "Grove": stand_grove, "Frost": stand_frost, "Coral": stand_coral,
          "Volcano": stand_volcano, "Starfall": stand_starfall}
