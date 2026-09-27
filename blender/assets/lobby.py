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
        m.box("wood_dark", (0.25, 0.3, H + 0.5), loc=(x + s * (W / 2 + 0.12), y, z), rot=rot)
    for s in (-1, 1):
        m.box("wood_dark", (W + 0.5, 0.3, 0.25), loc=(x, y, z + s * (H / 2 + 0.12)), rot=rot)
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
