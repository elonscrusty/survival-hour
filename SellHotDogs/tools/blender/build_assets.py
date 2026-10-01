"""Procedural low-poly asset builder for Sell Hot Dogs.

Every asset is original geometry generated from code in this file: no
downloaded models, no image textures. Colours are simple Principled BSDF
materials, also baked into a "Col" vertex-colour attribute so a single
Roblox MeshPart shows the right colours.

Usage (from the SellHotDogs/ folder):
    python3 tools/blender/build_assets.py                 # build everything
    python3 tools/blender/build_assets.py --only HotDog   # one asset (comma list ok)
    python3 tools/blender/build_assets.py --samples 8     # faster previews
    python3 tools/blender/build_assets.py --no-render     # geometry + exports only

Outputs (relative to SellHotDogs/assets/):
    blender/<Name>.blend   editable source scene
    exports/<Name>.fbx     Roblox import (1 Blender unit = 1 stud, Y up)
    exports/<Name>.obj/.mtl
    renders/<Name>.png     512x512 preview
    renders/contact_sheet.png
    exports/manifest.json  size (studs), triangles, materials per asset
"""

import argparse
import json
import math
import os
import sys
import time

import bpy  # noqa: E402  (must come before bmesh/mathutils)
import bmesh
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "assets")
DIRS = {k: os.path.join(ASSETS, k) for k in ("blender", "exports", "renders")}

TAU = math.tau
rad = math.radians

# ---------------------------------------------------------------- palette
PAL = {
    "bun": "E8B86B",
    "wood": "C98A4B",
    "wood_dark": "9C6534",
    "sausage": "B5543A",
    "sausage_dark": "8E3B26",
    "mustard": "F2C230",
    "ketchup": "D83A2E",
    "relish": "6DBE45",
    "cream": "FFF6E5",
    "teal": "3FB6C9",
    "teal_dark": "2A8797",
    "chrome": "B8C2CC",
    "tire": "34383F",
    "navy": "2E3550",
    "glass": "BFEFF7",
    "screen": "1E2A3A",
    "gold": "E8B23A",
    "stone": "EDE3CF",
    "stone_dark": "D6C8AC",
    "alien": "7FD957",
    "black": "1A1A1F",
    "void_bun": "3B1F5C",
    "void_glow": "3FE0D0",
    "violet": "9B5CFF",
    "pink": "FF9EC7",
    "mint": "9EF0C8",
    "lavender": "C3A8FF",
    "peach": "FFC79E",
    "sky": "9ED8FF",
    "window": "86D0E6",
    "kraft": "C99A62",
    "kraft_dark": "A87A45",
    "concrete": "CFCAC0",
    "concrete_dark": "A9A49A",
    "steel": "8C97A3",
    "frost": "DDF3FA",
    "leaf": "4FA33A",
    "brick": "C25B43",
}


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h):
    h = PAL.get(h, h)
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


_MATS = {}


def M(key, rough=0.6, metal=0.0, emit=0.0, transmission=0.0):
    """Get/create a material keyed by palette name (or hex)."""
    name = f"{key}" + (f"_e{emit:g}" if emit else "") + ("_glass" if transmission else "")
    if name in _MATS:
        return _MATS[name]
    rgb = hex_rgb(key)
    lin = tuple(srgb_to_lin(c) for c in rgb)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*lin, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*lin, 1)
        b.inputs["Emission Strength"].default_value = emit
    if transmission:
        b.inputs["Transmission Weight"].default_value = transmission
        b.inputs["Roughness"].default_value = 0.05
        b.inputs["IOR"].default_value = 1.2
    m.diffuse_color = (*lin, 1)
    m["hex"] = PAL.get(key, key)
    _MATS[name] = m
    return m


# ---------------------------------------------------------------- primitives
def _obj_from_bm(bm, name, mat, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), bevel=0.0, bevel_segs=3):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat is not None:
        me.materials.append(mat)
    ob.location = loc
    ob.rotation_euler = rot
    ob.scale = scale
    if bevel > 0:
        md = ob.modifiers.new("bevel", "BEVEL")
        md.width = bevel
        md.segments = bevel_segs
        md.limit_method = "ANGLE"
    return ob


def box(size, loc, mat, rot=(0, 0, 0), bevel=0.05, segs=2, name="box"):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    b = min(bevel, min(size) * 0.45)
    return _obj_from_bm(bm, name, mat, loc, rot, bevel=b, bevel_segs=segs)


def cyl(r, h, loc, mat, rot=(0, 0, 0), verts=20, r2=None, bevel=0.0, name="cyl", scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts,
                          radius1=r, radius2=r if r2 is None else r2, depth=h)
    return _obj_from_bm(bm, name, mat, loc, rot, scale, bevel=bevel, bevel_segs=2)


def sphere(r, loc, mat, scale=(1, 1, 1), segs=20, rings=10, rot=(0, 0, 0), name="sph"):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    return _obj_from_bm(bm, name, mat, loc, rot, scale)


def lathe(prof, mat, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), segs=24, closed=False,
          cap=True, name="lathe"):
    """Revolve a (radius, z) profile around Z."""
    bm = bmesh.new()
    rings = []
    for r, z in prof:
        if r < 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(TAU * i / segs), r * math.sin(TAU * i / segs), z))
                          for i in range(segs)])
    pairs = list(zip(rings, rings[1:]))
    if closed:
        pairs.append((rings[-1], rings[0]))
    for a, b in pairs:
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(segs):
            j = (i + 1) % segs
            if len(a) == 1:
                bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[i], a[j], b[0]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap and not closed:
        if len(rings[0]) > 1:
            bm.faces.new(rings[0])
        if len(rings[-1]) > 1:
            bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj_from_bm(bm, name, mat, loc, rot, scale)


def capsule(r, length, loc, mat, axis="X", scale=(1, 1, 1), segs=16, steps=5, rot=None, name="cap"):
    half = max(length / 2 - r, 0)
    prof = []
    for k in range(steps + 1):
        a = -math.pi / 2 + (math.pi / 2) * k / steps
        prof.append((r * math.cos(a), -half + r * math.sin(a)))
    for k in range(steps + 1):
        a = (math.pi / 2) * k / steps
        prof.append((r * math.cos(a), half + r * math.sin(a)))
    if rot is None:
        rot = {"X": (0, rad(90), 0), "Y": (rad(90), 0, 0), "Z": (0, 0, 0)}[axis]
    # scale is given in world axes; map onto local axes for the rotation
    if axis == "X":
        sc = (scale[2], scale[1], scale[0])
    elif axis == "Y":
        sc = (scale[0], scale[2], scale[1])
    else:
        sc = scale
    return lathe(prof, mat, loc, rot, sc, segs=segs, name=name)


def torus(R, r, loc, mat, rot=(0, 0, 0), segs=32, rsegs=10, name="torus", scale=(1, 1, 1)):
    prof = [(R + r * math.cos(TAU * k / rsegs), r * math.sin(TAU * k / rsegs)) for k in range(rsegs)]
    return lathe(prof, mat, loc, rot, scale, segs=segs, closed=True, name=name)


def tube(points, r, mat, res=6, name="tube"):
    """Round tube along a polyline (curve bevel, converted to mesh at finalize)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 1 if r < 0.1 else 2
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for p, co in zip(sp.points, points):
        p.co = (*co, 1)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    cu.materials.append(mat)
    return ob


def wedge_prism(pts2d, depth, mat, loc=(0, 0, 0), rot=(0, 0, 0), name="prism", bevel=0.0):
    """Extrude a 2D polygon (x,z) along Y by depth (centred)."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in pts2d]
    back = [bm.verts.new((x, depth / 2, z)) for x, z in pts2d]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(pts2d)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj_from_bm(bm, name, mat, loc, rot, bevel=bevel, bevel_segs=2)


def xform(objs, loc=(0, 0, 0), rot=(0, 0, 0), s=1.0):
    """Apply a group transform to already-built objects."""
    if isinstance(s, (int, float)):
        s = (s, s, s)
    T = Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*s, 1))
    bpy.context.view_layer.update()
    for o in objs:
        if o.type == "MESH":
            # bake into vertices so non-uniform group scales never lose shear
            o.data.transform(o.matrix_world)
            o.matrix_world = Matrix.Identity(4)
            o.data.transform(T)
        else:
            o.matrix_world = T @ o.matrix_world
    return objs


def track(fn):
    """Run fn and return the list of objects it created."""
    before = set(bpy.context.scene.objects)
    fn()
    return [o for o in bpy.context.scene.objects if o not in before]


# ---------------------------------------------------------------- reusable parts
def hotdog(lod=1.0, bun="bun", sausage="sausage", mustard="mustard", ketchup="ketchup",
           inner="cream", glow=0.0, bun_only=False, condiments=True):
    """Hot dog at origin: length 2 (X), width ~0.84 (Y), height ~0.75. Returns objects."""
    segs = max(8, int(16 * lod))
    steps = max(3, int(5 * lod))
    objs = []
    gap = 0.16 if bun_only else 0.2
    for side in (-1, 1):
        objs.append(capsule(0.24, 1.76, (0, side * gap, 0.36), M(bun), "X",
                            scale=(1, 0.8, 1.33), segs=segs, steps=steps,
                            rot=None, name="bun_half"))
        o = objs[-1]
        # tilt outward: rotation about world X after the capsule's own rotation
        o.rotation_euler = (Euler((rad(14) * (-side), 0, 0)).to_matrix() @ o.rotation_euler.to_matrix()).to_euler()
    objs.append(capsule(0.22, 1.72, (0, 0, 0.18), M(bun), "X", scale=(1, 1.25, 0.6),
                        segs=segs, steps=steps, name="bun_base"))
    objs.append(capsule(0.15, 1.66, (0, 0, 0.3), M(inner), "X", scale=(1, 1.5 if not bun_only else 1.1, 0.6),
                        segs=segs, steps=steps, name="bun_inner"))
    if bun_only:
        return objs
    sm = M(sausage, emit=glow) if glow else M(sausage, rough=0.45)
    objs.append(capsule(0.2, 2.0, (0, 0, 0.5), sm, "X", segs=segs, steps=steps, name="sausage"))
    if condiments:
        top = 0.5
        n = max(20, int(40 * lod))
        must = []
        ket = []
        for i in range(n + 1):
            x = -0.74 + 1.48 * i / n
            y = 0.11 * math.sin(x * math.pi * 4.2)
            must.append((x, y, top + math.sqrt(max(0.2 ** 2 - y * y, 0)) + 0.035))
            y2 = 0.03 * math.sin(x * math.pi * 2)
            ket.append((x * 0.95, y2, top + math.sqrt(max(0.2 ** 2 - y2 * y2, 0)) + 0.012))
        mm = M(mustard, emit=glow * 0.8) if glow else M(mustard, rough=0.35)
        km = M(ketchup, emit=glow * 0.8) if glow else M(ketchup, rough=0.35)
        objs.append(tube(ket, 0.03, km, name="ketchup"))
        objs.append(tube(must, 0.034, mm, name="mustard"))
    return objs


def sausage_obj(loc, rot=(0, 0, 0), s=1.0, segs=12, mat="sausage"):
    o = capsule(0.2 * s, 2.0 * s, (0, 0, 0), M(mat, rough=0.45), "X", segs=segs, steps=3, name="sausage")
    xform([o], loc, rot)
    return o


def wheel(r, w, loc, tire="tire", hub="chrome", axis="Y", segs=24):
    rot = (rad(90), 0, 0) if axis == "Y" else (0, rad(90), 0)
    objs = [torus(r - w * 0.35, w * 0.45, loc, M(tire, rough=0.8), rot=rot, segs=segs, rsegs=8, name="tire",
                  scale=(1, 1, 1.0)),
            cyl(r * 0.62, w * 0.7, loc, M(hub, metal=0.3, rough=0.4), rot=rot, verts=segs, name="hub"),
            cyl(r * 0.25, w * 0.9, loc, M("cream"), rot=rot, verts=12, name="hubcap")]
    return objs


def stripes(x0, x1, n, y, z, depth, thick, tilt, colors, name="awning"):
    """Striped awning slab: n stripes along X, sloping down toward -Y by tilt."""
    out = []
    w = (x1 - x0) / n
    for i in range(n):
        out.append(box((w + 0.002, depth, thick), (x0 + w * (i + 0.5), y, z), M(colors[i % len(colors)]),
                       rot=(rad(tilt), 0, 0), bevel=0.02, segs=1, name=name))
    return out


def scallops(x0, x1, n, y, z, r, colors, depth=0.12):
    out = []
    w = (x1 - x0) / n
    for i in range(n):
        pts = [((w / 2) * math.cos(a), -(w / 2) * math.sin(a)) for a in [math.pi * k / 8 for k in range(9)]]
        out.append(wedge_prism(pts, depth, M(colors[i % len(colors)]), loc=(x0 + w * (i + 0.5), y, z),
                               name="scallop"))
    return out


def flag(pole_loc, h, color, w=2.2, fh=1.3):
    x, y, z = pole_loc
    objs = [cyl(0.08, h, (x, y, z + h / 2), M("chrome", metal=0.4, rough=0.4), verts=10, name="pole"),
            sphere(0.16, (x, y, z + h + 0.1), M("gold", metal=0.6, rough=0.35), segs=10, rings=6)]
    pts = []
    for i in range(9):
        t = i / 8
        pts.append((t * w, 0.12 * math.sin(t * math.pi * 2)))
    bm = bmesh.new()
    top = [bm.verts.new((x + px, y + py, z + h - 0.1)) for px, py in pts]
    bot = [bm.verts.new((x + px, y + py, z + h - 0.1 - fh)) for px, py in pts]
    for i in range(8):
        bm.faces.new((bot[i], bot[i + 1], top[i + 1], top[i]))
    ob = _obj_from_bm(bm, "flag", M(color))
    sol = ob.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.06
    objs.append(ob)
    return objs


# ---------------------------------------------------------------- assets
def build_HotDog():
    hotdog(lod=1.0)


def build_VoidHotDog():
    hotdog(lod=1.0, bun="void_bun", sausage="void_glow", mustard="violet", ketchup="pink", inner="lavender",
           glow=2.5)


def build_Bun():
    hotdog(lod=1.0, bun_only=True)


def build_HotDogStand():
    red, cream = "ketchup", "cream"
    # cart body on wheels
    box((6.0, 3.2, 2.4), (0, 0, 2.2), M(red), bevel=0.15, segs=3, name="body")
    box((6.1, 3.3, 0.45), (0, 0, 2.0), M(cream), bevel=0.08, name="stripe")
    box((6.5, 3.6, 0.25), (0, 0, 3.5), M("cream"), bevel=0.08, name="counter")
    box((5.4, 0.1, 1.3), (0, -1.62, 2.5), M("mustard"), bevel=0.05, name="front_panel")
    # front panel hot dog decal
    xform(hotdog(lod=0.6), (0, -1.66, 2.25), (rad(90), 0, 0), (1.3, 1.3, 0.35))
    for x in (-1.9, 1.9):
        objs = wheel(1.0, 0.45, (x, -1.75, 1.0))
        objs = wheel(1.0, 0.45, (x, 1.75, 1.0))
    # posts
    for x in (-2.9, 2.9):
        for y in (-1.4, 1.4):
            cyl(0.09, 2.8, (x, y, 5.0), M("chrome", metal=0.4, rough=0.35), verts=10, name="post")
    # striped awning + scallops
    stripes(-3.4, 3.4, 9, -0.15, 6.45, 4.6, 0.14, 10, [red, cream])
    scallops(-3.4, 3.4, 9, -2.4, 6.02, 0.38, [red, cream])
    # roof sign (blank board for text)
    box((5.0, 0.25, 1.25), (0, 0, 7.45), M("cream"), bevel=0.06, name="sign")
    box((5.3, 0.2, 1.5), (0, 0.06, 7.45), M("teal"), bevel=0.08, name="sign_frame")
    for x in (-1.8, 1.8):
        cyl(0.06, 0.45, (x, 0.05, 6.75), M("chrome", metal=0.4), verts=8, name="sign_post")
    # side grill with sausages
    box((1.4, 2.4, 1.0), (3.75, 0, 3.0), M("tire", rough=0.7), bevel=0.06, name="grill")
    for i in range(5):
        box((1.3, 0.06, 0.06), (3.75, -0.9 + i * 0.45, 3.53), M("chrome", metal=0.6, rough=0.3), bevel=0, name="grate")
    for i, y in enumerate((-0.7, 0.0, 0.7)):
        sausage_obj((3.75, y, 3.72), (0, 0, rad(90)), s=0.55)
    box((0.2, 1.6, 0.6), (3.0, -1.4, 3.0), M("chrome", metal=0.3), bevel=0.04, name="grill_bracket")
    # condiment bottles on counter
    for x, col in ((-2.4, "mustard"), (-1.9, "ketchup")):
        lathe([(0, 0), (0.2, 0), (0.22, 0.4), (0.18, 0.6), (0.05, 0.75), (0.02, 0.85), (0, 0.85)], M(col),
              loc=(x, 0.9, 3.62), segs=14, name="bottle")
    # napkin box / hot dog on counter
    xform(hotdog(lod=0.6), (1.2, 0.6, 3.62), (0, 0, rad(10)), 0.8)


def build_CondimentStation():
    box((4.0, 2.6, 0.2), (0, 0, 1.5), M("wood"), bevel=0.06, name="top")
    box((3.8, 2.4, 0.3), (0, 0, 1.25), M("relish"), bevel=0.05, name="apron")
    for x in (-1.75, 1.75):
        for y in (-1.05, 1.05):
            box((0.2, 0.2, 1.2), (x, y, 0.6), M("wood_dark"), bevel=0.04, name="leg")
    box((3.4, 0.12, 0.12), (0, -1.05, 0.35), M("wood_dark"), bevel=0.02, name="rail")
    box((3.4, 0.12, 0.12), (0, 1.05, 0.35), M("wood_dark"), bevel=0.02, name="rail")

    def bottle(x, y, col, cap):
        prof = [(0, 0), (0.5, 0), (0.58, 0.15), (0.6, 1.2), (0.55, 1.45), (0.35, 1.65), (0.2, 1.75), (0, 1.75)]
        lathe(prof, M(col, rough=0.35), loc=(x, y, 1.6), segs=24, name="bottle")
        cyl(0.24, 0.25, (x, y, 3.45), M(cap), verts=16, name="cap")
        cyl(0.12, 0.35, (x, y, 3.75), M(cap), r2=0.03, verts=12, name="nozzle")
        box((0.7, 0.04, 0.5), (x, y - 0.6, 2.35), M("cream"), bevel=0.02, name="label")
    bottle(-1.1, 0.1, "mustard", "ketchup")
    bottle(0.3, 0.2, "ketchup", "mustard")
    # relish jar
    jx, jy = 1.45, -0.3
    lathe([(0, 0), (0.42, 0), (0.45, 0.1), (0.45, 0.9), (0.38, 1.0), (0, 1.0)], M("relish", rough=0.4),
          loc=(jx, jy, 1.6), segs=20, name="jar")
    cyl(0.4, 0.2, (jx, jy, 2.7), M("teal"), verts=20, bevel=0.03, name="lid")
    cyl(0.12, 0.12, (jx, jy, 2.85), M("cream"), verts=10, name="knob")
    box((0.5, 0.04, 0.35), (jx, jy - 0.44, 2.1), M("cream"), bevel=0.02, name="label")


def build_Bun_lod():
    return hotdog(lod=0.5, bun_only=True)


def build_BunRack():
    W, D = 3.8, 2.4
    for x in (-W / 2, W / 2):
        for y, h in ((-D / 2 + 0.1, 3.4), (D / 2 - 0.1, 4.8)):
            box((0.18, 0.18, h), (x, y, h / 2), M("wood_dark"), bevel=0.04, name="post")
        # side rails
        box((0.12, D, 0.12), (x, 0, 0.3), M("wood_dark"), bevel=0.02, name="rail")
    shelves = [(0.5, 0.35, -0.0), (1.9, 0.75, 0.25), (3.3, 0.9, 0.5)]
    shelves = [(0.45, -0.55, 0.0), (1.95, 0.0, 0.0), (3.45, 0.55, 0.0)]
    for i, (z, y, _) in enumerate(shelves):
        depth = 1.1
        box((W + 0.1, depth, 0.14), (0, y, z), M("wood"), bevel=0.04, name="shelf")
        box((W + 0.1, 0.08, 0.25), (0, y - depth / 2, z + 0.12), M("wood"), bevel=0.02, name="lip")
        for k, x in enumerate((-1.25, 0.0, 1.25)):
            for layer in range(2 if i < 2 else 1):
                xform(build_Bun_lod(), (x, y, z + 0.07 + layer * 0.55), (0, 0, rad(90 if layer else 0) * 0 + rad(4 * (k - 1))), 0.55)
    # top sign board
    box((W + 0.3, 0.16, 0.7), (0, D / 2 - 0.1, 4.6), M("ketchup"), bevel=0.05, name="sign")
    box((W - 0.3, 0.05, 0.45), (0, D / 2 - 0.2, 4.6), M("cream"), bevel=0.02, name="sign_face")


def build_CashRegister():
    # stand
    box((2.6, 2.1, 1.3), (0, 0, 0.65), M("wood"), bevel=0.08, segs=3, name="stand")
    box((2.2, 0.05, 0.8), (0, -1.06, 0.7), M("teal"), bevel=0.03, name="panel")
    box((2.8, 2.4, 0.15), (0, 0, 1.37), M("cream"), bevel=0.05, name="stand_top")
    # register body
    base_z = 1.45
    box((2.2, 1.7, 0.45), (0, 0.05, base_z + 0.22), M("ketchup"), bevel=0.06, name="drawer")
    box((1.4, 0.04, 0.12), (0, -0.82, base_z + 0.22), M("chrome", metal=0.5, rough=0.35), bevel=0.02, name="handle")
    prof = [(-1.0, 0.0), (1.0, 0.0), (1.0, 0.9), (0.2, 0.9), (-1.0, 0.25)]
    # side profile in (y, z): wedge with sloped keyboard facing -Y
    bm = bmesh.new()
    pts = [(-0.85, 0), (0.85, 0), (0.85, 1.1), (0.2, 1.1), (-0.85, 0.35)]
    left = [bm.verts.new((-1.0, y, z)) for y, z in pts]
    right = [bm.verts.new((1.0, y, z)) for y, z in pts]
    bm.faces.new(left)
    bm.faces.new(list(reversed(right)))
    for i in range(5):
        j = (i + 1) % 5
        bm.faces.new((left[i], left[j], right[j], right[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _obj_from_bm(bm, "body", M("ketchup"), (0, 0.05, base_z + 0.45), bevel=0.06, bevel_segs=2)
    # keys on slope: slope from (y=-0.8,z=0.35) to (y=0.25,z=1.1)
    ang = math.atan2(1.1 - 0.35, 0.85 + 0.2)
    for r in range(3):
        for c in range(4):
            t = (r + 0.6) / 3.6
            y = -0.8 + t * 1.05 + 0.05
            z = base_z + 0.45 + 0.35 + t * 0.75 + 0.05
            col = "cream" if (r + c) % 3 else "mustard"
            cyl(0.13, 0.12, (-0.6 + c * 0.4, y, z), M(col), rot=(-ang, 0, 0), verts=12, bevel=0.02, name="key")
    # display popup
    box((1.3, 0.5, 0.65), (0, 0.55, base_z + 1.85), M("teal"), bevel=0.06, name="display")
    box((1.0, 0.04, 0.35), (0, 0.29, base_z + 1.88), M("cream", emit=0.4), bevel=0.01, name="display_face")
    # crank
    cyl(0.12, 0.2, (1.1, 0.2, base_z + 0.9), M("chrome", metal=0.5), rot=(0, rad(90), 0), verts=12)
    tube([(1.2, 0.2, base_z + 0.9), (1.25, 0.2, base_z + 0.5), (1.4, 0.2, base_z + 0.5)], 0.05,
         M("chrome", metal=0.5, rough=0.35), name="crank")
    sphere(0.1, (1.45, 0.2, base_z + 0.5), M("ketchup"), segs=10, rings=6)
    # bell on top
    bz = base_z + 2.18
    cyl(0.25, 0.1, (-0.0, 0.55, bz), M("wood_dark"), verts=16, name="bell_base")
    lathe([(0.32, 0), (0.3, 0.06), (0.22, 0.18), (0.12, 0.3), (0, 0.33)], M("gold", metal=0.8, rough=0.3),
          loc=(0, 0.55, bz + 0.05), segs=20, name="bell")
    cyl(0.04, 0.1, (0, 0.55, bz + 0.42), M("chrome", metal=0.6), verts=8)
    sphere(0.07, (0, 0.55, bz + 0.5), M("chrome", metal=0.6, rough=0.3), segs=10, rings=6)


def build_Billboard():
    # posts
    for x in (-3.6, 3.6):
        box((0.6, 0.6, 6.5), (x, 0.3, 3.25), M("wood_dark"), bevel=0.06, name="post")
        box((0.9, 0.9, 0.4), (x, 0.3, 0.2), M("stone_dark"), bevel=0.06, name="footing")
    box((8.0, 0.25, 0.25), (0, 0.3, 4.2), M("wood_dark"), bevel=0.03, name="brace")
    # catwalk
    box((11.0, 0.8, 0.12), (0, -0.2, 5.75), M("chrome", metal=0.3, rough=0.5), bevel=0.02, name="catwalk")
    for i in range(12):
        cyl(0.03, 0.6, (-5.2 + i * 0.945, -0.55, 6.1), M("chrome", metal=0.4), verts=6, name="rail_post")
    box((11.0, 0.05, 0.05), (0, -0.55, 6.42), M("chrome", metal=0.4), bevel=0, name="rail")
    # board
    box((12.0, 0.4, 6.0), (0, 0.4, 8.95), M("teal"), bevel=0.1, segs=3, name="frame")
    box((11.3, 0.1, 5.3), (0, 0.17, 8.95), M("cream"), bevel=0.04, name="face")
    # text area (flat, lighter mustard panel) on the right
    box((5.2, 0.06, 3.8), (2.75, 0.09, 8.95), M("mustard"), bevel=0.03, name="text_area")
    # big hot dog on the left, facing -Y
    xform(hotdog(lod=0.8), (-2.9, 0.08, 8.9), (rad(90), rad(20), 0), (2.6, 2.6, 0.5))
    # lamps
    for x in (-3.5, 0, 3.5):
        tube([(x, -0.3, 5.9), (x, -0.55, 6.6), (x, -0.62, 6.6)], 0.05, M("chrome", metal=0.4), name="lamp_arm")
        cyl(0.18, 0.25, (x, -0.62, 6.5), M("tire"), r2=0.1, verts=12, name="lamp")
    # top trim bulbs
    for i in range(13):
        sphere(0.12, (-5.6 + i * (11.2 / 12), 0.4, 12.0), M("mustard", emit=1.0), segs=8, rings=5)


def build_IngredientRack():
    W, D, H = 5.6, 2.4, 4.6
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            box((0.22, 0.22, H), (x, y, H / 2), M("wood_dark"), bevel=0.05, name="post")
    for z in (0.35, 2.15):
        box((W + 0.2, D + 0.1, 0.16), (0, 0, z), M("wood"), bevel=0.04, name="shelf")
    box((W, 0.1, H - 0.4), (0, D / 2, H / 2 + 0.1), M("wood"), bevel=0.02, name="back")
    # awning on top
    stripes(-W / 2 - 0.3, W / 2 + 0.3, 8, -0.1, H + 0.45, D + 0.5, 0.12, 14, ["teal", "cream"])
    scallops(-W / 2 - 0.3, W / 2 + 0.3, 8, -D / 2 - 0.42, H + 0.08, 0.3, ["teal", "cream"])
    box((W - 0.6, 0.15, 0.8), (0, D / 2 - 0.1, H + 1.1), M("mustard"), bevel=0.05, name="sign")

    def crate(cx, cy, cz, content):
        cw, cd, ch = 1.5, 1.6, 0.8
        box((cw, cd, 0.08), (cx, cy, cz + 0.04), M("wood"), bevel=0.02, name="crate_floor")
        for sx in (-1, 1):
            box((0.08, cd, ch), (cx + sx * cw / 2, cy, cz + ch / 2), M("wood"), bevel=0.02, name="crate_side")
        for sy in (-1, 1):
            for k in range(2):
                box((cw, 0.08, 0.3), (cx, cy + sy * cd / 2, cz + 0.2 + k * 0.4), M("wood_dark" if k else "wood"),
                    bevel=0.02, name="crate_slat")
        if content == "sausage":
            for row in range(2):
                for i in range(4):
                    sausage_obj((cx, cy - 0.55 + i * 0.37, cz + 0.35 + row * 0.3),
                                (0, 0, 0), s=0.65, segs=8)
        else:
            for i in range(3):
                xform(hotdog(lod=0.4, bun_only=True), (cx, cy - 0.5 + i * 0.5, cz + 0.2), (0, 0, 0), 0.62)
    crate(-1.7, -0.1, 0.43, "sausage")
    crate(0.0, -0.1, 0.43, "bun")
    crate(1.7, -0.1, 0.43, "sausage")
    crate(-0.9, -0.1, 2.23, "bun")
    crate(0.9, -0.1, 2.23, "sausage")


def build_IngredientCrate():
    cw, cd, ch = 1.5, 1.5, 0.9
    box((cw, cd, 0.1), (0, 0, 0.05), M("wood"), bevel=0.02, name="floor")
    for sx in (-1, 1):
        for k in range(3):
            box((0.1, cd, 0.24), (sx * (cw / 2 - 0.05), 0, 0.17 + k * 0.3), M("wood" if k % 2 == 0 else "wood_dark"),
                bevel=0.025, name="slat")
            box((cw, 0.1, 0.24), (0, sx * (cd / 2 - 0.05), 0.17 + k * 0.3), M("wood" if k % 2 == 0 else "wood_dark"),
                bevel=0.025, name="slat")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.16, 0.16, ch), (sx * (cw / 2 - 0.06), sy * (cd / 2 - 0.06), ch / 2), M("wood_dark"), bevel=0.03,
                name="corner")
    for row, z in enumerate((0.5, 0.8)):
        n = 5 if row == 0 else 4
        for i in range(n):
            y = -0.52 + i * (1.04 / (n - 1))
            sausage_obj((0.0 + (0.06 if row else 0), y, z), (0, rad(4 * (i % 2)), rad((i * 7) % 11 - 5)), s=0.62,
                        segs=9)
    sausage_obj((0.05, 0.05, 1.03), (0, 0, rad(70)), s=0.62, segs=9)


def build_DeliveryBike():
    body, trim = "teal", "cream"
    for x in (-1.65, 1.75):
        wheel(0.7, 0.36, (x, 0, 0.7))
    # floorboard & rear body
    box((1.7, 0.85, 0.24), (0.1, 0, 0.85), M(body), bevel=0.08, segs=3, name="floor")
    capsule(0.6, 2.1, (-1.1, 0, 1.4), M(body), "X", scale=(1, 0.8, 0.8), segs=16, name="rear_body")
    capsule(0.32, 1.4, (-0.75, 0, 1.95), M("tire", rough=0.7), "X", scale=(1, 1.0, 0.45), segs=12, name="seat")
    # front shield
    box((0.3, 0.95, 1.7), (1.15, 0, 1.7), M(body), rot=(0, rad(-18), 0), bevel=0.12, segs=3, name="shield")
    capsule(0.34, 1.0, (1.65, 0, 1.08), M(body), "X", scale=(1, 0.8, 0.6), segs=12, name="mudguard")
    # fork + handlebar
    chrome = M("chrome", metal=0.5, rough=0.35)
    tube([(1.75, 0, 0.7), (1.5, 0, 1.9), (1.4, 0, 2.75)], 0.07, chrome, name="fork")
    tube([(1.4, -0.75, 2.85), (1.4, 0.75, 2.85)], 0.07, chrome, name="bar")
    for y in (-0.78, 0.78):
        cyl(0.09, 0.28, (1.4, y, 2.85), M("tire"), rot=(rad(90), 0, 0), verts=10, name="grip")
    for y in (-0.55, 0.55):
        tube([(1.4, y, 2.85), (1.35, y * 1.25, 3.3)], 0.03, chrome, name="mirror_stem")
        sphere(0.15, (1.35, y * 1.25, 3.38), chrome, scale=(0.4, 1, 0.8), segs=10, rings=6, name="mirror")
    sphere(0.24, (1.58, 0, 2.6), M(trim, emit=0.5), scale=(0.6, 1, 1), segs=14, rings=8, name="headlight")
    capsule(0.22, 0.7, (1.47, 0, 2.65), M(body), "Y", segs=12, name="headset")
    # rear rack + delivery box topped by a hot dog
    box((1.4, 1.0, 0.08), (-1.6, 0, 2.0), chrome, bevel=0.02, name="rack")
    box((1.5, 1.45, 1.05), (-1.6, 0, 2.58), M("ketchup"), bevel=0.12, segs=3, name="delivery_box")
    box((1.2, 0.04, 0.55), (-1.6, -0.74, 2.58), M("cream"), bevel=0.03, name="box_label")
    xform(hotdog(lod=0.7), (-1.6, 0, 3.08), (0, 0, 0), (0.95, 1.6, 1.3))


def build_DeliveryVan():
    body = "teal"
    L, Wd = 11.0, 5.4
    box((L, Wd, 3.9), (0, 0, 3.15), M(body), bevel=0.5, segs=4, name="body")
    box((L * 0.98, Wd + 0.04, 0.5), (0, 0, 2.0), M("cream"), bevel=0.15, name="belt")
    # cab bonnet slant
    box((2.0, Wd - 0.2, 1.6), (4.8, 0, 1.95), M(body), bevel=0.4, segs=3, name="nose")
    # windshield & windows
    box((0.25, Wd - 0.9, 1.5), (5.38, 0, 4.0), M("screen", rough=0.2), rot=(0, rad(-12), 0), bevel=0.1, name="windshield")
    for y in (-Wd / 2, Wd / 2):
        box((2.0, 0.1, 1.3), (3.8, y, 4.1), M("screen", rough=0.2), bevel=0.08, name="side_window")
        box((5.5, 0.1, 1.9), (-1.6, y, 3.6), M("cream"), bevel=0.1, name="side_panel")
    # hot dog decal on the side panel facing -Y
    xform(hotdog(lod=0.6), (-1.6, -Wd / 2 - 0.05, 3.0), (rad(90), 0, 0), (2.2, 2.2, 0.3))
    # bumpers & lights
    box((0.4, Wd, 0.5), (5.85, 0, 1.2), M("chrome", metal=0.4, rough=0.4), bevel=0.15, name="bumper")
    box((0.4, Wd, 0.5), (-5.55, 0, 1.2), M("chrome", metal=0.4, rough=0.4), bevel=0.15, name="bumper")
    for y in (-1.9, 1.9):
        sphere(0.35, (5.8, y, 2.15), M("cream", emit=0.6), scale=(0.5, 1, 1), segs=14, rings=8, name="headlight")
        box((0.15, 0.5, 0.5), (-5.55, y, 2.3), M("ketchup", emit=0.3), bevel=0.05, name="taillight")
    box((0.12, 2.4, 0.6), (5.85, 0, 1.85), M("tire"), bevel=0.05, name="grille")
    for x in (-3.4, 3.4):
        for y in (-Wd / 2 + 0.25, Wd / 2 - 0.25):
            wheel(1.15, 0.7, (x, y, 1.15))
    # roof rack + giant hot dog
    for x in (-3, 0, 3):
        box((0.25, Wd - 0.6, 0.25), (x, 0, 5.2), M("chrome", metal=0.4), bevel=0.05, name="roof_bar")
        for y in (-1.6, 1.6):
            box((0.2, 0.2, 0.3), (x, y, 5.15), M("chrome", metal=0.4), bevel=0.03, name="roof_foot")
    xform(hotdog(lod=1.0), (0, 0, 5.32), (0, 0, 0), 4.6)


def build_DepotTruck():
    Wd = 6.6
    # chassis
    box((15.0, 4.5, 0.7), (0, 0, 1.3), M("tire", rough=0.7), bevel=0.1, name="chassis")
    # cargo box
    box((10.6, Wd, 7.2), (-2.4, 0, 5.75), M("cream"), bevel=0.3, segs=3, name="cargo")
    box((10.7, Wd + 0.06, 0.6), (-2.4, 0, 2.6), M("ketchup"), bevel=0.1, name="cargo_stripe")
    box((10.7, Wd + 0.06, 0.4), (-2.4, 0, 9.0), M("ketchup"), bevel=0.1, name="cargo_stripe_top")
    for y in (-Wd / 2 - 0.02, Wd / 2 + 0.02):
        box((6.8, 0.06, 4.0), (-2.4, y, 5.7), M("mustard"), bevel=0.05, name="logo_panel")
    xform(hotdog(lod=0.7), (-2.4, -Wd / 2 - 0.04, 4.6), (rad(90), 0, 0), (3.0, 3.0, 0.25))
    # rear door lines
    for y in (-1.6, 1.6):
        box((0.06, 0.1, 6.6), (-7.72, y * 0.0 + y * 0.01, 5.7), M("chrome"), bevel=0, name="door_line")
    box((0.08, 0.3, 6.6), (-7.72, 0, 5.7), M("chrome", metal=0.3), bevel=0.02, name="door_seam")
    # cab
    box((3.8, Wd - 0.2, 4.6), (5.4, 0, 4.0), M("teal"), bevel=0.45, segs=3, name="cab")
    box((1.6, Wd - 0.4, 1.8), (6.9, 0, 2.3), M("teal"), bevel=0.35, segs=3, name="hood")
    box((0.2, Wd - 1.0, 1.6), (7.27, 0, 4.9), M("screen", rough=0.2), rot=(0, rad(-8), 0), bevel=0.08, name="windshield")
    for y in (-(Wd - 0.2) / 2, (Wd - 0.2) / 2):
        box((2.0, 0.1, 1.5), (5.4, y, 5.0), M("screen", rough=0.2), bevel=0.08, name="side_window")
        box((0.15, 0.4, 0.4), (7.2, y * 1.03, 4.4), M("tire"), bevel=0.04, name="mirror")
    box((0.4, Wd - 0.2, 0.6), (7.75, 0, 1.6), M("chrome", metal=0.4, rough=0.35), bevel=0.15, name="bumper")
    for y in (-2.2, 2.2):
        sphere(0.35, (7.7, y, 2.6), M("cream", emit=0.6), scale=(0.5, 1, 1), segs=14, rings=8, name="headlight")
    box((0.1, 2.6, 1.0), (7.73, 0, 2.6), M("tire"), bevel=0.05, name="grille")
    for x in (-5.6, -3.4, 5.3):
        for y in (-Wd / 2 + 0.55, Wd / 2 - 0.55):
            wheel(1.2, 0.85, (x, y, 1.2))


def build_TradingTicker():
    # base kiosk
    box((8.0, 2.8, 2.6), (0, 0, 1.3), M("teal"), bevel=0.15, segs=3, name="base")
    box((8.2, 3.0, 0.2), (0, 0, 2.7), M("cream"), bevel=0.06, name="counter")
    box((7.4, 0.08, 0.4), (0, -1.42, 1.6), M("mustard", emit=0.6), bevel=0.02, name="ticker_strip")
    for i in range(10):
        box((0.35, 0.06, 0.2), (-3.3 + i * 0.73, -1.47, 1.6), M("relish" if i % 3 else "ketchup", emit=0.8),
            bevel=0, name="ticker_mark")
    # pillars + board
    for x in (-3.6, 3.6):
        box((0.4, 0.4, 5.6), (x, 0.6, 5.5), M("chrome", metal=0.4, rough=0.4), bevel=0.08, name="pillar")
    box((7.8, 0.5, 4.6), (0, 0.6, 5.9), M("navy"), bevel=0.15, segs=3, name="board")
    box((7.2, 0.05, 4.0), (0, 0.33, 5.9), M("screen", rough=0.3), bevel=0.02, name="screen")
    for i in range(5):
        box((7.0, 0.02, 0.03), (0, 0.3, 4.2 + i * 0.85), M("teal_dark"), bevel=0, name="grid")
    # chart line rising left to right, ending in a hot dog arrow
    pts = [(-3.2, 0.25, 4.4), (-2.2, 0.25, 5.0), (-1.4, 0.25, 4.6), (-0.4, 0.25, 5.6), (0.4, 0.25, 5.2),
           (1.4, 0.25, 6.6)]
    tube(pts, 0.12, M("relish", emit=0.8), name="chart")
    ang = math.atan2(6.6 - 5.2, 1.4 - 0.4)
    xform(hotdog(lod=0.7), (2.15, 0.15, 6.55), (rad(90), -ang, 0), 1.05)
    cyl(0.5, 0.8, (3.0, 0.2, 8.1), M("relish", emit=0.8), r2=0.0, rot=(0, rad(90) - ang, 0), verts=12,
        name="arrow_head")
    # roof canopy
    box((8.2, 3.0, 0.35), (0, 0.0, 8.6), M("ketchup"), bevel=0.12, segs=3, name="roof")
    box((7.8, 0.1, 0.4), (0, -1.52, 8.6), M("cream"), bevel=0.03, name="roof_trim")


def build_LabMachine():
    # cabinet
    box((5.6, 3.6, 2.6), (0, 0, 1.3), M("cream"), bevel=0.2, segs=3, name="cabinet")
    box((5.7, 3.7, 0.3), (0, 0, 2.7), M("teal"), bevel=0.1, name="top_band")
    box((2.2, 0.06, 1.4), (-1.3, -1.82, 1.3), M("teal_dark"), bevel=0.03, name="panel")
    for i in range(3):
        cyl(0.17, 0.15, (-1.9 + i * 0.6, -1.88, 1.6), M(("ketchup", "mustard", "relish")[i]), rot=(rad(90), 0, 0),
            verts=12, bevel=0.03, name="button")
        cyl(0.12, 0.2, (-1.9 + i * 0.6, -1.9, 1.0), M("chrome", metal=0.5), rot=(rad(90), 0, 0), verts=10,
            name="knob")
    box((1.6, 0.06, 0.9), (1.3, -1.82, 1.6), M("screen", emit=0.0), bevel=0.03, name="gauge_bg")
    tube([(0.7, -1.87, 1.4), (1.0, -1.87, 1.8), (1.3, -1.87, 1.5), (1.6, -1.87, 1.9), (1.9, -1.87, 1.7)], 0.04,
         M("relish", emit=1.5), name="wave")
    # dome with hot dog inside
    cyl(1.25, 0.35, (-0.9, 0.2, 3.02), M("chrome", metal=0.5, rough=0.35), verts=24, bevel=0.05, name="dome_base")
    cyl(0.35, 0.3, (-0.9, 0.2, 3.3), M("teal"), verts=16, name="pedestal")
    xform(hotdog(lod=0.8), (-0.9, 0.2, 3.45), (0, 0, rad(-20)), 0.95)
    prof = [(1.15, 0)] + [(1.15 * math.cos(a), 1.3 * math.sin(a)) for a in [rad(d) for d in range(10, 91, 10)]]
    prof[-1] = (0, 1.3)
    lathe(prof, M("glass", transmission=1.0), loc=(-0.9, 0.2, 3.19), segs=28, cap=False, name="dome")
    sphere(0.14, (-0.9, 0.2, 4.55), M("ketchup"), segs=10, rings=6, name="dome_knob")
    # flask with bubbling liquid
    fx, fy = 1.7, 0.6
    flask = [(0, 0), (0.85, 0), (0.95, 0.1), (0.9, 0.35), (0.3, 1.4), (0.25, 2.2), (0.32, 2.3), (0.0, 2.3)]
    lathe(flask, M("glass", transmission=1.0), loc=(fx, fy, 2.85), segs=24, name="flask")
    liquid = [(0, 0.05), (0.8, 0.05), (0.85, 0.35), (0.55, 0.85), (0, 0.85)]
    lathe(liquid, M("relish", emit=1.2), loc=(fx, fy, 2.85), segs=24, name="liquid")
    for i, (dx, dz, r) in enumerate(((0.0, 3.95, 0.12), (0.12, 4.4, 0.09), (-0.08, 5.6, 0.14), (0.1, 6.1, 0.1),
                                     (-0.05, 6.55, 0.08))):
        sphere(r, (fx + dx, fy, dz), M("mint", emit=0.8), segs=10, rings=6, name="bubble")
    # coil tube from flask top to dome
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((fx - 0.0 - t * 1.6, fy + 0.6 * math.sin(t * math.pi * 3) * (1 - t), 5.2 + 0.4 * math.sin(t * math.pi)
                    - t * 0.6))
    tube(pts, 0.08, M("teal", rough=0.3), name="coil")
    # side antenna/chimney
    cyl(0.25, 1.6, (2.2, -1.2, 3.6), M("chrome", metal=0.5, rough=0.35), verts=14, name="chimney")
    sphere(0.3, (2.2, -1.2, 4.5), M("mustard", emit=0.8), segs=12, rings=8, name="lamp")


def build_KitchenRobot():
    body, trim = "cream", "teal"
    # base
    cyl(1.1, 0.5, (0, 0, 0.35), M("tire", rough=0.7), verts=24, bevel=0.1, name="base")
    cyl(0.9, 0.4, (0, 0, 0.75), M(trim), verts=24, bevel=0.08, name="base_ring")
    # body egg
    egg = [(0, 0)] + [(1.3 * math.sin(math.pi * k / 12) * (1 - 0.18 * k / 12), 2.6 * (1 - math.cos(math.pi * k / 12)) / 2)
                      for k in range(1, 12)] + [(0, 2.6)]
    lathe(egg, M(body), loc=(0, 0, 0.85), segs=24, name="body")
    box((1.1, 0.1, 0.8), (0, -1.22, 2.2), M(trim), rot=(rad(-8), 0, 0), bevel=0.06, name="chest_panel")
    sphere(0.16, (0, -1.3, 2.25), M("ketchup", emit=0.8), segs=12, rings=6, name="heart")
    # neck + head
    cyl(0.3, 0.4, (0, 0, 3.55), M("chrome", metal=0.5, rough=0.35), verts=14, name="neck")
    sphere(1.0, (0, 0, 4.5), M(body), scale=(1.1, 1.0, 0.9), segs=24, rings=12, name="head")
    box((1.5, 0.3, 0.6), (0, -0.88, 4.55), M("navy", rough=0.25), bevel=0.15, segs=3, name="visor")
    for x in (-0.38, 0.38):
        sphere(0.14, (x, -1.04, 4.6), M("void_glow", emit=2.0), scale=(1, 0.5, 1.2), segs=12, rings=6, name="eye")
    torus(0.18, 0.04, (0, -0.96, 4.12), M("ketchup"), rot=(rad(90), 0, 0), segs=12, rsegs=6, name="smile",
          scale=(1, 0.6, 1))
    # chef hat
    cyl(0.55, 0.5, (0, 0.1, 5.4), M("cream"), verts=20, name="hat_band")
    for dx, dy in ((0, 0), (0.35, 0.1), (-0.35, 0.1), (0, 0.4)):
        sphere(0.45, (dx, 0.1 + dy * 0.5, 5.9), M("cream"), segs=14, rings=8, name="hat_puff")
    # antenna
    tube([(0.7, 0.2, 5.0), (1.0, 0.3, 5.9)], 0.04, M("chrome", metal=0.5), name="antenna")
    sphere(0.14, (1.0, 0.3, 5.95), M("mustard", emit=1.0), segs=10, rings=6)
    # arms
    for side in (-1, 1):
        sphere(0.3, (side * 1.25, 0, 2.6), M(trim), segs=14, rings=8, name="shoulder")
        tube([(side * 1.3, 0, 2.6), (side * 1.75, -0.2, 2.1), (side * 1.7, -0.7, 2.3)], 0.13,
             M("chrome", metal=0.5, rough=0.35), name="arm")
        sphere(0.24, (side * 1.7, -0.75, 2.3), M(trim), segs=12, rings=8, name="hand")
    # spatula (right hand, +X)
    tube([(1.7, -0.75, 2.3), (1.7, -0.9, 3.4)], 0.06, M("wood_dark"), name="spatula_handle")
    box((0.55, 0.06, 0.65), (1.7, -0.93, 3.7), M("chrome", metal=0.6, rough=0.3), bevel=0.04, name="spatula_blade")
    # hot dog (left hand)
    xform(hotdog(lod=0.6), (-1.7, -1.0, 2.35), (0, 0, rad(70)), 0.75)


def build_RepublicMonument():
    steps = [(14.0, 1.0), (11.5, 1.0), (9.0, 1.0)]
    z = 0
    for i, (w, h) in enumerate(steps):
        box((w, w, h), (0, 0, z + h / 2), M("stone" if i % 2 == 0 else "stone_dark"), bevel=0.1, name="step")
        z += h
    box((5.2, 5.2, 4.2), (0, 0, z + 2.1), M("stone"), bevel=0.15, segs=3, name="pedestal")
    box((5.4, 5.4, 0.4), (0, 0, z + 4.3), M("gold", metal=0.6, rough=0.35), bevel=0.08, name="cornice")
    box((3.6, 0.1, 1.4), (0, -2.62, z + 2.1), M("gold", metal=0.6, rough=0.35), bevel=0.04, name="plaque")
    top = z + 4.5
    # upright hot dog statue
    xform(hotdog(lod=1.2), (0, 0, top + 7.5), (0, rad(-90), rad(-30)), 7.2)
    cyl(1.6, 0.4, (0, 0, top + 0.2), M("gold", metal=0.6, rough=0.35), verts=24, name="statue_foot")
    # flags at the corners of the second step
    for x in (-5.0, 5.0):
        for y in (-5.0, 5.0):
            flag((x, y, 2.0), 10.0, "ketchup" if (x > 0) == (y > 0) else "mustard", w=2.8, fh=1.8)
    # urns of relish bushes on the third step
    for x in (-3.5, 3.5):
        cyl(0.5, 0.6, (x, -3.5, 3.3), M("stone_dark"), r2=0.35, verts=14, name="urn")
        sphere(0.6, (x, -3.5, 4.0), M("relish"), segs=12, rings=8, name="bush")


def build_HotDogRocket():
    hotdog_rocket()


def hotdog_rocket():
    """The HotDogX rocket on its round pad (shared by HotDogRocket and LaunchSite)."""
    # launch pad
    cyl(5.0, 0.8, (0, 0, 0.4), M("chrome", metal=0.2, rough=0.6), verts=8, bevel=0.15, name="pad")
    cyl(3.8, 0.12, (0, 0, 0.86), M("mustard"), verts=8, name="pad_ring")
    cyl(3.2, 0.14, (0, 0, 0.9), M("tire"), verts=8, name="pad_inner")
    for i in range(4):
        a = TAU * i / 4 + TAU / 8
        box((0.6, 0.6, 4.5), (4.0 * math.cos(a), 4.0 * math.sin(a), 3.0), M("ketchup"), rot=(0, 0, a), bevel=0.08,
            name="clamp_tower")
        tube([(4.0 * math.cos(a), 4.0 * math.sin(a), 4.8), (2.0 * math.cos(a), 2.0 * math.sin(a), 5.0)], 0.12,
             M("chrome", metal=0.5, rough=0.35), name="clamp_arm")
    # rocket: sausage body standing up with bun boosters
    base = 2.6
    sausage_len = 26.0
    lathe([(0, 0), (1.9, 0)] + [(1.9, z) for z in (2.0, 16.0)] +
          [(1.9 * math.cos(a), 16.0 + (sausage_len - 16.0) * math.sin(a)) for a in [rad(d) for d in range(10, 91, 10)]],
          M("sausage", rough=0.45), loc=(0, 0, base), segs=28, name="rocket_body")
    for side in (-1, 1):
        capsule(1.15, 14.0, (side * 2.3, 0, base + 6.0), M("bun"), "Z", scale=(0.8, 1.05, 1.0), segs=20,
                name="booster")
        cyl(0.7, 1.0, (side * 2.3, 0, base - 1.1 + 0.15), M("chrome", metal=0.6, rough=0.3), r2=0.45, verts=16,
            name="booster_nozzle")
    cyl(1.3, 1.4, (0, 0, base - 0.7), M("chrome", metal=0.6, rough=0.3), r2=1.0, verts=20, name="nozzle")
    # mustard spiral
    pts = []
    for i in range(121):
        t = i / 120
        a = t * TAU * 3.5
        r = 1.95
        pts.append((r * math.cos(a), r * math.sin(a), base + 3.0 + t * 15.0))
    tube(pts, 0.16, M("mustard", rough=0.35), name="mustard_spiral")
    # portholes
    for k, zz in enumerate((19.0, 15.5)):
        torus(0.55, 0.14, (0, -1.85, base + zz), M("chrome", metal=0.6, rough=0.3), rot=(rad(90), 0, 0), segs=20,
              rsegs=8, name="porthole")
        cyl(0.5, 0.12, (0, -1.83, base + zz), M("teal", rough=0.2), rot=(rad(90), 0, 0), verts=20, name="glass")
    # fins
    for i in range(3):
        a = TAU * i / 3 + rad(90)
        fin = wedge_prism([(0, 0), (2.4, -1.2), (2.4, 0.4), (0, 4.0)], 0.3, M("ketchup"), bevel=0.06, name="fin")
        fin.location = (1.6 * math.cos(a), 1.6 * math.sin(a), base + 0.6)
        fin.rotation_euler = (0, 0, a)
    # HotDogX band
    cyl(1.98, 1.0, (0, 0, base + 11.5), M("cream"), verts=28, name="band")


def build_Staircase():
    cols = ["pink", "mint", "lavender", "peach", "sky"]
    n = 20
    rise = 19.0 / n
    for i in range(n):
        a = i * rad(24)
        z = i * rise + 0.2
        r = 3.45
        box((5.0, 1.8, 0.45), (r * math.cos(a), r * math.sin(a), z), M(cols[i % 5], emit=0.35, rough=0.4),
            rot=(0, 0, a), bevel=0.12, segs=3, name="step")
        sphere(0.14, (5.95 * math.cos(a), 5.95 * math.sin(a), z + 0.3), M("cream", emit=1.5), segs=10, rings=6,
               name="step_light")
    # central glowing spine (floating, broken into rings)
    cyl(0.85, 19.6, (0, 0, 9.9), M("lavender", emit=0.5, rough=0.3), verts=20, name="spine")
    for k in range(6):
        torus(1.15, 0.14, (0, 0, 1.5 + k * 3.4), M("void_glow", emit=1.5), segs=24, rsegs=6, name="spine_ring")
    # outer rail
    pts = []
    for i in range(161):
        t = i / 160 * (n - 1)
        a = t * rad(24)
        pts.append((5.9 * math.cos(a), 5.9 * math.sin(a), t * rise + 1.4))
    tube(pts, 0.09, M("cream", emit=0.5), name="rail")
    for i in range(0, n, 2):
        a = i * rad(24)
        z = i * rise + 0.2
        tube([(5.9 * math.cos(a), 5.9 * math.sin(a), z + 0.15), (5.9 * math.cos(a), 5.9 * math.sin(a), z + 1.2)],
             0.05, M("cream", emit=0.5), name="baluster")


def build_CosmicPortal():
    # base steps
    box((14.0, 3.0, 0.6), (0, 0, 0.3), M("navy"), bevel=0.1, name="base")
    box((10.0, 2.4, 0.5), (0, 0, 0.85), M("lavender"), bevel=0.1, name="base2")
    R = 5.9
    cz = 1.1 + R + 0.7
    rot = (rad(90), 0, 0)
    torus(R, 0.75, (0, 0, cz), M("navy", rough=0.4), rot=rot, segs=48, rsegs=12, name="ring")
    torus(R - 0.75, 0.18, (0, -0.35, cz), M("void_glow", emit=3.0), rot=rot, segs=48, rsegs=6, name="inner_glow")
    torus(R + 0.72, 0.12, (0, -0.25, cz), M("violet", emit=2.0), rot=rot, segs=48, rsegs=6, name="outer_glow")
    # swirling disc: concentric rings alternating violet/teal
    nring = 7
    for k in range(nring):
        r0 = (R - 0.8) * k / nring
        r1 = (R - 0.8) * (k + 1) / nring
        col = "violet" if k % 2 == 0 else "teal"
        lathe([(r0, 0), (r1, 0)], M(col, emit=1.2 + 0.2 * k), loc=(0, 0.02 * k, cz), rot=rot, segs=48, cap=False,
              name="disc")
    # spiral arms in front of the disc
    for arm in range(3):
        pts = []
        for i in range(50):
            t = i / 49
            a = arm * TAU / 3 + t * TAU * 0.9
            r = 0.3 + t * (R - 1.2)
            pts.append((r * math.cos(a), -0.2 - 0.1 * (1 - t), cz + r * math.sin(a)))
        tube(pts, 0.12, M("cream", emit=2.0), name="swirl")
    # rune studs around the ring
    for i in range(12):
        a = TAU * i / 12
        sphere(0.28, (R * math.cos(a), -0.7, cz + R * math.sin(a)), M("mustard" if i % 3 == 0 else "void_glow",
               emit=2.0), segs=10, rings=6, name="rune")
    # side pylons
    for x in (-6.4, 6.4):
        box((0.9, 1.2, 2.6), (x, 0, 1.9), M("lavender"), bevel=0.15, name="pylon")
        sphere(0.4, (x, 0, 3.6), M("void_glow", emit=2.0), segs=12, rings=8, name="pylon_orb")


def build_AlienInvestor():
    suit, skin = "navy", "alien"
    # legs + shoes
    for x in (-0.32, 0.32):
        cyl(0.22, 1.3, (x, 0, 0.95), M(suit), verts=14, name="leg")
        capsule(0.2, 0.9, (x, -0.2, 0.17), M("black", rough=0.3), "Y", scale=(1, 1, 0.8), segs=12, name="shoe")
    # torso (jacket)
    lathe([(0, 0), (0.75, 0), (0.85, 0.3), (0.8, 1.1), (0.55, 1.5), (0.0, 1.55)], M(suit), loc=(0, 0, 1.5),
          scale=(1, 0.9, 1), segs=20, name="torso")
    # shirt + tie
    wedge_prism([(-0.3, 1.45), (0.3, 1.45), (0, 0.6)], 0.05, M("cream"), loc=(0, -0.72, 1.5), name="shirt")
    wedge_prism([(-0.09, 1.38), (0.09, 1.38), (0.12, 0.9), (0, 0.72), (-0.12, 0.9)], 0.05, M("ketchup"),
                loc=(0, -0.76, 1.5), name="tie")
    sphere(0.08, (0.4, -0.7, 2.6), M("mustard"), segs=8, rings=5, name="pin")
    # neck + head
    cyl(0.2, 0.3, (0, 0, 3.1), M(skin), verts=12, name="neck")
    sphere(0.8, (0, 0, 3.8), M(skin), scale=(1.15, 1.08, 0.95), segs=24, rings=14, name="head")
    for x in (-0.33, 0.33):
        sphere(0.25, (x, -0.7, 3.87), M("black", rough=0.15), scale=(0.9, 0.55, 1.25), rot=(0, 0, rad(-20 if x < 0 else 20)),
               segs=14, rings=8, name="eye")
        sphere(0.07, (x + 0.06, -0.84, 4.0), M("cream", emit=0.5), segs=8, rings=5, name="eye_glint")
    torus(0.15, 0.035, (0, -0.78, 3.47), M("sausage_dark"), rot=(rad(90), 0, 0), segs=12, rsegs=5, name="smile",
          scale=(1, 0.5, 1))
    for x in (-0.3, 0.3):
        tube([(x, 0, 4.45), (x * 1.6, 0, 4.85)], 0.04, M(skin), name="antenna")
        sphere(0.11, (x * 1.6, 0, 4.9), M("mustard", emit=0.8), segs=10, rings=6, name="antenna_ball")
    # arms
    tube([(-0.8, 0, 2.85), (-1.0, -0.1, 2.2), (-0.95, -0.1, 1.75)], 0.15, M(suit), name="arm_l")
    sphere(0.16, (-0.95, -0.1, 1.65), M(skin), segs=10, rings=6, name="hand")
    tube([(0.8, 0, 2.85), (1.05, -0.35, 2.4), (0.75, -0.65, 2.3)], 0.15, M(suit), name="arm_r")
    sphere(0.16, (0.7, -0.7, 2.3), M(skin), segs=10, rings=6, name="hand")
    # briefcase in the left hand
    box((0.9, 0.3, 0.7), (-0.95, -0.1, 1.05), M("wood_dark"), bevel=0.06, name="briefcase")
    torus(0.15, 0.035, (-0.95, -0.1, 1.48), M("black"), rot=(rad(90), 0, 0), segs=12, rsegs=5, name="case_handle")
    for x in (-1.22, -0.68):
        box((0.1, 0.32, 0.1), (x, -0.1, 1.3), M("gold", metal=0.6), bevel=0.02, name="latch")


def build_MoneyBag():
    prof = [(0, 0), (0.45, 0.0), (0.62, 0.12), (0.72, 0.4), (0.7, 0.75), (0.55, 1.05), (0.25, 1.25), (0.2, 1.3),
            (0.3, 1.42), (0.45, 1.6), (0.38, 1.7), (0.0, 1.62)]
    lathe(prof, M("bun", rough=0.8), segs=24, name="bag")
    torus(0.23, 0.06, (0, 0, 1.28), M("sausage_dark"), segs=16, rsegs=6, name="rope")
    # hot dog emblem on the front
    cyl(0.35, 0.06, (0, -0.68, 0.62), M("cream"), rot=(rad(90 - 12), 0, 0), verts=20, name="emblem_disc")
    xform(hotdog(lod=0.5), (0, -0.73, 0.55), (rad(90 - 12), 0, rad(15)), 0.27)


# ---------------------------------------------------------------- detail helpers (buildings + upgrade props)
def chrome():
    return M("chrome", metal=0.5, rough=0.35)


def lerp3(a, b, t):
    return tuple(p + (q - p) * t for p, q in zip(a, b))


def place(fn, loc=(0, 0, 0), rotz=0.0, s=1.0, rot=None):
    """Build fn() in local space (front = -Y, base at z=0) and move it into place."""
    return xform(track(fn), loc, rot if rot is not None else (0, 0, rotz), s)


def rivets(p0, p1, n, r=0.06, mat="chrome"):
    m = chrome() if mat == "chrome" else M(mat)
    for i in range(n):
        sphere(r, lerp3(p0, p1, i / max(n - 1, 1)), m, segs=6, rings=4, name="rivet")


def window(w, h, frame="cream", glass="window", cols=2, rows=1, sill=True):
    """Framed window centred at the origin on a wall plane y=0, facing -Y."""
    box((w + 0.36, 0.2, h + 0.36), (0, -0.1, 0), M(frame), bevel=0.06, segs=1, name="win_frame")
    box((w, 0.06, h), (0, -0.22, 0), M(glass, rough=0.15), bevel=0, name="win_glass")
    for i in range(1, cols):
        box((0.12, 0.08, h), (-w / 2 + w * i / cols, -0.27, 0), M(frame), bevel=0, name="mullion")
    for j in range(1, rows):
        box((w, 0.08, 0.12), (0, -0.27, -h / 2 + h * j / rows), M(frame), bevel=0, name="transom")
    if sill:
        box((w + 0.7, 0.45, 0.16), (0, -0.22, -h / 2 - 0.24), M(frame), bevel=0.04, segs=1, name="sill")


def door(w, h, col="teal", frame="cream", glass=True, handle_side=1):
    """Door with its bottom at z=0 on a wall plane y=0, facing -Y."""
    box((w + 0.4, 0.2, h + 0.2), (0, -0.1, (h + 0.2) / 2), M(frame), bevel=0.05, segs=1, name="door_frame")
    box((w, 0.08, h), (0, -0.24, h / 2), M(col), bevel=0.03, segs=1, name="door")
    if glass:
        box((w * 0.6, 0.04, h * 0.42), (0, -0.29, h * 0.66), M("window", rough=0.15), bevel=0, name="door_glass")
    box((w * 0.7, 0.04, 0.12), (0, -0.29, h * 0.28), M(frame), bevel=0, name="kick")
    cyl(0.07, 0.3, (handle_side * w * 0.36, -0.36, h * 0.48), chrome(), rot=(rad(90), 0, 0), verts=8, name="handle")


def rollup(w, h, col="cream", frame="mustard", slats=9):
    """Roll-up garage / loading door, bottom at z=0 on wall plane y=0, facing -Y."""
    box((w + 0.9, 0.3, h + 0.5), (0, -0.15, (h + 0.5) / 2), M(frame), bevel=0.08, segs=1, name="bay_frame")
    box((w, 0.1, h), (0, -0.35, h / 2), M(col), bevel=0, name="bay_door")
    for i in range(1, slats):
        box((w, 0.06, 0.07), (0, -0.42, h * i / slats), M("steel"), bevel=0, name="slat")
    box((w * 0.3, 0.1, 0.14), (0, -0.46, 0.45), chrome(), bevel=0.02, segs=1, name="bay_handle")
    box((w + 0.7, 0.7, 0.55), (0, -0.4, h + 0.5), M(frame), bevel=0.1, segs=2, name="roll_housing")


def sign_panel(w, h, frame="ketchup", face="cream", bulbs=0):
    """Blank sign (flat face left for SurfaceGui text), centred at origin, front at about y=-0.35."""
    box((w + 0.6, 0.3, h + 0.6), (0, -0.15, 0), M(frame), bevel=0.12, segs=2, name="sign_frame")
    box((w, 0.06, h), (0, -0.33, 0), M(face), bevel=0, name="sign_face")
    if bulbs:
        m = M("mustard", emit=1.2) if frame != "mustard" else M("cream", emit=1.2)
        n = max(3, int(w / 1.1))
        for i in range(n):
            x = -w / 2 + w * i / (n - 1)
            for z in (h / 2 + 0.3, -h / 2 - 0.3):
                sphere(0.11, (x, -0.33, z), m, segs=8, rings=4, name="bulb")


def bush(loc, r=0.6, col="relish"):
    x, y, z = loc
    for dx, dy, dz, k in ((0, 0, 0, 1.0), (r * 0.6, r * 0.2, -r * 0.25, 0.72), (-r * 0.6, -r * 0.15, -r * 0.25, 0.72)):
        sphere(r * k, (x + dx, y + dy, z + dz), M(col, rough=0.8), segs=10, rings=6, name="bush")


def planter(loc, w=1.6, d=1.0, h=0.9, col="ketchup", leaf="relish"):
    x, y, z = loc
    box((w, d, h), (x, y, z + h / 2), M(col), bevel=0.08, segs=2, name="planter")
    box((w + 0.12, d + 0.12, 0.14), (x, y, z + h - 0.02), M("cream"), bevel=0.03, segs=1, name="planter_lip")
    box((w - 0.2, d - 0.2, 0.05), (x, y, z + h), M("wood_dark"), bevel=0, name="soil")
    bush((x, y, z + h + min(w, d) * 0.3), r=min(w, d) * 0.42, col=leaf)


def cone(loc, h=1.2):
    x, y, z = loc
    box((h * 0.72, h * 0.72, 0.1), (x, y, z + 0.05), M("ketchup"), bevel=0.03, segs=1, name="cone_base")
    cyl(h * 0.28, h * 0.9, (x, y, z + 0.1 + h * 0.45), M("ketchup"), r2=h * 0.06, verts=14, name="cone")
    cyl(h * 0.205, h * 0.18, (x, y, z + 0.1 + h * 0.45), M("cream"), r2=h * 0.16, verts=14, name="cone_band")


def cbox(size, loc, rotz=0.0, tape="mustard", label=True):
    """Cardboard box with tape and a small label; loc is the bottom centre."""
    w, d, h = size

    def f():
        box((w, d, h), (0, 0, h / 2), M("kraft", rough=0.85), bevel=0.04, segs=1, name="carton")
        box((w * 0.2, d + 0.03, 0.03), (0, 0, h + 0.005), M(tape), bevel=0, name="tape")
        box((w * 0.2, 0.03, h * 0.3), (0, -d / 2 - 0.005, h * 0.85), M(tape), bevel=0, name="tape_front")
        if label:
            box((w * 0.32, 0.03, h * 0.22), (w * 0.22, -d / 2 - 0.005, h * 0.4), M("cream"), bevel=0, name="label")
    return place(f, loc, rotz)


def monitor(w=1.6, h=1.0, glow="relish", kind="chart"):
    """Desk monitor standing at z=0, screen facing -Y."""
    box((0.7, 0.45, 0.06), (0, 0.1, 0.03), M("navy"), bevel=0.02, segs=1, name="mon_foot")
    box((0.14, 0.1, 0.5), (0, 0.15, 0.3), M("navy"), bevel=0, name="mon_neck")
    zc = 0.5 + h / 2
    box((w, 0.12, h), (0, 0.1, zc), M("navy"), bevel=0.04, segs=1, name="mon_bezel")
    box((w - 0.14, 0.03, h - 0.14), (0, 0.03, zc), M("screen", rough=0.3), bevel=0, name="mon_screen")
    gm = M(glow, emit=1.2)
    if kind == "chart":
        pts = [(-w * 0.38 + w * 0.76 * i / 5, 0.0, zc - h * 0.3 + h * 0.6 * (i / 5) + (0.12 * h if i % 2 else 0))
               for i in range(6)]
        tube(pts, 0.035, gm, name="mon_chart")
    elif kind == "bars":
        for i in range(5):
            bh = h * (0.15 + 0.12 * ((i * 3) % 5))
            box((w * 0.1, 0.03, bh), (-w * 0.32 + i * w * 0.16, 0.0, zc - h * 0.36 + bh / 2), gm, bevel=0, name="mon_bar")
    elif kind == "map":
        tube([(-w * 0.35, 0.0, zc - h * 0.2), (-w * 0.1, 0.0, zc + h * 0.15), (w * 0.15, 0.0, zc - h * 0.05),
              (w * 0.35, 0.0, zc + h * 0.25)], 0.03, gm, name="mon_route")
        sphere(0.07, (w * 0.35, -0.02, zc + h * 0.25), M("ketchup", emit=1.0), segs=8, rings=4, name="mon_pin")


def hazard(x0, x1, y, z, h, n, depth=0.06):
    """Mustard/black warning stripe along X facing -Y."""
    w = (x1 - x0) / n
    for i in range(n):
        box((w, depth, h), (x0 + w * (i + 0.5), y, z), M("mustard" if i % 2 == 0 else "black"), bevel=0,
            rot=(0, 0, 0), name="hazard")


def railing(p0, p1, h=1.1, n=5, mat="chrome"):
    m = chrome() if mat == "chrome" else M(mat)
    for i in range(n):
        p = lerp3(p0, p1, i / (n - 1))
        cyl(0.05, h, (p[0], p[1], p[2] + h / 2), m, verts=8, name="rail_post")
    tube([(p0[0], p0[1], p0[2] + h), (p1[0], p1[1], p1[2] + h)], 0.06, m, name="rail_top")
    tube([(p0[0], p0[1], p0[2] + h * 0.5), (p1[0], p1[1], p1[2] + h * 0.5)], 0.04, m, name="rail_mid")


def pallet(loc, w=2.4, d=2.0, rotz=0.0):
    def f():
        for k in range(5):
            box((w, d * 0.15, 0.08), (0, -d / 2 + d * 0.075 + k * (d * 0.85 / 4), 0.36), M("wood"), bevel=0.015, segs=1,
                name="pallet_board")
        for x in (-w / 2 + 0.12, 0, w / 2 - 0.12):
            box((0.22, d, 0.22), (x, 0, 0.21), M("wood_dark"), bevel=0.02, segs=1, name="pallet_runner")
        for y in (-d / 2 + 0.12, d / 2 - 0.12):
            box((w, 0.24, 0.08), (0, y, 0.05), M("wood"), bevel=0.015, segs=1, name="pallet_base")
    return place(f, loc, rotz)


def gear(r, th, loc, mat, teeth=10, rot=(rad(90), 0, 0)):
    """Flat gear emblem (disc + teeth) lying in local XY, rotated to face -Y by default."""
    def f():
        cyl(r, th, (0, 0, 0), mat, verts=teeth * 3, name="gear")
        for i in range(teeth):
            a = TAU * i / teeth
            box((r * 0.32, r * 0.3, th), (math.cos(a) * r * 1.08, math.sin(a) * r * 1.08, 0), mat, rot=(0, 0, a),
                bevel=0.02, segs=1, name="gear_tooth")
        cyl(r * 0.38, th + 0.06, (0, 0, 0), M("cream"), verts=16, name="gear_hub")
    return place(f, loc, rot=rot)


def lamp_post(loc, h=4.0, col="navy"):
    x, y, z = loc
    cyl(0.22, 0.3, (x, y, z + 0.15), M(col), verts=12, name="lamp_foot")
    cyl(0.09, h, (x, y, z + h / 2), M(col), verts=10, name="lamp_pole")
    sphere(0.32, (x, y, z + h + 0.2), M("cream", emit=1.2), segs=12, rings=8, name="lamp_globe")
    cyl(0.3, 0.12, (x, y, z + h + 0.5), M(col), r2=0.1, verts=12, name="lamp_cap")


def wavy_mustard(x0, x1, top, amp=0.09, freq=5.0, r=0.034, n=24):
    pts = []
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        y = amp * math.sin(x * math.pi * freq)
        pts.append((x, y, top + math.sqrt(max(0.2 ** 2 - y * y, 0)) + 0.03))
    return tube(pts, r, M("mustard", rough=0.35), name="mustard")


def mascot_dog(eyes=True):
    """Cheerful hot-dog mascot at hotdog scale (2 long): googly eyes + speed lines."""
    hotdog(lod=0.9, condiments=False)
    wavy_mustard(-0.78, 0.18, 0.5)
    if eyes:
        for x in (0.42, 0.7):
            sphere(0.13, (x, 0, 0.73), M("cream"), segs=12, rings=8, name="eye")
            sphere(0.065, (x + 0.01, -0.03, 0.84), M("black", rough=0.2), segs=10, rings=6, name="pupil")
    for z, ln in ((0.22, 0.7), (0.42, 0.95), (0.62, 0.6)):
        capsule(0.05, ln, (-1.12 - ln / 2, 0.0, z), M("cream"), "X", segs=8, steps=2, name="speed_line")


# ---------------------------------------------------------------- business buildings
def build_DashShop():
    W, D, H = 28.0, 14.0, 10.0
    y0 = 1.6
    fy = y0 - D / 2
    zb = 0.5
    red, yel = "ketchup", "mustard"
    # pavement + foundation (extends forward as a sidewalk)
    box((W + 1.2, D + 4.0, zb), (0, y0 - 1.6, zb / 2), M("concrete"), bevel=0.08, segs=1, name="sidewalk")
    box((W + 1.25, 0.5, 0.12), (0, y0 - 1.6 - (D + 4.0) / 2 + 0.25, zb + 0.02), M("concrete_dark"), bevel=0,
        name="curb")
    box((2.0, 8.4, 0.3), (W / 2 + 1.5, y0 + 3.3, 0.15), M("concrete_dark"), bevel=0.06, segs=1, name="apron")
    # shell
    box((W, D, H), (0, y0, zb + H / 2), M("cream"), bevel=0.15, segs=2, name="walls")
    box((W + 0.12, D + 0.12, 1.3), (0, y0, zb + 0.65), M(red), bevel=0.06, segs=1, name="base_band")
    box((W + 0.5, D + 0.5, 0.9), (0, y0, zb + H + 0.25), M(yel), bevel=0.12, segs=2, name="cornice")
    top = zb + H + 0.7
    box((W - 0.2, D - 0.2, 0.06), (0, y0, top + 0.03), M("concrete"), bevel=0, name="roof_deck")
    for sx in (-1, 1):
        box((0.4, D + 0.5, 0.6), (sx * (W / 2 + 0.05), y0, top + 0.3), M(red), bevel=0.06, segs=1, name="parapet")
        box((0.9, 0.9, H), (sx * W / 2, fy + 0.2, zb + H / 2), M(red), bevel=0.1, segs=1, name="pilaster")
    for sy in (-1, 1):
        box((W + 0.5, 0.4, 0.6), (0, y0 + sy * (D / 2 + 0.05), top + 0.3), M(red), bevel=0.06, segs=1, name="parapet")
    rivets((-W / 2 + 1.2, fy - 0.27, zb + H + 0.25), (W / 2 - 1.2, fy - 0.27, zb + H + 0.25), 16, r=0.09,
           mat="cream")
    # shop windows with hot-dog decals
    for sx in (-1, 1):
        place(lambda: window(9.0, 3.6, frame=red, cols=3), (sx * 7.6, fy, zb + 3.4))
        xform(hotdog(lod=0.5), (sx * 7.6, fy - 0.31, zb + 3.1), (rad(90), 0, rad(8 * sx)), (1.6, 1.6, 0.12))
    # double doors + step + transom
    for sx in (-1, 1):
        place(lambda: door(1.7, 4.4, col="teal", frame=red, handle_side=-1), (sx * 0.95, fy, zb))
    place(lambda: window(3.6, 0.7, frame=red, cols=1, sill=False), (0, fy, zb + 5.1))
    box((5.0, 1.3, 0.2), (0, fy - 0.65, zb + 0.1), M("concrete_dark"), bevel=0.05, segs=1, name="step")
    # striped awning
    adepth, tilt, az = 3.3, 16, zb + 6.0
    ay = fy - 0.05 - adepth / 2 * math.cos(rad(tilt))
    stripes(-13.2, 13.2, 14, ay, az, adepth, 0.14, tilt, [red, "cream"])
    fy2 = fy - 0.05 - adepth * math.cos(rad(tilt))
    fz = az - adepth / 2 * math.sin(rad(tilt))
    scallops(-13.2, 13.2, 14, fy2, fz, 0.4, [red, "cream"])
    for x in (-12.6, -4.4, 4.4, 12.6):
        tube([(x, fy, zb + 4.6), (x, fy2 + 0.3, fz - 0.05)], 0.06, chrome(), name="awning_strut")
    # blank sign with bulbs
    place(lambda: sign_panel(15.0, 2.0, frame=red, face="cream", bulbs=1), (0, fy, zb + 8.45))
    # planters + bollards by the door
    for sx in (-1, 1):
        planter((sx * 3.4, fy - 0.9, zb), w=1.8, d=1.0, h=0.9, col=yel)
        for x in (sx * 10.5, sx * 5.5):
            cyl(0.2, 0.9, (x, fy - 3.6, zb + 0.45), M(yel), verts=12, name="bollard")
            sphere(0.2, (x, fy - 3.6, zb + 0.9), M(yel), segs=10, rings=5, name="bollard_cap")
    # side garage door (+X) with its own small sign + side window
    place(lambda: rollup(7.0, 6.0, col="cream", frame=yel), (W / 2, y0 + 3.4, zb), rad(90))
    place(lambda: sign_panel(5.0, 0.9, frame=red), (W / 2, y0 + 3.4, zb + 8.6), rad(90))
    place(lambda: window(3.0, 2.6, frame=red, cols=2), (W / 2, fy + 2.4, zb + 4.0), rad(90))
    for sy in (-0.4, 7.2):
        sphere(0.25, (W / 2 + 0.3, y0 + sy, zb + 7.3), M("cream", emit=1.0), segs=10, rings=6, name="wall_lamp")
    # downspouts
    for sx in (-1, 1):
        cyl(0.18, H, (sx * (W / 2 + 0.2), y0 + D / 2 - 0.6, zb + H / 2), M("teal"), verts=10, name="downspout")
    # roof: AC unit, vents, mascot on plinth
    box((3.2, 2.4, 1.4), (-9.0, y0 + 3.5, top + 0.7), M("chrome", metal=0.5, rough=0.35), bevel=0.12, segs=2,
        name="ac_unit")
    torus(0.75, 0.1, (-9.0, y0 + 3.5, top + 1.42), M("navy"), segs=20, rsegs=6, name="ac_fan_ring")
    cyl(0.68, 0.06, (-9.0, y0 + 3.5, top + 1.41), M("navy"), verts=20, name="ac_fan")
    for x in (8.0, 10.0):
        cyl(0.3, 1.2, (x, y0 + 4.5, top + 0.6), chrome(), verts=12, name="vent")
        cyl(0.45, 0.2, (x, y0 + 4.5, top + 1.3), chrome(), r2=0.15, verts=12, name="vent_cap")
    cyl(3.0, 0.7, (0, y0 + 1.0, top + 0.35), M(red), verts=28, bevel=0.08, name="plinth")
    torus(3.0, 0.14, (0, y0 + 1.0, top + 0.68), M(yel), segs=28, rsegs=6, name="plinth_ring")
    for x in (-2.0, 2.0):
        cyl(0.16, 1.4, (x * 0.9, y0 + 1.0, top + 1.1), chrome(), verts=10, name="mascot_pole")
    place(mascot_dog, (0, y0 + 1.0, top + 1.4), rot=(rad(20), 0, 0), s=4.9)


def build_DepotBuilding():
    W, D, H = 34.0, 15.5, 11.0
    y0 = 2.0
    fy = y0 - D / 2
    zb = 0.4
    wall, rib = "teal", "teal_dark"
    box((W + 1.0, D + 1.0, zb), (0, y0, zb / 2), M("concrete"), bevel=0.06, segs=1, name="slab")
    box((W, D, H), (0, y0, zb + H / 2), M(wall), bevel=0.12, segs=2, name="walls")
    # company stripe (ketchup + mustard) wrapping the building
    box((W + 0.14, D + 0.14, 0.75), (0, y0, zb + 8.6), M("ketchup"), bevel=0.04, segs=1, name="stripe")
    box((W + 0.14, D + 0.14, 0.3), (0, y0, zb + 7.85), M("mustard"), bevel=0.02, segs=1, name="stripe2")
    box((W + 0.5, D + 0.5, 0.5), (0, y0, zb + H + 0.1), M("cream"), bevel=0.1, segs=1, name="coping")
    top = zb + H + 0.35
    # corrugated ribs on the front and +X walls
    for i in range(35):
        x = -W / 2 + 0.5 + i * (W - 1.0) / 34
        box((0.14, 0.12, 7.2), (x, fy - 0.05, zb + 3.6 + 0.2), M(rib), bevel=0, name="rib")
        box((0.14, 0.12, 1.75), (x, fy - 0.05, zb + 9.95), M(rib), bevel=0, name="rib")
    for i in range(16):
        y = fy + 0.5 + i * (D - 1.0) / 15
        box((0.12, 0.14, 7.2), (W / 2 + 0.05, y, zb + 3.8), M(rib), bevel=0, name="rib")
    # loading dock platform with hazard edge, bumpers, steps + rail
    dz = 1.4
    dx0, dx1 = -W / 2 + 0.2, 6.0
    box((dx1 - dx0, 3.2, dz), ((dx0 + dx1) / 2, fy - 1.6, dz / 2), M("concrete"), bevel=0.06, segs=1, name="dock")
    hazard(dx0, dx1, fy - 3.23, dz - 0.15, 0.3, 26)
    for k in range(4):
        box((1.8, 0.42, dz * (k + 1) / 4), (dx1 + 0.9, fy - 1.6 - 1.05 + k * 0.42, dz * (k + 1) / 8),
            M("concrete_dark"), bevel=0.03, segs=1, name="dock_step")
    railing((dx1 - 0.1, fy - 3.0, dz), (dx1 - 0.1, fy - 0.3, dz), h=1.0, n=3, mat="mustard")
    for i, x in enumerate((-12.0, -5.0, 2.0)):
        place(lambda: rollup(5.4, 5.6, col="cream", frame="mustard"), (x, fy, dz))
        for sx in (-1, 1):
            box((0.5, 0.5, 0.9), (x + sx * 2.3, fy - 0.3 - 0.25 - 0.3, dz + 0.55), M("black", rough=0.8), bevel=0.06,
                segs=1, name="dock_bumper")
        box((4.2, 1.0, 0.1), (x, fy - 0.7, dz + 0.05), M("steel"), bevel=0.02, segs=1, name="dock_plate")
        sphere(0.25, (x, fy - 0.9, dz + 7.25), M("mustard", emit=1.0), segs=10, rings=6, name="bay_light")
        box((0.5, 0.5, 0.3), (x, fy - 0.65, dz + 7.4), M("navy"), bevel=0.05, segs=1, name="bay_light_hood")
        place(lambda: sign_panel(1.0, 0.7, frame="navy", face="cream"), (x - 3.6, fy - 0.12, dz + 5.0))
    # office corner with door + windows
    ox = 11.6
    box((9.4, 2.0, 7.2), (ox, fy - 1.0, zb + 3.6), M("cream"), bevel=0.15, segs=2, name="office")
    box((9.6, 2.2, 0.5), (ox, fy - 1.0, zb + 7.3), M("ketchup"), bevel=0.08, segs=1, name="office_cap")
    place(lambda: door(1.8, 3.8, col="ketchup", frame="navy"), (ox - 2.6, fy - 2.0, zb))
    place(lambda: window(4.4, 2.2, frame="navy", cols=3), (ox + 1.6, fy - 2.0, zb + 2.6))
    place(lambda: window(7.6, 1.6, frame="navy", cols=4), (ox, fy - 2.0, zb + 5.6))
    box((3.6, 1.4, 0.15), (ox - 2.6, fy - 2.6, zb + 4.4), M("mustard"), bevel=0.04, segs=1, name="door_canopy")
    planter((ox + 3.8, fy - 2.9, zb), w=1.4, d=0.9, h=0.8, col="navy")
    # roof: turbine vents, skylights, rooftop company sign
    for x in (-13.0, -6.0, 1.0, 8.0, 14.0):
        cyl(0.55, 0.8, (x, y0 + 4.0, top + 0.4), M("steel"), verts=14, name="vent_neck")
        lathe([(0, 0), (0.95, 0), (0.95, 0.5), (0.7, 1.0), (0, 1.15)], chrome(), loc=(x, y0 + 4.0, top + 0.8),
              segs=14, name="turbine")
        for k in range(7):
            a = TAU * k / 7
            box((0.06, 0.4, 0.55), (x + 0.93 * math.cos(a), y0 + 4.0 + 0.93 * math.sin(a), top + 1.08),
                M("steel"), rot=(0, 0, a), bevel=0, name="turbine_fin")
    for x in (-10.0, 0.0, 10.0):
        box((4.0, 2.4, 0.5), (x, y0 + 0.2, top + 0.25), M("window", rough=0.15), bevel=0.12, segs=1, name="skylight")
    for x in (-10.0, 2.0):
        box((0.3, 0.3, 1.4), (x, fy + 1.0, top + 0.7), M("navy"), bevel=0.03, segs=1, name="sign_leg")
    place(lambda: sign_panel(14.0, 2.4, frame="ketchup", face="cream", bulbs=1), (-4.0, fy + 0.9, top + 2.9))


def build_TradingFloor():
    W, D = 23.6, 15.6
    zb = 0.6
    FH = 6.2
    box((26.0, 18.0, zb), (0, 0, zb / 2), M("stone_dark"), bevel=0.1, segs=1, name="plaza")
    fy = -D / 2
    for f in range(3):
        z0 = zb + f * FH
        box((W, D, FH - 0.6), (0, 0, z0 + (FH - 0.6) / 2), M("window", rough=0.15), bevel=0.05, segs=1,
            name="curtain_wall")
        box((W + 1.4, D + 1.4, 0.6), (0, 0, z0 + FH - 0.3), M("cream"), bevel=0.12, segs=2, name="slab")
        box((W + 1.46, D + 1.46, 0.16), (0, 0, z0 + FH - 0.42), M("teal"), bevel=0, name="slab_fascia")
        for i in range(13):
            x = -W / 2 + i * W / 12
            box((0.16, 0.16, FH - 0.6), (x, fy - 0.06, z0 + (FH - 0.6) / 2), chrome(), bevel=0, name="mullion")
        for i in range(9):
            y = fy + i * D / 8
            box((0.16, 0.16, FH - 0.6), (W / 2 + 0.06, y, z0 + (FH - 0.6) / 2), chrome(), bevel=0, name="mullion")
        if f > 0:
            box((W + 0.1, 0.12, 0.14), (0, fy - 0.08, z0 + 1.0), chrome(), bevel=0, name="transom")
            box((0.12, D + 0.1, 0.14), (W / 2 + 0.08, 0, z0 + 1.0), chrome(), bevel=0, name="transom")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.9, 0.9, 3 * FH), (sx * W / 2, sy * D / 2, zb + 1.5 * FH), M("cream"), bevel=0.12, segs=1,
                name="corner_column")
    # ground floor entrance, canopy and blank sign
    box((8.0, 1.0, 3.8), (0, fy - 0.4, zb + 1.9), M("navy"), bevel=0.06, segs=1, name="entrance_frame")
    for sx in (-1, 1):
        place(lambda: door(1.6, 3.2, col="window", frame="navy", glass=False, handle_side=-1),
              (sx * 0.85, fy - 0.9, zb))
    box((9.5, 3.2, 0.3), (0, fy - 1.9, zb + 4.0), M("teal"), bevel=0.08, segs=1, name="canopy")
    for x in (-4.4, 4.4):
        cyl(0.12, 4.0, (x, fy - 3.3, zb + 2.0), chrome(), verts=10, name="canopy_post")
    place(lambda: sign_panel(9.0, 1.2, frame="navy", face="cream", bulbs=1), (0, fy - 0.06, zb + 4.95))
    for sx in (-1, 1):
        planter((sx * 7.0, fy - 1.5, zb), w=2.4, d=1.0, h=0.8, col="navy")
    # roof: ticker band on posts around the perimeter
    top = zb + 3 * FH
    bz = top + 1.6
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            box((0.3, 0.3, 1.0), (sx * (W / 2 - 0.3), sy * (D / 2 - 0.3), top + 0.5), M("navy"), bevel=0, name="band_post")
    for sy in (-1, 1):
        box((W, 0.35, 1.5), (0, sy * (D / 2 - 0.2), bz + 0.2), M("navy"), bevel=0.06, segs=1, name="ticker_band")
    for sx in (-1, 1):
        box((0.35, D, 1.5), (sx * (W / 2 - 0.2), 0, bz + 0.2), M("navy"), bevel=0.06, segs=1, name="ticker_band")
    for z in (bz + 1.0, bz - 0.6):
        for sy in (-1, 1):
            box((W + 0.2, 0.55, 0.14), (0, sy * (D / 2 - 0.2), z), M("mustard"), bevel=0, name="band_trim")
        for sx in (-1, 1):
            box((0.55, D + 0.2, 0.14), (sx * (W / 2 - 0.2), 0, z), M("mustard"), bevel=0, name="band_trim")
    cols = ("relish", "relish", "ketchup", "relish", "mustard")
    for i in range(22):
        x = -W / 2 + 0.8 + i * (W - 1.6) / 21
        box((0.6, 0.05, 0.3 + 0.15 * (i % 3)), (x, -D / 2 + 0.0, bz + 0.2), M(cols[i % 5], emit=1.3), bevel=0,
            name="ticker_mark")
    for i in range(14):
        y = -D / 2 + 0.8 + i * (D - 1.6) / 13
        box((0.05, 0.6, 0.3 + 0.15 * (i % 3)), (W / 2 + 0.0, y, bz + 0.2), M(cols[(i + 2) % 5], emit=1.3), bevel=0,
            name="ticker_mark")
    # rooftop plant, mast with an up-arrow
    box((6.0, 4.0, 1.6), (-4.0, 2.0, top + 0.8), M("cream"), bevel=0.12, segs=1, name="roof_plant")
    for i in range(4):
        box((5.0, 0.06, 0.12), (-4.0, -0.03, top + 0.4 + i * 0.3), M("steel"), bevel=0, name="louvre")
    cyl(0.18, 4.4, (5.0, 2.0, top + 2.2), chrome(), verts=10, name="mast")
    box((0.9, 0.4, 1.6), (5.0, 2.0, top + 3.8), M("relish", emit=0.5), bevel=0.05, segs=1, name="arrow_stem")
    wedge_prism([(-1.0, 0), (1.0, 0), (0, 1.1)], 0.4, M("relish", emit=0.5), loc=(5.0, 2.0, top + 4.6), bevel=0.04,
                name="arrow_head")


def build_LabBuilding():
    W, D, H = 26.0, 15.0, 9.0
    y0 = 1.0
    fy = y0 - D / 2
    zb = 0.5
    box((W + 1.4, D + 4.0, zb), (0, y0 - 1.3, zb / 2), M("concrete"), bevel=0.08, segs=1, name="slab")
    box((W, D, H), (0, y0, zb + H / 2), M("cream"), bevel=1.0, segs=4, name="lab_shell")
    box((W + 0.1, D + 0.1, 0.7), (0, y0, zb + 0.95), M("teal"), bevel=0.3, segs=2, name="band_low")
    box((W + 0.1, D + 0.1, 0.4), (0, y0, zb + H - 1.4), M("teal"), bevel=0.15, segs=2, name="band_high")
    top = zb + H
    # round porthole windows
    for x in (-10.0, -7.0, -4.0, 4.0, 7.0, 10.0):
        torus(0.95, 0.18, (x, fy - 0.05, zb + 4.6), chrome(), rot=(rad(90), 0, 0), segs=20, rsegs=6, name="porthole")
        cyl(0.9, 0.1, (x, fy - 0.02, zb + 4.6), M("window", rough=0.15), rot=(rad(90), 0, 0), verts=20, name="port_glass")
        box((2.2, 0.3, 0.15), (x, fy - 0.15, zb + 3.3), M("teal"), bevel=0.04, segs=1, name="port_sill")
    for y in (fy + 3.5, fy + 7.0, fy + 10.5):
        torus(0.95, 0.18, (W / 2 + 0.05, y, zb + 4.6), chrome(), rot=(0, rad(90), 0), segs=20, rsegs=6, name="porthole")
        cyl(0.9, 0.1, (W / 2 + 0.02, y, zb + 4.6), M("window", rough=0.15), rot=(0, rad(90), 0), verts=20,
            name="port_glass")
    # entrance pod with rounded canopy + doors
    box((7.0, 1.6, 5.4), (0, fy - 0.6, zb + 2.7), M("teal"), bevel=0.6, segs=3, name="entry_pod")
    for sx in (-1, 1):
        place(lambda: door(1.6, 3.6, col="cream", frame="teal_dark", handle_side=-1), (sx * 0.85, fy - 1.4, zb))
    box((8.6, 2.6, 0.4), (0, fy - 1.9, zb + 5.6), M("cream"), bevel=0.18, segs=3, name="canopy")
    box((8.7, 2.7, 0.14), (0, fy - 1.9, zb + 5.4), M("teal_dark"), bevel=0.05, segs=1, name="canopy_trim")
    for x in (-3.9, 3.9):
        cyl(0.13, 5.4, (x, fy - 2.9, zb + 2.7), chrome(), verts=10, name="canopy_post")
    place(lambda: sign_panel(11.0, 1.6, frame="teal_dark", face="cream", bulbs=1), (0, fy, zb + 7.35))
    for sx in (-1, 1):
        planter((sx * 5.2, fy - 1.2, zb), w=2.0, d=1.0, h=0.8, col="teal", leaf="relish")
    # roof parapet + glass dome with a hot dog inside
    box((W - 1.6, D - 1.6, 0.25), (0, y0, top + 0.1), M("concrete"), bevel=0.05, segs=1, name="roof_deck")
    dx, dyy = -5.5, y0 + 1.0
    cyl(5.3, 0.9, (dx, dyy, top + 0.45), chrome(), verts=32, bevel=0.1, name="dome_drum")
    torus(5.3, 0.16, (dx, dyy, top + 0.92), M("teal"), segs=32, rsegs=6, name="dome_ring")
    cyl(1.0, 1.4, (dx, dyy, top + 1.6), M("teal"), verts=16, name="dome_pedestal")
    xform(hotdog(lod=0.8), (dx, dyy, top + 2.3), (0, 0, rad(-25)), 2.4)
    R = 5.0
    prof = [(R, 0)] + [(R * math.cos(a), R * 0.95 * math.sin(a)) for a in [rad(d) for d in range(10, 91, 10)]]
    prof[-1] = (0, R * 0.95)
    lathe(prof, M("glass", transmission=1.0), loc=(dx, dyy, top + 0.9), segs=32, cap=False, name="dome")
    for k in range(6):
        a = TAU * k / 6
        pts = [((R + 0.04) * math.cos(t) * math.cos(a) + dx, (R + 0.04) * math.cos(t) * math.sin(a) + dyy,
                top + 0.9 + (R * 0.95 + 0.04) * math.sin(t)) for t in [rad(d) for d in range(0, 91, 10)]]
        tube(pts, 0.08, M("teal"), name="dome_rib")
    sphere(0.4, (dx, dyy, top + 0.9 + R * 0.95 + 0.25), M("ketchup", emit=0.8), segs=12, rings=8, name="dome_beacon")
    # chimney with puffs
    cx, cy = 9.5, y0 + 4.0
    cyl(0.95, 6.0, (cx, cy, top + 3.0), M("teal_dark"), verts=18, name="chimney")
    for z in (top + 1.5, top + 4.0):
        cyl(1.05, 0.4, (cx, cy, z), M("cream"), verts=18, name="chimney_band")
    cyl(1.2, 0.5, (cx, cy, top + 6.1), chrome(), verts=18, name="chimney_cap")
    for i, (ox, oz, r) in enumerate(((0.2, 7.2, 0.8), (-0.6, 8.0, 0.65), (0.5, 8.6, 0.5))):
        sphere(r, (cx + ox, cy, top + oz), M("cream", rough=0.9), segs=14, rings=8, name="puff")
    # giant beakers on the roof
    def beaker(x, y, h, liquid):
        cyl(1.0, 0.25, (x, y, top + 0.37), M("teal_dark"), verts=16, name="beaker_base")
        prof = [(0, 0), (0.95, 0), (1.0, 0.15), (0.95, 0.4 * h), (0.35, 0.8 * h), (0.32, h), (0.42, h + 0.1),
                (0, h + 0.1)]
        lathe(prof, M("glass", transmission=1.0), loc=(x, y, top + 0.5), segs=20, name="beaker")
        lathe([(0, 0.05), (0.88, 0.05), (0.9, 0.35 * h), (0.55, 0.55 * h), (0, 0.55 * h)], M(liquid, emit=0.9),
              loc=(x, y, top + 0.5), segs=20, name="beaker_liquid")
        sphere(0.2, (x + 0.1, y, top + 0.5 + h + 0.5), M(liquid, emit=0.9), segs=8, rings=5, name="bubble")
    beaker(2.4, y0 - 4.0, 2.6, "relish")
    beaker(5.6, y0 - 4.4, 2.0, "pink")
    beaker(8.6, y0 - 3.4, 2.4, "mustard")
    tube([(2.4, y0 - 4.0, top + 2.7), (2.4, y0 - 2.0, top + 3.6), (6.0, y0 - 1.2, top + 3.6), (9.5, y0 + 3.0,
          top + 3.0)], 0.12, M("teal"), name="roof_pipe")


def build_RoboticsFactory():
    W, D, H = 30.0, 17.0, 8.0
    y0 = 1.4
    fy = y0 - D / 2
    zb = 0.4
    box((W + 1.0, D + 3.0, zb), (0, y0 - 1.0, zb / 2), M("concrete"), bevel=0.06, segs=1, name="slab")
    box((W, D, H), (0, y0, zb + H / 2), M("cream"), bevel=0.12, segs=2, name="walls")
    box((W + 0.14, D + 0.14, 2.2), (0, y0, zb + 1.1), M("navy"), bevel=0.06, segs=1, name="plinth_band")
    box((W + 0.4, D + 0.4, 0.45), (0, y0, zb + H), M("mustard"), bevel=0.08, segs=1, name="eave")
    top = zb + H + 0.22
    # sawtooth roof (4 teeth over -X part, flat deck over +X part)
    tw, th = 5.5, 3.0
    x0 = -W / 2
    for i in range(4):
        xa = x0 + i * tw
        wedge_prism([(xa, 0), (xa + tw, 0), (xa + tw, th)], D, M("teal"), loc=(0, y0, top), bevel=0.05,
                    name="saw_tooth")
        box((0.12, D - 0.8, th - 0.5), (xa + tw + 0.04, y0, top + (th - 0.5) / 2 + 0.15), M("window", rough=0.15),
            bevel=0, name="saw_glass")
        for k in range(1, 6):
            box((0.16, 0.12, th - 0.5), (xa + tw + 0.08, y0 - D / 2 + k * D / 6, top + (th - 0.5) / 2 + 0.15),
                chrome(), bevel=0, name="saw_mullion")
    box((W - 4 * tw - 0.2, D - 0.2, 0.2), (x0 + 4 * tw + (W - 4 * tw) / 2, y0, top + 0.1), M("concrete"), bevel=0,
        name="flat_deck")
    # front: hangar door, windows strip, gear emblem, blank sign
    place(lambda: rollup(8.0, 5.6, col="chrome", frame="mustard"), (-8.0, fy, zb))
    hazard(-12.4, -3.6, fy - 0.5, zb + 0.15, 0.3, 14)
    for x in (2.0, 9.5):
        place(lambda: window(5.0, 1.8, frame="navy", cols=4), (x, fy, zb + 5.0))
    place(lambda: door(1.8, 3.4, col="ketchup", frame="navy"), (12.4, fy, zb))
    gear(1.25, 0.3, (5.6, fy - 0.2, zb + 2.3), M("mustard"), teeth=10)
    place(lambda: sign_panel(11.0, 1.4, frame="navy", face="cream", bulbs=1), (-6.0, fy, zb + 7.0))
    for i in range(14):
        cyl(0.07, 0.12, (-W / 2 + 1 + i * (W - 2) / 13, fy - 0.06, zb + 2.0), chrome(), rot=(rad(90), 0, 0),
            verts=8, name="rivet")
    # +X side: loading door + pipes
    place(lambda: rollup(5.0, 4.6, col="cream", frame="mustard"), (W / 2, y0 + 2.5, zb), rad(90))
    for k, z in enumerate((zb + 6.2, zb + 6.8)):
        tube([(W / 2 + 0.3, fy + 0.5, z), (W / 2 + 0.3, y0 + D / 2 - 0.5, z)], 0.14,
             M("ketchup" if k else "relish"), name="wall_pipe")
    # robot arm on the flat deck
    ax, ay = 10.0, y0 - 1.0
    cyl(1.8, 0.6, (ax, ay, top + 0.5), M("navy"), verts=24, bevel=0.08, name="arm_base")
    cyl(1.3, 0.9, (ax, ay, top + 1.2), M("mustard"), verts=24, bevel=0.08, name="arm_turret")
    sh = Vector((ax, ay, top + 2.2))
    el = Vector((ax - 2.4, ay + 0.4, top + 6.6))
    wr = Vector((ax - 5.2, ay - 0.4, top + 5.0))
    sphere(0.85, sh, M("chrome", metal=0.5, rough=0.35), segs=16, rings=10, name="shoulder")
    sphere(0.7, el, M("chrome", metal=0.5, rough=0.35), segs=16, rings=10, name="elbow")
    for a, b, r in ((sh, el, 0.55), (el, wr, 0.42)):
        d = b - a
        mid = (a + b) / 2
        q = d.to_track_quat("Z", "Y").to_euler()
        o = capsule(r, d.length + r, (0, 0, 0), M("mustard"), "Z", segs=16, steps=3, name="arm_link")
        xform([o], tuple(mid), tuple(q))
    for a, b in ((sh, el), (el, wr)):
        d = b - a
        q = d.to_track_quat("Z", "Y").to_euler()
        place(lambda: cyl(0.6, 0.3, (0, 0, 0), M("navy"), verts=16, name="arm_band"), tuple((a + b) / 2), rot=tuple(q))
    sphere(0.45, wr, M("navy"), segs=12, rings=8, name="wrist")
    for sx in (-1, 1):
        box((0.22, 0.4, 1.1), (wr.x + sx * 0.45, wr.y, wr.z - 0.75), chrome(), bevel=0.04, segs=1, name="gripper")
    xform(hotdog(lod=0.6), (wr.x, wr.y, wr.z - 1.55), (0, 0, rad(90)), 1.0)
    box((2.6, 2.0, 1.2), (12.6, y0 + 5.0, top + 0.6), chrome(), bevel=0.1, segs=1, name="roof_unit")
    torus(0.6, 0.08, (12.6, y0 + 5.0, top + 1.22), M("navy"), segs=16, rsegs=5, name="roof_fan")
    # smokestack (ground to 20) with bands + smoke
    sx_, sy_ = -12.8, y0 + D / 2 - 1.8
    cyl(1.4, 18.0, (sx_, sy_, 9.1), M("brick"), r2=1.1, verts=20, name="stack")
    for z in (11.5, 14.0, 16.5):
        cyl(1.42 - (z - 0.1) * 0.0158 + 0.05, 0.6, (sx_, sy_, z), M("cream"), verts=20, name="stack_band")
    cyl(1.35, 0.5, (sx_, sy_, 18.3), M("navy"), verts=20, name="stack_lip")
    for ox, oz, r in ((0.2, 19.2, 0.95), (1.3, 19.9, 0.7)):
        sphere(r, (sx_ + ox, sy_, oz), M("cream", rough=0.9), segs=12, rings=8, name="smoke")
    # forklift parking cones out front
    for x in (-2.5, 0.0):
        cone((x, fy - 1.6, zb), 1.0)


def build_RepublicCapitol():
    zb = 2.4
    stone, dark, gold = "stone", "stone_dark", "gold"
    gm = M(gold, metal=0.6, rough=0.35)
    box((34.0, 18.0, zb), (0, 2.0, zb / 2), M(dark), bevel=0.12, segs=2, name="podium")
    box((34.3, 18.3, 0.3), (0, 2.0, zb - 0.1), M(stone), bevel=0.05, segs=1, name="podium_lip")
    fy_pod = 2.0 - 9.0
    n = 6
    for k in range(n):
        dep = (n - k) * 0.7
        box((14.0 - k * 0.2, dep, (k + 1) * zb / n), (0, fy_pod - dep / 2 + 0.05, (k + 1) * zb / n / 2),
            M(stone if k % 2 == 0 else dark), bevel=0.04, segs=1, name="stair")
    for sx in (-1, 1):
        box((1.2, n * 0.7, zb + 0.5), (sx * 7.6, fy_pod - n * 0.35, (zb + 0.5) / 2), M(stone), bevel=0.08, segs=1,
            name="stair_cheek")
        sphere(0.55, (sx * 7.6, fy_pod - n * 0.7 + 0.6, zb + 0.9), gm, segs=12, rings=8, name="cheek_ball")
    # main hall
    hy = 4.0
    box((30.0, 12.0, 8.0), (0, hy, zb + 4.0), M(stone), bevel=0.1, segs=2, name="hall")
    box((30.4, 12.4, 0.8), (0, hy, zb + 8.2), M(dark), bevel=0.08, segs=1, name="hall_cornice")
    box((30.2, 12.2, 0.6), (0, hy, zb + 0.3), M(dark), bevel=0.05, segs=1, name="hall_base")
    hfy = hy - 6.0
    for x in (-12.5, -9.5, 9.5, 12.5):
        place(lambda: window(1.6, 3.4, frame="cream", cols=1, rows=2), (x, hfy, zb + 4.0))
        cyl(0.98, 0.2, (x, hfy - 0.1, zb + 5.7), M("cream"), rot=(rad(90), 0, 0), verts=16, name="arch")
        cyl(0.8, 0.22, (x, hfy - 0.15, zb + 5.7), M("window", rough=0.15), rot=(rad(90), 0, 0), verts=16, name="arch_glass")
    for y in (hy - 3.0, hy + 1.0, hy + 4.5):
        place(lambda: window(1.6, 3.4, frame="cream", cols=1, rows=2), (15.0, y, zb + 4.0), rad(90))
    # portico: columns, entablature with blank sign, pediment
    py = hfy - 1.8
    for i in range(6):
        x = -6.25 + i * 2.5
        lathe([(0, 0), (0.85, 0), (0.85, 0.35), (0.62, 0.5), (0.55, 0.7), (0.48, 6.3), (0.6, 6.5), (0.85, 6.75),
               (0.85, 7.0), (0, 7.0)], M("cream"), loc=(x, py, zb), segs=16, name="column")
    ez = zb + 7.0
    box((16.4, 4.4, 1.7), (0, py + 1.2, ez + 0.85), M(stone), bevel=0.08, segs=1, name="entablature")
    place(lambda: sign_panel(11.0, 0.8, frame=gold, face="cream"), (0, py - 1.0, ez + 0.85))
    wedge_prism([(-8.6, 0), (8.6, 0), (0, 2.8)], 4.6, M(stone), loc=(0, py + 1.2, ez + 1.7), bevel=0.06,
                name="pediment")
    wedge_prism([(-7.4, 0), (7.4, 0), (0, 2.1)], 0.2, M(dark), loc=(0, py - 1.1, ez + 1.95), name="tympanum")
    xform(hotdog(lod=0.6), (0, py - 1.25, ez + 2.35), (rad(90), 0, 0), (1.8, 1.8, 0.2))
    box((16.4, 4.6, 0.25), (0, py + 1.2, ez + 1.82), M(gold, metal=0.6, rough=0.35), bevel=0.03, segs=1,
        name="gold_trim")
    place(lambda: door(2.6, 4.6, col="wood_dark", frame=gold, glass=False), (0, hfy, zb))
    # drum + colonnade + golden dome + lantern + hot dog
    dz = zb + 8.6
    cyl(6.2, 0.8, (0, hy, dz + 0.4), M(dark), verts=36, bevel=0.06, name="drum_base")
    cyl(5.3, 3.6, (0, hy, dz + 2.6), M(stone), verts=36, name="drum")
    for i in range(16):
        a = TAU * i / 16
        cyl(0.22, 3.4, (5.75 * math.cos(a), hy + 5.75 * math.sin(a), dz + 2.5), M("cream"), verts=10,
            name="drum_column")
    cyl(6.1, 0.4, (0, hy, dz + 4.4), M(dark), verts=36, name="drum_cornice")
    R = 5.0
    prof = [(R, 0)] + [(R * math.cos(a), R * 1.1 * math.sin(a)) for a in [rad(d) for d in range(8, 91, 8)]] + [
        (0, R * 1.1)]
    lathe(prof, gm, loc=(0, hy, dz + 4.6), segs=36, name="dome")
    for k in range(12):
        a = TAU * k / 12
        pts = [((R + 0.06) * math.cos(t) * math.cos(a), hy + (R + 0.06) * math.cos(t) * math.sin(a),
                dz + 4.6 + (R * 1.1 + 0.06) * math.sin(t)) for t in [rad(d) for d in range(0, 81, 8)]]
        tube(pts, 0.1, M("mustard"), name="dome_rib")
    lz = dz + 4.6 + R * 1.1 - 0.2
    cyl(1.0, 1.4, (0, hy, lz + 0.7), M("cream"), verts=16, name="lantern")
    for i in range(8):
        a = TAU * i / 8
        cyl(0.1, 1.2, (1.05 * math.cos(a), hy + 1.05 * math.sin(a), lz + 0.7), gm, verts=6, name="lantern_col")
    lathe([(1.15, 0), (0.9, 0.4), (0.4, 0.75), (0, 0.85)], gm, loc=(0, hy, lz + 1.4), segs=16, name="lantern_dome")
    cyl(0.12, 0.6, (0, hy, lz + 2.5), gm, verts=8, name="spire")
    xform(hotdog(lod=1.0), (0, hy, lz + 2.75), (0, 0, 0), 2.6)
    # flags + bushes on the podium
    for sx in (-1, 1):
        flag((sx * 15.8, -5.6, zb), 7.5, "ketchup" if sx < 0 else "mustard", w=2.4, fh=1.5)
        for x in (sx * 10.5, sx * 13.0):
            cyl(0.55, 0.7, (x, -5.0, zb + 0.35), M(dark), r2=0.4, verts=14, name="urn")
            bush((x, -5.0, zb + 1.1), r=0.6)


def build_LaunchSite():
    W, D = 40.0, 28.0
    box((W, D, 0.5), (0, 0, 0.25), M("concrete"), bevel=0.1, segs=1, name="pad_slab")
    zb = 0.5
    hazard(-W / 2 + 0.4, W / 2 - 0.4, -D / 2 + 0.6, zb + 0.01, 0.02, 40, depth=0.6)
    rx, ry = -9.0, 3.0
    cyl(7.2, 0.06, (rx, ry, zb + 0.03), M("mustard"), verts=40, name="pad_ring")
    cyl(6.6, 0.08, (rx, ry, zb + 0.04), M("concrete_dark"), verts=40, name="pad_inner")
    box((4.0, 12.0, 0.1), (rx, ry - 9.0, zb + 0.05), M("concrete_dark"), bevel=0, name="flame_trench")
    place(hotdog_rocket, (rx, ry, zb), s=1.08)
    # gantry tower (lattice) beside the rocket
    tx, ty = rx + 9.0, ry + 0.5
    TW, TH = 3.6, 32.0
    red = M("ketchup")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.36, 0.36, TH), (tx + sx * TW / 2, ty + sy * TW / 2, zb + TH / 2), red, bevel=0.04, segs=1,
                name="tower_post")
    nlev = 10
    for k in range(nlev + 1):
        z = zb + 0.6 + k * (TH - 0.6) / nlev
        for sy in (-1, 1):
            box((TW, 0.22, 0.22), (tx, ty + sy * TW / 2, z), red, bevel=0, name="tower_beam")
        for sx in (-1, 1):
            box((0.22, TW, 0.22), (tx + sx * TW / 2, ty, z), red, bevel=0, name="tower_beam")
        if k < nlev:
            z2 = zb + 0.6 + (k + 1) * (TH - 0.6) / nlev
            a, b = (-1, 1) if k % 2 else (1, -1)
            tube([(tx + a * TW / 2, ty - TW / 2 - 0.02, z), (tx + b * TW / 2, ty - TW / 2 - 0.02, z2)], 0.08,
                 M("cream"), name="brace")
            tube([(tx + TW / 2 + 0.02, ty + a * TW / 2, z), (tx + TW / 2 + 0.02, ty + b * TW / 2, z2)], 0.08,
                 M("cream"), name="brace")
            tube([(tx - TW / 2 - 0.02, ty + a * TW / 2, z), (tx - TW / 2 - 0.02, ty + b * TW / 2, z2)], 0.08,
                 M("cream"), name="brace")
    box((TW + 0.8, TW + 0.8, 0.4), (tx, ty, zb + TH + 0.2), M("navy"), bevel=0.08, segs=1, name="tower_cap")
    cyl(0.1, 3.0, (tx, ty, zb + TH + 1.9), chrome(), verts=8, name="lightning_rod")
    sphere(0.3, (tx, ty, zb + TH + 3.4), M("ketchup", emit=1.5), segs=10, rings=6, name="beacon")
    box((1.8, 1.8, 2.4), (tx, ty, zb + 1.2), M("mustard"), bevel=0.06, segs=1, name="elevator")
    # crew access arms to the rocket
    for z, ln in ((zb + 23.5, 6.0), (zb + 14.0, 5.6)):
        box((ln, 1.0, 0.4), (tx - TW / 2 - ln / 2, ty, z), M("navy"), bevel=0.05, segs=1, name="access_arm")
        railing((tx - TW / 2 - ln + 0.6, ty - 0.45, z + 0.2), (tx - TW / 2, ty - 0.45, z + 0.2), h=0.8, n=4,
                mat="mustard")
        box((1.4, 1.6, 1.6), (tx - TW / 2 - ln + 0.3, ty, z + 1.0), M("cream"), bevel=0.12, segs=1,
            name="white_room")
    tube([(tx - TW / 2, ty + 1.0, zb + 18.5), (rx + 2.2, ry + 1.0, zb + 17.0)], 0.15, chrome(), name="umbilical")
    # fuel tanks (mustard + ketchup) on saddles with pipes
    for i, (x, col) in enumerate(((13.0, "mustard"), (17.5, "ketchup"))):
        capsule(1.9, 10.0, (x, 4.0, zb + 2.6), M(col, rough=0.35), "Y", segs=20, name="fuel_tank")
        for y in (0.6, 7.4):
            box((3.2, 0.7, 1.2), (x, y, zb + 0.6), M("concrete_dark"), bevel=0.06, segs=1, name="saddle")
        for y in (0.2, 7.8):
            torus(1.92, 0.12, (x, y, zb + 2.6), M("navy"), rot=(rad(90), 0, 0), segs=24, rsegs=5, name="tank_band")
        tube([(x, -0.6, zb + 2.6), (x, -1.6, zb + 2.6), (x, -1.6, zb + 0.6), (tx + 2.2, -1.6, zb + 0.6),
              (tx + 2.2, ty - 1.2, zb + 0.6)], 0.18, chrome(), name="fuel_pipe")
        cyl(0.4, 0.15, (x, -1.6, zb + 1.9), M("ketchup" if col == "mustard" else "mustard"), verts=12,
            name="valve_wheel")
    sphere(2.6, (15.2, -6.8, zb + 4.3), M("cream"), segs=24, rings=14, name="sphere_tank")
    for a in range(4):
        ang = TAU * a / 4 + TAU / 8
        cyl(0.18, 3.4, (15.2 + 1.9 * math.cos(ang), -6.8 + 1.9 * math.sin(ang), zb + 1.7), M("steel"), verts=8,
            name="tank_leg")
    torus(2.62, 0.1, (15.2, -6.8, zb + 4.3), M("teal"), segs=28, rsegs=5, name="tank_equator")
    # blockhouse with blank sign
    bx, by = 5.0, -9.5
    box((8.0, 4.4, 3.4), (bx, by, zb + 1.7), M("cream"), bevel=0.4, segs=3, name="blockhouse")
    box((8.2, 4.6, 0.4), (bx, by, zb + 3.4), M("navy"), bevel=0.1, segs=1, name="blockhouse_roof")
    place(lambda: window(4.0, 0.9, frame="navy", cols=4, sill=False), (bx + 0.8, by - 2.2, zb + 2.2))
    place(lambda: door(1.3, 2.4, col="ketchup", frame="navy"), (bx - 2.6, by - 2.2, zb))
    for x in (bx - 3.0, bx + 3.0):
        box((0.3, 0.3, 1.4), (x, by + 0.6, zb + 4.3), M("navy"), bevel=0, name="sign_leg")
    place(lambda: sign_panel(8.5, 1.8, frame="ketchup", face="cream", bulbs=1), (bx, by + 0.6, zb + 6.0))
    box((1.6, 1.6, 1.0), (bx + 2.8, by + 1.0, zb + 4.1), chrome(), bevel=0.1, segs=1, name="antenna_box")
    for x in (-17.0, -1.0):
        lamp_post((x, -12.6, zb), h=5.0)


# @@PROPS@@

ASSETS_LIST = [
    ("HotDog", build_HotDog, (2, 0.8, 0.8)),
    ("Bun", build_Bun, (2, 0.8, 0.6)),
    ("HotDogStand", build_HotDogStand, (8, 5, 8)),
    ("CondimentStation", build_CondimentStation, (4, 3, 4)),
    ("BunRack", build_BunRack, (4, 2.5, 5)),
    ("CashRegister", build_CashRegister, (3, 2.5, 4)),
    ("Billboard", build_Billboard, (12, 1.5, 12)),
    ("IngredientRack", build_IngredientRack, (6, 3, 6)),
    ("IngredientCrate", build_IngredientCrate, (1.5, 1.5, 1.2)),
    ("DeliveryBike", build_DeliveryBike, (5, 2, 4)),
    ("DeliveryVan", build_DeliveryVan, (12, 6, 9)),
    ("DepotTruck", build_DepotTruck, (16, 7, 10)),
    ("TradingTicker", build_TradingTicker, (8, 3, 9)),
    ("LabMachine", build_LabMachine, (6, 4, 7)),
    ("KitchenRobot", build_KitchenRobot, (4, 3, 7)),
    ("RepublicMonument", build_RepublicMonument, (14, 14, 24)),
    ("HotDogRocket", build_HotDogRocket, (10, 10, 30)),
    ("Staircase", build_Staircase, (12, 12, 20)),
    ("CosmicPortal", build_CosmicPortal, (14, 3, 14)),
    ("AlienInvestor", build_AlienInvestor, (2.5, 2, 5)),
    ("MoneyBag", build_MoneyBag, (1.5, 1.5, 1.8)),
    ("VoidHotDog", build_VoidHotDog, (2, 0.8, 0.8)),
    # business buildings (front entrance faces -Y, blank sign panel for SurfaceGui text)
    ("DashShop", build_DashShop, (30, 18, 16)),
    ("DepotBuilding", build_DepotBuilding, (36, 20, 16)),
    ("TradingFloor", build_TradingFloor, (26, 18, 24)),
    ("LabBuilding", build_LabBuilding, (28, 18, 18)),
    ("RoboticsFactory", build_RoboticsFactory, (32, 20, 20)),
    ("RepublicCapitol", build_RepublicCapitol, (34, 22, 26)),
    ("LaunchSite", build_LaunchSite, (40, 28, 34)),
    # @@PROPLIST@@
]
FOOD = {"HotDog", "Bun", "VoidHotDog", "MoneyBag", "IngredientCrate"}


# ---------------------------------------------------------------- pipeline
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0


def finalize(name):
    """Convert everything to one mesh, ground it, bake vertex colours."""
    sc = bpy.context.scene
    objs = [o for o in sc.objects if o.type in ("MESH", "CURVE")]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")
    objs = [o for o in sc.objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = ob.data
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    off = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
    for v in me.vertices:
        v.co -= off
    bmesh_clean(me)
    bpy.ops.object.shade_smooth_by_angle(angle=rad(40))
    # bake material colour into a corner colour attribute
    col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    mats = me.materials
    for poly in me.polygons:
        m = mats[poly.material_index] if poly.material_index < len(mats) else None
        rgb = hex_rgb(m["hex"]) if m is not None and "hex" in m else (1, 1, 1)
        for li in poly.loop_indices:
            col.data[li].color_srgb = (*rgb, 1)
    me.color_attributes.active_color = col
    me.calc_loop_triangles()
    size = [max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)]
    return ob, size, len(me.loop_triangles), [m.name for m in mats]


def bmesh_clean(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()


def export(ob, name):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    fbx = os.path.join(DIRS["exports"], f"{name}.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y",
                             use_mesh_modifiers=True, mesh_smooth_type="FACE", colors_type="SRGB",
                             add_leaf_bones=False, bake_anim=False, path_mode="AUTO")
    obj = os.path.join(DIRS["exports"], f"{name}.obj")
    bpy.ops.wm.obj_export(filepath=obj, export_selected_objects=True, export_materials=True, export_colors=True,
                          forward_axis="NEGATIVE_Z", up_axis="Y", export_triangulated_mesh=False,
                          apply_modifiers=True)


def setup_render(ob, size, samples):
    sc = bpy.context.scene
    # world
    w = bpy.data.worlds.new("Sky")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*(srgb_to_lin(c) for c in hex_rgb("A9DCF5")), 1)
    bg.inputs["Strength"].default_value = 0.9
    # ground (preview only, not exported)
    R = max(size) * 60 + 100
    bpy.ops.mesh.primitive_plane_add(size=R, location=(0, 0, -0.001))
    g = bpy.context.active_object
    g.name = "_PreviewGround"
    gm = bpy.data.materials.new("_ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (
        *(srgb_to_lin(c) for c in hex_rgb("DCEFD2")), 1)
    gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    g.data.materials.append(gm)
    # sun
    sun_d = bpy.data.lights.new("Sun", "SUN")
    sun_d.energy = 3.2
    sun_d.angle = rad(12)
    sun = bpy.data.objects.new("Sun", sun_d)
    sc.collection.objects.link(sun)
    sun.rotation_euler = (rad(40), rad(-10), rad(-35))
    # camera 3/4 view from front-right (+X, -Y), framing the bounds
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.lens = 50
    cam = bpy.data.objects.new("Cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    center = Vector((0, 0, size[2] / 2))
    radius = 0.5 * math.sqrt(size[0] ** 2 + size[1] ** 2 + size[2] ** 2)
    fov = 2 * math.atan(18 / 50)
    dist = radius / math.sin(fov / 2) * 0.92
    d = Vector((0.85, -1.25, 0.6)).normalized()
    cam.location = center + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam_d.clip_end = dist * 10 + 100
    # engine
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.max_bounces = 6
    sc.cycles.transmission_bounces = 6
    try:
        sc.cycles.use_denoising = True
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        sc.cycles.use_denoising = False
    sc.render.resolution_x = 512
    sc.render.resolution_y = 512
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.render.image_settings.file_format = "PNG"


def build_one(name, fn, target, samples, render):
    t0 = time.time()
    reset()
    fn()
    ob, size, tris, mats = finalize(name)
    export(ob, name)
    if render:
        setup_render(ob, size, samples)
    bpy.context.preferences.filepaths.save_version = 0  # no .blend1 backups
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIRS["blender"], f"{name}.blend"), compress=True)
    t1 = time.time()
    if render:
        sc = bpy.context.scene
        sc.render.filepath = os.path.join(DIRS["renders"], f"{name}.png")
        bpy.ops.render.render(write_still=True)
    t2 = time.time()
    entry = {
        "size": [round(s, 3) for s in size],
        "target": list(target),
        "triangles": tris,
        "materials": mats,
        "files": {
            "blend": f"assets/blender/{name}.blend",
            "fbx": f"assets/exports/{name}.fbx",
            "obj": f"assets/exports/{name}.obj",
            "render": f"assets/renders/{name}.png",
        },
    }
    dev = [round(s / t - 1, 3) for s, t in zip(size, target)]
    print(f"[{name}] size={entry['size']} target={list(target)} dev={dev} tris={tris} "
          f"build={t1 - t0:.1f}s render={t2 - t1:.1f}s", flush=True)
    return entry


def contact_sheet():
    from PIL import Image, ImageDraw, ImageFont
    names = [n for n, _, _ in ASSETS_LIST if os.path.exists(os.path.join(DIRS["renders"], f"{n}.png"))]
    cols = 6
    cell = 256
    lab = 26
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGB", (cols * cell, rows * (cell + lab)), (250, 246, 236))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 16)
    except Exception:
        font = ImageFont.load_default()
    for i, n in enumerate(names):
        im = Image.open(os.path.join(DIRS["renders"], f"{n}.png")).convert("RGB").resize((cell, cell))
        x, y = (i % cols) * cell, (i // cols) * (cell + lab)
        sheet.paste(im, (x, y))
        d.text((x + 8, y + cell + 4), n, fill=(60, 40, 30), font=font)
    sheet.save(os.path.join(DIRS["renders"], "contact_sheet.png"))


def main():
    argv = sys.argv[1:]
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--no-render", action="store_true")
    a = ap.parse_args(argv)
    for d in DIRS.values():
        os.makedirs(d, exist_ok=True)
    only = {s.strip() for s in a.only.split(",") if s.strip()}
    man_path = os.path.join(DIRS["exports"], "manifest.json")
    manifest = {}
    if os.path.exists(man_path):
        with open(man_path) as f:
            manifest = json.load(f)
    manifest.pop("_meta", None)
    t0 = time.time()
    for name, fn, target in ASSETS_LIST:
        if only and name not in only:
            continue
        manifest[name] = build_one(name, fn, target, a.samples, not a.no_render)
    ordered = {"_meta": {"generator": "tools/blender/build_assets.py", "blender": bpy.app.version_string,
                         "units": "1 Blender unit = 1 Roblox stud; size is [X width, Y depth, Z height]",
                         "provenance": "original, procedurally generated, no third-party content"}}
    for name, _, _ in ASSETS_LIST:
        if name in manifest:
            ordered[name] = manifest[name]
    with open(man_path, "w") as f:
        json.dump(ordered, f, indent=2)
    if not a.no_render:
        contact_sheet()
    print(f"done in {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
