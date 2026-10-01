#!/usr/bin/env python3
"""Top-down map of a fully built plot from docs/evidence/plot_geometry.json (written by the smoke test).
A schematic of real part footprints (rotations included), drawn low-to-high. Not a Studio screenshot."""
import json, os
from PIL import Image, ImageDraw
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
parts = json.load(open(os.path.join(ROOT, "docs/evidence/plot_geometry.json")))
S, X0, Z0, W, H = 3, -115, -40, 230, 460  # px per stud, plot-local window
img = Image.new("RGB", (W * S, H * S), (110, 190, 90))
d = ImageDraw.Draw(img)
for p in sorted(parts, key=lambda q: q["y"]):
    pts = [((x - X0) * S, (H - (z - Z0)) * S) for x, z in p["p"]]
    c = tuple(int(255 * v) for v in p["c"])
    d.polygon(pts, fill=c, outline=(60, 40, 30))
d.text((8, 8), "Sell Hot Dogs - plot after buying everything (top-down, road at bottom)", fill=(20, 20, 20))
img.save(os.path.join(ROOT, "docs/evidence/plot_map_full.png"))
print("wrote docs/evidence/plot_map_full.png", len(parts), "parts")
