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
from lib import normalize

EGG_STAND_SCALE = 1.8
GOLD, GOLD_DK = 0xFFC93C, 0xD99A1E


from eggs import EGGS, STANDS, stand_prism  # noqa: E402,F401


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


GATE_STYLE = {
    "Grove": dict(pillar=0x6A4E5E, mat="W", cap=0xE0393E, cap_mat="P", barrier=0x52F2FF),
    "Frost": dict(pillar=0xBFE6FF, mat="I", cap=0xFFFFFF, cap_mat="S", barrier=0x9FE0FF),
    "Coral": dict(pillar=0xF2DBA0, mat="V", cap=0xFF7F6E, cap_mat="P", barrier=0x4FD8FF),
    "Volcano": dict(pillar=0x2E262A, mat="B", cap=0xFF6A1A, cap_mat="N", barrier=0xFF6A1A),
    "Starfall": dict(pillar=0x4A3C8A, mat="T", cap=0xFFE66B, cap_mat="N", barrier=0xB06CFF),
}


def gate(area):
    """Stone gate pillars with lanterns and a wooden name beam (reference/islands.jpg)."""
    st = GATE_STYLE.get(area, GATE_STYLE["Grove"])
    W, H = 18, 16
    stone, stone_dk = 0xA9A6A0, 0x8A8680
    p = []
    for x in (-W / 2 - 1.6, W / 2 + 1.6):
        p += [box((4.0, 1.2, 4.0), (x, 0.6, 0), stone_dk, "U"), box((3.2, H * 0.5, 3.2), (x, 1.2 + H * 0.25, 0), stone, "U"),
              box((3.0, H * 0.5, 3.0), (x, 1.2 + H * 0.75, 0), shade(stone, 1.06), "U"),
              box((3.8, 0.8, 3.8), (x, H + 1.6, 0), stone_dk, "U"), box((1.6, 1.6, 1.6), (x, H + 2.8, 0), 0xFFE27A, "N", tag="Glow"),
              box((2.2, 0.5, 2.2), (x, H + 3.85, 0), st["cap"], st["cap_mat"])]
    p += [box((W + 2.4, 2.6, 1.6), (0, H + 0.2, 0), 0x8A5A36, "K"), box((W + 3.2, 0.5, 1.9), (0, H + 1.65, 0), 0x6E4426, "W"),
          box((W + 3.2, 0.5, 1.9), (0, H - 1.25, 0), 0x6E4426, "W")]
    p.append(box((W - 1, 2.2, 0.1), (0, H + 0.2, -0.86), 0xFFFFFF, tag="SignFace", t=1.0))
    p.append(box((W, H - 1.6, 1.0), (0, (H - 1.6) / 2, 0), st["barrier"], "Z", tag="Barrier", t=0.35))
    p.append(box((1, 1, 1), (0, 3, -2.0), 0xFFFFFF, tag="Prompt", t=1.0))
    return p


def island_sign(c=0x9A6A40):
    return [box((0.8, 7, 0.8), (-4.5, 3.5, 0), shade(c, 0.75), "W"), box((0.8, 7, 0.8), (4.5, 3.5, 0), shade(c, 0.75), "W"),
            box((11, 3.6, 0.6), (0, 6.0, 0), c, "K"), box((10.4, 3.0, 0.1), (0, 6.0, -0.36), 0xFFFFFF, tag="SignFace", t=1.0)]


def bridge_lantern(glow=0xFFE27A):
    return [cyl(0.4, 4.0, (0, 2.0, 0), 0x5A4A3A, "W"), ball(0.9, (0, 4.4, 0), glow, "N", tag="Glow")]


def props():
    """name -> (builder, collide)"""
    import voxel as V
    P = {
        # shared
        "LanternPost": (V.lantern_post, True), "StoneLantern": (V.stone_lantern, True), "GrassTuft": (V.grass_tuft, False),
        "Rock": (V.vox_rock, True), "Fence": (V.fence, True), "HayCrate": (V.hay_crate, True), "Bench": (V.bench, True),
        "BridgeLantern": (bridge_lantern, True), "IslandSign": (island_sign, True),
        # Meadow
        "VoxTree": (V.vox_tree, True), "VoxBush": (V.vox_bush, True), "Daisies": (V.daisies, False), "Windmill": (V.windmill, True),
        "Dock": (V.dock, True),
        # Grove
        "GlowShroom": (V.glow_shroom, True), "GlowShroomBlue": (lambda: V.glow_shroom(0x6AE8FF), True),
        "GlowCluster": (V.glow_cluster, False), "PurpleCrystal": (V.purple_crystal, True), "VoxLog": (V.vox_log, True),
        "GroveTree": (V.grove_tree, True), "PurpleTuft": (lambda: V.grass_tuft(0x8A5AD8), False),
        # Frost
        "VoxPine": (V.vox_pine, True), "IceCrystal": (V.ice_crystal, True), "SnowRock": (V.snow_rock, True), "Snowman": (V.snowman, True),
        # Coral
        "VoxPalm": (V.vox_palm, True), "Coral": (V.vox_coral, False), "CoralPurple": (lambda: V.vox_coral(0xC77CFF), False),
        "Shell": (V.shell, True), "Starfish": (V.starfish, False), "BeachRock": (lambda: V.vox_rock(0xD9B98A, "V"), True),
        # Volcano
        "LavaRock": (V.lava_rock, True), "LavaPool": (V.lava_pool, False), "DeadTree": (V.dead_tree, True), "FireCrystal": (V.fire_crystal, True),
        # Starfall
        "FloatCrystal": (V.float_crystal, True), "FloatCrystalCyan": (lambda: V.float_crystal(0x6AF2FF, 0xFF9AD5), True),
        "Planet": (V.planet, True), "PlanetBlue": (lambda: V.planet(0x6AB8FF, 0xFF9AD5, 14), True), "StarProp": (V.star_prop, True),
        "MoonRock": (V.moon_rock, True),
        # landmarks
        "LandmarkGrove": (V.landmark_grove, True), "LandmarkFrost": (V.landmark_frost, True), "LandmarkCoral": (V.landmark_coral, True),
        "LandmarkVolcano": (V.landmark_volcano, True), "LandmarkStarfall": (V.landmark_starfall, True),
        # hub and interactables
        "TreeCluster": (V.tree_cluster, True), "ShroomCluster": (V.shroom_cluster, True), "PineCluster": (V.pine_cluster, True),
        "PalmCluster": (V.palm_cluster, True), "CrystalField": (V.crystal_field, True), "FlowerBed": (V.flower_bed, False),
        "PawPlaza": (V.paw_plaza, True), "ExpeditionBoard": (V.map_board, True), "CraftMachine": (V.gear_machine, True),
        "RebirthStatue": (lambda: V.dog_statue(normalize(PETS.BUILDERS["Puppy"](), 6.5)), True), "IndexBook": (V.giant_book, True),
        "PrismStand": (stand_prism, True), "RingArch": (V.ring_arch, True), "SteppingStone": (V.stepping_stone, False),
    }
    for area in THEMES:
        P[f"EggStand_{area}"] = (STANDS[area], True)
    for area in GATE_STYLE:
        P[f"Gate_{area}"] = ((lambda a=area: gate(a)), True)
    return P
