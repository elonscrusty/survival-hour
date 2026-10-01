"""Shared helpers for the Egg Farm asset scripts.

Everything is modelled procedurally with bmesh primitives into ONE mesh per asset.
Authoring happens in Roblox studs (easier to reason about game scale); `Builder.finish`
recentres the mesh (origin at base centre), scales studs -> metres (1 stud = 0.28 m) and
flat-shades it. Blender is Z-up; the FBX/OBJ exporters convert to Roblox's Y-up.
"""

import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

STUD = 0.28  # metres per Roblox stud

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Shared palette (sRGB 0-255). Meadow theme values from src/shared/Data/Themes.luau plus a few neutrals.
PALETTE = {
    "Grass": (108, 186, 82),
    "GrassDark": (86, 158, 66),
    "Path": (214, 186, 132),
    "Wood": (168, 112, 70),
    "WoodDark": (120, 78, 48),
    "Roof": (206, 64, 52),
    "RoofDark": (160, 46, 40),
    "Accent": (255, 214, 74),
    "White": (244, 242, 236),
    "Cream": (250, 236, 200),
    "Grey": (150, 154, 160),
    "GreyDark": (84, 88, 96),
    "Metal": (196, 202, 210),
    "Glass": (150, 206, 236),
    "Black": (40, 40, 46),
    "Tyre": (34, 34, 38),
    "Beak": (255, 170, 40),
    "Comb": (220, 50, 50),
    "Brown": (150, 92, 52),
    "BrownLight": (196, 132, 80),
    "Fox": (226, 112, 40),
    "Skin": (240, 196, 150),
    "Denim": (66, 104, 170),
    "Shirt": (206, 64, 52),
    "Hair": (98, 64, 40),
    "Straw": (236, 200, 110),
    "Leaf": (82, 160, 70),
    "LeafDark": (60, 128, 56),
    "Trunk": (124, 84, 52),
    "Rock": (140, 140, 136),
    "RockDark": (112, 112, 110),
    "Blue": (70, 130, 200),
    "Green": (76, 168, 96),
    "Teal": (54, 170, 196),
    "Light": (255, 246, 200),
}


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, rgb, emission=0.0, rough=0.8, metal=0.0):
    """Get-or-create a flat-colour material named EF_<name>."""
    full = "EF_" + name
    m = bpy.data.materials.get(full)
    if m:
        return m
    m = bpy.data.materials.new(full)
    lin = tuple(srgb_to_linear(v) for v in rgb) + (1.0,)
    m.diffuse_color = lin
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = lin
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if emission > 0:
            bsdf.inputs["Emission Color"].default_value = lin
            bsdf.inputs["Emission Strength"].default_value = emission
    return m


def xform(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """loc in studs, rot in degrees (XYZ euler), scale per axis."""
    r = Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()
    s = Matrix.Diagonal(Vector((scale[0], scale[1], scale[2], 1.0)))
    return Matrix.Translation(Vector(loc)) @ r @ s


class Builder:
    """Accumulates primitives into one bmesh. Coordinates are studs: X right, Y back, Z up.

    The model's FRONT faces -Y (Blender's front view), which ends up facing -Z (Roblox front)
    after export with axis_forward='-Z', axis_up='Y'.
    """

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []  # list of material names (palette keys or custom)
        self.custom = {}

    # ---------- materials ----------
    def mi(self, key, rgb=None, **kw):
        if rgb is not None:
            self.custom[key] = (rgb, kw)
        elif key not in PALETTE and key not in self.custom:
            raise KeyError(key)
        if key not in self.mats:
            self.mats.append(key)
        return self.mats.index(key)

    def _tag(self, geom, mat, before_faces):
        idx = self.mi(mat)
        new_faces = [f for f in self.bm.faces if f.index == -1 or f not in before_faces]
        for f in new_faces:
            f.material_index = idx
        self.bm.faces.index_update()
        return new_faces

    def _snapshot(self):
        self.bm.faces.index_update()
        return set(self.bm.faces)

    # ---------- primitives ----------
    def box(self, size, loc=(0, 0, 0), mat="White", rot=(0, 0, 0)):
        """Axis box of `size` (x,y,z) centred on loc."""
        before = self._snapshot()
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=xform(loc, rot, size))
        return self._tag(None, mat, before)

    def boxb(self, size, base=(0, 0, 0), mat="White", rot=(0, 0, 0)):
        """Box whose BOTTOM centre sits at `base`."""
        x, y, z = base
        return self.box(size, (x, y, z + size[2] / 2), mat, rot)

    def cyl(self, r, h, loc=(0, 0, 0), mat="White", segs=12, r2=None, rot=(0, 0, 0), scale=(1, 1, 1)):
        """Cylinder/cone along local Z, centred on loc (rotate to change axis)."""
        before = self._snapshot()
        r2 = r if r2 is None else r2
        m = xform(loc, rot, scale)
        bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs,
                              radius1=r, radius2=max(r2, 0.0), depth=h, matrix=m)
        return self._tag(None, mat, before)

    def cylb(self, r, h, base=(0, 0, 0), mat="White", segs=12, r2=None, scale=(1, 1, 1)):
        x, y, z = base
        return self.cyl(r, h, (x, y, z + h / 2), mat, segs, r2, scale=scale)

    def sphere(self, r, loc=(0, 0, 0), mat="White", scale=(1, 1, 1), u=10, v=6, rot=(0, 0, 0)):
        before = self._snapshot()
        bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=r,
                                  matrix=xform(loc, rot, scale))
        return self._tag(None, mat, before)

    def ico(self, r, loc=(0, 0, 0), mat="White", scale=(1, 1, 1), sub=1, rot=(0, 0, 0)):
        before = self._snapshot()
        bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=r, matrix=xform(loc, rot, scale))
        return self._tag(None, mat, before)

    def prism(self, pts, length, loc=(0, 0, 0), mat="Roof", rot=(0, 0, 0)):
        """Extrude a convex 2D polygon `pts` [(x,z),...] (in the XZ plane) along Y by `length`,
        centred on loc. Good for gable roofs, wedges and ramps."""
        before = self._snapshot()
        m = xform(loc, rot)
        hl = length / 2
        front = [self.bm.verts.new(m @ Vector((x, -hl, z))) for x, z in pts]
        back = [self.bm.verts.new(m @ Vector((x, hl, z))) for x, z in pts]
        n = len(pts)
        self.bm.faces.new(list(reversed(front)))
        self.bm.faces.new(back)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new([front[i], front[j], back[j], back[i]])
        faces = self._tag(None, mat, before)
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        return faces

    def gable(self, width, length, rise, base=(0, 0, 0), mat="Roof", overhang=0.8, thick=0.6):
        """Gable roof with the ridge along Y: two slanted slabs meeting over x=base.x.
        `base` is the eave line centre (top of the walls)."""
        x, y, z = base
        half = width / 2
        ang = math.atan2(rise, half)
        slant = math.hypot(half, rise) + overhang
        L = length + overhang * 2
        lift = thick / 2 / math.cos(ang)
        for side in (-1, 1):
            # slab centre: halfway along the slope, extended by the overhang at the eave end
            mx = side * (half / 2 + overhang * math.cos(ang) / 2)
            mz = rise / 2 - overhang * math.sin(ang) / 2 + lift
            self.box((slant, L, thick), (x + mx, y, z + mz), mat, rot=(0, side * math.degrees(ang), 0))
        # ridge cap
        self.box((thick * 1.6, L + 0.1, thick * 1.2), (x, y, z + rise + lift * 1.2), mat)

    def gable_fill(self, width, length, rise, base=(0, 0, 0), mat="Wood", rot=(0, 0, 0)):
        """Solid triangular gable wall (fills the space under a gable roof)."""
        w = width / 2
        x, y, z = base
        self.prism([(-w, 0), (w, 0), (0, rise)], length, (x, y, z), mat, rot)

    def merge(self, other_fn):
        other_fn(self)

    # ---------- output ----------
    def finish(self, collection=None):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        # recentre: x/y centre, min z = 0
        xs = [v.co.x for v in bm.verts]
        ys = [v.co.y for v in bm.verts]
        zs = [v.co.z for v in bm.verts]
        off = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
        bmesh.ops.translate(bm, verts=bm.verts, vec=-off)
        bmesh.ops.scale(bm, verts=bm.verts, vec=(STUD, STUD, STUD))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for f in bm.faces:
            f.smooth = False
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for key in self.mats:
            if key in self.custom:
                rgb, kw = self.custom[key]
                me.materials.append(material(key, rgb, **kw))
            else:
                kw = {}
                if key in ("Light",):
                    kw["emission"] = 2.0
                if key in ("Metal",):
                    kw["metal"] = 0.6
                    kw["rough"] = 0.4
                if key == "Glass":
                    kw["rough"] = 0.2
                me.materials.append(material(key, PALETTE[key], **kw))
        ob = bpy.data.objects.new(self.name, me)
        (collection or bpy.context.scene.collection).objects.link(ob)
        return ob


def tri_count(ob):
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def dims_studs(ob):
    d = ob.dimensions
    # Blender X,Y,Z -> Roblox X (width), Z (depth), Y (height)
    return (d.x / STUD, d.z / STUD, d.y / STUD)


def verts_of(faces):
    seen = []
    ids = set()
    for f in faces:
        for v in f.verts:
            if id(v) not in ids:
                ids.add(id(v))
                seen.append(v)
    return seen


def deform(faces, fn):
    """Apply fn(Vector)->Vector to every vertex of the given faces (each vertex once)."""
    for v in verts_of(faces):
        v.co = fn(v.co.copy())
