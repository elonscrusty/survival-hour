"""Marketing images for Pet Expedition: a 512x512 icon and two 1920x1080
thumbnails, rendered from the real pet/egg models (called by render.py)."""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter


def _burst(size, c1, c2, rays=(255, 255, 255, 40), n=18, centre=None):
    w, h = size
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    cx, cy = centre or (w / 2, h / 2)
    R = math.hypot(w, h)
    # radial gradient
    steps = 60
    for i in range(steps, 0, -1):
        t = i / steps
        col = tuple(int(c2[k] + (c1[k] - c2[k]) * (1 - t)) for k in range(3)) + (255,)
        r = R * t
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    ov = Image.new("RGBA", size)
    od = ImageDraw.Draw(ov)
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = a0 + math.pi / n
        od.polygon([(cx, cy), (cx + math.cos(a0) * R, cy + math.sin(a0) * R), (cx + math.cos(a1) * R, cy + math.sin(a1) * R)], fill=rays)
    im.alpha_composite(ov)
    rnd = random.Random(5)
    sp = Image.new("RGBA", size)
    sd = ImageDraw.Draw(sp)
    for _ in range(int(w * h / 9000)):
        x, y, s = rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(2, 7) * w / 1920 * 2
        sd.polygon([(x, y - s * 2), (x + s * 0.5, y), (x, y + s * 2), (x - s * 0.5, y)], fill=(255, 255, 255, 170))
        sd.polygon([(x - s * 2, y), (x, y + s * 0.5), (x + s * 2, y), (x, y - s * 0.5)], fill=(255, 255, 255, 170))
    im.alpha_composite(sp)
    return im


def _title(im, text, y, size, font_fn, fill=(255, 214, 64), stroke=(70, 30, 110)):
    d = ImageDraw.Draw(im)
    f = font_fn(size)
    w = d.textlength(text, font=f)
    x = (im.width - w) / 2
    sh = Image.new("RGBA", im.size)
    ImageDraw.Draw(sh).text((x + size * 0.04, y + size * 0.08), text, font=f, fill=(40, 10, 60, 160), stroke_width=int(size * 0.09),
                            stroke_fill=(40, 10, 60, 160))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size * 0.03)))
    d.text((x, y), text, font=f, fill=fill, stroke_width=int(size * 0.08), stroke_fill=stroke)


def _render_group(sc, items, path, res, direction=(0.12, 1.0, 0.18), margin=1.05):
    """items: list of (parts, (x, y, z) roblox offset)."""
    import render as R
    sc.clear()
    for parts, off in items:
        sc.add_parts(R.G.L.T(parts, off))
    sc.s.render.resolution_x, sc.s.render.resolution_y = res
    sc.s.render.film_transparent = True
    sc.frame(direction=direction, margin=margin)
    sc.render(path)
    return Image.open(path).convert("RGBA")


def make_marketing(sc, G, OUT):
    import render as R
    out = os.path.join(OUT, "marketing")
    os.makedirs(out, exist_ok=True)
    data = G.build_all()
    pets, eggs = data["pets"], data["eggs"]
    tmp = os.path.join(out, "tmp.png")
    sc.s.cycles.samples = max(sc.s.cycles.samples, 24)

    # Icon: puppy hero with a dragon and unicorn behind, an egg in front.
    items = [(pets["CosmicUnicorn"], (-2.6, 0, 2.5)), (pets["InfernoDragon"], (2.7, 0, 2.3)), (pets["Puppy"], (0, 0, 0)),
             (R.G.variant_parts(pets["Fox"], "Golden", False), (-3.2, 0, -0.6)), (eggs["PrismEgg"], (3.0, 0, -0.8))]
    fg = _render_group(sc, items, tmp, (512, 512), margin=0.9)
    bg = _burst((512, 512), (255, 236, 150), (255, 120, 190), n=14)
    bg.alpha_composite(fg)
    bg.convert("RGB").save(os.path.join(out, "icon_512.png"), optimize=True)

    # Thumbnail 1: big lineup of pets across rarities.
    lineup = ["Bunny", "Penguin", "Fox", "HoneyBear", "Puppy", "CometCat", "Narwhal", "Owl", "Kitten"]
    back = ["GlowcapDragon", "PolarKing", "CosmicUnicorn", "Phoenix", "CelestialDragon"]
    items = []
    for i, pid in enumerate(lineup):
        x = (i - (len(lineup) - 1) / 2) * 3.6
        items.append((pets[pid], (x, 0, -abs(x) * 0.15)))
    for i, pid in enumerate(back):
        x = (i - (len(back) - 1) / 2) * 5.6
        items.append((pets[pid], (x, 0, 5.5)))
    fg = _render_group(sc, items, tmp, (1920, 1080), direction=(0.0, 1.0, 0.32), margin=1.02)
    bg = _burst((1920, 1080), (140, 230, 255), (120, 90, 230), n=22, centre=(960, 700))
    fg = fg.resize((2400, 1350), Image.LANCZOS)
    canvas = bg.copy()
    canvas.alpha_composite(fg, (-240, -60))
    _title(canvas, "PET EXPEDITION", 40, 170, R.font)
    canvas.convert("RGB").save(os.path.join(out, "thumbnail_1.jpg"), quality=88)

    # Thumbnail 2: eggs and shiny variants.
    items = [(eggs[e], ((i - 3) * 3.2, 0, 4.5)) for i, e in enumerate(["MeadowEgg", "GroveEgg", "FrostEgg", "CoralEgg",
                                                                        "VolcanoEgg", "StarEgg", "PrismEgg"])]
    items += [(R.G.variant_parts(pets["InfernoDragon"], "Golden", False), (-6.5, 0, 0)),
              (R.G.variant_parts(pets["RainbowUnicorn"], "Normal", True), (0, 0, -0.5)),
              (R.G.variant_parts(pets["DiamondDragon"], "Rainbow", False), (6.5, 0, 0))]
    fg = _render_group(sc, items, tmp, (1920, 1080), direction=(0.0, 1.0, 0.28), margin=1.08)
    bg = _burst((1920, 1080), (255, 230, 140), (255, 110, 160), n=22, centre=(960, 760))
    canvas = bg.copy()
    canvas.alpha_composite(fg, (0, 110))
    _title(canvas, "PET EXPEDITION", 40, 170, R.font)
    _title(canvas, "HATCH  -  EXPLORE  -  COLLECT", 960, 70, R.font, fill=(255, 255, 255), stroke=(120, 40, 120))
    canvas.convert("RGB").save(os.path.join(out, "thumbnail_2.jpg"), quality=88)
    os.remove(tmp)
