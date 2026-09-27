"""Resource pickups: world drop + inventory icon models.

Each has a unique silhouette at a glance. Sizes are exaggerated slightly
(~1.2-1.8 studs) so drops stay visible on mobile. Pivot: centre on the
ground. Suggested: Anchored off, CanCollide on, CollisionFidelity Box, plus
a gentle spin/bob.
"""

import math

from mathutils import Vector

from sh.pipeline import asset

PIV = "Centre, resting on the ground."
D = 1.0  # texel density for pickups


@asset("SM_Pickup_Stick", "Pickups", "Pickup", density=D, icon=True, pivot=PIV,
       use="Stick: three thin sticks tied with fibre (long, thin, crossed).")
def stick(m):
    for k, a in enumerate((-12, 0, 14)):
        r = math.radians(a)
        d = Vector((math.cos(r), math.sin(r), 0)) * 0.85
        m.sweep("bark", [Vector((0, 0, 0.12 + k * 0.06)) - d, Vector((0, 0, 0.14 + k * 0.06)) + d],
                [0.065, 0.05], 5, cap_mat="end_grain")
    m.torus("fiber", 0.2, 0.04, seg=8, tseg=3, loc=(0, 0, 0.2), rot=(0, 90, 0))


@asset("SM_Pickup_Stone", "Pickups", "Pickup", density=D, icon=True, pivot=PIV, uv_box=True,
       use="Rock/stone: two veined chunks (matches the stone deposits).")
def stone(m):
    m.blob("stone_vein", 0.42, loc=(-0.15, 0, 0.3), scale=(1.2, 1.0, 0.8), jitter=0.06)
    m.blob("stone", 0.3, loc=(0.4, 0.15, 0.2), scale=(1.1, 1.0, 0.8), jitter=0.05)
    m.flatten_below(0)


@asset("SM_Pickup_Wood", "Pickups", "Pickup", density=D, icon=True, pivot=PIV,
       use="Wood: stack of chunky split logs with bright end grain.")
def wood(m):
    for i, (x, z) in enumerate(((-0.28, 0.24), (0.28, 0.24), (0.0, 0.68))):
        m.cylinder("bark", 0.26, 0.26, 1.3, seg=7, loc=(x, -0.65, z), rot=(-90, 0, 0), cap="end_grain",
                   scale=(1, 1, 1))


@asset("SM_Pickup_Fiber", "Pickups", "Pickup", density=D, icon=True, pivot=PIV,
       use="Plant fibre: pale-gold bundle tied at the waist, fanned ends.")
def fiber(m):
    for k in range(9):
        a = (k - 4) * 0.12
        y0 = -0.8
        pts = [(math.sin(a) * 0.5, y0, 0.12 + abs(a) * 0.1), (0, 0, 0.18),
               (math.sin(a) * 0.55, 0.85, 0.12 + abs(a) * 0.12)]
        m.sweep("fiber", pts, [0.03, 0.05, 0.02], 3)
    m.torus("rope", 0.12, 0.04, seg=8, tseg=3, loc=(0, 0, 0.18), rot=(90, 0, 0))


@asset("SM_Pickup_Rope", "Pickups", "Pickup", density=D, icon=True, pivot=PIV,
       use="Rope: flat coil with a trailing end.")
def rope(m):
    pts = []
    turns = 3.2
    n = 60
    for i in range(n):
        t = i / (n - 1)
        a = t * turns * math.tau
        r = 0.55 - 0.05 * math.floor(t * turns)
        pts.append((math.cos(a) * r, math.sin(a) * r, 0.08 + t * 0.2))
    pts.append((0.9, -0.3, 0.06))
    m.sweep("rope", pts, 0.075, 5)


@asset("SM_Pickup_Leather", "Pickups", "Pickup", density=D, icon=True, pivot=PIV,
       use="Leather: folded hides with stitched edges, tied with cord.")
def leather(m):
    for i in range(3):
        v = m.box("leather_stitch" if i == 2 else ("leather" if i % 2 == 0 else "leather_dark"),
                  (1.3 - i * 0.08, 0.9 - i * 0.05, 0.1), loc=(0, 0, 0.06 + i * 0.1), rot=(0, 0, i * 5), bevel=0.03)
        for vv in v:
            vv.co.z += 0.05 * math.sin(vv.co.x * 3)
    m.torus("rope", 0.62, 0.03, seg=12, tseg=3, loc=(0, 0, 0.18), rot=(0, 90, 0), scale=(0.35, 1, 1))


@asset("SM_Pickup_Ammo", "Pickups", "Pickup", density=D, icon=True, pivot=PIV,
       use="Generic ammunition: open wooden case of brass cartridges.")
def ammo(m):
    m.box("wood_dark", (1.2, 0.8, 0.45), loc=(0, 0, 0.23), bevel=0.04)
    m.box("metal_dark", (1.25, 0.1, 0.12), loc=(0, -0.4, 0.3))
    for i in range(5):
        for j in range(3):
            x, y = -0.4 + i * 0.2, -0.2 + j * 0.2
            m.cylinder("brass", 0.07, 0.07, 0.35, seg=6, loc=(x, y, 0.35))
            m.cone("metal_dark", 0.06, 0.12, seg=6, loc=(x, y, 0.7))


@asset("SM_Pickup_Bandage", "Pickups", "Pickup", density=D, icon=True, pivot=PIV,
       use="Bandage: white roll with a loose tail and a red cross-free band (no medical symbols).")
def bandage(m):
    m.cylinder("bandage", 0.35, 0.35, 0.55, seg=10, loc=(-0.275, 0, 0.36), rot=(0, 90, 0), cap="cloth")
    m.box("bandage", (0.5, 1.0, 0.03), loc=(0, -0.6, 0.02), bevel=0.01)
    m.torus("red_paint", 0.36, 0.03, seg=10, tseg=3, loc=(0, 0, 0.36), rot=(0, 90, 0))


@asset("SM_Pickup_Diamond", "Pickups", "Pickup", density=D, icon=True, pivot="Centre of the gem.",
       use="Diamond currency: large faceted gem (world drop, shop and UI icon model).",
       notes="Suggested: Material Glass or Neon rim light; spin slowly.")
def diamond(m):
    prof = [(0.0, -0.7), (0.62, 0.0), (0.66, 0.08), (0.45, 0.32), (0.0, 0.34)]
    m.lathe("diamond", prof, 8, loc=(0, 0, 0.75))
