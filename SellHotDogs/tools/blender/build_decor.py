"""Decor, customer, sky and icon-prop builder for Sell Hot Dogs.

Companion to build_assets.py: it imports that module for the shared helpers
(palette, materials, primitives, finalize/export/preview pipeline) so every
model follows the same conventions (1 Blender unit = 1 stud, lowest point at
Z=0, centred on X/Y, front faces -Y, one joined mesh with a "Col" vertex-colour
bake, FBX/OBJ export, 512px Cycles preview). All geometry is original and
generated from code; no downloaded models or image textures.

Usage (from the SellHotDogs/ folder):
    python3 tools/blender/build_decor.py                    # build everything
    python3 tools/blender/build_decor.py --only Bench,Coin  # some assets
    python3 tools/blender/build_decor.py --samples 8        # faster previews
    python3 tools/blender/build_decor.py --no-render        # geometry + exports only

Outputs (relative to SellHotDogs/assets/):
    blender/<Name>.blend, exports/<Name>.fbx/.obj/.mtl, renders/<Name>.png
    renders/contact_sheet_decor.png
    exports/manifest_decor.json   (same schema as manifest.json)
"""

import argparse
import json
import math
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_assets as BA  # noqa: E402  (imports bpy)
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

M, box, cyl, sphere, lathe = BA.M, BA.box, BA.cyl, BA.sphere, BA.lathe
capsule, torus, tube, wedge_prism = BA.capsule, BA.torus, BA.tube, BA.wedge_prism
xform, track, hotdog, sausage_obj = BA.xform, BA.track, BA.hotdog, BA.sausage_obj
TAU, rad = BA.TAU, BA.rad
DIRS = BA.DIRS

# extra palette entries (added to the shared dict in this process only)
BA.PAL.update({
    "leaf": "5DB04A",
    "leaf_dark": "3B8C3A",
    "iron": "2F4A44",
    "soil": "6B4A2E",
    "water": "6CCFE8",
    "white": "FFFFFF",
    "cloud_shade": "D8E6F6",
    "bird": "4FA3E0",
    "bird_dark": "2F7BC0",
    "orange": "FF9A3C",
    "money": "5FB35A",
    "money_dark": "3F8A3D",
    "money_light": "C4E8A8",
    "gold_dark": "C98A1E",
    "gold_light": "FFE08A",
    "lamp": "FFE9A8",
    "denim": "4767A8",
    "skin_a": "F5C9A0",
    "skin_b": "8D5A3B",
    "skin_c": "E8B48A",
    "hair_brown": "6B4226",
    "hair_dark": "2E2420",
    "hoodie": "57B868",
    "dress": "FF8FB8",
    "shirt_a": "3FB6C9",
})


# ---------------------------------------------------------------- local helpers
def beam(p0, p1, w, mat, h=None, bevel=0.03, name="beam"):
    """Square beam between two points (w x h cross-section)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    o = box((w, h or w, d.length), (0, 0, 0), mat, bevel=bevel, name=name)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.location = (p0 + p1) / 2
    return o


def bloom(r, col, loc, rot=(0, 0, 0), centre="mustard", lobes=5):
    """Flat cartoon flower (lobed disc + centre bead) facing +Z, then placed."""
    bm = bmesh.new()
    n = lobes * 3
    top, bot = [], []
    for i in range(n):
        a = TAU * i / n
        rr = r * (0.62 + 0.38 * abs(math.cos(a * lobes / 2)))
        top.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), 0.06 * r)))
        bot.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), -0.06 * r)))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    petals = BA._obj_from_bm(bm, "bloom", M(col, rough=0.5))
    c = sphere(r * 0.32, (0, 0, 0.08 * r), M(centre), scale=(1, 1, 0.6), segs=8, rings=4, name="bloom_c")
    xform([petals, c], loc, rot)
    return [petals, c]


def striped_lathe(prof, mats, segs=24, loc=(0, 0, 0), mat_fn=None, name="slathe"):
    """Lathe (closed at both ends by single verts) with per-face materials.

    mat_fn(seg_index, ring_index) -> index into mats.
    """
    bm = bmesh.new()
    rings = []
    for r, z in prof:
        if r < 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(TAU * i / segs), r * math.sin(TAU * i / segs), z))
                          for i in range(segs)])
    for k, (a, b) in enumerate(zip(rings, rings[1:])):
        for i in range(segs):
            j = (i + 1) % segs
            if len(a) == 1:
                f = bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1:
                f = bm.faces.new((a[i], a[j], b[0]))
            else:
                f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.material_index = mat_fn(i, k) if mat_fn else i % len(mats)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = BA._obj_from_bm(bm, name, None, loc)
    for m in mats:
        ob.data.materials.append(m)
    return ob


def front_y(x, r, pad=0.0):
    """Y of the front (-Y) surface of a Z-axis cylinder of radius r at offset x."""
    return -math.sqrt(max(r * r - x * x, 0.0)) - pad


def eyes_smile(cx, fy, ez, sz, sp=0.2, er=0.1, sw=0.2, dark="black", lip="sausage_dark"):
    """Cartoon face on a flat front plane y=fy."""
    for s in (-1, 1):
        sphere(er, (cx + s * sp, fy - 0.02, ez), M(dark, rough=0.2), scale=(1, 0.5, 1.4), segs=10, rings=6,
               name="eye")
        sphere(er * 0.35, (cx + s * sp - 0.03, fy - 0.07, ez + er * 0.5), M("white", emit=0.3), segs=6, rings=4,
               name="glint")
    pts = []
    for k in range(9):
        t = rad(-60 + 15 * k)
        pts.append((cx + sw * math.sin(t), fy - 0.02, sz - sw * 0.5 * math.cos(t)))
    tube(pts, 0.035, M(lip), name="smile")


# ---------------------------------------------------------------- decor shop items
def build_Bench():
    iron = M("iron", rough=0.45, metal=0.3)
    for x in (-2.78, 2.78):
        tube([(x, -1.0, 0.1), (x, -0.95, 1.5)], 0.11, iron, name="front_leg")
        tube([(x, 0.95, 0.1), (x, 0.85, 1.5), (x, 0.92, 2.3), (x, 1.08, 3.3)], 0.11, iron, name="back_leg")
        tube([(x, -0.95, 1.5), (x, 0.85, 1.5)], 0.09, iron, name="seat_rail")
        tube([(x, -0.95, 1.5), (x, -1.08, 2.15), (x, -0.95, 2.35), (x, 0.88, 2.42)], 0.09, iron, name="arm")
        sphere(0.15, (x, -1.1, 2.2), iron, segs=10, rings=6, name="arm_knob")
        for y in (-1.0, 0.95):
            box((0.42, 0.55, 0.12), (x, y, 0.06), iron, bevel=0.04, segs=1, name="foot")
    for i, y in enumerate((-0.92, -0.48, -0.04, 0.4)):
        box((5.95, 0.4, 0.13), (0, y, 1.62), M("wood" if i % 2 == 0 else "peach"), bevel=0.05, segs=2,
            name="seat_slat")
    for i, z in enumerate((2.05, 2.5, 2.95)):
        y = 0.86 + (z - 1.5) / 1.8 * 0.22
        box((5.95, 0.12, 0.36), (0, y, z), M("wood" if i % 2 == 0 else "peach"), rot=(rad(-8), 0, 0),
            bevel=0.04, segs=2, name="back_slat")
    box((6.05, 0.16, 0.26), (0, 1.12, 3.37), M("ketchup"), rot=(rad(-8), 0, 0), bevel=0.06, segs=2,
        name="top_rail")
    box((1.0, 0.05, 0.24), (0, 0.86, 2.5), M("gold", metal=0.6, rough=0.35), rot=(rad(-8), 0, 0), bevel=0.02,
        segs=1, name="plaque")


def build_PicnicTable():
    W = 7.0
    for i, y in enumerate((-1.04, -0.52, 0.0, 0.52, 1.04)):
        box((W, 0.5, 0.18), (0, y, 2.2), M("wood" if i % 2 == 0 else "peach"), bevel=0.05, segs=2, name="plank")
    for s in (-1, 1):
        for k, y in enumerate((2.3, 2.76)):
            box((W - 0.4, 0.44, 0.16), (0, s * y, 1.32), M("wood" if k == 0 else "peach"), bevel=0.05, segs=2,
                name="bench")
    for x in (-2.5, 2.5):
        for s in (-1, 1):
            beam((x, s * 2.7, 0.0), (x, s * 0.45, 2.12), 0.24, M("wood_dark"), name="leg")
        beam((x, -3.0, 1.15), (x, 3.0, 1.15), 0.22, M("wood_dark"), name="cross")
        beam((x, -1.3, 2.03), (x, 1.3, 2.03), 0.2, M("wood_dark"), name="cleat")
    # gingham runner
    n = 14
    for i in range(n):
        for j in range(3):
            box((0.4, 0.4, 0.02), (-2.6 + i * 0.4, -0.4 + j * 0.4, 2.3), M("ketchup" if (i + j) % 2 else "cream"),
                bevel=0, name="check")
    # bottles
    for x, y, col, cap in ((-1.2, 0.25, "ketchup", "cream"), (-0.75, -0.1, "mustard", "ketchup")):
        lathe([(0, 0), (0.2, 0), (0.23, 0.08), (0.23, 0.42), (0.17, 0.56), (0.07, 0.62), (0, 0.62)],
              M(col, rough=0.35), loc=(x, y, 2.31), segs=16, name="bottle")
        cyl(0.09, 0.08, (x, y, 2.97), M(cap), verts=10, name="cap")
        cyl(0.05, 0.14, (x, y, 3.08), M(cap), r2=0.015, verts=8, name="nozzle")
        box((0.32, 0.04, 0.2), (x, y - 0.23, 2.55), M("cream" if col != "cream" else "ketchup"), bevel=0.01,
            segs=1, name="label")
    # plate with a hot dog
    cyl(0.55, 0.06, (1.1, 0.0, 2.33), M("white"), r2=0.62, verts=20, name="plate")
    xform(hotdog(lod=0.5), (1.1, 0.0, 2.37), (0, 0, rad(-15)), 0.5)


def build_PatioUmbrella():
    n = 12
    apex, mid, rim = (0.0, 7.55), (1.9, 7.0), (3.45, 6.2)
    for i in range(n):
        a0, a1 = TAU * i / n, TAU * (i + 1) / n
        am = (a0 + a1) / 2
        bm = bmesh.new()

        def v(r, z, a):
            return bm.verts.new((r * math.cos(a), r * math.sin(a), z))
        ap = v(0, apex[1], 0)
        m0, m1 = v(mid[0], mid[1], a0), v(mid[0], mid[1], a1)
        r0, r1 = v(rim[0], rim[1], a0), v(rim[0], rim[1], a1)
        tip = v(rim[0] + 0.02, rim[1] - 0.45, am)
        bm.faces.new((ap, m0, m1))
        bm.faces.new((m0, r0, r1, m1))
        bm.faces.new((r0, tip, r1))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = BA._obj_from_bm(bm, "gore", M("ketchup" if i % 2 else "cream"))
        sol = ob.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.06
    for i in range(6):
        a = TAU * i / 6 + TAU / 24
        tube([(0, 0, 6.6), (3.1 * math.cos(a), 3.1 * math.sin(a), 6.25)], 0.035,
             M("chrome", metal=0.4, rough=0.4), name="rib")
    cyl(0.1, 7.6, (0, 0, 3.8), M("wood_dark"), verts=10, name="pole")
    cyl(0.18, 0.25, (0, 0, 7.6), M("ketchup"), verts=12, name="hub")
    sphere(0.17, (0, 0, 7.82), M("gold", metal=0.6, rough=0.35), segs=10, rings=6, name="finial")
    cyl(0.75, 0.2, (0, 0, 0.1), M("tire"), verts=20, bevel=0.05, name="base")
    # round table
    cyl(1.45, 0.12, (0, 0, 2.4), M("cream"), verts=28, bevel=0.03, name="table_top")
    torus(1.45, 0.07, (0, 0, 2.4), M("teal"), segs=28, rsegs=6, name="table_edge")
    for i in range(4):
        a = TAU * i / 4 + TAU / 8
        tube([(0.85 * math.cos(a), 0.85 * math.sin(a), 2.35), (1.05 * math.cos(a), 1.05 * math.sin(a), 0.05)],
             0.06, M("chrome", metal=0.4, rough=0.4), name="table_leg")
    torus(0.95, 0.04, (0, 0, 0.9), M("chrome", metal=0.4, rough=0.4), segs=20, rsegs=5, name="table_ring")
    # two chairs facing the table
    for s in (-1, 1):
        cx = s * 2.4
        box((1.0, 1.0, 0.12), (cx, 0, 1.45), M("teal"), bevel=0.04, name="chair_seat")
        for dx in (-0.4, 0.4):
            for dy in (-0.4, 0.4):
                cyl(0.05, 1.42, (cx + dx, dy, 0.71), M("chrome", metal=0.4, rough=0.4), verts=8, name="chair_leg")
        bx = cx + s * 0.47
        for dy in (-0.4, 0.4):
            cyl(0.05, 1.2, (bx, dy, 2.05), M("chrome", metal=0.4, rough=0.4), verts=8, name="chair_post")
        box((0.1, 1.0, 0.5), (bx, 0, 2.45), M("teal"), bevel=0.04, name="chair_back")
    # a hot dog on the table
    xform(hotdog(lod=0.5), (0.5, -0.5, 2.46), (0, 0, rad(20)), 0.45)


def build_LampPost():
    iron = M("iron", rough=0.45, metal=0.3)
    gold = M("gold", metal=0.6, rough=0.35)
    lathe([(0, 0), (0.74, 0), (0.74, 0.22), (0.6, 0.3), (0.52, 0.8), (0.34, 1.15), (0.24, 1.5), (0, 1.5)],
          iron, segs=8, rot=(0, 0, rad(22.5)), name="base")
    cyl(0.13, 6.7, (0, 0, 1.5 + 3.35), iron, verts=12, name="pole")
    for z in (1.55, 4.6, 8.15):
        torus(0.15, 0.05, (0, 0, z), gold, segs=14, rsegs=5, name="ring")
    lathe([(0.13, 0), (0.22, 0.15), (0.42, 0.35), (0.45, 0.45), (0, 0.45)], iron, loc=(0, 0, 8.1), segs=12,
          name="collar")
    # scrolls under the lantern
    for i in range(4):
        a = TAU * i / 4 + TAU / 8
        c, s = math.cos(a), math.sin(a)
        pts = []
        for k in range(9):
            t = k / 8
            r = 0.15 + 0.4 * math.sin(t * math.pi * 0.9)
            pts.append((r * c, r * s, 7.4 + t * 1.0))
        tube(pts, 0.035, iron, name="scroll")
    # lantern: tapered square glass body, frame posts, pyramid roof
    z0 = 8.55
    lathe([(0.32, 0), (0.55, 0.9), (0.0, 0.9)], M("lamp", emit=2.0), loc=(0, 0, z0), segs=4,
          rot=(0, 0, rad(45)), name="glass")
    lathe([(0, 0), (0.36, 0), (0.36, 0.08), (0, 0.08)], iron, loc=(0, 0, z0 - 0.06), segs=4, rot=(0, 0, rad(45)),
          name="lantern_floor")
    for i in range(4):
        a = TAU * i / 4 + TAU / 8
        p0 = (0.33 * math.cos(a) * 1.414 / 1.414, 0.33 * math.sin(a), z0)
        tube([(0.45 * math.cos(a), 0.45 * math.sin(a), z0), (0.78 * math.cos(a), 0.78 * math.sin(a), z0 + 0.9)],
             0.04, iron, name="frame")
    lathe([(0, 0), (0.75, 0), (0.75, 0.08), (0.2, 0.42), (0.1, 0.46), (0, 0.46)], iron, loc=(0, 0, z0 + 0.88),
          segs=4, rot=(0, 0, rad(45)), name="roof")
    sphere(0.11, (0, 0, z0 + 1.38), gold, segs=10, rings=6, name="finial")
    cyl(0.03, 0.15, (0, 0, z0 + 1.28), gold, verts=6, name="finial_stem")


def build_StringLights():
    cols = ["mustard", "ketchup", "relish", "teal", "pink", "peach"]
    span = 6.55
    for x in (-span, span):
        box((1.0, 1.0, 0.5), (x, 0, 0.25), M("stone_dark"), bevel=0.08, name="footing")
        box((0.8, 0.8, 0.12), (x, 0, 0.56), M("ketchup"), bevel=0.04, name="footing_trim")
        box((0.28, 0.28, 8.1), (x, 0, 0.6 + 4.05), M("wood_dark"), bevel=0.05, name="pole")
        lathe([(0, 0), (0.24, 0), (0.24, 0.06), (0.0, 0.3)], M("ketchup"), loc=(x, 0, 8.7), segs=4,
              rot=(0, 0, rad(45)), name="cap")
        tube([(x, 0, 8.45), (x - math.copysign(0.25, x), 0, 8.45)], 0.04, M("chrome", metal=0.5), name="hook")
    top = 8.45
    sag = 1.6
    xe = span - 0.25
    pts = []
    for i in range(31):
        x = -xe + 2 * xe * i / 30
        pts.append((x, 0, top - sag * (1 - (x / xe) ** 2)))
    tube(pts, 0.035, M("tire"), name="wire")
    n = 13
    for i in range(n):
        x = -xe + 2 * xe * (i + 0.5) / n
        z = top - sag * (1 - (x / xe) ** 2)
        cyl(0.08, 0.18, (x, 0, z - 0.1), M("tire"), verts=8, name="socket")
        sphere(0.19, (x, 0, z - 0.36), M(cols[i % len(cols)], emit=2.0), scale=(1, 1, 1.3), segs=10, rings=6,
               name="bulb")


def build_Fountain():
    stone, stone_d = M("stone"), M("stone_dark")
    water = M("water", rough=0.08)
    lathe([(0, 0), (5.0, 0), (5.0, 1.0), (4.85, 1.2), (4.45, 1.2), (4.35, 1.0), (4.35, 0.3), (0, 0.3)], stone,
          segs=32, name="basin")
    cyl(5.04, 0.28, (0, 0, 0.55), M("teal"), verts=32, name="tile_band")
    for i in range(16):
        a = TAU * (i + 0.5) / 16
        box((0.45, 0.08, 0.18), (5.06 * math.cos(a), 5.06 * math.sin(a), 0.55), M("cream"),
            rot=(0, 0, a + math.pi / 2), bevel=0, name="tile")
    cyl(4.38, 0.1, (0, 0, 0.85), water, verts=32, name="water")
    random.seed(3)
    for i in range(6):
        a, r = random.uniform(0, TAU), random.uniform(2.6, 3.9)
        cyl(0.18, 0.04, (r * math.cos(a), r * math.sin(a), 0.92), M("gold", metal=0.6, rough=0.3), verts=12,
            name="coin")
    # ripples
    for r in (2.4, 3.3):
        torus(r, 0.04, (0, 0, 0.9), M("white", emit=0.2), segs=28, rsegs=3, name="ripple")
    lathe([(0, 0), (1.25, 0), (1.25, 0.3), (0.75, 0.5), (0.5, 1.3), (0.62, 1.85), (0, 1.85)], stone_d,
          loc=(0, 0, 0.85), segs=24, name="pedestal")
    lathe([(0, 0), (0.6, 0), (1.85, 0.45), (2.1, 0.72), (1.98, 0.82), (1.8, 0.62), (0, 0.56)], stone,
          loc=(0, 0, 2.6), segs=32, name="bowl")
    cyl(1.8, 0.08, (0, 0, 3.24), water, verts=32, name="bowl_water")
    cyl(0.5, 0.4, (0, 0, 3.45), M("gold", metal=0.6, rough=0.35), verts=16, bevel=0.04, name="statue_base")
    xform(hotdog(lod=0.7), (0, 0.52, 3.65 + 1.5), (0, rad(-90), rad(90)), 1.5)
    # spout arcs from the statue top into the upper bowl
    wmat = M("water", emit=0.3, rough=0.08)
    for i in range(4):
        a = TAU * i / 4 + TAU / 8
        pts = []
        for k in range(11):
            t = k / 10
            r = 1.65 * t
            pts.append((r * math.cos(a), r * math.sin(a), 6.8 + 1.0 * t - 4.5 * t * t))
        tube(pts, 0.07, wmat, name="spout")
    sphere(0.22, (0, 0, 6.82), wmat, segs=10, rings=6, name="spout_top")
    # cascades from the bowl into the basin
    for i in range(8):
        a = TAU * i / 8
        pts = []
        for k in range(9):
            t = k / 8
            r = 2.05 + 1.0 * t
            pts.append((r * math.cos(a), r * math.sin(a), 3.32 + 0.25 * t - 2.62 * t * t))
        tube(pts, 0.06, wmat, name="cascade")
        sphere(0.16, (3.05 * math.cos(a), 3.05 * math.sin(a), 0.92), M("white", emit=0.2), scale=(1, 1, 0.5),
               segs=8, rings=4, name="splash")


def build_HotDogStatue():
    stone, stone_d = M("stone"), M("stone_dark")
    gold = M("gold", metal=0.6, rough=0.35)
    box((5.0, 5.0, 0.6), (0, 0, 0.3), stone_d, bevel=0.1, name="step")
    box((4.2, 4.2, 0.6), (0, 0, 0.9), stone, bevel=0.1, name="step2")
    box((3.2, 3.2, 2.4), (0, 0, 2.4), stone, bevel=0.14, segs=3, name="plinth")
    box((3.6, 3.6, 0.32), (0, 0, 3.76), gold, bevel=0.06, name="cornice")
    box((2.2, 0.08, 1.0), (0, -1.62, 2.4), gold, bevel=0.03, name="plaque")
    box((1.9, 0.04, 0.75), (0, -1.66, 2.4), M("ketchup"), bevel=0.02, name="plaque_inner")
    xform(hotdog(lod=0.5), (0, -1.69, 2.25), (rad(90), 0, 0), (0.75, 0.75, 0.2))
    z0 = 3.92
    for s in (-1, 1):
        capsule(0.3, 1.0, (s * 0.45, -0.2, z0 + 0.24), M("ketchup"), "Y", scale=(1, 1, 0.8), segs=12, name="shoe")
        cyl(0.2, 0.9, (s * 0.45, 0, z0 + 0.75), M("sausage_dark"), verts=12, name="leg")
    # body: sausage hugged by two bun halves
    r = 0.9
    capsule(r, 7.0, (0, 0, z0 + 1.0 + 3.5), M("sausage", rough=0.45), "Z", segs=20, steps=5, name="body")
    for s in (-1, 1):
        capsule(0.62, 5.0, (s * 0.98, 0.12, z0 + 1.1 + 2.5), M("bun"), "Z", scale=(1, 1.3, 1), segs=16,
                name="bun")
    capsule(0.55, 1.9, (0, 0.62, z0 + 1.2), M("bun"), "X", scale=(1, 0.9, 0.7), segs=14, name="bun_base")
    # face
    ez, sz = z0 + 6.95, z0 + 6.35
    for s in (-1, 1):
        x = s * 0.33
        sphere(0.29, (x, front_y(x, r, -0.08), ez), M("white"), scale=(1, 0.45, 1.25), segs=14, rings=8,
               name="eye_white")
        x2 = s * 0.3
        sphere(0.16, (x2, front_y(x2, r, 0.03), ez - 0.04), M("black", rough=0.2), scale=(1, 0.45, 1.3), segs=10,
               rings=6, name="pupil")
        sphere(0.05, (x2 - 0.05, front_y(x2, r, 0.1), ez + 0.06), M("white", emit=0.4), segs=6, rings=4,
               name="glint")
        x3 = s * 0.6
        sphere(0.17, (x3, front_y(x3, r, -0.04), sz + 0.08), M("pink"), scale=(1, 0.4, 0.7), segs=10, rings=5,
               name="cheek")
        box((0.3, 0.06, 0.07), (s * 0.34, front_y(s * 0.34, r, 0.0), ez + 0.42), M("sausage_dark"),
            rot=(0, s * rad(-12), 0), bevel=0.02, segs=1, name="brow")
    pts = []
    for k in range(11):
        t = rad(-70 + 14 * k)
        x = 0.4 * math.sin(t)
        pts.append((x, front_y(x, r, 0.02), sz - 0.2 * math.cos(t)))
    tube(pts, 0.065, M("sausage_dark"), name="smile")
    # mustard squiggle down the belly
    pts = []
    for k in range(25):
        t = k / 24
        x = 0.28 * math.sin(t * math.pi * 6)
        pts.append((x, front_y(x, r, 0.04), z0 + 5.6 - 4.0 * t))
    tube(pts, 0.1, M("mustard", rough=0.35), name="mustard")
    # arms: left waving, right on hip
    arm = M("sausage", rough=0.45)
    tube([(-1.45, 0, z0 + 4.8), (-2.0, -0.15, z0 + 5.6), (-2.05, -0.3, z0 + 6.5)], 0.17, arm, name="arm_l")
    sphere(0.32, (-2.05, -0.32, z0 + 6.8), M("white"), segs=14, rings=8, name="glove")
    for k in range(3):
        capsule(0.08, 0.36, (-2.15 + k * 0.12, -0.36, z0 + 7.12), M("white"), "Z", segs=8, steps=2, name="finger")
    tube([(1.45, 0, z0 + 4.6), (2.05, -0.1, z0 + 4.0), (1.65, -0.25, z0 + 3.25)], 0.17, arm, name="arm_r")
    sphere(0.3, (1.6, -0.25, z0 + 3.15), M("white"), segs=14, rings=8, name="glove")


def build_BalloonBunch():
    lathe([(0, 0), (0.45, 0), (0.5, 0.1), (0.44, 0.48), (0.22, 0.64), (0.12, 0.74), (0, 0.76)], M("ketchup"),
          segs=16, name="weight")
    cyl(0.48, 0.12, (0, 0, 0.27), M("mustard"), verts=16, name="weight_band")
    torus(0.1, 0.03, (0, 0, 0.86), M("gold", metal=0.5), rot=(rad(90), 0, 0), segs=10, rsegs=4, name="loop")
    anchor = Vector((0, 0, 0.9))
    balls = [((0.0, 0.05, 9.2), "ketchup"), ((-0.85, 0.15, 8.6), "teal"), ((0.85, -0.05, 8.65), "mustard"),
             ((-0.35, -0.75, 8.0), "pink"), ((0.45, 0.75, 8.1), "relish"), ((0.55, -0.55, 7.35), "violet"),
             ((-0.6, 0.6, 7.45), "orange")]
    for (x, y, z), col in balls:
        rr = 0.62
        sphere(rr, (x, y, z), M(col, rough=0.25), scale=(1, 1, 1.18), segs=16, rings=10, name="balloon")
        cyl(0.1, 0.12, (x, y, z - rr * 1.18 - 0.02), M(col, rough=0.25), r2=0.03, verts=8, name="knot")
        sphere(0.11, (x - 0.22, y - 0.5, z + 0.3), M("white", emit=0.4), scale=(1, 0.45, 1.6), segs=8, rings=4,
               name="shine")
        b = Vector((x, y, z - rr * 1.18 - 0.08))
        mid = anchor.lerp(b, 0.55) + Vector((0.12 * math.sin(x * 5), 0.12 * math.cos(y * 5), 0))
        tube([tuple(b), tuple(mid), tuple(anchor)], 0.018, M("cream"), name="string")
    # ribbon curls on the weight
    pts = [(0.08 * math.cos(t * 0.9) + 0.03 * t, -0.05 - 0.04 * t, 0.86 - 0.03 * t) for t in range(10)]
    tube(pts, 0.02, M("cream"), name="ribbon")


def build_FlowerArch():
    leaf, leaf_d = M("leaf"), M("leaf_dark")
    R, cz = 4.15, 5.3
    for s in (-1, 1):
        x = s * R
        box((1.8, 3.0, 1.1), (x, 0, 0.55), M("wood"), bevel=0.08, name="planter")
        box((2.0, 3.2, 0.18), (x, 0, 1.15), M("wood_dark"), bevel=0.05, name="planter_rim")
        box((1.82, 0.06, 0.3), (x, -1.51, 0.55), M("ketchup"), bevel=0.02, segs=1, name="planter_band")
        for dy in (-0.85, 0.85):
            sphere(0.75, (x, dy, 1.45), leaf_d, scale=(1, 1, 0.75), segs=10, rings=6, name="bush")
        for dy in (-0.45, 0.45):
            tube([(x - 0.45, dy, 1.2), (x - 0.45, dy, cz)], 0.06, M("cream"), name="trellis_post")
            tube([(x + 0.45, dy, 1.2), (x + 0.45, dy, cz)], 0.06, M("cream"), name="trellis_post")
    # trellis arcs + rungs
    for dy in (-0.45, 0.45):
        pts = [(R * math.cos(math.pi * k / 16), dy, cz + R * math.sin(math.pi * k / 16)) for k in range(17)]
        tube(pts, 0.06, M("cream"), name="trellis_arc")
    # leafy garland: up one pillar, over the arch, down the other
    path = [(-R, 0, 1.3 + (cz - 1.3) * k / 4) for k in range(4)]
    path += [(-R * math.cos(math.pi * k / 18), 0, cz + R * math.sin(math.pi * k / 18)) for k in range(19)]
    path += [(R, 0, cz - (cz - 1.3) * k / 4) for k in range(1, 5)]
    tube(path, 0.4, leaf, name="garland")
    # flowers along the garland, front and back
    cols = ["pink", "ketchup", "mustard", "cream", "lavender", "peach"]
    k = 0
    samples = []
    for t in [i / 13 for i in range(14)]:
        a = math.pi * t
        samples.append((-R * math.cos(a), cz + R * math.sin(a)))
    for z in (2.2, 3.4, 4.5):
        samples += [(-R, z), (R, z)]
    for (x, z) in samples:
        bloom(0.46, cols[k % len(cols)], (x, -0.42, z), (rad(90), 0, rad(15 * k)))
        k += 1
        if k % 3 == 0:
            bloom(0.4, cols[(k + 2) % len(cols)], (x * 1.04, 0.4, z + 0.05), (rad(-90), 0, 0))
    # hanging sign
    sy = 7.25
    for x in (-0.9, 0.9):
        tube([(x, -0.1, cz + R - 0.3), (x, -0.1, sy + 0.4)], 0.025, M("chrome", metal=0.5), name="chain")
    box((2.6, 0.14, 0.85), (0, -0.1, sy), M("ketchup"), bevel=0.06, name="sign_frame")
    box((2.3, 0.05, 0.62), (0, -0.19, sy), M("cream"), bevel=0.02, segs=1, name="sign_face")
    xform(hotdog(lod=0.45), (0, -0.23, sy - 0.12), (rad(90), 0, 0), (0.75, 0.75, 0.2))


def build_HotDogTopiary():
    box((7.6, 2.8, 1.3), (0, 0, 0.75), M("wood"), bevel=0.1, segs=2, name="planter")
    box((7.75, 2.95, 0.2), (0, 0, 1.4), M("wood_dark"), bevel=0.06, name="rim")
    for x in (-3.4, 3.4):
        for y in (-1.1, 1.1):
            box((0.5, 0.5, 0.12), (x, y, 0.06), M("wood_dark"), bevel=0.03, segs=1, name="foot")
    for i in range(7):
        box((0.06, 0.04, 1.0), (-3.0 + i, -1.41, 0.75), M("wood_dark"), bevel=0, name="slat_line")
    box((7.3, 2.5, 0.1), (0, 0, 1.47), M("soil"), bevel=0, name="soil")
    xform(hotdog(lod=1.0, bun="leaf_dark", sausage="leaf", mustard="mustard", ketchup="pink", inner="leaf_dark"),
          (0, 0, 1.42), (0, 0, 0), (3.6, 3.0, 4.4))
    for i, x in enumerate((-2.6, -1.5, -0.3, 0.9, 2.1)):
        bloom(0.3, ("pink", "cream", "mustard")[i % 3], (x, -1.18, 2.35 + 0.15 * (i % 2)), (rad(80), 0, 0))
    for x in (-3.2, 3.2):
        sphere(0.45, (x, -0.9, 1.65), M("leaf"), scale=(1, 1, 0.6), segs=10, rings=6, name="shrub")


def build_NeonSign():
    box((1.9, 1.9, 0.5), (0, 0, 0.25), M("stone_dark"), bevel=0.08, name="base")
    box((1.3, 1.3, 0.4), (0, 0, 0.7), M("stone"), bevel=0.06, name="base2")
    cyl(0.2, 6.0, (0, 0, 0.9 + 3.0), M("chrome", metal=0.5, rough=0.35), verts=14, name="pole")
    for z in (2.2, 4.2):
        cyl(0.27, 0.18, (0, 0, z), M("ketchup"), verts=14, bevel=0.03, name="pole_ring")
    cx, cz, bw, bh = 0.3, 8.8, 2.6, 4.6
    box((bw, 0.6, bh), (cx, 0, cz), M("teal_dark"), bevel=0.2, segs=3, name="board")
    box((bw - 0.4, 0.05, bh - 0.4), (cx, -0.3, cz), M("navy"), bevel=0.02, segs=1, name="face")
    # bulbs around the board edge
    per = []
    hw, hh = bw / 2 - 0.1, bh / 2 - 0.1
    for i in range(6):
        per.append((cx - hw + 2 * hw * i / 5, cz + hh))
        per.append((cx - hw + 2 * hw * i / 5, cz - hh))
    for i in range(1, 9):
        per.append((cx - hw, cz - hh + 2 * hh * i / 9))
        per.append((cx + hw, cz - hh + 2 * hh * i / 9))
    for x, z in per:
        sphere(0.09, (x, -0.31, z), M("lamp", emit=2.5), segs=6, rings=4, name="bulb")
    neon_y = -0.36
    # neon hot dog
    def stadium(w, h, x0, z0, n=10):
        pts = []
        r = h / 2
        for k in range(n + 1):
            a = -math.pi / 2 + math.pi * k / n
            pts.append((x0 + w / 2 - r + r * math.cos(a), neon_y, z0 + r * math.sin(a)))
        for k in range(n + 1):
            a = math.pi / 2 + math.pi * k / n
            pts.append((x0 - w / 2 + r + r * math.cos(a), neon_y, z0 + r * math.sin(a)))
        pts.append(pts[0])
        return pts
    tube(stadium(1.75, 0.38, cx, 10.15), 0.06, M("ketchup", emit=3.0), name="neon_sausage")
    tube(stadium(1.5, 0.62, cx, 10.0), 0.07, M("mustard", emit=3.0), name="neon_bun")
    pts = [(cx - 0.6 + 1.2 * k / 12, neon_y - 0.04, 10.3 + 0.06 * math.sin(k * math.pi / 2)) for k in range(13)]
    tube(pts, 0.04, M("mint", emit=3.0), name="neon_squiggle")
    # neon letters E A T
    lm = M("pink", emit=3.0)
    lw, lh = 0.6, 0.62

    def letter(ch, x0, zb):
        l, r_, c = x0 - lw / 2, x0 + lw / 2, x0
        t, m = zb + lh, zb + lh / 2
        if ch == "E":
            tube([(r_, neon_y, t), (l, neon_y, t), (l, neon_y, zb), (r_, neon_y, zb)], 0.06, lm, name="E")
            tube([(l, neon_y, m), (r_ - 0.12, neon_y, m)], 0.06, lm, name="E_mid")
        elif ch == "A":
            tube([(l, neon_y, zb), (c, neon_y, t), (r_, neon_y, zb)], 0.06, lm, name="A")
            tube([(l + 0.15, neon_y, m - 0.06), (r_ - 0.15, neon_y, m - 0.06)], 0.06, lm, name="A_bar")
        elif ch == "T":
            tube([(l, neon_y, t), (r_, neon_y, t)], 0.06, lm, name="T")
            tube([(c, neon_y, t), (c, neon_y, zb)], 0.06, lm, name="T_stem")
    for i, ch in enumerate("EAT"):
        letter(ch, cx, 8.75 - i * 0.92)
    # header + hot dog on top
    box((3.0, 0.75, 0.5), (cx, 0, cz + bh / 2 + 0.2), M("ketchup"), bevel=0.15, segs=2, name="header")
    xform(hotdog(lod=0.6), (cx, 0, cz + bh / 2 + 0.45), (0, 0, 0), 0.75)
    # big arrow pointing down-left, studded with bulbs
    p0, p1 = Vector((1.55, 6.65)), Vector((-1.95, 5.35))
    d = (p1 - p0).normalized()
    nrm = Vector((-d.y, d.x))
    hl, sw, hw2 = 0.95, 0.27, 0.62
    neck = p1 - d * hl
    poly = [p0 + nrm * sw, neck + nrm * sw, neck + nrm * hw2, p1, neck - nrm * hw2, neck - nrm * sw, p0 - nrm * sw]
    wedge_prism([(v.x, v.y) for v in poly], 0.35, M("ketchup"), loc=(0, -0.55, 0), bevel=0.06, name="arrow")
    for k in range(8):
        q = p0.lerp(neck, (k + 0.5) / 8)
        sphere(0.08, (q.x, -0.76, q.y), M("lamp", emit=2.5), segs=6, rings=4, name="arrow_bulb")
    for q in (neck + nrm * 0.4, neck - nrm * 0.4, p1 - d * 0.3):
        sphere(0.08, (q.x, -0.76, q.y), M("lamp", emit=2.5), segs=6, rings=4, name="arrow_bulb")
    tube([(0.0, -0.1, 6.0), (0.0, -0.45, 6.05)], 0.06, M("chrome", metal=0.5), name="arrow_bracket")


def build_Planter():
    box((5.6, 1.6, 1.1), (0, 0, 0.7), M("wood"), bevel=0.06, segs=2, name="box")
    for z in (0.45, 0.85):
        for s in (-1, 1):
            box((5.6, 0.04, 0.05), (0, s * 0.81, z), M("wood_dark"), bevel=0, name="groove")
    for x in (-2.85, 2.85):
        for y in (-0.85, 0.85):
            box((0.3, 0.3, 1.3), (x, y, 0.65), M("wood_dark"), bevel=0.05, name="post")
            sphere(0.13, (x, y, 1.33), M("wood_dark"), segs=8, rings=5, name="post_knob")
    box((6.0, 2.0, 0.14), (0, 0, 1.25), M("wood_dark"), bevel=0.04, name="rim")
    box((1.8, 0.04, 0.45), (0, -0.82, 0.68), M("cream"), bevel=0.02, segs=1, name="label")
    xform(hotdog(lod=0.45), (0, -0.85, 0.6), (rad(90), 0, 0), (0.6, 0.6, 0.15))
    box((5.4, 1.5, 0.1), (0, 0, 1.3), M("soil"), bevel=0, name="soil")
    for i in range(6):
        sphere(0.5, (-2.3 + i * 0.92, 0.3 * (1 if i % 2 else -1), 1.45), M("leaf_dark"), scale=(1, 1, 0.65),
               segs=10, rings=6, name="leafy")
    cols = ["pink", "mustard", "ketchup", "cream", "lavender", "orange"]
    for i in range(10):
        x = -2.35 + i * 0.52
        y = -0.35 if i % 2 else 0.3
        h = 1.95 + 0.25 * ((i * 7) % 3) / 2
        tube([(x, y, 1.3), (x + 0.04, y - 0.05, h)], 0.035, M("relish"), name="stem")
        sphere(0.12, (x + 0.12, y - 0.05, 1.3 + (h - 1.3) * 0.5), M("relish"), scale=(1.6, 0.6, 0.5), segs=6,
               rings=4, name="leaf")
        bloom(0.28, cols[i % len(cols)], (x + 0.04, y - 0.06, h + 0.04), (rad(45), 0, rad(10 * i)))


# ---------------------------------------------------------------- customers
def person(skin, shirt, pants, shoes, style):
    # shoes + legs
    for s in (-1, 1):
        box((0.55, 0.85, 0.32), (s * 0.33, -0.08, 0.16), M(shoes), bevel=0.12, segs=2, name="shoe")
        box((0.57, 0.04, 0.12), (s * 0.33, -0.08, 0.06), M("white"), bevel=0, name="sole")
    leg_col = skin if style == "B" else pants
    for s in (-1, 1):
        box((0.52, 0.58, 1.75), (s * 0.33, 0.05, 0.3 + 0.875), M(leg_col), bevel=0.1, segs=2, name="leg")
    if style != "B":
        box((1.32, 0.66, 0.4), (0, 0.05, 2.02), M(pants), bevel=0.1, segs=2, name="hips")
    # torso
    box((1.35, 0.72, 1.7), (0, 0.05, 2.95), M(shirt), bevel=0.18, segs=2, name="torso")
    cyl(0.22, 0.2, (0, 0.05, 3.85), M(skin), verts=12, name="neck")
    # head
    hz = 4.45
    box((1.05, 0.95, 1.02), (0, 0.05, hz), M(skin), bevel=0.3, segs=3, name="head")
    fy = 0.05 - 0.475
    eyes_smile(0, fy, hz + 0.08, hz - 0.18, sp=0.21, er=0.1, sw=0.18, lip="sausage_dark")
    for s in (-1, 1):
        sphere(0.11, (s * 0.33, fy - 0.0, hz - 0.12), M("pink"), scale=(1, 0.35, 0.65), segs=8, rings=4,
               name="cheek")
        box((0.2, 0.05, 0.06), (s * 0.22, fy - 0.01, hz + 0.32), M("hair_dark"), rot=(0, s * rad(-8), 0), bevel=0,
            name="brow")
    return hz, fy


def arm(side, sleeve, skin, rot=(0, 0, 0), long_sleeve=False):
    """Arm hanging from the shoulder (built at origin then rotated)."""
    objs = []
    sl = 1.5 if long_sleeve else 0.62
    objs.append(box((0.42, 0.5, sl), (0, 0, -sl / 2 + 0.1), M(sleeve), bevel=0.1, segs=2, name="sleeve"))
    if not long_sleeve:
        objs.append(box((0.36, 0.44, 0.95), (0, 0, -0.95), M(skin), bevel=0.1, segs=2, name="forearm"))
    else:
        objs.append(box((0.38, 0.46, 0.2), (0, 0, -1.48), M(skin), bevel=0.08, segs=1, name="hand"))
    xform(objs, (side * 0.93, 0.05, 3.7), rot)
    return objs


def build_CustomerA():
    # cheerful kid: teal tee with hot-dog print, jeans, red cap, white sneakers
    hz, fy = person("skin_a", "shirt_a", "denim", "white", "A")
    for s in (-1, 1):
        arm(s, "shirt_a", "skin_a", rot=(0, s * rad(-4), 0))
        box((0.57, 0.88, 0.1), (s * 0.33, -0.08, 0.2), M("ketchup"), bevel=0.03, segs=1, name="shoe_stripe")
    xform(hotdog(lod=0.5), (0, -0.33, 3.0), (rad(90), 0, rad(8)), (0.42, 0.42, 0.12))
    # cap
    sphere(0.58, (0, 0.05, hz + 0.42), M("ketchup"), scale=(1, 0.95, 0.6), segs=16, rings=8, name="cap")
    box((0.85, 0.6, 0.08), (0, -0.62, hz + 0.47), M("ketchup"), bevel=0.04, segs=1, name="brim")
    sphere(0.08, (0, 0.05, hz + 0.78), M("cream"), segs=8, rings=4, name="cap_button")
    box((1.08, 0.4, 0.3), (0, 0.38, hz + 0.25), M("hair_brown"), bevel=0.1, segs=1, name="hair_back")


def build_CustomerB():
    # sundress, long hair with a flower clip, yellow sandals, tote bag
    hz, fy = person("skin_b", "dress", "dress", "mustard", "B")
    lathe([(0.0, 0.0), (0.98, 0.0), (0.92, 0.25), (0.74, 1.15), (0.0, 1.15)], M("dress"), loc=(0, 0.05, 1.15),
          scale=(1, 0.72, 1), segs=20, name="skirt")
    torus(0.86, 0.05, (0, 0.05, 1.28), M("cream"), scale=(1, 0.75, 1), segs=20, rsegs=4, name="hem")
    for k in range(4):
        sphere(0.07, (-0.35 + k * 0.23, -0.34, 3.3 - 0.0), M("cream"), segs=6, rings=4, name="dot")
    for s in (-1, 1):
        arm(s, "dress", "skin_b", rot=(0, s * rad(-5), 0))
    # long hair: cap over the head, falling down the back and sides
    sphere(0.62, (0, 0.12, hz + 0.25), M("hair_dark"), scale=(0.98, 0.95, 0.72), segs=16, rings=8, name="hair_top")
    box((1.12, 0.45, 1.5), (0, 0.42, hz - 0.35), M("hair_dark"), bevel=0.18, segs=2, name="hair_back")
    for s in (-1, 1):
        box((0.18, 0.5, 1.05), (s * 0.58, 0.12, hz - 0.18), M("hair_dark"), bevel=0.07, segs=1, name="hair_side")
    bloom(0.2, "mustard", (0.45, -0.25, hz + 0.45), (rad(90), rad(30), 0), centre="ketchup")
    # little cross-body bag
    box((0.5, 0.2, 0.4), (0.38, -0.42, 2.05), M("cream"), bevel=0.06, segs=1, name="bag")
    box((0.5, 0.04, 0.15), (0.38, -0.53, 2.18), M("ketchup"), bevel=0.02, segs=1, name="bag_flap")
    tube([(0.6, -0.4, 2.2), (0.15, -0.4, 3.0), (-0.45, -0.35, 3.7)], 0.035, M("ketchup"), name="strap")


def build_CustomerC():
    # hoodie, beanie, glasses, holding a hot dog out in front
    hz, fy = person("skin_c", "hoodie", "navy", "ketchup", "C")
    arm(-1, "hoodie", "skin_c", rot=(0, rad(4), 0), long_sleeve=True)
    arm(1, "hoodie", "skin_c", rot=(rad(-45), 0, rad(-8)), long_sleeve=True)
    box((0.9, 0.06, 0.45), (0, -0.33, 2.6), M("leaf_dark"), bevel=0.04, segs=1, name="pocket")
    torus(0.45, 0.14, (0, 0.28, 3.88), M("hoodie"), scale=(1, 0.8, 1), segs=14, rsegs=6, name="hood")
    for s in (-1, 1):
        tube([(s * 0.18, -0.33, 3.75), (s * 0.2, -0.36, 3.3)], 0.03, M("cream"), name="drawstring")
    # beanie with pompom
    lathe([(0.0, 0.0), (0.6, 0.0), (0.6, 0.22), (0.56, 0.42), (0.36, 0.62), (0.0, 0.68)], M("mustard"),
          loc=(0, 0.05, hz + 0.28), segs=18, name="beanie")
    torus(0.58, 0.08, (0, 0.05, hz + 0.32), M("ketchup"), segs=18, rsegs=5, name="beanie_band")
    sphere(0.16, (0, 0.05, hz + 1.0), M("cream"), segs=10, rings=6, name="pompom")
    # glasses
    for s in (-1, 1):
        torus(0.14, 0.03, (s * 0.21, fy - 0.04, hz + 0.08), M("navy"), rot=(rad(90), 0, 0), segs=14, rsegs=4,
              name="lens")
    tube([(-0.07, fy - 0.04, hz + 0.1), (0.07, fy - 0.04, hz + 0.1)], 0.025, M("navy"), name="bridge")
    # hot dog in the raised right hand
    sh = Vector((0.93, 0.05, 3.7))
    hand = sh + Vector((0, -1.48 * math.sin(rad(45)), -1.48 * math.cos(rad(45))))
    xform(hotdog(lod=0.6), (hand.x - 0.05, hand.y - 0.05, hand.z + 0.12), (0, 0, rad(70)), 0.62)


# ---------------------------------------------------------------- sky objects
def build_Blimp():
    zb = 3.0
    xform(hotdog(lod=1.3), (0, 0, zb), (0, 0, 0), (19.0, 12.0, 12.0))
    zc = zb + 0.5 * 12.0
    fin = M("teal")
    vpts = [(-13.0, 2.5), (-17.0, 5.0), (-19.8, 5.0), (-19.0, 1.0)]
    wedge_prism([(x, zc + z) for x, z in vpts], 0.45, fin, bevel=0.1, name="fin_top")
    wedge_prism([(x, zc - z) for x, z in vpts], 0.45, fin, bevel=0.1, name="fin_bottom")
    for s in (-1, 1):
        wedge_prism([(x, s * (z + 1.5)) for x, z in vpts], 0.45, fin, loc=(0, 0, zc), rot=(rad(90), 0, 0),
                    bevel=0.1, name="fin_side")
    for s in (-1, 1):
        wedge_prism([(-17.3, s * 5.0), (-18.1, s * 5.0), (-17.3, s * 3.2), (-16.5, s * 3.2)], 0.5, M("cream"),
                    loc=(0, 0, zc), bevel=0.04, name="fin_stripe")
    # gondola
    box((7.5, 3.2, 2.2), (0, 0, 1.1), M("cream"), bevel=0.6, segs=3, name="gondola")
    box((7.6, 3.3, 0.35), (0, 0, 0.75), M("ketchup"), bevel=0.15, segs=2, name="gondola_stripe")
    for s in (-1, 1):
        for i in range(5):
            box((0.9, 0.1, 0.7), (-2.6 + i * 1.3, s * 1.58, 1.45), M("screen", rough=0.2), bevel=0.08, segs=1,
                name="window")
    box((0.1, 2.2, 0.8), (3.72, 0, 1.4), M("screen", rough=0.2), bevel=0.08, segs=1, name="front_window")
    for x in (-2.6, 2.6):
        for s in (-1, 1):
            tube([(x, s * 1.3, 2.1), (x * 1.3, s * 2.3, zb + 0.6)], 0.09, M("chrome", metal=0.5), name="strut")
    # propellers
    for s in (-1, 1):
        cyl(0.35, 1.0, (-3.9, s * 1.9, 1.3), M("chrome", metal=0.5, rough=0.35), rot=(0, rad(90), 0), verts=12,
            name="engine")
        cyl(0.12, 0.3, (-4.5, s * 1.9, 1.3), M("ketchup"), rot=(0, rad(90), 0), verts=8, name="prop_hub")
        for a in (rad(30), rad(150), rad(270)):
            box((0.08, 0.25, 1.1), (-4.55, s * 1.9 + 0.55 * math.cos(a), 1.3 + 0.55 * math.sin(a)), M("tire"),
                rot=(a - math.pi / 2, 0, 0), bevel=0.03, segs=1, name="blade")


def build_HotAirBalloon():
    prof = [(0.0, 5.9), (1.4, 6.05), (2.6, 7.4), (4.3, 9.0), (5.4, 10.5), (5.95, 12.0), (6.0, 13.3), (5.6, 14.6),
            (4.6, 15.9), (3.0, 17.05), (1.4, 17.75), (0.0, 18.0)]
    mats = [M("mustard", rough=0.45), M("ketchup", rough=0.45), M("cream", rough=0.45)]

    def mf(i, ring):
        if ring in (5,):
            return 2
        if ring >= 9:
            return 2
        return i % 2
    striped_lathe(prof, mats, segs=24, mat_fn=mf, name="envelope")
    torus(1.4, 0.1, (0, 0, 6.0), M("wood_dark"), segs=20, rsegs=5, name="mouth")
    # ropes
    for i in range(4):
        a = TAU * i / 4 + TAU / 8
        tube([(1.25 * math.cos(a), 1.25 * math.sin(a), 1.75), (1.35 * math.cos(a), 1.35 * math.sin(a), 6.0)], 0.04,
             M("wood_dark"), name="rope")
    # burner and flame
    cyl(0.45, 0.45, (0, 0, 3.7), M("chrome", metal=0.6, rough=0.3), verts=14, bevel=0.04, name="burner")
    lathe([(0, 0), (0.32, 0.15), (0.3, 0.5), (0.15, 0.95), (0, 1.25)], M("mustard", emit=3.0), loc=(0, 0, 3.95),
          segs=12, name="flame")
    lathe([(0, 0), (0.18, 0.12), (0.12, 0.45), (0, 0.65)], M("orange", emit=3.0), loc=(0, 0, 3.97), segs=10,
          name="flame_core")
    # wicker basket
    box((2.4, 2.4, 1.6), (0, 0, 0.8), M("wood"), bevel=0.15, segs=2, name="basket")
    for z in (0.4, 0.8, 1.2):
        box((2.44, 2.44, 0.14), (0, 0, z), M("wood_dark"), bevel=0.05, segs=1, name="weave")
    box((2.6, 2.6, 0.2), (0, 0, 1.68), M("wood_dark"), bevel=0.08, segs=2, name="basket_rim")
    for s in (-1, 1):
        capsule(0.2, 0.55, (s * 1.32, -0.6, 1.0), M("cream"), "Z", segs=10, steps=3, name="sandbag")
        capsule(0.2, 0.55, (s * 1.32, 0.5, 1.0), M("peach"), "Z", segs=10, steps=3, name="sandbag")


def build_CloudPuff():
    white = M("white", rough=0.9)
    shade = M("cloud_shade", rough=0.9)
    sphere(1.0, (0, 0, 2.3), shade, scale=(14.6, 6.4, 2.3), segs=24, rings=12, name="base")
    puffs = [(-11.0, 0.5, 3.4, 3.0), (-6.4, -0.6, 4.6, 4.2), (0.0, 0.3, 5.3, 4.6), (6.2, -0.4, 4.6, 4.0),
             (11.0, 0.4, 3.4, 3.2), (-3.0, 2.3, 4.2, 3.4), (3.6, 2.4, 4.0, 3.4), (-2.6, -2.7, 3.5, 2.7),
             (4.0, -2.8, 3.3, 2.6)]
    for x, y, z, r in puffs:
        sphere(r, (x, y, z), white, segs=20, rings=10, name="puff")


def build_Bird():
    blue, dark = M("bird", rough=0.5), M("bird_dark", rough=0.5)
    sphere(0.42, (0, 0.08, 0.4), blue, scale=(1, 1.3, 0.95), segs=16, rings=10, name="body")
    sphere(0.32, (0, -0.12, 0.3), M("cream"), scale=(0.95, 1.2, 0.8), segs=14, rings=8, name="belly")
    sphere(0.3, (0, -0.42, 0.52), blue, segs=16, rings=10, name="head")
    cyl(0.1, 0.25, (0, -0.8, 0.5), M("orange"), r2=0.0, rot=(rad(90), 0, 0), verts=10, name="beak")
    for s in (-1, 1):
        sphere(0.065, (s * 0.15, -0.67, 0.6), M("black", rough=0.2), scale=(1, 0.6, 1.25), segs=8, rings=5,
               name="eye")
        sphere(0.07, (s * 0.21, -0.6, 0.46), M("pink"), scale=(1, 0.5, 0.7), segs=6, rings=4, name="cheek")
        sphere(0.48, (s * 0.52, 0.12, 0.45), dark, scale=(1.05, 0.55, 0.12), rot=(0, s * rad(-14), s * rad(8)),
               segs=14, rings=6, name="wing")
    sphere(0.28, (0, 0.62, 0.5), dark, scale=(1.1, 1.3, 0.25), rot=(rad(18), 0, 0), segs=12, rings=6, name="tail")
    sphere(0.06, (0, -0.42, 0.84), blue, scale=(0.6, 1.4, 1.2), segs=6, rings=4, name="tuft")


# ---------------------------------------------------------------- icon props
def build_Clipboard():
    def make():
        box((2.0, 0.14, 2.6), (0, 0, 1.3), M("wood"), bevel=0.1, segs=2, name="board")
        box((1.7, 0.03, 2.1), (0, -0.085, 1.15), M("white"), bevel=0.01, segs=1, name="paper")
        box((1.0, 0.18, 0.32), (0, -0.09, 2.5), M("chrome", metal=0.6, rough=0.3), bevel=0.06, segs=2, name="clip")
        torus(0.2, 0.05, (0, -0.02, 2.7), M("chrome", metal=0.6, rough=0.3), rot=(rad(90), 0, 0), segs=14, rsegs=5,
              name="clip_ring")
        for i, z in enumerate((1.85, 1.4, 0.95, 0.5)):
            box((0.26, 0.03, 0.26), (-0.5, -0.1, z), M("teal"), bevel=0.02, segs=1, name="checkbox")
            box((0.75 - 0.12 * (i % 2), 0.03, 0.1), (0.2, -0.1, z), M("navy"), bevel=0.01, segs=1, name="line")
            if i < 3:
                tube([(-0.62, -0.13, z + 0.02), (-0.52, -0.13, z - 0.1), (-0.32, -0.13, z + 0.2)], 0.05,
                     M("ketchup"), name="tick")
    xform(track(make), (0, 0, 0), (rad(-10), 0, 0))


def build_Sneaker():
    sole = [(-1.45, 0), (1.3, 0), (1.52, 0.12), (1.47, 0.32), (-1.5, 0.32), (-1.56, 0.12)]
    wedge_prism(sole, 1.0, M("white"), bevel=0.05, name="sole")
    box((2.96, 1.03, 0.09), (0, 0, 0.13), M("teal"), bevel=0.02, segs=1, name="tread_stripe")
    upper = [(-1.45, 0.3), (1.35, 0.3), (1.45, 0.45), (1.2, 0.7), (0.5, 0.85), (-0.1, 1.05), (-0.6, 1.32),
             (-1.3, 1.32), (-1.5, 1.0)]
    wedge_prism(upper, 0.92, M("ketchup"), bevel=0.12, name="upper")
    toe = [(0.75, 0.3), (1.38, 0.3), (1.47, 0.45), (1.24, 0.66), (0.75, 0.66)]
    wedge_prism(toe, 0.96, M("white"), bevel=0.08, name="toe_cap")
    box((0.22, 0.5, 0.55), (-1.5, 0, 1.12), M("mustard"), bevel=0.06, segs=1, name="heel_tab")
    box((0.75, 0.62, 0.05), (-0.95, 0, 1.34), M("tire"), bevel=0.02, segs=1, name="opening")
    box((0.45, 0.62, 0.12), (-0.45, 0, 1.3), M("white"), rot=(0, rad(-28), 0), bevel=0.05, segs=1, name="tongue")
    for k in range(4):
        t = k / 3
        x = 0.42 - t * 0.68
        z = 0.88 + t * 0.32
        box((0.08, 0.78, 0.07), (x, 0, z), M("white"), rot=(0, rad(-25), 0), bevel=0.02, segs=1, name="lace")
    bolt = [(-1.0, 0.48), (-0.15, 0.95), (-0.25, 0.72), (0.55, 0.82), (-0.3, 0.4), (-0.22, 0.6)]
    wedge_prism(bolt, 0.95, M("mustard"), name="bolt")


def build_BookStack():
    def book(w, d, t, cover, loc, rz):
        objs = [box((w, d, 0.07), (0, 0, t / 2 - 0.035), M(cover), bevel=0.03, segs=1, name="cover_top"),
                box((w, d, 0.07), (0, 0, -t / 2 + 0.035), M(cover), bevel=0.03, segs=1, name="cover_bot"),
                box((w, 0.1, t), (0, -d / 2 + 0.05, 0), M(cover), bevel=0.04, segs=2, name="spine"),
                box((w - 0.14, d - 0.14, t - 0.1), (0, 0.03, 0), M("cream"), bevel=0.0, name="pages")]
        for x in (-w * 0.3, w * 0.3):
            objs.append(box((0.08, 0.04, t * 0.85), (x, -d / 2 - 0.005, 0), M("gold", metal=0.5, rough=0.35),
                            bevel=0, name="band"))
        xform(objs, loc, (0, 0, rz))
    z = 0
    for w, d, t, col, rz, dx in ((2.5, 1.75, 0.45, "ketchup", 0, 0), (2.3, 1.65, 0.38, "teal", 7, 0.08),
                                 (2.4, 1.7, 0.48, "relish", -5, -0.06), (2.0, 1.5, 0.34, "violet", 10, 0.05)):
        book(w, d, t, col, (dx, 0, z + t / 2), rad(rz))
        z += t
    tube([(0.6, -0.65, z - 0.02), (0.65, -0.82, z - 0.15), (0.62, -0.86, z - 0.55)], 0.05, M("mustard"),
         name="bookmark")
    # apple on top
    sphere(0.32, (-0.4, 0.1, z + 0.28), M("ketchup", rough=0.35), scale=(1, 1, 0.9), segs=14, rings=8, name="apple")
    cyl(0.03, 0.18, (-0.4, 0.1, z + 0.6), M("wood_dark"), verts=6, name="stem")
    sphere(0.1, (-0.3, 0.1, z + 0.62), M("relish"), scale=(1.6, 0.5, 0.6), segs=6, rings=4, name="leaf")


def build_RemoteControl():
    def make():
        box((1.0, 0.42, 2.6), (0, 0, 1.3), M("navy"), bevel=0.2, segs=3, name="body")
        cyl(0.17, 0.08, (0, -0.22, 2.2), M("ketchup", emit=0.3), rot=(rad(90), 0, 0), verts=14, name="power")
        box((0.5, 0.06, 0.16), (0, -0.22, 1.7), M("cream"), bevel=0.03, segs=1, name="dpad_h")
        box((0.16, 0.06, 0.5), (0, -0.22, 1.7), M("cream"), bevel=0.03, segs=1, name="dpad_v")
        cyl(0.08, 0.08, (0, -0.25, 1.7), M("teal"), rot=(rad(90), 0, 0), verts=10, name="ok")
        for k, col in enumerate(("ketchup", "relish", "mustard", "teal")):
            box((0.16, 0.06, 0.1), (-0.27 + k * 0.18, -0.22, 1.32), M(col), bevel=0.02, segs=1, name="color_btn")
        for r in range(3):
            for c in range(3):
                cyl(0.075, 0.07, (-0.25 + c * 0.25, -0.22, 1.05 - r * 0.25), M("cream"), rot=(rad(90), 0, 0),
                    verts=10, name="num")
        cyl(0.1, 0.18, (0.3, 0, 2.66), M("chrome", metal=0.5), verts=10, name="antenna_base")
        tube([(0.3, 0, 2.7), (0.6, 0.05, 3.75)], 0.035, M("chrome", metal=0.6, rough=0.3), name="antenna")
        sphere(0.11, (0.6, 0.05, 3.8), M("ketchup"), segs=10, rings=6, name="antenna_tip")
    xform(track(make), (0, 0, 0), (rad(-12), 0, rad(-8)))


def build_Basket():
    bands = [("wood", 0.0, 0.32), ("wood_dark", 0.32, 0.52), ("wood", 0.52, 0.84), ("wood_dark", 0.84, 1.04),
             ("wood", 1.04, 1.3)]
    for col, z0, z1 in bands:
        r0 = 1.55 + 0.25 * z0 / 1.3
        r1 = 1.55 + 0.25 * z1 / 1.3
        o = cyl(r0, z1 - z0, (0, 0, (z0 + z1) / 2), M(col, rough=0.8), r2=r1, rot=(0, 0, rad(45)), verts=4,
                name="weave")
        xform([o], (0, 0, 0), (0, 0, 0), (1.05, 0.62, 1.0))
    rim = cyl(1.86, 0.16, (0, 0, 1.36), M("wood_dark"), rot=(0, 0, rad(45)), verts=4, bevel=0.05, name="rim")
    xform([rim], (0, 0, 0), (0, 0, 0), (1.05, 0.62, 1.0))
    # gingham cloth
    for i in range(7):
        for j in range(4):
            box((0.34, 0.34, 0.03), (-1.02 + i * 0.34, -0.51 + j * 0.34, 1.4), M("ketchup" if (i + j) % 2 else "cream"),
                bevel=0, name="cloth")
    box((0.7, 0.05, 0.5), (-0.6, -0.88, 1.2), M("ketchup"), rot=(rad(-15), 0, 0), bevel=0.02, segs=1, name="flap")
    # sausages + bun poking out
    sausage_obj((-0.3, -0.1, 1.75), (0, rad(-30), rad(15)), s=0.65)
    sausage_obj((0.15, 0.15, 1.8), (0, rad(-40), rad(-20)), s=0.65)
    sausage_obj((0.5, -0.2, 1.62), (0, rad(-20), rad(5)), s=0.6)
    xform(hotdog(lod=0.45, bun_only=True), (-0.7, 0.2, 1.4), (0, rad(-15), rad(20)), 0.5)
    # handle
    pts = [(-1.15 * math.cos(math.pi * k / 12), 0, 1.4 + 1.15 * math.sin(math.pi * k / 12)) for k in range(13)]
    tube(pts, 0.09, M("wood_dark"), name="handle")


def build_Stopwatch():
    def make():
        cz = 1.05
        X = (rad(90), 0, 0)
        cyl(1.0, 0.45, (0, 0, cz), M("chrome", metal=0.6, rough=0.3), rot=X, verts=36, bevel=0.06, name="case")
        torus(0.93, 0.08, (0, -0.22, cz), M("ketchup"), rot=X, segs=36, rsegs=6, name="bezel")
        cyl(0.88, 0.05, (0, -0.22, cz), M("white"), rot=X, verts=36, name="face")
        arc = [(0, 0)] + [(0.78 * math.sin(rad(a)), 0.78 * math.cos(rad(a))) for a in range(0, 121, 15)]
        wedge_prism(arc, 0.02, M("mint"), loc=(0, -0.255, cz), name="elapsed")
        for i in range(12):
            a = TAU * i / 12
            L = 0.16 if i % 3 == 0 else 0.09
            box((0.05, 0.03, L), (0.72 * math.sin(a), -0.27, cz + 0.72 * math.cos(a)), M("navy"),
                rot=(0, a, 0), bevel=0, name="tick")
        box((0.07, 0.03, 0.7), (0.29, -0.29, cz + 0.17), M("ketchup"), rot=(0, rad(120 - 180) + math.pi, 0),
            bevel=0.01, segs=1, name="hand_long")
        box((0.08, 0.03, 0.42), (-0.1, -0.29, cz + 0.17), M("navy"), rot=(0, rad(-30), 0), bevel=0.01, segs=1,
            name="hand_short")
        cyl(0.08, 0.06, (0, -0.31, cz), M("navy"), rot=X, verts=10, name="hub")
        cyl(0.15, 0.3, (0, 0, cz + 1.12), M("chrome", metal=0.6, rough=0.3), verts=12, name="crown")
        cyl(0.26, 0.16, (0, 0, cz + 1.32), M("ketchup"), verts=14, bevel=0.03, name="button")
        torus(0.2, 0.05, (0, 0, cz + 1.56), M("chrome", metal=0.6, rough=0.3), rot=X, segs=12, rsegs=5, name="loop")
        for s in (-1, 1):
            cyl(0.1, 0.22, (s * 0.76, 0, cz + 0.76), M("ketchup"), rot=(0, s * rad(45), 0), verts=10, name="side_btn")
    xform(track(make), (0, 0, 0), (0, 0, rad(12)))


def coin_base(face="gold_dark", rim="gold_light"):
    X = (rad(90), 0, 0)
    gold = M("gold", metal=0.7, rough=0.3)
    cyl(1.0, 0.26, (0, 0, 1.0), gold, rot=X, verts=40, bevel=0.04, name="coin")
    for s in (-1, 1):
        torus(0.9, 0.06, (0, s * 0.13, 1.0), M(rim, metal=0.6, rough=0.3), rot=X, segs=40, rsegs=5, name="rim")
        cyl(0.82, 0.03, (0, s * 0.135, 1.0), M(face, metal=0.6, rough=0.35), rot=X, verts=40, name="inner")
    for i in range(36):
        a = TAU * i / 36
        box((0.05, 0.27, 0.08), (1.0 * math.cos(a), 0, 1.0 + 1.0 * math.sin(a)), gold, rot=(0, -a, 0), bevel=0,
            name="reed")


def build_InfinityToken():
    def make():
        coin_base(face="violet", rim="gold_light")
        a = 0.6
        pts = []
        for k in range(49):
            t = TAU * k / 48
            d = 1 + math.sin(t) ** 2
            pts.append((a * 1.15 * math.cos(t) / d, -0.19, 1.0 + a * 1.1 * math.sin(t) * math.cos(t) / d))
        tube(pts, 0.1, M("gold_light", metal=0.5, rough=0.3), name="infinity")
        for x, z, s in ((0.55, 1.6, 0.16), (-0.6, 0.45, 0.11)):
            box((s * 2, 0.04, 0.05), (x, -0.2, z), M("white", emit=1.0), bevel=0, name="spark")
            box((0.05, 0.04, s * 2), (x, -0.2, z), M("white", emit=1.0), bevel=0, name="spark")
    xform(track(make), (0, 0, 0), (0, 0, rad(15)))


def build_Coin():
    def make():
        coin_base(face="ketchup", rim="gold_light")
        xform(hotdog(lod=0.6), (0, -0.16, 1.0), (rad(90), rad(-25), 0), (0.68, 0.68, 0.35))
    xform(track(make), (0, 0, 0), (0, 0, rad(15)))


def build_Ufo():
    cyl(0.35, 0.3, (0, 0, 0.42), M("mint", emit=1.5), r2=0.5, verts=16, name="emitter")
    lathe([(0, 0.0), (0.7, 0.05), (1.5, 0.35), (1.55, 0.45), (1.0, 0.68), (0, 0.72)], M("teal"), loc=(0, 0, 0.35),
          segs=32, name="saucer")
    torus(1.5, 0.09, (0, 0, 0.78), M("cream"), segs=32, rsegs=6, name="rim")
    for i in range(10):
        a = TAU * i / 10
        sphere(0.12, (1.42 * math.cos(a), 1.42 * math.sin(a), 0.86), M("mustard" if i % 2 else "pink", emit=2.0),
               segs=8, rings=5, name="light")
    for i in range(3):
        a = TAU * i / 3 + TAU / 4
        tube([(0.6 * math.cos(a), 0.6 * math.sin(a), 0.45), (0.95 * math.cos(a), 0.95 * math.sin(a), 0.08)], 0.05,
             M("chrome", metal=0.5), name="leg")
        sphere(0.11, (0.95 * math.cos(a), 0.95 * math.sin(a), 0.08), M("chrome", metal=0.5), scale=(1, 1, 0.6),
               segs=8, rings=4, name="foot")
    # alien pilot under a glass dome
    sphere(0.38, (0, 0, 1.3), M("alien"), scale=(1.1, 1, 0.95), segs=16, rings=10, name="pilot")
    for s in (-1, 1):
        sphere(0.11, (s * 0.15, -0.31, 1.34), M("black", rough=0.15), scale=(0.9, 0.5, 1.3), segs=8, rings=5,
               name="eye")
        tube([(s * 0.15, 0, 1.6), (s * 0.25, 0, 1.75)], 0.025, M("alien"), name="antenna")
        sphere(0.05, (s * 0.25, 0, 1.78), M("mustard", emit=1.0), segs=6, rings=4, name="antenna_ball")
    lathe([(0.82, 0), (0.8, 0.22), (0.7, 0.46), (0.52, 0.66), (0.28, 0.79), (0, 0.84)], M("glass", transmission=1.0),
          loc=(0, 0, 1.03), segs=24, cap=False, name="dome")


def build_CashStack():
    random.seed(7)
    n = 7
    for i in range(n):
        rz = rad(random.uniform(-6, 6))
        dx, dy = random.uniform(-0.08, 0.08), random.uniform(-0.05, 0.05)
        objs = [box((2.4, 1.15, 0.12), (0, 0, 0), M("money" if i % 2 == 0 else "money_dark"), bevel=0.02, segs=1,
                    name="bill")]
        if i == n - 1:
            objs.append(box((2.15, 0.92, 0.02), (0, 0, 0.065), M("money_light"), bevel=0.01, segs=1, name="panel"))
            objs.append(cyl(0.3, 0.03, (0, 0, 0.08), M("money_dark"), verts=20, name="seal", scale=(1.25, 1, 1)))
            objs.append(cyl(0.2, 0.035, (0, 0, 0.085), M("money_light"), verts=16, name="seal_in",
                            scale=(1.25, 1, 1)))
            for x in (-0.85, 0.85):
                objs.append(cyl(0.12, 0.03, (x, 0, 0.08), M("money_dark"), verts=12, name="corner"))
        xform(objs, (dx, dy, 0.06 + i * 0.125), (0, 0, rz))
    top = 0.06 + (n - 1) * 0.125 + 0.07
    box((0.5, 1.24, top + 0.04), (0.0, 0, top / 2), M("mustard"), bevel=0.03, segs=1, name="band")
    box((0.52, 0.06, 0.25), (0.0, -0.63, top * 0.5), M("ketchup"), bevel=0.01, segs=1, name="band_tag")


def build_Lock():
    gold = M("gold", metal=0.6, rough=0.35)
    box((1.6, 0.7, 1.35), (0, 0, 0.675), gold, bevel=0.22, segs=3, name="body")
    box((1.3, 0.05, 1.05), (0, -0.35, 0.675), M("gold_dark", metal=0.5, rough=0.4), bevel=0.03, segs=1,
        name="plate")
    cyl(0.17, 0.06, (0, -0.38, 0.8), M("black"), rot=(rad(90), 0, 0), verts=14, name="keyhole")
    wedge_prism([(-0.07, 0.8), (0.07, 0.8), (0.12, 0.45), (-0.12, 0.45)], 0.06, M("black"), loc=(0, -0.38, 0),
                name="keyhole_slot")
    for x in (-0.52, 0.52):
        for z in (0.27, 1.08):
            sphere(0.06, (x, -0.38, z), M("gold_light", metal=0.5), segs=6, rings=4, name="rivet")
    r = 0.48
    pts = [(-r, 0, 1.25), (-r, 0, 1.85)]
    pts += [(-r * math.cos(math.pi * k / 12), 0, 1.85 + r * math.sin(math.pi * k / 12)) for k in range(1, 12)]
    pts += [(r, 0, 1.85), (r, 0, 1.25)]
    tube(pts, 0.14, M("chrome", metal=0.6, rough=0.3), name="shackle")


# ---------------------------------------------------------------- registry
DECOR_LIST = [
    # decor shop items
    ("Bench", build_Bench, (6, 2.5, 3.5)),
    ("PicnicTable", build_PicnicTable, (7, 6, 3)),
    ("PatioUmbrella", build_PatioUmbrella, (7, 7, 8)),
    ("LampPost", build_LampPost, (1.5, 1.5, 10)),
    ("StringLights", build_StringLights, (14, 1, 9)),
    ("Fountain", build_Fountain, (10, 10, 7)),
    ("HotDogStatue", build_HotDogStatue, (5, 5, 12)),
    ("BalloonBunch", build_BalloonBunch, (3, 3, 10)),
    ("FlowerArch", build_FlowerArch, (10, 3, 10)),
    ("HotDogTopiary", build_HotDogTopiary, (8, 3, 5)),
    ("NeonSign", build_NeonSign, (4, 2, 12)),
    ("Planter", build_Planter, (6, 2, 2.5)),
    # customers
    ("CustomerA", build_CustomerA, (2.2, 1.4, 5.2)),
    ("CustomerB", build_CustomerB, (2.2, 1.4, 5.2)),
    ("CustomerC", build_CustomerC, (2.2, 1.4, 5.2)),
    # sky
    ("Blimp", build_Blimp, (40, 12, 14)),
    ("HotAirBalloon", build_HotAirBalloon, (12, 12, 18)),
    ("CloudPuff", build_CloudPuff, (30, 14, 10)),
    ("Bird", build_Bird, (2, 2, 0.8)),
    # icon props
    ("Clipboard", build_Clipboard, (2, 0.6, 2.8)),
    ("Sneaker", build_Sneaker, (3, 1, 1.4)),
    ("BookStack", build_BookStack, (2.6, 1.9, 2.3)),
    ("RemoteControl", build_RemoteControl, (1.2, 1.0, 3.8)),
    ("Basket", build_Basket, (3.4, 2.0, 2.6)),
    ("Stopwatch", build_Stopwatch, (2.2, 1.0, 2.7)),
    ("InfinityToken", build_InfinityToken, (2, 0.8, 2)),
    ("Ufo", build_Ufo, (3.2, 3.2, 1.9)),
    ("CashStack", build_CashStack, (2.6, 1.4, 1.0)),
    ("Coin", build_Coin, (2, 0.8, 2)),
    ("Lock", build_Lock, (1.6, 0.7, 2.5)),
]


def contact_sheet(names):
    from PIL import Image, ImageDraw, ImageFont
    names = [n for n in names if os.path.exists(os.path.join(DIRS["renders"], f"{n}.png"))]
    cols, cell, lab = 6, 256, 26
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
    sheet.save(os.path.join(DIRS["renders"], "contact_sheet_decor.png"))


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
    man_path = os.path.join(DIRS["exports"], "manifest_decor.json")
    manifest = {}
    if os.path.exists(man_path):
        with open(man_path) as f:
            manifest = json.load(f)
    manifest.pop("_meta", None)
    t0 = time.time()
    for name, fn, target in DECOR_LIST:
        if only and name not in only:
            continue
        manifest[name] = BA.build_one(name, fn, target, a.samples, not a.no_render)
    ordered = {"_meta": {"generator": "tools/blender/build_decor.py (helpers from build_assets.py)",
                         "blender": bpy.app.version_string,
                         "units": "1 Blender unit = 1 Roblox stud; size is [X width, Y depth, Z height]",
                         "provenance": "original, procedurally generated, no third-party content"}}
    for name, _, _ in DECOR_LIST:
        if name in manifest:
            ordered[name] = manifest[name]
    with open(man_path, "w") as f:
        json.dump(ordered, f, indent=2)
    if not a.no_render:
        contact_sheet([n for n, _, _ in DECOR_LIST])
    print(f"done in {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
