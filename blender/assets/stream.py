"""Modular stream kit.

Every open end has the same cross-section: 24 studs wide, water channel
7 studs wide, bank top at Z=+1.2, stream bed at Z=-1.6, water surface at
Z=-0.6. Ends sit at Y = -8 and Y = +8 (straight) so pieces snap on a 16-stud
grid. The water is a separate mesh so it can be transparent without making
the banks transparent.
"""

import math

from mathutils import Vector

from sh.pipeline import asset

W, L = 24.0, 16.0
BED, TOP, WATER = -1.6, 1.2, -0.6
PIVOT = "Centre of the piece at original ground level (bank tops at +1.2, bed at -1.6)."


def profile(s):
    """Height for distance s from the stream centreline."""
    if s < 3.5:
        return BED + 0.15 * math.cos(s * 1.3)
    if s < 7.5:
        t = (s - 3.5) / 4.0
        return BED + (TOP - BED) * (t * t * (3 - 2 * t))
    return TOP


def bank_mat(rng):
    def mat(x, y, z, slope):
        if z < BED + 0.4:
            return "stone" if rng.random() < 0.6 else "stone_dark"
        if z < WATER + 0.4:
            return "dirt" if rng.random() < 0.7 else "stone_mossy"
        if slope > 0.25:
            return "dirt"
        return "moss" if rng.random() < 0.3 else "forest_floor"
    return mat


def ends_fade(y, half=L / 2):
    return math.sin(math.pi * (y + half) / (2 * half))


def edge_rocks(m, pts):
    for p in pts:
        m.blob("stone_mossy", m.rng.uniform(0.5, 0.9), loc=p, scale=(1.3, 1, 0.6), jitter=0.1, subdiv=1)


@asset("SM_Stream_Straight", "Stream", "WorldProp", density=4.0, pivot=PIVOT, fidelity="Default",
       footprint=[24, 16], use="Straight stream bank piece (flow along Z).",
       notes="Snaps to other stream pieces every 16 studs along the flow. Add SM_Stream_Water_Straight.")
def straight(m):
    rng = m.rng
    m.heightfield(W, L, 24, 12,
                  lambda x, y: profile(abs(x)) + 0.25 * math.sin(y * 0.9 + x) * ends_fade(y) * (abs(x) > 8),
                  bank_mat(rng), base=-2.6)
    edge_rocks(m, [(4.3, -3, -0.4), (-4.6, 2.5, -0.3), (4.8, 5, -0.2)])
    m.meta["water_level"] = WATER


def bend_warp(x, y):
    th = (y + L / 2) / L * (math.pi / 2)
    rad = 16 + x
    return (-16 + rad * math.cos(th), -L / 2 + rad * math.sin(th))


@asset("SM_Stream_Bend90", "Stream", "WorldProp", density=4.0, pivot=PIVOT, fidelity="Default",
       footprint=[28, 28],
       use="90-degree bend: enters at the -Z end like the straight piece, exits facing +X (Roblox).",
       notes="Pair with SM_Stream_Water_Bend90.")
def bend(m):
    m.heightfield(W, L, 24, 16, lambda x, y: profile(abs(x)), bank_mat(m.rng), base=-2.6, warp=bend_warp)
    edge_rocks(m, [(bend_warp(4.5, 0)[0], bend_warp(4.5, 0)[1], -0.3),
                   (bend_warp(-4.4, -4)[0], bend_warp(-4.4, -4)[1], -0.3)])


def pool_s(x, y):
    d_pool = max(0.0, math.hypot(x, y - 3.0) - 3.8)
    d_chan = abs(x) if y < 3.0 else 99
    return min(d_pool, d_chan)


@asset("SM_Stream_PoolEnd", "Stream", "WorldProp", density=4.0, pivot=PIVOT, fidelity="Default",
       footprint=[24, 24], use="Stream end: a small spring pool. Connects at its -Z end.",
       notes="Pair with SM_Stream_Water_PoolEnd. Good spot for the canteen refill interaction.")
def pool(m):
    def h(x, y):
        return profile(pool_s(x, y))
    m.heightfield(W, 24, 24, 24, h, bank_mat(m.rng), base=-2.6, loc=(0, 4, 0))
    edge_rocks(m, [(3.5, 9.5, 0.2), (-4.5, 8, 0.0), (5.5, 4, 0.2), (-2, 12.2, 0.5)])
    m.attach("Refill", (0, 7, WATER))


def water_slab(m, width, length, warp=None, loc=(0, 0, 0), ny=8):
    m.heightfield(width, length, 4, ny, lambda x, y: WATER, lambda *a: "water", base=WATER - 0.1,
                  warp=warp, loc=loc, skirt_mat="water")


@asset("SM_Stream_Water_Straight", "Stream", "Effect", density=4.0, pivot=PIVOT, dummy=False,
       use="Water surface for the straight piece. Suggested: Material Glass or SmoothPlastic, "
           "Transparency 0.35, CanCollide off.")
def water_straight(m):
    water_slab(m, 10.5, L)


@asset("SM_Stream_Water_Bend90", "Stream", "Effect", density=4.0, pivot=PIVOT, dummy=False,
       use="Water surface for the bend.")
def water_bend(m):
    water_slab(m, 10.5, L, warp=bend_warp, ny=12)


@asset("SM_Stream_Water_PoolEnd", "Stream", "Effect", density=4.0, pivot=PIVOT, dummy=False,
       use="Water surface for the pool end.")
def water_pool(m):
    m.cylinder("water", 6.2, 6.2, 0.1, seg=20, loc=(0, 7, WATER - 0.1), cap="water")
    water_slab(m, 10.5, 8.0, loc=(0, -4, 0), ny=4)


def river_stones(m, n, spread, mats=("stone", "stone_mossy", "stone_dark")):
    for k in range(n):
        a = m.rng.uniform(0, math.tau)
        d = m.rng.uniform(0, spread)
        r = m.rng.uniform(0.4, 1.0)
        m.blob(mats[k % len(mats)], r, loc=(math.cos(a) * d, math.sin(a) * d, r * 0.2),
               rot=(0, 0, math.degrees(a)), scale=(1.4, 1.0, 0.45), jitter=0.05, subdiv=2)
    m.flatten_below(0)


@asset("SM_StreamRocks01", "Stream", "WorldProp", density=2.5, uv_box=True, pivot="Centre on the bed.",
       use="Smooth streambed stones (place on the bed at Y=-1.6).")
def stream_rocks01(m):
    river_stones(m, 5, 1.5)


@asset("SM_StreamRocks02", "Stream", "WorldProp", density=2.5, uv_box=True, pivot="Centre on the bed.",
       use="Stepping stones across the stream (tops above the water line when placed on the bed).")
def stream_rocks02(m):
    for k, x in enumerate((-2.6, 0, 2.6)):
        m.blob("stone_mossy" if k == 1 else "stone", 1.0, loc=(x, m.rng.uniform(-0.3, 0.3), 0.6),
               scale=(1.2, 1.0, 0.95), jitter=0.08, subdiv=2)
        m.col_box((x, 0, 0.8), (2.0, 1.8, 1.6))
    m.flatten_below(0)


@asset("SM_StreamRocks03", "Stream", "WorldProp", density=2.5, uv_box=True, pivot="Centre on the bed.",
       use="Pebble spread for shallows.")
def stream_rocks03(m):
    for k in range(12):
        a = m.rng.uniform(0, math.tau)
        d = m.rng.uniform(0, 2.4)
        m.blob(("stone", "stone_dark")[k % 2], m.rng.uniform(0.15, 0.3),
               loc=(math.cos(a) * d, math.sin(a) * d, 0.05), scale=(1.3, 1, 0.5), subdiv=1)
    m.flatten_below(0)
