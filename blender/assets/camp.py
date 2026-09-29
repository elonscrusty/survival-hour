"""Starting camp: campfire (3 states + effects) and workbenches level 1-3."""

import math

from mathutils import Vector

from sh.pipeline import asset

FIRE_NOTE = ("Attachments: Fire_Att (flame emitter base), Smoke_Att (smoke column), Light_Att "
             "(PointLight, warm, Range ~28), Extinguish_Att (steam burst), WaterTarget_Att "
             "(centre of the pour zone, radius 2.3), TeamFlag_Att (top of the team stake: put a "
             "Highlight or Billboard marker here so the fire reads through walls).")


def stone_ring(m, radius=2.7, count=11, mats=("stone", "stone_dark", "stone_mossy")):
    for i in range(count):
        a = i / count * math.tau + m.rng.uniform(-0.06, 0.06)
        s = m.rng.uniform(0.95, 1.25)
        m.blob(mats[i % len(mats)], 0.62 * s,
               loc=(math.cos(a) * radius, math.sin(a) * radius, 0.3 * s),
               rot=(0, 0, math.degrees(a)), scale=(0.85, 1.15, 0.7), jitter=0.1)
    m.flatten_below(0.0)


def fire_logs(m, state):
    bark = {"burning": "bark", "extinguished": "charcoal", "cold": "wet_wood"}[state]
    low = {"burning": "embers", "extinguished": "charcoal", "cold": "wet_wood"}[state]
    for i in range(5):
        a = i / 5 * math.tau + 0.3
        d = Vector((math.cos(a), math.sin(a), 0))
        base = d * 1.75 + Vector((0, 0, 0.15))
        tip = d * 0.15 + Vector((0, 0, 1.9 if state != "extinguished" else 1.1))
        v = m.sweep(bark, [base - d * 0.25, (base + tip) / 2, tip], [0.26, 0.24, 0.2], 7,
                    cap_mat="end_grain" if state == "cold" else "charcoal")
        m.paint_where(v, low, lambda c, n: c.z < 0.75)
    if state == "extinguished":  # collapsed charred chunks
        for i in range(4):
            a = m.rng.uniform(0, math.tau)
            m.box("charcoal", (0.9, 0.35, 0.3), loc=(math.cos(a) * 0.6, math.sin(a) * 0.6, 0.25),
                  rot=(0, 10, math.degrees(a)), bevel=0.05)


def campfire(m, state):
    stone_ring(m)
    bed = {"burning": "embers", "extinguished": "ash", "cold": "ash"}[state]
    m.cylinder(bed, 2.25, 2.1, 0.14, seg=14, cap=bed)
    fire_logs(m, state)
    if state == "cold":  # puddle + soaked ash
        m.cylinder("water", 1.9, 1.9, 0.06, seg=14, loc=(0.2, -0.1, 0.13), cap="water")
    # team stake: tall, readable over walls, carries the team colour
    sx, sy = 2.1, 2.6
    m.sweep("wood_dark", [(sx, sy, -0.3), (sx + 0.05, sy, 3.0), (sx, sy + 0.05, 6.2)], [0.13, 0.11, 0.08], 6)
    m.cylinder("team_cloth", 0.2, 0.2, 0.8, seg=6, loc=(sx + 0.02, sy + 0.02, 4.9))
    m.prism("team_cloth", [(0, 0), (1.4, -0.25), (0, -0.7)], 0.06, loc=(sx + 0.15, sy, 6.1),
            rot=(0, 0, 0))
    m.cylinder("rope", 0.18, 0.18, 0.12, seg=6, loc=(sx + 0.02, sy + 0.02, 5.9))
    for n, loc in (("Fire", (0, 0, 0.6)), ("Smoke", (0, 0, 3.6)), ("Light", (0, 0, 2.4)),
                   ("Extinguish", (0, 0, 1.2)), ("WaterTarget", (0, 0, 0.2)),
                   ("TeamFlag", (sx, sy, 6.3))):
        m.attach(n, loc)
    m.col_box((0, 0, 0.45), (6.4, 6.4, 0.9))
    m.meta["state"] = state
    m.meta["water_target_radius"] = 2.3


@asset("SM_Campfire_Burning", "Camp", "Structure", density=2.5, lod=True,
       use="Team campfire, lit. Show SM_Campfire_Flames on top (Material Neon) plus Fire/Smoke/Light effects.",
       pivot="Centre of the fire pit on the ground.", fidelity="Box", footprint=[6.4, 6.4],
       notes=FIRE_NOTE)
def campfire_burning(m):
    campfire(m, "burning")


@asset("SM_Campfire_Extinguished", "Camp", "Structure", density=2.5, lod=True,
       use="Just put out: charred, collapsed logs over ash. Emit steam from Extinguish_Att for a few seconds.",
       pivot="Centre of the fire pit on the ground.", footprint=[6.4, 6.4], notes=FIRE_NOTE)
def campfire_out(m):
    campfire(m, "extinguished")


@asset("SM_Campfire_ColdWet", "Camp", "Structure", density=2.5, lod=True,
       use="Cold / soaked state: dark wet logs and a puddle. Relight to return to Burning.",
       pivot="Centre of the fire pit on the ground.", footprint=[6.4, 6.4], notes=FIRE_NOTE)
def campfire_cold(m):
    campfire(m, "cold")


@asset("SM_Campfire_Flames", "Camp", "Effect", density=2.0, smooth=60,
       use="Flame body for the burning state. Set Material = Neon, CanCollide/CanQuery off; "
           "scale Y 0.8-1.1 in a loop for flicker.",
       pivot="Centre of the fire pit on the ground (same as the campfire).", fidelity="Box")
def campfire_flames(m):
    for i, (r, h, rot) in enumerate(((1.25, 3.4, 0), (0.95, 4.3, 40), (0.8, 3.0, 110), (0.55, 4.9, 200))):
        v = m.cone("fire", r, h, seg=7, loc=(0.2 * math.cos(i * 2), 0.2 * math.sin(i * 2), 0.25),
                   rot=(0, 0, rot))
        for vv in v:  # twist the flame tongues
            t = max(vv.co.z, 0) / h
            a = t * 1.6
            x, y = vv.co.x, vv.co.y
            vv.co.x = x * math.cos(a) - y * math.sin(a) + 0.25 * t * math.sin(i)
            vv.co.y = x * math.sin(a) + y * math.cos(a)


@asset("SM_Campfire_WaterTarget", "Camp", "Effect", density=2.0,
       use="Pour-zone ring shown to a player holding water near an enemy fire. Material Neon, "
           "Transparency ~0.4, CanCollide off.",
       pivot="Centre of the fire pit on the ground (same as the campfire).", fidelity="Box",
       footprint=[4.8, 4.8])
def campfire_target(m):
    m.torus("water", 2.3, 0.1, seg=28, tseg=4, loc=(0, 0, 0.35), scale=(1, 1, 0.5))
    for i in range(8):
        a = i / 8 * math.tau
        m.cone("water", 0.22, 0.45, seg=4, loc=(math.cos(a) * 2.75, math.sin(a) * 2.75, 0.35),
               rot=(0, -90, math.degrees(a) + 180))


# ------------------------------------------------------------- workbenches
# Five tiers that must read as clear upgrades: I stone-age log bench, II carpenter's
# plank bench, III iron-banded smithy bench, IV/V (survival_wars.py) forge benches.
# Each keeps its published outer bounds exactly (tools/check_bounds.py), so the
# pieces that touch a bound are marked "bound" below.

BENCH_PIVOT = ("Bottom centre on the ground. Players work from the front (-Z). "
               "Craft_Att = work surface, Prompt_Att = ProximityPrompt / UI anchor.")


def grp(m, loc, rot, build, scale=1.0):
    """Build a sub-assembly at the origin, then move it into place."""
    from sh.kit import xform
    before = set(m.bm.verts)
    build()
    new = [v for v in m.bm.verts if v not in before]
    m.transform(new, xform(loc, rot, scale))
    return new


def nail(m, x, y, z, mat="metal_dark", s=0.09):
    """Flat four-sided nail / rivet head (6 tris)."""
    m.cone(mat, s * 0.7, 0.06, seg=4, loc=(x, y, z - 0.01))


def cbox(m, mat, size, loc=(0, 0, 0), rot=(0, 0, 0), c=0.04, axis=None):
    """Box with the four edges along its longest axis chamfered: reads like a bevelled
    plank or post for 28 tris instead of the 44 of a fully bevelled box."""
    from sh.kit import xform
    sx, sy, sz = size
    axis = axis or "xyz"[max(range(3), key=lambda i: size[i])]
    u, w, L = {"x": (sy, sz, sx), "y": (sx, sz, sy), "z": (sx, sy, sz)}[axis]
    c = min(c, u / 3, w / 3)
    hu, hw = u / 2, w / 2
    prof = [(-hu + c, -hw), (hu - c, -hw), (hu, -hw + c), (hu, hw - c), (hu - c, hw), (-hu + c, hw),
            (-hu, hw - c), (-hu, -hw + c)]
    verts = m.prism(mat, prof, L)
    pre = {"x": xform(rot=(0, 0, 90)), "y": xform(), "z": xform(rot=(90, 0, 0))}[axis]
    m.transform(verts, xform(loc, rot) @ pre)
    return verts


def plank_run(m, mat, x0, x1, y0, y1, z0, z1, n, gap=0.05, bevel=0.035, nails_at=(), jit=0.015,
              mats=None, nail_mat="metal_dark"):
    """n planks running along X that fill the rectangle, with nail heads at nails_at (x)."""
    w = (y1 - y0 - gap * (n - 1)) / n
    for i in range(n):
        y = y0 + w / 2 + i * (w + gap)
        dz = m.rng.uniform(-jit, 0) if jit else 0.0
        pm = mats[i % len(mats)] if mats else mat
        if bevel:
            cbox(m, pm, (x1 - x0, w, z1 - z0), loc=((x0 + x1) / 2, y, (z0 + z1) / 2 + dz), c=bevel * 1.4)
        else:
            m.box(pm, (x1 - x0, w, z1 - z0), loc=((x0 + x1) / 2, y, (z0 + z1) / 2 + dz))
        for x in nails_at:
            nail(m, x, y, z1 + dz, nail_mat)


# --- tools (built in local space: handle along +Z from the origin, flat side facing -Y)

def hammer(m, loc, rot=(0, 0, 0), s=1.0, kind="claw", head="metal_dark", handle="wood"):
    def b():
        L = 1.15 * s
        m.cylinder(handle, 0.065 * s, 0.055 * s, L, seg=6)
        hz = L - 0.1 * s
        if kind == "stone":
            m.blob(head, 0.22 * s, loc=(0.05 * s, 0, hz), scale=(1.6, 1.0, 0.9), jitter=0.03, subdiv=1)
            m.cylinder("rope", 0.1 * s, 0.1 * s, 0.22 * s, seg=6, loc=(0, 0, hz - 0.3 * s))
        elif kind == "mallet":
            m.cylinder("wood_dark", 0.19 * s, 0.19 * s, 0.62 * s, seg=8, loc=(-0.31 * s, 0, hz), rot=(0, 90, 0),
                       cap="end_grain")
        elif kind == "sledge":
            cbox(m, head, (0.62 * s, 0.26 * s, 0.26 * s), loc=(0, 0, hz), c=0.05 * s)
        else:
            m.box(head, (0.36 * s, 0.19 * s, 0.19 * s), loc=(0.06 * s, 0, hz))
            m.cylinder(head, 0.13 * s, 0.13 * s, 0.1 * s, seg=4, loc=(0.24 * s, 0, hz), rot=(45, 90, 0))
            if kind == "claw":
                m.prism(head, [(-0.1 * s, -0.08 * s), (-0.1 * s, 0.09 * s), (-0.3 * s, 0.02 * s),
                               (-0.42 * s, -0.2 * s), (-0.3 * s, -0.08 * s)], 0.15 * s, loc=(0, 0, hz))
    return grp(m, loc, rot, b)


def saw(m, loc, rot=(0, 0, 0), L=1.7, blade="metal", teeth=7):
    """Hand saw lying in the XZ plane: toothed blade to +X, open wooden handle at the origin."""
    def b():
        step = (L - 0.12) / teeth
        pts = [(0.0, 0.0)]
        for i in range(teeth):
            pts += [(0.12 + (i + 0.5) * step, -0.08), (0.12 + (i + 1) * step, 0.0)]
        pts += [(L, 0.2), (0.0, 0.42)]
        m.prism(blade, pts, 0.03)
        ring = [(-0.05, 0, -0.05), (-0.5, 0, 0.0), (-0.58, 0, 0.3), (-0.4, 0, 0.55), (-0.05, 0, 0.5)]
        m.sweep("wood", ring, 0.07, seg=4, closed=True, up_hint=(0, 1, 0))
        m.box("wood", (0.3, 0.1, 0.55), loc=(0.02, 0, 0.22))
        nail(m, 0.02, -0.07, 0.1, "brass", 0.07)
    return grp(m, loc, rot, b)


def chisel(m, loc, rot=(0, 0, 0), s=1.0, blade="metal"):
    def b():
        m.cylinder("wood", 0.07 * s, 0.06 * s, 0.42 * s, seg=6, cap="end_grain")
        m.cylinder("brass", 0.07 * s, 0.07 * s, 0.06 * s, seg=6, loc=(0, 0, -0.05 * s))
        m.prism(blade, [(-0.05 * s, 0), (0.05 * s, 0), (0.07 * s, -0.5 * s), (-0.07 * s, -0.5 * s)], 0.03 * s)
    return grp(m, loc, rot, b)


def file_tool(m, loc, rot=(0, 0, 0), s=1.0):
    def b():
        m.cylinder("wood_dark", 0.07 * s, 0.06 * s, 0.38 * s, seg=6)
        m.prism("metal_dark", [(-0.06 * s, 0), (0.06 * s, 0), (0.04 * s, -0.75 * s), (-0.04 * s, -0.75 * s)],
                0.04 * s)
    return grp(m, loc, rot, b)


def tongs(m, loc, rot=(0, 0, 0), s=1.0, mat="metal_dark"):
    """Blacksmith tongs standing on their handles, jaws up."""
    def b():
        for sx, dy in ((-1, -0.025), (1, 0.025)):
            m.sweep(mat, [(sx * 0.12 * s, dy, 0), (sx * 0.06 * s, dy, 0.8 * s), (-sx * 0.04 * s, dy, 1.02 * s),
                          (-sx * 0.02 * s, dy, 1.3 * s)], [0.035 * s, 0.035 * s, 0.045 * s, 0.03 * s], seg=4)
        m.box(mat, (0.1 * s, 0.12 * s, 0.1 * s), loc=(0, 0, 0.93 * s), rot=(0, 45, 0))
    return grp(m, loc, rot, b)


def axe(m, loc, rot=(0, 0, 0), s=1.0, head="metal", handle="wood"):
    def b():
        m.sweep(handle, [(0, 0, 0), (0.05 * s, 0, 0.6 * s), (0, 0, 1.25 * s)], [0.06 * s, 0.055 * s, 0.065 * s], seg=6)
        m.prism(head, [(-0.07 * s, 0.95 * s), (-0.07 * s, 1.2 * s), (0.2 * s, 1.18 * s), (0.42 * s, 1.34 * s),
                       (0.44 * s, 0.84 * s), (0.2 * s, 1.0 * s)], 0.1 * s)
    return grp(m, loc, rot, b)


def anvil(m, loc, rot=(0, 0, 0), s=1.0):
    """Horn to +X, heel to -X; the polished face is on top at 0.95 * s."""
    def b():
        v = m.prism("metal_dark", [(-0.55, 0), (0.55, 0), (0.42, 0.14), (0.25, 0.22), (0.25, 0.5), (0.55, 0.66),
                                   (0.62, 0.95), (-0.8, 0.95), (-0.8, 0.8), (-0.3, 0.62), (-0.25, 0.5),
                                   (-0.25, 0.22), (-0.42, 0.14)], 0.55, scale=(s, s, s))
        m.paint_where(v, "metal", lambda c, n: n.z > 0.9 and c.z > 0.9 * s)
        m.cone("metal_dark", 0.2 * s, 0.62 * s, seg=8, loc=(0.6 * s, 0, 0.8 * s), rot=(0, 84, 0),
               scale=(1.0, 1.0, 1.0))
    return grp(m, loc, rot, b)


def bucket(m, loc, r=0.42, h=0.85, water=True):
    x, y, z = loc
    m.cylinder("wood", r * 0.88, r, h, seg=8, loc=loc, cap="end_grain")
    for t in (0.18, 0.72):
        rr = r * (0.88 + 0.12 * t) + 0.02
        m.cylinder("metal_dark", rr, rr, 0.08, seg=8, loc=(x, y, z + h * t))
    if water:
        m.cylinder("water", r * 0.93, r * 0.93, 0.04, seg=8, loc=(x, y, z + h - 0.06))


def ingot(m, loc, rot=(0, 0, 0), mat="metal"):
    m.prism(mat, [(-0.32, 0), (0.32, 0), (0.24, 0.16), (-0.24, 0.16)], 0.26, loc=loc, rot=rot)


def rope_coil(m, loc, rot=(0, 0, 0), R=0.32, n=1):
    x, y, z = loc
    for i in range(n):
        m.torus("rope", R - i * 0.04, 0.075, seg=9, tseg=4, loc=(x, y, z + i * 0.1), rot=rot)


def log_piece(m, a, b, r, mat="bark"):
    m.sweep(mat, [a, b], r, seg=7, cap_mat="end_grain")


# ------------------------------------------------------------- Tier I

@asset("SM_Workbench_Level01", "Camp", "Structure", density=2.5, pivot=BENCH_PIVOT, footprint=[6, 3],
       use="Starting workbench: split-log table on two stumps, knapping stone, stone hammer and "
           "axe, rope and hides. Crafts L1 items.",
       notes="Team accent: cloth throw on the right end (team atlas variant).")
def workbench1(m):
    # stumps with root flares and peg holes
    for x in (-2.0, 2.0):
        m.cylinder("bark", 0.75, 0.66, 2.26, seg=9, loc=(x, 0, 0), cap="end_grain")
        for k in range(4):
            a = k / 4 * math.tau + 0.4 + x
            c, s_ = math.cos(a), math.sin(a)
            m.sweep("bark", [(x + c * 0.45, s_ * 0.45, 0.55), (x + c * 0.78, s_ * 0.78, 0.18),
                             (x + c * 0.92, s_ * 0.92, 0.02)], [0.22, 0.16, 0.08], seg=5)
    m.flatten_below(0.0)
    # top: two split halves, adzed flat on top (bound: X +-3, Y +-1.22)
    for y in (-0.6, 0.6):
        v = m.cylinder("bark", 0.62, 0.62, 6.0, seg=10, loc=(-3.0, y, 2.55), rot=(0, 90, 0), cap="end_grain",
                       scale=(0.55, 1, 1))
        for vv in v:
            vv.co.z = min(vv.co.z, 2.7)
        m.paint_where(v, "wood_fresh", lambda c, n: n.z > 0.9)
    for x in (-2.0, 2.0):  # pegs driven through into the stumps
        for y in (-0.6, 0.6):
            m.cylinder("wood_dark", 0.1, 0.1, 0.1, seg=6, loc=(x + 0.15 * y, y, 2.66), cap="end_grain")
    # rope lashing tying the halves together near each end
    for x in (-2.6, 1.3):
        m.sweep("rope", [(x, -1.0, 2.25), (x, -1.14, 2.5), (x, -0.95, 2.71), (x, 0, 2.75), (x, 0.95, 2.71),
                         (x, 1.14, 2.5), (x, 1.0, 2.25)], 0.075, seg=4)
    # knapping stone with flint flakes
    m.blob("stone_dark", 0.6, loc=(-1.65, 0.2, 2.82), scale=(1.15, 0.95, 0.38), jitter=0.05)
    for i, (x, y) in enumerate(((-1.4, 0.35), (-1.9, 0.05), (-1.1, -0.35), (-0.8, 0.5))):
        m.prism("stone_vein", [(-0.14, 0), (0.12, 0.02), (0.02, 0.05)], 0.16,
                loc=(x, y, 2.97 if i < 2 else 2.71), rot=(90, 0, 40 * i + 15))
    # stone hammer lying across the top
    hammer(m, (-0.2, -0.75, 2.84), rot=(90, 0, 100), s=0.95, kind="stone", head="stone_dark")
    # stone axe stuck upright in the top (bound: Z 3.46 = handle tip)
    def stuck_axe():
        m.sweep("wood", [(0, 0, 0.1), (0.03, 0, 0.5), (0, 0, 0.95)], [0.07, 0.065, 0.075], seg=6)
        m.prism("stone", [(-0.1, 0.12), (0.12, 0.12), (0.42, -0.1), (0.36, -0.3), (-0.08, -0.02)], 0.16,
                loc=(0, 0, 0.3))
        m.cylinder("rope", 0.1, 0.1, 0.22, seg=6, loc=(0, 0, 0.36))
    grp(m, (-2.35, -0.5, 2.558), (0, -24, 0), stuck_axe)
    # rope coil, hide with bone needle, bundle of sticks
    rope_coil(m, (1.0, 0.5, 2.72), R=0.34)
    v = m.box("leather", (1.0, 0.8, 0.05), loc=(0.25, 0.35, 2.73), rot=(0, 0, 14))
    m.jitter(v, 0.02, (0, 0, 1))
    m.cylinder("bone", 0.03, 0.01, 0.55, seg=4, loc=(0.1, 0.25, 2.79), rot=(0, 90, 30))
    for i, (y, z) in enumerate(((-0.62, 2.76), (-0.8, 2.76), (-0.71, 2.9))):
        m.cylinder("wood", 0.08, 0.08, 1.3, seg=5, loc=(0.35 + i * 0.05, y, z), rot=(0, 90, 0), cap="end_grain")
    m.cylinder("rope", 0.19, 0.19, 0.1, seg=6, loc=(0.95, -0.71, 2.83), rot=(0, 90, 0))
    # team cloth throw over the right end
    v = m.sweep("team_cloth", [(2.3, -1.16, 2.0), (2.3, -1.17, 2.5), (2.3, -1.0, 2.76), (2.3, 0, 2.8),
                               (2.3, 1.0, 2.76), (2.3, 1.17, 2.5), (2.3, 1.16, 2.0)], 0.62, seg=4, flat=0.07,
                up_hint=(0, 1, 0))
    m.jitter(v, 0.02)
    # firewood stacked between the stumps
    for (y, z) in ((-0.35, 0.28), (0.35, 0.28), (0.0, 0.8)):
        log_piece(m, (-1.15, y, z), (1.15, y + 0.05, z), 0.28)
    m.attach("Craft", (0, 0, 2.75))
    m.attach("Prompt", (0, -1.6, 3.6))
    m.col_box((0, 0, 1.4), (6.0, 2.6, 2.8))


# ------------------------------------------------------------- Tier II

@asset("SM_Workbench_Level02", "Camp", "Structure", density=2.5, pivot=BENCH_PIVOT, footprint=[7, 3.5],
       use="Level 2: nailed plank bench with a wooden leg vise, stocked shelf, hand plane and a "
           "team-painted tool board (saw, hammers, chisels, square, rope).",
       notes="Team accent: painted backboard (team_paint).")
def workbench2(m):
    top = 3.0
    # nailed plank top (bound: X +-3.5)
    plank_run(m, "wood", -3.5, 3.5, -1.5, 1.5, top - 0.3, top, 5, nails_at=(-3.15, 3.15),
              mats=("wood", "wood", "wood_fresh"))
    for y in (-1.37, 1.37):
        cbox(m, "wood_dark", (6.1, 0.12, 0.34), loc=(0, y, top - 0.45), c=0.028)
    for x in (-3.1, 3.1):
        for y in (-1.2, 1.2):
            cbox(m, "wood_dark", (0.4, 0.4, top - 0.3), loc=(x, y, (top - 0.3) / 2), c=0.056)
        m.box("wood_dark", (0.16, 2.2, 0.26), loc=(x, 0, 0.7))                      # side rail
        cbox(m, "wood", (0.12, 2.9, 0.22), loc=(x + (0.21 if x > 0 else -0.21), 0, 1.65),
             rot=(-33, 0, 0), c=0.03)                                            # diagonal brace
    # lower shelf with stock
    plank_run(m, "wood_dark", -2.9, 2.9, -1.0, 1.0, 0.72, 0.9, 3, gap=0.08, bevel=0, jit=0)
    for i in range(3):
        m.box("wood_fresh", (2.2, 0.5, 0.14), loc=(-1.6 + i * 0.12, -0.3 + i * 0.06, 0.98 + i * 0.14),
              rot=(0, 0, 3 - i * 4))
    for y, z in ((-0.35, 1.18), (0.3, 1.18), (0.0, 1.62)):
        log_piece(m, (0.6, y, z), (2.6, y, z), 0.26)
    # tool board: posts, painted vertical planks, top rail (bound: Z 6.4, Y +1.5225)
    for x in (-3.25, 3.25):
        cbox(m, "wood_dark", (0.3, 0.3, 3.3), loc=(x, 1.35, top + 1.55), c=0.042)
    m.box("wood_dark", (6.3, 0.08, 2.9), loc=(0, 1.46, top + 1.55))
    for i in range(6):
        x = -2.75 + i * 1.1
        m.box("team_paint", (1.0, 0.12, 2.86), loc=(x, 1.36, top + 1.55 + m.rng.uniform(-0.03, 0.03)))
    cbox(m, "wood_dark", (7.0, 0.35, 0.35), loc=(0, 1.3475, 6.225), c=0.056)
    m.box("wood_dark", (6.5, 0.12, 0.2), loc=(0, 1.26, top + 0.35))
    m.box("wood", (6.2, 0.14, 0.14), loc=(0, 1.22, top + 2.55))                      # peg rail
    for x in (-2.6, -1.4, -0.35, 0.6, 2.4):
        m.cylinder("wood_dark", 0.05, 0.05, 0.22, seg=4, loc=(x, 1.2, top + 2.55), rot=(90, 0, 0))
    saw(m, (-2.7, 1.19, top + 1.55), rot=(0, 0, 0), L=1.7)
    hammer(m, (-0.35, 1.17, top + 2.62), rot=(0, 180, 0), s=0.95)
    hammer(m, (0.6, 1.14, top + 2.62), rot=(0, 180, 0), s=0.8, kind="mallet")
    chisel(m, (1.3, 1.18, top + 2.35), s=1.0)
    chisel(m, (1.6, 1.18, top + 2.35), s=0.85)
    m.box("metal", (0.9, 0.04, 0.12), loc=(2.3, 1.17, top + 1.4))                     # try square
    m.box("wood_dark", (0.14, 0.08, 0.8), loc=(1.9, 1.17, top + 1.73))
    rope_coil(m, (2.55, 1.13, top + 2.1), rot=(90, 0, 0), R=0.36)
    # wooden leg vise on the front-left (bound: screw knob at Y -2.0975)
    cbox(m, "wood_dark", (0.75, 0.22, 1.6), loc=(-2.75, -1.62, top - 0.55), c=0.056)
    m.cylinder("wood", 0.11, 0.11, 0.5975, seg=8, loc=(-2.75, -1.5, top - 0.3), rot=(90, 0, 0),
               cap="end_grain")
    m.cylinder("wood", 0.045, 0.045, 1.0, seg=5, loc=(-3.25, -1.98, top - 0.3), rot=(0, 90, 0))
    # on the bench: a board being planed, shavings, tool roll, glue pot
    cbox(m, "wood_fresh", (2.4, 0.7, 0.14), loc=(0.2, -0.45, top + 0.07), rot=(0, 0, -6), c=0.028)
    def plane():
        cbox(m, "wood_dark", (0.9, 0.3, 0.22), loc=(0, 0, 0.11), c=0.042)
        m.prism("wood", [(-0.4, 0.2), (-0.15, 0.2), (-0.18, 0.46), (-0.34, 0.46)], 0.1)
        m.cylinder("wood", 0.09, 0.07, 0.18, seg=6, loc=(0.3, 0, 0.2))
        m.box("metal", (0.06, 0.24, 0.3), loc=(0.05, 0, 0.3), rot=(0, 30, 0))
    grp(m, (0.5, -0.5, top + 0.14), (0, 0, -6), plane)
    for i in range(2):
        m.torus("wood_fresh", 0.1, 0.03, seg=5, tseg=3, loc=(-0.6 - i * 0.22, -0.35 + (i % 2) * 0.25, top + 0.2),
                rot=(80, 0, 30 * i))
    cbox(m, "leather_dark", (1.1, 0.6, 0.12), loc=(-2.1, 0.3, top + 0.06), rot=(0, 0, 8), c=0.056)
    m.cylinder("stone_dark", 0.22, 0.18, 0.35, seg=8, loc=(2.3, 0.4, top), cap="charcoal")
    m.cylinder("wood", 0.03, 0.03, 0.5, seg=4, loc=(2.3, 0.4, top + 0.15), rot=(15, 0, 0))
    m.attach("Craft", (0, -0.4, top))
    m.attach("Prompt", (0, -1.9, top + 1.2))
    m.col_box((0, 0, top / 2), (7.0, 3.0, top))
    m.col_box((0, 1.35, top + 1.7), (6.8, 0.4, 3.4))


# ------------------------------------------------------------- Tier III

@asset("SM_Workbench_Level03", "Camp", "Structure", density=2.5, pivot=BENCH_PIVOT, footprint=[8, 4],
       use="Level 3: iron-banded timber bench, anvil on a banded stump with quench bucket, crank "
           "grindstone, tool rack with shelves and a team banner.",
       notes="Team accent: banner hanging from the rack. Metal parts share the atlas (Metalness map).")
def workbench3(m):
    top = 3.1
    # heavy beam top wrapped by riveted iron bands (bound: Y +-1.75 = band outer faces, X +4.0)
    plank_run(m, "wood_dark", -4.0, 4.0, -1.7, 1.7, top - 0.45, top, 4, gap=0.06, bevel=0.06, jit=0.02,
              mats=("wood_dark", "wood"))
    for x in (-3.0, 0.0, 3.0):
        m.box("metal_dark", (0.18, 3.46, 0.05), loc=(x, 0, top + 0.02))
        for y in (-1.725, 1.725):
            m.box("metal_dark", (0.18, 0.05, 0.55), loc=(x, y, top - 0.25))
        for y in (-1.2, 0.0, 1.2):
            nail(m, x, y, top + 0.03, "metal", 0.1)
    for x in (-3.6, 3.6):
        for y in (-1.4, 1.4):
            cbox(m, "wood", (0.55, 0.55, top - 0.45), loc=(x, y, (top - 0.45) / 2), c=0.07)
            m.box("metal_dark", (0.63, 0.63, 0.3), loc=(x, y, 0.15))
    for y in (-1.4, 1.4):
        cbox(m, "wood", (6.7, 0.3, 0.4), loc=(0, y, 0.9), c=0.056)
    plank_run(m, "wood_dark", -3.3, 3.3, -1.2, 1.2, 1.1, 1.26, 3, gap=0.08, bevel=0, jit=0)
    # shelf stock: ingots, charcoal sack, rope
    for i, (x, y, z) in enumerate(((-2.4, -0.4, 1.26), (-1.8, -0.4, 1.26), (-2.1, -0.4, 1.42), (-2.4, 0.35, 1.26))):
        ingot(m, (x, y, z), rot=(0, 0, 90 if i == 3 else 0), mat="metal" if i % 2 else "metal_dark")
    m.blob("cloth_dark", 0.55, loc=(0.2, 0.1, 1.72), scale=(1.1, 0.9, 0.9), jitter=0.05, subdiv=1)
    m.cylinder("rope", 0.16, 0.16, 0.12, seg=6, loc=(0.2, 0.1, 2.15))
    # anvil on a banded stump, quench bucket (bound: X -6.089 = stump)
    m.cylinder("bark", 0.77, 0.72, 1.9, seg=10, loc=(-5.3, -0.3, 0), rot=(0, 0, 18), cap="end_grain")
    m.cylinder("metal_dark", 0.789, 0.789, 0.14, seg=10, loc=(-5.3, -0.3, 1.55), rot=(0, 0, 18))
    anvil(m, (-5.2, -0.3, 1.9), s=1.0)
    hammer(m, (-5.5, -0.05, 2.97), rot=(90, 0, 60), s=0.8)
    tongs(m, (-5.0, -1.2, 0.05), rot=(-14, 0, 10), s=1.2)
    bucket(m, (-5.35, 1.12, 0), r=0.4, h=0.85)
    # crank grindstone on the right end
    gx, gy = 2.9, -0.35
    cbox(m, "wood", (1.6, 0.9, 0.3), loc=(gx, gy, top + 0.15), c=0.042)             # trough
    m.box("water", (1.4, 0.7, 0.04), loc=(gx, gy, top + 0.28))
    for y in (gy - 0.3, gy + 0.3):
        m.box("wood", (0.22, 0.14, 1.25), loc=(gx, y, top + 0.72))
    m.cylinder("stone", 0.82, 0.82, 0.26, seg=16, loc=(gx, gy + 0.13, top + 1.12), rot=(90, 0, 0),
               cap="stone_dark")
    m.cylinder("metal_dark", 0.06, 0.06, 1.1, seg=6, loc=(gx, gy + 0.45, top + 1.12), rot=(90, 0, 0))
    m.sweep("metal_dark", [(gx, gy - 0.62, top + 1.12), (gx, gy - 0.62, top + 0.72), (gx, gy - 0.95, top + 0.72)],
            0.05, seg=4)
    m.cylinder("wood", 0.07, 0.07, 0.3, seg=6, loc=(gx, gy - 0.95, top + 0.72), rot=(90, 0, 0))
    # tool rack: posts, crown beam (bound: Z 7.8), rail, shelves
    for x in (-3.8, 3.8):
        cbox(m, "wood", (0.35, 0.35, 5.0), loc=(x, 1.55, top + 2.0), c=0.056)
        m.box("metal_dark", (0.39, 0.39, 0.12), loc=(x, 1.55, top + 3.6))
    cbox(m, "wood_dark", (8.0, 0.4, 0.35), loc=(0, 1.55, 7.625), c=0.07)
    m.box("wood", (7.4, 0.2, 0.2), loc=(0, 1.5, top + 2.1))
    for sx in (-1, 1):
        m.box("wood_dark", (2.1, 0.5, 0.1), loc=(sx * 2.6, 1.42, top + 3.35))
        for dx in (-0.8, 0.8):
            m.prism("wood_dark", [(0, 0), (0.3, 0), (0, -0.3)], 0.08, loc=(sx * 2.6 + dx, 1.6, top + 3.3),
                    rot=(0, 0, -90))
    for i in range(3):
        ingot(m, (-3.1 + i * 0.28, 1.42, top + 3.4 + (0.16 if i == 1 else 0)), rot=(0, 0, 90),
              mat="metal" if i != 1 else "brass")
    m.cylinder("stone_dark", 0.18, 0.15, 0.4, seg=8, loc=(-2.1, 1.42, top + 3.4), cap="charcoal")
    m.cylinder("leather", 0.16, 0.2, 0.32, seg=8, loc=(-1.75, 1.42, top + 3.4))
    rope_coil(m, (2.4, 1.38, top + 3.47), R=0.26)
    m.cylinder("wood", 0.2, 0.2, 0.45, seg=8, loc=(3.15, 1.42, top + 3.4), cap="end_grain")
    # tools hanging from the rail
    tongs(m, (-3.35, 1.34, top + 1.0), s=0.9)
    hammer(m, (-2.75, 1.34, top + 2.2), rot=(0, 180, 0), s=1.05, kind="sledge")
    file_tool(m, (-2.2, 1.36, top + 2.02))
    chisel(m, (-1.85, 1.36, top + 1.92))
    hammer(m, (1.85, 1.34, top + 2.2), rot=(0, 180, 0), s=0.95)
    axe(m, (2.6, 1.34, top + 0.75), rot=(0, 0, 0), s=1.0)
    hammer(m, (3.3, 1.34, top + 2.2), rot=(0, 180, 0), s=0.85, kind="claw")
    # team banner with an anvil emblem, hung from a rod
    m.cylinder("wood_dark", 0.06, 0.06, 2.9, seg=6, loc=(-1.45, 1.35, 7.2), rot=(0, 90, 0))
    for x in (-1.0, 1.0):
        m.sweep("rope", [(x, 1.4, 7.2), (x, 1.45, 7.45)], 0.04, seg=4)
    m.box("team_cloth", (2.5, 0.08, 2.5), loc=(0, 1.36, 5.9))
    m.prism("team_cloth", [(-1.25, 0), (1.25, 0), (1.25, -0.75), (0, -0.3), (-1.25, -0.75)], 0.08,
            loc=(0, 1.36, 4.65))
    m.box("cloth_dark", (2.52, 0.1, 0.22), loc=(0, 1.35, 6.95))
    m.prism("cloth_dark", [(-0.45, 0.0), (0.45, 0.0), (0.3, 0.2), (0.22, 0.45), (0.9, 0.62), (1.0, 0.85),
                           (-0.75, 0.85), (-0.8, 0.62), (-0.3, 0.5), (-0.22, 0.45), (-0.3, 0.2)], 0.04,
            loc=(0.0, 1.31, 5.15))
    # on the bench: leather apron, a blade blank, a small hammer
    m.box("leather_stitch", (1.6, 1.0, 0.08), loc=(-1.6, -0.2, top + 0.09), rot=(0, 0, -8))
    m.prism("metal", [(-0.7, 0), (0.55, 0), (0.75, 0.1), (0.55, 0.2), (-0.7, 0.2)], 0.05,
            loc=(0.3, -0.7, top + 0.1), rot=(90, 0, 18))
    m.attach("Craft", (0, -0.5, top))
    m.attach("Prompt", (0, -2.1, top + 1.2))
    m.col_box((0, 0, top / 2), (8.0, 3.4, top))
    m.col_box((-5.3, -0.3, 1.2), (1.6, 1.6, 2.4))
    m.col_box((0, 1.55, top + 2.1), (8.0, 0.5, 4.8))


@asset("SM_Camp_Hut", "Camp", "Structure", density=2.5, pivot="Bottom centre of the floor, on the ground.",
       footprint=[12, 10],
       use="Clan cabin behind each camp: chunky cartoon log cabin (thick round logs, big overhanging "
           "roof, stone chimney, glowing windows, open doorway and a small porch). Replaces the "
           "procedural Camp.Hut look; its parts stay as the hidden colliders.",
       notes="Front (doorway) faces -Y (Roblox -Z). Team accent: door banner and bedroll (team_cloth).")
def camp_hut(m):
    W, D, WALL = 11.0, 8.4, 6.6  # wall box (X width, Y depth, height); roof/porch overhang to 12 x 10
    hx, hy = W / 2, D / 2
    R = 0.6  # fat cartoon logs
    # stone footing + plank floor
    m.box("stone_dark", (W + 0.6, D + 0.6, 0.5), loc=(0, 0.3, 0.25), bevel=0.12)
    m.box("wood_dark", (W - 0.4, D - 0.4, 0.2), loc=(0, 0.3, 0.6), bevel=0.03)
    rows = int(WALL / (R * 1.8))
    door_w, door_h = 2.6, 4.6
    win_z0, win_z1 = 2.4, 4.6
    for i in range(rows):
        z = 0.5 + R + i * R * 1.8
        alt = (i % 2) * R * 0.9
        # back wall, full length with log ends poking past the corners
        m.cylinder("wood", R, R, W + 1.4, seg=8, loc=(-(W + 1.4) / 2, hy, z), rot=(0, 90, 0), cap="end_grain")
        # side walls (window gap in the middle rows)
        for x in (-hx, hx):
            if win_z0 < z < win_z1:
                for y0, y1 in ((-hy - 0.7, -1.1), (1.1, hy + 0.7)):
                    m.cylinder("wood", R, R, y1 - y0, seg=8, loc=(x, y0, z + alt), rot=(-90, 0, 0), cap="end_grain")
            else:
                m.cylinder("wood", R, R, D + 1.4, seg=8, loc=(x, -hy - 0.7, z + alt), rot=(-90, 0, 0),
                           cap="end_grain")
        # front wall, split around the doorway
        if z < door_h + 0.5:
            for x0, x1 in ((-hx - 0.7, -door_w / 2), (door_w / 2, hx + 0.7)):
                m.cylinder("wood", R, R, x1 - x0, seg=8, loc=(x0, -hy, z), rot=(0, 90, 0), cap="end_grain")
        else:
            m.cylinder("wood", R, R, W + 1.4, seg=8, loc=(-(W + 1.4) / 2, -hy, z), rot=(0, 90, 0), cap="end_grain")
    # door frame + an open plank door swung inward, team banner over the door
    for x in (-door_w / 2, door_w / 2):
        m.box("wood_dark", (0.35, 0.5, door_h), loc=(x, -hy - 0.1, 0.6 + door_h / 2), bevel=0.05)
    m.box("wood_dark", (door_w + 0.7, 0.5, 0.4), loc=(0, -hy - 0.1, 0.6 + door_h + 0.2), bevel=0.05)
    m.box("wood", (0.25, door_w - 0.2, door_h - 0.3), loc=(-door_w / 2 + 0.2, -hy + 1.3, 0.6 + (door_h - 0.3) / 2),
          bevel=0.04)
    v = m.box("team_cloth", (1.6, 0.08, 1.2), loc=(0, -hy - 0.45, 0.6 + door_h + 1.1))
    m.jitter(v, 0.04)
    # glowing windows with cross frames in the side walls
    for x in (-hx, hx):
        s = 1 if x > 0 else -1
        m.box("glow", (0.1, 2.0, win_z1 - win_z0 - 0.3), loc=(x - s * 0.1, 0, (win_z0 + win_z1) / 2 + 0.3))
        m.box("wood_dark", (0.3, 2.5, 0.3), loc=(x + s * 0.25, 0, win_z0 + 0.1), bevel=0.04)
        m.box("wood_dark", (0.3, 2.5, 0.3), loc=(x + s * 0.25, 0, win_z1 + 0.4), bevel=0.04)
        m.box("wood_dark", (0.2, 0.2, win_z1 - win_z0), loc=(x + s * 0.25, 0, (win_z0 + win_z1) / 2 + 0.3))
        m.box("wood_dark", (0.2, 2.2, 0.2), loc=(x + s * 0.25, 0, (win_z0 + win_z1) / 2 + 0.3))
    # log-end gables on the sides, thick overhanging plank roof, ridge beam
    top = 0.5 + rows * R * 1.8 + 0.2
    peak = top + 3.6
    for x in (-hx, hx):
        m.prism("wood", [(-hy - 0.6, top), (hy + 0.6, top), (0, peak - 0.3)], 1.0, loc=(x, 0, 0), rot=(0, 0, 90))
    run = hy + 1.5
    rise = peak - top + 0.5
    ang = math.degrees(math.atan2(rise, run))
    slab = math.hypot(run, rise)
    for s in (-1, 1):
        m.box("wood_dark", (W + 2.4, slab, 0.55), loc=(0, s * run / 2, top + rise / 2 + 0.1),
              rot=(s * -ang, 0, 0), bevel=0.12)
        for k in range(5):  # chunky shingle ridges
            t = (k + 0.5) / 5
            m.box("wood", (W + 2.5, 0.35, 0.2), loc=(0, s * run * t, top + rise * (1 - t) + 0.45),
                  rot=(s * -ang, 0, 0), bevel=0.05)
    m.cylinder("bark", 0.55, 0.55, W + 2.8, seg=8, loc=(-(W + 2.8) / 2, 0, peak + 0.2), rot=(0, 90, 0),
               cap="end_grain")
    # stone chimney on the back-right with a smoke cap
    cx, cy = hx - 1.8, hy + 1.0  # outside the back wall
    for i in range(7):
        m.blob("stone" if i % 2 else "stone_mossy", 0.75, loc=(cx, cy, 1.0 + i * 1.35), scale=(1.4, 1.2, 0.8),
               jitter=0.08)
    m.box("stone_dark", (1.6, 1.4, 0.4), loc=(cx, cy, 10.4), bevel=0.08)
    m.attach("Smoke", (cx, cy, 10.8))
    # little porch: plank deck, two posts, a lantern and a firewood stack
    m.box("wood", (5.5, 1.4, 0.3), loc=(0, -hy - 1.0, 0.45), bevel=0.05)
    for x in (-2.6, 2.6):
        m.cylinder("bark", 0.3, 0.3, 0.9, seg=7, loc=(x, -hy - 1.5, 0))
    m.cylinder("metal_dark", 0.28, 0.28, 0.12, seg=8, loc=(-2.0, -hy - 0.55, 0.6 + door_h - 0.3))
    m.cylinder("glow", 0.22, 0.22, 0.5, seg=8, loc=(-2.0, -hy - 0.55, 0.6 + door_h - 0.85))
    m.attach("Light", (-2.0, -hy - 0.55, 0.6 + door_h - 0.6))
    for k, (x, z) in enumerate(((3.6, 0.9), (4.3, 0.9), (3.95, 1.45))):
        m.cylinder("bark", 0.3, 0.3, 1.6, seg=7, loc=(x, -hy - 0.9, z), rot=(-90, 0, 0), cap="end_grain")
    # inside, seen through the door: bedroll and a crate
    m.box("cloth_dark", (2.0, 4.0, 0.16), loc=(-2.8, 1.2, 0.78), bevel=0.05)
    m.box("team_cloth", (1.9, 2.7, 0.12), loc=(-2.8, 1.7, 0.9), bevel=0.04)
    m.box("wood", (1.5, 1.2, 1.1), loc=(3.2, 2.0, 1.25), bevel=0.06)
    m.col_box((0, 0, 0.45), (W, D, 0.9))
    m.col_box((0, hy, 3.8), (W, 1.2, WALL))
    for x in (-hx, hx):
        m.col_box((x, 0, 3.8), (1.2, D, WALL))
