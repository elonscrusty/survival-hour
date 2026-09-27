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

BENCH_PIVOT = ("Bottom centre on the ground. Players work from the front (-Z). "
               "Craft_Att = work surface, Prompt_Att = ProximityPrompt / UI anchor.")


def tool_hammer_small(m, loc, rot=(0, 0, 0), head="stone_dark"):
    from sh.kit import xform
    x, y, z = loc
    m.box("wood", (0.12, 0.12, 1.1), loc=(x, y, z), rot=rot)
    m.box(head, (0.45, 0.22, 0.22), loc=(x, y, z + 0.55), rot=rot, bevel=0.03)


@asset("SM_Workbench_Level01", "Camp", "Structure", density=2.5, pivot=BENCH_PIVOT, footprint=[6, 3],
       use="Starting workbench: crude split-log table on stumps with stone tools. Crafts L1 items.",
       notes="Team accent: cloth throw on the right end (team atlas variant).")
def workbench1(m):
    for x in (-2.0, 2.0):
        m.cylinder("bark", 0.75, 0.7, 2.2, seg=9, loc=(x, 0, 0), cap="end_grain")
    for y in (-0.6, 0.6):  # two split halves as the top
        v = m.cylinder("bark", 0.62, 0.62, 6.0, seg=8, loc=(-3.0, y, 2.55), rot=(0, 90, 0), cap="end_grain",
                       scale=(0.55, 1, 1))
        for vv in v:
            vv.co.z = min(vv.co.z, 2.7)
        m.paint_where(v, "wood_fresh", lambda c, n: n.z > 0.9)
    m.blob("stone_dark", 0.55, loc=(-1.6, 0.1, 2.95), scale=(1.2, 1.0, 0.55), jitter=0.05)  # anvil stone
    m.blob("stone_vein", 0.3, loc=(-0.6, -0.4, 2.85), scale=(1.3, 0.8, 0.5), jitter=0.04, subdiv=1)
    tool_hammer_small(m, (0.4, -0.2, 2.8), rot=(90, 0, 70))
    m.torus("rope", 0.35, 0.08, seg=10, tseg=4, loc=(1.2, 0.4, 2.8))
    m.torus("rope", 0.3, 0.08, seg=10, tseg=4, loc=(1.2, 0.4, 2.95))
    v = m.box("team_cloth", (1.3, 2.3, 0.08), loc=(2.35, 0, 2.74))
    for vv in v:  # drape over the front and back edges
        if abs(vv.co.y) > 1.0:
            vv.co.z -= 0.6
    m.box("leather", (0.9, 0.7, 0.05), loc=(-0.2, 0.45, 2.73), rot=(0, 0, 12))
    m.attach("Craft", (0, 0, 2.75))
    m.attach("Prompt", (0, -1.6, 3.6))
    m.col_box((0, 0, 1.4), (6.0, 2.6, 2.8))


@asset("SM_Workbench_Level02", "Camp", "Structure", density=2.5, pivot=BENCH_PIVOT, footprint=[7, 3.5],
       use="Level 2: plank bench with vise, shelf, hanging saw/hammer and a painted team backboard.",
       notes="Team accent: painted backboard (team_paint).")
def workbench2(m):
    top = 3.0
    m.box("wood", (7.0, 3.0, 0.3), loc=(0, 0, top - 0.15), bevel=0.05)
    for x in (-3.1, 3.1):
        for y in (-1.2, 1.2):
            m.box("wood_dark", (0.4, 0.4, top - 0.3), loc=(x, y, (top - 0.3) / 2), bevel=0.04)
    m.box("wood_dark", (6.4, 2.6, 0.18), loc=(0, 0, 0.8), bevel=0.03)  # lower shelf
    for i in range(3):
        m.box("wood_fresh", (2.0, 0.5, 0.18), loc=(-1.5 + i * 0.3, -0.5 + i * 0.5, 1.0 + i * 0.18))
    m.box("wood_dark", (6.2, 0.15, 0.3), loc=(0, -1.25, 1.6), rot=(0, 18, 0))  # brace
    # backboard with team paint + tools
    m.box("team_paint", (6.6, 0.25, 3.0), loc=(0, 1.35, top + 1.7), bevel=0.04)
    for x in (-3.2, 3.2):
        m.box("wood_dark", (0.3, 0.3, 4.9), loc=(x, 1.35, top + 1.0 - 0.55))
    m.box("wood_dark", (6.8, 0.35, 0.3), loc=(0, 1.35, top + 3.25))
    # saw
    m.prism("metal", [(-1.2, 0), (1.1, 0), (1.1, 0.45), (-1.2, 0.2)], 0.04, loc=(-1.6, 1.18, top + 1.9))
    m.box("wood", (0.35, 0.1, 0.5), loc=(-0.35, 1.18, top + 2.1), bevel=0.03)
    tool_hammer_small(m, (1.2, 1.18, top + 1.4), rot=(0, 0, 0), head="metal_dark")
    m.torus("rope", 0.45, 0.08, seg=10, tseg=4, loc=(2.4, 1.15, top + 1.7), rot=(90, 0, 0))
    # vise on the front-left corner
    m.box("wood_dark", (0.8, 0.6, 0.6), loc=(-2.8, -1.25, top + 0.3), bevel=0.05)
    m.cylinder("metal_dark", 0.08, 0.08, 1.0, seg=6, loc=(-2.8, -1.1, top + 0.3), rot=(90, 0, 0))
    m.box("leather_dark", (1.2, 0.8, 0.25), loc=(1.4, -0.3, top + 0.12), bevel=0.06)
    m.attach("Craft", (0, -0.4, top))
    m.attach("Prompt", (0, -1.9, top + 1.2))
    m.col_box((0, 0, top / 2), (7.0, 3.0, top))
    m.col_box((0, 1.35, top + 1.7), (6.8, 0.4, 3.4))


@asset("SM_Workbench_Level03", "Camp", "Structure", density=2.5, pivot=BENCH_PIVOT, footprint=[8, 4],
       use="Level 3: iron-banded timber bench, anvil, grinding wheel, tool rack, team banner.",
       notes="Team accent: banner hanging from the rack. Metal parts share the atlas (Metalness map).")
def workbench3(m):
    top = 3.1
    m.box("wood_dark", (8.0, 3.4, 0.45), loc=(0, 0, top - 0.22), bevel=0.06)
    for x in (-3.0, 0.0, 3.0):
        m.box("metal_dark", (0.14, 3.5, 0.5), loc=(x, 0, top - 0.22))
    for x in (-3.6, 3.6):
        for y in (-1.4, 1.4):
            m.box("wood", (0.55, 0.55, top - 0.45), loc=(x, y, (top - 0.45) / 2), bevel=0.05)
            m.box("metal_dark", (0.62, 0.62, 0.3), loc=(x, y, 0.3), bevel=0.03)
    m.box("wood", (7.0, 0.3, 0.4), loc=(0, -1.4, 0.9), bevel=0.04)
    m.box("wood", (7.0, 0.3, 0.4), loc=(0, 1.4, 0.9), bevel=0.04)
    # anvil on its own stump, left of the bench
    m.cylinder("bark", 0.8, 0.75, 1.9, seg=9, loc=(-5.3, -0.3, 0), cap="end_grain")
    m.box("metal_dark", (1.2, 0.6, 0.5), loc=(-5.3, -0.3, 2.15), bevel=0.06)
    m.box("metal_dark", (0.7, 0.45, 0.35), loc=(-5.3, -0.3, 1.82))
    m.cone("metal_dark", 0.28, 0.8, seg=6, loc=(-4.7, -0.3, 2.2), rot=(0, 90, 0), scale=(1, 0.8, 1))
    # grinding wheel on the right end
    m.cylinder("stone", 0.9, 0.9, 0.3, seg=14, loc=(3.0, -0.4, top + 1.0), rot=(90, 0, 0), cap="stone_dark")
    m.cylinder("metal_dark", 0.08, 0.08, 1.1, seg=6, loc=(3.0, -0.95, top + 1.0), rot=(-90, 0, 0))
    for y in (-0.8, 0.0):
        m.box("wood", (0.25, 0.2, 1.1), loc=(3.0, y, top + 0.5))
    m.box("metal", (0.1, 0.1, 0.5), loc=(3.0, -1.35, top + 0.8))
    # tool rack and banner
    for x in (-3.8, 3.8):
        m.box("wood", (0.35, 0.35, 5.2), loc=(x, 1.55, top + 2.1))
    m.box("wood", (8.0, 0.4, 0.35), loc=(0, 1.55, top + 4.5))
    m.box("wood", (7.4, 0.25, 0.25), loc=(0, 1.55, top + 2.8))
    v = m.box("team_cloth", (2.6, 0.08, 3.2), loc=(0, 1.35, top + 2.85))
    m.prism("team_cloth", [(-1.3, 0), (1.3, 0), (0, -0.7)], 0.08, loc=(0, 1.35, top + 1.25))
    for i, x in enumerate((-2.8, -2.0, 2.0, 2.8)):
        m.box("wood", (0.12, 0.12, 1.5), loc=(x, 1.3, top + 2.1))
        m.box("metal" if i % 2 else "metal_dark", (0.5, 0.2, 0.25), loc=(x, 1.3, top + 2.8), bevel=0.03)
    m.box("leather_stitch", (1.6, 1.0, 0.1), loc=(-1.4, -0.3, top + 0.05), rot=(0, 0, -8))
    m.box("metal", (1.2, 0.35, 0.12), loc=(0.6, -0.5, top + 0.06), rot=(0, 0, 20))
    m.attach("Craft", (0, -0.5, top))
    m.attach("Prompt", (0, -2.1, top + 1.2))
    m.col_box((0, 0, top / 2), (8.0, 3.4, top))
    m.col_box((-5.3, -0.3, 1.2), (1.6, 1.6, 2.4))
    m.col_box((0, 1.55, top + 2.1), (8.0, 0.5, 4.8))
