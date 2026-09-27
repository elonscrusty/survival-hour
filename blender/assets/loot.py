"""Loot: air-dropped care package (crate, lid, parachute, lines), beacon,
landing marker, small forest supply crates, held bandage, ammo pickups."""

import math

from mathutils import Vector

from sh.pipeline import asset

CRATE_H = 3.4


def crate_body(m, W=4.0, D=4.0, H=CRATE_H, open_=False):
    m.box("crate_paint", (W, D, H - 0.3), loc=(0, 0, (H - 0.3) / 2 + 0.3), bevel=0.06)
    for x in (-W / 2, W / 2):  # skids
        m.box("wood_dark", (0.45, D + 0.2, 0.35), loc=(x * 0.8, 0, 0.17), bevel=0.04)
    for z in (0.7, H - 0.4):  # metal bands
        for s in (-1, 1):
            m.box("metal_dark", (W + 0.08, 0.1, 0.35), loc=(0, s * (D / 2 + 0.02), z))
            m.box("metal_dark", (0.1, D + 0.08, 0.35), loc=(s * (W / 2 + 0.02), 0, z))
    for x in (-W / 2, W / 2):  # corner caps
        for y in (-D / 2, D / 2):
            m.box("metal", (0.45, 0.45, 0.45), loc=(x, y, H - 0.25), bevel=0.05)
            m.box("metal", (0.45, 0.45, 0.45), loc=(x, y, 0.55), bevel=0.05)
    for s in (-1, 1):  # side handles
        m.torus("metal_dark", 0.35, 0.06, seg=8, tseg=3, loc=(s * (W / 2 + 0.1), 0, H * 0.55),
                rot=(0, 90, 0), arc=180)
    # straw padding visible when open
    m.box("fiber", (W - 0.5, D - 0.5, 0.15), loc=(0, 0, H - 0.35))


@asset("SM_CarePackage_Crate", "Loot", "Structure", density=2.5,
       pivot="Bottom centre on the ground. Lid hinges on the back top edge.", footprint=[4, 4],
       use="Main air-dropped care package. Lid = SM_CarePackage_Lid (hinged; rotate ~-110 deg or detach).",
       notes="ItemSpawn1-3_Att sit 5 studs out in front so the three released items stay visible. "
             "ParachuteLink_Att = where SM_Parachute_Lines attaches (top centre).")
def care_crate(m):
    crate_body(m)
    lid = m.part("SM_CarePackage_Lid", placement=(0, 2.0, CRATE_H))
    lid.meta["pivot"] = "Hinge along the back top edge. Rotate about the part's X axis to open."
    lid.box("crate_paint", (4.2, 4.2, 0.35), loc=(0, -2.0, 0.18), bevel=0.06)
    for x in (-1.3, 1.3):
        lid.box("metal_dark", (0.35, 4.3, 0.1), loc=(x, -2.0, 0.38))
    lid.box("red_paint", (4.25, 0.5, 0.36), loc=(0, -3.7, 0.18))  # readable red lip, no text
    lid.torus("metal", 0.3, 0.06, seg=8, tseg=3, loc=(0, -4.18, 0.1), rot=(90, 0, 0), arc=180)
    lid.col_box((0, -2.0, 0.18), (4.2, 4.2, 0.36))
    for i, a in enumerate((-50, 0, 50)):
        r = math.radians(a - 90)
        m.attach(f"ItemSpawn{i + 1}", (math.cos(r) * 5.0, math.sin(r) * 5.0, 0.1))
    m.attach("ParachuteLink", (0, 0, CRATE_H + 0.4))
    m.attach("Smoke", (1.6, -1.6, CRATE_H + 0.5))
    m.attach("Prompt", (0, -2.6, 2.4))
    m.col_box((0, 0, CRATE_H / 2), (4.2, 4.2, CRATE_H))


@asset("SM_Parachute_Canopy", "Loot", "Effect", density=3.0, dummy=False,
       pivot="Line convergence point (= crate ParachuteLink_Att). Canopy floats 12-16 studs above it.",
       use="Parachute canopy, separate from lines and crate. CanCollide off. Alternating orange/cream gores.")
def canopy(m):
    R, z0 = 7.0, 12.0
    outer = [(R, z0), (R * 0.93, z0 + 1.7), (R * 0.72, z0 + 3.2), (R * 0.4, z0 + 4.1), (0.7, z0 + 4.4)]
    inner = [(0.7, z0 + 4.25), (R * 0.4, z0 + 3.95), (R * 0.72, z0 + 3.05), (R * 0.93, z0 + 1.55),
             (R - 0.12, z0 + 0.05)]
    v = m.lathe("chute_a", outer + inner, 16, closed=True)
    m.paint_where(v, "chute_b", lambda c, n: int((math.atan2(c.y, c.x) + math.pi) / (math.tau / 8)) % 2 == 0)
    m.meta["line_anchor_radius"] = R


@asset("SM_Parachute_Lines", "Loot", "Effect", density=2.0, dummy=False,
       pivot="Line convergence point (= crate ParachuteLink_Att).",
       use="Suspension lines + riser (separate so they can be hidden/cut on landing). CanCollide off.")
def lines(m):
    R, z0 = 7.0, 12.0
    for k in range(12):
        a = k * math.tau / 12
        m.sweep("rope", [(0, 0, 0.8), (math.cos(a) * R * 0.99, math.sin(a) * R * 0.99, z0 + 0.02)], 0.035, 3)
    m.sweep("cloth_dark", [(0, 0, 0.0), (0, 0, 0.9)], 0.12, 6)
    for x in (-1.8, 1.8):  # harness straps to the crate lid corners
        for y in (-1.8, 1.8):
            m.sweep("cloth_dark", [(0, 0, 0.1), (x, y, -0.35)], 0.05, 4)


@asset("SM_Beacon", "Loot", "WorldProp", density=1.5, pivot="Centre on the ground.", footprint=[2.5, 2.5],
       use="Drop-zone beacon: tripod with a red lamp. Light_Att for a pulsing red PointLight; Smoke_Att for signal smoke.")
def beacon(m):
    for k in range(3):
        a = k * math.tau / 3
        m.sweep("metal_dark", [(math.cos(a) * 1.1, math.sin(a) * 1.1, -0.1), (0, 0, 3.0)], 0.07, 5)
    m.cylinder("metal_dark", 0.3, 0.3, 0.3, seg=8, loc=(0, 0, 2.9))
    m.cylinder("red_paint", 0.26, 0.22, 0.5, seg=8, loc=(0, 0, 3.2))
    m.cone("metal_dark", 0.3, 0.2, seg=8, loc=(0, 0, 3.7))
    m.sweep("metal", [(0.1, 0, 3.8), (0.1, 0, 5.0)], 0.03, 4)
    m.attach("Light", (0, 0, 3.45))
    m.attach("Smoke", (0, 0, 3.9))
    m.col_box((0, 0, 1.6), (1.6, 1.6, 3.2))


@asset("SM_LandingMarker", "Loot", "WorldProp", density=3.0, pivot="Centre on the ground.", footprint=[10, 10],
       use="Ground X of orange cloth pinned with stones: marks where the package will land (CanCollide off).")
def landing_marker(m):
    for rot in (45, -45):
        m.box("chute_a", (10, 1.3, 0.06), loc=(0, 0, 0.03), rot=(0, 0, rot))
    for k in range(4):
        a = math.radians(45 + k * 90)
        m.blob("stone", 0.35, loc=(math.cos(a) * 4.6, math.sin(a) * 4.6, 0.12), scale=(1.2, 1, 0.6))
    m.flatten_below(0)


def supply(m, W, D, H, lid_name, band=True):
    m.box("wood", (W, D, H), loc=(0, 0, H / 2), bevel=0.05)
    for x in (-W / 2 + 0.1, W / 2 - 0.1):
        m.box("wood_dark", (0.2, D + 0.05, H + 0.02), loc=(x, 0, H / 2))
    if band:
        m.box("rope", (W + 0.06, 0.12, 0.12), loc=(0, -D / 2 - 0.02, H * 0.55))
    lid = m.part(lid_name, placement=(0, D / 2, H))
    lid.meta["pivot"] = "Hinge along the back top edge."
    lid.box("wood_dark", (W + 0.1, D + 0.1, 0.2), loc=(0, -D / 2, 0.1), bevel=0.04)
    lid.box("wood", (W * 0.7, D * 0.5, 0.06), loc=(0, -D / 2, 0.22))
    lid.col_box((0, -D / 2, 0.1), (W + 0.1, D + 0.1, 0.2))
    m.attach("Prompt", (0, -D / 2 - 0.8, H))
    m.attach("Contents", (0, 0, H * 0.5))
    m.col_box((0, 0, H / 2), (W, D, H))


@asset("SM_SupplyCrate_Small01", "Loot", "Structure", density=2.0, pivot="Bottom centre on the ground.",
       footprint=[1.8, 1.8], use="Small unmarked forest supply crate (lid SM_SupplyCrate_Small01_Lid).")
def supply01(m):
    supply(m, 1.8, 1.8, 1.5, "SM_SupplyCrate_Small01_Lid")


@asset("SM_SupplyCrate_Small02", "Loot", "Structure", density=2.0, pivot="Bottom centre on the ground.",
       footprint=[3.2, 1.4], use="Long supply crate (weapons-length; lid SM_SupplyCrate_Small02_Lid).")
def supply02(m):
    supply(m, 3.2, 1.4, 1.1, "SM_SupplyCrate_Small02_Lid")


@asset("SM_SupplyCrate_Small03", "Loot", "Structure", density=2.0, pivot="Bottom centre on the ground.",
       footprint=[2.2, 1.6], use="Rope-bound supply chest half-sunk in moss (lid SM_SupplyCrate_Small03_Lid).")
def supply03(m):
    supply(m, 2.2, 1.6, 1.3, "SM_SupplyCrate_Small03_Lid")
    m.blob("moss", 1.4, loc=(0.4, 0.3, -0.35), scale=(1.4, 1.2, 0.35))
    m.flatten_below(0)


@asset("SM_Bandage_Held", "Loot", "Equippable", density=1.2,
       pivot="Grip point (RightGripAttachment). Roll in the hand, strip hanging forward.",
       use="Held-use bandage (play while healing).")
def bandage_held(m):
    m.cylinder("bandage", 0.28, 0.28, 0.45, seg=10, loc=(-0.225, 0, 0.1), rot=(0, 90, 0), cap="cloth")
    v = m.box("bandage", (0.4, 0.03, 1.2), loc=(0, -0.3, -0.45), bevel=0.01)
    for vv in v:
        vv.co.y -= 0.12 * math.sin((vv.co.z + 0.45) * 3)
    m.torus("red_paint", 0.29, 0.025, seg=10, tseg=3, loc=(0, 0, 0.1), rot=(0, 90, 0))


def rounds(m, n, x0, y0, z, mat_case="brass", tip="metal_dark", r=0.06, h=0.3, dx=0.15):
    for i in range(n):
        m.cylinder(mat_case, r, r, h, seg=6, loc=(x0 + i * dx, y0, z))
        if tip:
            m.cone(tip, r * 0.9, r * 2, seg=6, loc=(x0 + i * dx, y0, z + h))


@asset("SM_Ammo_Pistol", "Loot", "Pickup", density=1.0, icon=True, pivot="Centre on the ground.",
       use="Pistol ammo pickup: small leather-strapped box with short rounds on top.")
def ammo_pistol(m):
    m.box("cloth_dark", (0.9, 0.6, 0.45), loc=(0, 0, 0.23), bevel=0.04)
    m.box("leather", (0.2, 0.62, 0.47), loc=(0.2, 0, 0.23))
    rounds(m, 4, -0.3, -0.1, 0.45, r=0.055, h=0.18)


@asset("SM_Ammo_Shotgun", "Loot", "Pickup", density=1.0, icon=True, pivot="Centre on the ground.",
       use="Shotgun shells: fat red shells with brass bases in a leather pouch.")
def ammo_shotgun(m):
    m.box("leather", (1.1, 0.7, 0.5), loc=(0, 0, 0.25), bevel=0.08)
    for i in range(4):
        x = -0.36 + i * 0.24
        m.cylinder("brass", 0.1, 0.1, 0.1, seg=8, loc=(x, 0, 0.5))
        m.cylinder("red_paint", 0.095, 0.095, 0.35, seg=8, loc=(x, 0, 0.6))


@asset("SM_Ammo_Rifle", "Loot", "Pickup", density=1.0, icon=True, pivot="Centre on the ground.",
       use="Rifle ammo: long rounds on a metal stripper clip atop a wooden box.")
def ammo_rifle(m):
    m.box("wood", (1.3, 0.6, 0.35), loc=(0, 0, 0.18), bevel=0.04)
    m.box("metal_dark", (0.95, 0.1, 0.06), loc=(0, 0, 0.38))
    rounds(m, 5, -0.4, 0, 0.4, r=0.055, h=0.45, dx=0.2)
