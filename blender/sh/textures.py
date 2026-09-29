"""Procedural PBR texture atlas for Survival Hour.

One 1024 x 1024 atlas holds 64 material tiles (8 x 8, 128 px each). Every
mesh in the pack uses this single atlas, so the whole pack needs one
SurfaceAppearance (Color, Normal, Roughness, Metalness). Team variants only
swap the Color map: the two "team" tiles are recoloured.

Tiles are seamless. Grain and fibre features run along the tile's U axis;
the modeling code aligns U with the long direction of each face.

Pure numpy + zlib, so it runs inside Blender without extra packages.
"""

import struct
import zlib

import numpy as np

TILE = 128
GRID = 8
ATLAS = TILE * GRID
MARGIN = 10  # px kept free around each tile's used area (mip bleeding)

TEAMS = {
    "Red": "a8372c",
    "Blue": "2f5d9c",
    "Yellow": "c99a22",
    "Purple": "6a3f8f",
}
NEUTRAL_TEAM = "8a8578"


# --- noise ------------------------------------------------------------------

def _smooth(t):
    return t * t * (3 - 2 * t)


def vnoise(rng, fx, fy, size=TILE):
    """Periodic value noise with fx x fy lattice cells over the tile."""
    g = rng.random((fy, fx))
    x = np.arange(size) * fx / size
    y = np.arange(size) * fy / size
    xi, yi = np.floor(x).astype(int), np.floor(y).astype(int)
    xf, yf = _smooth(x - xi), _smooth(y - yi)
    x0, x1 = xi % fx, (xi + 1) % fx
    y0, y1 = yi % fy, (yi + 1) % fy
    a = g[np.ix_(y0, x0)]
    b = g[np.ix_(y0, x1)]
    c = g[np.ix_(y1, x0)]
    d = g[np.ix_(y1, x1)]
    top = a + (b - a) * xf[None, :]
    bot = c + (d - c) * xf[None, :]
    return top + (bot - top) * yf[:, None]


def fbm(rng, fx, fy=None, octaves=4, gain=0.5):
    fy = fx if fy is None else fy
    out = np.zeros((TILE, TILE))
    amp, total = 1.0, 0.0
    for i in range(octaves):
        out += vnoise(rng, fx * 2 ** i, fy * 2 ** i) * amp
        total += amp
        amp *= gain
    return out / total


def worley(rng, n):
    """Periodic distance to nearest feature point (n x n cells), 0..~1."""
    pts = rng.random((n, n, 2))
    ys, xs = np.mgrid[0:TILE, 0:TILE] * (n / TILE)
    ci, cj = np.floor(ys).astype(int), np.floor(xs).astype(int)
    best = np.full((TILE, TILE), 9.0)
    second = np.full((TILE, TILE), 9.0)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            ni, nj = ci + di, cj + dj
            p = pts[ni % n, nj % n]
            d = np.hypot(ni + p[..., 0] - ys, nj + p[..., 1] - xs)
            second = np.where(d < best, best, np.minimum(second, d))
            best = np.minimum(best, d)
    return best, second


def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def mix(c1, c2, t):
    t = np.clip(t, 0, 1)[..., None]
    return c1 * (1 - t) + c2 * t


def norm01(a):
    a = a - a.min()
    m = a.max()
    return a / m if m > 0 else a


# --- tile generators ----------------------------------------------------------
# Each returns (albedo HxWx3, height HxW, roughness HxW, metal HxW), 0..1.

def t_wood(rng, light, dark, weather=0.35):
    n = fbm(rng, 2, 14, 4)
    grain = 0.5 + 0.5 * np.sin(n * 40 + fbm(rng, 1, 6, 2) * 12)
    streak = fbm(rng, 1, 40, 2)
    t = 0.55 * grain + 0.45 * streak
    col = mix(hexrgb(dark), hexrgb(light), t)
    grey = fbm(rng, 3, 3, 3)
    col = mix(col, np.array([0.55, 0.53, 0.5]) * col.mean(), grey * weather)
    crack = np.clip(1 - np.abs(fbm(rng, 1, 10, 3) - 0.5) * 60, 0, 1)
    col *= (1 - 0.45 * crack)[..., None]
    h = 0.6 * grain + 0.4 * streak - 0.8 * crack
    return col, norm01(h), 0.78 + 0.15 * grey, np.zeros_like(h)


def t_end_grain(rng, light, dark):
    ys, xs = np.mgrid[0:TILE, 0:TILE] / TILE - 0.5
    r = np.hypot(xs, ys) + fbm(rng, 3, 3, 3) * 0.06
    rings = 0.5 + 0.5 * np.sin(r * 95)
    col = mix(hexrgb(light), hexrgb(dark), rings * 0.45 + r * 0.6)
    crack = np.clip(1 - np.abs(np.arctan2(ys, xs) - 0.7) * 25, 0, 1) * (r < 0.4)
    col *= (1 - 0.5 * crack)[..., None]
    return col, norm01(rings - crack), np.full((TILE, TILE), 0.8), np.zeros((TILE, TILE))


def t_bark(rng, light, dark, ridges=7):
    ys = np.mgrid[0:TILE, 0:TILE][0] / TILE
    warp = fbm(rng, 3, 2, 3)
    r = np.abs(np.sin((ys * ridges + warp * 1.5) * np.pi))
    plates = fbm(rng, 6, 3, 3)
    h = r ** 0.6 * 0.7 + plates * 0.3
    col = mix(hexrgb(dark), hexrgb(light), h * 1.1 - 0.1)
    moss = np.clip((fbm(rng, 2, 2, 3) - 0.7) * 5, 0, 1)
    col = mix(col, hexrgb("56663a"), moss * 0.35)
    return col, h, 0.9 - 0.1 * h, np.zeros_like(h)


def t_birch(rng):
    col, h, rgh, met = t_bark(rng, "e6e1d3", "c9c2b0", ridges=2)
    marks = (fbm(rng, 10, 1, 3) > 0.66) & (fbm(rng, 1, 20, 2) > 0.5)
    col[marks] = hexrgb("2d2a26")
    h = h * 0.3 - marks * 0.4
    return col, norm01(h), rgh, met


def t_stone(rng, light, dark, vein=None, moss=0.0):
    big = fbm(rng, 3, 3, 5)
    f1, f2 = worley(rng, 3)
    crack = np.clip(1 - (f2 - f1) * 14, 0, 1) * (fbm(rng, 4, 4, 2) > 0.45)
    grit = fbm(rng, 16, 16, 3)
    speck = (vnoise(rng, 64, 64) > 0.8) * 0.12
    h = big * 0.6 + grit * 0.4 - crack * 0.5
    col = mix(hexrgb(dark), hexrgb(light), big * 1.2 - 0.1 + (grit - 0.5) * 0.5 + speck)
    col *= (1 - 0.4 * crack)[..., None]
    if vein:
        v = np.clip(1 - np.abs(fbm(rng, 2, 3, 4) - 0.5) * 22, 0, 1)
        col = mix(col, hexrgb(vein), v)
        h += v * 0.2
    if moss:
        m = np.clip((fbm(rng, 3, 3, 4) - (0.62 - moss * 0.3)) * 6, 0, 1)
        col = mix(col, hexrgb("4f6b35"), m * 0.85)
    return col, norm01(h), 0.88 - speck, np.zeros_like(h)


def t_leather(rng, base, dark, stitch=False):
    f1, _ = worley(rng, 22)
    pebble = 1 - np.clip(f1 * 1.4, 0, 1)
    tone = fbm(rng, 3, 3, 4)
    col = mix(hexrgb(dark), hexrgb(base), tone * 0.9 + pebble * 0.25)
    scuff = np.clip((fbm(rng, 4, 4, 3) - 0.6) * 4, 0, 1)
    col = mix(col, hexrgb(base) * 1.25, scuff * 0.5)
    h = pebble * 0.5 + tone * 0.2
    if stitch:  # two stitch lines near the tile's top and bottom (fit-mapped straps)
        ys, xs = np.mgrid[0:TILE, 0:TILE]
        for yc in (MARGIN + 12, TILE - MARGIN - 12):
            line = (np.abs(ys - yc) < 2) & ((xs // 6) % 2 == 0)
            col[line] = hexrgb("d8c9a3")
            h = np.where(line, 1.0, h)
            groove = np.abs(ys - yc) < 4
            h = np.where(groove & ~line, h - 0.2, h)
    return col, norm01(h), 0.62 - 0.2 * scuff, np.zeros_like(h)


def t_rope(rng, light, dark):
    ys, xs = np.mgrid[0:TILE, 0:TILE] / TILE
    strands = 0.5 + 0.5 * np.sin((xs * 6 + ys * 2) * 2 * np.pi)
    fib = fbm(rng, 2, 30, 2)
    h = strands ** 0.7 * 0.8 + fib * 0.2
    col = mix(hexrgb(dark), hexrgb(light), h)
    return col, h, np.full_like(h, 0.92), np.zeros_like(h)


def t_metal(rng, base, rust=0.2, worn="d4d8dc"):
    brushed = fbm(rng, 1, 40, 2)
    tone = fbm(rng, 3, 3, 4)
    col = mix(hexrgb(base) * 0.85, hexrgb(base) * 1.1, brushed * 0.5 + tone * 0.5)
    scratch = np.clip(1 - np.abs(fbm(rng, 2, 7, 3) - 0.5) * 70, 0, 1)
    col = mix(col, hexrgb(worn), scratch * 0.7)
    r = np.clip((fbm(rng, 4, 4, 5) - (0.7 - rust * 0.3)) * 5, 0, 1) * (rust > 0)
    col = mix(col, hexrgb("7a4128"), r)
    met = np.clip(1 - r * 1.2, 0, 1)
    rough = 0.45 + 0.25 * tone + 0.35 * r - 0.2 * scratch
    return col, norm01(brushed * 0.3 - r * 0.2 + tone * 0.3), rough, met


def t_cloth(rng, base, dark=None, weave=24):
    ys, xs = np.mgrid[0:TILE, 0:TILE] / TILE
    w = (np.sin(xs * weave * 2 * np.pi) * np.sin(ys * weave * 2 * np.pi)) * 0.5 + 0.5
    tone = fbm(rng, 3, 3, 4)
    dirt = np.clip((fbm(rng, 3, 3, 4) - 0.6) * 3, 0, 1)
    b = hexrgb(base)
    col = mix(b * 0.82, b * 1.05, w * 0.4 + tone * 0.6)
    col = mix(col, hexrgb(dark or "5a4a35"), dirt * 0.45)
    return col, w * 0.6 + tone * 0.4, np.full_like(w, 0.95), np.zeros_like(w)


def t_foliage(rng, light, dark, blotch=6):
    f1, f2 = worley(rng, blotch * 2)
    leaf = np.clip((f2 - f1) * 4, 0, 1)
    tone = fbm(rng, 3, 3, 4)
    col = mix(hexrgb(dark), hexrgb(light), leaf * 0.6 + tone * 0.5)
    return col, norm01(leaf + tone * 0.5), 0.75 - 0.15 * leaf, np.zeros_like(leaf)


def t_streaks(rng, light, dark, fy=24, tip=None):
    s = fbm(rng, 1, fy, 3)
    tone = fbm(rng, 2, 2, 3)
    col = mix(hexrgb(dark), hexrgb(light), s * 0.8 + tone * 0.4)
    if tip:
        xs = np.mgrid[0:TILE, 0:TILE][1] / TILE
        col = mix(col, hexrgb(tip), np.clip((xs - 0.7) * 3, 0, 1) * 0.6)
    return col, s, np.full_like(s, 0.8), np.zeros_like(s)


def t_fur(rng, light, dark, under=None):
    s = fbm(rng, 2, 36, 3)
    clumps = fbm(rng, 4, 8, 3)
    h = s * 0.7 + clumps * 0.3
    col = mix(hexrgb(dark), hexrgb(light), h * 1.2 - 0.1)
    if under:
        col = mix(col, hexrgb(under), np.clip((fbm(rng, 2, 2, 2) - 0.55) * 3, 0, 1) * 0.4)
    return col, h, np.full_like(h, 0.85), np.zeros_like(h)


def t_ground(rng, light, dark, pebbles=True):
    tone = fbm(rng, 4, 4, 5)
    col = mix(hexrgb(dark), hexrgb(light), tone)
    h = tone
    if pebbles:
        f1, _ = worley(rng, 10)
        p = f1 < 0.18
        col[p] = mix(col[p], np.array([0.5, 0.48, 0.45]), np.full(p.sum(), 0.7))
        h = h + p * 0.4
    return col, norm01(h), np.full_like(h, 0.95), np.zeros_like(h)


def t_flat(rng, color, rough=0.8, metal=0.0, noise=0.06):
    tone = fbm(rng, 3, 3, 3)
    col = hexrgb(color) * (1 - noise + noise * 2 * tone)[..., None]
    return col, tone * 0.2, np.full_like(tone, rough), np.full_like(tone, metal)


def t_embers(rng):
    f1, f2 = worley(rng, 7)
    crack = np.clip(1 - (f2 - f1) * 8, 0, 1)
    col = mix(hexrgb("1c1918"), hexrgb("2e2926"), fbm(rng, 3, 3, 3))
    col = mix(col, hexrgb("ff6a1a"), crack ** 2)
    return col, norm01(1 - crack), np.full_like(crack, 0.9), np.zeros_like(crack)


def t_fire(rng):
    xs = np.mgrid[0:TILE, 0:TILE][1] / TILE
    n = fbm(rng, 2, 4, 3)
    t = np.clip(xs + n * 0.4 - 0.2, 0, 1)
    col = mix(hexrgb("ffe27a"), hexrgb("e8491f"), t)
    return col, n * 0.1, np.full_like(n, 1.0), np.zeros_like(n)


def t_crystal(rng):
    f1, f2 = worley(rng, 4)
    facet = np.clip((f2 - f1) * 3, 0, 1)
    col = mix(hexrgb("bff6ff"), hexrgb("3fb8e0"), facet)
    return col, facet, np.full_like(facet, 0.1), np.zeros_like(facet)


def t_painted_wood(rng, paint, wear=0.45):
    col, h, rough, met = t_wood(rng, "a9825a", "5e4128", 0.2)
    chip = np.clip((fbm(rng, 5, 5, 4) - (1 - wear)) * 6, 0, 1)
    paint_col = hexrgb(paint) * (0.9 + 0.15 * fbm(rng, 3, 3, 3))[..., None]
    col = mix(paint_col, col, chip)
    return col, norm01(h * 0.3 + (1 - chip) * 0.3), rough * 0.9, met


# --- tile table -----------------------------------------------------------------
# name -> generator. ORDER MATTERS: indices are baked into mesh UVs. Append only.

def _tiles():
    return [
        ("wood", lambda r: t_wood(r, "b08a5c", "6d4d30")),
        ("wood_dark", lambda r: t_wood(r, "7d6a55", "3f3326", 0.55)),
        ("wood_fresh", lambda r: t_wood(r, "e1c08f", "b98f5c", 0.0)),
        ("end_grain", lambda r: t_end_grain(r, "e3c79a", "9c7447")),
        ("bark", lambda r: t_bark(r, "6e5440", "2f231a")),
        ("bark_pine", lambda r: t_bark(r, "875438", "3a2217", 10)),
        ("bark_birch", t_birch),
        ("bark_dead", lambda r: t_bark(r, "8a857c", "3b3834", 5)),
        ("stone", lambda r: t_stone(r, "a3a39c", "5d5d58")),
        ("stone_dark", lambda r: t_stone(r, "70706b", "383836")),
        ("stone_mossy", lambda r: t_stone(r, "9a9a90", "585852", moss=0.7)),
        ("stone_vein", lambda r: t_stone(r, "9f9a92", "57534e", vein="f3e7c4")),
        ("leather", lambda r: t_leather(r, "8a5a36", "4a2c18")),
        ("leather_stitch", lambda r: t_leather(r, "8a5a36", "4a2c18", True)),
        ("leather_dark", lambda r: t_leather(r, "5a3a26", "2a1a10")),
        ("rope", lambda r: t_rope(r, "c9ad7a", "7c6440")),
        ("metal", lambda r: t_metal(r, "8d949b", 0.12)),
        ("metal_dark", lambda r: t_metal(r, "4b4f54", 0.35, worn="9aa0a6")),
        ("gunmetal", lambda r: t_metal(r, "3a3e44", 0.05, worn="7d848c")),
        ("brass", lambda r: t_metal(r, "b38b3e", 0.0, worn="f0d68a")),
        ("cloth", lambda r: t_cloth(r, "cbb895")),
        ("cloth_dark", lambda r: t_cloth(r, "5d5446", "2a241c")),
        ("bandage", lambda r: t_cloth(r, "ece6d8", "b7a98d", weave=40)),
        ("leaves", lambda r: t_foliage(r, "6f9a45", "2f5a2a")),
        ("leaves_dark", lambda r: t_foliage(r, "4a7a3c", "1f3f22")),
        ("leaves_birch", lambda r: t_foliage(r, "a3b84e", "5a7a2e")),
        ("pine_needles", lambda r: t_streaks(r, "3f6e4c", "1c3d2c", 40)),
        ("grass", lambda r: t_streaks(r, "7aa34a", "3c6a2c", 30, tip="c8c77a")),
        ("fiber", lambda r: t_streaks(r, "c9cf86", "7c9a4a", 36, tip="efe3a3")),
        ("fern", lambda r: t_foliage(r, "5f9a3e", "2b5a26", 10)),
        ("dirt", lambda r: t_ground(r, "7a5f44", "4a3828")),
        ("forest_floor", lambda r: t_ground(r, "5f5a3a", "35321f")),
        ("moss", lambda r: t_foliage(r, "6f8a3a", "3a5222", 12)),
        ("fur_grey", lambda r: t_fur(r, "9a948c", "4b4843", "c9c2b5")),
        ("fur_light", lambda r: t_fur(r, "d6cfc0", "978f82")),
        ("fur_brown", lambda r: t_fur(r, "7a5238", "33200f", "9c7650")),
        ("fur_bat", lambda r: t_fur(r, "4d3f3a", "1d1715")),
        ("membrane", lambda r: t_leather(r, "5a4540", "2e2220")),
        ("bone", lambda r: t_flat(r, "e8dfc8", 0.5)),
        ("eye", lambda r: t_flat(r, "1a1410", 0.15, noise=0.02)),
        ("eye_glow", lambda r: t_flat(r, "e8b73a", 0.2, noise=0.02)),
        ("nose", lambda r: t_flat(r, "22201e", 0.35)),
        ("fire", t_fire),
        ("embers", t_embers),
        ("charcoal", lambda r: t_stone(r, "34302d", "141211")),
        ("ash", lambda r: t_ground(r, "8d8882", "4d4945", False)),
        ("wet_wood", lambda r: t_wood(r, "4c3a2a", "1e160f", 0.1)),
        ("water", lambda r: t_flat(r, "3f6f86", 0.05, noise=0.1)),
        ("team_cloth", lambda r: t_cloth(r, NEUTRAL_TEAM)),
        ("team_paint", lambda r: t_painted_wood(r, NEUTRAL_TEAM)),
        ("diamond", t_crystal),
        ("chute_a", lambda r: t_cloth(r, "d9692e", weave=16)),
        ("chute_b", lambda r: t_cloth(r, "e8e2d2", weave=16)),
        ("crate_paint", lambda r: t_painted_wood(r, "58633b", 0.3)),
        ("sign_blank", lambda r: t_wood(r, "d8c29a", "b39a70", 0.05)),
        ("enamel_teal", lambda r: t_flat(r, "2f8f8a", 0.35)),
        ("enamel_amber", lambda r: t_flat(r, "d08a22", 0.35)),
        ("enamel_red", lambda r: t_flat(r, "a8322c", 0.35)),
        ("enamel_slate", lambda r: t_flat(r, "4d6a8f", 0.35)),
        ("enamel_orange", lambda r: t_flat(r, "b8622a", 0.35)),
        ("enamel_purple", lambda r: t_flat(r, "6d4a9a", 0.35)),
        ("glow", lambda r: t_flat(r, "ffc56a", 0.3, noise=0.02)),
        ("red_paint", lambda r: t_painted_wood(r, "b3302a", 0.2)),
        ("pine_needles_dark", lambda r: t_streaks(r, "335f40", "142e20", 40)),
    ]


TILE_NAMES = [n for n, _ in _tiles()]
TILE_INDEX = {n: i for i, n in enumerate(TILE_NAMES)}
assert len(TILE_NAMES) <= GRID * GRID


def tile_rect(index):
    """(u0, v0, u1, v1) of the usable area of a tile, inside the margin."""
    col, row = index % GRID, index // GRID
    u0 = (col * TILE + MARGIN) / ATLAS
    u1 = ((col + 1) * TILE - MARGIN) / ATLAS
    v1 = 1 - (row * TILE + MARGIN) / ATLAS
    v0 = 1 - ((row + 1) * TILE - MARGIN) / ATLAS
    return u0, v0, u1, v1


# --- output ---------------------------------------------------------------------

def _png(path, arr):
    arr = np.clip(arr * 255 + 0.5, 0, 255).astype(np.uint8)
    h, w = arr.shape[:2]
    ctype = 0 if arr.ndim == 2 else 2
    raw = b"".join(b"\x00" + arr[y].tobytes() for y in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def _normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, 1, 0) - np.roll(h, -1, 0)) * strength  # +V is up (OpenGL)
    n = np.dstack([-dx, -dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def downscale(arr, factor):
    h, w = arr.shape[:2]
    return arr.reshape(h // factor, factor, w // factor, factor, *arr.shape[2:]).mean(axis=(1, 3))


def build_atlas(out_dir, embed_size=256):
    """Write all atlas maps. Returns dict of written file paths."""
    import os
    os.makedirs(out_dir, exist_ok=True)
    color = np.zeros((ATLAS, ATLAS, 3))
    normal = np.zeros((ATLAS, ATLAS, 3))
    rough = np.zeros((ATLAS, ATLAS))
    metal = np.zeros((ATLAS, ATLAS))
    team_tiles = {}
    for i, (name, gen) in enumerate(_tiles()):
        rng = np.random.default_rng(1000 + i)
        c, h, r, m = gen(rng)
        y, x = (i // GRID) * TILE, (i % GRID) * TILE
        color[y:y + TILE, x:x + TILE] = np.clip(c, 0, 1)
        normal[y:y + TILE, x:x + TILE] = _normal_from_height(h, 2.2)
        rough[y:y + TILE, x:x + TILE] = np.clip(r, 0.02, 1)
        metal[y:y + TILE, x:x + TILE] = np.clip(m, 0, 1)
        if name.startswith("team_"):
            team_tiles[name] = (i, gen)
    # unused tiles: neutral grey
    for i in range(len(TILE_NAMES), GRID * GRID):
        y, x = (i // GRID) * TILE, (i % GRID) * TILE
        color[y:y + TILE, x:x + TILE] = 0.5
        normal[y:y + TILE, x:x + TILE] = (0.5, 0.5, 1.0)
        rough[y:y + TILE, x:x + TILE] = 0.8

    files = {}
    p = lambda n: os.path.join(out_dir, n)
    _png(p("T_SurvivalAtlas_Color_Neutral.png"), color)
    files["Color_Neutral"] = p("T_SurvivalAtlas_Color_Neutral.png")
    _png(p("T_SurvivalAtlas_Normal.png"), normal)
    _png(p("T_SurvivalAtlas_Roughness.png"), rough)
    _png(p("T_SurvivalAtlas_Metalness.png"), metal)
    files.update(Normal=p("T_SurvivalAtlas_Normal.png"),
                 Roughness=p("T_SurvivalAtlas_Roughness.png"),
                 Metalness=p("T_SurvivalAtlas_Metalness.png"))

    for team, hexcol in TEAMS.items():
        tc = color.copy()
        for name, (i, _) in team_tiles.items():
            rng = np.random.default_rng(1000 + i)
            gen = (lambda r, hc=hexcol: t_cloth(r, hc)) if name == "team_cloth" else \
                  (lambda r, hc=hexcol: t_painted_wood(r, hc))
            c = gen(rng)[0]
            y, x = (i // GRID) * TILE, (i % GRID) * TILE
            tc[y:y + TILE, x:x + TILE] = np.clip(c, 0, 1)
        path = p(f"T_SurvivalAtlas_Color_{team}.png")
        _png(path, tc)
        files["Color_" + team] = path

    small = downscale(color, ATLAS // embed_size)
    _png(p("T_SurvivalAtlas_Color_Embed256.png"), small)
    files["Embed"] = p("T_SurvivalAtlas_Color_Embed256.png")
    return files


if __name__ == "__main__":
    import sys
    print(build_atlas(sys.argv[1] if len(sys.argv) > 1 else "Textures"))


# --- flat colour picks (no atlas change) -------------------------------------------

_TONE_CACHE = {}
_TONE_RGB = {}


def _box_blur(a, r):
    out = np.zeros_like(a)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out += np.roll(np.roll(a, dy, 0), dx, 1)
    return out / (2 * r + 1) ** 2


def tone_uv(index, q):
    """Atlas UV of a calm spot inside tile `index` whose (blurred) lightness sits at
    percentile q (0 = darkest, 100 = lightest). Collapsing a face's UVs onto this
    point gives it one flat colour taken from the existing atlas, so flat-coloured
    models need no new tiles. Also survives the downscaled embedded atlas."""
    key = (index, int(q))
    if key in _TONE_CACHE:
        return _TONE_CACHE[key]
    if index not in _TONE_CACHE:
        gen = _tiles()[index][1]
        c = np.clip(gen(np.random.default_rng(1000 + index))[0], 0, 1)
        c = _box_blur(c, 5)
        lum = c @ np.array([0.3, 0.59, 0.11])
        gy, gx = np.gradient(lum)
        _TONE_CACHE[index] = (lum, np.hypot(gx, gy), c)
    lum, grad, _ = _TONE_CACHE[index]
    lo, hi = MARGIN + 12, TILE - MARGIN - 12
    inner = lum[lo:hi, lo:hi]
    target = np.percentile(inner, q)
    score = np.abs(inner - target) + 2.0 * grad[lo:hi, lo:hi]
    y, x = np.unravel_index(np.argmin(score), score.shape)
    _TONE_RGB[key] = tuple(float(v) for v in _TONE_CACHE[index][2][y + lo, x + lo])
    y, x = y + lo + 0.5, x + lo + 0.5
    col, row = index % GRID, index // GRID
    uv = ((col * TILE + x) / ATLAS, 1 - (row * TILE + y) / ATLAS)
    _TONE_CACHE[key] = uv
    return uv


def tone_rgb(index, q):
    """sRGB colour (0..1) that tone_uv(index, q) picks: lets a model match a
    source colour to the nearest existing atlas swatch."""
    tone_uv(index, q)
    return _TONE_RGB[(index, int(q))]
