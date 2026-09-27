"""Forest kit: trees, stumps, logs, branches, rocks, plants, floor props,
landmarks and clearing / camp dressing."""

import math

from mathutils import Vector

from sh.pipeline import asset

TREE_PIVOT = "Base of the trunk at ground level (Z=0 is the ground)."


# ------------------------------------------------------------------ helpers

def trunk(m, mat, height, r0, r1, seg=9, lean=0.4, roots=4, root_len=1.6, wobble=0.25):
    """Tapered, slightly wandering trunk with a root flare. Returns the list
    of centreline points (for attaching limbs)."""
    n = 6
    ang = m.rng.uniform(0, math.tau)
    pts, radii = [], []
    for i in range(n + 1):
        t = i / n
        off = Vector((math.cos(ang), math.sin(ang), 0)) * lean * t * t
        off += Vector((m.rng.uniform(-1, 1), m.rng.uniform(-1, 1), 0)) * wobble * (0 < i < n)
        pts.append(Vector((0, 0, -0.4 + (height + 0.4) * t)) + off)
        radii.append(r0 + (r1 - r0) * t ** 0.8)
    radii[0] *= 1.25
    m.sweep(mat, pts, radii, seg, cap_mat="end_grain")
    for k in range(roots if not m.lod else max(2, roots - 2)):
        a = ang + k * math.tau / roots + m.rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        rl = root_len * m.rng.uniform(0.8, 1.2)
        m.sweep(mat, [Vector((0, 0, 0.9)) + d * r0 * 0.3, Vector((0, 0, 0.35)) + d * (r0 + rl * 0.45),
                      Vector((0, 0, -0.25)) + d * (r0 + rl)],
                [r0 * 0.5, r0 * 0.33, 0.06], 5)
    return pts


def point_on(pts, t):
    f = t * (len(pts) - 1)
    i = min(int(f), len(pts) - 2)
    return pts[i].lerp(pts[i + 1], f - i)


def limb(m, mat, start, direction, length, r0, seg=6, rise=0.25, kinks=3):
    d = Vector(direction).normalized()
    pts = [Vector(start)]
    for i in range(1, kinks + 1):
        t = i / kinks
        p = Vector(start) + d * length * t + Vector((0, 0, rise * length * t * t))
        p += Vector((m.rng.uniform(-1, 1), m.rng.uniform(-1, 1), m.rng.uniform(-1, 1))) * 0.12 * length * (i < kinks)
        pts.append(p)
    radii = [r0 * (1 - 0.75 * i / kinks) for i in range(kinks + 1)]
    m.sweep(mat, pts, radii, seg)
    return pts[-1]


def pine_tier(m, z, r, h, mat="pine_needles", droop=0.7, lobes=7):
    seg = 14
    prof = [(0, z + h * 0.28), (r, z), (r * 0.9, z + h * 0.1), (r * 0.45, z + h * 0.55), (0, z + h)]
    verts = m.lathe(mat, prof, seg, rot=(m.rng.uniform(-5, 5), m.rng.uniform(-5, 5),
                                         m.rng.uniform(0, 360)))
    lobes = m.rng.choice((5, 6, 7))
    phase = m.rng.uniform(0, math.tau)
    for v in verts:
        rad = math.hypot(v.co.x, v.co.y)
        if rad < 1e-4:
            continue
        a = math.atan2(v.co.y, v.co.x)
        f = 1 + 0.24 * math.cos(lobes * a + phase) + m.rng.uniform(-0.1, 0.1)
        v.co.x *= f
        v.co.y *= f
        v.co.z -= droop * (rad / r) ** 2 + m.rng.uniform(0, 0.12)


def canopy(m, centers, mat="leaves", jitter=0.35, flat=0.8):
    for (c, r) in centers:
        m.blob(mat, r, loc=c, scale=(1, 1, flat), jitter=jitter * r / 3, subdiv=3 if r > 2.2 else 2)


def harvest_notch(m, height=1.1, r=0.5):
    """Fresh axe notch on the tree's front: the 'this can be chopped' cue."""
    m.prism("wood_fresh", [(-r * 0.8, -0.35), (r * 0.8, -0.35), (0, 0.35)], 0.5,
            loc=(0, -r * 0.82, height), rot=(0, 0, 0))
    m.attach("HarvestHit", (0, -r - 0.05, height), (0, 0, 0))


# ------------------------------------------------------------------- pines

def pine(m, height, r0, tiers, spread, notch=False):
    pts = trunk(m, "bark_pine", height * 0.92, r0, r0 * 0.25, seg=9, lean=0.25, roots=5,
                root_len=r0 * 2)
    base = height * 0.22
    n = tiers if not m.lod else max(3, tiers - 2)
    for i in range(n):
        t = i / (n - 1)
        z = base + (height - base - 2.4) * t
        c = point_on(pts, min(z / height, 1))
        r = spread * (1 - t * 0.8) * m.rng.uniform(0.92, 1.08)
        h = (2.6 + 1.2 * (1 - t)) * max(0.5, min(1.0, height / 20))
        m.transform(pine_tier_at(m, z, r, h),
                    _tr(c.x + m.rng.uniform(-0.3, 0.3), c.y + m.rng.uniform(-0.3, 0.3)))
    top = point_on(pts, 1.0)
    m.cone("pine_needles", spread * 0.18, 2.6, seg=7, loc=(top.x, top.y, height - 2.6))
    if notch:
        harvest_notch(m, 1.1, r0)
    m.col_box((0, 0, height * 0.3), (r0 * 2.2, r0 * 2.2, height * 0.6))


def pine_tier_at(m, z, r, h):
    before = set(m.bm.verts)
    pine_tier(m, z, r, h, mat=m.rng.choice(("pine_needles", "pine_needles_dark")))
    return [v for v in m.bm.verts if v not in before]


def _tr(x, y):
    from mathutils import Matrix
    return Matrix.Translation((x, y, 0))


@asset("SM_Tree_Pine_Medium01", "Forest", "WorldProp", lod=True, use="Common medium pine.",
       pivot=TREE_PIVOT, footprint=[2, 2],
       notes="Collide with the trunk only (collision box / COL_ file). Needles: CanCollide off.")
def pine_medium01(m):
    pine(m, 20, 0.75, 7, 5.2)


@asset("SM_Tree_Pine_Medium02", "Forest", "WorldProp", lod=True, pivot=TREE_PIVOT, footprint=[2, 2],
       use="Medium pine, narrower.")
def pine_medium02(m):
    pine(m, 17, 0.65, 6, 4.2)


@asset("SM_Tree_Pine_Large01", "Forest", "WorldProp", lod=True, pivot=TREE_PIVOT, footprint=[3, 3],
       use="Tall landmark pine.")
def pine_large01(m):
    pine(m, 32, 1.15, 9, 7.0)


@asset("SM_Tree_Pine_Small01", "Forest", "Harvestable", lod=True, pivot=TREE_PIVOT,
       footprint=[1.5, 1.5], use="Harvestable small pine: gives wood. Axe notch = harvest cue.",
       notes="Swap for SM_Tree_Pine_Small01_Stump when depleted.")
def pine_small01(m):
    pine(m, 10, 0.45, 5, 2.9, notch=True)


# ------------------------------------------------------------ broadleaves

def broadleaf(m, height, r0, limbs, crown, bark="bark", leaf="leaves", leaf2="leaves_dark",
              notch=False, clumps_per=3):
    pts = trunk(m, bark, height * 0.55, r0, r0 * 0.55, seg=9, lean=0.5, roots=5, root_len=r0 * 2.2)
    top = pts[-1]
    centers = [(top + Vector((0, 0, crown * 0.55)), crown * 0.75)]
    for k in range(limbs):
        a = k * math.tau / limbs + m.rng.uniform(-0.4, 0.4)
        start = point_on(pts, m.rng.uniform(0.7, 0.95))
        d = Vector((math.cos(a), math.sin(a), m.rng.uniform(0.6, 1.1)))
        end = limb(m, bark, start, d, height * m.rng.uniform(0.3, 0.42), r0 * 0.5, seg=7)
        for j in range(clumps_per if not m.lod else 1):
            off = Vector((m.rng.uniform(-1, 1), m.rng.uniform(-1, 1), m.rng.uniform(-0.3, 0.6)))
            centers.append((end + off * crown * 0.3, crown * m.rng.uniform(0.42, 0.6)))
    for i, (c, r) in enumerate(centers):
        m.blob(leaf if i % 2 == 0 else leaf2, r, loc=c, scale=(1, 1, 0.78), jitter=0.14 * r,
               subdiv=3 if r > 2.5 else 2)
    if notch:
        harvest_notch(m, 1.0, r0)
    m.col_box((0, 0, height * 0.25), (r0 * 2.2, r0 * 2.2, height * 0.5))


@asset("SM_Tree_Oak_Medium01", "Forest", "WorldProp", lod=True, pivot=TREE_PIVOT, footprint=[2, 2],
       use="Medium broadleaf tree.")
def oak_medium01(m):
    broadleaf(m, 16, 0.85, 4, 4.2)


@asset("SM_Tree_Oak_Medium02", "Forest", "WorldProp", lod=True, pivot=TREE_PIVOT, footprint=[2, 2],
       use="Medium broadleaf tree, wider crown.")
def oak_medium02(m):
    broadleaf(m, 14, 0.8, 5, 4.6, leaf="leaves_dark", leaf2="leaves")


@asset("SM_Tree_Oak_Large01", "Forest", "WorldProp", lod=True, pivot=TREE_PIVOT, footprint=[3.5, 3.5],
       use="Large old broadleaf: clearing centrepiece.")
def oak_large01(m):
    broadleaf(m, 24, 1.5, 6, 6.5, clumps_per=3)


@asset("SM_Tree_Oak_Small01", "Forest", "Harvestable", lod=True, pivot=TREE_PIVOT,
       footprint=[1.5, 1.5], use="Harvestable small broadleaf: gives wood.",
       notes="Swap for SM_Tree_Oak_Small01_Stump when depleted.")
def oak_small01(m):
    broadleaf(m, 8.5, 0.42, 3, 2.3, notch=True, clumps_per=2)


def birch(m, height, r0, crown, notch=False):
    pts = trunk(m, "bark_birch", height * 0.85, r0, r0 * 0.45, seg=8, lean=0.6, roots=3,
                root_len=r0 * 1.5, wobble=0.15)
    centers = []
    for i in range(5 if not m.lod else 3):
        t = 0.45 + 0.55 * i / 4
        c = point_on(pts, t)
        a = m.rng.uniform(0, math.tau)
        if i < 4:
            end = limb(m, "bark_birch", c, (math.cos(a), math.sin(a), 1.4), crown * 0.9, r0 * 0.3, seg=5)
        else:
            end = c
        centers.append((end + Vector((0, 0, 0.4)), crown * m.rng.uniform(0.55, 0.75)))
    centers.append((pts[-1] + Vector((0, 0, crown * 0.5)), crown * 0.7))
    for i, (c, r) in enumerate(centers):
        m.blob("leaves_birch", r, loc=c, scale=(0.85, 0.85, 1.15), jitter=0.12 * r)
    if notch:
        harvest_notch(m, 1.0, r0)
    m.col_box((0, 0, height * 0.3), (r0 * 2.4, r0 * 2.4, height * 0.6))


@asset("SM_Tree_Birch_Medium01", "Forest", "WorldProp", lod=True, pivot=TREE_PIVOT, footprint=[1.5, 1.5],
       use="Pale birch: breaks up the darker pines.")
def birch_medium01(m):
    birch(m, 16, 0.5, 3.0)


@asset("SM_Tree_Birch_Small01", "Forest", "Harvestable", lod=True, pivot=TREE_PIVOT,
       footprint=[1.2, 1.2], use="Harvestable small birch: gives wood.",
       notes="Swap for SM_Tree_Birch_Small01_Stump when depleted.")
def birch_small01(m):
    birch(m, 9, 0.32, 2.0, notch=True)


@asset("SM_Tree_Dead_Large01", "Forest", "WorldProp", lod=True, pivot=TREE_PIVOT, footprint=[2.5, 2.5],
       use="Gnarled dead tree for the mysterious deep-forest mood.")
def dead_large01(m):
    pts = trunk(m, "bark_dead", 15, 1.1, 0.35, seg=9, lean=1.2, roots=5, root_len=2.2, wobble=0.4)

    def grow(start, d, length, r, depth):
        end = limb(m, "bark_dead", start, d, length, r, seg=6 if depth == 0 else 4, rise=0.1)
        if depth < (2 if not m.lod else 1):
            for k in range(2):
                a = math.atan2(d[1], d[0]) + m.rng.uniform(-0.9, 0.9)
                grow(end, (math.cos(a), math.sin(a), m.rng.uniform(0.2, 0.9)), length * 0.55, r * 0.5,
                     depth + 1)
    for k in range(4):
        a = k * math.tau / 4 + m.rng.uniform(-0.5, 0.5)
        grow(point_on(pts, m.rng.uniform(0.55, 0.95)), (math.cos(a), math.sin(a), 0.7), 5.5, 0.45, 0)
    m.col_box((0, 0, 5), (2.4, 2.4, 10))


# --------------------------------------------------------- stumps (depleted)

def stump(m, r, h, bark="bark", fresh=True, chips=True, moss=False):
    trunk_pts = [Vector((0, 0, -0.3)), Vector((0, 0, h * 0.5)), Vector((0, 0, h))]
    m.sweep(bark, trunk_pts, [r * 1.25, r * 1.02, r], 9,
            cap_mat="end_grain" if fresh else "wood_dark")
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        m.sweep(bark, [d * r * 0.3 + Vector((0, 0, h * 0.6)), d * (r + 0.5) + Vector((0, 0, 0.25)),
                       d * (r + 1.1) + Vector((0, 0, -0.2))], [r * 0.45, r * 0.3, 0.05], 5)
    if moss:
        m.blob("moss", r * 0.9, loc=(0.1, 0.1, h), scale=(1, 1, 0.25), jitter=0.05)
    if chips:
        for i in range(5):
            a = m.rng.uniform(0, math.tau)
            d = r + m.rng.uniform(0.4, 1.2)
            m.box("wood_fresh", (0.35, 0.18, 0.06), loc=(math.cos(a) * d, math.sin(a) * d, 0.03),
                  rot=(0, 0, math.degrees(a)))
    m.col_box((0, 0, h / 2), (r * 2.2, r * 2.2, h))


@asset("SM_Tree_Pine_Small01_Stump", "Forest", "Harvestable", pivot=TREE_PIVOT,
       use="Depleted state of SM_Tree_Pine_Small01 (fresh cut + chips).")
def pine_small_stump(m):
    stump(m, 0.45, 0.9, "bark_pine")


@asset("SM_Tree_Oak_Small01_Stump", "Forest", "Harvestable", pivot=TREE_PIVOT,
       use="Depleted state of SM_Tree_Oak_Small01.")
def oak_small_stump(m):
    stump(m, 0.42, 0.85, "bark")


@asset("SM_Tree_Birch_Small01_Stump", "Forest", "Harvestable", pivot=TREE_PIVOT,
       use="Depleted state of SM_Tree_Birch_Small01.")
def birch_small_stump(m):
    stump(m, 0.32, 0.8, "bark_birch")


@asset("SM_Stump_Old01", "Forest", "WorldProp", pivot=TREE_PIVOT, use="Old mossy stump (decor).")
def stump_old01(m):
    stump(m, 1.1, 1.6, "bark", fresh=False, chips=False, moss=True)


@asset("SM_Stump_Old02", "Forest", "WorldProp", pivot=TREE_PIVOT, use="Broken tall stump (decor).")
def stump_old02(m):
    stump(m, 0.9, 2.6, "bark_dead", fresh=False, chips=False)
    for k in range(6):  # jagged broken top
        a = k * math.tau / 6
        m.cone("bark_dead", 0.3, m.rng.uniform(0.6, 1.4), seg=4,
               loc=(math.cos(a) * 0.6, math.sin(a) * 0.6, 2.5))


# ------------------------------------------------------ logs, branches, sticks

def fallen_log(m, length, r, mat="bark", moss=False, hollow=False, broken=False):
    pts = [Vector((-length / 2, 0, r * 0.85)), Vector((0, 0.15, r * 0.9)), Vector((length / 2, 0, r * 0.8))]
    m.sweep(mat, pts, [r, r * 0.95, r * 0.85], 9, cap_mat="end_grain" if not hollow else "wood_dark")
    if hollow:  # dark opening at one end
        m.cylinder("charcoal", r * 0.7, r * 0.7, 0.2, seg=9, loc=(length / 2 - 0.05, 0, r * 0.8),
                   rot=(0, 90, 0))
    if broken:
        for k in range(4):
            a = k * math.tau / 4
            m.cone("wood_fresh", r * 0.35, m.rng.uniform(0.4, 0.8), seg=4,
                   loc=(-length / 2 + 0.05, math.cos(a) * r * 0.5, r * 0.85 + math.sin(a) * r * 0.5),
                   rot=(0, -90, 0))
    for k in range(2):  # stub branches
        x = m.rng.uniform(-length * 0.3, length * 0.3)
        m.sweep(mat, [(x, 0, r * 1.5), (x + 0.3, -0.2, r * 1.5 + 0.9)], [r * 0.25, r * 0.12], 5,
                cap_mat="end_grain")
    if moss:
        m.blob("moss", r * 1.02, loc=(length * 0.1, 0.1, r * 1.15), scale=(length * 0.3 / r, 0.9, 0.35),
               jitter=0.05)
    m.col_box((0, 0, r * 0.85), (length, r * 2, r * 1.7))


@asset("SM_FallenLog01", "Forest", "WorldProp", lod=True, footprint=[8, 1.8], pivot="Centre on the ground.",
       use="Fallen log; players can hop over it.")
def fallen_log01(m):
    fallen_log(m, 8, 0.85, moss=True)


@asset("SM_FallenLog02_Hollow", "Forest", "WorldProp", lod=True, footprint=[10, 2.8],
       pivot="Centre on the ground.", use="Large hollow log, mossy; broken end.")
def fallen_log02(m):
    fallen_log(m, 10, 1.35, mat="bark_dead", moss=True, hollow=True, broken=True)


def branch_shape(m, length, r, twigs, mat="bark"):
    a = Vector((-length / 2, 0, r)); b = Vector((length / 2, 0.3, r * 0.7))
    mid = (a + b) / 2 + Vector((0, 0.3, 0.15))
    m.sweep(mat, [a, mid, b], [r, r * 0.8, r * 0.3], 6, cap_mat="end_grain")
    for k in range(twigs):
        t = (k + 1) / (twigs + 1)
        p = a.lerp(b, t)
        side = 1 if k % 2 else -1
        m.sweep(mat, [p, p + Vector((0.4, side * 0.9, 0.15)), p + Vector((0.9, side * 1.4, 0.1))],
                [r * 0.45, r * 0.3, r * 0.1], 4)
    m.flatten_below(0.0)


@asset("SM_Branch01", "Forest", "WorldProp", density=2.5, pivot="Centre on the ground.",
       fidelity="Box", use="Fallen branch (decor, CanCollide off).")
def branch01(m):
    branch_shape(m, 4.5, 0.2, 4)


@asset("SM_Branch02", "Forest", "WorldProp", density=2.5, pivot="Centre on the ground.",
       use="Forked fallen branch with leaves (decor, CanCollide off).")
def branch02(m):
    branch_shape(m, 3.6, 0.17, 3, "bark_dead")
    for k in range(3):
        m.blob("leaves", 0.45, loc=(m.rng.uniform(-1, 1.5), m.rng.uniform(-1, 1), 0.3),
               scale=(1, 1, 0.5), jitter=0.05)


@asset("SM_Sticks_Loose01", "Forest", "WorldProp", density=2.0, pivot="Centre on the ground.",
       use="Scatter of loose sticks (decor). Pickup version: SM_Pickup_Stick.")
def sticks01(m):
    for k in range(6):
        a = m.rng.uniform(0, 180)
        x, y = m.rng.uniform(-1, 1), m.rng.uniform(-1, 1)
        L = m.rng.uniform(1.2, 2.0)
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0)) * L / 2
        m.sweep("bark", [Vector((x, y, 0.08)) - d, Vector((x, y, 0.1 + k * 0.03)) + d], [0.07, 0.05], 5,
                cap_mat="end_grain")


# ------------------------------------------------------------------ rocks

def rock(m, r, loc=(0, 0, 0), scale=(1.3, 1.0, 0.75), mat="stone", jitter=0.25, subdiv=3):
    v = m.blob(mat, r, loc=loc, scale=scale, jitter=r * jitter / 2, subdiv=subdiv)
    # flatten a few facets for a chiselled, rough-stone look
    for vv in v:
        if vv.co.z > loc[2] + r * scale[2] * 0.7:
            vv.co.z = loc[2] + r * scale[2] * 0.7 + (vv.co.z - loc[2] - r * scale[2] * 0.7) * 0.3
    return v


@asset("SM_Rock_Small01", "Forest", "WorldProp", density=2.5, uv_box=True, pivot="Centre on the ground.",
       use="Small rock (decor).")
def rock_small01(m):
    rock(m, 0.7, (0, 0, 0.2), subdiv=2)
    m.flatten_below(0)


@asset("SM_Rock_Small02", "Forest", "WorldProp", density=2.5, uv_box=True, pivot="Centre on the ground.",
       use="Small mossy rock pair (decor).")
def rock_small02(m):
    rock(m, 0.8, (0, 0, 0.25), mat="stone_mossy", subdiv=2)
    rock(m, 0.5, (0.9, 0.4, 0.1), mat="stone", subdiv=2)
    m.flatten_below(0)


@asset("SM_Rock_Small03", "Forest", "WorldProp", density=2.5, uv_box=True, pivot="Centre on the ground.",
       use="Flat stepping-stone rock (decor).")
def rock_small03(m):
    rock(m, 1.0, (0, 0, 0.0), scale=(1.4, 1.1, 0.35), mat="stone_dark", subdiv=2)
    m.flatten_below(0)


@asset("SM_Boulder01", "Forest", "WorldProp", density=4.0, uv_box=True, lod=True,
       pivot="Centre on the ground.", fidelity="Hull", use="Large boulder; blocks movement.")
def boulder01(m):
    rock(m, 3.2, (0, 0, 1.4), scale=(1.3, 1.0, 0.8), mat="stone_mossy")
    rock(m, 1.6, (3.0, 1.2, 0.4), mat="stone")
    m.flatten_below(0)
    m.col_box((0.6, 0.2, 1.7), (8.6, 6.4, 3.4))


@asset("SM_Boulder02", "Forest", "WorldProp", density=4.0, uv_box=True, lod=True,
       pivot="Centre on the ground.", fidelity="Hull", use="Tall split boulder.")
def boulder02(m):
    rock(m, 2.6, (-1.0, 0, 2.2), scale=(0.9, 1.0, 1.25), mat="stone")
    rock(m, 2.3, (1.4, 0.2, 1.8), scale=(0.8, 1.0, 1.15), mat="stone_dark")
    rock(m, 1.0, (0, -2.2, 0.3), mat="stone_mossy", subdiv=2)
    m.flatten_below(0)
    m.col_box((0.2, 0, 2.4), (6.6, 5.4, 4.8))


@asset("SM_Boulder03", "Forest", "WorldProp", density=4.0, uv_box=True, lod=True,
       pivot="Centre on the ground.", fidelity="Hull", use="Low, wide mossy boulder cluster.")
def boulder03(m):
    for i in range(5):
        a = i * math.tau / 5
        rock(m, m.rng.uniform(1.2, 1.9), (math.cos(a) * 2, math.sin(a) * 1.5, 0.4),
             mat=("stone_mossy", "stone", "stone_dark")[i % 3], subdiv=1)
    rock(m, 2.2, (0, 0, 0.9), mat="stone_mossy")
    m.flatten_below(0)
    m.col_box((0, 0, 1.3), (7.5, 6.5, 2.6))


def deposit(m, depleted=False):
    """Harvestable stone: pale-veined rock with a flat chipped face and a
    few loose shards; reads differently from grey decor rocks."""
    if not depleted:
        rock(m, 1.9, (0, 0, 1.0), scale=(1.2, 1.0, 0.95), mat="stone_vein")
        rock(m, 1.1, (1.6, -0.6, 0.5), mat="stone_vein", subdiv=2)
        rock(m, 0.9, (-1.5, 0.6, 0.4), mat="stone_dark", subdiv=2)
        m.prism("stone_vein", [(-0.8, 0), (0.8, 0), (0.6, 1.4), (-0.5, 1.2)], 0.2,
                loc=(0.1, -2.05, 0.5), rot=(-12, 0, 0))
        m.attach("HarvestHit", (0, -2.1, 1.2))
    else:
        rock(m, 1.3, (0, 0, 0.3), scale=(1.4, 1.1, 0.45), mat="stone_vein", subdiv=2)
    for k in range(5):
        a = m.rng.uniform(0, math.tau)
        d = m.rng.uniform(2.0, 2.8)
        m.blob("stone_vein" if k % 2 else "stone", 0.25, loc=(math.cos(a) * d, math.sin(a) * d, 0.1),
               jitter=0.05, subdiv=1)
    m.flatten_below(0)
    m.col_box((0, 0, 1.0 if not depleted else 0.35), (4.6, 3.8, 2.0 if not depleted else 0.7))


@asset("SM_StoneDeposit01", "Forest", "Harvestable", density=3.0, uv_box=True, lod=True,
       pivot="Centre on the ground.", fidelity="Hull",
       use="Harvestable stone: pale quartz veins + flat chipped face = 'mine me'. Gives Rock/Stone.",
       notes="Swap for SM_StoneDeposit01_Depleted when empty.")
def deposit01(m):
    deposit(m)


@asset("SM_StoneDeposit01_Depleted", "Forest", "Harvestable", density=3.0, uv_box=True,
       pivot="Centre on the ground.", use="Depleted stone deposit: low rubble.")
def deposit01_d(m):
    deposit(m, depleted=True)


# ----------------------------------------------------------------- plants

def blade(m, mat, base, height, width, lean_dir, curl=0.4):
    """One grass/fibre blade: thin 3-sided spike (watertight, 6 tris)."""
    d = Vector(lean_dir)
    pts = [Vector(base), Vector(base) + d * height * 0.3 + Vector((0, 0, height * 0.55)),
           Vector(base) + d * height * curl + Vector((0, 0, height))]
    m.sweep(mat, pts, [width, width * 0.6, 0.0], 3)


def tuft(m, mat, count, height, spread, width=0.07, curl=0.4, at=(0, 0)):
    for k in range(count):
        a = m.rng.uniform(0, math.tau)
        r = m.rng.uniform(0, spread)
        base = (at[0] + math.cos(a) * r, at[1] + math.sin(a) * r, -0.05)
        blade(m, mat, base, height * m.rng.uniform(0.7, 1.15), width,
              (math.cos(a) * 0.6, math.sin(a) * 0.6, 0), curl)


@asset("SM_FiberPlant01", "Forest", "Harvestable", density=1.5, lod=True, pivot="Centre on the ground.",
       use="Harvestable plant fibre: tall pale-gold stalks with seed heads. Gives Plant Fiber.",
       notes="CanCollide off. Swap for SM_FiberPlant01_Harvested.", fidelity="Box")
def fiber01(m):
    n = 16 if not m.lod else 9
    tuft(m, "fiber", n, 3.2, 0.45, width=0.06, curl=0.35)
    for k in range(5 if not m.lod else 3):
        a = k * math.tau / 5 + 0.4
        top = (math.cos(a) * 0.9, math.sin(a) * 0.9, 3.5 + m.rng.uniform(-0.3, 0.3))
        m.sweep("fiber", [(math.cos(a) * 0.2, math.sin(a) * 0.2, 0), top], [0.05, 0.03], 3)
        m.blob("wood_fresh", 0.16, loc=top, scale=(0.6, 0.6, 1.6))
    m.attach("HarvestHit", (0, 0, 1.2))


@asset("SM_FiberPlant01_Harvested", "Forest", "Harvestable", density=1.5, pivot="Centre on the ground.",
       use="Cut stubble left after harvesting fibre.")
def fiber01_h(m):
    tuft(m, "fiber", 10, 0.6, 0.45, width=0.06, curl=0.1)


@asset("SM_Grass_Clump01", "Forest", "WorldProp", density=1.5, lod=True, pivot="Centre on the ground.",
       use="Grass clump (repeat freely; CanCollide/CanQuery off).")
def grass01(m):
    tuft(m, "grass", 14 if not m.lod else 7, 1.3, 0.5)


@asset("SM_Grass_Clump02", "Forest", "WorldProp", density=1.5, lod=True, pivot="Centre on the ground.",
       use="Wide grass patch.")
def grass02(m):
    for at in ((0, 0), (0.9, 0.4), (-0.8, 0.5)):
        tuft(m, "grass", 8 if not m.lod else 4, 1.0, 0.4, at=at)


@asset("SM_Grass_Clump03", "Forest", "WorldProp", density=1.5, lod=True, pivot="Centre on the ground.",
       use="Tall dry grass.")
def grass03(m):
    tuft(m, "fiber", 6 if not m.lod else 3, 1.8, 0.35, width=0.05)
    tuft(m, "grass", 10 if not m.lod else 5, 1.4, 0.45)


def bush(m, r, mat_a="leaves", mat_b="leaves_dark", n=5, berries=False):
    for k in range(n if not m.lod else max(2, n - 2)):
        a = k * math.tau / n + m.rng.uniform(-0.3, 0.3)
        d = r * 0.55 if k else 0
        rr = r * m.rng.uniform(0.55, 0.75) if k else r * 0.8
        m.blob(mat_a if k % 2 == 0 else mat_b, rr,
               loc=(math.cos(a) * d, math.sin(a) * d, rr * 0.8), scale=(1, 1, 0.85), jitter=rr * 0.12)
    m.sweep("bark", [(0, 0, -0.2), (0, 0, r * 0.5)], [0.15, 0.1], 5)
    m.flatten_below(0)
    if berries:
        for k in range(12):
            a = m.rng.uniform(0, math.tau)
            z = m.rng.uniform(0.4, 1.4) * r
            m.blob("red_paint", 0.12, loc=(math.cos(a) * r * 1.02, math.sin(a) * r * 1.02, z), subdiv=1)


@asset("SM_Bush01", "Forest", "WorldProp", density=2.5, uv_box=True, lod=True, pivot="Centre on the ground.",
       use="Round shrub (CanCollide off: players push through).")
def bush01(m):
    bush(m, 1.5)


@asset("SM_Bush02", "Forest", "WorldProp", density=2.5, uv_box=True, lod=True, pivot="Centre on the ground.",
       use="Wide low shrub.")
def bush02(m):
    bush(m, 2.0, "leaves_dark", "leaves", n=6)


@asset("SM_Bush03_Berry", "Forest", "WorldProp", density=2.5, uv_box=True, lod=True,
       pivot="Centre on the ground.", use="Berry shrub (decor; red berries add colour).")
def bush03(m):
    bush(m, 1.4, "leaves_birch", "leaves", berries=True)


def fern(m, fronds, length):
    for k in range(fronds):
        a = k * math.tau / fronds + m.rng.uniform(-0.2, 0.2)
        L = length * m.rng.uniform(0.8, 1.1)
        # serrated frond outline, extruded thin, then arched
        prof = [(0, -0.02)]
        steps = 7
        for i in range(1, steps + 1):
            t = i / steps
            w = 0.38 * math.sin(math.pi * min(t, 0.95)) * (1.25 if i % 2 else 0.8)
            prof.append((t * L, w))
        prof.append((L * 1.03, 0))
        for i in range(steps, 0, -1):
            t = i / steps
            w = 0.38 * math.sin(math.pi * min(t, 0.95)) * (1.25 if i % 2 else 0.8)
            prof.append((t * L, -w))
        v = m.prism("fern", prof, 0.04, rot=(90, 0, 0))
        for vv in v:  # arch: rise then droop
            x = vv.co.x
            vv.co.z += 0.9 * x - 0.28 * x * x
        m.transform(v, _rotz(math.degrees(a)))
    m.flatten_below(0)


def _rotz(deg):
    from mathutils import Matrix
    return Matrix.Rotation(math.radians(deg), 4, "Z")


@asset("SM_Fern01", "Forest", "WorldProp", density=1.5, lod=True, pivot="Centre on the ground.",
       use="Fern (CanCollide off).")
def fern01(m):
    fern(m, 7 if not m.lod else 5, 2.2)


@asset("SM_Fern02", "Forest", "WorldProp", density=1.5, lod=True, pivot="Centre on the ground.",
       use="Small fern.")
def fern02(m):
    fern(m, 5 if not m.lod else 4, 1.5)


# ------------------------------------------------------ forest floor props

@asset("SM_Mushrooms01", "Forest", "WorldProp", density=1.0, pivot="Centre on the ground.",
       use="Cluster of pale mushrooms (decor).")
def mushrooms01(m):
    for k in range(5):
        a = m.rng.uniform(0, math.tau)
        d = m.rng.uniform(0, 0.5)
        h = m.rng.uniform(0.35, 0.8)
        x, y = math.cos(a) * d, math.sin(a) * d
        m.cylinder("bone", 0.07, 0.06, h, seg=6, loc=(x, y, 0))
        m.lathe("cloth", [(0.0, h - 0.05), (0.28 * h + 0.1, h), (0.2 * h + 0.08, h + 0.12), (0, h + 0.16)], 8,
                loc=(x, y, 0))


@asset("SM_Mushrooms02_Glow", "Forest", "WorldProp", density=1.0, pivot="Centre on the ground.",
       use="Faintly glowing mushrooms for night mood (set cap faces' part Material Neon, "
           "or add a small PointLight at Glow_Att).")
def mushrooms02(m):
    for k in range(4):
        a = m.rng.uniform(0, math.tau)
        d = m.rng.uniform(0.1, 0.5)
        h = m.rng.uniform(0.25, 0.55)
        x, y = math.cos(a) * d, math.sin(a) * d
        m.cylinder("bone", 0.05, 0.04, h, seg=5, loc=(x, y, 0))
        m.lathe("enamel_teal", [(0.0, h - 0.03), (0.2, h), (0.14, h + 0.1), (0, h + 0.13)], 7, loc=(x, y, 0))
    m.attach("Glow", (0, 0, 0.5))


@asset("SM_LeafLitter01", "Forest", "WorldProp", density=3.0, uv_box=True, pivot="Centre on the ground.",
       use="Leaf-litter mound to break up flat ground (CanCollide off).")
def leaf_litter(m):
    for k in range(4):
        a = k * 1.7
        m.blob(("leaves_birch", "forest_floor", "leaves_dark", "forest_floor")[k], 1.4,
               loc=(math.cos(a) * 1.1, math.sin(a) * 0.8, -0.2), scale=(1.4, 1.2, 0.25), jitter=0.1)
    m.flatten_below(0)


@asset("SM_Pinecones01", "Forest", "WorldProp", density=1.0, pivot="Centre on the ground.",
       use="Pinecone scatter under pines (decor).")
def pinecones(m):
    for k in range(6):
        a = m.rng.uniform(0, math.tau)
        d = m.rng.uniform(0.2, 1.3)
        m.blob("bark_pine", 0.18, loc=(math.cos(a) * d, math.sin(a) * d, 0.12),
               rot=(90, 0, math.degrees(a)), scale=(0.8, 0.8, 1.4), jitter=0.03, subdiv=1)


@asset("SM_MossPatch01", "Forest", "WorldProp", density=3.0, uv_box=True, pivot="Centre on the ground.",
       use="Low moss patch for rocks/roots (CanCollide off).")
def moss_patch(m):
    m.blob("moss", 1.6, loc=(0, 0, -0.35), scale=(1.5, 1.1, 0.3), jitter=0.12)
    m.flatten_below(0)


# ---------------------------------------------------------------- landmarks

@asset("SM_Landmark_StandingStones", "Forest", "WorldProp", density=4.0, uv_box=True, lod=True,
       pivot="Centre of the ring on the ground.", fidelity="Hull", footprint=[20, 20],
       use="Ring of old mossy standing stones: navigation landmark / mystery spot.")
def standing_stones(m):
    for k in range(7):
        a = k * math.tau / 7
        h = m.rng.uniform(5, 8) if k != 3 else 3.0
        x, y = math.cos(a) * 8, math.sin(a) * 8
        v = m.blob("stone_mossy" if k % 2 else "stone_dark", 1.0, loc=(x, y, h / 2),
                   rot=(m.rng.uniform(-6, 6), m.rng.uniform(-6, 6), math.degrees(a)),
                   scale=(1.0, 1.4, h / 2), jitter=0.1)
        m.col_box((x, y, h / 2), (2.2, 2.2, h), (0, 0, math.degrees(a)))
        # carved spiral mark on the inner face
        m.torus("enamel_teal", 0.45, 0.06, seg=10, tseg=3, loc=(x * 0.86, y * 0.86, h * 0.6),
                rot=(90, 0, math.degrees(a) + 90))
    m.blob("stone", 1.3, loc=(0, 0, 0.3), scale=(1.6, 1.6, 0.4), jitter=0.1)
    m.flatten_below(0)


@asset("SM_Landmark_AntlerTotem", "Forest", "WorldProp", density=2.5, pivot="Base on the ground.",
       footprint=[3, 3], use="Weathered wooden totem with antlers and cloth ties: eerie, not gory.")
def antler_totem(m):
    m.sweep("wood_dark", [(0, 0, -0.3), (0.05, 0, 3), (0, 0.05, 6.5)], [0.55, 0.5, 0.42], 8, cap_mat="end_grain")
    for z, s in ((1.6, 1), (3.2, -1), (4.8, 1)):  # carved rings
        m.torus("wood_fresh", 0.52, 0.08, seg=10, tseg=3, loc=(0, 0, z))
    m.box("bone", (0.8, 0.25, 0.9), loc=(0, -0.45, 5.6), bevel=0.1)  # carved face plate
    for sx in (-0.2, 0.2):
        m.box("charcoal", (0.14, 0.05, 0.2), loc=(sx, -0.6, 5.75))
    for s in (1, -1):  # antlers
        base = Vector((s * 0.35, 0, 6.4))
        tip = limb(m, "bone", base, (s, 0, 1.2), 2.0, 0.12, seg=5, rise=0.3)
        for t in (0.4, 0.7):
            p = base.lerp(tip, t)
            m.sweep("bone", [p, p + Vector((s * 0.2, -0.3, 0.6))], [0.07, 0.02], 4)
    for z in (4.0, 4.3):
        m.prism("cloth", [(0, 0), (0.35, 0), (0.25, -1.4), (0.05, -1.2)], 0.05, loc=(0.5, -0.1, z), rot=(0, 0, 20))
    m.col_box((0, 0, 3.3), (1.2, 1.2, 6.6))


@asset("SM_Landmark_GiantLog", "Forest", "WorldProp", density=4.0, lod=True,
       pivot="Centre on the ground.", fidelity="Default", footprint=[22, 7],
       use="Huge fallen trunk players can walk through (tunnel 4 studs wide, 5.5 tall).",
       notes="Use CollisionFidelity Default or the provided wall boxes so the tunnel stays open.")
def giant_log(m):
    L, R = 22, 3.4
    seg = 12
    # hollow shell built as ring of staves so the interior is walkable
    for k in range(seg):
        a0 = k / seg * math.tau
        if abs(math.sin(a0 + math.pi / seg)) < 0.3 and math.cos(a0 + math.pi / seg) < 0:
            continue  # floor opening
        a = a0 + math.pi / seg
        c = Vector((0, math.cos(a) * R, R * 0.9 + math.sin(a) * R))
        m.box("bark_dead" if k % 3 else "bark", (L, 2 * R * math.sin(math.pi / seg) + 0.15, 0.7),
              loc=tuple(c), rot=(math.degrees(a) - 90, 0, 0))
    m.box("forest_floor", (L, 5.2, 0.3), loc=(0, 0, 0.15))
    m.blob("moss", R, loc=(2, 0, R * 1.9), scale=(2.4, 0.9, 0.35), jitter=0.2)
    for x in (-L / 2, L / 2):
        m.torus("end_grain", R - 0.15, 0.4, seg=14, tseg=4, loc=(x, 0, R * 0.9), rot=(0, 90, 0))
    for sgn in (1, -1):
        m.col_box((0, sgn * (R - 0.2), R * 0.9), (L, 0.8, R * 1.8))
    m.col_box((0, 0, R * 1.9 - 0.2), (L, 2 * R, 0.8))


# ---------------------------------------------------- clearing / camp dressing

@asset("SM_Clearing_GroundPatch", "Forest", "WorldProp", density=4.0, uv_box=True,
       pivot="Centre on the ground (top surface at Z=0.05).", fidelity="Box", footprint=[40, 40],
       use="Worn dirt clearing under a camp: lay over terrain (CanCollide off).")
def clearing_patch(m):
    def h(x, y):  # rim dips below ground so terrain hides the edge
        return 0.05 - 0.45 * min(1.0, max(0, math.hypot(x, y) / 20 - 0.8) * 5)

    def mat(x, y, z, slope):
        r = math.hypot(x, y) + m.rng.uniform(-3, 3)
        return "dirt" if r < 12 else ("forest_floor" if r < 17 else "moss")
    m.heightfield(40, 40, 16, 16, h, mat, base=-0.6)


@asset("SM_Camp_LogBench", "Forest", "WorldProp", density=2.5, pivot="Centre on the ground.",
       footprint=[5, 1.4], use="Split-log bench (seat height 1.6).")
def log_bench(m):
    m.cylinder("bark", 0.65, 0.65, 5, seg=9, loc=(-2.5, 0, 1.25), rot=(0, 90, 0), cap="end_grain",
               scale=(1, 1, 1))
    m.box("wood_fresh", (4.9, 1.1, 0.12), loc=(0, 0, 1.62))
    for x in (-1.8, 1.8):
        m.box("wood_dark", (0.5, 1.0, 0.7), loc=(x, 0, 0.35), bevel=0.05)
    m.col_box((0, 0, 0.85), (5, 1.4, 1.7))


@asset("SM_Camp_FirewoodStack", "Forest", "WorldProp", density=2.5, pivot="Centre on the ground.",
       footprint=[3.2, 1.6], use="Stacked split firewood.")
def firewood(m):
    for row in range(3):
        for i in range(4 - row):
            x = -1.05 + i * 0.7 + row * 0.35
            m.cylinder("bark", 0.32, 0.32, 1.5, seg=6, loc=(x, -0.75, 0.32 + row * 0.56), rot=(-90, 0, 0),
                       cap="end_grain")
    m.col_box((0, 0, 0.9), (3.0, 1.5, 1.8))


@asset("SM_Camp_DryingRack", "Forest", "WorldProp", density=2.5, pivot="Centre on the ground.",
       footprint=[4.5, 2], use="Pole drying rack with a stretched hide (no gore).")
def drying_rack(m):
    for x in (-2, 2):
        m.sweep("wood_dark", [(x, -0.6, -0.2), (x, 0, 4)], 0.12, 6)
        m.sweep("wood_dark", [(x, 0.6, -0.2), (x, 0, 4)], 0.12, 6)
    m.sweep("wood", [(-2.3, 0, 3.9), (2.3, 0, 3.9)], 0.1, 6)
    m.box("leather", (2.6, 0.08, 2.2), loc=(0, 0, 2.6), bevel=0.03)
    for x in (-1.2, 0, 1.2):
        m.sweep("rope", [(x, 0, 3.7), (x, 0, 3.9)], 0.04, 4)
    m.col_box((0, 0, 2), (4.4, 1.4, 4))


@asset("SM_Camp_Lantern", "Forest", "WorldProp", density=1.2, pivot="Base of the post on the ground.",
       footprint=[1, 1], use="Lantern on a post. Glow part: add PointLight at Light_Att (warm, Range 16).")
def lantern(m):
    m.sweep("wood_dark", [(0, 0, -0.3), (0, 0, 5)], 0.14, 6)
    m.sweep("wood_dark", [(0, 0, 4.8), (0.9, 0, 4.9)], 0.07, 5)
    m.cylinder("metal_dark", 0.28, 0.28, 0.1, seg=8, loc=(0.9, 0, 3.95))
    m.cylinder("glow", 0.22, 0.22, 0.55, seg=8, loc=(0.9, 0, 4.05))
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        m.box("metal_dark", (0.05, 0.05, 0.6), loc=(0.9 + math.cos(a) * 0.25, math.sin(a) * 0.25, 4.3))
    m.cone("metal_dark", 0.32, 0.25, seg=8, loc=(0.9, 0, 4.6))
    m.torus("metal", 0.08, 0.02, seg=6, tseg=3, loc=(0.9, 0, 4.9), rot=(90, 0, 0))
    m.attach("Light", (0.9, 0, 4.3))
    m.col_box((0, 0, 2.5), (0.4, 0.4, 5))


@asset("SM_Camp_Bedroll", "Forest", "WorldProp", density=2.0, pivot="Centre on the ground.",
       footprint=[2, 5], use="Rolled-out bedroll with pillow roll (decor, CanCollide off).")
def bedroll(m):
    m.box("cloth_dark", (1.8, 4.6, 0.18), loc=(0, 0, 0.09), bevel=0.06)
    m.box("team_cloth", (1.7, 3.2, 0.12), loc=(0, 0.6, 0.22), bevel=0.05)
    m.cylinder("cloth", 0.3, 0.3, 1.7, seg=8, loc=(-0.85, -1.9, 0.3), rot=(0, 90, 0))
    for x in (-0.5, 0.5):
        m.torus("leather", 0.32, 0.04, seg=8, tseg=3, loc=(x, -1.9, 0.3), rot=(0, 90, 0))


@asset("SM_Camp_Barrel", "Forest", "WorldProp", density=2.0, pivot="Centre on the ground.",
       footprint=[2, 2], fidelity="Hull", use="Water barrel (decor / cover).")
def barrel(m):
    prof = [(0.8, 0), (0.95, 0.6), (1.0, 1.25), (0.95, 1.9), (0.8, 2.5)]
    m.lathe("wood", prof, 12, band_mats=["wood", "wood", "wood", "wood"])
    for z in (0.35, 2.15):
        m.torus("metal_dark", 0.9, 0.06, seg=12, tseg=3, loc=(0, 0, z))
    m.cylinder("wood_dark", 0.78, 0.78, 0.06, seg=12, loc=(0, 0, 2.47))
    m.col_box((0, 0, 1.25), (2, 2, 2.5))


@asset("SM_Camp_ChoppingBlock", "Forest", "WorldProp", density=2.5, pivot="Centre on the ground.",
       footprint=[2, 2], use="Chopping stump with split wood around it.")
def chopping_block(m):
    stump(m, 0.8, 1.4, "bark", fresh=True, chips=True)
    for k in range(3):
        a = k * 2.1
        m.prism("wood_fresh", [(-0.3, 0), (0.3, 0), (0, 0.45)], 1.1,
                loc=(math.cos(a) * 1.6, math.sin(a) * 1.6, 0), rot=(0, 0, math.degrees(a)))


@asset("SM_Camp_TeamBanner", "Forest", "WorldProp", density=2.0, pivot="Base of the pole on the ground.",
       footprint=[2, 1], use="Tall team banner for camp edges (team colour via atlas variant).")
def team_banner(m):
    m.sweep("wood_dark", [(0, 0, -0.4), (0, 0, 9)], [0.16, 0.12], 6)
    m.sweep("wood_dark", [(-0.1, 0, 8.5), (2.1, 0, 8.5)], 0.08, 5)
    v = m.box("team_cloth", (2.0, 0.08, 4.2), loc=(1.05, 0, 6.3))
    for vv in v:  # gentle wave
        vv.co.y += 0.15 * math.sin(vv.co.x * 2.2)
        if vv.co.z < 4.3:
            vv.co.x += 0.0
    m.prism("team_cloth", [(0.05, 0), (2.05, 0), (1.05, -0.6)], 0.08, loc=(0, 0, 4.2))
    m.torus("rope", 0.16, 0.04, seg=8, tseg=3, loc=(0, 0, 8.4))
    m.col_box((0, 0, 4.3), (0.35, 0.35, 8.6))
