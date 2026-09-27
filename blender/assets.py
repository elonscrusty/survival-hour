"""Survival Hour starter assets.

Each function takes a Model and adds parts to it. Sizes are in studs; a
Roblox character is about 5 studs tall. Register a new asset by adding a
function with the @asset decorator.
"""

import math

from lowpoly import Model

ASSETS = {}


def asset(name, seed=1):
    def register(fn):
        ASSETS[name] = (fn, seed)
        return fn
    return register


def make(name):
    fn, seed = ASSETS[name]
    m = Model(name, seed)
    fn(m)
    return m


# --- Nature -----------------------------------------------------------------

@asset("PineTree", seed=11)
def pine_tree(m):
    m.cylinder("bark", 0.9, 0.55, 6.0, segments=7)
    tiers = [(5.0, 5.0, 3.0), (4.1, 4.4, 6.0), (3.1, 4.0, 8.8), (2.0, 3.6, 11.4)]
    for i, (r, h, z) in enumerate(tiers):
        v = m.cone("pine" if i % 2 == 0 else "pine_dark", r, h, segments=7,
                   loc=(0, 0, z), rot=(0, 0, i * 23))
        m.jitter(v, 0.18)
    m.cone("pine", 1.0, 1.8, segments=6, loc=(0, 0, 14.6))


@asset("OakTree", seed=7)
def oak_tree(m):
    m.cylinder("bark", 1.1, 0.7, 7.0, segments=7)
    m.cylinder("bark", 0.45, 0.25, 3.2, segments=6, loc=(0.4, 0, 4.5), rot=(0, 50, 0))
    m.cylinder("bark", 0.4, 0.25, 3.0, segments=6, loc=(-0.3, 0.2, 5.0), rot=(-15, -45, 0))
    clumps = [
        ((0, 0, 9.0), 3.6, "leaf"),
        ((2.6, 0.3, 7.8), 2.6, "leaf_dark"),
        ((-2.4, 0.6, 8.2), 2.5, "leaf_light"),
        ((0.5, -2.2, 8.0), 2.4, "leaf_dark"),
        ((-0.6, 2.2, 8.6), 2.3, "leaf"),
    ]
    for loc, r, col in clumps:
        m.blob(col, r, loc=loc, scale=(1, 1, 0.8), jitter=0.35)


@asset("BerryBush", seed=5)
def berry_bush(m):
    for loc, r, col in [((0, 0, 1.2), 1.5, "leaf"), ((1.1, 0.4, 0.9), 1.1, "leaf_dark"),
                        ((-1.0, -0.3, 0.9), 1.1, "leaf_light")]:
        m.blob(col, r, loc=loc, scale=(1, 1, 0.85), jitter=0.15)
    m.flatten_below(0.0)
    for i in range(10):
        a = m.rng.uniform(0, math.tau)
        z = m.rng.uniform(0.7, 2.2)
        rad = 1.55 if z < 1.8 else 1.1
        m.blob("berry", 0.2, loc=(math.cos(a) * rad, math.sin(a) * rad, z))


@asset("RockLarge", seed=3)
def rock_large(m):
    m.blob("stone", 3.0, loc=(0, 0, 1.2), scale=(1.3, 1.0, 0.75), jitter=0.45)
    m.blob("stone_dark", 1.7, loc=(2.8, 1.2, 0.6), scale=(1.1, 1.0, 0.8), jitter=0.3)
    m.blob("stone_light", 1.0, loc=(-2.4, -1.6, 0.3), jitter=0.2)
    m.flatten_below(0.0)


@asset("Stone", seed=9)
def stone(m):
    """Small pickup-size stone (resource)."""
    m.blob("stone", 0.8, loc=(0, 0, 0.35), scale=(1.2, 1.0, 0.7), jitter=0.12)
    m.flatten_below(0.0)


@asset("Log", seed=2)
def log(m):
    m.cylinder("bark", 0.7, 0.7, 6.0, segments=8, loc=(-3.0, 0, 0.7), rot=(0, 90, 0),
               cap_color="wood_light")
    m.cylinder("bark_dark", 0.18, 0.1, 0.9, segments=5, loc=(0.8, 0, 1.25), rot=(-30, 0, 0))


# --- Camp -------------------------------------------------------------------

@asset("Campfire", seed=4)
def campfire(m):
    m.cylinder("ash", 1.7, 1.6, 0.12, segments=10)
    for i in range(9):
        a = i / 9 * math.tau
        m.blob("stone" if i % 2 else "stone_dark", 0.5,
               loc=(math.cos(a) * 2.1, math.sin(a) * 2.1, 0.25),
               scale=(1.1, 0.9, 0.7), jitter=0.08)
    for i in range(4):
        a = i * 90 + 20
        m.cylinder("bark", 0.24, 0.2, 2.6, segments=6,
                   loc=(math.cos(math.radians(a)) * 1.4, math.sin(math.radians(a)) * 1.4, 0.1),
                   rot=(0, -58, a), cap_color="charcoal")
    m.cone("fire_red", 0.95, 2.3, segments=6, loc=(0, 0, 0.15))
    m.cone("fire_orange", 0.7, 2.7, segments=6, loc=(0.1, 0.05, 0.2), rot=(0, 0, 30))
    m.cone("fire_yellow", 0.4, 1.9, segments=5, loc=(-0.05, -0.05, 0.25))
    m.flatten_below(0.0)


@asset("Tent", seed=6)
def tent(m):
    w, h, d = 7.0, 5.0, 8.0
    m.prism("canvas", [(-w / 2, 0), (w / 2, 0), (0.25, h), (-0.25, h)], d)
    m.prism("canvas_dark", [(-1.3, 0), (1.3, 0), (0, h * 0.72)], 0.1,
            loc=(0, -d / 2 - 0.05, 0))
    m.cylinder("wood_dark", 0.12, 0.12, d + 1.2, segments=6,
               loc=(0, -(d + 1.2) / 2, h), rot=(-90, 0, 0))
    for y in (-d / 2 - 0.4, d / 2 + 0.4):
        m.cylinder("wood_dark", 0.13, 0.13, h + 0.2, segments=6, loc=(0, y, 0))
    for x in (-w / 2 - 0.3, w / 2 + 0.3):  # tent pegs
        for y in (-d / 2 + 0.6, d / 2 - 0.6):
            m.box("wood_light", (0.18, 0.18, 0.5), loc=(x, y, 0.25))


@asset("Crate", seed=8)
def crate(m):
    s, t = 3.0, 0.32
    m.box("wood", (s - 0.1, s - 0.1, s - 0.1), loc=(0, 0, s / 2))
    half, c = s / 2 - t / 2, s / 2
    for a in (-half, half):
        for b in (-half, half):
            m.box("wood_dark", (t, t, s), loc=(a, b, c))  # vertical edges
            m.box("wood_dark", (s - 2 * t, t, t), loc=(0, a, c + b))  # along X
            m.box("wood_dark", (t, s - 2 * t, t), loc=(a, 0, c + b))  # along Y
    for side in (-1, 1):
        m.box("wood_dark", (s * 1.2, 0.2, t * 0.8), loc=(0, side * (s / 2), c), rot=(0, 45, 0))


@asset("Canteen", seed=10)
def canteen(m):
    m.cylinder("water_blue", 0.9, 0.9, 0.55, segments=10, loc=(0, 0.275, 1.0), rot=(90, 0, 0))
    m.cylinder("metal_cap", 0.22, 0.2, 0.35, segments=6, loc=(0, 0, 1.85))
    m.cylinder("leather", 0.95, 0.95, 0.12, segments=10, loc=(0, 0.06, 1.0), rot=(90, 0, 0))
    m.flatten_below(0.0)


# --- Tools (origin = grip point, handle along +Z) ---------------------------

def _handle(m, length=3.0, below=0.8, r=0.12):
    m.cylinder("wood", r, r * 0.9, length, segments=6, loc=(0, 0, -below),
               cap_color="wood_dark")
    m.cylinder("leather", r * 1.25, r * 1.25, 0.9, segments=6, loc=(0, 0, -0.45))


@asset("Axe", seed=12)
def axe(m):
    _handle(m)
    top = 2.1
    m.box("steel_dark", (0.55, 0.32, 0.6), loc=(0.05, 0, top))
    blade = m.box("steel", (0.9, 0.14, 0.55), loc=(0.75, 0, top))
    for v in blade:  # flare the cutting edge taller
        if v.co.x > 0.9:
            v.co.z = top + (v.co.z - top) * 1.9
    m.box("steel_dark", (0.3, 0.26, 0.35), loc=(-0.35, 0, top))


@asset("Pickaxe", seed=13)
def pickaxe(m):
    _handle(m)
    top = 2.2
    m.box("steel_dark", (0.4, 0.34, 0.45), loc=(0, 0, top))
    for side in (1, -1):
        m.cylinder("steel", 0.2, 0.0, 1.5, segments=4, loc=(side * 0.15, 0, top),
                   rot=(0, side * 105, 0))


@asset("Torch", seed=14)
def torch(m):
    m.cylinder("wood", 0.1, 0.16, 2.6, segments=6, loc=(0, 0, -0.8))
    m.cylinder("cloth", 0.22, 0.24, 0.55, segments=6, loc=(0, 0, 1.4))
    m.cone("fire_orange", 0.24, 0.9, segments=5, loc=(0, 0, 1.95))
    m.cone("fire_yellow", 0.14, 0.6, segments=5, loc=(0.02, 0, 2.0), rot=(0, 0, 36))
