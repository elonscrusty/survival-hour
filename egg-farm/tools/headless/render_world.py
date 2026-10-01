#!/usr/bin/env python3
"""Renders the world dumps (tools/headless/out/world_*.json, written by the render_dump
scenario) with Blender Cycles (CPU): docs/screenshots/offline_<state>_<camera>.png.

These are OFFLINE RENDERS OF THE GENERATED LAYOUT: every BasePart the real World/Models code
built inside the headless mock (class, shape, size, CFrame, colour, material, transparency),
drawn as plain geometry. Not Roblox screenshots: no Roblox lighting, materials, terrain,
textures, particles or GUIs. Run with: python3 tools/headless/render_world.py [--samples 16]
"""
import glob
import json
import math
import os
import sys
import time

import bpy  # noqa: E402  (bpy must be imported before bmesh/mathutils)
import bmesh
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "docs", "screenshots")
SAMPLES = 16
RES = (960, 540)

# Roblox (x right, y up, -z forward) -> Blender (x right, y forward, z up): (x, y, z) -> (x, -z, y)
P = mathutils.Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
PT = P.transposed()


def rbx_to_bl(v):
    return mathutils.Vector((v[0], -v[2], v[1]))


def part_matrix(cf):
    x, y, z = cf[0], cf[1], cf[2]
    r = mathutils.Matrix(((cf[3], cf[4], cf[5]), (cf[6], cf[7], cf[8]), (cf[9], cf[10], cf[11])))
    rb = P @ r @ PT
    m = rb.to_4x4()
    m.translation = rbx_to_bl((x, y, z))
    return m


def unit_geom(kind):
    """Vertices (Roblox-local, unit half-extents) and faces for each part shape."""
    if kind == "block":
        v = [(sx, sy, sz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        return v, f
    if kind == "wedge":
        # Roblox WedgePart: high edge at +Z (back), slope down to the front (-Z)
        v = [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1), (-1, 1, 1), (1, 1, 1)]
        f = [(0, 3, 2, 1), (3, 4, 5, 2), (0, 1, 5, 4), (0, 4, 3), (1, 2, 5)]
        return v, f
    if kind == "cornerwedge":
        v = [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1), (1, 1, -1)]
        f = [(0, 3, 2, 1), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
        return v, f
    if kind == "cylinder":
        # axis along X
        n = 16
        v, f = [], []
        for i in range(n):
            a = 2 * math.pi * i / n
            v.append((-1, math.cos(a), math.sin(a)))
            v.append((1, math.cos(a), math.sin(a)))
        for i in range(n):
            j = (i + 1) % n
            f.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
        f.append(tuple(2 * i for i in range(n))[::-1])
        f.append(tuple(2 * i + 1 for i in range(n)))
        return v, f
    if kind == "sphere":
        rings, segs = 8, 14
        v = [(0, -1, 0)]
        for r in range(1, rings):
            phi = math.pi * r / rings - math.pi / 2
            for s in range(segs):
                th = 2 * math.pi * s / segs
                v.append((math.cos(phi) * math.cos(th), math.sin(phi), math.cos(phi) * math.sin(th)))
        v.append((0, 1, 0))
        f = []
        top = len(v) - 1
        for s in range(segs):
            f.append((0, 1 + (s + 1) % segs, 1 + s))
        for r in range(rings - 2):
            for s in range(segs):
                a = 1 + r * segs + s
                b = 1 + r * segs + (s + 1) % segs
                f.append((a, b, b + segs, a + segs))
        base = 1 + (rings - 2) * segs
        for s in range(segs):
            f.append((base + s, base + (s + 1) % segs, top))
        return v, f
    raise ValueError(kind)


GEOM = {k: unit_geom(k) for k in ("block", "wedge", "cornerwedge", "cylinder", "sphere")}


def shape_of(p):
    c = p["c"]
    if c == "WedgePart":
        return "wedge", None
    if c == "CornerWedgePart":
        return "cornerwedge", None
    mesh = p.get("mesh")
    if mesh == "Sphere":
        return "sphere", None
    if mesh == "Cylinder":
        return "cylinder", None
    sh = p.get("sh")
    if sh == "Ball":
        return "sphere", "uniform"
    if sh == "Cylinder":
        return "cylinder", "cyl"
    return "block", None


def material_key(p):
    col = tuple(p["col"])
    m = p["m"]
    t = round(p.get("t", 0), 2)
    return (col, m, t)


def make_material(key):
    (r, g, b), m, t = key
    mat = bpy.data.materials.new("m_%d_%d_%d_%s_%s" % (r, g, b, m, t))
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")

    def lin(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    color = (lin(r), lin(g), lin(b), 1)
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.55 if m in ("SmoothPlastic", "Plastic") else 0.85
    if m == "Neon":
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = 2.0
    if m == "Glass":
        t = max(t, 0.4)
    if t > 0:
        bsdf.inputs["Alpha"].default_value = max(0.0, 1 - t)
    return mat


def build_scene(data):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.preferences.addon_enable(module="cycles")
    except Exception:
        pass
    sc = bpy.context.scene
    mesh = bpy.data.meshes.new("world")
    bm = bmesh.new()
    mats = {}
    mat_list = []
    skipped = 0
    for idx, p in enumerate(data["parts"]):
        t = p.get("t", 0)
        if t >= 0.98:
            skipped += 1
            continue
        kind, mode = shape_of(p)
        sx, sy, sz = p["s"]
        if mode == "uniform":
            d = min(sx, sy, sz)
            sx = sy = sz = d
        elif mode == "cyl":
            d = min(sy, sz)
            sy = sz = d
        if p.get("meshScale") and p.get("mesh") in ("Sphere", "Cylinder"):
            ms = p["meshScale"]
            sx, sy, sz = sx * ms[0], sy * ms[1], sz * ms[2]
        key = material_key(p)
        if key not in mats:
            mats[key] = len(mat_list)
            mat_list.append(make_material(key))
        mi = mats[key]
        m = part_matrix(p["cf"])
        verts_l, faces = GEOM[kind]
        bv = []
        # Roblox draws overlapping coplanar parts fine; Cycles shows black where two faces of
        # one mesh coincide, so grow each part by a tiny per-part amount (<= 0.012 studs)
        eps = 0.003 * (idx % 5)
        for (x, y, z) in verts_l:
            local = rbx_to_bl((x * (sx / 2 + eps), y * (sy / 2 + eps), z * (sz / 2 + eps)))
            bv.append(bm.verts.new(m @ local))
        for f in faces:
            try:
                face = bm.faces.new([bv[i] for i in f])
                face.material_index = mi
                face.smooth = kind in ("sphere", "cylinder")
            except ValueError:
                pass
    bm.to_mesh(mesh)
    bm.free()
    for mat in mat_list:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new("world", mesh)
    sc.collection.objects.link(obj)
    # big ground below everything (the game builds its own ground parts; this is the void)
    gmesh = bpy.data.meshes.new("void")
    gbm = bmesh.new()
    s = 5000
    vs = [gbm.verts.new((x, y, -2)) for x, y in ((-s, -s), (s, -s), (s, s), (-s, s))]
    gbm.faces.new(vs)
    gbm.to_mesh(gmesh)
    gbm.free()
    gm = bpy.data.materials.new("void")
    gm.use_nodes = True
    gm.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.18, 0.3, 0.12, 1)
    gmesh.materials.append(gm)
    gobj = bpy.data.objects.new("void", gmesh)
    sc.collection.objects.link(gobj)
    # sky + sun (Lighting ClockTime ~14 in the project file)
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.65, 0.95, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sc.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.5
    sun.angle = math.radians(3)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(40), math.radians(15), math.radians(30))
    sc.collection.objects.link(so)
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 3
    sc.render.resolution_x, sc.render.resolution_y = RES
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.render.image_settings.compression = 90
    sc.view_settings.view_transform = "Standard"
    return sc, skipped, len(mat_list)


def stamp(path, text):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return
    img = Image.open(path).convert("RGB")
    d = ImageDraw.Draw(img)
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 12)
    except OSError:
        f = ImageFont.load_default()
    w = d.textlength(text, font=f)
    d.rectangle([0, img.height - 18, w + 10, img.height], fill=(0, 0, 0))
    d.text((5, img.height - 16), text, font=f, fill=(255, 255, 0))
    img.save(path, optimize=True)


def render_cameras(sc, data):
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for c in data["cameras"]:
        pos = rbx_to_bl(c["pos"])
        look = rbx_to_bl(c["look"])
        cam.location = pos
        cam.rotation_euler = (look - pos).to_track_quat("-Z", "Y").to_euler()
        cam_data.angle = math.radians(c.get("fov", 70))
        cam_data.sensor_fit = "VERTICAL"
        cam_data.clip_end = 5000
        dest = os.path.join(OUT, c["name"] + ".png")
        sc.render.filepath = dest
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        stamp(dest, "OFFLINE RENDER of the generated layout (headless mock + Blender), not a Roblox screenshot - " + c["name"])
        print("wrote %s (%d KB, %.1fs)" % (os.path.relpath(dest, ROOT), os.path.getsize(dest) // 1024, time.time() - t0))


def main():
    global SAMPLES
    if "--samples" in sys.argv:
        SAMPLES = int(sys.argv[sys.argv.index("--samples") + 1])
    files = sorted(glob.glob(os.path.join(HERE, "out", "world_*.json")))
    if not files:
        raise SystemExit("no world_*.json dumps; run: python3 tools/headless/run.py render_dump")
    os.makedirs(OUT, exist_ok=True)
    for f in files:
        data = json.load(open(f))
        sc, skipped, nm = build_scene(data)
        print("%s: %d parts (%d invisible skipped), %d materials" % (os.path.basename(f), len(data["parts"]), skipped, nm))
        render_cameras(sc, data)


if __name__ == "__main__":
    main()
