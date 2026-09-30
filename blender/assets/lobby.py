"""Forest lobby kit.

Signs: the blank panel is a separate mesh (SM_Sign_*_Panel) whose front
face (-Z) is exactly the UI surface, so a SurfaceGui with Face = Front
covers it edge to edge. No words or prices are baked into textures.
"""

import math

from mathutils import Vector

from sh.pipeline import asset

EMBLEM_COLORS = {
    "Trailblazer": "enamel_teal",
    "Scavenger": "enamel_amber",
    "Hunter": "enamel_red",
    "Climber": "enamel_slate",
    "Craftsman": "enamel_orange",
    "Sharpshooter": "enamel_purple",
}


def deck(m, R, mat="wood", seg=12, h=0.6):
    m.cylinder(mat, R, R, h, seg=seg, cap="wood")
    m.torus("wood_dark", R, 0.25, seg=seg, tseg=4, loc=(0, 0, h - 0.1), rot=(0, 0, 180 / seg))
    for k in range(seg):
        a = k * math.tau / seg
        m.box("wood_dark", (0.15, R * 2 - 0.4, 0.04), loc=(0, 0, h + 0.01), rot=(0, 0, math.degrees(a)))


def log_seat(m, x, y, rot, L=4.0):
    a = math.radians(rot)
    d = Vector((math.cos(a), math.sin(a), 0)) * L / 2
    p = Vector((x, y, 0.55))
    m.sweep("bark", [p - d, p + d], 0.55, 8, cap_mat="end_grain")


@asset("SM_Lobby_GatheringArea", "Lobby", "Lobby", density=4.0, pivot="Centre on the ground (deck top at 0.6).",
       footprint=[30, 30], fidelity="Default",
       use="Central gathering deck (radius 13) with a stone fire pit and log seating ring.",
       notes="Fire pit: reuse SM_Campfire_Flames at FirePit_Att. Spawn_Att marks the spawn centre.")
def gathering(m):
    deck(m, 13, seg=16)
    for k in range(9):
        a = k * math.tau / 9
        m.blob("stone" if k % 2 else "stone_dark", 0.7, loc=(math.cos(a) * 2.6, math.sin(a) * 2.6, 0.85),
               scale=(1, 1.2, 0.7), jitter=0.06)
    m.cylinder("embers", 2.2, 2.2, 0.15, seg=12, loc=(0, 0, 0.6), cap="embers")
    for k in range(6):
        a = k * math.tau / 6 + 0.3
        log_seat(m, math.cos(a) * 8, math.sin(a) * 8, math.degrees(a) + 90)
    for k in range(4):  # lantern posts at the deck edge
        a = k * math.tau / 4 + math.pi / 4
        x, y = math.cos(a) * 12, math.sin(a) * 12
        m.sweep("wood_dark", [(x, y, 0.4), (x, y, 7)], 0.2, 6)
        m.cylinder("glow", 0.35, 0.35, 0.7, seg=8, loc=(x, y, 6.2))
        m.cone("metal_dark", 0.5, 0.4, seg=8, loc=(x, y, 6.9))
        m.attach(f"Light{k + 1}", (x, y, 6.5))
    m.attach("FirePit", (0, 0, 0.7))
    m.attach("Spawn", (0, -6, 0.6))
    m.col_box((0, 0, 0.3), (26, 26, 0.6))


@asset("SM_Lobby_ReadyStation", "Lobby", "Lobby", density=3.0, pivot="Centre of the ready pad on the ground.",
       footprint=[9, 5], use="Ready-up arch over a glowing stone pad. Stand on Pad_Att to ready up.",
       notes="Glow ring: set to Neon via a separate part if desired, or add a SurfaceLight at Pad_Att. "
             "Mount SM_Sign_Hanging_Panel at SignMount_Att for the countdown UI.")
def ready_station(m):
    m.cylinder("stone", 2.6, 2.7, 0.35, seg=16, cap="stone")
    m.torus("glow", 2.1, 0.1, seg=24, tseg=4, loc=(0, 0, 0.36))
    for s in (-1, 1):
        m.sweep("bark", [(s * 3.6, 0, -0.3), (s * 3.5, 0, 4), (s * 3.2, 0, 7.4)], [0.5, 0.45, 0.4], 8,
                cap_mat="end_grain")
        m.blob("stone_mossy", 0.8, loc=(s * 3.6, 0, 0.3), scale=(1.1, 1.1, 0.6))
    m.sweep("bark", [(-4.2, 0, 7.2), (0, 0, 7.9), (4.2, 0, 7.2)], 0.45, 8, cap_mat="end_grain")
    for x in (-2.0, 2.0):
        m.torus("rope", 0.46, 0.08, seg=8, tseg=3, loc=(x, 0, 7.6), rot=(0, 90, 0))
    m.sweep("rope", [(-1.2, 0, 7.5), (-1.2, 0, 6.3)], 0.05, 4)
    m.sweep("rope", [(1.2, 0, 7.5), (1.2, 0, 6.3)], 0.05, 4)
    m.attach("Pad", (0, 0, 0.4))
    m.attach("SignMount", (0, 0, 6.3))
    for s in (-1, 1):
        m.col_box((s * 3.5, 0, 3.7), (1.0, 1.0, 7.4))
    m.col_box((0, 0, 0.17), (5.4, 5.4, 0.35))


@asset("SM_Lobby_PartyArea", "Lobby", "Lobby", density=3.0, pivot="Centre on the ground (platform top 0.5).",
       footprint=[14, 14], use="Party gathering platform: four stump seats around a lantern totem.",
       notes="Seat1-4_Att: party member spots (use Seats). TotemTop_Att: party banner / UI.")
def party_area(m):
    m.box("wood", (14, 14, 0.5), loc=(0, 0, 0.25), bevel=0.08)
    for i in range(7):
        m.box("wood_dark", (14.05, 0.12, 0.04), loc=(0, -6 + i * 2, 0.51))
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        x, y = math.cos(a) * 4.2, math.sin(a) * 4.2
        m.cylinder("bark", 0.9, 0.85, 1.7, seg=9, loc=(x, y, 0.5), cap="end_grain")
        m.attach(f"Seat{k + 1}", (x, y, 2.2))
    m.sweep("wood_dark", [(0, 0, 0.5), (0, 0, 8)], [0.45, 0.35], 8, cap_mat="end_grain")
    for z in (3, 5):
        m.torus("wood_fresh", 0.45, 0.08, seg=10, tseg=3, loc=(0, 0, z))
    for k in range(4):
        a = k * math.tau / 4
        m.sweep("wood_dark", [(0, 0, 7.2), (math.cos(a) * 1.4, math.sin(a) * 1.4, 7.4)], 0.07, 4)
        m.cylinder("glow", 0.2, 0.2, 0.45, seg=6, loc=(math.cos(a) * 1.4, math.sin(a) * 1.4, 6.8))
    m.attach("TotemTop", (0, 0, 8.2))
    m.col_box((0, 0, 0.25), (14, 14, 0.5))


@asset("SM_Lobby_PowerupStand", "Lobby", "Lobby", density=2.5, pivot="Centre on the ground.",
       footprint=[3, 3], use="Pedestal for one powerup emblem (Emblem_Att), with a blank plaque slot (Plaque_Att).",
       notes="Put an SM_Emblem_* at Emblem_Att; mount SM_Sign_Plaque_Panel at Plaque_Att for the name/price UI.")
def powerup_stand(m):
    m.cylinder("stone", 1.4, 1.5, 0.5, seg=10, cap="stone")
    m.cylinder("stone_dark", 1.1, 1.2, 0.3, seg=10, loc=(0, 0, 0.5), cap="stone_dark")
    m.sweep("wood", [(0, 0, 0.7), (0, 0, 3.2)], [0.45, 0.38], 8, cap_mat="end_grain")
    for z in (1.2, 2.6):
        m.torus("brass", 0.44, 0.06, seg=10, tseg=3, loc=(0, 0, z))
    m.box("brass", (0.5, 0.25, 0.9), loc=(0, 0.2, 3.5), bevel=0.04)  # bracket behind the emblem
    m.box("wood_dark", (1.6, 0.2, 0.6), loc=(0, -1.2, 0.55), rot=(-30, 0, 0))
    m.attach("Emblem", (0, -0.05, 4.4))
    m.attach("Plaque", (0, -1.32, 0.62), (-30, 0, 0))
    m.col_box((0, 0, 1.6), (2.8, 2.8, 3.2))


@asset("SM_Lobby_ShopDisplay", "Lobby", "Lobby", density=3.0, pivot="Bottom centre on the ground.",
       footprint=[10, 6], use="Market stall: counter, shelves, striped awning, three display plinths (Item1-3_Att).",
       notes="Mount SM_Sign_Board_Panel at SignMount_Att for shop UI.")
def shop(m):
    for x in (-4.5, 4.5):
        for y in (-2.5, 2.5):
            m.box("wood_dark", (0.4, 0.4, 7.2 if y > 0 else 6.2), loc=(x, y, (7.2 if y > 0 else 6.2) / 2), bevel=0.04)
    m.box("wood", (9.4, 1.4, 2.8), loc=(0, -2.3, 1.4), bevel=0.05)  # counter
    m.box("wood_fresh", (9.6, 1.6, 0.2), loc=(0, -2.3, 2.9), bevel=0.04)
    for z in (1.2, 2.8, 4.4):  # back shelves
        m.box("wood", (8.6, 1.0, 0.18), loc=(0, 2.1, z), bevel=0.03)
    v = m.box("chute_a", (10.0, 6.4, 0.12), loc=(0, 0, 6.8), rot=(-9, 0, 0))
    for k in range(5):
        m.box("chute_b", (1.0, 6.45, 0.13), loc=(-4 + k * 2.0, 0, 6.8), rot=(-9, 0, 0))
    for k in range(10):  # scalloped front edge
        m.cone("chute_a" if k % 2 else "chute_b", 0.5, 0.6, seg=3, loc=(-4.5 + k * 1.0, -3.2, 6.3),
               rot=(180, 0, 0))
    for i, x in enumerate((-3, 0, 3)):
        m.cylinder("stone", 0.55, 0.6, 0.4, seg=8, loc=(x, -2.3, 3.0), cap="stone")
        m.attach(f"Item{i + 1}", (x, -2.3, 3.6))
    m.box("wood_dark", (0.9, 0.9, 1.2), loc=(-3.4, 2.1, 5.2), bevel=0.05)
    m.attach("SignMount", (0, -3.3, 5.2))
    m.col_box((0, -2.3, 1.5), (9.6, 1.6, 3.0))
    m.col_box((0, 2.1, 2.6), (8.8, 1.2, 5.2))


# ---------------------------------------------------------------- signs

def sign_frame_panel(m, name, W, H, loc, rot=(0, 0, 0)):
    """Rustic frame on the main mesh + separate blank panel part."""
    x, y, z = loc
    for s in (-1, 1):
        m.box("wood_dark", (0.25, 0.3, H + 0.26), loc=(x + s * (W / 2 + 0.12), y, z), rot=rot)
    for s in (-1, 1):  # slightly deeper than the side rails: no coplanar faces at the corners
        m.box("wood_dark", (W + 0.5, 0.34, 0.25), loc=(x, y, z + s * (H / 2 + 0.12)), rot=rot)
    p = m.part(name, placement=(x, y, z), rot=rot)
    p.meta["pivot"] = "Panel centre. Front (-Z) face is the UI surface; use SurfaceGui Face=Front."
    p.box("sign_blank", (W, 0.2, H), loc=(0, 0, 0))
    p.col_box((0, 0, 0), (W, 0.2, H))
    return p


@asset("SM_Sign_Post", "Lobby", "Lobby", density=2.0, pivot="Base of the post on the ground.", footprint=[4, 1],
       use="Signpost with a 3.5 x 1.8 blank panel (SM_Sign_Post_Panel).")
def sign_post(m):
    m.sweep("wood_dark", [(0, 0.1, -0.3), (0, 0.1, 4.8)], 0.2, 6)
    sign_frame_panel(m, "SM_Sign_Post_Panel", 3.5, 1.8, (0, -0.1, 3.6))
    m.col_box((0, 0, 2.4), (0.4, 0.4, 4.8))


@asset("SM_Sign_Hanging", "Lobby", "Lobby", density=2.0, pivot="Top hook point (hang from beams/arches).",
       dummy=False, use="Hanging sign on ropes with a 4 x 2 blank panel (SM_Sign_Hanging_Panel).")
def sign_hanging(m):
    for x in (-1.6, 1.6):
        m.sweep("rope", [(x, 0, 0), (x, 0, -1.0)], 0.05, 4)
    sign_frame_panel(m, "SM_Sign_Hanging_Panel", 4.0, 2.0, (0, 0, -2.2))


@asset("SM_Sign_Board", "Lobby", "Lobby", density=3.0, pivot="Bottom centre on the ground.", footprint=[11, 2],
       use="Large notice board with roof: 9 x 4.5 blank panel (SM_Sign_Board_Panel) for leaderboards / shop.")
def sign_board(m):
    for x in (-5, 5):
        m.sweep("bark", [(x, 0.15, -0.4), (x, 0.15, 8.5)], 0.35, 8, cap_mat="end_grain")
    sign_frame_panel(m, "SM_Sign_Board_Panel", 9.0, 4.5, (0, 0, 5.0))
    m.prism("wood_dark", [(-6, 0), (6, 0), (0, 1.3)], 1.6, loc=(0, 0.1, 7.6))
    m.col_box((0, 0.1, 4.2), (10.8, 0.8, 8.4))


@asset("SM_Sign_Plaque", "Lobby", "Lobby", density=2.0, dummy=False, pivot="Plaque centre.",
       use="Small blank plaque (SM_Sign_Plaque_Panel) for powerup names/prices on the stands.")
def sign_plaque(m):
    sign_frame_panel(m, "SM_Sign_Plaque_Panel", 1.3, 0.45, (0, 0, 0))


# --------------------------------------------------------------- emblems

def medallion(m, color):
    m.cylinder(color, 1.15, 1.15, 0.18, seg=24, loc=(0, 0.09, 0), rot=(90, 0, 0), cap=color)
    m.torus("brass", 1.2, 0.12, seg=24, tseg=4, rot=(90, 0, 0))
    m.cylinder("wood_dark", 1.25, 1.25, 0.12, seg=24, loc=(0, 0.28, 0), rot=(90, 0, 0), cap="wood_dark")


def raised(m, profile, loc=(0, 0, 0), rot=(0, 0, 0), mat="brass", depth=0.14, scale=(1, 1, 1)):
    x, y, z = loc
    return m.prism(mat, profile, depth, loc=(x, -0.1 + y, z), rot=rot, scale=scale)


def emblem(name, key, use):
    return asset(f"SM_Emblem_{name}", "Lobby", "Lobby", density=1.0, dummy=False,
                 pivot="Medallion centre. Face points -Z. Sits at SM_Lobby_PowerupStand Emblem_Att.",
                 use=use, notes="No text. Can double as a 3D icon for the powerup UI.")


@emblem("Trailblazer", "teal", "Trailblazer (movement/sprint): winged boot with speed streaks.")
def trailblazer(m):
    medallion(m, EMBLEM_COLORS["Trailblazer"])
    boot = [(-0.35, -0.55), (0.55, -0.55), (0.6, -0.35), (0.1, -0.25), (0.05, 0.5), (-0.35, 0.5)]
    raised(m, boot, loc=(0.05, 0, 0))
    for i in range(3):
        raised(m, [(0, 0), (0.55, 0.05), (0.5, 0.16), (0, 0.12)], loc=(-0.95, 0, 0.1 - i * 0.28))
    for i in range(3):  # wing feathers
        raised(m, [(0, 0), (0.45 - i * 0.08, 0.1), (0.4 - i * 0.08, 0.22), (0, 0.14)], loc=(-0.3, -0.02, 0.35 - i * 0.18),
               rot=(0, 20 + i * 12, 0))


@emblem("Scavenger", "amber", "Scavenger (gathering/finding crates): magnifying glass over a sparkle.")
def scavenger(m):
    medallion(m, EMBLEM_COLORS["Scavenger"])
    m.torus("brass", 0.42, 0.09, seg=16, tseg=4, loc=(-0.12, -0.12, 0.15), rot=(90, 0, 0))
    m.cylinder("glow", 0.36, 0.36, 0.06, seg=16, loc=(-0.12, -0.06, 0.15), rot=(90, 0, 0), cap="glow")
    raised(m, [(-0.08, 0), (0.08, 0), (0.08, 0.7), (-0.08, 0.7)], loc=(0.2, -0.02, -0.2), rot=(0, 135, 0))
    star = []
    for k in range(8):
        r = 0.22 if k % 2 == 0 else 0.07
        a = k * math.tau / 8
        star.append((math.cos(a) * r, math.sin(a) * r))
    raised(m, star, loc=(0.55, 0, 0.6), mat="bone")


@emblem("Hunter", "red", "Hunter (tracking/fighting animals): paw print with three claw slashes.")
def hunter(m):
    medallion(m, EMBLEM_COLORS["Hunter"])
    pad = [(math.cos(a) * 0.35, math.sin(a) * 0.28 - 0.25) for a in [k * math.tau / 12 for k in range(12)]]
    raised(m, pad, mat="bone")
    for x, z in ((-0.45, 0.2), (-0.16, 0.42), (0.16, 0.42), (0.45, 0.2)):
        toe = [(math.cos(a) * 0.13 + x, math.sin(a) * 0.17 + z) for a in [k * math.tau / 10 for k in range(10)]]
        raised(m, toe, mat="bone")
    for i in range(3):
        raised(m, [(0, 0), (0.06, 0), (0.5, 0.35), (0.44, 0.38)], loc=(0.2 + i * 0.12, -0.03, -0.85), mat="brass",
               depth=0.1)


@emblem("Climber", "slate", "Climber (climbing/crossing walls): grappling hook with rope coil.")
def climber(m):
    medallion(m, EMBLEM_COLORS["Climber"])
    m.sweep("metal", [(0, -0.15, -0.55), (0, -0.15, 0.55)], 0.07, 6)
    for k in range(3):
        a = math.radians(-60 + k * 60)
        pts = [(0, -0.15, -0.5), (math.sin(a) * 0.35, -0.15, -0.72), (math.sin(a) * 0.55, -0.15, -0.45)]
        m.sweep("metal", pts, [0.06, 0.05, 0.02], 5)
    m.torus("metal", 0.12, 0.04, seg=8, tseg=3, loc=(0, -0.15, 0.66), rot=(90, 0, 0))
    m.torus("rope", 0.3, 0.05, seg=12, tseg=3, loc=(0.45, -0.15, 0.55), rot=(90, 0, 0))
    m.sweep("rope", [(0.12, -0.15, 0.7), (0.35, -0.15, 0.62)], 0.04, 3)


@emblem("Craftsman", "orange", "Craftsman (building/repairs): hammer over an anvil.")
def craftsman(m):
    medallion(m, EMBLEM_COLORS["Craftsman"])
    anvil = [(-0.65, -0.1), (0.4, -0.1), (0.75, 0.05), (0.4, 0.12), (0.35, 0.18), (-0.55, 0.18),
             (-0.55, 0.12), (-0.25, 0.05), (-0.2, -0.4), (0.2, -0.4), (0.25, -0.55), (-0.35, -0.55), (-0.3, -0.4)]
    raised(m, [(-0.65, 0.1), (0.4, 0.1), (0.75, 0.25), (0.4, 0.32), (-0.55, 0.32)], loc=(0, 0, -0.3), mat="metal")
    raised(m, [(-0.2, -0.3), (0.2, -0.3), (0.2, 0.1), (-0.2, 0.1)], loc=(0, 0, -0.3), mat="metal")
    raised(m, [(-0.4, -0.55), (0.4, -0.55), (0.3, -0.3), (-0.3, -0.3)], loc=(0, 0, -0.3), mat="metal")
    raised(m, [(-0.05, 0), (0.05, 0), (0.05, 0.75), (-0.05, 0.75)], loc=(0.1, -0.02, 0.1), rot=(0, -35, 0), mat="brass")
    raised(m, [(-0.25, 0), (0.25, 0), (0.25, 0.2), (-0.25, 0.2)], loc=(0.48, -0.03, 0.62), rot=(0, -35, 0), mat="brass")


@emblem("Sharpshooter", "purple", "Sharpshooter (aiming/archery): target rings pierced by an arrow.")
def sharpshooter(m):
    medallion(m, EMBLEM_COLORS["Sharpshooter"])
    for r, mat in ((0.8, "bone"), (0.5, "brass"), (0.2, "bone")):
        m.torus(mat, r, 0.06, seg=20, tseg=3, loc=(0, -0.1, 0), rot=(90, 0, 0))
    m.sweep("wood_fresh", [(-0.9, -0.2, -0.75), (0.1, -0.2, 0.08)], 0.045, 5)
    m.cone("metal", 0.1, 0.25, seg=4, loc=(0.1, -0.2, 0.08), rot=(0, 50, 0))
    for s in (-1, 1):
        raised(m, [(0, 0), (0.28, 0), (0.22, 0.1), (0, 0.06)], loc=(-0.85, -0.03, -0.7 + s * 0.05),
               rot=(0, -40 + s * 30, 0), mat="bone", depth=0.05)


# --------------------------------------------------------------- campfire plaza
# The evening plaza round the lobby fire: a log lodge (Camp Store + Classes), roofed
# leaderboards, the Daily Challenges board, big log seats and a lantern fence.
# Board faces are plain dark panels: every word is a SurfaceGui drawn by the game on a
# part just in front of the panel (see src/shared/Models/Refuge.luau PLAZA).

ROOF = "crate_paint"  # olive painted shingles


def log(m, a, b, r, mat="bark"):
    m.sweep(mat, [a, b], r, 8, cap_mat="end_grain")


def lantern(m, x, y, z, name=None):
    """Hanging lantern whose hook is at (x, y, z)."""
    m.sweep("metal_dark", [(x, y, z), (x, y, z - 0.35)], 0.04, 4)
    m.cone("metal_dark", 0.42, 0.35, seg=8, loc=(x, y, z - 0.7))
    m.box("glow", (0.55, 0.55, 0.75), loc=(x, y, z - 1.1), bevel=0.06)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box("metal_dark", (0.08, 0.08, 0.8), loc=(x + sx * 0.3, y + sy * 0.3, z - 1.1))
    m.box("metal_dark", (0.7, 0.7, 0.14), loc=(x, y, z - 1.52), bevel=0.04)
    if name:
        m.attach(name, (x, y, z - 1.1))


def shingle_roof(m, width, run, ridge, eave_drop, loc, rows=4):
    """Gable roof along X: ridge at loc (x, y, z), slopes down toward -Y and +Y."""
    x, y, z = loc
    ang = math.degrees(math.atan2(eave_drop, run))
    slope = math.hypot(run, eave_drop)
    for s in (-1, 1):
        for i in range(rows):  # overlapping shingle courses
            t = (i + 0.5) / rows
            m.box(ROOF, (width, slope / rows + 0.25, 0.28),
                  loc=(x, y + s * run * t, z - eave_drop * t + 0.05 * (rows - i)),
                  rot=(-s * ang, 0, 0), bevel=0.06)
    m.box("wood_dark", (width + 0.3, 0.45, 0.45), loc=(x, y, z + 0.28), bevel=0.08)


@asset("SM_Lobby_Leaderboard", "Lobby", "Lobby", density=3.0, pivot="Bottom centre on the ground; the panel faces -Z.",
       footprint=[12, 3], fidelity="Box",
       use="Roofed leaderboard (Most Kills / Wins / Playtime). Text drawn by the game.",
       notes="Panel 10 x 7.6 centred 6.4 up, front face 0.3 in front of the pivot. Title plank 9.6 x 1.5 at 11.1. "
             "Lanterns at Light1_Att / Light2_Att.")
def leaderboard(m):
    for x in (-5.6, 5.6):
        log(m, (x, 0.2, -0.3), (x, 0.2, 12.4), 0.38)
        m.blob("stone_dark", 0.6, loc=(x, 0.2, 0.2), scale=(1.2, 1.2, 0.6), jitter=0.05)
    m.box("wood_dark", (11.0, 0.5, 10.6), loc=(0, 0.2, 6.9), bevel=0.1)  # backboard
    m.box("wood_dark", (10.0, 0.2, 7.6), loc=(0, -0.2, 6.4), bevel=0.04)  # dark text panel
    for z, h in ((2.4, 0.5), (10.4, 0.5)):  # frame rails
        m.box("wood", (10.8, 0.5, h), loc=(0, -0.25, z), bevel=0.1)
    for x in (-5.15, 5.15):
        m.box("wood", (0.5, 0.5, 8.5), loc=(x, -0.25, 6.4), bevel=0.1)
    m.box("wood_fresh", (9.6, 0.35, 1.5), loc=(0, -0.3, 11.1), bevel=0.1)  # title plank
    for x in (-3.5, 3.5):
        m.box("metal_dark", (0.15, 0.1, 0.15), loc=(x, -0.5, 11.1))
    shingle_roof(m, 13.0, 1.9, 1.3, 1.1, (0, 0.2, 13.4))
    for x in (-6.2, 6.2):  # gable end boards
        m.prism("wood_dark", [(-0.1, 0), (0.1, 0), (0.1, 1.1), (-0.1, 1.1)], 3.6, loc=(x, 0.2, 12.2))
    for i, x in enumerate((-5.6, 5.6)):
        m.box("metal_dark", (0.12, 1.0, 0.12), loc=(x, -0.45, 11.9))
        lantern(m, x, -0.9, 11.85, f"Light{i + 1}")
    m.col_box((0, 0.1, 6.5), (12, 1.0, 13))


@asset("SM_Lobby_QuestBoard", "Lobby", "Lobby", density=3.0, pivot="Bottom centre on the ground; the panel faces -Z.",
       footprint=[13, 3], fidelity="Box",
       use="Daily Challenges board: log frame, carved header sign with pine trees. Text drawn by the game.",
       notes="Panel 11.2 x 6.6 centred 6 up, front face 0.3 in front of the pivot (matches ChallengeBoardFace). "
             "Header plank 9 x 2.2 at 12.")
def quest_board(m):
    for x in (-6.4, 6.4):
        log(m, (x, 0.2, -0.3), (x, 0.2, 13.8), 0.42)
        m.blob("stone_dark", 0.65, loc=(x, 0.2, 0.2), scale=(1.2, 1.2, 0.6), jitter=0.05)
        m.cone("wood_dark", 0.5, 0.6, seg=8, loc=(x, 0.2, 13.8))
    m.box("wood_dark", (12.4, 0.5, 8.0), loc=(0, 0.2, 6.0), bevel=0.1)
    m.box("wood_dark", (11.2, 0.2, 6.6), loc=(0, -0.2, 6.0), bevel=0.04)
    for z in (2.45, 9.55):
        log(m, (-6.2, -0.2, z), (6.2, -0.2, z), 0.3, "wood")
    # header: plank sign between two little pines
    m.box("wood_fresh", (9.0, 0.4, 2.2), loc=(0, -0.2, 12.0), bevel=0.12)
    m.box("wood_dark", (9.6, 0.5, 0.3), loc=(0, -0.15, 10.8), bevel=0.06)
    m.box("wood_dark", (9.6, 0.5, 0.3), loc=(0, -0.15, 13.2), bevel=0.06)
    for x in (-5.4, 5.4):
        for i, (r, h) in enumerate(((0.9, 1.2), (0.7, 1.1), (0.45, 1.0))):
            m.cone("pine_needles_dark", r, h, seg=8, loc=(x, -0.2, 11.0 + i * 0.7))
    for x in (-3.8, 3.8):
        m.sweep("rope", [(x, -0.3, 13.4), (x, -0.3, 13.9)], 0.06, 4)
    m.col_box((0, 0.1, 7), (13.4, 1.0, 14))


@asset("SM_Lobby_BigLog", "Lobby", "Lobby", density=3.0, pivot="Bottom centre on the ground; the log runs along X.",
       footprint=[9, 2.6], use="Chunky log seat for the campfire ring.")
def big_log(m):
    log(m, (-4.4, 0, 1.25), (4.4, 0, 1.25), 1.25)
    m.cylinder("end_grain", 1.05, 1.05, 0.1, seg=10, loc=(4.42, 0, 1.25), rot=(0, 90, 0), cap="end_grain")
    m.sweep("bark", [(-1.5, 0.6, 2.1), (-1.9, 1.1, 2.8)], [0.25, 0.12], 6)  # branch stub
    m.blob("moss", 0.5, loc=(2.2, 0.4, 2.35), scale=(1.6, 1.1, 0.35), jitter=0.04)
    m.col_box((0, 0, 1.25), (8.8, 2.5, 2.5))


@asset("SM_Lobby_Fence", "Lobby", "Lobby", density=3.0, pivot="Bottom of the post at the -X end; rails run to +X.",
       footprint=[8, 1], use="Log fence segment, 8 studs: a post and two rails (chain them end to end).")
def fence(m):
    log(m, (0, 0, -0.3), (0, 0, 3.3), 0.4, "wood_dark")
    m.cone("wood_dark", 0.42, 0.4, seg=8, loc=(0, 0, 3.3))
    for z in (1.1, 2.5):
        log(m, (0.2, 0, z), (8.0, 0, z + 0.05), 0.24, "wood")
    m.col_box((4, 0, 1.6), (8, 0.6, 3.2))


@asset("SM_Lobby_FenceLantern", "Lobby", "Lobby", density=3.0, pivot="Bottom of the post.",
       footprint=[1.5, 1.5], use="Thick fence post with a lantern on top (goes between fence segments).",
       notes="Lantern light at Light_Att.")
def fence_lantern(m):
    m.box("wood_dark", (1.1, 1.1, 3.8), loc=(0, 0, 1.6), bevel=0.12)
    m.box("wood", (1.4, 1.4, 0.3), loc=(0, 0, 3.6), bevel=0.08)
    m.box("metal_dark", (0.9, 0.9, 0.15), loc=(0, 0, 3.8), bevel=0.04)
    m.box("glow", (0.7, 0.7, 0.95), loc=(0, 0, 4.35), bevel=0.06)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box("metal_dark", (0.1, 0.1, 1.0), loc=(sx * 0.4, sy * 0.4, 4.35))
    m.cone("metal_dark", 0.62, 0.5, seg=4, loc=(0, 0, 4.85), rot=(0, 0, 45))
    m.attach("Light", (0, 0, 4.35))
    m.col_box((0, 0, 1.9), (1.2, 1.2, 3.8))


@asset("SM_Lobby_Lodge", "Lobby", "Lobby", density=4.0, lod=True,
       pivot="Ground level at the centre of the front wall; the lodge faces -Z (porch in front, 7.2 deep).",
       footprint=[37, 23], fidelity="Default",
       use="Two-storey log lodge: CAMP STORE (left) and CLASSES (right) shopfronts on a covered porch, "
           "big gable sign board. Every word is drawn by the game.",
       notes="Floor/porch top 1.2. In Roblox model space (+X is the viewer's left): store counter top at "
             "(9, 4.9, -0.8), class lectern top at (-9, 4.65, -0.9), class stage top 1.8 from z 1.1 to 4.5 behind "
             "the right opening. Shop sign panels 12 x 1.8 hang from the porch beam, faces at z -6.45, "
             "centred (+-10.25, 8.6). Gable sign panel 14.6 x 4.4, face at z -1.55, centred (0, 21.3). Porch front edge z -6.2, steps to -7.7.")
def lodge(m):
    HW, D, F = 18.0, 14.0, 1.2  # half width, depth (back), floor height
    # plinth, floor and porch deck with steps across the front
    m.box("stone_dark", (2 * HW + 0.6, D + 0.6, 0.8), loc=(0, D / 2, 0.4), bevel=0.1)
    m.box("wood_dark", (2 * HW, D, 0.4), loc=(0, D / 2, F - 0.2))
    m.box("wood", (2 * HW + 1, 6.2, 0.5), loc=(0, -3.1, F - 0.25), bevel=0.08)
    for i, (dy, h) in enumerate(((-6.6, 0.8), (-7.3, 0.4))):
        m.box("wood_dark", (2 * HW + 1, 0.8, h), loc=(0, dy, h / 2), bevel=0.06)
    for x in range(-17, 18, 3):  # porch plank lines
        m.box("wood_dark", (0.08, 6.1, 0.05), loc=(x + 0.5, -3.1, F + 0.01))
    # ground floor log walls: back, sides, front piers either side of two shop openings
    ROW = 0.9
    for i in range(11):
        z = F + ROW / 2 + i * ROW
        log(m, (-HW - 0.6, D, z), (HW + 0.6, D, z), ROW / 2)
        for x in (-HW, HW):
            log(m, (x, -0.6, z), (x, D + 0.6, z), ROW / 2)
    for x0, x1 in ((-HW, -15.5), (-2.5, 2.5), (15.5, HW)):
        for i in range(11):
            z = F + ROW / 2 + i * ROW
            log(m, (x0, 0, z), (x1, 0, z), ROW / 2)
    for x in (-15.5, 15.5, -2.5, 2.5):
        m.box("wood_dark", (0.6, 0.8, 7.6), loc=(x, 0, F + 3.8), bevel=0.08)
    log(m, (-HW, 0, F + 8.2), (HW, 0, F + 8.2), 0.55)  # lintel
    m.box("wood_dark", (0.6, D, 9.8), loc=(0, D / 2, F + 4.9))  # dividing wall
    # interior back glow (warm light through the openings)
    for sx in (-1, 1):
        m.box("glow", (12.4, 0.2, 5.8), loc=(sx * 9, D - 0.6, F + 3.6))
    # CAMP STORE on the viewer's left (Blender -X)
    m.box("wood", (11.0, 1.4, 3.4), loc=(-9, -0.8, F + 1.7), bevel=0.1)  # counter
    m.box("wood_dark", (11.6, 1.8, 0.3), loc=(-9, -0.8, F + 3.55), bevel=0.06)
    for i, x in enumerate((-13, -11, -9, -7, -5)):  # goods on the counter
        if i % 2:
            m.cylinder("brass", 0.3, 0.3, 0.7, seg=8, loc=(x, -0.8, F + 3.7), cap="brass")
        else:
            m.box("crate_paint" if i else "leather", (0.8, 0.7, 0.6), loc=(x, -0.8, F + 4.0), bevel=0.06)
    for z in (F + 2.2, F + 4.2, F + 6.2):  # back shelves with jars and boxes
        m.box("wood_dark", (12.4, 1.4, 0.25), loc=(-9, D - 1.4, z))
        for k in range(8):
            x = -14.5 + k * 1.55
            if k % 3 == 0:
                m.cylinder("glow" if k % 2 else "brass", 0.3, 0.3, 0.8, seg=8, loc=(x, D - 1.4, z + 0.12), cap="metal_dark")
            elif k % 3 == 1:
                m.box("crate_paint", (0.9, 0.8, 0.8), loc=(x, D - 1.4, z + 0.52), bevel=0.06)
            else:
                m.box("red_paint", (0.8, 0.6, 1.0), loc=(x, D - 1.4, z + 0.62), bevel=0.06)
    m.box("leather", (3.0, 0.1, 2.2), loc=(-6, D - 0.55, F + 7.2))  # map on the wall
    # CLASSES (right): a raised stage where the class mannequins stand
    m.box("wood_dark", (12.8, 3.4, 0.6), loc=(9, 2.8, F + 0.3), bevel=0.08)
    m.box("wood", (2.6, 1.2, 3.2), loc=(9, -0.9, F + 1.6), bevel=0.1)  # lectern (class prompt)
    m.box("wood_dark", (3.0, 1.5, 0.3), loc=(9, -0.9, F + 3.3), bevel=0.06)
    # shop sign boards hung from the porch beam (text by the game)
    for sx in (-1, 1):
        m.box("wood", (12.6, 0.4, 2.3), loc=(sx * 10.25, -6.1, F + 7.4), bevel=0.1)
        m.box("wood_dark", (12.0, 0.2, 1.8), loc=(sx * 10.25, -6.35, F + 7.4), bevel=0.04)
        for dx in (-5, 5):
            m.box("metal_dark", (0.12, 0.12, 0.7), loc=(sx * 10.25 + dx, -6.1, F + 8.8))
    # porch posts, beam and roof
    for x in (-HW, -2.5, 2.5, HW):
        log(m, (x, -5.8, F), (x, -5.8, F + 8.9), 0.42)
    log(m, (-HW - 0.6, -5.8, F + 9.1), (HW + 0.6, -5.8, F + 9.1), 0.45)
    ang = math.degrees(math.atan2(2.6, 7.4))
    for i in range(4):
        t = (i + 0.5) / 4
        m.box(ROOF, (2 * HW + 2, 7.9 / 4 + 0.3, 0.3), loc=(0, 0.8 - 7.6 * t, F + 12.3 - 2.6 * t + 0.05 * (4 - i)),
              rot=(ang, 0, 0), bevel=0.06)
    for i, x in enumerate((-17.1, -3.6, 3.6, 17.1)):
        lantern(m, x, -5.8, F + 8.65, f"Porch{i + 1}")
    # ground-floor roof over the sides and back
    m.box("wood_dark", (2 * HW + 1.4, D + 1.4, 0.6), loc=(0, D / 2, F + 10.2))
    for sx in (-1, 1):
        a2 = math.degrees(math.atan2(1.8, 7.0))
        m.box(ROOF, (7.6, D + 1.6, 0.3), loc=(sx * 14.9, D / 2, F + 11.3), rot=(0, sx * a2, 0), bevel=0.06)
    # upper storey: log walls, glowing windows, balcony rail, gable with the big sign
    UW, UZ = 11.0, F + 10.5
    for i in range(8):
        z = UZ + ROW / 2 + i * ROW
        log(m, (-UW, 1.5, z), (UW, 1.5, z), ROW / 2)
        log(m, (-UW, D - 1, z), (UW, D - 1, z), ROW / 2)
        for x in (-UW, UW):
            log(m, (x, 1.0, z), (x, D - 0.5, z), ROW / 2)
    for x in (-7, 7):
        m.box("glow", (2.6, 0.3, 3.2), loc=(x, 1.25, UZ + 3.8))
        m.box("wood_dark", (3.2, 0.5, 0.3), loc=(x, 1.1, UZ + 2.1), bevel=0.05)
        m.box("wood_dark", (3.2, 0.5, 0.3), loc=(x, 1.1, UZ + 5.5), bevel=0.05)
        m.box("wood_dark", (0.3, 0.5, 3.6), loc=(x, 1.1, UZ + 3.8))
    for sx in (-1, 1):  # side windows downstairs
        for y in (4.5, 9.5):
            m.box("glow", (0.3, 2.4, 2.8), loc=(sx * (HW + 0.2), y, F + 4.8))
            m.box("wood_dark", (0.5, 3.0, 0.3), loc=(sx * (HW + 0.3), y, F + 3.3), bevel=0.05)
    # upper gable roof (ridge along Y) and the front gable wall with the sign
    RZ, EZ = UZ + 14.6, UZ + 7.0
    ang2 = math.degrees(math.atan2(RZ - EZ, UW + 1.6))
    slope = math.hypot(UW + 1.6, RZ - EZ)
    for sx in (-1, 1):
        for i in range(5):
            t = (i + 0.5) / 5
            m.box(ROOF, (slope / 5 + 0.3, D + 1.2, 0.34),
                  loc=(sx * (UW + 1.6) * t, D / 2 - 0.3, RZ - (RZ - EZ) * t + 0.06 * (5 - i)),
                  rot=(0, sx * ang2, 0), bevel=0.06)
    m.box("wood_dark", (0.6, D + 1.6, 0.6), loc=(0, D / 2 - 0.3, RZ + 0.3), bevel=0.08)
    m.prism("wood", [(-UW, 0), (UW, 0), (0, RZ - EZ)], 0.9, loc=(0, 1.5, EZ))
    m.box("wood", (15.6, 0.5, 5.2), loc=(0, -1.1, UZ + 9.6), bevel=0.14)  # big sign
    m.box("wood_dark", (14.6, 0.2, 4.4), loc=(0, -1.45, UZ + 9.6), bevel=0.05)
    for x in (-6.6, 6.6):  # little pines standing on the sign's top corners
        m.cone("pine_needles_dark", 0.9, 1.6, seg=8, loc=(x, -1.1, UZ + 12.2))
        m.cone("pine_needles_dark", 0.6, 1.3, seg=8, loc=(x, -1.1, UZ + 13.2))
    m.box("wood", (2 * UW + 1, 2.2, 0.3), loc=(0, 0.3, UZ + 0.1))  # balcony floor
    log(m, (-UW, -0.7, UZ + 1.6), (UW, -0.7, UZ + 1.6), 0.18, "wood")
    for x in range(-10, 11, 2):
        m.box("wood_dark", (0.25, 0.25, 1.5), loc=(x, -0.7, UZ + 0.9))
    lantern(m, -3, -0.7, UZ + 7.0, "Upper1")
    lantern(m, 3, -0.7, UZ + 7.0, "Upper2")
    # chimney
    m.box("stone", (2.6, 2.6, 17), loc=(12.5, D - 3, F + 8.5 + 7), bevel=0.15)
    m.box("stone_dark", (3.0, 3.0, 0.6), loc=(12.5, D - 3, F + 24.2), bevel=0.1)
    # porch clutter: barrels and crates at the ends
    for sx in (-1, 1):
        m.cylinder("wood", 0.9, 0.9, 1.9, seg=10, loc=(sx * 16.6, -4.6, F), cap="end_grain")
        m.torus("metal_dark", 0.92, 0.07, seg=10, tseg=4, loc=(sx * 16.6, -4.6, F + 0.5))
        m.torus("metal_dark", 0.92, 0.07, seg=10, tseg=4, loc=(sx * 16.6, -4.6, F + 1.4))
        m.box("crate_paint", (1.5, 1.5, 1.5), loc=(sx * 14.6, -5.0, F + 0.75), rot=(0, 0, 12 * sx), bevel=0.08)
    m.attach("StoreCounter", (-9, -0.8, F + 3.4))
    m.attach("ClassLectern", (9, -0.9, F + 3.2))
