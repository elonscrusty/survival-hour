"""Low-poly modeling helpers for Survival Hour.

Every asset is built into one bmesh, then turned into a single Blender object
that uses one shared material: a small palette texture. Each face is UV-mapped
to the centre of one colour cell, so a whole model imports into Roblox as a
single MeshPart with a single texture.

Units: 1 Blender unit = 1 Roblox stud. Models sit on the ground at Z = 0,
except hand tools, whose origin is at the grip.
"""

import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# Palette colours (sRGB hex). Add new colours at the END so existing UVs
# keep pointing at the same cells.
PALETTE = [
    ("bark", "5b3a24"),
    ("bark_dark", "402818"),
    ("wood", "a8784a"),
    ("wood_light", "d2a36c"),
    ("wood_dark", "6e4a2c"),
    ("leaf", "3f8a3a"),
    ("leaf_dark", "2c6a33"),
    ("leaf_light", "6bab45"),
    ("pine", "2f6b4a"),
    ("pine_dark", "1f4d38"),
    ("stone", "8a8d91"),
    ("stone_dark", "5f6368"),
    ("stone_light", "b3b5b8"),
    ("steel", "a7b0ba"),
    ("steel_dark", "5c646e"),
    ("berry", "c0283a"),
    ("fire_red", "d8452b"),
    ("fire_orange", "f28c28"),
    ("fire_yellow", "ffd24a"),
    ("ash", "3a3533"),
    ("canvas", "c9a66b"),
    ("canvas_dark", "8c6f43"),
    ("cloth", "7a3b2e"),
    ("rope", "b89968"),
    ("water_blue", "3e6f8e"),
    ("metal_cap", "3b3f45"),
    ("leather", "6b4226"),
    ("charcoal", "1e1b1a"),
]
COLOR_INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}

GRID = 8  # 8 x 8 cells
CELL_PX = 8  # each cell is 8 x 8 pixels
TEX_SIZE = GRID * CELL_PX  # 64 x 64 texture


def cell_uv(index):
    """UV coordinate at the centre of a palette cell."""
    cx, cy = index % GRID, index // GRID
    return ((cx + 0.5) / GRID, (cy + 0.5) / GRID)


def make_palette_image(path):
    img = bpy.data.images.new("survival_palette", TEX_SIZE, TEX_SIZE, alpha=False)
    pixels = [0.0] * (TEX_SIZE * TEX_SIZE * 4)
    for i, (_, hexcol) in enumerate(PALETTE):
        rgb = [int(hexcol[j:j + 2], 16) / 255 for j in (0, 2, 4)]
        cx, cy = i % GRID, i // GRID
        for py in range(cy * CELL_PX, (cy + 1) * CELL_PX):
            for px in range(cx * CELL_PX, (cx + 1) * CELL_PX):
                o = (py * TEX_SIZE + px) * 4
                pixels[o:o + 4] = [*rgb, 1.0]
    img.pixels[:] = pixels
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.filepath = path
    return img


def make_palette_material(image):
    mat = bpy.data.materials.new("SurvivalPalette")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.9
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"  # no colour bleeding between cells
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def xform(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Matrix from location, rotation in degrees (XYZ) and scale."""
    r = Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    return Matrix.Translation(Vector(loc)) @ r @ Matrix.Diagonal(Vector((*scale, 1.0)))


class Model:
    """Collects low-poly parts into one mesh."""

    def __init__(self, name, seed=0):
        self.name = name
        self.rng = random.Random(seed)
        self.bm = bmesh.new()
        self.pal = self.bm.faces.layers.int.new("pal")

    # -- internals -------------------------------------------------------

    def _faces(self, verts):
        faces = set()
        for v in verts:
            faces.update(v.link_faces)
        return faces

    def _paint(self, verts, color):
        idx = COLOR_INDEX[color]
        for f in self._faces(verts):
            f[self.pal] = idx
        return verts

    # -- primitives ------------------------------------------------------

    def cylinder(self, color, r1, r2, h, segments=8, loc=(0, 0, 0), rot=(0, 0, 0),
                 scale=(1, 1, 1), cap_color=None):
        """Cylinder or cone standing on its base at `loc` (before rotation).
        r2 = 0 makes a pointed cone."""
        m = xform(loc, rot, scale) @ Matrix.Translation((0, 0, h / 2))
        verts = bmesh.ops.create_cone(
            self.bm, cap_ends=True, cap_tris=False, segments=segments,
            radius1=r1, radius2=r2, depth=h, matrix=m)["verts"]
        self._paint(verts, color)
        if cap_color:
            for f in self._faces(verts):
                if len(f.verts) == segments:
                    f[self.pal] = COLOR_INDEX[cap_color]
        return verts

    def cone(self, color, r, h, segments=8, **kw):
        return self.cylinder(color, r, 0, h, segments, **kw)

    def box(self, color, size, loc=(0, 0, 0), rot=(0, 0, 0)):
        """Box of `size` (x, y, z) centred on `loc`."""
        verts = bmesh.ops.create_cube(self.bm, size=1.0, matrix=xform(loc, rot, size))["verts"]
        return self._paint(verts, color)

    def blob(self, color, radius, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1),
             jitter=0.0, subdiv=1):
        """Icosphere with random vertex jitter: rocks, leaf clumps, berries."""
        verts = bmesh.ops.create_icosphere(
            self.bm, subdivisions=subdiv, radius=radius,
            matrix=xform(loc, rot, scale))["verts"]
        self.jitter(verts, jitter)
        return self._paint(verts, color)

    def prism(self, color, profile, depth, loc=(0, 0, 0), rot=(0, 0, 0)):
        """Extrude a 2D profile [(x, z), ...] along Y by `depth`, centred."""
        m = xform(loc, rot)
        front = [self.bm.verts.new(m @ Vector((x, -depth / 2, z))) for x, z in profile]
        back = [self.bm.verts.new(m @ Vector((x, depth / 2, z))) for x, z in profile]
        self.bm.faces.new(front)
        self.bm.faces.new(list(reversed(back)))
        n = len(profile)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((front[i], back[i], back[j], front[j]))
        return self._paint(front + back, color)

    # -- modifiers -------------------------------------------------------

    def jitter(self, verts, amount):
        if amount:
            for v in verts:
                v.co += Vector([self.rng.uniform(-amount, amount) for _ in range(3)])
        return verts

    def flatten_below(self, z=0.0, verts=None):
        """Push any vertex below `z` up to `z` so the model sits flat."""
        for v in verts if verts is not None else self.bm.verts:
            if v.co.z < z:
                v.co.z = z

    # -- output ----------------------------------------------------------

    def build(self, material, collection):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            f.smooth = False
            u = cell_uv(f[self.pal])
            for loop in f.loops:
                loop[uv].uv = u
        bm.faces.layers.int.remove(self.pal)

        mesh = bpy.data.meshes.new(self.name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(material)
        obj = bpy.data.objects.new(self.name, mesh)
        collection.objects.link(obj)
        return obj
