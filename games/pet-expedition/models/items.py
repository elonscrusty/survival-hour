"""Eggs, breakables (themed per island) and world props (decorations and the
bodies of interactables: egg stands, gates, the expedition board, craft
machine, rebirth statue, index book, signs).

Special part tags used by Models/World.luau:
  EggSpot   where the egg model sits on an egg stand (invisible)
  Prompt    invisible part that holds the ProximityPrompt
  SignFace  part whose front face gets a SurfaceGui with text
  Barrier   gate wall the client hides once the area is opened
  Glow      neon accent (PointLight may be added at runtime)
"""
import math
import random
from lib import (ball, box, cyl, wedge, T, sym, mirror, cone, spike, tri, chain, ring, crystal, on_surface, ell_point,
                 rot, mmul, rx, ry, rz, face_rot, up_rot, shade, mix, hsv, add, mul, norm, RAINBOW, WHITE, EYE)
import pets as PETS

EGG_STAND_SCALE = 1.35
GOLD, GOLD_DK = 0xFFC93C, 0xD99A1E


# ======================================================================= eggs
EC_UP, ER_UP = (0, 1.5, 0), (1.15, 1.5, 1.15)
EC_LO, ER_LO = (0, 1.2, 0), (1.15, 1.2, 1.15)


def egg_shape(col, mat="P"):
    return [ball((2.3, 3.0, 2.3), EC_UP, col, mat, tag="Body"), ball((2.3, 2.4, 2.3), EC_LO, col, mat, tag="Body")]


def egg_radius(y):
    a = 1 - ((y - 1.5) / 1.5) ** 2
    b = 1 - ((y - 1.2) / 1.2) ** 2
    return max(1.15 * math.sqrt(max(0, a)), 1.15 * math.sqrt(max(0, b)))


def egg_surface(yaw, pitch, inset=0.0):
    """Point + normal on the egg surface (uses whichever ellipsoid is outermost)."""
    pu, nu = ell_point(EC_UP, ER_UP, yaw, pitch, inset)
    pl, nl = ell_point(EC_LO, ER_LO, yaw, pitch, inset)
    du = (pu[0] ** 2 + pu[2] ** 2)
    dl = (pl[0] ** 2 + pl[2] ** 2)
    # pick the point farther from the vertical axis at similar height
    return (pu, nu) if pu[1] > 1.3 or du >= dl else (pl, nl)


def egg_spot(yaw, pitch, s, col, mat="P", depth=0.12, spin=0, tag=None):
    pos, n = egg_surface(yaw, pitch, inset=depth * 0.25)
    return ball((s, s, depth), pos, col, mat, R=mmul(rot(face_rot(n)), rz(spin)), tag=tag)


def egg_dash(yaw, pitch, L, col, mat="N", spin=0, w=0.1, tag=None):
    pos, n = egg_surface(yaw, pitch, inset=0.0)
    return box((L, w, 0.08), pos, col, mat, R=mmul(rot(face_rot(n)), rz(spin)), tag=tag)


def band(y, h, col, mat="P", grow=0.06, tag=None):
    return cyl(2 * egg_radius(y) + grow, h, (0, y, 0), col, mat, tag=tag)


def meadow_egg():
    p = egg_shape(0xFFF6DC)
    cols = [0x8ED16A, 0xFFD84A, 0xFF9EBB]
    rnd = random.Random(3)
    for i, (yaw, pitch) in enumerate(((0, 20), (70, 45), (-80, 30), (150, 10), (-150, 50), (35, -20), (-35, 60),
                                      (110, -15), (-115, -10), (190, 35), (0, 80))):
        p.append(egg_spot(yaw, pitch, 0.42 + rnd.random() * 0.25, cols[i % 3]))
    p.append(band(0.32, 0.26, 0x6CC24A, grow=0.05))
    return p


def grove_egg():
    p = egg_shape(0x7E5BC4)
    for y, c in ((0.75, 0x4FE0C8), (1.45, 0x4FE0C8), (2.15, 0x4FE0C8)):
        p.append(band(y, 0.24, c))
    for y, c in ((1.1, 0xFFD45A), (1.8, 0xFFD45A)):
        p.append(band(y, 0.08, c))
    for yaw in (0, 90, 180, 270):
        p.append(egg_spot(yaw + 45, 22, 0.24, 0xB6FFF2, "N", tag="Glow"))
    p.append(ball((0.95, 0.42, 0.95), (0, 2.88, 0), 0xE0393E))
    p += [ball((0.18, 0.08, 0.18), (0.22, 3.06, -0.1), WHITE), ball((0.14, 0.08, 0.14), (-0.2, 3.04, 0.15), WHITE)]
    return p


def frost_egg():
    p = egg_shape(0xBFE8FF, "P")
    p.append(ball((1.9, 1.0, 1.9), (0, 2.62, 0), 0xFFFFFF, "S"))
    for yaw in range(0, 360, 45):
        a = math.radians(yaw)
        y = 2.25 - (0.25 if yaw % 90 else 0.05)
        r = egg_radius(y)
        p.append(ball((0.34, 0.6, 0.34), (math.sin(a) * r * 0.95, y, -math.cos(a) * r * 0.95), 0xFFFFFF, "S"))
    for yaw, pitch in ((20, 10), (-60, 25), (120, 5), (200, 20)):
        p.append(egg_dash(yaw, pitch, 0.5, 0xFFFFFF, "N", spin=0))
        p.append(egg_dash(yaw, pitch, 0.5, 0xFFFFFF, "N", spin=60))
        p.append(egg_dash(yaw, pitch, 0.5, 0xFFFFFF, "N", spin=120))
    p += crystal((0.1, 2.75, 0), 0.36, 0.8, 0x9FE0FF, "G", r=(0, 0, -12), t=0.1)
    p += crystal((-0.35, 2.7, 0.15), 0.26, 0.55, 0xD8F6FF, "G", r=(0, 0, 28), t=0.1)
    p.append(band(0.3, 0.22, 0x9FE0FF, "P"))
    return p


def coral_egg():
    p = egg_shape(0xFFCBA8)
    p.append(band(1.25, 0.34, 0x4FC8E0))
    for i in range(12):
        a = 2 * math.pi * i / 12
        r = egg_radius(1.45)
        p.append(ball(0.26, (math.sin(a) * r, 1.45, -math.cos(a) * r), 0x4FC8E0))
    for yaw, pitch, c in ((30, 40, 0xFF7F8E), (-50, 55, 0xFFE0A0), (150, 45, 0xFF7F8E), (-140, 30, 0xFFE0A0)):
        p.append(egg_spot(yaw, pitch, 0.38, c))
    # coral branches at the base
    for x, z, h, c, a in ((0.95, -0.35, 1.3, 0xFF6F7F, -15), (1.1, 0.1, 0.9, 0xC77CFF, -35), (0.75, -0.75, 0.8, 0xFF9A6F, 10)):
        top = (x + math.sin(math.radians(-a)) * h, h, z)
        p += [cyl(0.22, h, (x + math.sin(math.radians(-a)) * h / 2, h / 2, z), c, r=(0, 0, a)), ball(0.32, top, c)]
    p += [ball((0.55, 0.35, 0.42), (-0.55, 0.2, -1.05), 0xFFF0E0), ball(0.16, (0.6, 2.75, -0.55), 0xDFF8FF, "G", t=0.3),
          ball(0.12, (0.75, 3.0, -0.4), 0xDFF8FF, "G", t=0.3)]
    return p


def volcano_egg():
    p = egg_shape(0x2B2326, "B")
    lava = 0xFF6A1A
    cracks = [((0, 20), 0.7, 60), ((10, 34), 0.55, -40), ((-8, 5), 0.6, 110), ((80, 40), 0.75, 70), ((90, 22), 0.5, -30),
              ((180, 30), 0.8, 50), ((170, 10), 0.5, 140), ((-90, 35), 0.7, -60), ((-100, 15), 0.55, 30), ((-140, 55), 0.6, 0),
              ((40, 62), 0.55, 20), ((130, -10), 0.6, 80)]
    for (yaw, pitch), L, spin in cracks:
        p.append(egg_dash(yaw, pitch, L, lava, "N", spin=spin, w=0.11, tag="Glow"))
    p.append(band(0.18, 0.2, lava, "N", grow=0.08, tag="Glow"))
    p.append(ball((0.6, 0.26, 0.6), (0, 2.98, 0), 0xFFB03A, "N", tag="Glow"))
    return p


def star_egg():
    p = egg_shape(0x1D2560)
    star = 0xFFE66B
    for yaw, pitch, s in ((10, 25, 0.55), (100, 45, 0.45), (-80, 15, 0.5), (190, 30, 0.5), (-160, 60, 0.4)):
        p.append(egg_dash(yaw, pitch, s, star, "N", spin=0, w=0.12, tag="Glow"))
        p.append(egg_dash(yaw, pitch, s, star, "N", spin=90, w=0.12, tag="Glow"))
    for yaw, pitch in ((50, 10), (-30, 50), (150, -5), (-120, 30), (60, 70), (230, 10)):
        p.append(egg_spot(yaw, pitch, 0.16, 0xFFFFFF, "N"))
    p.append(cyl(3.3, 0.08, (0, 1.35, 0), GOLD, "N", r=(18, 0, 12), tag="Glow"))
    p.append(cyl(2.9, 0.1, (0, 1.35, 0), 0xC79BFF, "P", r=(18, 0, 12)))
    return p


def prism_egg():
    p = egg_shape(0xFBF8FF, "P")
    for i, c in enumerate(RAINBOW):
        p.append(band(0.75 + i * 0.27, 0.2, c, "P"))
    p += crystal((0, 2.75, 0), 0.5, 1.0, 0xE8FBFF, "G", t=0.1)
    p += crystal((0.35, 2.6, 0.2), 0.3, 0.6, 0xFFD6F5, "G", r=(0, 0, -30), t=0.1)
    p += crystal((-0.35, 2.6, -0.1), 0.3, 0.6, 0xD6F0FF, "G", r=(0, 0, 30), t=0.1)
    for yaw, pitch in ((30, 50), (-60, 45), (160, 55)):
        p.append(egg_spot(yaw, pitch, 0.18, 0xFFFFFF, "N"))
    return p


EGGS = {"MeadowEgg": meadow_egg, "GroveEgg": grove_egg, "FrostEgg": frost_egg, "CoralEgg": coral_egg,
        "VolcanoEgg": volcano_egg, "StarEgg": star_egg, "PrismEgg": prism_egg}


# ======================================================================= themes
THEMES = {
    "Meadow": dict(wood=0xC08A52, wood_dk=0x7E5230, wood_mat="K", metal=0xD9A640, metal_mat="M", rock=0x9A9A8E,
                   rock_mat="R", base=0xE6C35C, base_mat="X", gems=(0x5CFF8F, 0xFF6FB5), accent=0xFF8FB8, leaf=0x6CC24A),
    "Grove": dict(wood=0x7A5468, wood_dk=0x4A3040, wood_mat="W", metal=0x6FD6C0, metal_mat="M", rock=0x5C6B4F,
                  rock_mat="T", base=0x4C7A3A, base_mat="E", gems=(0x4CF2E8, 0xB57CFF), accent=0xE0393E, leaf=0x3F8A4E),
    "Frost": dict(wood=0xBFE6FF, wood_dk=0x7AA9D6, wood_mat="I", metal=0xDDE6F0, metal_mat="M", rock=0x8FA3B8,
                  rock_mat="T", base=0xF5F9FF, base_mat="S", gems=(0x7FD9FF, 0xE6F8FF), accent=0xFFFFFF, leaf=0x2F6E5A),
    "Coral": dict(wood=0xCFAE84, wood_dk=0x8C6E52, wood_mat="W", metal=0x4FC2B5, metal_mat="M", rock=0xE8A08F,
                  rock_mat="V", base=0xF2DBA0, base_mat="A", gems=(0xFFF0F5, 0x4FD8FF), accent=0xFF7F6E, leaf=0x4FB06A),
    "Volcano": dict(wood=0x2E262A, wood_dk=0x1A1518, wood_mat="B", metal=0x6E5E5A, metal_mat="M", rock=0x3A3034,
                    rock_mat="B", base=0x2C2427, base_mat="B", gems=(0xFF3B2F, 0xFFB02E), accent=0xFF6A1A, leaf=0x5A4A44),
    "Starfall": dict(wood=0x4A3C8A, wood_dk=0x2A2058, wood_mat="T", metal=0xE8D8FF, metal_mat="M", rock=0x4A3C7A,
                     rock_mat="T", base=0x2E2558, base_mat="T", gems=(0xB06CFF, 0x6AF2FF), accent=0xFFE66B, leaf=0x8E7CE0),
}


def coin(pos, r=(0, 0, 0), d=0.9):
    return [cyl(d, 0.16, pos, GOLD, "F", r=r), cyl(d * 0.62, 0.18, pos, 0xFFE27A, "F", r=r)]


def theme_deco(area, th, at, s=1.0):
    """A tiny themed accent placed on breakables."""
    if area == "Meadow":
        out = [cyl(0.08, 0.6, (0, 0.3, 0), 0x4FA83A)]
        for i in range(5):
            a = 2 * math.pi * i / 5
            out.append(ball((0.3, 0.1, 0.3), (math.sin(a) * 0.17, 0.62, -math.cos(a) * 0.17), th["accent"]))
        out.append(ball(0.16, (0, 0.64, 0), 0xFFD84A))
    elif area == "Grove":
        out = [cyl(0.2, 0.45, (0, 0.22, 0), 0xF6EEDC), ball((0.62, 0.36, 0.62), (0, 0.5, 0), 0xE0393E),
               ball((0.12, 0.05, 0.12), (0.15, 0.66, -0.05), WHITE)]
    elif area == "Frost":
        out = [ball((0.9, 0.35, 0.9), (0, 0.12, 0), 0xFFFFFF, "S")] + crystal((0.1, 0.05, 0), 0.22, 0.6, 0x9FE0FF, "G", t=0.15)
    elif area == "Coral":
        out = [cyl(0.14, 0.6, (0, 0.3, 0), 0xFF6F7F), ball(0.22, (0, 0.62, 0), 0xFF6F7F), cyl(0.1, 0.35, (0.14, 0.36, 0), 0xFF6F7F, r=(0, 0, -35)),
               ball((0.5, 0.18, 0.4), (0.3, 0.09, 0.25), 0xFFF0E0)]
    elif area == "Volcano":
        out = [ball((0.6, 0.35, 0.55), (0, 0.15, 0), 0x2A2228, "B"), box((0.5, 0.06, 0.06), (0, 0.3, -0.24), 0xFF6A1A, "N", r=(0, 0, 30), tag="Glow")]
    else:
        out = [box((0.32, 0.32, 0.32), (0, 0.5, 0), th["accent"], "N", R=mmul(rx(-35.264), rz(45)), tag="Glow"),
               ball(0.14, (0.3, 0.2, 0.1), 0x6AF2FF, "N")]
    return T(out, at, s=s)


# ======================================================================= breakables
def coin_pile(area, th):
    p = []
    # themed base
    if area == "Meadow":
        p.append(ball((3.0, 0.7, 2.8), (0, 0.25, 0), th["base"], "X"))
    elif area == "Frost":
        p.append(ball((3.0, 0.7, 2.8), (0, 0.25, 0), 0xFFFFFF, "S"))
    elif area == "Volcano":
        p += [ball((3.0, 0.6, 2.8), (0, 0.22, 0), th["base"], "B"), cyl(3.1, 0.12, (0, 0.06, 0), 0xFF6A1A, "N", tag="Glow")]
    else:
        p.append(ball((3.0, 0.6, 2.8), (0, 0.22, 0), th["base"], th["base_mat"]))
    p.append(ball((2.4, 1.2, 2.2), (0, 0.6, 0), GOLD, "F", tag="Body"))
    rnd = random.Random(hash(area) & 0xFFFF)
    for x, z, n in ((-0.65, -0.35, 3), (0.55, 0.3, 4), (0.15, -0.55, 2)):
        for i in range(n):
            p += coin((x + rnd.uniform(-0.04, 0.04), 0.95 + i * 0.17, z), r=(0, 0, 0), d=0.82)
    for pos, r in (((0.9, 0.72, -0.55), (60, 20, 0)), ((-0.8, 0.85, 0.6), (-40, 0, 30)), ((0.0, 1.32, 0.1), (20, 0, -15)),
                   ((0.0, 0.85, -1.05), (75, 0, 0))):
        p += coin(pos, r=r, d=0.9)
    p += theme_deco(area, th, (1.05, 0.25, 0.75), 0.9)
    return p


def crate(area, th):
    w = 3.4
    wood, dk, m = th["wood"], th["wood_dk"], th["wood_mat"]
    tr = 0.15 if area == "Frost" else 0.0
    p = [box((w, w, w), (0, w / 2, 0), wood, m, tag="Body", t=tr)]
    if area == "Frost":
        p.append(box((w * 0.6, w * 0.6, w * 0.6), (0, w / 2, 0), GOLD, "F"))
    for y in (0.22, w - 0.2):
        p.append(box((w + 0.12, 0.44, w + 0.12), (0, y, 0), dk, m))
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.append(box((0.44, w + 0.06, 0.44), (sx * (w / 2 - 0.1), w / 2 + 0.01, sz * (w / 2 - 0.1)), dk, m))
    # diagonal brace on front and back
    L = math.hypot(w - 0.8, w - 0.8)
    for z in (-w / 2 - 0.05, w / 2 + 0.05):
        p.append(box((L, 0.36, 0.12), (0, w / 2, z), dk, m, r=(0, 0, 45)))
    if area == "Frost":
        p.append(ball((w + 0.3, 0.6, w + 0.3), (0, w + 0.05, 0), 0xFFFFFF, "S"))
    elif area == "Volcano":
        p += [box((0.08, 1.4, 0.08), (0.6, w / 2 + 0.2, -w / 2 - 0.08), 0xFF6A1A, "N", r=(0, 0, 25), tag="Glow"),
              box((0.08, 1.0, 0.08), (-0.7, w / 2 - 0.5, -w / 2 - 0.08), 0xFF6A1A, "N", r=(0, 0, -35), tag="Glow")]
    elif area == "Starfall":
        p += [box((0.14, 0.14, w + 0.16), (sx * (w / 2), w + 0.02, 0), th["gems"][1], "N", tag="Glow") for sx in (-1, 1)]
    p += theme_deco(area, th, (0.6, w, 0.4), 1.2)
    if area in ("Meadow", "Coral"):
        p += theme_deco(area, th, (-0.7, w, -0.5), 0.9)
    return p


def chest(area, th, big=False):
    s = 1.6 if big else 1.0
    wood, dk, m = th["wood"], th["wood_dk"], th["wood_mat"]
    metal = GOLD if big else th["metal"]
    mm = "F" if big else th["metal_mat"]
    W, H, D = 4.6, 2.2, 3.0
    p = [box((W, H, D), (0, H / 2, 0), wood, m, tag="Body"),
         box((W + 0.08, 0.72, D + 0.08), (0, H + 0.36, 0), shade(wood, 1.04), m),
         cyl(D + 0.08, W + 0.04, (0, H + 0.72, 0), shade(wood, 1.08), m, r=(0, 0, 90))]
    # metal bands and rim
    for x in (-W / 2 + 0.6, W / 2 - 0.6):
        p.append(box((0.34, H + 0.75, D + 0.2), (x, (H + 0.75) / 2, 0), metal, mm))
        p.append(cyl(D + 0.2, 0.34, (x, H + 0.72, 0), metal, mm, r=(0, 0, 90)))
    p.append(box((W + 0.18, 0.18, D + 0.18), (0, H, 0), metal, mm))
    p.append(box((W + 0.14, 0.2, D + 0.14), (0, 0.1, 0), dk, m))
    # lock
    p += [box((0.72, 0.85, 0.2), (0, H + 0.1, -D / 2 - 0.1), GOLD, "F"), box((0.14, 0.3, 0.06), (0, H + 0.05, -D / 2 - 0.22), 0x2A1E1A)]
    if big:
        # crown of gems and coins spilling out
        g1, g2 = th["gems"]
        p += crystal((0, H + 1.9, 0), 0.6, 1.3, g1, "G", t=0.1)
        p += crystal((0.9, H + 1.6, 0.2), 0.45, 0.9, g2, "G", r=(0, 0, -25), t=0.1)
        p += crystal((-0.9, H + 1.6, -0.1), 0.45, 0.9, g2, "G", r=(0, 0, 25), t=0.1)
        p += sym([cyl(0.7, 0.2, (W / 2 + 0.08, H * 0.6, 0), metal, mm, r=(0, 0, 90))])
        for pos, r in (((1.4, 0.1, -1.9), (0, 0, 0)), ((1.7, 0.25, -1.75), (20, 0, 10)), ((-1.5, 0.1, -1.85), (0, 0, 0)),
                       ((-1.2, 0.28, -2.0), (-25, 0, 0)), ((0.6, 0.1, -2.1), (0, 0, 0))):
            p += coin(pos, r=r, d=0.75)
        p.append(ball((3.6, 0.5, 1.2), (0, 0.2, -2.0), GOLD, "F"))
    else:
        p += theme_deco(area, th, (1.6, H + 1.35, 0.3), 1.0)
    out = T(p, (0, 0, 0), s=s)
    if big:
        out = T(out, (0, 0, 0), s=8 / (W * s) * 1.0)
    return out


def gem_rock(area, th):
    g1, g2 = th["gems"]
    rock, rm = th["rock"], th["rock_mat"]
    p = [ball((3.4, 1.6, 3.0), (0, 0.65, 0), rock, rm, tag="Body"), ball((2.0, 1.5, 1.8), (-0.6, 1.1, 0.4), shade(rock, 0.9), rm, r=(0, 30, 10)),
         ball((1.6, 1.1, 1.5), (0.9, 0.8, 0.5), shade(rock, 1.1), rm, r=(0, -20, -10))]
    p += crystal((0, 0.7, -0.1), 0.75, 2.6, g1, "G", r=(-8, 0, 6), t=0.1)
    p += crystal((0.9, 0.6, -0.4), 0.5, 1.7, g2, "G", r=(-10, 0, -28), t=0.1)
    p += crystal((-1.0, 0.6, -0.3), 0.5, 1.6, g1, "G", r=(-5, 0, 30), t=0.1)
    p += crystal((0.3, 0.8, 0.8), 0.45, 1.3, g2, "G", r=(25, 0, -10), t=0.1)
    p += crystal((-0.5, 0.4, -1.1), 0.36, 0.9, g2, "N", r=(-30, 0, 15), tag="Glow")
    if area == "Frost":
        p.append(ball((2.2, 0.5, 1.8), (-0.6, 1.75, 0.4), 0xFFFFFF, "S"))
    elif area == "Grove":
        p.append(ball((1.8, 0.35, 1.5), (-0.5, 1.75, 0.5), 0x5FA84A, "E"))
    elif area == "Volcano":
        p.append(box((1.6, 0.08, 0.08), (0.2, 0.7, -1.4), 0xFF6A1A, "N", r=(0, 10, 15), tag="Glow"))
    elif area == "Coral":
        p += [ball(0.4, (1.4, 0.45, -0.6), 0xFFF8F0, "P"), ball(0.3, (-1.4, 0.35, 0.4), 0xFFF8F0, "P")]
    return p


def breakable(kind, area):
    th = THEMES.get(area, THEMES["Meadow"])
    if kind == "CoinPile":
        return coin_pile(area, th)
    if kind == "Crate":
        return T(crate(area, th), s=4 / 3.6)
    if kind == "Chest":
        return T(chest(area, th), s=5 / 4.7)
    if kind == "GemRock":
        return T(gem_rock(area, th), s=4 / 3.4)
    if kind == "BigChest":
        return chest(area, th, big=True)
    raise ValueError(kind)


# ======================================================================= props (decorations)
def tree_round(leaf=0x5DBB46, leaf2=0x7ED35A, trunk=0x8A5A36):
    p = [cyl(1.6, 8, (0, 4, 0), trunk, "W"), cyl(2.4, 1.0, (0, 0.5, 0), shade(trunk, 0.9), "W")]
    for pos, s, c in (((0, 10, 0), 8.5, leaf), ((2.6, 8.4, 1.0), 5.5, leaf2), ((-2.4, 8.8, -0.6), 5.8, leaf2),
                      ((0.6, 12.6, -0.4), 5.2, leaf2), ((-0.6, 8.0, 2.4), 4.8, leaf)):
        p.append(ball(s, pos, c, "P"))
    p += [ball(0.9, (2.4, 7.4, -2.0), 0xFF5A5A), ball(0.9, (-1.8, 9.0, -3.2), 0xFF5A5A), ball(0.9, (3.6, 10.0, -0.6), 0xFF5A5A)]
    return p


def bush(c=0x4FA83A, c2=0x6CC24A, berries=0xFF6F9A):
    p = [ball((4.2, 3.0, 3.6), (0, 1.3, 0), c), ball((2.8, 2.4, 2.6), (1.4, 1.1, 0.6), c2), ball((2.6, 2.2, 2.4), (-1.5, 1.0, -0.4), c2)]
    if berries:
        p += [ball(0.5, (0.6, 2.6, -1.2), berries), ball(0.5, (-0.9, 2.2, -1.4), berries), ball(0.5, (1.8, 1.8, -0.6), berries)]
    return p


def flower_patch(cols=(0xFF6F9A, 0xFFD84A, 0xA77BFF, 0xFFFFFF)):
    p = [ball((4.0, 0.5, 3.4), (0, 0.1, 0), 0x5DBB46, "E")]
    for i, (x, z) in enumerate(((-1.0, -0.6), (0.8, -0.8), (0.1, 0.7), (-1.2, 0.9), (1.4, 0.6))):
        h = 1.1 + (i % 3) * 0.35
        c = cols[i % len(cols)]
        p.append(cyl(0.14, h, (x, h / 2, z), 0x3E8F35))
        for k in range(5):
            a = 2 * math.pi * k / 5
            p.append(ball((0.42, 0.16, 0.42), (x + math.sin(a) * 0.26, h, z - math.cos(a) * 0.26), c))
        p.append(ball(0.26, (x, h + 0.04, z), 0xFFC23A if c != 0xFFD84A else 0xC0662A))
    return p


def hay_bale():
    c = 0xE6C35C
    return [cyl(3.2, 3.6, (0, 1.6, 0), c, "X", r=(0, 0, 90)), cyl(3.3, 0.25, (0.9, 1.6, 0), 0xC79A3A, "X", r=(0, 0, 90)),
            cyl(3.3, 0.25, (-0.9, 1.6, 0), 0xC79A3A, "X", r=(0, 0, 90))]


def rock(c=0x9A9A8E, mat="R", s=1.0):
    p = [ball((4.5, 2.6, 3.8), (0, 0.9, 0), c, mat, r=(0, 20, 0)), ball((2.6, 2.0, 2.4), (1.4, 0.7, 0.8), shade(c, 0.9), mat, r=(10, 40, 0)),
         ball((2.0, 1.4, 1.8), (-1.6, 0.5, -0.6), shade(c, 1.08), mat)]
    return T(p, s=s)


def windmill():
    wall, roof, sail = 0xF4E6CC, 0xD8483A, 0xFFF8EE
    p = [cyl(8, 2, (0, 1, 0), 0xB0A090, "U"), cyl(7, 14, (0, 8, 0), wall, "P"), cyl(6.2, 2, (0, 15.5, 0), wall, "P"),
         ball((7.6, 6, 7.6), (0, 17, 0), roof, "P"), box((1.6, 3, 0.3), (0, 2.5, -3.5), 0x8A5A36, "W"),
         box((1.2, 1.2, 0.3), (0, 10, -3.45), 0x7EC8F0, "G")]
    hub = (0, 15, -4.2)
    p.append(cyl(1.2, 1.4, hub, 0x8A5A36, "W", r=(90, 0, 0)))
    for i in range(4):
        a = 45 + i * 90
        p += T([box((0.5, 9, 0.2), (0, 4.8, 0), 0x8A5A36, "W"), box((2.4, 7, 0.12), (1.3, 5.2, 0.1), sail, "X")], hub, r=(0, 0, a))
    return p


def lamp(glow=0xFFE27A, post=0x5A4A3A, mat="M"):
    return [cyl(1.2, 0.5, (0, 0.25, 0), post, mat), cyl(0.4, 6.5, (0, 3.5, 0), post, mat),
            box((1.4, 0.3, 1.4), (0, 6.7, 0), post, mat), ball(1.2, (0, 7.4, 0), glow, "N", tag="Glow"),
            cyl(1.4, 0.3, (0, 8.1, 0), post, mat)]


def giant_mushroom(cap=0xE0393E, stem=0xF6EEDC, dots=0xFFFFFF, glow=False, h=12):
    p = [cyl(2.6, h, (0, h / 2, 0), stem, "P"), cyl(3.4, 1.0, (0, 0.5, 0), shade(stem, 0.92), "P"),
         ball((11, 5, 11), (0, h + 1.2, 0), cap, "N" if glow else "P", tag="Glow" if glow else None),
         ball((9.5, 1.2, 9.5), (0, h - 0.6, 0), shade(stem, 0.9))]
    for yaw, pitch, s in ((0, 30, 1.6), (72, 45, 1.3), (144, 25, 1.5), (216, 50, 1.2), (288, 30, 1.4), (30, 80, 1.6)):
        p.append(on_surface((0, h + 1.2, 0), (5.5, 2.5, 5.5), yaw, pitch, (s, s, 0.3), dots, "N" if glow else "P", inset=0.3))
    return p


def mushroom_cluster(cap=0x52F2FF):
    p = []
    for x, z, h, s in ((0, 0, 2.2, 1.0), (1.3, 0.6, 1.4, 0.7), (-1.1, 0.8, 1.6, 0.8), (0.4, -1.1, 1.1, 0.6)):
        p += [cyl(0.4 * s, h, (x, h / 2, z), 0xF6EEDC), ball((1.8 * s, 0.9 * s, 1.8 * s), (x, h + 0.1, z), cap, "N", tag="Glow")]
    return p


def log(c=0x6E4A34):
    return [cyl(2.2, 7, (0, 1.1, 0), c, "W", r=(0, 0, 90)), cyl(1.8, 0.1, (3.52, 1.1, 0), 0xC9A27C, "W", r=(0, 0, 90)),
            cyl(1.8, 0.1, (-3.52, 1.1, 0), 0xC9A27C, "W", r=(0, 0, 90)), ball((1.4, 0.5, 1.2), (1.0, 2.2, 0), 0x5FA84A, "E"),
            cyl(0.3, 0.7, (-1.5, 2.4, 0.2), 0xF6EEDC), ball((0.9, 0.45, 0.9), (-1.5, 2.8, 0.2), 0xB57CFF, "N", tag="Glow")]


def grove_tree():
    trunk, leaf, leaf2 = 0x5A3E30, 0x2F7A4A, 0x3F9A5A
    p = [cyl(2.0, 11, (0, 5.5, 0), trunk, "W"), cyl(3.0, 1.2, (0, 0.6, 0), shade(trunk, 0.85), "W")]
    for pos, s, c in (((0, 13, 0), 9.5, leaf), ((3.0, 11, 1.2), 6, leaf2), ((-3.0, 11.6, -0.8), 6.4, leaf2), ((0.4, 15.8, 0), 5.6, leaf2)):
        p.append(ball(s, pos, c))
    p += [ball(0.7, (3.4, 9.6, -2.0), 0x52F2FF, "N", tag="Glow"), ball(0.7, (-2.8, 10.4, -2.6), 0xB57CFF, "N", tag="Glow")]
    return p


def pine_snow(h=14):
    trunk, g, snow = 0x6A4A34, 0x2F6E5A, 0xFFFFFF
    p = [cyl(1.4, 3, (0, 1.5, 0), trunk, "W")]
    for i, (y, d, hh) in enumerate(((3, 9, 5), (6.5, 7, 4.5), (9.5, 5, 4))):
        p += cone((0, y, 0), d, hh, g, n=4, tip=0.2)
        p.append(cyl(d * 0.62, 0.45, (0, y + hh * 0.42, 0), snow, "S"))
    p.append(ball((1.6, 1.4, 1.6), (0, 13.2, 0), snow, "S"))
    return p


def ice_spire():
    return (crystal((0, 0, 0), 2.6, 12, 0xA8E4FF, "G", t=0.15) + crystal((2.0, 0, 0.8), 1.6, 7, 0xC8F0FF, "G", r=(0, 0, -15), t=0.15)
            + crystal((-1.8, 0, -0.6), 1.4, 6, 0x8FD3FF, "G", r=(0, 0, 18), t=0.15) + [ball((5.5, 1.2, 5), (0, 0.2, 0), 0xFFFFFF, "S")])


def snow_rock():
    return rock(0x8FA3B8, "T") + [ball((3.8, 1.0, 3.2), (0, 2.0, 0.1), 0xFFFFFF, "S")]


def snowman():
    w = 0xFFFFFF
    p = [ball(4.0, (0, 1.9, 0), w, "S"), ball(3.0, (0, 4.8, 0), w, "S"), ball(2.2, (0, 6.9, 0), w, "S"),
         spike((0, 6.9, -1.1), 0.36, 0.8, 0xFF8A2A, r=(-90, 0, 0)), cyl(2.4, 0.3, (0, 7.9, 0), 0x2A2A3A),
         cyl(1.6, 1.4, (0, 8.6, 0), 0x2A2A3A), cyl(2.8, 0.5, (0, 5.9, 0), 0xE0353F, "X")]
    p += sym([ball(0.3, (0.4, 7.2, -0.95), EYE), cyl(0.2, 2.6, (1.9, 5.4, 0), 0x6A4A34, r=(0, 0, 60))])
    return p


def palm():
    trunk, leaf = 0xB08A5A, 0x4FB06A
    p = []
    for i in range(6):
        p.append(cyl(1.6 - i * 0.12, 2.6, (i * 0.35, 1.3 + i * 2.45, 0), trunk if i % 2 == 0 else shade(trunk, 0.88), "W", r=(0, 0, -6)))
    top = (2.1, 15.2, 0)
    for k in range(7):
        a = 360 * k / 7
        p += T([ball((1.8, 0.3, 7.5), (0, -0.8, -3.4), leaf, "P", r=(-20, 0, 0))], top, r=(0, a, 0))
    p += [ball(1.2, (2.6, 14.4, -0.6), 0x7A5A34), ball(1.2, (1.6, 14.3, 0.7), 0x7A5A34), ball(1.2, (2.9, 14.5, 0.8), 0x7A5A34)]
    return p


def coral_branch(c=0xFF6F7F):
    p = [ball((3.2, 1.0, 3.0), (0, 0.3, 0), 0xE8C090, "V")]
    for x, z, h, a in ((0, 0, 5, 0), (1.0, 0.3, 3.5, -25), (-1.0, -0.2, 3.8, 28), (0.3, -0.9, 3.0, -10)):
        p += [cyl(0.6, h, (x + math.sin(math.radians(-a)) * h / 2, h / 2, z), c, r=(0, 0, a)),
              ball(0.9, (x + math.sin(math.radians(-a)) * h, h, z), c)]
    return p


def shell():
    c = 0xFFD8C8
    p = [ball((3.4, 1.6, 3.0), (0, 0.8, 0), c, "P")]
    for i in range(5):
        a = -50 + i * 25
        p.append(ball((0.45, 1.75, 3.0), (math.sin(math.radians(a)) * 1.2, 0.85, 0), shade(c, 0.92), r=(0, 0, -a * 0.8)))
    p.append(ball(0.9, (0, 1.0, -1.3), 0xFFF8F0))
    return p


def starfish(c=0xFF8A5A):
    p = [ball((1.2, 0.4, 1.2), (0, 0.2, 0), c)]
    for i in range(5):
        a = 360 * i / 5
        p += T([ball((0.6, 0.35, 1.6), (0, 0.18, -0.9), c)], (0, 0, 0), r=(0, a, 0))
    return p


def umbrella():
    cols = [0xFF5A6A, 0xFFFFFF]
    p = [cyl(0.3, 9, (0, 4.5, 0), 0xEEEEEE, "M"), ball((9, 2.6, 9), (0, 9.0, 0), cols[0], "X")]
    for i in range(4):
        a = 45 + 90 * i
        p += T([ball((1.6, 2.7, 4.4), (0, 0, -2.2), cols[1], "X")], (0, 9.02, 0), r=(0, a, 0))
    p += [box((4, 0.5, 6), (3.5, 0.25, 1), 0x4FC8E0, "X"), ball(0.6, (0, 10.4, 0), 0xFFFFFF)]
    return p


def beach_rock():
    return rock(0xD9B98A, "V", 1.2)


def lava_rock():
    p = rock(0x3A3034, "B", 1.1)
    p += [box((3.0, 0.15, 0.15), (0.2, 1.4, -1.6), 0xFF6A1A, "N", r=(0, 15, 20), tag="Glow"),
          box((2.0, 0.15, 0.15), (-1.0, 0.9, -1.4), 0xFF6A1A, "N", r=(0, -20, -30), tag="Glow"),
          box((1.6, 0.15, 0.15), (1.6, 0.9, 0.2), 0xFF6A1A, "N", r=(0, 70, 10), tag="Glow")]
    return p


def lava_pool():
    p = [cyl(9, 0.6, (0, 0.3, 0), 0x2A2228, "B"), cyl(7.6, 0.66, (0, 0.33, 0), 0xFF6A1A, "N", tag="Glow"),
         ball(1.0, (1.2, 0.6, 0.8), 0xFFC23A, "N"), ball(0.7, (-1.6, 0.6, -1.0), 0xFFC23A, "N")]
    for i in range(7):
        a = 2 * math.pi * i / 7
        p.append(ball((2.0, 1.2, 1.6), (math.sin(a) * 4.4, 0.4, -math.cos(a) * 4.4), 0x3A3034, "B", r=(0, math.degrees(a), 0)))
    return p


def dead_tree():
    c = 0x2E2626
    p = [cyl(1.4, 9, (0, 4.5, 0), c, "B"), cyl(0.7, 4, (1.3, 7.5, 0), c, "B", r=(0, 0, -45)), cyl(0.6, 3.5, (-1.2, 8.5, 0.3), c, "B", r=(0, 0, 40)),
         cyl(0.5, 2.5, (0.4, 10.2, -0.6), c, "B", r=(-25, 0, -10)), box((0.12, 3.0, 0.12), (0, 3.0, -0.7), 0xFF6A1A, "N", r=(0, 0, 8), tag="Glow")]
    return p


def obsidian_spike():
    return (crystal((0, 0, 0), 2.0, 9, 0x2A2228, "B") + crystal((1.6, 0, 0.6), 1.4, 6, 0x3A3034, "B", r=(0, 0, -18))
            + [box((0.15, 5, 0.15), (0.3, 3.5, -0.75), 0xFF6A1A, "N", r=(0, 45, 5), tag="Glow")])


def float_crystal(c=0xB06CFF, c2=0x6AF2FF):
    p = [ball((4.0, 1.6, 3.6), (0, 0.5, 0), 0x4A3C7A, "T")]
    p += crystal((0, 0.8, 0), 1.4, 5, c, "G", t=0.1) + crystal((1.0, 0.6, 0.4), 0.9, 3, c2, "G", r=(0, 0, -25), t=0.1)
    p += [box((1.4, 1.4, 1.4), (0, 9.0, 0), c2, "N", R=mmul(rx(-35.264), rz(45)), tag="Glow"),
          box((0.8, 0.8, 0.8), (1.8, 7.6, 0.6), c, "N", R=mmul(ry(30), mmul(rx(-35.264), rz(45))), tag="Glow")]
    return p


def planet(c=0xFF9AD5, ringc=0xFFE66B, h=12):
    return [cyl(0.4, h - 2.5, (0, (h - 2.5) / 2, 0), 0x4A3C7A, "T", t=1.0), ball(5, (0, h, 0), c, "P"),
            cyl(9, 0.25, (0, h, 0), ringc, "N", r=(20, 0, 15), tag="Glow"), ball((3, 1.0, 2.6), (0, 0.4, 0), 0x4A3C7A, "T")]


def star_lamp():
    return lamp(0xFFE66B, 0xE8D8FF, "M")[:3] + [box((1.4, 1.4, 1.4), (0, 7.6, 0), 0xFFE66B, "N", R=mmul(rx(-35.264), rz(45)), tag="Glow")]


def moon_rock():
    p = rock(0x6A5CA0, "T", 1.0)
    p += [cyl(1.0, 0.2, (0.6, 2.0, -0.6), 0x4A3C7A, "T", r=(10, 0, 5)), cyl(0.8, 0.2, (-1.2, 1.4, 0.4), 0x4A3C7A, "T", r=(-10, 0, -10))]
    return p


def star_tree():
    trunk = 0xE8D8FF
    p = [cyl(1.0, 9, (0, 4.5, 0), trunk, "M"), cyl(0.5, 4, (1.3, 8, 0), trunk, "M", r=(0, 0, -40)), cyl(0.5, 3.6, (-1.2, 8.6, 0), trunk, "M", r=(0, 0, 40))]
    for pos, c in (((0, 10.2, 0), 0xB06CFF), ((2.6, 9.6, 0), 0x6AF2FF), ((-2.4, 10.0, 0), 0xFF9AD5)):
        p.append(ball(2.4, pos, c, "N", tag="Glow"))
    return p


# ======================================================================= props (interactables)
def pedestal(top=0xFFF6E0, trim=GOLD, base=0xB0A090, mat="Y", h=3.0):
    p = [cyl(9.0, 0.8, (0, 0.4, 0), base, "U"), cyl(6.0, h, (0, 0.8 + h / 2, 0), top, mat),
         cyl(6.6, 0.5, (0, 0.8 + h, 0), trim, "F"), cyl(5.2, 0.4, (0, 1.3 + h, 0), top, mat)]
    return p, 1.5 + h


def egg_stand(area):
    th = THEMES[area]
    top = {"Meadow": 0xFFF6E0, "Grove": 0x8A6AB0, "Frost": 0xE6F6FF, "Coral": 0xFFE6D2, "Volcano": 0x3A3034,
           "Starfall": 0x5B4B9E}[area]
    trim = {"Volcano": 0xFF6A1A, "Starfall": 0xFFE66B, "Frost": 0x9FE0FF, "Grove": 0x52F2FF}.get(area, GOLD)
    p, top_y = pedestal(top=top, trim=trim, mat="Y" if area in ("Meadow", "Coral") else th["rock_mat"])
    p.append(box((0.5, 0.5, 0.5), (0, top_y, 0), 0xFFFFFF, tag="EggSpot", t=1.0))
    # name board in front
    p += [box((0.4, 2.6, 0.4), (-2.4, 1.3, -4.6), th["wood_dk"], "W"), box((0.4, 2.6, 0.4), (2.4, 1.3, -4.6), th["wood_dk"], "W"),
          box((6.0, 2.0, 0.4), (0, 2.8, -4.6), th["wood"] if area != "Frost" else 0x7AA9D6, "W")]
    p.append(box((5.6, 1.7, 0.1), (0, 2.8, -4.85), 0xFFFFFF, tag="SignFace", t=1.0))
    p += sym([ball(1.2, (3.8, 0.6, -2.4), th["leaf"] if area != "Volcano" else 0x3A3034)])
    p.append(box((1, 1, 1), (0, 3, -3.5), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def prism_stand():
    p, top_y = pedestal(top=0xFBF8FF, trim=0xC79BFF, base=0xE8E0FF, mat="Y", h=3.4)
    for i, c in enumerate(RAINBOW):
        a = 2 * math.pi * i / 6
        p += crystal((math.sin(a) * 4.0, 0.8, -math.cos(a) * 4.0), 0.7, 3.2 + (i % 2), c, "G", t=0.1)
    p.append(box((0.5, 0.5, 0.5), (0, top_y, 0), 0xFFFFFF, tag="EggSpot", t=1.0))
    p += [box((0.4, 2.6, 0.4), (-2.4, 1.3, -5.2), 0xE8E0FF, "Y"), box((0.4, 2.6, 0.4), (2.4, 1.3, -5.2), 0xE8E0FF, "Y"),
          box((6.0, 2.0, 0.4), (0, 2.8, -5.2), 0xC79BFF, "P"), box((5.6, 1.7, 0.1), (0, 2.8, -5.45), 0xFFFFFF, tag="SignFace", t=1.0)]
    p.append(box((1, 1, 1), (0, 3, -4.0), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def expedition_board():
    wood, dk, paper = 0x9A6A40, 0x6A4628, 0xF6E8C8
    p = [box((1.0, 13, 1.0), (-7.5, 6.5, 0), dk, "W"), box((1.0, 13, 1.0), (7.5, 6.5, 0), dk, "W"),
         box((15, 9, 0.6), (0, 7.5, 0), wood, "K"), box((16.6, 1.0, 1.4), (0, 12.5, 0), dk, "W"),
         wedge((16.6, 1.4, 1.8), (0, 13.6, 0.5), 0xC0473A, "P", r=(0, 0, 0)), wedge((16.6, 1.4, 1.8), (0, 13.6, -0.5), 0xC0473A, "P", r=(0, 180, 0)),
         box((15.4, 0.4, 0.8), (0, 3.0, -0.2), dk, "W")]
    # map: parchment with sea, six island dots and a dashed route
    p += [box((9.5, 6.2, 0.1), (-2.2, 7.2, -0.35), paper, "X"), box((9.0, 5.7, 0.1), (-2.2, 7.2, -0.42), 0x8FD3F0, "P")]
    icols = [0x6CC24A, 0x7A4FC9, 0xF2F7FF, 0xF2DCA2, 0x3A3034, 0x8E7CE0]
    for i, c in enumerate(icols):
        x = -6.0 + i * 1.5
        y = 6.0 + (1.6 if i % 2 else 0) + (0.4 if i == 5 else 0)
        p.append(cyl(1.1, 0.12, (x, y, -0.5), c, "P", r=(90, 0, 0)))
        if i < 5:
            p.append(box((1.2, 0.12, 0.06), (x + 0.75, y + (0.8 if i % 2 == 0 else -0.8), -0.52), 0xC0473A, "P",
                         r=(0, 0, 45 if i % 2 == 0 else -45)))
    p += [box((0.3, 0.9, 0.1), (-6.0 + 7.5, 8.6, -0.55), 0xE0353F, "P")]
    # notes pinned on the right
    for i, (x, y, rr) in enumerate(((4.2, 9.4, 4), (6.0, 9.2, -5), (4.4, 6.2, -3), (6.1, 6.4, 6))):
        p += [box((1.6, 2.0, 0.08), (x, y, -0.36), [0xFFF6C8, 0xD8F0FF, 0xFFE0E8, 0xE0FFD8][i], "P", r=(0, 0, rr)),
              ball(0.25, (x, y + 0.8, -0.45), 0xE0353F)]
    p.append(box((7.0, 1.5, 0.1), (-2.2, 11.3, -0.75), 0xFFFFFF, tag="SignFace", t=1.0))
    p.append(box((1, 1, 1), (0, 3, -2.5), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def craft_machine():
    g, dk, glass = GOLD, GOLD_DK, 0x9FE6FF
    p = [box((9, 1.0, 7), (0, 0.5, 0), 0x6E5E5A, "D"), box((7.5, 6.5, 6), (0, 4.25, 0.3), g, "F", tag="Body"),
         box((7.9, 0.6, 6.4), (0, 7.6, 0.3), dk, "F"), cyl(4.6, 2.0, (0, 9.0, 0.3), g, "F"),
         cyl(2.4, 2.4, (0, 11.0, 0.3), dk, "F"), cyl(3.6, 0.6, (0, 12.3, 0.3), g, "F")]
    # window with a swirling glow, input funnels, gears and pipes
    p += [cyl(4.0, 0.4, (0, 4.6, -2.75), dk, "F", r=(90, 0, 0)), cyl(3.4, 0.3, (0, 4.6, -2.85), glass, "G", r=(90, 0, 0), t=0.2),
          ball((2.0, 2.0, 0.6), (0, 4.6, -2.75), 0xFFE66B, "N", tag="Glow"), ball((1.0, 1.0, 0.7), (0, 4.6, -2.85), 0xFFFFFF, "N")]
    for x in (-3.0, 3.0):
        p += [cyl(1.6, 2.6, (x * 1.15, 3.0, -0.5), dk, "F"), cyl(2.2, 0.6, (x * 1.15, 4.5, -0.5), g, "F")]
    p += sym([cyl(3.0, 0.5, (3.95, 6.0, 1.5), 0xB0B0B8, "M", r=(0, 0, 90)), cyl(1.2, 0.6, (4.0, 6.0, 1.5), dk, "M", r=(0, 0, 90))])
    for i in range(6):
        a = 360 * i / 6
        p += T([box((0.5, 0.7, 0.5), (0, 1.75, 0), 0xB0B0B8, "M")], (4.0, 6.0, 1.5), r=(a, 0, 0))
    p += [box((3.2, 0.8, 1.2), (0, 0.4, -4.0), dk, "D"), ball(0.8, (2.5, 7.6, -2.5), 0x5CFF8F, "N", tag="Glow"),
          ball(0.8, (-2.5, 7.6, -2.5), 0xFF6FB5, "N", tag="Glow"), ball(1.0, (0, 12.9, 0.3), 0xFFE66B, "N", tag="Glow")]
    p.append(box((5.0, 1.4, 0.1), (0, 1.7, -2.75), 0xFFFFFF, tag="SignFace", t=1.0))
    p.append(box((1, 1, 1), (0, 3, -4.5), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def rebirth_statue():
    stone, glow = 0xE8E4F0, 0xC79BFF
    p = [cyl(12, 1.0, (0, 0.5, 0), 0xB8B0C8, "U"), cyl(9, 3.0, (0, 2.5, 0), stone, "Y"), cyl(9.8, 0.6, (0, 4.2, 0), glow, "N", tag="Glow"),
         cyl(8.0, 0.8, (0, 4.8, 0), stone, "Y")]
    pup = PETS.BUILDERS["Puppy"]()
    from lib import normalize
    pup = normalize(pup, 9.0)
    keep = []
    for q in pup:
        if q.tag == "Eye":
            continue
        keep.append(q.copy(col=0xF2EEF8 if q.mat != "N" else glow, mat="Y" if q.mat != "N" else "N"))
    p += T(keep, (0, 5.2, 0))
    ringp = ring((0, 10.0, 0), 6.5, 12, (0, 0.35, 0.35), glow, "N", tilt=(0, 0, 0), tag="Glow")
    p += ringp
    p.append(box((6.0, 1.6, 0.1), (0, 2.5, -4.55), 0xFFFFFF, tag="SignFace", t=1.0))
    p.append(box((1, 1, 1), (0, 3, -6.0), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def index_book():
    wood, cover, page = 0x8A5A36, 0x7A3FC4, 0xFFF8E8
    p = [cyl(5, 0.8, (0, 0.4, 0), 0x6A4628, "W"), cyl(1.6, 5.5, (0, 3.5, 0), wood, "W"), box((6.5, 0.6, 4.5), (0, 6.4, 0), wood, "W", r=(-20, 0, 0))]
    # open book: two covers and two page blocks tilted into a V, ribbon
    for s in (-1, 1):
        p += T([box((4.2, 0.3, 5.4), (s * 2.1, 0, 0), cover, "X"), box((3.9, 0.7, 5.0), (s * 2.0, 0.45, 0), page, "P"),
                box((3.7, 0.08, 4.6), (s * 2.0, 0.82, 0), 0xFFFFFF, "P")], (0, 7.2, 0.2), r=(-20, 0, s * -8))
    p += [box((0.4, 0.06, 3.0), (0.2, 8.0, -1.8), 0xE0353F, "X", r=(-20, 0, 0)), ball(0.9, (0, 7.2, 2.4), GOLD, "F")]
    for i in range(4):
        p.append(box((3.0, 0.06, 0.18), (-2.0, 8.2 - i * 0.16, -0.7 + i * 0.45), 0x8A7A9A, "P", r=(-20, 0, 8)))
        p.append(box((3.0, 0.06, 0.18), (2.0, 8.2 - i * 0.16, -0.7 + i * 0.45), 0x8A7A9A, "P", r=(-20, 0, -8)))
    p += [ball(0.6, (3.2, 9.6, 0), 0xFFE66B, "N", tag="Glow"), ball(0.4, (-3.0, 9.9, 0.4), 0xFFE66B, "N", tag="Glow"),
          ball(0.35, (0.4, 10.6, 0.2), 0xFFFFFF, "N", tag="Glow")]
    p.append(box((4.5, 1.2, 0.1), (0, 2.6, -1.0), 0xFFFFFF, tag="SignFace", t=1.0))
    p.append(box((4.6, 1.2, 0.2), (0, 2.6, -0.9), 0x6A4628, "W"))
    p.append(box((1, 1, 1), (0, 3, -3.0), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


GATE_STYLE = {
    "Grove": dict(pillar=0x6A4E5E, mat="W", cap=0xE0393E, cap_mat="P", barrier=0x52F2FF),
    "Frost": dict(pillar=0xBFE6FF, mat="I", cap=0xFFFFFF, cap_mat="S", barrier=0x9FE0FF),
    "Coral": dict(pillar=0xF2DBA0, mat="V", cap=0xFF7F6E, cap_mat="P", barrier=0x4FD8FF),
    "Volcano": dict(pillar=0x2E262A, mat="B", cap=0xFF6A1A, cap_mat="N", barrier=0xFF6A1A),
    "Starfall": dict(pillar=0x4A3C8A, mat="T", cap=0xFFE66B, cap_mat="N", barrier=0xB06CFF),
}


def gate(area):
    st = GATE_STYLE.get(area, GATE_STYLE["Grove"])
    W, H = 18, 16
    p = []
    for x in (-W / 2 - 1.5, W / 2 + 1.5):
        p += [box((3.4, 1.0, 3.4), (x, 0.5, 0), shade(st["pillar"], 0.85), st["mat"]), box((3, H, 3), (x, H / 2, 0), st["pillar"], st["mat"]),
              box((3.6, 1.0, 3.6), (x, H + 0.5, 0), shade(st["pillar"], 0.85), st["mat"]), ball(2.6, (x, H + 2.2, 0), st["cap"], st["cap_mat"])]
    p += [box((W + 6, 2.6, 2.4), (0, H + 1.3, 0), st["pillar"], st["mat"]), box((W - 2, 2.2, 0.3), (0, H + 1.3, -1.25), 0x3A2E2A, "W")]
    p.append(box((W - 2.4, 1.9, 0.1), (0, H + 1.3, -1.45), 0xFFFFFF, tag="SignFace", t=1.0))
    p.append(box((W, H, 1.0), (0, H / 2, 0), st["barrier"], "Z", tag="Barrier", t=0.35))
    p.append(box((1, 1, 1), (0, 3, -2.0), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def island_sign(c=0x9A6A40):
    return [box((0.8, 7, 0.8), (-4.5, 3.5, 0), shade(c, 0.75), "W"), box((0.8, 7, 0.8), (4.5, 3.5, 0), shade(c, 0.75), "W"),
            box((11, 3.6, 0.6), (0, 6.0, 0), c, "K"), box((10.4, 3.0, 0.1), (0, 6.0, -0.36), 0xFFFFFF, tag="SignFace", t=1.0)]


def spawn_pad():
    p = [cyl(16, 0.6, (0, 0.3, 0), 0xFFF6E0, "Y"), cyl(17, 0.4, (0, 0.2, 0), GOLD, "F")]
    for i in range(8):
        a = 360 * i / 8
        p += T([ball((1.4, 0.3, 2.4), (0, 0.6, -5.5), RAINBOW[i % 6], "N", tag="Glow")], r=(0, a, 0))
    return p


def bench():
    w = 0xA0703F
    return [box((6, 0.4, 1.8), (0, 1.6, 0), w, "K"), box((6, 1.6, 0.3), (0, 2.6, 0.8), w, "K", r=(-10, 0, 0)),
            box((0.4, 1.5, 1.6), (-2.6, 0.75, 0), 0x4A4A50, "M"), box((0.4, 1.5, 1.6), (2.6, 0.75, 0), 0x4A4A50, "M")]


def fence():
    w = 0xF4EEE0
    return [box((0.5, 3, 0.5), (-3, 1.5, 0), w), box((0.5, 3, 0.5), (3, 1.5, 0), w), box((0.5, 3, 0.5), (0, 1.5, 0), w),
            box((6.6, 0.4, 0.3), (0, 2.2, 0), w), box((6.6, 0.4, 0.3), (0, 1.1, 0), w)]


def bridge_lantern(glow=0xFFE27A):
    return [cyl(0.4, 4.0, (0, 2.0, 0), 0x5A4A3A, "W"), ball(0.9, (0, 4.4, 0), glow, "N", tag="Glow")]


# Backdrop set pieces that sit outside the islands (in the sea, or floating).
def mountain():
    p = []
    for x, z, d, h, c in ((0, 0, 70, 70, 0x8FA3B8), (-30, 15, 50, 48, 0x9FB4C8), (32, 10, 46, 42, 0x7F93A8)):
        p += cone((x, 0, z), d, h, c, "T", n=5, tip=0.12)
        p.append(cyl(d * 0.32, h * 0.18, (x, h * 0.86, z), 0xFFFFFF, "S"))
    return p


def volcano_peak():
    p = cone((0, 0, 0), 110, 75, 0x3A3034, "B", n=6, tip=0.32)
    p += [cyl(32, 1.2, (0, 75, 0), 0xFF6A1A, "N", tag="Glow"), cyl(36, 3, (0, 74, 0), 0x2A2228, "B")]
    for a in (20, 140, 250):
        p += T([box((4, 60, 1.5), (0, 0, -30), 0xFF5A1A, "N", tag="Glow")], (0, 40, 0), r=(48, a, 0))
    return p


def big_planet():
    return [ball(60, (0, 0, 0), 0xFF9AD5, "P"), ball((50, 8, 50), (0, 20, 0), 0xFFB8E0, "P"),
            cyl(110, 1.2, (0, 0, 0), 0xFFE66B, "N", r=(18, 0, 12), tag="Glow"), cyl(96, 1.4, (0, 0, 0), 0xC79BFF, "P", r=(18, 0, 12))]


def lighthouse():
    p = [cyl(16, 6, (0, 3, 0), 0xD9B98A, "V")]
    for i in range(5):
        p.append(cyl(8 - i * 0.6, 6, (0, 9 + i * 6, 0), 0xFFFFFF if i % 2 == 0 else 0xE0353F, "P"))
    p += [cyl(6.4, 4, (0, 40, 0), 0xFFE27A, "N", tag="Glow"), cyl(7.2, 0.8, (0, 38, 0), 0x3A3A44, "M")]
    p += cone((0, 42, 0), 7.4, 5, 0xE0353F, n=3, tip=0.2)
    return p


def giant_mushroom_backdrop():
    return T(giant_mushroom(cap=0xB57CFF, dots=0x52F2FF, glow=False, h=12), s=3.6)


def big_tree():
    return T(tree_round(), s=3.2)


def props():
    """name -> (builder, collide)"""
    P = {
        # Meadow
        "TreeRound": (tree_round, True), "Bush": (bush, True), "Flowers": (flower_patch, False), "HayBale": (hay_bale, True),
        "Rock": (rock, True), "Windmill": (windmill, True), "Lamp": (lamp, True), "Fence": (fence, True), "Bench": (bench, True),
        # Grove
        "GiantMushroom": (giant_mushroom, True), "GlowMushroom": (lambda: giant_mushroom(0x7A4FC9, dots=0x52F2FF, glow=False, h=9), True),
        "MushroomCluster": (mushroom_cluster, False), "Log": (log, True), "GroveTree": (grove_tree, True),
        "GroveBush": (lambda: bush(0x2F7A4A, 0x3F9A5A, 0x52F2FF), True), "GroveLamp": (lambda: lamp(0x52F2FF, 0x4A3040, "W"), True),
        # Frost
        "PineSnow": (pine_snow, True), "IceSpire": (ice_spire, True), "SnowRock": (snow_rock, True), "Snowman": (snowman, True),
        "FrostLamp": (lambda: lamp(0x9FE0FF, 0xDDE6F0, "M"), True),
        # Coral
        "Palm": (palm, True), "Coral": (coral_branch, False), "CoralPurple": (lambda: coral_branch(0xC77CFF), False),
        "Shell": (shell, True), "Starfish": (starfish, False), "Umbrella": (umbrella, True), "BeachRock": (beach_rock, True),
        "CoralLamp": (lambda: lamp(0xFFB08A, 0xCFAE84, "W"), True),
        # Volcano
        "LavaRock": (lava_rock, True), "LavaPool": (lava_pool, False), "DeadTree": (dead_tree, True), "ObsidianSpike": (obsidian_spike, True),
        "VolcanoLamp": (lambda: lamp(0xFF6A1A, 0x2E262A, "B"), True),
        # Starfall
        "FloatCrystal": (float_crystal, True), "FloatCrystalCyan": (lambda: float_crystal(0x6AF2FF, 0xFF9AD5), True),
        "Planet": (planet, True), "PlanetBlue": (lambda: planet(0x6AB8FF, 0xFF9AD5, 14), True), "StarLamp": (star_lamp, True),
        "MoonRock": (moon_rock, True), "StarTree": (star_tree, True),
        # Backdrops
        "Mountain": (mountain, True), "VolcanoPeak": (volcano_peak, True), "BigPlanet": (big_planet, True),
        "Lighthouse": (lighthouse, True), "GiantMushroomBackdrop": (giant_mushroom_backdrop, True), "BigTree": (big_tree, True),
        # Interactables and hub
        "ExpeditionBoard": (expedition_board, True), "CraftMachine": (craft_machine, True), "RebirthStatue": (rebirth_statue, True),
        "IndexBook": (index_book, True), "PrismStand": (prism_stand, True), "IslandSign": (island_sign, True),
        "SpawnPad": (spawn_pad, True), "BridgeLantern": (bridge_lantern, True),
    }
    for area in THEMES:
        P[f"EggStand_{area}"] = ((lambda a=area: egg_stand(a)), True)
    for area in GATE_STYLE:
        P[f"Gate_{area}"] = ((lambda a=area: gate(a)), True)
    return P
