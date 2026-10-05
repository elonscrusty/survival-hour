"""Build every Pet Race League 3D model with Blender's Python module (bpy).

    python3 blender/build.py [--only Pup,Tree_Round] [--no-render] [--samples 12]

Outputs (under pet-race-league/models/):
    fbx/<Name>.fbx     one mesh per model, palette texture embedded (upload these)
    palette.png        the shared colour palette every model is UV-mapped onto
    catalog.json       size and pivot offset of every model (Roblox studs/axes)
    renders/<Name>.png preview renders, renders/_sheet.png a contact sheet

Conventions (same as Roblox's Blender guide and the Survival Hour pack):
    * models are authored in Roblox axes: +Y up, front faces -Z, 1 unit = 1 stud
    * the pivot (origin) is at the bottom centre: where the model touches the ground
    * converted to Blender axes on export (Forward Z, Up Y in the FBX exporter)
Pet shapes are read from src/shared/Pets.luau so they match the in-game fallback.
"""

import argparse
import json
import math
import os
import random
import re
import struct
import sys
import zlib

import bpy  # must come before bmesh/mathutils
import bmesh  # noqa: E402
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "models")
FBX_DIR = os.path.join(OUT, "fbx")
RENDER_DIR = os.path.join(OUT, "renders")

# Roblox (x, y, z) -> Blender (-x, z, y)
R2B = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


# ----------------------------------------------------------------- matrices

def T(x, y=0.0, z=0.0):
    if isinstance(x, (Vector, tuple, list)):
        x, y, z = x
    return Matrix.Translation((x, y, z))


def S(x, y=None, z=None):
    if y is None:
        y = z = x
    return Matrix.Diagonal((x, y, z, 1.0))


def Rx(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def Ry(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")


def Rz(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


# ------------------------------------------------------------------ palette

PALETTE = []
GRID = 16  # 16 x 16 colour cells
CELL = 8  # pixels per cell


def pal(color):
    c = tuple(int(v) for v in color)
    if c not in PALETTE:
        if len(PALETTE) >= GRID * GRID:
            raise RuntimeError("palette full")
        PALETTE.append(c)
    return PALETTE.index(c)


def cell_uv(i):
    col, row = i % GRID, i // GRID
    return ((col + 0.5) / GRID, 1.0 - (row + 0.5) / GRID)


def write_png(path, width, height, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def write_palette(path):
    size = GRID * CELL
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            i = (y // CELL) * GRID + (x // CELL)
            row.extend(PALETTE[i] if i < len(PALETTE) else (255, 0, 255))
        rows.append(row)
    write_png(path, size, size, rows)


# --------------------------------------------------------------- mesh kit

class Mesh:
    """One model: primitives are added in Roblox space, each with one palette colour."""

    def __init__(self, name, category):
        self.name = name
        self.category = category
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.bone_layer = self.bm.verts.layers.int.new("bone")
        # Skeleton (pets only): (name, parent, pivot in Roblox space). New primitives
        # are skinned 100% to self.bone (rigid parts, like the part-built rig).
        self.bones = []
        self.bone = None

    def add_bone(self, name, parent, pivot):
        self.bones.append((name, parent, Vector(pivot)))

    def _paint(self, before, color, smooth):
        u, v = cell_uv(pal(color))
        bi = 0
        if self.bone:
            bi = [b[0] for b in self.bones].index(self.bone) + 1
        for f in self.bm.faces:
            if f not in before:
                f.smooth = smooth
                for loop in f.loops:
                    loop[self.uv].uv = (u, v)
                    loop.vert[self.bone_layer] = bi

    def sphere(self, color, m, seg=18, rings=12, smooth=True):
        """Unit-diameter sphere transformed by m (use S() for an ellipsoid)."""
        before = set(self.bm.faces)
        bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=0.5, matrix=m)
        self._paint(before, color, smooth)

    def ico(self, color, m, subdiv=2, jitter=0.0, seed=0, smooth=False):
        before = set(self.bm.faces)
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=0.5, matrix=Matrix())
        rng = random.Random(seed)
        for v in res["verts"]:
            v.co *= 1.0 + rng.uniform(-jitter, jitter)
            v.co = m @ v.co
        self._paint(before, color, smooth)

    def box(self, color, m, bevel=0.0):
        """Unit cube (1 x 1 x 1) transformed by m. bevel rounds the edges (studs)."""
        before = set(self.bm.faces)
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        if bevel > 0:
            verts = res["verts"]
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=verts + edges, offset=bevel, segments=2, affect="EDGES", profile=0.5)
        self._paint(before, color, smooth=False)

    def cyl(self, color, m, r1=0.5, r2=None, seg=16, smooth=True):
        """Cylinder/cone of height 1 along local +Y, base at local y=-0.5."""
        before = set(self.bm.faces)
        bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1,
                              radius2=r1 if r2 is None else r2, depth=1.0, matrix=m @ Rx(-90))
        self._paint(before, color, smooth)

    def rod(self, color, a, b, r1, r2=None, seg=12, smooth=True):
        """Cylinder or cone from point a to point b."""
        a, b = Vector(a), Vector(b)
        d = b - a
        rot = Vector((0, 1, 0)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        self.cyl(color, T((a + b) / 2) @ rot @ S(1, d.length, 1), r1, r2, seg, smooth)

    def finish(self):
        bm = self.bm
        xs = [v.co for v in bm.verts]
        lo = Vector((min(c.x for c in xs), min(c.y for c in xs), min(c.z for c in xs)))
        hi = Vector((max(c.x for c in xs), max(c.y for c in xs), max(c.z for c in xs)))
        size = hi - lo
        center = (hi + lo) / 2
        rec = {
            "name": self.name,
            "category": self.category,
            "size": [round(size.x, 3), round(size.y, 3), round(size.z, 3)],
            # pivot relative to the bounding-box centre (pivot is the origin)
            "offset": [round(-center.x, 3), round(-center.y, 3), round(-center.z, 3)],
            "tris": sum(len(f.verts) - 2 for f in bm.faces),
        }
        bmesh.ops.transform(bm, matrix=R2B, verts=bm.verts)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(self.name, me)
        if self.bones:
            rec["bones"] = [b[0] for b in self.bones]
            groups = [obj.vertex_groups.new(name=b[0]) for b in self.bones]
            ids = me.attributes["bone"].data
            per = {}
            for i in range(len(me.vertices)):
                per.setdefault(max(ids[i].value, 1) - 1, []).append(i)
            for gi, verts in per.items():
                groups[gi].add(verts, 1.0, "REPLACE")
        return obj, rec

    def make_armature(self, obj, collection):
        """Builds the skeleton and skins obj to it. Bones point up (Blender +Z) with
        no roll, so pose axes map to Roblox axes as (-X, Y, -Z): see PetAnimator."""
        arm = bpy.data.armatures.new(self.name + "_Rig")
        rig = bpy.data.objects.new(self.name + "_Rig", arm)
        collection.objects.link(rig)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")
        made = {}
        for name, parent, pivot in self.bones:
            eb = arm.edit_bones.new(name)
            head = (R2B @ pivot.to_4d()).to_3d()
            eb.head = head
            eb.tail = head + Vector((0, 0, 0.4))
            eb.roll = 0
            if parent:
                eb.parent = made[parent]
            made[name] = eb
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.parent = rig
        mod = obj.modifiers.new("Rig", "ARMATURE")
        mod.object = rig
        return rig


# ------------------------------------------------------------------ data

def lua_species():
    text = open(os.path.join(ROOT, "src", "shared", "Pets.luau")).read()
    out = []
    for line in text.splitlines():
        m = re.search(r'\{ Id = "([^"]+)"', line)
        if not m or "Body =" not in line:
            continue

        def nums(key):
            mm = re.search(key + r" = \{ ([^}]*) \}", line)
            return [float(x) for x in mm.group(1).split(",")]

        def num(key):
            return float(re.search(key + r" = ([\d.]+)", line).group(1))

        def word(key):
            mm = re.search(key + r' = "(\w+)"', line)
            return mm.group(1) if mm else None

        out.append({
            "Id": m.group(1), "Body": nums("Body"), "Head": num("Head"), "Legs": num("Legs"),
            "Color": nums("Color"), "Accent": nums("Accent"), "Ears": word("Ears"), "Tail": word("Tail"),
            "Horn": "Horn = true" in line, "Wings": "Wings = true" in line, "Neon": "Neon = true" in line,
        })
    return out


def lua_eggs():
    text = open(os.path.join(ROOT, "src", "shared", "Eggs.luau")).read()
    pat = r'Id = "(\w+)",\s*Name = "[^"]+",\s*Price = \d+,\s*Color = \{ (\d+), (\d+), (\d+) \}'
    return [(m.group(1), (int(m.group(2)), int(m.group(3)), int(m.group(4)))) for m in re.finditer(pat, text)]


# ------------------------------------------------------------------- pets

DARK = (35, 30, 38)
WHITE = (255, 255, 255)
ORANGE = (255, 160, 40)
GOLD = (255, 205, 80)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def model_name(pid):
    return "Pet_" + pid.replace(" ", "")


def head_center(sp):
    """Chibi layout shared with src/shared/PetModel.luau: a big head over the front of the body."""
    bx, by, bz = sp["Body"]
    legH, hs = sp["Legs"], sp["Head"]
    return Vector((0, legH + by * 0.85 + hs * 0.2, -bz * 0.4))


def build_pet(sp):
    """Chibi pet: round bean body, oversized head, big glossy eyes, stubby legs."""
    pid = sp["Id"]
    m = Mesh(model_name(pid), "Pets")
    bx, by, bz = sp["Body"]
    legH, hs = sp["Legs"], sp["Head"]
    col, acc = tuple(sp["Color"]), tuple(sp["Accent"])
    rng = random.Random(pid)
    bodyY = legH + by / 2
    ear_col, leg_col, foot_col = col, col, acc
    if pid == "Panda":
        ear_col = leg_col = foot_col = acc
    elif pid == "Fox":
        leg_col, foot_col = (70, 40, 35), (55, 30, 28)
    elif pid == "Penguin":
        foot_col = ORANGE
    elif pid == "Tiger":
        foot_col = (255, 240, 220)
    elif pid == "Cosmic Cat":
        foot_col = acc

    # Skeleton: same joints and pivots as the part-built rig (PetModel.BuildParts).
    hc = head_center(sp)
    legTop = legH + by * 0.35
    m.add_bone("Root", None, (0, 0, 0))
    m.add_bone("Body", "Root", (0, bodyY, 0))
    m.add_bone("Head", "Body", hc + Vector((0, -hs * 0.3, hs * 0.25)))
    if sp["Ears"]:
        ear_base = {"Long": (0.25, 0.45, 0.04), "Round": (0.34, 0.26, 0.03), "Point": (0.27, 0.33, 0.02)}[sp["Ears"]]
        for name, side in (("EarL", 1), ("EarR", -1)):
            m.add_bone(name, "Head", hc + Vector((side * hs * ear_base[0], hs * ear_base[1], hs * ear_base[2])))
    for name, lx, lz in (("LegFL", 1, -1), ("LegFR", -1, -1), ("LegBL", 1, 1), ("LegBR", -1, 1)):
        m.add_bone(name, "Body", (lx * bx * 0.27, legTop, lz * bz * 0.28))
    if sp["Tail"]:
        m.add_bone("Tail", "Body", (0, bodyY + by * 0.15, bz * 0.46))
    if sp["Wings"] or pid == "Penguin":
        for name, side in (("WingL", 1), ("WingR", -1)):
            m.add_bone(name, "Body", (side * bx * 0.42, bodyY + by * 0.38, 0))
    m.bone = "Body"

    # Body: a round bean, a little higher at the back.
    m.sphere(col, T(0, bodyY, 0) @ S(bx, by, bz), 28, 18)
    m.sphere(col, T(0, bodyY + by * 0.06, bz * 0.18) @ S(bx * 0.96, by * 0.96, bz * 0.6), 22, 14)
    belly = (255, 255, 255) if pid in ("Penguin", "Panda") else acc
    if pid not in ("Tiger", "Cosmic Cat", "Panda"):
        m.sphere(belly, T(0, bodyY - by * 0.14, -bz * 0.1) @ S(bx * 0.8, by * 0.8, bz * 0.78), 22, 14)
    if pid == "Tiger":
        for i in range(6):
            z = -bz * 0.3 + i * bz * 0.13
            f = math.sqrt(max(0.0, 1 - (2 * z / bz) ** 2))
            m.sphere((45, 25, 30), T(0, bodyY + by * 0.06, z) @ S(bx * 1.03 * f, by * 1.03 * f, bz * 0.045), 22, 8)
    if pid == "Pup":
        m.sphere((160, 100, 55), T(bx * 0.22, bodyY + by * 0.25, bz * 0.12) @ S(bx * 0.6, by * 0.55, bz * 0.45), 16, 10)
    if pid == "Deer":
        for _ in range(8):
            a = rng.uniform(-0.6, 0.6)
            m.sphere(WHITE, T(bx * 0.48 * math.sin(a), bodyY + by * 0.44, rng.uniform(-bz * 0.15, bz * 0.38)) @ S(0.42, 0.18, 0.42), 10, 6)
    if pid == "Cosmic Cat":
        for _ in range(22):
            th = rng.uniform(0, math.pi * 2)
            ph = rng.uniform(0.15, 1.5)
            p = Vector((math.cos(th) * math.sin(ph) * bx * 0.5, math.cos(ph) * by * 0.5, math.sin(th) * math.sin(ph) * bz * 0.5))
            m.sphere(acc if rng.random() < 0.6 else (255, 240, 120), T(0, bodyY, 0) @ T(p) @ S(rng.uniform(0.22, 0.4)), 8, 6)
    if pid == "Dragon":
        for i in range(6):
            z = -bz * 0.1 + i * bz * 0.1
            yy = bodyY + by * 0.5 - (z / bz) ** 2 * by * 0.6
            m.rod(acc, (0, yy - 0.2, z), (0, yy + 0.75, z + 0.3), 0.38, 0.0, 8, False)
    if pid == "Wolf":
        m.sphere(acc, T(0, bodyY + by * 0.05, -bz * 0.42) @ S(bx * 0.75, by * 0.75, bz * 0.3), 16, 10)

    # Stubby legs with round feet
    top = legH + by * 0.35
    for lx in (-1, 1):
        for lz in (-1, 1):
            m.bone = "Leg" + ("F" if lz < 0 else "B") + ("L" if lx > 0 else "R")
            x, z = lx * bx * 0.27, lz * bz * 0.28
            m.cyl(leg_col, T(x, (top + bx * 0.1) / 2, z) @ S(1, top - bx * 0.1, 1), bx * 0.15, bx * 0.15, 16)
            m.sphere(foot_col, T(x, bx * 0.11, z - bx * 0.05) @ S(bx * 0.36, bx * 0.24, bx * 0.42), 14, 10)
    if pid == "Bunny":
        for lx in (-1, 1):
            m.bone = "LegBL" if lx > 0 else "LegBR"
            m.sphere(acc, T(lx * bx * 0.28, bx * 0.1, bz * 0.2) @ S(bx * 0.34, bx * 0.2, bx * 0.75), 14, 10)

    # Big head
    m.bone = "Head"
    head_col = WHITE if pid == "Griffin" else col
    m.sphere(head_col, T(hc) @ S(hs * 1.04, hs * 0.96, hs), 28, 18)
    if pid == "Panda":
        for side in (-1, 1):
            ep = hc + Vector((side * hs * 0.21, hs * 0.02, -hs * 0.42))
            m.sphere(acc, T(ep) @ Rz(side * -30) @ S(hs * 0.3, hs * 0.38, hs * 0.14), 14, 10)
    # Muzzle / beak
    if pid in ("Penguin", "Griffin", "Phoenix"):
        bc = GOLD if pid == "Griffin" else ORANGE
        m.rod(bc, hc + Vector((0, -hs * 0.1, -hs * 0.4)), hc + Vector((0, -hs * 0.16, -hs * 0.68)), hs * 0.13, 0.02, 12)
    elif pid == "Piggy":
        m.cyl(acc, T(hc + Vector((0, -hs * 0.14, -hs * 0.48))) @ Rx(90) @ S(1, hs * 0.14, 1), hs * 0.17, hs * 0.17, 18)
        for side in (-1, 1):
            m.sphere((150, 50, 80), T(hc + Vector((side * hs * 0.06, -hs * 0.14, -hs * 0.56))) @ S(hs * 0.05, hs * 0.08, hs * 0.03), 8, 6)
    else:
        snout = WHITE if pid in ("Panda", "Tiger", "Wolf", "Fox", "Kitty", "Cosmic Cat") else acc
        m.sphere(snout, T(hc + Vector((0, -hs * 0.17, -hs * 0.38))) @ S(hs * 0.42, hs * 0.28, hs * 0.26), 18, 12)
        m.sphere(DARK, T(hc + Vector((0, -hs * 0.09, -hs * 0.51))) @ S(hs * 0.13, hs * 0.09, hs * 0.07), 10, 8)
        for side in (-1, 1):  # little "w" smile
            a = hc + Vector((0, -hs * 0.2, -hs * 0.5))
            m.rod(DARK, a, a + Vector((side * hs * 0.07, -hs * 0.035, hs * 0.01)), hs * 0.012, hs * 0.012, 5)
    if pid == "Bunny":
        m.box(WHITE, T(hc + Vector((0, -hs * 0.3, -hs * 0.48))) @ S(hs * 0.12, hs * 0.09, hs * 0.03))
    if pid in ("Kitty", "Cosmic Cat", "Tiger"):
        for side in (-1, 1):
            for dy in (-0.035, 0.035):
                a = hc + Vector((side * hs * 0.2, -hs * 0.15 + dy * hs, -hs * 0.44))
                m.rod(DARK if pid != "Cosmic Cat" else WHITE, a, a + Vector((side * hs * 0.32, dy * hs * 1.5, hs * 0.04)), 0.035, 0.025, 4)
    # Big glossy eyes with two highlights, and blush
    for side in (-1, 1):
        ep = hc + Vector((side * hs * 0.2, hs * 0.05, -hs * 0.455))
        iris = (25, 20, 35) if pid != "Cosmic Cat" else (20, 60, 90)
        m.sphere(iris, T(ep) @ S(hs * 0.19, hs * 0.26, hs * 0.1), 16, 12)
        m.sphere(WHITE, T(ep + Vector((-side * hs * 0.03, hs * 0.06, -hs * 0.045))) @ S(hs * 0.08), 10, 8)
        m.sphere(WHITE, T(ep + Vector((side * hs * 0.035, -hs * 0.06, -hs * 0.04))) @ S(hs * 0.035), 8, 6)
        if pid not in ("Panda",):
            m.sphere((255, 120, 150), T(hc + Vector((side * hs * 0.33, -hs * 0.12, -hs * 0.36))) @ S(hs * 0.14, hs * 0.08, hs * 0.06), 10, 6)

    # Ears
    ears = sp["Ears"]
    for side in (-1, 1):
        if ears:
            m.bone = "EarL" if side > 0 else "EarR"
        if ears == "Point":
            base = hc + Vector((side * hs * 0.27, hs * 0.33, hs * 0.02))
            tip = base + Vector((side * hs * 0.1, hs * 0.38, 0.0))
            m.rod(ear_col, base, tip, hs * 0.16, 0.03, 12)
            inner = (255, 170, 190) if pid not in ("Cosmic Cat",) else acc
            m.rod(inner, base + Vector((0, 0.05, -hs * 0.07)), tip + Vector((-side * hs * 0.03, -hs * 0.1, -hs * 0.06)), hs * 0.08, 0.02, 8)
        elif ears == "Round":
            p = hc + Vector((side * hs * 0.34, hs * 0.38, hs * 0.03))
            m.sphere(ear_col, T(p) @ S(hs * 0.32, hs * 0.32, hs * 0.16), 16, 10)
            if pid != "Panda":
                m.sphere((255, 170, 190) if pid != "Piggy" else acc, T(p + Vector((0, 0, -hs * 0.06))) @ S(hs * 0.18, hs * 0.18, hs * 0.07), 12, 8)
        elif ears == "Long":
            p = hc + Vector((side * hs * 0.18, hs * 0.78, hs * 0.04))
            m.sphere(ear_col, T(p) @ Rz(side * -12) @ S(hs * 0.24, hs * 0.8, hs * 0.14), 16, 12)
            m.sphere(acc, T(p + Vector((0, 0, -hs * 0.055))) @ Rz(side * -12) @ S(hs * 0.13, hs * 0.6, hs * 0.06), 12, 10)

    # Horns, antlers, crests, manes
    m.bone = "Head"
    if sp["Horn"]:
        if pid == "Deer":
            antler = (170, 115, 70)
            for side in (-1, 1):
                a = hc + Vector((side * hs * 0.2, hs * 0.4, hs * 0.05))
                b = a + Vector((side * hs * 0.3, hs * 0.6, hs * 0.1))
                m.rod(antler, a, b, hs * 0.05, hs * 0.035, 8)
                for t, d in ((0.45, Vector((side * hs * 0.04, hs * 0.25, -hs * 0.15))), (0.8, Vector((-side * hs * 0.12, hs * 0.22, -hs * 0.06)))):
                    q = a + (b - a) * t
                    m.rod(antler, q, q + d, hs * 0.035, hs * 0.02, 6)
                m.sphere(antler, T(b) @ S(hs * 0.07), 8, 6)
        elif pid == "Dragon":
            for side in (-1, 1):
                a = hc + Vector((side * hs * 0.24, hs * 0.36, hs * 0.1))
                m.rod(acc, a, a + Vector((side * hs * 0.1, hs * 0.36, hs * 0.32)), hs * 0.09, 0.01, 10)
        else:
            a = hc + Vector((0, hs * 0.44, -hs * 0.16))
            b = a + Vector((0, hs * 0.55, -hs * 0.18))
            m.rod(GOLD, a, b, hs * 0.08, 0.01, 12)
            for i in range(3):
                q = a + (b - a) * (0.18 + i * 0.25)
                r = hs * (0.13 - i * 0.03)
                m.sphere(mix(GOLD, WHITE, 0.45), T(q) @ S(r, hs * 0.035, r), 12, 4)
    if pid == "Phoenix":
        for i, dz in enumerate((-0.12, 0.04, 0.2)):
            a = hc + Vector((0, hs * 0.4, hs * dz))
            m.rod(acc if i != 1 else (255, 150, 40), a, a + Vector((0, hs * 0.45, hs * (0.2 + dz))), hs * 0.07, 0.01, 8)
    if pid == "Unicorn":
        mane = [acc, (180, 130, 255), (120, 210, 255)]
        for i in range(7):
            t = i / 6
            p = Vector((0, legH + by * (0.7 + 0.45 * (1 - t)) + hs * 0.25 * (1 - t), -bz * 0.15 + t * bz * 0.35))
            m.sphere(mane[i % 3], T(p) @ S(hs * 0.3, hs * 0.3, hs * 0.26), 12, 8)

    # Tail
    m.bone = "Tail" if sp["Tail"] else "Body"
    tb = Vector((0, bodyY + by * 0.15, bz * 0.48))
    tail = sp["Tail"]
    if tail == "Short":
        m.sphere(WHITE if pid == "Bunny" else acc if pid != "Panda" else acc, T(tb + Vector((0, 0, bx * 0.04))) @ S(bx * 0.3), 14, 10)
    elif tail == "Fluffy":
        c = tb + Vector((0, by * 0.35, bz * 0.16))
        tcol = WHITE if pid == "Bunny" else col
        m.sphere(tcol, T(c) @ Rx(-40) @ S(bx * 0.42, bx * 0.42, bz * 0.48), 16, 12)
        m.sphere(WHITE if pid == "Fox" else acc, T(c + Vector((0, by * 0.2, bz * 0.17))) @ S(bx * 0.3), 12, 8)
        if pid == "Phoenix":
            for side in (-1, 0, 1):
                a = tb + Vector((side * bx * 0.12, 0, 0))
                m.rod(acc if side == 0 else (255, 150, 40), a, a + Vector((side * bx * 0.28, by * 0.55, bz * 0.6)), bx * 0.07, 0.01, 8)
    elif tail == "Long":
        d = Vector((0, 0.55, 0.84)) if pid not in ("Dragon", "Griffin") else Vector((0, 0.2, 1))
        L = bz * (0.55 if pid != "Dragon" else 0.75)
        m.rod(col, tb, tb + d * L, bx * 0.09, bx * 0.05, 12)
        tip = acc if pid in ("Unicorn", "Griffin", "Dragon", "Cosmic Cat") else col
        m.sphere(tip, T(tb + d * L) @ S(bx * (0.24 if pid != "Dragon" else 0.2)), 12, 8)

    # Wings: three layered feathers per side, swept up and back
    if sp["Wings"]:
        for side in (-1, 1):
            m.bone = "WingL" if side > 0 else "WingR"
            base = Vector((side * bx * 0.5, bodyY + by * 0.38, bz * 0.02))
            for i, (sc, c2) in enumerate(((1.0, acc), (0.82, col), (0.62, WHITE if pid != "Dragon" else acc))):
                ctr = base + Vector((side * bx * 0.35 * sc, by * 0.12 * i, bz * 0.05 * i))
                m.sphere(c2, T(ctr) @ Ry(side * -12) @ Rz(side * 32) @ S(bx * 0.9 * sc, by * 0.1, bz * 0.42 * sc), 16, 8)
    if pid == "Penguin":
        for side in (-1, 1):
            m.bone = "WingL" if side > 0 else "WingR"
            m.sphere(col, T(side * bx * 0.5, bodyY, 0) @ Rz(side * 22) @ S(bx * 0.18, by * 0.65, bz * 0.42), 14, 10)
    return m


# ------------------------------------------------------------------- eggs

def build_egg(eid, color):
    m = Mesh("Egg_" + eid, "Eggs")
    before = set(m.bm.faces)
    res = bmesh.ops.create_uvsphere(m.bm, u_segments=28, v_segments=18, radius=0.5, matrix=Matrix())
    for v in res["verts"]:
        y = v.co.z  # sphere is built along z; treat z as up before mapping
        taper = 1.0 - 0.22 * max(0.0, y * 2)
        v.co = Vector((v.co.x * 5 * taper, y * 7 + 3.5, v.co.y * 5 * taper))
    m._paint(before, color, True)
    spot = WHITE if eid != "Sky" else GOLD
    rng = random.Random(eid)
    for i in range(10):
        th = i * 2.4 + rng.uniform(-0.2, 0.2)
        h = rng.uniform(-0.38, 0.32)
        taper = 1.0 - 0.22 * max(0.0, h * 2)
        r = math.sqrt(max(0.0, 0.25 - h * h)) * 5 * taper
        p = Vector((math.cos(th) * r, h * 7 + 3.5, math.sin(th) * r))
        n = Vector((math.cos(th), 0.2, math.sin(th))).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4()
        s = rng.uniform(0.7, 1.2)
        m.sphere(spot, T(p) @ rot @ S(1.0 * s, 1.0 * s, 0.25), 10, 6)
    # zigzag crack band
    band = mix(color, WHITE, 0.5)
    for i in range(16):
        th = i / 16 * math.pi * 2
        y = 3.5 + (0.35 if i % 2 == 0 else -0.35)
        p = Vector((math.cos(th) * 2.5, y, math.sin(th) * 2.5))
        m.sphere(band, T(p) @ S(0.55), 6, 4)
    return m


# ----------------------------------------------------------------- props

GREEN = (95, 215, 75)
GREEN_D = (55, 170, 65)
BARK = (160, 100, 60)
STONE = (175, 180, 205)
WOOD = (215, 150, 90)


def build_props():
    out = []

    m = Mesh("Tree_Round", "Lobby")
    m.rod(BARK, (0, 0, 0), (0, 8, 0), 0.9, 0.6, 10)
    for a in range(3):
        th = a * 2.1
        m.rod(BARK, (0, 0.6, 0), (math.cos(th) * 1.6, 0, math.sin(th) * 1.6), 0.4, 0.2, 6)
    for p, s, c in (((0, 10.5, 0), 7.5, GREEN), ((2.2, 9, 1), 5, GREEN_D), ((-2.2, 9.2, -0.8), 5.2, GREEN), ((0.3, 12.6, -0.5), 4.6, (110, 200, 95))):
        m.sphere(c, T(p) @ S(s), 14, 10)
    out.append(m)

    m = Mesh("Tree_Pine", "Lobby")
    m.rod(BARK, (0, 0, 0), (0, 4, 0), 0.8, 0.6, 10)
    for i, (y, r, h) in enumerate(((3, 4.5, 5), (6, 3.6, 4.5), (8.8, 2.6, 4))):
        m.cyl((40, 120, 70) if i % 2 == 0 else (55, 140, 80), T(0, y + h / 2, 0) @ S(1, h, 1), r, 0.2, 14)
    out.append(m)

    m = Mesh("Tree_Blossom", "Lobby")
    m.rod(BARK, (0, 0, 0), (0, 7, 0), 0.8, 0.55, 10)
    m.rod(BARK, (0, 5, 0), (2.2, 8, 0.5), 0.45, 0.3, 8)
    for p, s, c in (((0, 9.5, 0), 6.5, (255, 175, 205)), ((2.4, 8.8, 0.8), 4.5, (255, 200, 220)), ((-2, 8.6, -0.6), 4.6, (250, 150, 190))):
        m.sphere(c, T(p) @ S(s), 14, 10)
    out.append(m)

    m = Mesh("Bush", "Lobby")
    for p, s in (((0, 1.4, 0), 3.2), ((1.4, 1.1, 0.4), 2.4), ((-1.3, 1.0, -0.3), 2.5)):
        m.sphere(GREEN, T(p) @ S(s, s * 0.85, s), 12, 8)
    rng = random.Random(5)
    for _ in range(7):
        m.sphere((230, 60, 70), T(rng.uniform(-2, 2), rng.uniform(1.2, 2.6), rng.uniform(-1.2, 1.2) - 0.9) @ S(0.35), 6, 4)
    out.append(m)

    m = Mesh("Rock", "Lobby")
    m.ico(STONE, T(0, 1.3, 0) @ S(4, 2.8, 3.4), 2, 0.12, 3)
    m.ico((130, 130, 140), T(1.8, 0.7, 1) @ S(1.8, 1.4, 1.6), 1, 0.1, 4)
    out.append(m)

    m = Mesh("Flowers", "Lobby")
    rng = random.Random(9)
    colors = [(255, 90, 120), (255, 220, 70), (160, 110, 255), (255, 255, 255), (255, 150, 60)]
    for i in range(9):
        x, z = rng.uniform(-2, 2), rng.uniform(-2, 2)
        h = rng.uniform(0.8, 1.6)
        m.rod(GREEN_D, (x, 0, z), (x, h, z), 0.07, 0.06, 5)
        c = colors[i % len(colors)]
        for k in range(5):
            th = k / 5 * math.pi * 2
            m.sphere(c, T(x + math.cos(th) * 0.22, h, z + math.sin(th) * 0.22) @ S(0.3, 0.12, 0.3), 6, 4)
        m.sphere((255, 210, 60), T(x, h + 0.05, z) @ S(0.18), 6, 4)
    out.append(m)

    m = Mesh("Fence", "Lobby")
    for x in (-5.5, 0, 5.5):
        m.box(WOOD, T(x, 1.9, 0) @ S(0.6, 3.8, 0.6), 0.08)
    for y in (1.3, 2.9):
        m.box(mix(WOOD, WHITE, 0.15), T(0, y, 0) @ S(12, 0.45, 0.3), 0.06)
    out.append(m)

    m = Mesh("Pedestal", "Lobby")
    m.cyl((235, 235, 245), T(0, 1.25, 0) @ S(1, 2.5, 1), 5, 4.6, 28)
    m.cyl(GOLD, T(0, 2.65, 0) @ S(1, 0.3, 1), 5.1, 5.1, 28)
    m.cyl((220, 220, 235), T(0, 0.2, 0) @ S(1, 0.4, 1), 5.4, 5.4, 28)
    out.append(m)

    m = Mesh("SpeedGate", "Lobby")
    blue, white = (60, 160, 255), (240, 245, 255)
    for side in (-1, 1):
        for i in range(7):
            m.cyl(blue if i % 2 == 0 else white, T(side * 7, i * 2 + 1, 0) @ S(1, 2, 1), 0.6, 0.6, 12)
        m.sphere(GOLD, T(side * 7, 14.6, 0) @ S(1.6), 12, 8)
    m.box(blue, T(0, 14, 0) @ S(14.4, 1.2, 1.2), 0.15)
    for i in range(6):
        m.box(white if i % 2 == 0 else (30, 30, 40), T(-4.5 + i * 1.8, 12.6, 0) @ S(1.8, 1.4, 0.3))
    out.append(m)

    m = Mesh("PortalArch", "Lobby")
    purple, crystal = (90, 70, 140), (255, 110, 200)
    for side in (-1, 1):
        m.box(purple, T(side * 15, 11, 0) @ S(3.2, 22, 3.2), 0.3)
        m.box(mix(purple, WHITE, 0.2), T(side * 15, 0.6, 0) @ S(4.4, 1.2, 4.4), 0.2)
        for i in range(4):
            m.sphere(crystal, T(side * 15, 4 + i * 5, -1.7) @ S(0.8), 8, 6)
    m.box(purple, T(0, 23.5, 0) @ S(34, 3, 3.4), 0.3)
    m.sphere(crystal, T(0, 26.5, 0) @ S(3, 4.5, 3), 6, 4, smooth=False)
    out.append(m)

    m = Mesh("RaceArch", "Track")  # spans X; the track builder turns it across the lane
    for side in (-1, 1):
        m.box(WHITE, T(side * 14, 8, 0) @ S(2, 16, 2), 0.2)
    for i in range(15):
        for j in range(2):
            c = WHITE if (i + j) % 2 == 0 else (25, 25, 30)
            m.box(c, T(-14 + i * 2, 17 + j * 2, 0) @ S(2, 2, 1.6))
    for side in (-1, 1):
        m.sphere((255, 80, 160), T(side * 14, 17.5, 0) @ S(2.4), 10, 8)
    out.append(m)

    m = Mesh("Pillar", "Track")
    for i in range(6):
        c = (235, 70, 70) if i % 2 == 0 else WHITE
        m.box(c, T(0, i * 2 + 1, 0) @ S(4, 2, 18), 0.25 if i in (0, 5) else 0.0)
    out.append(m)

    m = Mesh("Cloud", "Track")
    for p, s in (((0, 6, 0), (24, 12, 18)), ((-10, 4.5, 2), (16, 9, 14)), ((10, 5, -1), (18, 10, 15)), ((3, 9, 2), (14, 8, 12)), ((-5, 3.5, -5), (14, 7, 10))):
        m.sphere(WHITE, T(p) @ S(*s), 14, 10)
    out.append(m)

    m = Mesh("TrophyStatue", "Lobby")
    m.box((60, 60, 75), T(0, 1, 0) @ S(7, 2, 7), 0.25)
    m.box((80, 80, 100), T(0, 2.5, 0) @ S(5, 1, 5), 0.2)
    m.cyl(GOLD, T(0, 3.6, 0) @ S(1, 1.2, 1), 1.6, 1.1, 16)
    m.cyl(GOLD, T(0, 5.5, 0) @ S(1, 2.6, 1), 0.5, 0.5, 12)
    m.cyl(GOLD, T(0, 8.8, 0) @ S(1, 4, 1), 1.2, 2.8, 20)
    m.cyl(mix(GOLD, WHITE, 0.3), T(0, 10.85, 0) @ S(1, 0.3, 1), 2.9, 2.9, 20)
    for side in (-1, 1):
        m.rod(GOLD, (side * 2.2, 10, 0), (side * 3.4, 8.5, 0), 0.35, 0.35, 8)
        m.rod(GOLD, (side * 3.4, 8.5, 0), (side * 2.0, 7.2, 0), 0.35, 0.35, 8)
    m.sphere((255, 90, 160), T(0, 12.4, 0) @ S(1.8), 6, 4, smooth=False)
    out.append(m)

    m = Mesh("LampPost", "Lobby")
    m.cyl((50, 55, 70), T(0, 0.3, 0) @ S(1, 0.6, 1), 0.8, 0.7, 12)
    m.cyl((50, 55, 70), T(0, 5, 0) @ S(1, 9, 1), 0.25, 0.2, 10)
    m.sphere((255, 240, 180), T(0, 10, 0) @ S(1.6), 12, 8)
    m.cyl((50, 55, 70), T(0, 10.9, 0) @ S(1, 0.4, 1), 1.0, 0.3, 12)
    out.append(m)
    return out


# ------------------------------------------------------------ render/export

def make_material(palette_path):
    mat = bpy.data.materials.new("Palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(palette_path)
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.42
    return mat


def export_fbx(obj, path, rig=None):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    if rig:
        rig.select_set(True)
    bpy.context.view_layer.objects.active = rig or obj
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH", "ARMATURE"},
        use_armature_deform_only=False, primary_bone_axis="Y", secondary_bone_axis="X",
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS", global_scale=1.0,
        axis_forward="Z", axis_up="Y", mesh_smooth_type="FACE", use_mesh_modifiers=True,
        use_triangles=False, add_leaf_bones=False, bake_anim=False,
        path_mode="COPY", embed_textures=True)


def setup_render(samples, outline=1.4):
    """Bright toon look: true colours (no filmic wash-out), blue sky, black outlines."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.render.resolution_x = sc.render.resolution_y = 320
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.25
    try:
        sc.render.use_freestyle = True
        sc.render.line_thickness_mode = "ABSOLUTE"
        sc.render.line_thickness = outline
        ls = sc.view_layers[0].freestyle_settings.linesets[0]
        ls.select_by_visibility = True
        ls.select_silhouette = True
        ls.select_border = True
        ls.select_crease = False
        if ls.linestyle is None:
            ls.linestyle = bpy.data.linestyles.new("Toon")
        ls.linestyle.color = (0.08, 0.06, 0.12)
    except Exception as e:  # Freestyle missing in this build: no outlines
        print("no outlines:", e)
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.62, 0.86, 1.0, 1)
    ramp.color_ramp.elements[1].position = 0.6
    ramp.color_ramp.elements[1].color = (0.18, 0.52, 1.0, 1)
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs[0])
    bg.inputs[1].default_value = 0.85
    sc.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.0
    sun.data.color = (1.0, 0.96, 0.88)
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def render(obj, rec, cam, path):
    sx, sy, sz = rec["size"]
    c = Vector((-rec["offset"][0], -rec["offset"][1], -rec["offset"][2]))  # Roblox centre
    cb = (R2B @ c.to_4d()).to_3d()
    radius = 0.5 * math.sqrt(sx * sx + sy * sy + sz * sz)
    # From the front-left, a bit above (Roblox front is -Z -> Blender -Y).
    d = Vector((0.75, -1.0, 0.55)).normalized()
    cam.location = cb + d * radius * 2.9
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def contact_sheet(paths, out_path, cols=6, cell=160):
    imgs = []
    for p in paths:
        im = bpy.data.images.load(p)
        imgs.append(im)
    rows = (len(imgs) + cols - 1) // cols
    W, H = cols * cell, rows * cell
    canvas = [0.95] * (W * H * 4)
    for idx, im in enumerate(imgs):
        w, h = im.size
        px = list(im.pixels)
        ox, oy = (idx % cols) * cell, (rows - 1 - idx // cols) * cell
        for y in range(cell):
            sy = int(y * h / cell)
            for x in range(cell):
                sx = int(x * w / cell)
                si = (sy * w + sx) * 4
                di = ((oy + y) * W + ox + x) * 4
                canvas[di:di + 4] = px[si:si + 4]
    sheet = bpy.data.images.new("sheet", W, H)
    sheet.pixels = canvas
    sheet.filepath_raw = out_path
    sheet.file_format = "PNG"
    sheet.save()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--no-render", action="store_true")
    ap.add_argument("--samples", type=int, default=12)
    args = ap.parse_args(argv)
    only = {s.strip() for s in args.only.split(",") if s.strip()}

    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(FBX_DIR, exist_ok=True)
    os.makedirs(RENDER_DIR, exist_ok=True)

    meshes = [build_pet(sp) for sp in lua_species()]
    meshes += [build_egg(eid, c) for eid, c in lua_eggs()]
    meshes += build_props()

    built = []
    mesh_of = {m.name: m for m in meshes}
    for m in meshes:
        obj, rec = m.finish()  # every model is built so the palette is identical each run
        built.append((obj, rec))

    palette_path = os.path.join(OUT, "palette.png")
    write_palette(palette_path)
    mat = make_material(palette_path)

    cat_path = os.path.join(OUT, "catalog.json")
    catalog = {}
    if os.path.exists(cat_path):
        catalog = {r["name"]: r for r in json.load(open(cat_path))}
    cam = None if args.no_render else setup_render(args.samples)
    coll = bpy.context.scene.collection
    renders = []
    for obj, rec in built:
        catalog[rec["name"]] = rec
        if only and rec["name"] not in only and rec["category"] not in only:
            continue
        obj.data.materials.append(mat)
        coll.objects.link(obj)
        rig = mesh_of[rec["name"]].make_armature(obj, coll) if mesh_of[rec["name"]].bones else None
        export_fbx(obj, os.path.join(FBX_DIR, rec["name"] + ".fbx"), rig)
        print(f"  {rec['name']:<16} {rec['tris']:>6} tris  size {rec['size']}")
        if cam:
            for o in coll.objects:
                if o.type == "MESH":
                    o.hide_render = o is not obj
            p = os.path.join(RENDER_DIR, rec["name"] + ".png")
            render(obj, rec, cam, p)
            renders.append(p)
    with open(cat_path, "w") as f:
        json.dump(sorted(catalog.values(), key=lambda r: (r["category"], r["name"])), f, indent=1)
    if renders and not only:
        contact_sheet(renders, os.path.join(RENDER_DIR, "_sheet.png"))
    print(f"{len(built)} models, {len(PALETTE)} palette colours")


if __name__ == "__main__":
    main()
