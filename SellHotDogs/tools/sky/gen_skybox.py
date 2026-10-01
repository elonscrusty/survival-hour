"""Procedural cartoon skybox for Sell Hot Dogs (numpy + Pillow only).

Writes six 1024x1024 faces to assets/sky/sky_{bk,dn,ft,lf,rt,up}.png for a
Roblox Sky object (SkyboxBk/Dn/Ft/Lf/Rt/Up).

How it stays seamless:
  * Every pixel's colour comes from the elevation of its view direction on the
    cube (gnomonic projection), so the four side faces share exactly the same
    horizon height and gradient along every vertical edge, and their top and
    bottom edges meet the up/down faces at matching colours.
  * The sky gradient is flat above ~34 deg and the ground is flat below ~-30
    deg, so the up face is a plain light blue and the down face plain grass:
    both look the same in any rotation Roblox applies to them.
  * Clouds and distant hills fade out before the vertical face edges, so the
    side faces join cleanly whatever order or mirroring the engine uses.

Usage (from SellHotDogs/):  python3 tools/sky/gen_skybox.py [--size 1024] [--seed 4]
"""

import argparse
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "sky")


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


# elevation (degrees) -> colour keys
SKY = [(0.0, "FFE2B8"), (1.5, "FFEFD6"), (4.0, "D9F0FF"), (10.0, "A6DBFF"), (20.0, "7CC6FA"),
       (34.0, "62B6F4"), (90.0, "62B6F4")]
GROUND = [(0.0, "E4F0EA"), (-0.8, "B9DCB0"), (-2.5, "8DCB6E"), (-8.0, "74BD57"), (-30.0, "63AE48"),
          (-90.0, "63AE48")]


def ramp(e, keys):
    """Piecewise-smooth colour ramp; keys sorted by elevation (any direction)."""
    keys = sorted(keys)
    xs = np.array([k for k, _ in keys])
    cs = np.stack([hexc(c) for _, c in keys])
    e = np.clip(e, xs[0], xs[-1])
    idx = np.clip(np.searchsorted(xs, e, side="right") - 1, 0, len(xs) - 2)
    t = (e - xs[idx]) / (xs[idx + 1] - xs[idx])
    t = t * t * (3 - 2 * t)
    return cs[idx] * (1 - t[..., None]) + cs[idx + 1] * t[..., None]


def side_elevation(n):
    """Elevation (deg) for every pixel of a side face; x,y in [-1,1], y up."""
    c = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(c, -c)
    return np.degrees(np.arctan2(y, np.sqrt(1 + x * x))), x, y


def edge_window(x, margin=0.16):
    """1 in the middle of a face, fading to 0 within `margin` of the left/right edges."""
    d = 1 - np.abs(x)
    t = np.clip(d / margin, 0, 1)
    return t * t * (3 - 2 * t)


def value_noise_1d(n, rng, octaves=3):
    out = np.zeros(n)
    for o in range(octaves):
        k = 4 * 2 ** o
        pts = rng.uniform(-1, 1, k + 1)
        xs = np.linspace(0, k, n)
        i = np.floor(xs).astype(int).clip(0, k - 1)
        f = xs - i
        f = f * f * (3 - 2 * f)
        out += (pts[i] * (1 - f) + pts[i + 1] * f) / 2 ** o
    return out


def paint_hills(img, elev, x, rng):
    """Two soft bands of distant hills just above the horizon, faded at the face edges."""
    n = img.shape[0]
    win = edge_window(x[0], 0.22)
    for height, col, haze in ((4.5, "A7D3A6", 0.5), (2.4, "86C27A", 0.2)):
        prof = 0.35 + 0.65 * (0.5 + 0.5 * value_noise_1d(n, rng))
        h = 0.35 + (height * prof - 0.35) * win  # constant 0.35 deg at the edges
        mask = (elev > -1.5) & (elev < h[None, :])
        soft = np.clip((h[None, :] - elev) / 0.25, 0, 1) * mask
        c = hexc(col) * (1 - haze) + hexc("E8F3F0") * haze
        img[:] = img * (1 - soft[..., None]) + c * soft[..., None]


def paint_clouds(img, rng, count):
    """Flat-bottomed cartoon clouds in the horizon band, kept off the face edges."""
    n = img.shape[0]
    horizon = n / 2
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    placed = []
    tries = 0
    while len(placed) < count and tries < 200:
        tries += 1
        w = (0.38 if not placed else rng.uniform(0.18, 0.28)) * n * rng.uniform(0.9, 1.1)
        cx = rng.uniform(0.12 * n + w / 2, 0.88 * n - w / 2)
        base = horizon - rng.uniform(0.06, 0.24) * n
        if any(abs(cx - px) < (w + pw) / 2 + 0.03 * n and abs(base - pb) < 0.1 * n for px, pb, pw in placed):
            continue
        placed.append((cx, base, w))
    for cx, base, w in placed:
        lobes = rng.integers(4, 7)
        circles = []
        for i in range(lobes):
            t = i / (lobes - 1)
            r = w * (0.16 + 0.14 * math.sin(math.pi * t) + rng.uniform(-0.02, 0.03))
            circles.append((cx - w / 2 + r * 0.9 + t * (w - 1.8 * r), base - r * rng.uniform(0.25, 0.6), r))
        # extra top puffs
        for _ in range(2):
            r = w * rng.uniform(0.13, 0.19)
            circles.append((cx + rng.uniform(-0.2, 0.2) * w, base - w * rng.uniform(0.2, 0.3), r))
        x0 = int(max(0, cx - w)); x1 = int(min(n, cx + w))
        y0 = int(max(0, base - w)); y1 = int(min(n, base + 4))
        sx, sy = xx[y0:y1, x0:x1], yy[y0:y1, x0:x1]
        sd = np.full(sx.shape, 1e9)
        for px, py, r in circles:
            sd = np.minimum(sd, np.hypot(sx - px, sy - py) - r)
        sd = np.maximum(sd, sy - base)  # flat bottom
        alpha = np.clip(0.5 - sd / 2.0, 0, 1)
        h = w * 0.55
        t = np.clip((sy - (base - h)) / h, 0, 1)  # 0 at the cloud top, 1 at its flat base
        lower = np.clip((t - 0.55) / 0.45, 0, 1)[..., None]
        col = hexc("FFFFFF") * (1 - lower) + hexc("D3E4F5") * lower
        # thin soft rim (slightly bluer) for the stylised look
        rim = np.clip(1 - np.abs(sd + 3) / 3, 0, 1) * 0.35
        col = col * (1 - rim[..., None]) + hexc("BCD6EE") * rim[..., None]
        a = alpha[..., None]
        img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * (1 - a) + col * a


def side_face(n, rng, clouds):
    elev, x, y = side_elevation(n)
    img = np.where(elev[..., None] >= 0, ramp(elev, SKY), ramp(elev, GROUND))
    # warm glow concentrated near the horizon
    glow = np.exp(-np.abs(elev) / 2.5)[..., None] * 0.08
    img = img + glow * (hexc("FFD9A0") - img)
    paint_hills(img, elev, x, rng)
    paint_clouds(img, rng, clouds)
    return img


def cap_face(n, up):
    c = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(c, c)
    elev = np.degrees(np.arctan2(1.0, np.sqrt(x * x + y * y)))
    if not up:
        elev = -elev
    return ramp(elev, SKY if up else GROUND)


def save(img, name):
    arr = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(arr, "RGB").save(os.path.join(OUT, f"sky_{name}.png"), optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--seed", type=int, default=4)
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    n = a.size
    for i, (name, clouds) in enumerate((("ft", 3), ("rt", 2), ("bk", 3), ("lf", 2))):
        save(side_face(n, np.random.default_rng(a.seed * 10 + i), clouds), name)
    save(cap_face(n, True), "up")
    save(cap_face(n, False), "dn")
    # preview strip (lf ft rt bk) with up/dn above/below ft, for eyeballing seams
    faces = {k: Image.open(os.path.join(OUT, f"sky_{k}.png")).resize((256, 256)) for k in
             ("lf", "ft", "rt", "bk", "up", "dn")}
    prev = Image.new("RGB", (1024, 768), (30, 30, 30))
    for i, k in enumerate(("lf", "ft", "rt", "bk")):
        prev.paste(faces[k], (i * 256, 256))
    prev.paste(faces["up"], (256, 0))
    prev.paste(faces["dn"], (256, 512))
    prev.save(os.path.join(OUT, "sky_preview.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
