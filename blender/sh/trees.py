"""Simple, chunky low-poly trees (flat colours, clean silhouettes).

Shared by the forest kit (assets/world.py) and the Survival Wars landscape kit
(assets/survival_wars.py). Every tree is built around its trunk on the origin,
then `Model.fit_bounds` snaps it to the bounding box it was published with, so
the uploaded asset IDs keep working (tools/check_bounds.py).

Colours come from existing atlas tiles through `Model.tone` (one flat colour per
face, picked at a lightness percentile), so no atlas tile is added or changed.
"""

import math

from mathutils import Vector

# (material, lightness percentile) swatches
PALETTES = {
    "pine": dict(main=("fern", 50), top=("grass", 85), under=("leaves_dark", 30)),
    "spruce": dict(main=("leaves_dark", 70), top=("fern", 40), under=("pine_needles", 40)),
    "oak": dict(main=("leaves", 50), top=("grass", 90), under=("leaves_dark", 40)),
    "oak_dark": dict(main=("fern", 30), top=("leaves", 80), under=("leaves_dark", 20)),
    "birch": dict(main=("leaves_birch", 45), top=("leaves_birch", 95), under=("leaves", 40)),
    "aspen": dict(main=("leaves_birch", 70), top=("leaves_birch", 98), under=("moss", 60)),
}
BARK = {
    "pine": ("bark_pine", 50),
    "oak": ("bark", 55),
    "birch": ("bark_birch", 60),
    "dead": ("bark_dead", 55),
}
MARK = ("charcoal", 50)


def flat(m, verts, swatch):
    mat, q = swatch
    m.paint(verts, mat)
    m.tone(verts, q)
    return verts


def shade(m, verts, pal, top_z=None, under=-0.3, top_n=None):
    """Main colour, a darker underside (normal.z < under) and a lighter top
    (face centre above top_z, or normal.z above top_n)."""
    flat(m, verts, pal["main"])
    for key, pred in (
            ("under", lambda c, n: n.z < under),
            ("top", lambda c, n: (top_z is not None and c.z > top_z and n.z > -0.1)
             or (top_n is not None and n.z > top_n))):
        mat, q = pal[key]
        m.paint_where(verts, mat, pred)
        m.tone(verts, q, pred)
    return verts


def trunk(m, bark, height, r0, r1, seg=8, flare=1.35, below=0.45):
    """Straight tapered trunk with a small base flare, sunk `below` into the ground."""
    prof = [(r0 * flare, -below), (r0 * (1 + (flare - 1) * 0.55), 0.25), (r0, 0.9),
            (r1, height)]
    return flat(m, m.lathe(bark[0], prof, seg), bark)


def branch(m, bark, start, end, r0, r1, seg=6):
    s, e = Vector(start), Vector(end)
    v = flat(m, m.sweep(bark[0], [s, s.lerp(e, 0.5), e], [r0, (r0 + r1) / 2, r1], seg), bark)
    return v


def notch(m, height, r):
    """Fresh axe notch on the trunk's front (-Y): the 'this can be chopped' cue."""
    v = m.prism("wood_fresh", [(-r * 0.75, -0.3), (r * 0.75, -0.3), (0, 0.3)], 0.45,
                loc=(0, -r * 0.84, height))
    flat(m, v, ("wood_fresh", 60))
    m.attach("HarvestHit", (0, -r - 0.05, height), (0, 0, 0))


# ------------------------------------------------------------------- conifers

def cone_tier(m, cx, cy, z, r, h, pal, seg=10, tip=False, droop=0.12):
    """One slightly rounded cone skirt: a crisp rim, gently bulging sides and a
    shallow hollow underneath."""
    prof = [(0, z + h * 0.2), (r * 0.9, z - h * droop * 0.4), (r, z - h * droop * 0.1),
            (r * 0.93, z + h * 0.1), (r * 0.66, z + h * 0.4), (r * 0.36, z + h * 0.7)]
    prof += [(r * 0.12, z + h * 0.93), (0, z + h)] if tip else [(0, z + h)]
    v = m.lathe(pal["main"][0], prof, seg, loc=(cx, cy, 0),
                rot=(0, 0, m.rng.uniform(0, 360)))
    shade(m, v, pal, top_z=z + h * 0.55)
    return v


def conifer(m, lo, hi, pal, tiers=4, r0=0.6, clear=0.18, seg=10, bark=BARK["pine"],
            shape=(1.0, 0.8, 0.6, 0.42, 0.3), heights=None, col=True):
    """Stacked-cone pine / spruce filling the box lo..hi (Z up, origin = trunk base)."""
    H = hi[2]
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    R = min(hi[0] - lo[0], hi[1] - lo[1]) / 2
    trunk(m, bark, H * 0.8, r0, r0 * 0.4, seg=8, below=-lo[2])
    z0 = H * clear
    crown = H - z0
    # tier bases as fractions of the crown; each tier overlaps the next
    fr = heights or [0, 0.27, 0.49, 0.67, 0.8][:tiers]
    fr = [f * (0.67 / fr[-1]) for f in fr] if tiers < 4 else fr
    for i, f in enumerate(fr):
        base = z0 + crown * f
        last = i == len(fr) - 1
        h = (H - base) if last else crown * (fr[i + 1] - f) * 2.0
        r = R * shape[i]
        cone_tier(m, cx * (1 - i * 0.15), cy * (1 - i * 0.15), base, r, h, pal,
                  seg=seg, tip=last)
    if col:
        m.col_box((0, 0, H * 0.3), (r0 * 2.2, r0 * 2.2, H * 0.6))


# ----------------------------------------------------------------- broadleaves

def lump(m, pal, c, r, scale=(1, 1, 0.85), subdiv=2):
    v = m.blob(pal["main"][0], r, loc=c, scale=scale, jitter=r * 0.03, subdiv=subdiv,
               rot=(0, 0, m.rng.uniform(0, 360)))
    shade(m, v, pal, top_n=0.62, under=-0.45)
    return v


def broadleaf(m, lo, hi, pal, bark=BARK["oak"], r0=0.7, crown_base=0.42, lumps=3,
              tall=0.85, limbs=3, subdiv=2):
    """Trunk plus a crown of a few big soft lumps filling the box lo..hi."""
    H = hi[2]
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    rx, ry = (hi[0] - lo[0]) / 2, (hi[1] - lo[1]) / 2
    zb = H * crown_base
    rz = (H - zb) / 2
    zc = zb + rz
    trunk(m, bark, zc, r0, r0 * 0.6, seg=8, below=-lo[2])
    # thick limbs up into the crown
    for k in range(limbs):
        a = k * math.tau / limbs + m.rng.uniform(-0.3, 0.3)
        s = Vector((0, 0, zb + (zc - zb) * 0.1))
        e = Vector((cx + math.cos(a) * rx * 0.45, cy + math.sin(a) * ry * 0.45, zc))
        branch(m, bark, s, e, r0 * 0.5, r0 * 0.3)
    # a big top lump, and a ring of lumps around it
    rr = min(rx, ry)
    lump(m, pal, (cx, cy, zc + rz * 0.28), rr * 0.62, scale=(1, 1, tall), subdiv=subdiv)
    for k in range(lumps):
        a = k * math.tau / lumps + m.rng.uniform(-0.25, 0.25) + 0.4
        d = Vector((math.cos(a) * rx, math.sin(a) * ry, 0)) * 0.45
        lump(m, pal, (cx + d.x, cy + d.y, zc - rz * 0.18 + m.rng.uniform(-0.1, 0.1) * rz),
             rr * m.rng.uniform(0.5, 0.58), scale=(1, 1, tall), subdiv=subdiv)
    m.col_box((0, 0, H * 0.25), (r0 * 2.2, r0 * 2.2, H * 0.5))


def birch_marks(m, h0, h1, r_at, n=8):
    """Short dark horizontal dashes on a pale trunk."""
    for i in range(n if not m.lod else n // 2):
        z = h0 + (h1 - h0) * (i + m.rng.uniform(0.2, 0.8)) / n
        a = m.rng.uniform(0, 360)
        r = r_at(z)
        v = m.box(MARK[0], (r * 1.1, r * 0.4, max(0.14, r * 0.3)),
                  loc=(math.cos(math.radians(a)) * r * 0.8, math.sin(math.radians(a)) * r * 0.8, z),
                  rot=(0, 0, a + 90))
        flat(m, v, MARK)


def pale_tree(m, lo, hi, pal, r0=0.45, crown_base=0.45, lumps=3, tall=1.2, subdiv=2, col=True):
    """Birch / aspen: slim white trunk with dark marks, tall oval crown of lumps."""
    H = hi[2]
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    rx, ry = (hi[0] - lo[0]) / 2, (hi[1] - lo[1]) / 2
    zb = H * crown_base
    rz = (H - zb) / 2
    zc = zb + rz
    top = H * 0.8
    r1 = r0 * 0.55
    trunk(m, BARK["birch"], top, r0, r1, seg=8, flare=1.25, below=-lo[2])
    birch_marks(m, 0.6, zb + rz * 0.2, lambda z: r0 + (r1 - r0) * max(0, z - 0.9) / (top - 0.9))
    # one tall egg-shaped crown with a few softer lumps on its sides
    rh = min(rx, ry) * 0.66
    rv = (H - zb) / 2 * 0.9
    lump(m, pal, (cx, cy, zc + rz * 0.08), rh, scale=(1, 1, rv / rh), subdiv=subdiv)
    for k in range(lumps):
        a = k * math.tau / lumps + m.rng.uniform(-0.3, 0.3)
        r = rh * m.rng.uniform(0.8, 0.9)
        z = zb + r * tall + (rz * 0.8) * (k / max(1, lumps - 1))
        lump(m, pal, (cx + math.cos(a) * rx * 0.42, cy + math.sin(a) * ry * 0.42, z), r,
             scale=(1, 1, tall), subdiv=subdiv)
    if col:
        m.col_box((0, 0, H * 0.3), (r0 * 2.4, r0 * 2.4, H * 0.6))


# ------------------------------------------------------------------- dead / stumps

def dead_tree(m, lo, hi, bark=BARK["dead"], r0=1.25):
    """Clean bare trunk with a few thick, upturned branches (one fork each)."""
    H = hi[2]
    th = H * 0.8
    trunk(m, bark, th, r0, r0 * 0.45, seg=8, flare=1.4, below=-lo[2])
    reach = [(hi[0], 0.1), (lo[1], 1.6), (lo[0], 3.3), (hi[1], 4.8)]
    for i, (ext, a) in enumerate(reach):
        a += m.rng.uniform(-0.2, 0.2)
        z = th * (0.45 + 0.13 * i)
        rad = r0 * 0.46 * (1 - i * 0.1)
        s = Vector((0, 0, z))
        L = abs(ext) * 0.95
        mid = s + Vector((math.cos(a) * L * 0.55, math.sin(a) * L * 0.55, L * 0.3))
        end = s + Vector((math.cos(a) * L, math.sin(a) * L, L * 0.85))
        flat(m, m.sweep(bark[0], [s, mid, end], [rad, rad * 0.78, rad * 0.5], 7), bark)
        b = a + (0.7 if i % 2 else -0.7)
        fork = mid + Vector((math.cos(b) * L * 0.35, math.sin(b) * L * 0.35, L * 0.2))
        branch(m, bark, mid, fork, rad * 0.62, rad * 0.4, seg=6)
    m.col_box((0, 0, 5), (2.4, 2.4, 10))


def cut_stump(m, lo, hi, bark, r):
    """Fresh stump that matches the new trunks: straight flared trunk, clean
    end-grain top, a few chunky root nubs and chips."""
    h = hi[2]
    v = m.sweep(bark[0], [Vector((0, 0, lo[2])), Vector((0, 0, 0.2)), Vector((0, 0, h))],
                [r * 1.35, r * 1.12, r], 8, cap_mat="end_grain")
    m.tone([x for x in v], bark[1], lambda c, n: n.z < 0.9)
    for k in range(3):
        a = k * math.tau / 3 + 0.5
        d = Vector((math.cos(a), math.sin(a), 0))
        branch(m, bark, d * r * 0.5 + Vector((0, 0, h * 0.45)), d * (r * 2.1) + Vector((0, 0, 0.0)),
               r * 0.42, r * 0.2, seg=5)
    for i, a in enumerate((2.4, 3.6, 5.0)):
        dist = r + 0.55 + 0.25 * i
        flat(m, m.box("wood_fresh", (0.4, 0.2, 0.08), loc=(math.cos(a) * dist, math.sin(a) * dist, 0.04),
                      rot=(0, 0, math.degrees(a) + 30)), ("wood_fresh", 60))
    # reach the published footprint (the old stump's roots / chips) in every direction
    for a in (0.0, math.pi / 2, math.pi, 1.5 * math.pi):
        ex = hi[0] if math.cos(a) > 0.5 else lo[0] if math.cos(a) < -0.5 else 0
        ey = hi[1] if math.sin(a) > 0.5 else lo[1] if math.sin(a) < -0.5 else 0
        if abs(ex) + abs(ey) > r * 2.2:
            flat(m, m.box("wood_fresh", (0.3, 0.16, 0.07), loc=(ex * 0.85, ey * 0.85, 0.035),
                          rot=(0, 0, math.degrees(a) + 60)), ("wood_fresh", 60))
    if bark == BARK["birch"]:
        birch_marks(m, 0.15, h - 0.1, lambda z: r * 1.05, n=3)
    m.col_box((0, 0, h / 2), (r * 2.2, r * 2.2, h))
