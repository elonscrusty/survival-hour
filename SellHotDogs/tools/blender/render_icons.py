"""Render square UI icons (transparent PNG) for every asset .blend.

For each assets/blender/<Name>.blend: open it, drop the preview ground,
lights and camera, add a soft three-sun studio rig, frame the model with an
orthographic camera from a slight 3/4 angle so it fills ~85% of the frame,
render with Cycles (transparent film), then add a soft dark outline in PIL so
the silhouette still reads at 64px. Re-runnable: an icon newer than its .blend
is skipped unless --force.

Usage (from the SellHotDogs/ folder):
    python3 tools/blender/render_icons.py                 # all, skip up-to-date
    python3 tools/blender/render_icons.py --force         # re-render everything
    python3 tools/blender/render_icons.py --only Coin,Lock
    python3 tools/blender/render_icons.py --samples 16 --size 256
    python3 tools/blender/render_icons.py --sheet-only    # just rebuild icon_sheet.png

Outputs: assets/icons/<Name>.png (256x256 RGBA), assets/icons/icon_sheet.png
"""

import argparse
import glob
import math
import os
import sys
import time

import bpy  # noqa: E402
import numpy as np
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND_DIR = os.path.join(ROOT, "assets", "blender")
ICON_DIR = os.path.join(ROOT, "assets", "icons")

VIEW_DIR = Vector((0.78, -1.3, 0.72)).normalized()  # camera sits front-right, slightly above
FILL = 0.85
OVERSAMPLE = 2  # render at 2x then downsample for crisp edges


def lin(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def world_verts(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    out = []
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        n = len(me.vertices)
        if n:
            co = np.empty(n * 3, dtype=np.float64)
            me.vertices.foreach_get("co", co)
            co = co.reshape(-1, 3)
            mw = np.array(o.matrix_world)
            out.append(co @ mw[:3, :3].T + mw[:3, 3])
        ev.to_mesh_clear()
    return np.concatenate(out) if out else np.zeros((1, 3))


def setup_scene(size, samples):
    sc = bpy.context.scene
    for o in list(sc.objects):
        if o.name.startswith("_") or o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in sc.objects if o.type in ("MESH", "CURVE") and not o.hide_render]
    # soft ambient
    w = bpy.data.worlds.new("IconWorld")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*lin("F4F1EA"), 1)
    bg.inputs["Strength"].default_value = 0.75
    # three soft suns: key (front-left-top), fill (front-right), rim (behind)
    for name, energy, angle, rot, col in (
            ("Key", 3.0, 30, (rad(50), rad(0), rad(-30)), "FFF4E6"),
            ("Fill", 0.9, 45, (rad(65), rad(0), rad(60)), "E6F0FF"),
            ("Rim", 2.2, 20, (rad(-60), rad(0), rad(-20)), "FFFFFF")):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = energy
        ld.angle = rad(angle)
        ld.color = lin(col)
        lo = bpy.data.objects.new(name, ld)
        sc.collection.objects.link(lo)
        lo.rotation_euler = rot
    # orthographic camera framed on the projected silhouette
    cd = bpy.data.cameras.new("IconCam")
    cd.type = "ORTHO"
    cam = bpy.data.objects.new("IconCam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    verts = world_verts(meshes)
    lo_, hi_ = verts.min(0), verts.max(0)
    centre = Vector(((lo_ + hi_) / 2).tolist())
    radius = float(np.linalg.norm(hi_ - lo_)) / 2 + 1.0
    rot = (-VIEW_DIR).to_track_quat("-Z", "Y")
    right = np.array(rot @ Vector((1, 0, 0)))
    up = np.array(rot @ Vector((0, 1, 0)))
    rel = verts - np.array(centre)
    u, v = rel @ right, rel @ up
    du, dv = u.max() - u.min(), v.max() - v.min()
    shift = Vector(right * (u.max() + u.min()) / 2 + up * (v.max() + v.min()) / 2)
    cam.location = centre + shift + VIEW_DIR * (radius * 3)
    cam.rotation_euler = rot.to_euler()
    cd.ortho_scale = max(du, dv) / FILL
    cd.clip_start = 0.01
    cd.clip_end = radius * 8
    # render settings
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.max_bounces = 6
    try:
        sc.cycles.use_denoising = True
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        sc.cycles.use_denoising = False
    sc.render.resolution_x = size * OVERSAMPLE
    sc.render.resolution_y = size * OVERSAMPLE
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"


def rad(d):
    return math.radians(d)


def postprocess(raw, out, size):
    """Downsample and add a soft dark outline so the icon reads on any background."""
    from PIL import Image, ImageFilter
    im = Image.open(raw).convert("RGBA")
    a = im.getchannel("A")
    k = 2 * OVERSAMPLE + 1
    ring = a.filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.GaussianBlur(OVERSAMPLE * 0.6))
    outline = Image.new("RGBA", im.size, (52, 38, 34, 0))
    outline.putalpha(ring.point(lambda p: int(p * 0.85)))
    comp = Image.alpha_composite(outline, im)
    comp = comp.resize((size, size), Image.LANCZOS)
    comp.save(out)


def icon_sheet(size):
    from PIL import Image, ImageDraw, ImageFont
    names = sorted(os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(ICON_DIR, "*.png"))
                   if not p.endswith("icon_sheet.png"))
    cols, big, small, lab, pad = 8, 128, 64, 18, 8
    cw, ch = big + small + pad * 3, big + lab + pad * 2
    rows = max(1, math.ceil(len(names) / cols))
    sheet = Image.new("RGB", (cols * cw, rows * ch), (236, 240, 244))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 12)
    except Exception:
        font = ImageFont.load_default()
    for i, n in enumerate(names):
        x, y = (i % cols) * cw, (i // cols) * ch
        # checker behind the large copy shows transparency; dark tile behind the 64px copy
        for cx in range(0, big, 16):
            for cy in range(0, big, 16):
                c = (250, 250, 250) if (cx + cy) // 16 % 2 == 0 else (222, 226, 232)
                d.rectangle([x + pad + cx, y + pad + cy, x + pad + cx + 15, y + pad + cy + 15], fill=c)
        d.rectangle([x + big + pad * 2, y + pad, x + big + pad * 2 + small, y + pad + small], fill=(40, 52, 70))
        d.rectangle([x + big + pad * 2, y + pad + small + 4, x + big + pad * 2 + small,
                     y + pad + small * 2 + 4 - 8], fill=(255, 214, 90))
        im = Image.open(os.path.join(ICON_DIR, f"{n}.png")).convert("RGBA")
        sheet.paste(im.resize((big, big), Image.LANCZOS), (x + pad, y + pad), im.resize((big, big), Image.LANCZOS))
        sm = im.resize((small, small), Image.LANCZOS)
        sheet.paste(sm, (x + big + pad * 2, y + pad), sm)
        sm2 = im.resize((small - 8, small - 8), Image.LANCZOS)
        sheet.paste(sm2, (x + big + pad * 2 + 4, y + pad + small + 4), sm2)
        d.text((x + pad, y + pad + big + 2), n, fill=(40, 30, 30), font=font)
    sheet.save(os.path.join(ICON_DIR, "icon_sheet.png"))
    return len(names)


def main():
    argv = sys.argv[1:]
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--samples", type=int, default=14)
    ap.add_argument("--size", type=int, default=256)
    ap.add_argument("--sheet-only", action="store_true")
    a = ap.parse_args(argv)
    os.makedirs(ICON_DIR, exist_ok=True)
    only = {s.strip() for s in a.only.split(",") if s.strip()}
    t0 = time.time()
    done = skipped = 0
    if not a.sheet_only:
        blends = sorted(glob.glob(os.path.join(BLEND_DIR, "*.blend")))
        tmp = os.path.join(ICON_DIR, "_raw.png")
        for path in blends:
            name = os.path.splitext(os.path.basename(path))[0]
            if only and name not in only:
                continue
            out = os.path.join(ICON_DIR, f"{name}.png")
            if not a.force and os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(path):
                skipped += 1
                continue
            t1 = time.time()
            try:
                bpy.ops.wm.open_mainfile(filepath=path, load_ui=False)
                setup_scene(a.size, a.samples)
                bpy.context.scene.render.filepath = tmp
                bpy.ops.render.render(write_still=True)
                postprocess(tmp, out, a.size)
                done += 1
                print(f"[icon] {name} {time.time() - t1:.1f}s", flush=True)
            except Exception as e:  # keep going; another helper may be mid-write on a .blend
                print(f"[icon] {name} FAILED: {e}", flush=True)
        if os.path.exists(tmp):
            os.remove(tmp)
    n = icon_sheet(a.size)
    print(f"icons: rendered {done}, skipped {skipped}, sheet has {n}; {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
