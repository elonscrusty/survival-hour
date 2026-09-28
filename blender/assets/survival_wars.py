"""Survival Wars expansion: landscape kit, points of interest, cave kit, chests,
ore/scrap nodes, tiered tools, storage tiers, traps and higher-tier camp pieces.

Axis reminder (see sh/kit.py): Blender -Y becomes Roblox -Z (front), Blender +X
becomes Roblox -X. The game's POI builders (src/shared/Models/Landmarks.luau)
put each entrance on Roblox local +Z, i.e. Blender +Y here, and every POI mesh
matches its procedural collider layout (walls, door gaps, floors) so the
invisible colliders line up with what players see.
"""

import math

from mathutils import Vector

from sh import trees as T
from sh.pipeline import asset

GROUND = "Bottom centre on the ground (Z=0)."
POI_PIVOT = ("Ground centre of the site. Entrance faces Blender +Y (Roblox +Z), matching "
             "Landmarks.luau, which keeps the collider parts and swaps in this mesh.")
TOOL_PIVOT = ("Grip point (RightGripAttachment). Handle runs up +Y, striking side faces forward "
              "(-Z). Default Tool.Grip = identity.")
GUNLIKE_PIVOT = ("Grip point (RightGripAttachment). Points forward along -Z (LookVector), up is +Y. "
                 "Default Tool.Grip = identity.")
HELD = 1.5


# =============================================================== helpers

def plank_wall(m, a, b, h, mat="wood", t=0.8, z0=0.0, door=None, window=None, broken=False):
    """Straight wall from a to b (2D points) of height h. door=(centre_t, width, height),
    window=(centre_t, width, z_low, z_high). t along the wall from 0..1."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    d = b - a
    L = d.length
    ang = math.degrees(math.atan2(d.y, d.x))
    gaps = []
    if door:
        gaps.append((door[0] * L - door[1] / 2, door[0] * L + door[1] / 2, 0.0, door[2]))
    if window:
        gaps.append((window[0] * L - window[1] / 2, window[0] * L + window[1] / 2, window[2], window[3]))

    def seg(s0, s1, zlo, zhi):
        if s1 - s0 < 0.05 or zhi - zlo < 0.05:
            return
        mid = a + d.normalized() * ((s0 + s1) / 2)
        m.box(mat, (s1 - s0, t, zhi - zlo), loc=(mid.x, mid.y, z0 + (zlo + zhi) / 2), rot=(0, 0, ang), bevel=0.04)

    # split the wall into vertical strips around gaps
    cuts = sorted({0.0, L, *[g[0] for g in gaps], *[g[1] for g in gaps]})
    for s0, s1 in zip(cuts, cuts[1:]):
        inside = [g for g in gaps if g[0] <= s0 + 1e-6 and g[1] >= s1 - 1e-6]
        top = h * (0.4 if broken else 1.0)
        if not inside:
            seg(s0, s1, 0, top)
        else:
            g = inside[0]
            seg(s0, s1, 0, g[2])
            seg(s0, s1, g[3], top)
    # plank seams (thin darker battens) for texture read
    for k in range(1, int(L / 1.6)):
        p = a + d.normalized() * (k * 1.6)
        m.box("wood_dark", (0.12, t + 0.06, h * (0.4 if broken else 1.0) * 0.96), loc=(p.x, p.y, z0 + h * (0.2 if broken else 0.48)),
              rot=(0, 0, ang))


def room(m, w, d, h, mat="wood", t=0.8, door_w=5.5, door_h=7.5, window=False, broken=(), floor=True,
         ox=0.0, oy=0.0, floor_mat="wood_dark"):
    """Matches Landmarks.room(): door centred on the +Y wall, optional side windows."""
    x0, x1, y0, y1 = ox - w / 2, ox + w / 2, oy - d / 2, oy + d / 2
    if floor:
        m.box(floor_mat, (w, d, 0.6), loc=(ox, oy, 0.3), bevel=0.05)
    plank_wall(m, (x0, y0 + t / 2), (x1, y0 + t / 2), h, mat, t, broken="back" in broken)
    win = (0.5, d * 0.3, h * 0.42, h * 0.72) if window else None
    plank_wall(m, (x0 + t / 2, y0), (x0 + t / 2, y1), h, mat, t, window=win, broken="left" in broken)
    plank_wall(m, (x1 - t / 2, y0), (x1 - t / 2, y1), h, mat, t, window=win, broken="right" in broken)
    plank_wall(m, (x0, y1 - t / 2), (x1, y1 - t / 2), h, mat, t, door=(0.5, door_w, door_h))
    # corner posts
    for x in (x0 + 0.3, x1 - 0.3):
        for y in (y0 + 0.3, y1 - 0.3):
            m.box("wood_dark", (0.7, 0.7, h + 0.2), loc=(x, y, h / 2), bevel=0.06)


def gable(m, w, d, z, mat="wood_dark", ox=0.0, oy=0.0, broken=False):
    """Pitched roof over a w x d room (ridge along Y)."""
    rise = w * 0.32
    for sx in (-1, 1):
        if broken and sx == 1:
            m.box(mat, (w / 2, d * 0.6, 0.35), loc=(ox + sx * w * 0.2, oy - d * 0.1, z * 0.45), rot=(0, 35, 0))
            continue
        ang = math.degrees(math.atan2(rise, w / 2))
        run = math.hypot(w / 2 + 0.6, rise)
        m.box(mat, (run, d + 1.0, 0.35), loc=(ox + sx * (w / 4 + 0.15), oy, z + rise / 2), rot=(0, sx * ang, 0), bevel=0.05)
    # gable ends (prism profile is (x, z), extruded along Y)
    for sy in (-1, 1):
        m.prism("wood", [(-w / 2, 0), (w / 2, 0), (0, rise)], 0.4, loc=(ox, oy + sy * (d / 2 - 0.2), z))


def rock(m, loc, r, mat="stone", sq=(1, 1, 0.7), jit=0.18, subdiv=2):
    m.blob(mat, r, loc=loc, scale=sq, jitter=r * jit, subdiv=subdiv)


def crate(m, loc, s=1.0, rot=0.0):
    m.box("crate_paint", (2 * s, 2 * s, 2 * s), loc=(loc[0], loc[1], loc[2] + s), rot=(0, 0, rot), bevel=0.08 * s)
    for k in (-1, 1):
        m.box("wood_dark", (2.05 * s, 0.25 * s, 0.3 * s), loc=(loc[0], loc[1], loc[2] + s + k * 0.6 * s), rot=(0, 0, rot))


def tent(m, loc, rot=0.0, mat="cloth"):
    m.prism(mat, [(-2.6, 0), (2.6, 0), (0, 3.4)], 5.0, loc=loc, rot=(0, 0, rot))
    m.cylinder("wood_dark", 0.08, 0.08, 3.6, seg=5, loc=(loc[0], loc[1], loc[2]))


def fire_pit(m, loc):
    for i in range(8):
        a = i * math.tau / 8
        rock(m, (loc[0] + math.cos(a) * 1.6, loc[1] + math.sin(a) * 1.6, loc[2] + 0.25), 0.5, "stone_dark", (1, 1, 0.7), subdiv=1)
    m.cylinder("ash", 1.3, 1.3, 0.12, seg=10, loc=loc)
    for k in range(3):
        m.cylinder("charcoal", 0.18, 0.18, 1.6, seg=5, loc=(loc[0], loc[1], loc[2] + 0.2), rot=(90, 0, k * 60))


def truss_ladder(m, loc, h, rot=0):
    for sx in (-0.75, 0.75):
        m.box("wood_dark", (0.2, 0.2, h), loc=(loc[0] + sx, loc[1], loc[2] + h / 2), rot=(0, 0, rot))
    for k in range(int(h / 0.9)):
        m.box("wood", (1.6, 0.18, 0.14), loc=(loc[0], loc[1], loc[2] + 0.6 + k * 0.9), rot=(0, 0, rot))


# =============================================================== landscape kit

@asset("SM_Cliff_Face01", "SW_Landscape", "WorldProp", density=5.0, lod=True, pivot=GROUND, uv_box=True,
       footprint=[20, 8], use="Modular cliff face for the map rim (20 wide x 26 tall). Tile along X; rotate/flip for variety.",
       notes="Visual only. The rim is voxel terrain; collision stays on the terrain (simplified).")
def cliff_face01(m):
    for i in range(7):
        x = -9 + i * 3
        h = m.rng.uniform(18, 26)
        m.blob("stone" if i % 2 else "stone_dark", 3.2, loc=(x, m.rng.uniform(-0.6, 0.6), h / 2),
               scale=(1.1, 1.3, h / 6.4), jitter=0.7, subdiv=2)
    for i in range(5):
        m.blob("stone_mossy", 2.2, loc=(-8 + i * 4, -1.8, m.rng.uniform(1, 3)), scale=(1.4, 1.2, 0.8), jitter=0.4)
    for i in range(4):
        m.blob("moss", 1.4, loc=(-7 + i * 4.5, -1.2, m.rng.uniform(8, 14)), scale=(1.2, 0.5, 0.6), jitter=0.2, subdiv=1)


@asset("SM_Cliff_Face02", "SW_Landscape", "WorldProp", density=5.0, lod=True, pivot=GROUND, uv_box=True,
       footprint=[20, 8], use="Cliff face variant with a ledge and hanging roots.")
def cliff_face02(m):
    for i in range(6):
        x = -8.5 + i * 3.4
        h = m.rng.uniform(16, 24)
        m.blob("stone_dark" if i % 2 else "stone_vein", 3.4, loc=(x, 0, h / 2), scale=(1.0, 1.2, h / 6.8), jitter=0.8)
    m.box("stone", (18, 3, 1.2), loc=(0, -2.4, 12), bevel=0.3)
    for i in range(6):
        x = -8 + i * 3.1
        m.sweep("bark_dead", [(x, -2.2, 12), (x + 0.3, -2.8, 9), (x - 0.2, -2.6, 6.5)], [0.14, 0.1, 0.04], 4)


@asset("SM_CaveEntrance", "SW_Landscape", "WorldProp", density=4.0, lod=True, pivot=POI_PIVOT, uv_box=True,
       footprint=[20, 8], use="Rock arch that frames a cave mouth. Opening faces Blender -Y (the forest); the tunnel "
       "runs along +Y (into the cliff). WorldService carves the tunnel into terrain.")
def cave_entrance(m):
    for i in range(9):
        a = math.radians(-12 + i * 25.5)
        r = m.rng.uniform(2.4, 3.2)
        rock(m, (math.cos(a) * 7.2, m.rng.uniform(-0.8, 0.8), math.sin(a) * 7.8 + 1), r,
             "stone_dark" if i % 3 else "stone_vein", (1, 1.3, 1), jit=0.25)
    m.box("moss", (11, 3.2, 0.5), loc=(0, 0, 9.4))
    for x in (-3, -1, 1.5, 3.5):
        m.sweep("bark_dead", [(x, -1.2, 9), (x + 0.2, -1.6, 7.4), (x, -1.4, 6.2)], [0.12, 0.08, 0.03], 4)
    for x in (-8.5, 8.5):
        rock(m, (x, -2, 0.8), 1.4, "stone_mossy", (1.2, 1, 0.7))


@asset("SM_CaveTunnel_Segment", "SW_Landscape", "WorldProp", density=5.0, lod=True, pivot=GROUND, uv_box=True,
       footprint=[12, 8], use="Modular cave interior piece (8 studs long, 11 wide, 10 tall), open front/back. "
       "Chain along +Y to line a tunnel carved in terrain.")
def cave_segment(m):
    for side in (-1, 1):
        for k in range(3):
            y = -3 + k * 3
            rock(m, (side * 5.4, y, 3.5), 2.2, "stone_dark", (0.7, 1.1, 1.8), jit=0.3)
    for k in range(3):
        rock(m, (0, -3 + k * 3, 10), 3.0, "stone", (1.9, 1.1, 0.5), jit=0.3)
    for k in range(4):
        m.cone("stone_vein", 0.35, 1.4, seg=5, loc=(m.rng.uniform(-3, 3), m.rng.uniform(-3, 3), 9.5), rot=(180, 0, 0))


@asset("SM_CaveChamber_End", "SW_Landscape", "WorldProp", density=5.0, lod=True, pivot=GROUND, uv_box=True,
       footprint=[16, 16], use="Dome that caps a cave tunnel (dead end / chamber), with glowing crystals.")
def cave_chamber(m):
    for i in range(10):
        a = math.radians(i * 30 - 150)
        rock(m, (math.cos(a) * 7, math.sin(a) * 7 + 4, 4), 2.8, "stone_dark", (1, 1, 1.6), jit=0.3)
    rock(m, (0, 4, 11), 6.5, "stone", (1.2, 1.2, 0.45), jit=0.3)
    for k in range(5):
        a = k * 1.3
        m.cone("eye_glow", 0.35, m.rng.uniform(1.2, 2.2), seg=5, loc=(math.cos(a) * 5, 4 + math.sin(a) * 5, 0), rot=(m.rng.uniform(-15, 15), 0, 0))


def bank(m, curve=None):
    def height(x, y):
        # grass shelf (y > 3) sloping to mud and rocks toward the water (y < -3)
        t = max(0.0, min(1.0, (y + 5) / 10))
        return -0.8 + 1.4 * t + 0.08 * math.sin(x * 1.3)

    def mat(x, y, z, slope):
        if y > 2.5:
            return "grass" if (int(x * 0.7) % 3) else "moss"
        if y > -1.0:
            return "dirt"
        return "stone_mossy"

    m.heightfield(16, 10, 16, 8, height, mat, base=-1.4, warp=curve)
    for i in range(6):
        x = -7 + i * 2.8 + m.rng.uniform(-0.5, 0.5)
        p = curve(x, -4.2) if curve else (x, -4.2)
        rock(m, (p[0], p[1], -0.2), m.rng.uniform(0.5, 0.9), "stone_mossy", (1.3, 1, 0.6), subdiv=1)


@asset("SM_Riverbank_Straight", "SW_Landscape", "WorldProp", density=4.0, lod=True, pivot=GROUND,
       footprint=[16, 10], use="Riverbank strip (16 long): grass/moss -> mud -> rocks -> water edge (at -Y). "
       "Lines stream edges; water stays terrain water.")
def bank_straight(m):
    bank(m)


@asset("SM_Riverbank_Bend", "SW_Landscape", "WorldProp", density=4.0, lod=True, pivot=GROUND,
       footprint=[16, 12], use="Curved riverbank strip (45-degree bend).")
def bank_bend(m):
    def warp(x, y):
        a = math.radians(45) * (x + 8) / 16
        r = 14 - y
        return (math.sin(a) * r - 4, 14 - math.cos(a) * r)
    bank(m, warp)


@asset("SM_Ground_Forest01", "SW_Landscape", "WorldProp", density=6.0, lod=True, pivot=GROUND,
       footprint=[32, 32], use="Modular 32x32 forest-floor section (moss, leaf litter, dirt, grass). Edges are flat "
       "at Z=0 so sections tile seamlessly; used for hand-built areas (lobby, set pieces).",
       notes="Collision: the flat top (box). Small bumps are visual only.")
def ground_forest01(m):
    def h(x, y):
        edge = min(1.0, (16 - abs(x)) / 4, (16 - abs(y)) / 4)
        return max(0.0, edge) * (0.35 * math.sin(x * 0.4) * math.cos(y * 0.33) + 0.2 * math.sin(x * 1.1 + y * 0.7))

    def mat(x, y, z, s):
        n = math.sin(x * 0.31) + math.cos(y * 0.27) + 0.5 * math.sin((x + y) * 0.6)
        return "moss" if n > 0.8 else "forest_floor" if n > -0.4 else "dirt" if n > -1.3 else "grass"
    m.heightfield(32, 32, 16, 16, h, mat, base=-2)
    m.col_box((0, 0, -1), (32, 32, 2))


@asset("SM_Ground_Clearing01", "SW_Landscape", "WorldProp", density=6.0, lod=True, pivot=GROUND,
       footprint=[32, 32], use="Modular 32x32 camp-clearing section: packed earth centre, grass edge, a stone ring.")
def ground_clearing01(m):
    def h(x, y):
        return 0.1 * math.sin(x * 0.5) * math.cos(y * 0.5) * min(1, (16 - max(abs(x), abs(y))) / 4)

    def mat(x, y, z, s):
        r = math.hypot(x, y)
        return "dirt" if r < 10 else "forest_floor" if r < 13 else "grass"
    m.heightfield(32, 32, 16, 16, h, mat, base=-2)
    for i in range(12):
        a = i * math.tau / 12
        rock(m, (math.cos(a) * 11.5, math.sin(a) * 11.5, 0.3), 0.6, "stone_mossy", (1.2, 1, 0.6), subdiv=1)
    m.col_box((0, 0, -1), (32, 32, 2))


@asset("SM_Trail_Segment01", "SW_Landscape", "WorldProp", density=4.0, pivot=GROUND, footprint=[4, 12],
       use="Dirt trail strip with a log edge and stones (12 long). Decal-like; sits 0.05 above ground.")
def trail_segment(m):
    m.box("dirt", (3.4, 12, 0.1), loc=(0, 0, 0.05))
    m.sweep("bark", [(2.1, -6, 0.3), (2.3, 0, 0.3), (2.0, 6, 0.3)], 0.3, 6, cap_mat="end_grain")
    for i in range(5):
        rock(m, (-2.0, -5 + i * 2.5, 0.15), 0.35, "stone", (1.2, 1, 0.5), subdiv=1)


@asset("SM_Roots01", "SW_Landscape", "WorldProp", density=3.0, pivot=GROUND, footprint=[4, 4],
       use="Surface roots (decor, no collision).")
def roots01(m):
    for k in range(5):
        a = k * 1.25
        m.sweep("bark", [(0, 0, 0.3), (math.cos(a) * 1.4, math.sin(a) * 1.4, 0.25), (math.cos(a + 0.3) * 2.6, math.sin(a + 0.3) * 2.6, 0.02)],
                [0.25, 0.16, 0.05], 5)


@asset("SM_Roots02", "SW_Landscape", "WorldProp", density=3.0, pivot=GROUND, footprint=[5, 3],
       use="Arching roots (decor, no collision).")
def roots02(m):
    for k in range(3):
        y = -1 + k
        m.sweep("bark_dead", [(-2.4, y, 0.0), (-1, y + 0.2, 0.7), (1, y - 0.2, 0.6), (2.4, y, 0.0)], [0.08, 0.18, 0.16, 0.06], 5)


def flowers(m, cols):
    for i in range(9):
        x, y = m.rng.uniform(-1.2, 1.2), m.rng.uniform(-1.2, 1.2)
        h = m.rng.uniform(0.4, 0.8)
        m.cylinder("fiber", 0.03, 0.02, h, seg=4, loc=(x, y, 0))
        m.blob(cols[i % len(cols)], 0.14, loc=(x, y, h), subdiv=1)
    m.blob("leaves", 0.9, loc=(0, 0, 0.1), scale=(1.4, 1.4, 0.25), subdiv=1)


@asset("SM_Flowers01", "SW_Landscape", "WorldProp", density=2.0, pivot=GROUND, footprint=[3, 3], use="Wildflower clump (warm).")
def flowers01(m):
    flowers(m, ["enamel_amber", "enamel_red", "bandage"])


@asset("SM_Flowers02", "SW_Landscape", "WorldProp", density=2.0, pivot=GROUND, footprint=[3, 3], use="Wildflower clump (cool).")
def flowers02(m):
    flowers(m, ["enamel_purple", "enamel_teal", "bandage"])


@asset("SM_Sapling01", "SW_Landscape", "WorldProp", density=3.0, pivot=GROUND, footprint=[2, 2], use="Young tree (5 studs).")
def sapling01(m):
    m.sweep("bark", [(0, 0, -0.2), (0.1, 0, 2.5), (0, 0.1, 4.6)], [0.14, 0.1, 0.05], 5)
    for z, r in ((2.4, 1.2), (3.4, 1.0), (4.4, 0.7)):
        m.blob("leaves", r, loc=(m.rng.uniform(-0.2, 0.2), m.rng.uniform(-0.2, 0.2), z), scale=(1, 1, 0.7), jitter=0.12)


# Published bounds (Blender lo / hi); the flat low-poly rework is fitted to them.
SW_TREE_BOUNDS = {
    "SM_Tree_Spruce01": ((-6.105, -5.828, -0.408), (6.105, 6.202, 20.002)),
    "SM_Tree_Spruce02": ((-7.21, -6.879, -0.405), (7.21, 7.321, 24.045)),
    "SM_Tree_Aspen01": ((-3.998, -3.945, -0.306), (3.671, 3.595, 18.914)),
}


def _fit(m, name, build):
    lo, hi = SW_TREE_BOUNDS[name]
    build(lo, hi)
    m.fit_bounds(lo, hi)


@asset("SM_Tree_Spruce01", "SW_Landscape", "WorldProp", density=4.0, lod=True, pivot=GROUND, footprint=[9, 9],
       use="Narrow dark spruce (20 studs).")
def spruce01(m):
    _fit(m, "SM_Tree_Spruce01", lambda lo, hi: T.conifer(
        m, lo, hi, T.PALETTES["spruce"], tiers=5, r0=0.55, clear=0.12,
        shape=(1.0, 0.8, 0.62, 0.45, 0.3), heights=[0, 0.22, 0.42, 0.6, 0.76], col=False))


@asset("SM_Tree_Spruce02", "SW_Landscape", "WorldProp", density=4.0, lod=True, pivot=GROUND, footprint=[11, 11],
       use="Broad old spruce (24 studs).")
def spruce02(m):
    _fit(m, "SM_Tree_Spruce02", lambda lo, hi: T.conifer(
        m, lo, hi, T.PALETTES["spruce"], tiers=5, r0=0.7, clear=0.1, seg=12,
        shape=(1.0, 0.82, 0.64, 0.46, 0.3), heights=[0, 0.22, 0.42, 0.6, 0.76], col=False))


@asset("SM_Tree_Aspen01", "SW_Landscape", "WorldProp", density=4.0, lod=True, pivot=GROUND, footprint=[8, 8],
       use="Slim pale aspen with a high round crown (18 studs).")
def aspen01(m):
    _fit(m, "SM_Tree_Aspen01", lambda lo, hi: T.pale_tree(
        m, lo, hi, T.PALETTES["aspen"], r0=0.36, crown_base=0.55, lumps=3, tall=1.1, col=False))


# =============================================================== nodes

@asset("SM_ScrapPile01", "SW_Landscape", "Harvestable", density=2.5, pivot=GROUND, footprint=[5, 4],
       use="Scrap Pile resource node (pickaxe). Yield mesh; hide when mined out.")
def scrap_pile(m):
    m.blob("dirt", 2.2, loc=(0, 0, 0.1), scale=(1.1, 1, 0.2), subdiv=1)
    for i in range(7):
        m.box("metal_dark" if i % 2 else "red_paint", (m.rng.uniform(1.2, 2.2), m.rng.uniform(0.8, 1.6), 0.15),
              loc=(m.rng.uniform(-1.2, 1.2), m.rng.uniform(-1, 1), 0.4 + i * 0.16),
              rot=(m.rng.uniform(-30, 30), m.rng.uniform(-30, 30), m.rng.uniform(0, 180)))
    m.torus("metal_dark", 0.7, 0.14, seg=12, tseg=4, loc=(1.1, 0.6, 0.9), rot=(70, 0, 20))
    m.cylinder("enamel_teal", 0.25, 0.25, 0.6, seg=6, loc=(-1.3, -0.8, 0.2), rot=(90, 0, 30))


def ore(m, seam):
    rock(m, (0, 0, 1.2), 2.2, "stone_dark", (1.1, 0.95, 0.75), jit=0.2)
    for i in range(6):
        a = i * math.tau / 6
        m.blob(seam, 0.45, loc=(math.cos(a) * 1.7, math.sin(a) * 1.5, 1.0 + (i % 3) * 0.4), scale=(1.3, 1, 0.7), jitter=0.08, subdiv=1)


@asset("SM_OreDeposit_Coal", "SW_Landscape", "Harvestable", density=2.5, pivot=GROUND, footprint=[5, 5],
       use="Coal seam node (Stone Pickaxe+).")
def ore_coal(m):
    ore(m, "charcoal")


@asset("SM_OreDeposit_Iron", "SW_Landscape", "Harvestable", density=2.5, pivot=GROUND, footprint=[5, 5],
       use="Iron deposit node (Stone Pickaxe+). Rich veins use this mesh at 1.3x with a glow.")
def ore_iron(m):
    ore(m, "enamel_orange")


# =============================================================== chests

def chest(m, body, trim, glow=False):
    """Chest body only (the lid stays procedural in game so it can open). Bounds are
    locked to the published mesh: X 3.4, depth -1.3..1.175 (+glow), height 2.4."""
    # plank body on four stubby feet, with a base skirt and a top rim
    m.box(body, (3.2, 2.1, 1.35), loc=(0, 0, 0.9), bevel=0.06)
    m.box(body, (3.3, 2.2, 0.22), loc=(0, 0, 0.3), bevel=0.05)
    m.box("wood_dark", (3.36, 2.24, 0.12), loc=(0, 0, 1.54), bevel=0.03)
    for x in (-1.4, 1.4):
        for y in (-0.85, 0.85):
            m.box("wood_dark", (0.36, 0.36, 0.2), loc=(x, y, 0.1), bevel=0.04)
    # plank seams on the long faces
    for z in (0.62, 0.98, 1.3):
        for y in (-1.07, 1.07):
            m.box("wood_dark", (3.1, 0.05, 0.05), loc=(0, y, z))
    # iron corner brackets (L plates) up each vertical edge
    for x in (-1, 1):
        for y in (-1, 1):
            m.box(trim, (0.08, 0.3, 1.3), loc=(x * 1.66, y * 0.97, 0.9), bevel=0.02)
            m.box(trim, (0.3, 0.08, 1.3), loc=(x * 1.53, y * 1.12, 0.9), bevel=0.02)
    # two hoop bands that wrap the (procedural) lid, riveted
    for x in (-1.2, 1.2):
        for y in (-1, 1):
            m.box(trim, (0.3, 0.07, 2.36), loc=(x, y * 1.14, 1.18), bevel=0.02)
        m.box(trim, (0.3, 2.35, 0.07), loc=(x, 0, 2.365), bevel=0.02)
        for y in (-1.18, 1.14):
            for z in (0.5, 1.1, 1.7, 2.2):
                m.box("metal_dark", (0.09, 0.05, 0.09), loc=(x, y if y > 0 else -1.18, z))
    # lock plate + hasp on the front
    m.box(trim, (0.5, 0.2, 0.6), loc=(0, -1.2, 1.5), bevel=0.04)
    m.torus("metal_dark", 0.12, 0.03, seg=8, tseg=4, loc=(0, -1.27, 1.32), rot=(90, 0, 0))
    if glow:
        m.box("glow", (0.5, 0.05, 0.5), loc=(0, -1.33, 0.9))
        m.box(trim, (0.62, 0.04, 0.62), loc=(0, -1.29, 0.9))


@asset("SM_Chest_Common", "SW_Loot", "Structure", density=2.0, pivot=GROUND, footprint=[3.4, 2.2],
       use="Common POI chest body (lid stays procedural so it can open).")
def chest_common(m):
    chest(m, "wood", "metal_dark")


@asset("SM_Chest_Uncommon", "SW_Loot", "Structure", density=2.0, pivot=GROUND, footprint=[3.4, 2.2],
       use="Uncommon POI chest body (painted green, iron trim).")
def chest_uncommon(m):
    chest(m, "crate_paint", "metal")


@asset("SM_Chest_Rare", "SW_Loot", "Structure", density=2.0, pivot=GROUND, footprint=[3.4, 2.2],
       use="Rare POI chest body (blue, brass trim, glowing lock).")
def chest_rare(m):
    chest(m, "enamel_slate", "brass", glow=True)


@asset("SM_Chest_VeryRare", "SW_Loot", "Structure", density=2.0, pivot=GROUND, footprint=[3.4, 2.2],
       use="Very Rare POI chest body (purple, gold trim, glowing lock).")
def chest_veryrare(m):
    chest(m, "enamel_purple", "brass", glow=True)


# =============================================================== POIs (match Landmarks.luau)
# Landmarks use Roblox local coords (x, z); here Blender (x, y) = (-x_roblox, z_roblox).

@asset("SM_POI_Campsite", "SW_POI", "Structure", density=3.0, lod=True, pivot=POI_PIVOT, footprint=[22, 22],
       use="Abandoned campsite (common POI): two tents, fire pit, log seats, crate, backpack.")
def poi_campsite(m):
    fire_pit(m, (0, 1, 0))
    tent(m, (6, -5, 0), rot=-20, mat="cloth")
    tent(m, (-6, -6, 0), rot=15, mat="leather_dark")
    for loc, rot in (((0, 5, 0.55), 0), ((4.5, 2, 0.55), 70)):
        m.cylinder("bark", 0.55, 0.55, 4, seg=8, loc=loc, rot=(0, 90, rot), cap="end_grain")
    crate(m, (-3, -2, 0), 0.8)
    m.blob("cloth_dark", 0.8, loc=(3, -1, 0.8), scale=(0.8, 0.6, 1.1), subdiv=1)


@asset("SM_POI_Shed", "SW_POI", "Structure", density=3.0, pivot=POI_PIVOT, footprint=[10, 8],
       use="Tool shed (common POI), 8x6, lean-to tin roof.")
def poi_shed(m):
    room(m, 8, 6, 6.5, "wood_dark", door_w=5, door_h=6)
    m.box("metal_dark", (9, 7, 0.3), loc=(0, 0, 7.1), rot=(8, 0, 0), bevel=0.05)
    crate(m, (2.5, -1.5, 0.6), 0.7)


@asset("SM_POI_HuntingBlind", "SW_POI", "Structure", density=3.0, pivot=POI_PIVOT, footprint=[9, 9],
       use="Raised hunting blind (common POI): platform at 6 studs, camouflage screens, ladder at +Y.")
def poi_blind(m):
    for x in (-2.6, 2.6):
        for y in (-2.6, 2.6):
            m.cylinder("bark", 0.3, 0.28, 6, seg=6, loc=(x, y, 0))
    for y in (-2.6, 2.6):                                    # cross bracing
        m.box("wood_dark", (5.6, 0.18, 0.25), loc=(0, y, 3.0), rot=(0, 38, 0))
    m.box("wood", (6.4, 6.4, 0.5), loc=(0, 0, 6), bevel=0.05)
    # screens: slatted planks with brush woven in (same volumes as the colliders)
    for c, sz in (((0, -3, 7.4), (6.4, 0.3, 2.4)), ((3, 0, 7.4), (0.3, 6.4, 2.4)), ((-3, 0, 7.4), (0.3, 6.4, 2.4))):
        along_x = sz[0] > sz[1]
        L = sz[0] if along_x else sz[1]
        n = int(L / 0.7)
        for k in range(n):
            o = -L / 2 + 0.35 + k * (L - 0.7) / (n - 1)
            h = 2.4 - (k % 3) * 0.18
            loc = (c[0] + (o if along_x else 0), c[1] + (0 if along_x else o), c[2] - (2.4 - h) / 2)
            m.box("wood_dark" if k % 2 else "wood", (0.55, 0.22, h) if along_x else (0.22, 0.55, h), loc=loc)
        m.box("wood_dark", (sz[0], sz[1], 0.2), loc=(c[0], c[1], 7.9))
        for k in range(4):
            o = -L / 2 + 0.9 + k * (L - 1.8) / 3
            m.blob("leaves_dark" if k % 2 else "leaves", 0.5, loc=(c[0] + (o if along_x else 0), c[1] + (0 if along_x else o), 7.1 + (k % 2) * 0.5),
                   scale=(1.2, 0.3, 0.8) if along_x else (0.3, 1.2, 0.8), subdiv=1)
    truss_ladder(m, (0, 3.6, 0), 6)


@asset("SM_POI_BrokenVehicle", "SW_POI", "Structure", density=3.0, lod=True, pivot=POI_PIVOT, footprint=[16, 12],
       use="Rusted pickup truck (common POI), tilted into a ditch; scrap piles nearby are separate nodes.")
def poi_vehicle(m):
    # Same volumes as the Landmarks colliders (chassis, bed, cab, hood, wheels) and the
    # published bounds; now an olive pickup with an open rusted bed, glass, rims and grille.
    rot = -15
    tilt = (0, -6, rot)

    def at(x, y, z):
        a = math.radians(rot)
        return (x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a) - 2, z)
    m.box("metal_dark", (12, 5, 1.2), loc=at(0, 0, 1.4), rot=tilt, bevel=0.1)
    # open bed: floor, side walls, tailgate, rust patches
    m.box("metal_dark", (7, 5, 0.3), loc=at(2.5, 0, 2.15), rot=tilt, bevel=0.05)
    for y in (-2.35, 2.35):
        m.box("crate_paint", (7, 0.3, 2.4), loc=at(2.5, y, 3.2), rot=tilt, bevel=0.08)
        m.box("metal_dark", (6.8, 0.34, 0.25), loc=at(2.5, y, 4.3), rot=tilt)
        for x in (0.2, 4.8):
            m.box("metal_dark", (1.2, 0.34, 0.9), loc=at(x, y, 2.9), rot=tilt)
    m.box("crate_paint", (0.3, 4.9, 2.3), loc=at(5.8, 0, 3.15), rot=tilt, bevel=0.08)
    m.box("crate_paint", (0.3, 4.6, 2.0), loc=at(-0.85, 0, 3.4), rot=tilt)
    for k in range(3):
        m.box("wood_dark", (1.1, 3.6, 0.35), loc=at(1.2 + k * 1.3, 0.2 - k * 0.3, 2.5 + (k % 2) * 0.25), rot=(0, -6 + k * 5, rot + k * 12))
    m.blob("cloth_dark", 0.8, loc=at(4.3, 1.0, 2.8), scale=(1.1, 0.8, 0.5), subdiv=1)
    # cab with windows and a roof
    m.box("crate_paint", (3.6, 4.6, 3.2), loc=at(-3.6, 0, 3.6), rot=tilt, bevel=0.25)
    for y in (-2.32, 2.32):
        m.box("water", (1.8, 0.06, 1.1), loc=at(-3.5, y, 4.3), rot=tilt)
        m.box("metal_dark", (0.12, 0.08, 1.4), loc=at(-2.3, y, 4.2), rot=tilt)
    m.box("crate_paint", (3.3, 4.4, 0.2), loc=at(-3.6, 0, 5.0), rot=tilt, bevel=0.06)
    m.box("water", (0.2, 4, 1.6), loc=at(-5.4, 0, 4.2), rot=(0, -21, rot))
    m.box("metal_dark", (0.3, 4.2, 0.18), loc=at(-5.3, 0, 3.35), rot=tilt)
    # hood, grille, bumper, headlights
    m.box("crate_paint", (2.6, 4.6, 1.6), loc=at(-6.6, 0, 2.6), rot=tilt, bevel=0.2)
    m.box("metal_dark", (2.3, 3.2, 0.1), loc=at(-6.6, 0, 3.42), rot=tilt)
    for k in range(5):
        m.box("metal", (0.12, 0.3, 1.0), loc=at(-7.92, -1.2 + k * 0.6, 2.5), rot=tilt)
    m.box("metal", (0.4, 5.2, 0.6), loc=at(-8, 0, 1.8), rot=tilt, bevel=0.06)
    for y in (-1.8, 1.8):
        m.box("enamel_amber", (0.1, 0.6, 0.4), loc=at(-7.95, y, 2.6), rot=tilt)
    # wheels: tyre + rim + hub; the front-left one is flat and sunk
    for x in (-4, 4):
        for y in (-2.6, 2.6):
            flat = x == -4 and y < 0
            z = 0.9 if flat else 1.1
            m.cylinder("charcoal", 1.1, 1.1, 1.0, seg=12, loc=at(x, y, z), rot=(90, 0, rot), scale=(1, 0.82 if flat else 1, 1))
            out = 1 if y > 0 else -1
            m.cylinder("metal", 0.62, 0.62, 0.12, seg=10, loc=at(x, y + out * 0.02, z), rot=(90, 0, rot))
            m.cylinder("metal_dark", 0.22, 0.22, 0.18, seg=8, loc=at(x, y + out * 0.05, z), rot=(90, 0, rot))
    # weeds growing through
    for k in range(5):
        m.cone("grass", 0.25, 1.2 + (k % 3) * 0.3, seg=4, loc=at(-2 + k * 1.8, 2.9 - (k % 2) * 5.6, 0))


@asset("SM_POI_SmallCabin", "SW_POI", "Structure", density=3.0, lod=True, pivot=POI_PIVOT, footprint=[13, 11],
       use="Small log cabin (common POI), 10x8 with windows, porch, stove pipe.")
def poi_small_cabin(m):
    room(m, 10, 8, 7.5, "bark", window=True)
    gable(m, 10, 8, 7.5)
    m.cylinder("metal_dark", 0.3, 0.3, 3, seg=6, loc=(-3, -2, 8.5))
    m.box("wood_dark", (10, 2.4, 0.4), loc=(0, 5.2, 0.2))


@asset("SM_POI_Cabin", "SW_POI", "Structure", density=3.0, lod=True, pivot=POI_PIVOT, footprint=[18, 14],
       use="Log cabin (uncommon POI), 14x10, stone chimney, porch.")
def poi_cabin(m):
    room(m, 14, 10, 8, "bark", window=True)
    gable(m, 14, 10, 8)
    m.box("wood_dark", (14, 3, 0.4), loc=(0, 6.4, 0.2))
    for x in (-6.6, 6.6):
        m.cylinder("bark", 0.25, 0.25, 7, seg=6, loc=(x, 7.6, 0))
    # stacked-stone chimney (square, capped) instead of a mossy tube through the roof
    for k in range(11):
        w = 1.8 - (0.3 if k > 7 else 0)
        m.box("stone" if k % 2 else "stone_dark", (w, w, 1.0), loc=(5, -4, 0.5 + k), rot=(0, 0, (k % 3 - 1) * 3), bevel=0.06)
    m.box("stone_dark", (1.7, 1.7, 0.25), loc=(5, -4, 10.9))


@asset("SM_POI_RangerStation", "SW_POI", "Structure", density=3.0, lod=True, pivot=POI_PIVOT, footprint=[20, 16],
       use="Ranger station (uncommon POI): green office 14x11 + lookout on stilts behind, flagpole.")
def poi_ranger(m):
    room(m, 14, 11, 8, "crate_paint", window=True)
    gable(m, 14, 11, 8, "metal_dark")
    for x in (-2.4, 2.4):
        for y in (-8, -12.8):
            m.cylinder("wood_dark", 0.3, 0.3, 12, seg=6, loc=(x, y, 0))
    m.box("wood", (6, 6, 0.5), loc=(0, -10.4, 12))
    truss_ladder(m, (-3.8, -10.4, 0), 12, rot=90)
    m.cylinder("metal", 0.15, 0.15, 12, seg=6, loc=(-8, 6, 0))
    m.box("team_cloth", (0.1, 2.6, 1.6), loc=(-8, 7.4, 11))


@asset("SM_POI_LoggingCamp", "SW_POI", "Structure", density=3.0, lod=True, pivot=POI_PIVOT, footprint=[24, 24],
       use="Logging camp (uncommon POI): small shed, stacked logs, sawhorse.")
def poi_logging(m):
    room(m, 8, 7, 6.5, "wood_dark", ox=6, oy=-5)
    gable(m, 8, 7, 6.5, "metal_dark", ox=6, oy=-5)
    for row in range(3):
        for i in range(4 - row):
            m.cylinder("bark", 0.65, 0.65, 9, seg=8, loc=(-6 - (i - (3 - row) / 2) * 1.35, 0.5, 0.65 + row * 1.15),
                       rot=(90, 0, 0), cap="end_grain")
    m.box("wood_dark", (0.4, 3, 2.4), loc=(-3, 5, 1.2))


@asset("SM_POI_AbandonedHouse", "SW_POI", "Structure", density=3.0, lod=True, pivot=POI_PIVOT, footprint=[22, 18],
       use="Ruined two-room house (uncommon POI): collapsed side wall and half the roof.")
def poi_house(m):
    room(m, 16, 12, 8.5, "wood_dark", window=True, broken=("left",))
    gable(m, 16, 12, 8.5, "wood_dark", broken=True)
    m.box("wood_dark", (0.6, 5, 8.5), loc=(0, -3.2, 4.25))
    for i in range(5):
        rock(m, (-6 + i * 0.8, -4, 0.4), 0.6, "stone", (1.3, 1, 0.5), subdiv=1)


@asset("SM_POI_MineEntrance", "SW_POI", "Structure", density=3.5, lod=True, pivot=POI_PIVOT, footprint=[18, 14],
       use="Timbered mine mouth in a rock mound (uncommon POI), rails and a cart outside.")
def poi_mine(m):
    for i in range(6):
        a = math.radians(-150 + i * 60)
        rock(m, (-math.cos(a) * 5, -3 + math.sin(a) * 3, 2.4), 3.2, "stone_dark", (1, 1, 0.9), jit=0.25)
    for x in (-2.8, 2.8):
        m.box("wood_dark", (0.8, 0.8, 7), loc=(x, 2, 3.5))
    m.box("wood_dark", (6.8, 0.9, 0.9), loc=(0, 2, 7.2))
    m.box("charcoal", (4.8, 0.2, 6.4), loc=(0, 1.2, 3.3))
    # name board on the header, knee braces and a hanging lantern
    m.box("sign_blank", (3.0, 0.12, 0.7), loc=(0, 2.52, 7.2))           # weathered name board
    for sx in (-1, 1):
        m.box("wood_dark", (0.35, 0.5, 2.2), loc=(sx * 2.1, 2.3, 6.2), rot=(0, sx * 40, 0))
    m.cylinder("metal_dark", 0.03, 0.03, 0.6, seg=4, loc=(1.6, 2.5, 6.1))
    m.box("glow", (0.3, 0.3, 0.45), loc=(1.6, 2.5, 5.9))
    m.box("metal_dark", (0.4, 0.4, 0.08), loc=(1.6, 2.5, 6.16))
    # track: two rails on sleepers
    for x in (-0.9, 0.9):
        m.box("metal_dark", (0.2, 10, 0.2), loc=(x, 6.5, 0.1))
    for k in range(9):
        m.box("wood_dark", (2.5, 0.45, 0.12), loc=(0, 2.0 + k * 1.15, 0.06), rot=(0, 0, (k % 3 - 1) * 3))
    # ore cart: tapered steel tub on a frame with four wheels, heaped with ore
    m.box("metal_dark", (2.0, 2.6, 0.3), loc=(0, 8, 0.75))
    for x in (-0.9, 0.9):
        for y in (7.0, 9.0):
            m.cylinder("metal", 0.35, 0.35, 0.2, seg=8, loc=(x * 1.05, y, 0.4), rot=(0, 90, 0))
    m.lathe("red_paint", [(0.95, 0.9), (1.2, 2.0)], 4, loc=(0, 8, 0), rot=(0, 0, 45), scale=(1.0, 1.25, 1))
    m.box("metal_dark", (2.4, 3.0, 0.1), loc=(0, 8, 1.95))
    for i in range(4):
        m.blob("stone_dark", 0.45, loc=(-0.5 + (i % 2) * 0.9, 7.4 + (i // 2) * 1.1, 1.85), scale=(1, 1, 0.6), subdiv=1)


@asset("SM_POI_Bunker", "SW_POI", "Structure", density=3.5, lod=True, pivot=POI_PIVOT, footprint=[18, 16],
       use="Half-buried concrete bunker (rare POI): thick walls, mossy slab, sandbags.")
def poi_bunker(m):
    room(m, 13, 11, 7, "stone", t=1.4, door_w=5, door_h=6.4, floor_mat="stone")
    m.box("stone", (14.6, 12.6, 1.4), loc=(0, 0, 7.7), bevel=0.2)
    # moss creeping over the slab in patches, not a green lid
    for i, (x, y, r) in enumerate(((-4.5, -3.5, 2.6), (3.8, 2.6, 2.2), (-1, 4.2, 1.6), (5, -4.2, 1.4), (-5.8, 3.4, 1.2))):
        m.blob("moss", r, loc=(x, y, 8.4), scale=(1.2, 0.9, 0.07), subdiv=1)
    for x in (-6.9, 6.9):                                    # moss dripping over the edges
        m.box("moss", (0.12, 3.0, 1.0), loc=(x * 1.045, -2 if x < 0 else 2, 7.6))
    # steel door frame, lamp cage and a vent
    for x in (-2.7, 2.7):
        m.box("metal_dark", (0.4, 0.4, 6.6), loc=(x, 5.4, 3.3))
    m.box("metal_dark", (5.8, 0.4, 0.4), loc=(0, 5.4, 6.6))
    m.box("glow", (0.5, 0.3, 0.3), loc=(0, 5.62, 6.1))
    m.box("metal_dark", (1.6, 0.3, 0.8), loc=(4.5, 5.55, 5.0))
    for k in range(3):
        m.box("metal", (1.4, 0.32, 0.08), loc=(4.5, 5.56, 4.8 + k * 0.2))
    # sandbag wall in two courses
    for i in range(-2, 3):
        m.blob("cloth", 0.9, loc=(-i * 2.1, 8.2, 0.4), scale=(1.1, 0.55, 0.45), subdiv=1)
    for i in range(-1, 2):
        m.blob("cloth_dark", 0.9, loc=(-i * 2.1 - 1.05, 8.2, 1.1), scale=(1.1, 0.55, 0.42), subdiv=1)


@asset("SM_POI_Outpost", "SW_POI", "Structure", density=3.5, lod=True, pivot=POI_PIVOT, footprint=[30, 30],
       use="Abandoned outpost (rare POI): palisade ring open at +Y, tents, small watch deck, fire pit.")
def poi_outpost(m):
    for i in range(18):
        a = math.radians(i * 20)
        x, y = -math.sin(a) * 13, -math.cos(a) * 13
        if y < 9:
            m.cylinder("bark", 0.55, 0.5, 7, seg=6, loc=(x, y, 0))
            m.cone("wood_fresh", 0.5, 1, seg=6, loc=(x, y, 7))
    for x in (-4, 4):
        tent(m, (x, -4, 0), mat="cloth")
    for x in (-1.6, 1.6):
        for y in (-8.4, -11.6):
            m.cylinder("wood_dark", 0.3, 0.3, 9, seg=6, loc=(-7 + x, y, 0))
    m.box("wood", (4.4, 4.4, 0.4), loc=(-7, -10, 9))
    fire_pit(m, (0, 2, 0))


@asset("SM_POI_IndustrialSite", "SW_POI", "Structure", density=4.0, lod=True, pivot=POI_PIVOT, footprint=[34, 30],
       use="Derelict industrial yard (rare POI): steel shed, two containers, fuel tank, barrels.")
def poi_industrial(m):
    # steel shed (beams, ribbed back wall, roof with purlins underneath)
    for x in (-9, 0, 9):
        for y in (-8, 4):
            m.box("metal_dark", (0.8, 0.8, 10), loc=(x, y, 5))
        m.box("metal_dark", (0.5, 12.4, 0.5), loc=(x, -2, 9.75))
    m.box("metal_dark", (20, 14, 0.6), loc=(0, -2, 10.3))
    m.box("metal", (19, 0.6, 9), loc=(0, -8.6, 4.5))
    for k in range(-9, 10):
        m.box("metal_dark", (0.25, 0.3, 9), loc=(k, -8.2, 4.5))
    # shipping containers: corrugated walls, end doors with lock bars
    for cx, cy, rz, mat in ((14, 2, 0, "red_paint"), (-14, 0, -8, "enamel_slate")):
        a = math.radians(rz)

        def at(x, y, z):
            return (cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a), z)
        m.box(mat, (5.7, 14, 5.8), loc=at(0, 0, 2.95), rot=(0, 0, rz), bevel=0.06)
        for k in range(14):
            for sx in (-1, 1):
                m.box(mat, (0.3, 0.45, 5.4), loc=at(sx * 2.85, -6.4 + k * 0.98, 2.95), rot=(0, 0, rz))
        m.box("metal_dark", (6, 14, 0.2), loc=at(0, 0, 5.9), rot=(0, 0, rz))
        m.box("metal_dark", (6, 14, 0.25), loc=at(0, 0, 0.12), rot=(0, 0, rz))
        for sx in (-1, 1):
            m.box("metal_dark", (0.06, 0.1, 5.4), loc=at(0, 7.02, 2.95), rot=(0, 0, rz))
            for x in (sx * 0.8, sx * 2.0):
                m.box("metal", (0.12, 0.12, 5.2), loc=at(x, 7.05, 2.95), rot=(0, 0, rz))
    # fuel tank with ladder, hatch and a pipe run
    m.cylinder("enamel_orange", 2.5, 2.5, 8, seg=16, loc=(6, 11, 0))
    m.cylinder("metal_dark", 2.45, 2.45, 0.3, seg=16, loc=(6, 11, 8))
    m.cylinder("metal", 0.5, 0.5, 0.3, seg=8, loc=(6, 11, 8.3))
    truss_ladder(m, (6, 8.4, 0), 8)
    m.cylinder("metal_dark", 0.2, 0.2, 5, seg=6, loc=(3.5, 11, 0.6), rot=(0, -90, 0))
    # barrel cluster (ribbed drums, one tipped) and pallet stack
    for i, (x, y, tip) in enumerate(((-5, 9, 0), (-3.7, 9.2, 0), (-4.4, 10.3, 0), (-2.2, 9.8, 1))):
        mat = "crate_paint" if i % 2 else "enamel_red"
        if tip:
            m.cylinder(mat, 0.6, 0.6, 1.8, seg=10, loc=(x, y, 0.6), rot=(0, 90, 30))
        else:
            m.cylinder(mat, 0.6, 0.6, 1.8, seg=10, loc=(x, y, 0))
            for z in (0.45, 1.35):
                m.torus("metal_dark", 0.6, 0.04, seg=10, tseg=4, loc=(x, y, z))
    for k in range(3):
        m.box("wood_fresh" if k % 2 else "wood", (3.6, 3.6, 0.45), loc=(2, -5, 0.25 + k * 0.5), rot=(0, 0, k * 6))
    crate(m, (-4, -4, 0), 0.9)
    crate(m, (-4.5, -4.2, 1.8), 0.7, 20)


@asset("SM_POI_LargeMine", "SW_POI", "Structure", density=3.5, lod=True, pivot=POI_PIVOT, footprint=[22, 20],
       use="Large mine (rare POI): mine mouth + wooden headframe with wheel + ore shed.")
def poi_large_mine(m):
    poi_mine(m)
    for x in (8, 4):
        m.box("wood_dark", (0.7, 0.7, 12), loc=(x, -6, 6))
    m.torus("metal_dark", 1.4, 0.18, seg=14, tseg=4, loc=(6, -6, 12), rot=(0, 90, 0))
    m.box("wood_dark", (6, 5, 5), loc=(-8, -2, 2.5), bevel=0.1)


# =============================================================== tools

def haft(m, length=2.9):
    m.sweep("wood", [(0, 0, -0.7), (0, 0.03, 0.8), (0, 0.0, length - 0.6), (0, -0.05, length)],
            [0.12, 0.11, 0.105, 0.1], 7, cap_mat="end_grain")
    m.lathe("leather_stitch", [(0.14, -0.35), (0.155, -0.2), (0.155, 0.45), (0.14, 0.6)], 8)


@asset("SM_Pickaxe_Stone", "SW_Tools", "Equippable", density=HELD, pivot=TOOL_PIVOT,
       use="Crude/Stone Pickaxe (tinted by tier in game). Tool > Handle.")
def pickaxe_stone(m):
    haft(m)
    for s in (-1, 1):
        m.cone("stone_dark", 0.2, 1.1, seg=5, loc=(0, 0, 2.55), rot=(s * 90, 0, 0))
    m.box("stone", (0.36, 0.5, 0.4), loc=(0, 0, 2.55), bevel=0.06)
    for z in (2.35, 2.75):
        m.torus("rope", 0.19, 0.045, seg=10, tseg=4, loc=(0, 0, z))


@asset("SM_Pickaxe_Iron", "SW_Tools", "Equippable", density=HELD, pivot=TOOL_PIVOT,
       use="Iron/Steel Pickaxe. Tool > Handle.")
def pickaxe_iron(m):
    haft(m)
    m.sweep("metal", [(0, -1.3, 2.35), (0, -0.6, 2.62), (0, 0, 2.7), (0, 0.6, 2.62), (0, 1.3, 2.35)], [0.03, 0.14, 0.18, 0.14, 0.03], 6)
    m.box("metal_dark", (0.3, 0.3, 0.4), loc=(0, 0, 2.6))


@asset("SM_Axe_Iron", "SW_Tools", "Equippable", density=HELD, pivot=TOOL_PIVOT,
       use="Iron/Steel Axe. Tool > Handle.")
def axe_iron(m):
    haft(m)
    m.prism("metal", [(-0.3, -0.1), (1.0, -0.5), (1.1, 0.55), (-0.3, 0.3)], 0.22, loc=(0, 0, 2.25), rot=(0, 0, -90))
    m.box("metal_dark", (0.3, 0.36, 0.5), loc=(0, 0.3, 2.3))


@asset("SM_Crowbar", "SW_Tools", "Equippable", density=HELD, pivot=TOOL_PIVOT,
       use="Crowbar (breaching tool). Tool > Handle.")
def crowbar(m):
    m.sweep("red_paint", [(0, 0, -0.8), (0, 0, 1.8), (0, -0.25, 2.3), (0, -0.6, 2.35)], [0.07, 0.07, 0.07, 0.04], 6)
    m.sweep("metal_dark", [(0, 0, -0.8), (0, 0.25, -1.1)], [0.07, 0.03], 5)
    # worn grip where hands go, bare steel showing through the chipped paint at the claw
    m.lathe("leather_dark", [(0.085, -0.2), (0.09, -0.1), (0.09, 0.8), (0.085, 0.9)], 7)
    m.sweep("metal", [(0, -0.3, 2.33), (0, -0.58, 2.35)], [0.05, 0.035], 5)


@asset("SM_Sledgehammer", "SW_Tools", "Equippable", density=HELD, pivot=TOOL_PIVOT,
       use="Sledgehammer (breaching tool, heavy vs walls). Tool > Handle.")
def sledge(m):
    haft(m, 3.4)
    # forged head: octagonal-ish block with bevelled striking faces and a steel collar
    m.box("metal_dark", (0.6, 1.1, 0.6), loc=(0, 0, 3.2), bevel=0.1)
    for s in (-1, 1):
        m.cylinder("metal", 0.27, 0.24, 0.2, seg=8, loc=(0, s * 0.55, 3.2), rot=(-s * 90, 0, 0))
    m.box("gunmetal", (0.6, 0.3, 0.58), loc=(0, 0, 3.2), bevel=0.04)


@asset("SM_HuntingBow", "SW_Tools", "Equippable", density=HELD, pivot=GUNLIKE_PIVOT,
       use="Hunting Bow (Tier III). Draw along -Z.")
def hunting_bow(m):
    m.sweep("wood_dark", [(0, 0.3, -2.4), (0, -0.2, -1.2), (0, 0, 0), (0, -0.2, 1.2), (0, 0.3, 2.4)],
            [0.05, 0.1, 0.12, 0.1, 0.05], 6)
    m.lathe("leather_stitch", [(0.14, -0.35), (0.15, 0.35)], 8, rot=(0, 0, 0))
    m.cylinder("rope", 0.02, 0.02, 4.6, seg=4, loc=(0, 0.45, -2.3))


@asset("SM_Crossbow", "SW_Tools", "Equippable", density=HELD, pivot=GUNLIKE_PIVOT,
       use="Crossbow (Tier IV). Points along -Z; bolts.")
def crossbow(m):
    # stock with a butt plate, trigger guard and a loaded bolt
    m.box("wood", (0.35, 3.0, 0.35), loc=(0, -0.9, 0.35), bevel=0.05)
    m.box("wood_dark", (0.4, 0.8, 0.8), loc=(0, 0.2, 0), bevel=0.06)
    m.box("metal_dark", (0.42, 0.1, 0.8), loc=(0, 0.55, 0))
    m.box("metal_dark", (0.12, 0.35, 0.05), loc=(0, -0.05, 0.13))
    m.torus("metal_dark", 0.14, 0.025, seg=8, tseg=4, loc=(0, -0.05, 0.06), rot=(0, 90, 0))
    m.sweep("metal_dark", [(-1.6, -2.4, 0.45), (0, -2.3, 0.45), (1.6, -2.4, 0.45)], [0.05, 0.1, 0.05], 5)
    m.cylinder("rope", 0.02, 0.02, 3.2, seg=4, loc=(-1.6, -2.0, 0.5), rot=(0, 90, 0))
    m.cylinder("wood_fresh", 0.035, 0.035, 2.0, seg=5, loc=(0, -0.2, 0.49), rot=(90, 0, 0))
    m.cone("metal", 0.05, 0.2, seg=4, loc=(0, -2.2, 0.49), rot=(90, 0, 0))


# =============================================================== base pieces

@asset("SM_ReinforcedChest", "SW_Base", "Structure", density=2.0, pivot=GROUND, footprint=[6, 4],
       use="Reinforced Chest storage (Tier II, 20 stacks).")
def reinforced_chest(m):
    m.box("wood_dark", (6, 4, 3.2), loc=(0, 0, 1.6), bevel=0.1)
    m.box("wood", (6.2, 4.2, 1.0), loc=(0, 0, 3.7), bevel=0.1)
    for x in (-2, 0, 2):
        m.box("metal_dark", (0.4, 4.3, 4.3), loc=(x, 0, 2.15))


@asset("SM_MetalLocker", "SW_Base", "Structure", density=2.0, pivot=GROUND, footprint=[4, 3],
       use="Metal Locker storage (Tier III, 30 stacks).")
def metal_locker(m):
    # bounds locked: X +-2, Y -1.7..1.5, Z 0..7
    m.box("enamel_slate", (4, 3, 6.7), loc=(0, 0, 3.5), bevel=0.08)
    m.box("metal_dark", (3.9, 2.9, 0.3), loc=(0, 0, 0.15), bevel=0.04)       # kick plate
    m.box("metal_dark", (4, 3, 0.18), loc=(0, 0, 6.91), bevel=0.04)          # top lip
    m.box("metal_dark", (0.06, 0.08, 6.2), loc=(0, -1.52, 3.55))             # double-door seam
    for sx in (-1, 1):
        for z in (6.1, 5.85, 5.6, 1.4, 1.15):                                  # louvre vents
            m.box("metal_dark", (1.3, 0.1, 0.1), loc=(sx * 1.0, -1.55, z))
        m.box("metal", (0.22, 0.1, 0.12), loc=(sx * 1.87, -1.55, 5.4))        # hinges
        m.box("metal", (0.22, 0.1, 0.12), loc=(sx * 1.87, -1.55, 1.8))
        m.box("brass", (0.14, 0.2, 0.8), loc=(sx * 0.3, -1.6, 3.5), bevel=0.03)  # handles
    m.box("sign_blank", (0.9, 0.04, 0.5), loc=(-1.0, -1.52, 4.6))  # name card


@asset("SM_SurvivalSafe", "SW_Base", "Structure", density=2.0, pivot=GROUND, footprint=[4.5, 4.5],
       use="Survival Safe storage (Tier IV, 45 stacks).")
def survival_safe(m):
    # bounds locked: X +-2.25, Y -2.55..2.25, Z 0..5
    m.box("gunmetal", (4.5, 4.5, 4.7), loc=(0, 0, 2.65), bevel=0.15)
    for x in (-1.9, 1.9):
        for y in (-1.9, 1.9):
            m.box("metal_dark", (0.5, 0.5, 0.3), loc=(x, y, 0.15), bevel=0.05)    # feet
    m.box("metal_dark", (3.7, 0.08, 3.9), loc=(0, -2.28, 2.65), bevel=0.05)       # door plate
    for z in (1.3, 4.0):
        m.cylinder("metal", 0.12, 0.12, 0.7, seg=8, loc=(2.05, -2.3, z - 0.35))  # hinge barrels
    m.cylinder("brass", 0.7, 0.7, 0.2, seg=16, loc=(-0.8, -2.3, 2.8), rot=(90, 0, 0))
    m.cylinder("metal_dark", 0.35, 0.35, 0.14, seg=12, loc=(-0.8, -2.4, 2.8), rot=(90, 0, 0))
    for k in range(3):                                                              # locking wheel spokes
        m.box("metal", (0.08, 0.1, 1.3), loc=(0.9, -2.4, 2.6), rot=(0, k * 60, 0))
    m.cylinder("metal", 0.14, 0.14, 0.2, seg=8, loc=(0.9, -2.33, 2.6), rot=(90, 0, 0))
    m.box("metal", (0.4, 0.3, 1.4), loc=(1.1, -2.3, 2.6))
    m.box("metal_dark", (0.3, 0.1, 0.3), loc=(1.1, -2.5, 2.6))


@asset("SM_ScrapWall", "SW_Base", "Structure", density=3.0, pivot=GROUND, footprint=[10, 2],
       use="Scrap Wall (Tier III): corrugated sheets on a timber frame, 10 wide.")
def scrap_wall(m):
    # same frame and sheet layout as the published mesh (bounds locked); sheets are
    # now mostly weathered metal with one faded red panel, ribbed and bolted
    for x in (-4.6, 0, 4.6):
        m.box("wood_dark", (0.8, 0.8, 10.4), loc=(x, -0.6, 5.2), bevel=0.05)
    mats = ["metal_dark", "metal", "red_paint", "gunmetal", "metal_dark"]
    for i in range(5):
        rot = (0, (i % 3 - 1) * 2, 0)
        x = -4 + i * 2
        m.box(mats[i], (2.3, 0.3, 9.4), loc=(x, 0.2, 5), rot=rot)
        for k in (-0.7, 0, 0.7):
            m.box("metal_dark", (0.12, 0.1, 9.2), loc=(x + k, 0.0, 5), rot=rot)
        for z in (1.2, 8.6):
            m.box("metal", (0.14, 0.06, 0.14), loc=(x, 0.33, z), rot=rot)
    m.box("wood_dark", (10.2, 0.5, 0.5), loc=(0, -0.6, 8.6))
    m.box("wood_dark", (10.2, 0.5, 0.5), loc=(0, -0.6, 1.6))


@asset("SM_MetalWall", "SW_Base", "Structure", density=3.0, pivot=GROUND, footprint=[10, 2.6],
       use="Metal Wall (Tier IV): riveted plates between beams, 10 wide.")
def metal_wall(m):
    for row in range(3):
        for i in range(2):
            x, z = -2.5 + i * 5, 1.9 + row * 3.6
            m.box("gunmetal" if (row + i) % 2 else "metal_dark", (4.9, 1.6, 3.5), loc=(x, 0, z), bevel=0.1)
            for sy in (-1, 1):
                for dx in (-2.1, 2.1):
                    for dz in (-1.45, 1.45):
                        m.box("metal", (0.16, 0.08, 0.16), loc=(x + dx, sy * 0.82, z + dz))
                m.box("metal_dark", (4.3, 0.08, 0.18), loc=(x, sy * 0.82, z))
    for x in (-5, 5):
        m.box("metal_dark", (0.8, 2.6, 11), loc=(x, 0, 5.5), bevel=0.05)
    m.box("metal_dark", (9.2, 2.0, 0.4), loc=(0, 0, 10.8))


@asset("SM_WoodFloor", "SW_Base", "Structure", density=3.0, pivot=GROUND, footprint=[10, 10],
       use="Wooden Floor (Tier I), 10x10 platform.")
def wood_floor(m):
    for i in range(8):
        m.box("wood" if i % 2 else "wood_fresh", (10, 1.2, 0.5), loc=(0, -4.4 + i * 1.26, 0.75), bevel=0.04)
    for x in (-4.4, 4.4):
        m.box("wood_dark", (0.6, 10, 0.6), loc=(x, 0, 0.3))


@asset("SM_BearTrap", "SW_Base", "Structure", density=1.5, pivot=GROUND, footprint=[3, 3],
       use="Bear Trap (Tier III), set.")
def bear_trap(m):
    m.cylinder("metal_dark", 0.8, 0.8, 0.2, seg=12)
    for s in (-1, 1):
        m.torus("metal", 1.2, 0.08, seg=14, tseg=4, loc=(0, s * 0.4, 0.2), arc=180, rot=(0, 0, 90 * (1 + s)))
        for k in range(7):
            a = k * math.pi / 6
            m.cone("metal", 0.08, 0.3, seg=4, loc=(math.cos(a) * 1.2, s * 0.4 + math.sin(a) * 0.1, 0.25))


@asset("SM_Snare", "SW_Base", "Structure", density=1.5, pivot=GROUND, footprint=[3, 3],
       use="Snare (Tier II): rope loop on a bent sapling.")
def snare(m):
    m.torus("rope", 1.2, 0.06, seg=14, tseg=4, loc=(0, 0, 0.08))
    m.sweep("bark", [(1.4, 0, 0), (1.8, 0, 2.2), (0.8, 0, 3.2)], [0.12, 0.08, 0.04], 5)


@asset("SM_TripwireAlarm", "SW_Base", "Structure", density=1.5, pivot=GROUND, footprint=[8, 1],
       use="Tripwire Alarm (Tier II): stakes, wire and can rattle.")
def tripwire(m):
    for x in (-3.8, 3.8):
        m.box("wood_dark", (0.3, 0.3, 1.4), loc=(x, 0, 0.7))
    m.cylinder("metal", 0.025, 0.025, 7.6, seg=4, loc=(-3.8, 0, 0.6), rot=(0, 90, 0))
    for k in range(3):
        m.cylinder("enamel_teal", 0.18, 0.18, 0.45, seg=6, loc=(3.8, 0.2, 0.9 - k * 0.3))


@asset("SM_Workbench_Level04", "SW_Base", "Structure", density=2.5, pivot=GROUND, footprint=[12, 4],
       use="Workbench Tier IV: stone forge with coals and chimney beside the bench.")
def workbench4(m):
    # bounds locked: X -4..8.1, Y +-2, Z 0..7.7
    m.box("wood", (8, 4, 0.8), loc=(0, 0, 3.4), bevel=0.06)
    for x in (-3.4, 3.4):
        for y in (-1.5, 1.5):
            m.box("wood_dark", (0.7, 0.7, 3), loc=(x, y, 1.5), bevel=0.05)
        m.box("wood_dark", (0.4, 3.2, 0.4), loc=(x, 0, 0.7))
    m.box("wood_dark", (7.2, 3.4, 0.25), loc=(0, 0, 0.95), bevel=0.03)          # lower shelf
    for i, x in enumerate((-2.4, -1.2, 0.2)):                                     # stock on the shelf
        m.box("wood_fresh" if i % 2 else "wood", (1.0, 2.6, 0.3), loc=(x, 0, 1.23 + 0.3 * (i % 2)), rot=(0, 0, 4 * i))
    m.box("metal_dark", (0.9, 0.9, 0.5), loc=(1.6, -1.1, 4.05), bevel=0.05)     # vise
    m.box("metal", (0.2, 0.8, 0.12), loc=(1.6, -1.55, 4.2))
    # rear tool board with pegs (tools hang on it, so nothing floats at Tier V)
    m.box("wood_dark", (5.0, 0.25, 3.4), loc=(-1.2, 1.75, 5.9), bevel=0.04)
    for x in (-3.6, 1.2):
        m.box("wood_dark", (0.3, 0.3, 4.3), loc=(x, 1.75, 5.55))
    for x in (-3.1, -2.1, -1.2, -0.4):
        m.box("metal_dark", (0.08, 0.3, 0.08), loc=(x, 1.55, 7.2))
    # forge: stone hearth with glowing coals, bellows and chimney
    m.box("stone_dark", (3.4, 3, 2.6), loc=(6.4, 0.4, 1.3), bevel=0.15)
    m.box("stone", (3.4, 3.0, 0.25), loc=(6.4, 0.4, 2.6), bevel=0.05)
    m.box("embers", (2.4, 2, 0.3), loc=(6.4, 0.4, 2.7))
    for i in range(4):
        m.blob("charcoal", 0.3, loc=(5.8 + i * 0.4, 0.1 + (i % 2) * 0.5, 2.9), scale=(1, 1, 0.6), subdiv=1)
    m.box("stone", (1.4, 1.4, 5), loc=(6.9, 1.3, 5.2), bevel=0.08)
    m.box("stone_dark", (1.7, 1.4, 0.3), loc=(6.9, 1.3, 7.55))
    m.box("leather_dark", (0.9, 1.4, 0.6), loc=(4.4, -1.0, 3.1), rot=(0, 0, 20), bevel=0.1)  # bellows
    m.box("metal_dark", (0.8, 0.8, 0.9), loc=(4.4, 1.1, 4.25), bevel=0.06)     # anvil block on the bench
    m.box("metal", (1.4, 0.6, 0.35), loc=(4.4, 1.1, 4.85), bevel=0.05)


@asset("SM_Workbench_Level05", "SW_Base", "Structure", density=2.5, pivot=GROUND, footprint=[12, 4],
       use="Workbench Tier V: steel-plated top, tool rack and forge.")
def workbench5(m):
    workbench4(m)
    m.box("metal", (8.1, 4.1, 0.12), loc=(0, 0, 3.86))
    for x in (-3.9, 3.9):
        for y in (-1.9, 1.9):
            m.box("metal_dark", (0.3, 0.3, 0.14), loc=(x, y, 3.93))
    # steel tools hanging from the board's pegs (was floating bars)
    for x, ln in ((-3.1, 2.4), (-2.1, 2.0), (-1.2, 2.6)):
        m.box("metal", (0.22, 0.12, ln), loc=(x, 1.5, 7.15 - ln / 2))
    m.box("metal_dark", (0.7, 0.2, 0.35), loc=(-2.1, 1.5, 5.2))
    m.box("metal_dark", (0.5, 0.2, 0.6), loc=(-1.2, 1.5, 4.6))
