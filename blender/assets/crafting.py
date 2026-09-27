"""Craftable items and structures, workbench levels 1-3.

Building grid: walls and gates are 8 studs wide. Each wall owns the post on
its LEFT end (x = -4, seen from the front / outside). Its right end butts
against the next piece's post. Close a run or a corner with SM_WallPost.
Front (outside, facing enemies) is -Y. Pivot: bottom centre of the 8-stud
span, on the ground.
"""

import math

from mathutils import Vector

from sh.pipeline import asset

WALL_PIVOT = ("Bottom centre of the 8-stud span, on the ground. Snap pieces 8 studs apart along X; "
              "the left post (x=-4) belongs to this piece, the right end meets the next piece's post.")
TOOL_PIVOT = ("Grip point (RightGripAttachment). Handle runs up +Y, striking side faces forward "
              "(-Z). Default Tool.Grip = identity.")
GUNLIKE_PIVOT = ("Grip point (RightGripAttachment). Points forward along -Z (LookVector), up is +Y. "
                 "Default Tool.Grip = identity.")
HELD = 1.5  # studs per atlas tile for held items (higher texel density)


# ------------------------------------------------------------------ helpers

def log_post(m, x, y, h, r, mat="bark", point=True, lean=0.0, seg=8):
    top = Vector((x + lean, y, h))
    m.sweep(mat, [Vector((x, y, -0.3)), Vector((x + lean * 0.5, y, h * 0.5)), top],
            [r, r * 0.97, r * 0.93], seg, cap_mat="end_grain")
    if point:
        m.cone("wood_fresh", r * 0.93, r * 2.2, seg=seg, loc=tuple(top))


def lashing(m, x, y, z, r, turns=1):
    for k in range(turns):
        m.torus("rope", r + 0.05, 0.07, seg=8, tseg=3, loc=(x, y, z + k * 0.16))


def rail(m, x0, x1, y, z, h=0.45, t=0.3, mat="wood_dark"):
    m.box(mat, (x1 - x0, t, h), loc=((x0 + x1) / 2, y, z), bevel=0.05)


def splinter_top(m, x, y, h, r, mat="bark"):
    """Broken log: stump of the post with jagged fresh wood."""
    m.sweep(mat, [Vector((x, y, -0.3)), Vector((x, y, h))], [r, r * 0.97], 8, cap_mat="end_grain")
    for k in range(4):
        a = k * math.tau / 4 + 0.3
        m.cone("wood_fresh", r * 0.45, m.rng.uniform(0.4, 0.9), seg=4,
               loc=(x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45, h - 0.05))


# ------------------------------------------------------------ L1: structures

def palisade(m, damaged=False):
    log_post(m, -4, 0, 8.4, 0.65, point=True)  # owned left post
    xs = [-2.9, -1.75, -0.6, 0.55, 1.7, 2.85]
    for i, x in enumerate(xs):
        h = 7.3 + m.rng.uniform(-0.35, 0.35)
        r = m.rng.uniform(0.5, 0.58)
        if damaged and i in (1, 4):
            splinter_top(m, x, 0, h * m.rng.uniform(0.35, 0.55), r)
        elif damaged and i == 2:
            continue  # log missing: a hole in the wall
        else:
            log_post(m, x, 0, h, r, lean=m.rng.uniform(-0.08, 0.08))
    for z in (1.7, 5.4):
        if damaged and z > 5:
            m.box("wood_dark", (4.0, 0.3, 0.45), loc=(-2.3, 0.72, z + 0.2), rot=(0, -8, 0), bevel=0.05)
        else:
            rail(m, -4.4, 3.9, 0.72, z)
        for x in xs[::2] + [-4]:
            if not (damaged and x == xs[2]):
                lashing(m, x, 0, z - 0.15, 0.58)
    m.col_box((-0.3, 0, 3.8), (8.7, 1.4, 7.6))


@asset("SM_WoodenWall", "Crafting_L1", "Structure", density=3.0, lod=True, pivot=WALL_PIVOT,
       footprint=[8, 1.5], use="Workbench L1. Sharpened log palisade; 7.6 studs tall blocks players.",
       notes="Use COL_WoodenWall (one box) or CollisionFidelity Box. Rails sit on the inside (+Z).")
def wooden_wall(m):
    palisade(m)
    m.attach("SnapLeft", (-4, 0, 0))
    m.attach("SnapRight", (4, 0, 0))


@asset("SM_WoodenWall_Damaged", "Crafting_L1", "Structure", density=3.0, lod=True, pivot=WALL_PIVOT,
       footprint=[8, 1.5], use="Swap in below ~40% health: broken logs, a gap, a fallen rail.")
def wooden_wall_damaged(m):
    palisade(m, damaged=True)


@asset("SM_WallPost", "Crafting_L1", "Structure", density=3.0, pivot="Post centre on the ground.",
       footprint=[1.4, 1.4], use="End cap for wall/gate runs and corners (the missing right-hand post).")
def wall_post(m):
    log_post(m, 0, 0, 8.4, 0.65)
    lashing(m, 0, 0, 1.55, 0.6)
    lashing(m, 0, 0, 5.25, 0.6)
    m.col_box((0, 0, 4.2), (1.3, 1.3, 8.4))


# --------------------------------------------------------------- L1: tools

@asset("SM_StoneAxe", "Crafting_L1", "Equippable", density=HELD, pivot=TOOL_PIVOT,
       use="Workbench L1 tool: chops trees. Tool > Handle.", fidelity="Box")
def stone_axe(m):
    m.sweep("wood", [(0, 0, -0.7), (0, 0.03, 0.8), (0, 0.0, 2.2), (0, -0.05, 2.75)],
            [0.12, 0.11, 0.105, 0.1], 7, cap_mat="end_grain")
    m.lathe("leather_stitch", [(0.14, -0.35), (0.155, -0.2), (0.155, 0.45), (0.14, 0.6)], 8)
    # knapped stone head, edge forward (-Y)
    head = m.prism("stone_dark", [(-0.35, -0.1), (0.95, -0.42), (1.05, 0.5), (-0.35, 0.28)], 0.34,
                   loc=(0, 0, 2.2), rot=(0, 0, -90))
    for v in head:
        fwd = -v.co.y
        if fwd > 0.7:  # thin the cutting edge
            v.co.x *= 0.25
    m.jitter(head, 0.035)
    m.box("stone", (0.3, 0.3, 0.32), loc=(0, 0.35, 2.25), rot=(0, 0, 8), bevel=0.06)
    for k, z in enumerate((1.95, 2.1, 2.5, 2.65)):
        m.torus("rope", 0.19, 0.045, seg=10, tseg=4, loc=(0, 0, z), rot=(0, 12 * (-1) ** k, 0))
    m.sweep("rope", [(0.16, 0.1, 1.95), (0.2, -0.1, 2.35), (0.16, 0.1, 2.7)], 0.04, 4)
    m.sweep("rope", [(-0.16, 0.1, 1.95), (-0.2, -0.1, 2.35), (-0.16, 0.1, 2.7)], 0.04, 4)
    m.attach("Hit", (0, -0.85, 2.3))
    m.meta["r15"] = "RightGripAttachment"


# ---------------------------------------------------------- L1: storage box

def chest_body(m, damaged=False):
    W, D, H = 3.0, 2.0, 1.8
    for x in (-W / 2 + 0.15, W / 2 - 0.15):
        for y in (-D / 2 + 0.15, D / 2 - 0.15):
            m.box("wood_dark", (0.3, 0.3, H), loc=(x, y, H / 2), bevel=0.04)
    for i in range(3):  # side planks (front/back)
        z = 0.3 + i * 0.6
        for y in (-D / 2 + 0.05, D / 2 - 0.05):
            if damaged and i == 1 and y < 0:
                m.box("wood", (1.1, 0.12, 0.5), loc=(-0.8, y, z), rot=(0, 8, 0))
                continue
            m.box("wood", (W - 0.3, 0.12, 0.52), loc=(0, y, z), bevel=0.03)
        for x in (-W / 2 + 0.05, W / 2 - 0.05):
            m.box("wood", (0.12, D - 0.3, 0.52), loc=(x, 0, z), bevel=0.03)
    m.box("wood_dark", (W - 0.3, D - 0.3, 0.12), loc=(0, 0, 0.1))
    for x in (-W / 2 - 0.02, W / 2 + 0.02):  # rope handles
        m.torus("rope", 0.28, 0.06, seg=8, tseg=3, loc=(x, 0, 1.1), rot=(0, 90, 0), arc=180)
    m.col_box((0, 0, H / 2), (W, D, H))


def chest_lid(p, damaged=False):
    W, D = 3.1, 2.1
    p.meta["pivot"] = "Hinge line along the back top edge. Rotate about the part's X axis to open (~-100 deg)."
    for i in range(4):
        y = -D + 0.26 + i * 0.52
        rot = (4, 0, 0) if damaged and i == 1 else (0, 0, 0)
        p.box("wood", (W, 0.5, 0.22), loc=(0, y, 0.11 + (0.12 if damaged and i == 1 else 0)), rot=rot, bevel=0.04)
    for x in (-1.2, 1.2):  # leather hinge straps running over the lid
        p.box("leather_stitch", (0.28, D + 0.1, 0.06), loc=(x, -D / 2 + 0.05, 0.25))
    p.box("metal_dark", (0.35, 0.1, 0.35), loc=(0, -D - 0.02, 0.0), bevel=0.02)  # latch
    p.col_box((0, -D / 2, 0.12), (W, D, 0.25))


@asset("SM_StorageBox", "Crafting_L1", "Structure", density=2.0, pivot="Bottom centre on the ground.",
       footprint=[3, 2], use="Workbench L1: shared team chest. Lid is SM_StorageBox_Lid (hinged).",
       notes="Prompt_Att for the open prompt. Items render at Contents_Att.")
def storage_box(m):
    chest_body(m)
    chest_lid(m.part("SM_StorageBox_Lid", placement=(0, 1.05, 1.8)))
    m.attach("Prompt", (0, -1.4, 2.2))
    m.attach("Contents", (0, 0, 0.9))


@asset("SM_StorageBox_Damaged", "Crafting_L1", "Structure", density=2.0, pivot="Bottom centre on the ground.",
       footprint=[3, 2], use="Damaged chest body (broken front plank). Uses SM_StorageBox_Lid_Damaged.")
def storage_box_d(m):
    chest_body(m, damaged=True)
    chest_lid(m.part("SM_StorageBox_Lid_Damaged", placement=(0, 1.05, 1.8), rot=(-8, 0, 3)), damaged=True)


@asset("SM_Spear", "Crafting_L1", "Equippable", density=HELD, pivot=GUNLIKE_PIVOT,
       use="Workbench L1: wooden spear with knapped stone point. Thrust forward along -Z.")
def spear(m):
    m.sweep("wood", [(0, 2.4, 0), (0, 0, 0.02), (0, -3.6, 0)], [0.1, 0.105, 0.095], 7, cap_mat="end_grain")
    m.lathe("leather_stitch", [(0.12, -0.45), (0.135, -0.3), (0.135, 0.3), (0.12, 0.45)], 8, rot=(90, 0, 0))
    head = m.prism("stone_dark", [(-0.24, 0), (0.24, 0), (0.1, 0.8), (0, 1.25), (-0.1, 0.8)], 0.1,
                   loc=(0, -3.55, 0), rot=(90, 0, 0))
    for v in head:  # thicken the centre ridge
        if abs(v.co.x) < 0.02:
            v.co.z *= 1.8
    m.jitter(head, 0.01)
    for y in (-3.45, -3.3, -3.15):
        m.torus("rope", 0.13, 0.04, seg=8, tseg=3, loc=(0, y, 0), rot=(90, 0, 0))
    m.prism("team_cloth", [(0, 0), (0.12, 0), (0.18, -0.9), (0.02, -0.7)], 0.03, loc=(0.1, -3.0, 0.05),
            rot=(0, 0, 10))
    m.attach("Tip", (0, -4.85, 0))
    m.attach("SecondHand", (0, 1.4, 0))


@asset("SM_RepairHammer", "Crafting_L1", "Equippable", density=HELD, pivot=TOOL_PIVOT,
       use="Workbench L1: wood-and-stone repair mallet for structures.")
def repair_hammer(m):
    m.sweep("wood", [(0, 0, -0.7), (0, 0.02, 0.9), (0, 0, 2.1)], [0.11, 0.1, 0.1], 7, cap_mat="end_grain")
    m.lathe("leather_stitch", [(0.13, -0.35), (0.145, -0.2), (0.145, 0.45), (0.13, 0.6)], 8)
    m.box("wood_dark", (0.5, 1.1, 0.5), loc=(0, -0.05, 2.1), bevel=0.06)  # head block
    v = m.blob("stone", 0.34, loc=(0, -0.7, 2.1), scale=(1.1, 0.8, 1.1), jitter=0.03)
    for z in (1.95, 2.25):
        m.torus("rope", 0.3, 0.05, seg=8, tseg=3, loc=(0, -0.45, z), rot=(0, 0, 0), scale=(1.2, 1.0, 1))
    m.box("leather", (0.54, 0.25, 0.54), loc=(0, 0.35, 2.1), bevel=0.04)
    m.attach("Hit", (0, -1.0, 2.1))


# ------------------------------------------------------------------ debris

@asset("SM_Debris_Splinters", "Crafting_L1", "Debris", density=1.5, pivot="Centre.", fidelity="Box",
       use="Spawn 2-4 copies when a wooden structure takes a hit or breaks; despawn after ~4 s.")
def debris_splinters(m):
    for k in range(4):
        a = k * 1.6
        m.prism("wood_fresh" if k % 2 else "bark", [(-0.35, 0), (0.4, 0.05), (0.1, 0.18)], 0.12,
                loc=(math.cos(a) * 0.4, math.sin(a) * 0.4, 0.08), rot=(0, 0, math.degrees(a)))


@asset("SM_Debris_LogChunk", "Crafting_L1", "Debris", density=2.0, pivot="Centre.", fidelity="Hull",
       use="Broken log section for wall/gate destruction (spawn 3-5).")
def debris_log(m):
    m.cylinder("bark", 0.5, 0.5, 1.6, seg=7, loc=(-0.8, 0, 0.5), rot=(0, 90, 0), cap="end_grain")
    for k in range(3):
        a = k * math.tau / 3
        m.cone("wood_fresh", 0.2, 0.5, seg=4, loc=(0.8, math.cos(a) * 0.25, 0.5 + math.sin(a) * 0.25),
               rot=(0, 90, 0))


@asset("SM_Debris_MetalBand", "Crafting_L1", "Debris", density=1.5, pivot="Centre.",
       use="Bent iron band + bolts for reinforced wall / L3 destruction.")
def debris_metal(m):
    v = m.box("metal_dark", (2.0, 0.08, 0.3), loc=(0, 0, 0.2))
    for vv in v:
        vv.co.y += 0.25 * vv.co.x ** 2
    for x in (-0.6, 0.4):
        m.cylinder("metal", 0.07, 0.07, 0.3, seg=6, loc=(x, 0.2, 0.05))


# --------------------------------------------------------------- L2 items

@asset("SM_Canteen", "Crafting_L2", "Equippable", density=HELD, pivot=GUNLIKE_PIVOT,
       use="Workbench L2: leather canteen with rope strap. Pour_Att at the spout (tilt forward to pour on fires).")
def canteen(m):
    prof = [(0.0, -0.45), (0.35, -0.42), (0.52, -0.2), (0.55, 0.15), (0.45, 0.45), (0.2, 0.62), (0.0, 0.64)]
    m.lathe("leather", prof, 12, loc=(0, -0.3, 0.35), scale=(1, 0.62, 1))
    m.torus("leather_stitch", 0.54, 0.05, seg=16, tseg=3, loc=(0, -0.3, 0.35), rot=(0, 90, 0),
            scale=(1, 1, 0.62))
    # spout angled forward so it reads when pouring
    m.lathe("metal", [(0.13, 0.0), (0.12, 0.25), (0.15, 0.3), (0.15, 0.38)], 8,
            loc=(0, -0.45, 0.93), rot=(-35, 0, 0))
    m.lathe("wood_fresh", [(0.1, 0.0), (0.12, 0.18), (0.0, 0.2)], 8, loc=(0, -0.68, 1.26), rot=(-35, 0, 0))
    m.sweep("rope", [(0, -0.62, 1.2), (0.2, -0.55, 1.05), (0.25, -0.4, 0.95)], 0.03, 3)
    # strap loop
    m.torus("rope", 0.62, 0.05, seg=16, tseg=3, loc=(0, -0.3, 0.8), rot=(0, 90, 0), arc=200,
            scale=(1, 1.2, 1.1))
    m.attach("Pour", (0, -0.82, 1.4), (-35, 0, 0))


def bow_limbs(m, height=4.6):
    h = height / 2
    pts_up = [(0, 0, 0), (0, -0.25, h * 0.4), (0, -0.2, h * 0.8), (0, 0.05, h)]
    pts_dn = [(0, 0, 0), (0, -0.25, -h * 0.4), (0, -0.2, -h * 0.8), (0, 0.05, -h)]
    for pts in (pts_up, pts_dn):
        m.sweep("wood", pts, [0.11, 0.09, 0.065, 0.04], 6, flat=0.7)
    m.lathe("leather_stitch", [(0.12, -0.45), (0.14, -0.35), (0.14, 0.35), (0.12, 0.45)], 8)
    m.sweep("rope", [(0, 0.05, -h + 0.05), (0, 0.18, 0), (0, 0.05, h - 0.05)], 0.025, 3)
    for z in (h - 0.1, -h + 0.1):
        m.torus("rope", 0.06, 0.02, seg=6, tseg=3, loc=(0, 0.05, z))


@asset("SM_Bow", "Crafting_L2", "Equippable", density=HELD, pivot="Grip. Bow stands along +Y (Roblox), "
       "string toward the player (+Z), arrows fly along -Z.",
       use="Workbench L2: handmade wooden bow with a visible string.",
       notes="String is modelled straight (rest). For a draw pose, move Nock_Att back; the string mesh does not bend.")
def bow(m):
    bow_limbs(m)
    m.attach("Nock", (0, 0.18, 0.1))
    m.attach("ArrowRest", (0, -0.15, 0.12))


def arrow(m, loc=(0, 0, 0), rot=(0, 0, 0), length=3.0):
    from sh.kit import xform
    before = set(m.bm.verts)
    L = length
    m.sweep("wood_fresh", [(0, L / 2, 0), (0, -L / 2 + 0.3, 0)], 0.035, 5, cap_mat="end_grain")
    m.prism("stone_dark", [(-0.1, 0), (0.1, 0), (0, 0.35)], 0.04, loc=(0, -L / 2 + 0.3, 0), rot=(90, 0, 0))
    for k, mat in enumerate(("cloth", "team_cloth", "cloth")):
        a = k * 120
        m.prism(mat, [(0, 0), (0.55, 0), (0.45, 0.15), (0.05, 0.13)], 0.015, loc=(0, L / 2 - 0.65, 0),
                rot=(0, a, -90))
    m.torus("rope", 0.045, 0.015, seg=5, tseg=3, loc=(0, -L / 2 + 0.34, 0), rot=(90, 0, 0))
    vs = [v for v in m.bm.verts if v not in before]
    m.transform(vs, xform(loc, rot))


@asset("SM_Arrow", "Crafting_L2", "Projectile", density=HELD, dummy=False,
       pivot="Centre of the shaft. Tip points -Z (flight direction).",
       use="Arrow projectile (one team-coloured fletching). Tip_Att at the point.")
def arrow_single(m):
    arrow(m)
    m.attach("Tip", (0, -1.55, 0))
    m.attach("Nock", (0, 1.5, 0))


@asset("SM_ArrowBundle", "Crafting_L2", "Pickup", density=HELD, icon=True, pivot="Centre on the ground.",
       use="Arrow ammo pickup: six arrows tied with rope.")
def arrow_bundle(m):
    for i in range(6):
        a = i * math.tau / 6
        arrow(m, loc=(math.cos(a) * 0.09, 0, 0.2 + math.sin(a) * 0.09), rot=(0, 0, (i - 3) * 2))
    for y in (-0.4, 0.5):
        m.torus("rope", 0.16, 0.04, seg=8, tseg=3, loc=(0, y, 0.2), rot=(90, 0, 0))


# ---------------------------------------------------------------- L2: gate

def gate_frame(m):
    log_post(m, -4, 0, 9.2, 0.7, point=True)
    m.box("wood_dark", (8.6, 1.0, 0.8), loc=(-0.05, 0, 7.9), bevel=0.06)  # lintel
    for x in (-2.6, -0.9, 0.8, 2.5):  # sharpened stakes along the lintel
        m.cone("wood_fresh", 0.35, 1.3, seg=6, loc=(x, 0, 8.3))
    for x in (-3.8, 3.6):
        m.box("metal_dark", (0.5, 1.05, 0.12), loc=(x, 0, 7.6))
    m.col_box((-4, 0, 4.6), (1.4, 1.4, 9.2))
    m.col_box((0, 0, 7.9), (8.6, 1.0, 0.8))


def gate_door(p, damaged=False):
    """Pivot on the hinge line (bottom); door extends along +X (Blender)."""
    p.meta["pivot"] = ("Hinge axis: bottom of the hinge edge. Rotate about the part's Y (up) axis. "
                       "Closed = placement in SM_Gate.")
    W, H = 6.6, 7.2
    n = 6
    for i in range(n):
        x = (i + 0.5) * W / n
        h = H + (0.25 if i % 2 else 0)
        if damaged and i == 3:
            h = H * 0.45
        p.box("wood", (W / n - 0.05, 0.35, h), loc=(x, 0, h / 2), bevel=0.04)
        if damaged and i == 3:
            p.cone("wood_fresh", 0.2, 0.6, seg=4, loc=(x, 0, h - 0.05))
    for z in (1.2, 6.0):
        p.box("wood_dark", (W - 0.3, 0.3, 0.5), loc=(W / 2, 0.3, z), bevel=0.04)
    br = p.box("wood_dark", (7.4, 0.28, 0.45), loc=(W / 2, 0.3, 3.6),
               rot=(0, -math.degrees(math.atan2(4.8, W - 0.4)), 0), bevel=0.04)
    if damaged:
        p.transform(br, __import__("mathutils").Matrix.Translation((0, 0.15, -0.3)))
    for z in (1.2, 6.0):  # iron hinge straps
        p.box("metal_dark", (1.8, 0.12, 0.3), loc=(0.9, -0.22, z))
        p.cylinder("metal_dark", 0.14, 0.14, 0.7, seg=6, loc=(0.0, 0.0, z - 0.35))
    p.torus("metal", 0.2, 0.04, seg=8, tseg=3, loc=(W - 0.6, -0.25, 3.4), rot=(90, 0, 0))
    p.col_box((W / 2, 0, H / 2), (W, 0.45, H))


@asset("SM_Gate", "Crafting_L2", "Structure", density=3.0, lod=True, pivot=WALL_PIVOT, footprint=[8, 1.5],
       use="Workbench L2: gate frame. Door is SM_Gate_Door (hinged on the left post). 6.6 x 7.2 opening.",
       notes="Anchor the frame; hinge the door with a HingeConstraint or tween its CFrame about Hinge_Att.")
def gate(m):
    gate_frame(m)
    gate_door(m.part("SM_Gate_Door", placement=(-3.35, 0, 0.05)))
    m.attach("Hinge", (-3.35, 0, 0.05))
    m.attach("SnapLeft", (-4, 0, 0))
    m.attach("SnapRight", (4, 0, 0))


@asset("SM_Gate_Door_Damaged", "Crafting_L2", "MovingPart", density=3.0, dummy=False,
       pivot="Hinge axis, same as SM_Gate_Door.", use="Damaged door: broken plank, sagging brace.")
def gate_door_damaged(m):
    gate_door(m, damaged=True)


def spikes(m, damaged=False):
    for x in (-3.2, 3.2):  # X-frame ends
        m.sweep("bark", [(x, -1.3, -0.2), (x, 1.3, 2.2)], 0.22, 6, cap_mat="end_grain")
        m.sweep("bark", [(x, 1.3, -0.2), (x, -1.3, 2.2)], 0.22, 6, cap_mat="end_grain")
    m.sweep("bark", [(-4, 0, 1.0), (4, 0, 1.0)], 0.35, 8, cap_mat="end_grain")
    for i in range(9):
        x = -3.6 + i * 0.9
        for s in (1, -1):
            if damaged and (i + (s > 0)) % 4 == 1:
                m.sweep("wood", [(x, 0, 1.0), (x, -0.5 * s, 1.5)], [0.14, 0.12], 5, cap_mat="wood_fresh")
                continue
            tip = (x + (0.1 if s > 0 else -0.1), -2.1 * s if s > 0 else 1.2, 2.6 if s > 0 else 2.4)
            v = m.sweep("wood", [(x, 0.3 * s, 0.9), tip], [0.14, 0.0], 5)
            tv = Vector(tip)
            m.paint_where(v, "charcoal", lambda c, n, tv=tv: (c - tv).length < 0.7)  # fire-hardened tips
    m.flatten_below(0)
    m.col_box((0, -0.4, 1.3), (8.2, 3.0, 2.6))


@asset("SM_Spikes", "Crafting_L2", "Structure", density=2.5, lod=True, pivot=WALL_PIVOT, footprint=[8, 3.2],
       use="Workbench L2: sharpened stake barrier. Stakes point outward (-Z) and up. Damages on touch.",
       notes="Use the collision box as a CanTouch hurt zone; keep CanCollide on so it blocks.")
def spikes_asset(m):
    spikes(m)
    m.attach("HurtZone", (0, -0.4, 1.3))


@asset("SM_Spikes_Damaged", "Crafting_L2", "Structure", density=2.5, pivot=WALL_PIVOT, footprint=[8, 3.2],
       use="Damaged spikes: snapped stakes.")
def spikes_damaged(m):
    spikes(m, damaged=True)


# ------------------------------------------------------------ L3 structures

def reinforced(m, damaged=False):
    # stone footing
    for i in range(7):
        x = -3.5 + i * 1.2
        m.blob("stone" if i % 2 else "stone_dark", 0.75, loc=(x, 0, 0.35), scale=(1.1, 1.2, 0.6), jitter=0.05,
               subdiv=1)
    m.box("wood_dark", (1.3, 1.3, 9.2), loc=(-4, 0, 4.6), bevel=0.08)  # owned left post
    m.cone("metal_dark", 0.95, 0.8, seg=4, loc=(-4, 0, 9.2), rot=(0, 0, 45))
    beams = [(-2.85, 8.4), (-1.75, 8.6), (-0.65, 8.4), (0.45, 8.6), (1.55, 8.4), (2.65, 8.6), (3.55, 8.4)]
    for i, (x, h) in enumerate(beams):
        if damaged and i in (2, 3):
            h = h * (0.4 if i == 2 else 0.6)
            m.box("wood", (1.0, 1.0, h), loc=(x, 0, h / 2 + 0.3), bevel=0.05)
            m.cone("wood_fresh", 0.4, 0.8, seg=4, loc=(x, 0, h + 0.25))
            continue
        m.box("wood", (1.0, 1.0, h), loc=(x, 0, h / 2 + 0.3), bevel=0.05)
        m.cone("metal", 0.35, 0.7, seg=4, loc=(x, 0, h + 0.3), rot=(0, 0, 45))
    for z in (1.6, 4.6, 7.6):
        if damaged and z == 4.6:
            v = m.box("metal_dark", (8.6, 0.12, 0.45), loc=(-0.1, -0.56, z))
            for vv in v:
                vv.co.y -= 0.35 * max(0, 1 - abs(vv.co.x - 0.0) / 2.5)
        else:
            m.box("metal_dark", (8.6, 0.12, 0.45), loc=(-0.1, -0.56, z))
        for x, _ in beams[::2]:
            m.cylinder("metal", 0.1, 0.1, 0.1, seg=6, loc=(x, -0.62, z), rot=(90, 0, 0))
    # inner diagonal braces and walkway ledge
    for x0 in (-3.2, 0.3):
        m.box("wood_dark", (4.4, 0.4, 0.45), loc=(x0 + 1.6, 0.72, 4.0), rot=(0, -50, 0), bevel=0.04)
    m.box("wood_dark", (8.2, 0.35, 0.5), loc=(0, 0.72, 1.2), bevel=0.04)
    m.col_box((-0.1, 0, 4.4), (8.9, 1.5, 8.8))


@asset("SM_ReinforcedWall", "Crafting_L3", "Structure", density=3.0, lod=True, pivot=WALL_PIVOT,
       footprint=[8, 1.6], use="Workbench L3: squared timber on a stone footing, iron bands, capped beams.",
       notes="Same 8-stud snapping as SM_WoodenWall, so it upgrades in place.")
def reinforced_wall(m):
    reinforced(m)
    m.attach("SnapLeft", (-4, 0, 0))
    m.attach("SnapRight", (4, 0, 0))


@asset("SM_ReinforcedWall_Damaged", "Crafting_L3", "Structure", density=3.0, lod=True, pivot=WALL_PIVOT,
       footprint=[8, 1.6], use="Damaged reinforced wall: two beams broken, middle band bent out.")
def reinforced_wall_d(m):
    reinforced(m, damaged=True)


@asset("SM_Watchtower", "Crafting_L3", "Structure", density=3.0, lod=True,
       pivot="Bottom centre of the 8 x 8 footprint on the ground.", footprint=[8, 8], fidelity="Box",
       use="Workbench L3: platform at 10 studs, ladder on the front (-Z) through a 2.8 x 2.4 hatch, "
           "3.5-stud railing, 6.5 studs head room under the roof.",
       notes="Put an invisible TrussPart in the Climb volume (see catalog 'meta.climb_volume') so every "
             "avatar can climb. Use the collision boxes (not mesh collision) so the hatch stays open.")
def watchtower(m):
    F = 10.0  # floor height
    for x in (-3.4, 3.4):
        for y in (-3.4, 3.4):
            m.sweep("bark", [(x, y, -0.4), (x * 0.97, y * 0.97, F), (x * 0.97, y * 0.97, F + 7.4)],
                    [0.4, 0.36, 0.3], 8, cap_mat="end_grain")
    for s in (-1, 1):  # X braces on the sides and back
        for a, b in (((-3.3, s * 3.3), (3.3, s * 3.3)),):
            pass
    for (x0, y0, x1, y1) in ((-3.3, 3.3, 3.3, 3.3), (-3.3, -3.3, -3.3, 3.3), (3.3, -3.3, 3.3, 3.3)):
        m.sweep("wood_dark", [(x0, y0, 1.0), (x1, y1, F - 0.6)], 0.16, 6, cap_mat="end_grain")
        m.sweep("wood_dark", [(x1, y1, 1.0), (x0, y0, F - 0.6)], 0.16, 6, cap_mat="end_grain")
    # floor with hatch: hatch spans x 0.6..3.4, y -3.6..-1.2
    hx0, hx1, hy0, hy1 = 0.6, 3.4, -3.8, -1.2
    m.box("wood", (7.8, 3.8 - hy1 + 0.0, 0.4), loc=(0, (hy1 + 3.9) / 2, F), bevel=0.04)
    m.box("wood", (hx0 + 3.9, hy1 - hy0, 0.4), loc=((-3.9 + hx0) / 2, (hy0 + hy1) / 2, F), bevel=0.04)
    m.box("wood", (3.9 - hx1, hy1 - hy0, 0.4), loc=((hx1 + 3.9) / 2, (hy0 + hy1) / 2, F), bevel=0.04)
    for y in (-3.9, 3.9):
        m.box("wood_dark", (8.2, 0.4, 0.5), loc=(0, y, F - 0.4))
    for x in (-3.9, 3.9):
        m.box("wood_dark", (0.4, 8.2, 0.5), loc=(x, 0, F - 0.4))
    # railings (front rail leaves the ladder side open above the hatch only at floor level)
    for z in (F + 1.6, F + 3.3):
        for y in (-3.6, 3.6):
            m.box("wood", (7.2, 0.25, 0.3), loc=(0, y, z), bevel=0.03)
        for x in (-3.6, 3.6):
            m.box("wood", (0.25, 7.2, 0.3), loc=(x, 0, z), bevel=0.03)
    # ladder (front, under the hatch)
    lx0, lx1, ly = 1.0, 3.0, -2.4
    for x in (lx0, lx1):
        m.box("wood_dark", (0.22, 0.3, F + 0.6), loc=(x, ly, (F + 0.6) / 2 - 0.1))
    for i in range(10):
        m.cylinder("wood", 0.08, 0.08, lx1 - lx0, seg=6, loc=(lx0, ly, 0.9 + i * 1.0), rot=(0, 90, 0))
    # roof
    m.lathe("wood_dark", [(6.4, F + 6.9), (5.6, F + 7.3), (0.0, F + 9.6)], 4, rot=(0, 0, 45))
    m.lathe("wood", [(6.2, F + 6.95), (0.0, F + 9.45)], 4, rot=(0, 0, 45))
    m.sweep("wood_dark", [(0, 0, F + 9.4), (0, 0, F + 12.2)], 0.1, 5)
    m.box("team_cloth", (1.8, 0.06, 1.1), loc=(0.95, 0, F + 11.5))
    m.attach("TeamFlag", (0, 0, F + 12.2))
    m.attach("Lookout", (0, 1.0, F + 0.2))
    m.meta["climb_volume"] = {"cframe_blender_center": [2.0, -2.8, (F + 0.6) / 2],
                              "size_studs_roblox_XYZ": [2.2, F + 0.6, 0.6]}
    m.meta["floor_height"] = F
    # collision boxes
    for x in (-3.4, 3.4):
        for y in (-3.4, 3.4):
            m.col_box((x, y, (F + 7.4) / 2), (0.8, 0.8, F + 7.4))
    m.col_box((0, (hy1 + 3.9) / 2, F), (7.8, 3.9 - hy1, 0.4))
    m.col_box(((-3.9 + hx0) / 2, (hy0 + hy1) / 2, F), (hx0 + 3.9, hy1 - hy0, 0.4))
    for y in (-3.6, 3.6):
        m.col_box((0, y, F + 1.9), (7.4, 0.3, 3.6))
    for x in (-3.6, 3.6):
        m.col_box((x, 0, F + 1.9), (0.3, 7.4, 3.6))
    m.col_box((0, 0, F + 7.4), (12.8, 12.8, 0.8))


# ---------------------------------------------------------------- L3 items

@asset("SM_Sword", "Crafting_L3", "Equippable", density=HELD, pivot=TOOL_PIVOT,
       use="Workbench L3: broad single-edged survival sword with a saw-backed spine. Blade up, edge forward.",
       notes="Trail_Att0/Trail_Att1 span the blade for a Trail effect on swings.")
def sword(m):
    # blade profile in (x=forward, z=up), extruded thin, turned so +x -> -Y (edge forward)
    prof = [(-0.18, 0.55), (0.2, 0.55), (0.26, 2.2), (0.3, 3.2), (0.05, 3.75), (-0.2, 3.35)]
    blade = m.prism("metal", prof + [(-0.2, 1.4)], 0.09, rot=(0, 0, -90))
    for v in blade:  # thin the cutting edge
        if -v.co.y > 0.12:
            v.co.x *= 0.35
    for i in range(5):  # saw teeth on the spine
        z = 2.2 + i * 0.22
        m.prism("metal_dark", [(0, 0), (0.12, 0.06), (0, 0.14)], 0.07, loc=(0, 0.19, z), rot=(0, 0, 90))
    m.box("metal_dark", (0.03, 0.12, 1.6), loc=(0, 0.02, 1.6))  # fuller line
    m.box("metal_dark", (0.3, 0.95, 0.18), loc=(0, 0.03, 0.5), bevel=0.04)  # guard
    m.lathe("leather_stitch", [(0.1, -0.4), (0.12, -0.3), (0.12, 0.3), (0.11, 0.42)], 8)
    m.lathe("brass", [(0.0, -0.62), (0.16, -0.55), (0.14, -0.42), (0.0, -0.4)], 8)
    m.attach("Trail0", (0, -0.05, 0.8))
    m.attach("Trail1", (0, -0.05, 3.6))
    m.attach("Hit", (0, -0.2, 2.6))


@asset("SM_Shield", "Crafting_L3", "Equippable", density=HELD,
       pivot="Hand grip behind the boss. Face points -Z (forward). Weld to LeftHand, or use as a Tool.",
       use="Workbench L3: round plank shield, iron rim and boss, leather arm straps, team-painted band.",
       notes="For the left arm: weld Grip_Att to LeftGripAttachment (rotate 90 deg about Y if it faces sideways).")
def shield(m):
    R = 1.35
    planks = []
    for i in range(5):
        x = -R + (i + 0.5) * 2 * R / 5
        w = 2 * R / 5 - 0.03
        hh = 2 * math.sqrt(max(R * R - x * x, 0.1)) * 0.98
        mat = "team_paint" if i == 2 else "wood"
        m.box(mat, (w, 0.16, hh), loc=(x, -0.25, 0), bevel=0.03)
    # trim planks into a disc by pulling corners in
    for v in m.bm.verts:
        r = math.hypot(v.co.x, v.co.z)
        if r > R:
            v.co.x *= R / r
            v.co.z *= R / r
    m.torus("metal_dark", R, 0.1, seg=24, tseg=4, loc=(0, -0.25, 0), rot=(90, 0, 0))
    m.lathe("metal", [(0.42, 0.0), (0.4, 0.12), (0.25, 0.25), (0.0, 0.3)], 12, loc=(0, -0.33, 0), rot=(90, 0, 0))
    for a in range(8):
        ang = a * math.tau / 8
        m.blob("metal", 0.06, loc=(math.cos(ang) * 1.15, -0.36, math.sin(ang) * 1.15), subdiv=1)
    m.box("leather_stitch", (0.25, 0.1, 1.5), loc=(0, 0.0, 0), bevel=0.02)  # hand grip strap
    m.box("leather_stitch", (1.6, 0.1, 0.25), loc=(0, -0.1, 0.55), bevel=0.02)
    m.attach("Grip", (0, 0, 0))
