#!/usr/bin/env python3
"""Draws the PlayerGui layout dumps (tools/headless/out/ui_*.json, written by the render_dump
scenario) as rough 2D box diagrams: docs/screenshots/offline_ui_*.png.

These are OFFLINE LAYOUT SKETCHES from the headless mock's approximate layout engine (UDim2,
UIScale, UIListLayout/UIGridLayout, padding, safe-area insets; text width estimated). They show
where things land; they are not Roblox screenshots (no icons/images, fonts or gradients).
"""
import glob
import json
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "docs", "screenshots")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

_fonts = {}


def font(size):
    size = max(6, min(int(size), 64))
    if size not in _fonts:
        try:
            _fonts[size] = ImageFont.truetype(FONT, size)
        except OSError:
            _fonts[size] = ImageFont.load_default()
    return _fonts[size]


def render(path):
    data = json.load(open(path))
    w, h = int(data["w"]), int(data["h"])
    tag = os.path.basename(path)[3:-5]
    # game-world stand-in background (sky over grass) so translucent panels read correctly
    img = Image.new("RGBA", (w, h), (120, 170, 220, 255))
    d0 = ImageDraw.Draw(img)
    d0.rectangle([0, int(h * 0.45), w, h], fill=(110, 160, 80, 255))
    for b in data["boxes"]:
        if "gui" in b:
            continue
        x, y, bw, bh = b["x"], b["y"], b["w"], b["h"]
        if bw <= 0 or bh <= 0:
            continue
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        rect = [x, y, x + bw - 1, y + bh - 1]
        r = max(0, min(b.get("cr") or 0, min(bw, bh) / 2))
        alpha = int(255 * (1 - (b.get("bgt") or 0)))
        if alpha > 0 and b.get("bg"):
            fill = tuple(b["bg"]) + (alpha,)
            d.rounded_rectangle(rect, radius=r, fill=fill)
        st = b.get("stroke")
        if st and (alpha > 0 or st.get("border") is False):
            d.rounded_rectangle(rect, radius=r, outline=tuple(st["c"]) + (255,), width=max(1, int(round(st["w"]))))
        text = b.get("text")
        if text:
            ts = b.get("ts") or 12
            if b.get("scaled"):
                # TextScaled: shrink until the longest line fits the box (like Roblox does)
                longest = max(text.split("\n"), key=len)
                while ts > 7 and d.textlength(longest, font=font(ts)) > bw - 4:
                    ts -= 1
            f = font(ts)
            tc = tuple(b.get("tc") or (255, 255, 255)) + (255,)
            lines = text.replace("\r", "").split("\n")
            # crude wrap to the box width
            wrapped = []
            for line in lines:
                words = line.split(" ")
                cur = ""
                for word in words:
                    trial = (cur + " " + word).strip()
                    if d.textlength(trial, font=f) <= max(bw - 4, 8) or not cur:
                        cur = trial
                    else:
                        wrapped.append(cur)
                        cur = word
                wrapped.append(cur)
            lh = ts * 1.15
            ty = y + (bh - lh * len(wrapped)) / 2
            for line in wrapped:
                tw = d.textlength(line, font=f)
                tx = x + (bw - tw) / 2
                d.text((tx + 1, ty + 1), line, font=f, fill=(0, 0, 0, 160))
                d.text((tx, ty), line, font=f, fill=tc)
                ty += lh
        clip = b.get("clip")
        if clip:
            mask = Image.new("L", (w, h), 0)
            ImageDraw.Draw(mask).rectangle([clip[0], clip[1], clip[2], clip[3]], fill=255)
            empty = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            layer = Image.composite(layer, empty, mask)
        img = Image.alpha_composite(img, layer)
    d = ImageDraw.Draw(img)
    label = "OFFLINE LAYOUT SKETCH (headless mock, not a Roblox screenshot) - %s" % tag
    f = font(11)
    tw = d.textlength(label, font=f)
    d.rectangle([0, h - 16, tw + 8, h], fill=(0, 0, 0, 200))
    d.text((4, h - 15), label, font=f, fill=(255, 255, 0, 255))
    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, "offline_ui_%s.png" % tag)
    img.convert("RGB").save(dest, optimize=True)
    print("wrote", os.path.relpath(dest, ROOT), os.path.getsize(dest) // 1024, "KB")


def main():
    files = sorted(glob.glob(os.path.join(HERE, "out", "ui_*.json")))
    if not files:
        raise SystemExit("no ui_*.json dumps; run: python3 tools/headless/run.py render_dump")
    for p in files:
        render(p)


if __name__ == "__main__":
    main()
