"""Segmented wildlife: one static mesh per part of the in-game creature rigs.

The game's animals (src/shared/Models/Animals.luau) are part-built rigs whose
Motor6Ds (Body, Neck, LegFL/FR/BL/BR, Tail; the bat's WingL/WingR) are posed
procedurally by the client. Each mesh here dresses one of those parts, so the
existing animation moves it:

  SM_<Species>_Body   -> Torso      (torso, belly, chest, neck base)
  SM_<Species>_Head   -> Head       (head, snout, ears, eyes, upper neck)
  SM_<Species>_LegF   -> LegFL, LegFR (symmetric, shared)
  SM_<Species>_LegB   -> LegBL, LegBR
  SM_<Species>_Tail   -> TailPart
  SM_Bat_Body         -> Body       (body, head, ears)
  SM_Bat_Wing         -> WingRPart, and WingLPart turned 180 deg about its forward axis

Every mesh's origin is its rig part's centre (Motor6D C1 space), so the game
places it with part.CFrame and welds it. The rig numbers below mirror
Animals.luau: change both together. Blender axes: -Y forward, +Z up, X side
(Roblox X = -Blender X, Roblox Y = Blender Z, Roblox Z = Blender Y).
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

from sh import pipeline as P
from sh import textures as tx

CAT = "Animals"

# W, H, L, Leg, Tail, Scale exactly as in Animals.luau
RIGS = {
    "Wolf": (1.6, 1.7, 4.2, 2.4, 2.4, 1.0),
    "Bear": (2.2, 2.2, 4.0, 2.1, 0.6, 1.8),
    "Deer": (1.3, 1.6, 3.8, 3.2, 0.5, 1.1),
    "Rabbit": (1.4, 1.4, 2.2, 1.1, 0.6, 0.45),
    "Boar": (1.8, 1.8, 3.4, 1.5, 0.6, 1.05),
}


class Rig:
    """Joint positions of Animals.luau's quadruped(), in Blender coordinates."""

    def __init__(self, sp):
        W, H, L, Leg, Tail, s = RIGS[sp]
        self.s = s
        self.w, self.h, self.l = W * s, H * s, L * s
        self.leg, self.tail = Leg * s, Tail * s
        self.neck = Vector((0, -0.55 * L * s, 0.35 * H * s))  # Neck C0 (torso space)
        self.neck_in_head = Vector((0, 0.05 * L * s, 0))  # Neck C1 (head space)
        self.hip_f = Vector((0.32 * W * s, -0.36 * L * s, -0.3 * H * s))
        self.hip_b = Vector((0.32 * W * s, 0.36 * L * s, -0.3 * H * s))
        self.tail_joint = Vector((0, 0.5 * L * s, 0.25 * H * s))
        self.ground = -0.3 * H * s - Leg * s - 0.15 * s  # torso space
        self.foot = -Leg * s / 2 - 0.15 * s  # leg space: bottom of the paw


# ------------------------------------------------------------------ helpers

class Skel:
    """Skin-modifier skeleton: nodes (position, radius) joined by edges."""

    def __init__(self):
        self.nodes, self.edges = [], []

    def n(self, pos, r, link=None):
        self.nodes.append((Vector(pos), r))
        i = len(self.nodes) - 1
        if link is not None:
            self.edges.append((link, i))
        return i

    def chain(self, start, pts):
        prev = start
        for p, r in pts:
            prev = self.n(p, r, prev)
        return prev

    def build(self, m, paint, subdiv=1, scale=(1, 1, 1), fit=None, keep=None, floor=None):
        """Adds the skinned, subdivided surface to Model m; paint(centre, normal) -> tile.
        fit=(lo, hi) stretches the result to exactly fill that box (rig part bounds);
        keep < 1 decimates to that share of the faces (thin limbs need fewer);
        floor stretches the lower end down to that height and flattens it (a sole
        standing exactly on the rig's ground)."""
        me = bpy.data.meshes.new("skin_tmp")
        me.from_pydata([tuple(p) for p, _ in self.nodes], self.edges, [])
        o = bpy.data.objects.new("skin_tmp", me)
        bpy.context.scene.collection.objects.link(o)
        o.modifiers.new("Skin", "SKIN")
        if len(me.skin_vertices) == 0:
            me.skin_vertices.new()
        for d, (_, r) in zip(me.skin_vertices[0].data, self.nodes):
            d.radius = (r, r)
        me.skin_vertices[0].data[0].use_root = True
        if subdiv:
            o.modifiers.new("Sub", "SUBSURF").levels = subdiv
        if keep:
            o.modifiers.new("Dec", "DECIMATE").ratio = keep
        dg = bpy.context.evaluated_depsgraph_get()
        ev = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        tmp = bmesh.new()
        tmp.from_mesh(ev)
        bm = m.bm
        sc = Vector(scale)
        pts = {v: Vector((v.co.x * sc.x, v.co.y * sc.y, v.co.z * sc.z)) for v in tmp.verts}
        if fit:
            lo0 = [min(p[i] for p in pts.values()) for i in range(3)]
            hi0 = [max(p[i] for p in pts.values()) for i in range(3)]
            lo, hi = fit
            for p in pts.values():
                for i in range(3):
                    p[i] = lo[i] + (p[i] - lo0[i]) / (hi0[i] - lo0[i]) * (hi[i] - lo[i])
        if floor is not None:
            zmin = min(p.z for p in pts.values())
            zmax = max(p.z for p in pts.values())
            low = floor - 0.04 * (zmax - zmin)
            for p in pts.values():
                p.z = max(floor, zmax - (zmax - p.z) * (zmax - low) / (zmax - zmin))
        vmap = {v: bm.verts.new(p) for v, p in pts.items()}
        faces = []
        for f in tmp.faces:
            nf = bm.faces.new([vmap[v] for v in f.verts])
            faces.append(nf)
        tmp.free()
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
        bpy.data.meshes.remove(ev)
        # the skin modifier can leave small gaps where branches meet: close them
        edges = list({e for f in faces for e in f.edges if len(e.link_faces) == 1})
        if edges:
            faces += bmesh.ops.holes_fill(bm, edges=edges, sides=0)["faces"]
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        for f in faces:
            f.normal_update()
            f[m.l_mat] = tx.TILE_INDEX[paint(f.calc_center_median(), f.normal)]
        return list(vmap.values())


def surface(m, target, outward):
    """Point on the current surface of m hit by a ray from outside, travelling
    along -outward through `target`. Returns (point, normal)."""
    bm = m.bm
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    d = Vector(outward).normalized()
    hit, nrm, _, _ = tree.ray_cast(Vector(target) + d * 4.0, -d)
    if hit is None:
        return Vector(target), d
    return hit, nrm


def eye(m, target, outward, r, iris="eye_glow", pupil=True):
    """Eye set into the surface: a coloured ball with a dark pupil in front."""
    p, n = surface(m, target, outward)
    c = p - n * r * 0.35
    m.blob(iris, r, loc=c, subdiv=2)
    if pupil:
        m.blob("eye", r * 0.55, loc=c + n * r * 0.62, scale=(1, 1, 1), subdiv=1)
    return p, n


def flatten_bottom(m, z):
    for v in m.bm.verts:
        if v.co.z < z:
            v.co.z = z


def ear(m, mat, base, h, r, tilt_out, tilt_fwd, flat=0.45, inner=None, sg=1):
    """Pointed ear: flattened cone standing on `base`, tilted outwards (and
    forwards for positive tilt_fwd)."""
    m.cone(mat, r, h, seg=6, loc=base, rot=(tilt_fwd, sg * tilt_out, 0), scale=(1, flat, 1))
    if inner:
        rot = Matrix.Rotation(math.radians(sg * tilt_out), 3, "Y") @ Matrix.Rotation(math.radians(tilt_fwd), 3, "X")
        fwd = rot @ Vector((0, -1, 0))
        m.cone(inner, r * 0.62, h * 0.72, seg=6,
               loc=Vector(base) + fwd * r * flat * 0.45 + rot @ Vector((0, 0, h * 0.08)),
               rot=(tilt_fwd, sg * tilt_out, 0), scale=(1, flat * 0.5, 1))


def membrane(m, poly, thickness, mat="membrane"):
    """Thin watertight wing membrane in the XY plane (centred on z=0)."""
    tmp = bmesh.new()
    vs = [tmp.verts.new((x, y, 0)) for x, y in poly]
    tmp.faces.new(vs)
    bmesh.ops.triangulate(tmp, faces=tmp.faces[:], ngon_method="BEAUTY")
    bmesh.ops.subdivide_edges(tmp, edges=tmp.edges[:], cuts=1, use_grid_fill=True)
    bm = m.bm
    top = {v: bm.verts.new(v.co + Vector((0, 0, thickness / 2))) for v in tmp.verts}
    bot = {v: bm.verts.new(v.co - Vector((0, 0, thickness / 2))) for v in tmp.verts}
    for f in tmp.faces:
        a = bm.faces.new([top[v] for v in f.verts])
        b = bm.faces.new([bot[v] for v in reversed(f.verts)])
        a[m.l_mat] = b[m.l_mat] = tx.TILE_INDEX[mat]
    for e in tmp.edges:
        if len(e.link_faces) == 1:
            v0, v1 = e.verts
            f = bm.faces.new((top[v0], top[v1], bot[v1], bot[v0]))
            f[m.l_mat] = tx.TILE_INDEX[mat]
    tmp.free()


# ------------------------------------------------------------------- wolf

def wolf_body(m):
    k = Skel()
    rump = k.n((0, 1.8, 0.28), 0.5)
    hips = k.n((0, 1.25, 0.18), 0.64, rump)
    mid = k.n((0, 0.15, 0.2), 0.6, hips)
    chest = k.n((0, -1.05, 0.12), 0.78, mid)
    k.n((0, -1.9, 0.42), 0.6, chest)  # neck base
    k.n((0, -1.2, -0.32), 0.56, chest)  # deep chest
    for sg in (1, -1):
        k.n((sg * 0.4, -1.5, -0.28), 0.42, chest)
        k.n((sg * 0.38, 1.5, -0.2), 0.5, hips)

    def paint(c, n):
        if n.z < -0.35 and c.z < 0.1 or (c.y < -1.5 and c.z < -0.2):
            return "fur_light"
        if n.z > 0.6 and -0.9 < c.y < 1.6:
            return "fur_bat"
        return "fur_grey"
    k.build(m, paint, fit=((-0.74, -2.12, -0.8), (0.74, 2.08, 0.8)))


def wolf_head(m):
    k = Skel()
    neck = k.n((0, 0.8, -0.42), 0.5)
    nape = k.n((0, 0.3, -0.06), 0.52, neck)
    skull = k.n((0, -0.12, 0.14), 0.52, nape)
    cheek = k.n((0, -0.5, -0.06), 0.44, skull)
    muzzle = k.n((0, -0.98, -0.18), 0.26, cheek)
    k.n((0, -1.36, -0.18), 0.16, muzzle)

    def paint(c, n):
        if c.y < -0.3 and (n.z < -0.2 or c.z < -0.2):
            return "fur_light"
        if n.z > 0.55 and c.y > -0.6:
            return "fur_bat"
        return "fur_grey"
    k.build(m, paint, scale=(0.95, 1, 1))
    for sg in (1, -1):
        eye(m, (sg * 0.3, -0.58, 0.2), (sg * 0.55, -0.8, 0.15), 0.1)
        # brow ridge
        p, n = surface(m, (sg * 0.26, -0.5, 0.36), (sg * 0.3, -0.5, 0.8))
        m.box("fur_bat", (0.22, 0.12, 0.05), loc=p, rot=(20, sg * -16, sg * 8))
        ear(m, "fur_grey", (sg * 0.28, 0.02, 0.5), 0.62, 0.22, 16, -8, inner="fur_bat", sg=sg)
        m.cone("bone", 0.035, 0.13, seg=4, loc=(sg * 0.1, -1.3, -0.33), rot=(180, 0, 0))
    m.blob("nose", 0.13, loc=(0, -1.52, -0.12), scale=(1.1, 0.85, 0.8))


def toes(m, foot, mat="fur_light", r=0.07, xs=(-0.08, 0.08)):
    """Two toe bumps on the front of a paw, resting on the ground."""
    for x in xs:
        p, n = surface(m, (x, -0.1, foot + r * 0.9), (0, -1, 0))
        m.blob(mat, r, loc=(p.x, p.y + r * 0.2, foot + r * 0.8), scale=(1, 1.3, 0.8), subdiv=1)


def wolf_leg_f(m, r):
    k = Skel()
    top = k.n((0, 0, 1.6), 0.3)
    k.chain(top, [((0, -0.02, 1.15), 0.36), ((0, 0.04, 0.55), 0.27), ((0, 0.1, 0.05), 0.19),
                  ((0, 0.03, -0.8), 0.13), ((0, -0.12, -1.2), 0.17)])
    k.build(m, lambda c, n: "fur_light" if c.z < -0.55 else "fur_grey", keep=0.65, floor=r.foot)
    flatten_bottom(m, r.foot)
    toes(m, r.foot)


def wolf_leg_b(m, r):
    k = Skel()
    top = k.n((0, 0, 1.6), 0.36)
    k.chain(top, [((0, -0.1, 1.1), 0.44), ((0, -0.2, 0.45), 0.32), ((0, 0.05, -0.1), 0.2),
                  ((0, 0.34, -0.55), 0.14), ((0, 0.12, -1.0), 0.13), ((0, -0.08, -1.22), 0.17)])
    k.build(m, lambda c, n: "fur_light" if c.z < -0.75 else "fur_grey", keep=0.65, floor=r.foot)
    flatten_bottom(m, r.foot)
    toes(m, r.foot)


def wolf_tail(m):
    k = Skel()
    k.chain(k.n((0, -1.6, 0.08), 0.1), [((0, -1.2, 0.04), 0.16), ((0, -0.75, -0.02), 0.24), ((0, 0.05, -0.14), 0.3),
                                          ((0, 0.75, -0.32), 0.22), ((0, 1.3, -0.5), 0.07)])
    k.build(m, lambda c, n: "fur_bat" if c.y > 0.75 or (n.z > 0.6 and c.y < -0.4) else
            ("fur_light" if n.z < -0.5 else "fur_grey"), keep=0.65)


# ------------------------------------------------------------------- bear

def bear_body(m):
    k = Skel()
    rump = k.n((0, 2.6, 0.25), 1.35)
    hips = k.n((0, 1.7, 0.2), 1.65, rump)
    mid = k.n((0, 0.1, 0.25), 1.68, hips)
    chest = k.n((0, -1.9, 0.15), 1.72, mid)
    k.n((0, -1.3, 1.05), 1.25, chest)  # shoulder hump
    k.n((0, -3.2, 0.75), 1.25, chest)  # neck base
    for sg in (1, -1):
        k.n((sg * 1.05, -2.5, -0.6), 0.95, chest)
        k.n((sg * 1.0, 2.45, -0.5), 1.1, hips)

    def paint(c, n):
        if n.z < -0.5 and c.z < -1.2:
            return "fur_bat"
        return "fur_brown"
    k.build(m, paint, fit=((-1.9, -3.85, -1.75), (1.9, 3.65, 1.95)))


def bear_head(m):
    k = Skel()
    neck = k.n((0, 1.25, -0.55), 1.1)
    nape = k.n((0, 0.5, -0.05), 1.12, neck)
    skull = k.n((0, -0.3, 0.22), 1.05, nape)
    cheek = k.n((0, -0.65, -0.25), 0.98, skull)
    muzzle = k.n((0, -1.45, -0.5), 0.58, cheek)
    k.n((0, -2.0, -0.5), 0.4, muzzle)

    def paint(c, n):
        if c.y < -1.25 and (c.z < -0.05 or n.y < -0.5):
            return "fur_light"
        return "fur_brown"
    k.build(m, paint, scale=(0.95, 1, 0.95))
    for sg in (1, -1):
        eye(m, (sg * 0.55, -1.2, 0.35), (sg * 0.45, -0.85, 0.3), 0.14)
        p, n = surface(m, (sg * 0.5, -1.05, 0.55), (sg * 0.3, -0.55, 0.8))
        m.box("fur_bat", (0.45, 0.3, 0.1), loc=p, rot=(20, sg * -14, sg * 6))
        m.blob("fur_brown", 0.42, loc=(sg * 0.85, 0.05, 0.95), scale=(1, 0.5, 1), subdiv=2)
        m.blob("fur_bat", 0.25, loc=(sg * 0.85, -0.12, 0.95), scale=(0.8, 0.35, 0.8), subdiv=2)
        m.cone("bone", 0.07, 0.24, seg=4, loc=(sg * 0.2, -2.2, -0.72), rot=(180, 0, 0))
    m.blob("nose", 0.3, loc=(0, -2.38, -0.4), scale=(1.2, 0.8, 0.8))


def bear_leg(m, r, front):
    k = Skel()
    if front:
        top = k.n((0, 0, 2.6), 0.8)
        k.chain(top, [((0, 0, 1.8), 0.95), ((0, 0.05, 0.7), 0.72), ((0, 0.05, -0.6), 0.56),
                      ((0, -0.05, -1.35), 0.52), ((0, -0.3, -1.85), 0.58)])
    else:
        top = k.n((0, 0, 2.6), 0.9)
        k.chain(top, [((0, -0.15, 1.7), 1.05), ((0, -0.25, 0.7), 0.82), ((0, 0.25, -0.5), 0.54),
                      ((0, 0.15, -1.3), 0.5), ((0, -0.2, -1.85), 0.58)])
    k.build(m, lambda c, n: "fur_bat" if c.z < -1.45 else "fur_brown", floor=r.foot)
    flatten_bottom(m, r.foot)
    for x in (-0.3, -0.1, 0.1, 0.3):
        p, n = surface(m, (x, -0.4, r.foot + 0.2), (0, -1, 0.15))
        m.cone("bone", 0.07, 0.3, seg=4, loc=p - Vector((0, -0.05, 0)), rot=(100, 0, 0))


def bear_tail(m):
    k = Skel()
    k.chain(k.n((0, -0.6, 0.05), 0.3), [((0, 0.05, -0.05), 0.36), ((0, 0.45, -0.15), 0.16)])
    k.build(m, lambda c, n: "fur_brown")


# ------------------------------------------------------------------- deer

def deer_body(m):
    k = Skel()
    rump = k.n((0, 1.72, 0.22), 0.52)
    hips = k.n((0, 1.2, 0.12), 0.6, rump)
    mid = k.n((0, 0.05, 0.08), 0.58, hips)
    chest = k.n((0, -1.15, 0.1), 0.64, mid)
    k.n((0, -1.75, 0.42), 0.46, chest)  # neck base
    k.n((0, -1.15, -0.32), 0.44, chest)  # brisket
    for sg in (1, -1):
        k.n((sg * 0.34, -1.4, -0.22), 0.36, chest)
        k.n((sg * 0.34, 1.4, -0.15), 0.44, hips)

    def paint(c, n):
        if c.y > 1.75 and c.z < 0.45 or (n.z < -0.4 and c.z < -0.3):
            return "fur_light"
        return "fur_brown"
    k.build(m, paint, fit=((-0.66, -2.15, -0.74), (0.66, 2.1, 0.78)))


def deer_head(m, antlers):
    k = Skel()
    base = k.n((0, 0.85, -0.55), 0.42)
    neck = k.n((0, 0.4, -0.05), 0.34, base)
    upper = k.n((0, 0.02, 0.35), 0.3, neck)
    skull = k.n((0, -0.25, 0.52), 0.32, upper)
    muzzle = k.n((0, -0.72, 0.3), 0.21, skull)
    k.n((0, -1.0, 0.2), 0.15, muzzle)

    def paint(c, n):
        if c.y < -0.5 and c.z < 0.3 or (c.y > -0.2 and n.y < -0.55 and c.z < 0.2):
            return "fur_light"
        return "fur_brown"
    k.build(m, paint, scale=(0.95, 1, 1))
    for sg in (1, -1):
        eye(m, (sg * 0.27, -0.45, 0.58), (sg * 0.8, -0.45, 0.25), 0.075)
        ear(m, "fur_brown", (sg * 0.26, -0.1, 0.72), 0.55, 0.2, 62, -10, flat=0.4, inner="fur_light", sg=sg)
        if antlers:
            root = Vector((sg * 0.16, -0.12, 0.78))
            beam = [root, root + Vector((sg * 0.18, 0.02, 0.35)), root + Vector((sg * 0.42, 0.12, 0.7)),
                    root + Vector((sg * 0.55, 0.05, 1.05)), root + Vector((sg * 0.5, -0.12, 1.35))]
            m.sweep("bone", beam, [0.07, 0.06, 0.05, 0.04, 0.02], seg=5)
            for i, (dx, dy, dz) in ((1, (0.0, -0.25, 0.35)), (2, (0.05, -0.28, 0.32)), (3, (0.12, -0.05, 0.25))):
                a = beam[i]
                m.sweep("bone", [a, a + Vector((sg * dx, dy, dz))], [0.04, 0.015], seg=4)
            m.blob("wood_dark", 0.08, loc=root, subdiv=1)
    m.blob("nose", 0.1, loc=(0, -1.12, 0.22), scale=(1.1, 0.8, 0.85))


def deer_leg(m, r, front):
    k = Skel()
    if front:
        top = k.n((0, 0, 2.15), 0.24)
        k.chain(top, [((0, 0.02, 1.4), 0.26), ((0, 0.04, 0.5), 0.15), ((0, 0.0, -0.1), 0.11),
                      ((0, -0.02, -1.45), 0.09), ((0, -0.06, -1.74), 0.11)])
    else:
        top = k.n((0, 0, 2.15), 0.3)
        k.chain(top, [((0, -0.12, 1.4), 0.38), ((0, 0.05, 0.4), 0.2), ((0, 0.34, -0.3), 0.11),
                      ((0, 0.08, -1.45), 0.09), ((0, -0.02, -1.74), 0.11)])
    k.build(m, lambda c, n: "nose" if c.z < -1.66 else ("fur_light" if n.y > 0.5 and c.z > 0.6 and not front
                                                        else "fur_brown"), keep=0.5, floor=r.foot)
    flatten_bottom(m, r.foot)


def deer_tail(m):
    k = Skel()
    k.chain(k.n((0, -0.3, 0.02), 0.1), [((0, -0.02, 0.0), 0.15), ((0, 0.26, -0.04), 0.08)])
    k.build(m, lambda c, n: "fur_brown" if n.z > 0.5 else "fur_light", scale=(1, 1, 0.7))


# ----------------------------------------------------------------- rabbit

def rabbit_body(m):
    k = Skel()
    rump = k.n((0, 0.28, 0.02), 0.34)
    mid = k.n((0, -0.08, 0.02), 0.3, rump)
    chest = k.n((0, -0.36, 0.0), 0.24, mid)
    k.n((0, -0.5, 0.12), 0.18, chest)
    for sg in (1, -1):
        k.n((sg * 0.2, 0.34, -0.1), 0.2, rump)  # haunches

    def paint(c, n):
        if n.z < -0.4 or (c.y < -0.4 and c.z < 0.0):
            return "fur_light"
        return "fur_grey"
    k.build(m, paint, fit=((-0.3, -0.56, -0.3), (0.3, 0.54, 0.3)))


def rabbit_head(m):
    k = Skel()
    neck = k.n((0, 0.12, -0.05), 0.17)
    skull = k.n((0, -0.04, 0.05), 0.19, neck)
    cheek = k.n((0, -0.2, -0.02), 0.15, skull)
    k.n((0, -0.3, -0.04), 0.09, cheek)

    def paint(c, n):
        if c.y < -0.22 and c.z < -0.02 or n.z < -0.6:
            return "fur_light"
        return "fur_grey"
    k.build(m, paint, scale=(1.0, 1, 1))
    for sg in (1, -1):
        eye(m, (sg * 0.13, -0.12, 0.08), (sg * 0.9, -0.3, 0.2), 0.05, iris="eye", pupil=False)
        m.blob("eye_glow", 0.012, loc=(sg * 0.165, -0.15, 0.115), subdiv=1)
        base = (sg * 0.07, 0.03, 0.17)
        m.blob("fur_grey", 0.07, loc=(sg * 0.1, 0.07, 0.4), rot=(-18, sg * 14, 0), scale=(0.85, 0.42, 3.4))
        m.blob("fur_light", 0.052, loc=(sg * 0.103, 0.045, 0.41), rot=(-18, sg * 14, 0), scale=(0.7, 0.3, 3.1),
               subdiv=1)
        m.blob("fur_grey", 0.06, loc=base, scale=(1, 0.8, 1.2), subdiv=1)
    m.blob("nose", 0.03, loc=(0, -0.365, -0.01), scale=(1.2, 0.8, 0.8), subdiv=1)


def rabbit_leg(m, r, front):
    k = Skel()
    if front:
        top = k.n((0, 0, 0.4), 0.09)
        k.chain(top, [((0, -0.01, 0.22), 0.1), ((0, -0.02, -0.05), 0.07), ((0, -0.06, -0.24), 0.065)])
        k.build(m, lambda c, n: "fur_light" if c.z < -0.12 else "fur_grey", keep=0.6, floor=r.foot)
    else:
        top = k.n((0, 0, 0.42), 0.16)
        k.chain(top, [((0, 0.05, 0.2), 0.21), ((0, 0.08, -0.06), 0.14), ((0, 0.12, -0.22), 0.07),
                      ((0, -0.14, -0.26), 0.075)])
        k.build(m, lambda c, n: "fur_light" if c.z < -0.18 else "fur_grey", keep=0.6, floor=r.foot)
    flatten_bottom(m, r.foot)


def rabbit_tail(m):
    m.blob("fur_light", 0.1, loc=(0, -0.12, -0.02), jitter=0.01, subdiv=2)


# ------------------------------------------------------------------- boar

def boar_body(m):
    k = Skel()
    rump = k.n((0, 1.35, 0.02), 0.7)
    mid = k.n((0, 0.35, 0.05), 0.8, rump)
    shoulder = k.n((0, -0.85, 0.18), 0.92, mid)
    k.n((0, -1.55, 0.3), 0.78, shoulder)  # neck base
    k.n((0, -0.55, 0.55), 0.62, shoulder)  # high withers
    for sg in (1, -1):
        k.n((sg * 0.45, -1.0, -0.25), 0.5, shoulder)
        k.n((sg * 0.42, 1.2, -0.2), 0.55, rump)

    def paint(c, n):
        if n.z < -0.45 and c.z < -0.3:
            return "fur_brown"
        return "fur_bat"
    k.build(m, paint, fit=((-0.9, -1.95, -0.85), (0.9, 1.85, 0.95)))
    # bristly mane along the spine
    for i in range(9):
        y = -1.55 + i * 0.3
        p, n = surface(m, (0, y, 0.6), (0, 0, 1))
        h = 0.5 - abs(i - 2.5) * 0.06
        m.cone("fur_bat", 0.15, max(h, 0.16), seg=4, loc=p - n * 0.08, rot=(-30, 0, 45), scale=(0.45, 1, 1))


def boar_head(m):
    k = Skel()
    neck = k.n((0, 0.6, -0.2), 0.62)
    skull = k.n((0, 0.1, 0.1), 0.56, neck)
    face = k.n((0, -0.4, -0.08), 0.42, skull)
    k.n((0, -1.0, -0.24), 0.26, face)

    def paint(c, n):
        if c.y < -0.7:
            return "leather"
        if n.z < -0.4:
            return "fur_brown"
        return "fur_bat"
    k.build(m, paint, scale=(0.95, 1, 1))
    # snout disc
    m.cylinder("leather", 0.25, 0.25, 0.14, seg=10, loc=(0, -1.16, -0.24), rot=(90, 0, 0), cap="leather")
    for sg in (1, -1):
        m.blob("nose", 0.055, loc=(sg * 0.08, -1.31, -0.24), scale=(0.8, 0.5, 1.1), subdiv=1)
        eye(m, (sg * 0.3, -0.25, 0.2), (sg * 0.7, -0.6, 0.25), 0.07)
        ear(m, "fur_bat", (sg * 0.3, 0.2, 0.46), 0.42, 0.17, 28, 20, flat=0.45, inner="fur_brown", sg=sg)
        m.sweep("bone", [(sg * 0.2, -0.92, -0.36), (sg * 0.32, -1.05, -0.26), (sg * 0.38, -1.08, -0.02)],
                [0.06, 0.05, 0.012], seg=5)


def boar_leg(m, r, front):
    k = Skel()
    if front:
        top = k.n((0, 0, 1.2), 0.36)
        k.chain(top, [((0, 0, 0.8), 0.42), ((0, 0.03, 0.2), 0.27), ((0, 0.0, -0.5), 0.13),
                      ((0, -0.06, -0.82), 0.14)])
    else:
        top = k.n((0, 0, 1.2), 0.4)
        k.chain(top, [((0, -0.08, 0.75), 0.5), ((0, -0.12, 0.25), 0.34), ((0, 0.18, -0.35), 0.13),
                      ((0, 0.0, -0.82), 0.14)])
    k.build(m, lambda c, n: "nose" if c.z < -0.78 else "fur_bat", floor=r.foot)
    flatten_bottom(m, r.foot)


def boar_tail(m):
    k = Skel()
    k.chain(k.n((0, -0.6, 0.05), 0.1), [((0, -0.28, -0.02), 0.09), ((0, -0.05, -0.25), 0.065),
                                         ((0, 0.02, -0.55), 0.12)])
    k.build(m, lambda c, n: "fur_bat", keep=0.6)


# -------------------------------------------------------------------- bat

def bat_body(m):
    k = Skel()
    tailn = k.n((0, 0.6, -0.1), 0.32)
    belly = k.n((0, 0.2, -0.02), 0.58, tailn)
    chest = k.n((0, -0.35, 0.08), 0.62, belly)
    head = k.n((0, -0.9, 0.3), 0.44, chest)
    k.n((0, -1.28, 0.24), 0.22, head)
    k.build(m, lambda c, n: "fur_light" if n.z < -0.5 and c.y < 0.1 and c.y > -0.7 else "fur_bat",
            fit=((-0.72, -1.5, -0.62), (0.72, 0.95, 0.8)))
    for sg in (1, -1):
        p, n = surface(m, (sg * 0.24, -0.85, 0.5), (0, 0, 1))
        ear(m, "fur_bat", p - Vector((0, 0, 0.06)), 0.75, 0.24, 22, -12, flat=0.45, inner="membrane", sg=sg)
        eye(m, (sg * 0.2, -1.15, 0.42), (sg * 0.45, -0.85, 0.3), 0.075)
        m.cone("bone", 0.035, 0.14, seg=4, loc=(sg * 0.08, -1.38, 0.12), rot=(180, 0, 0))
        m.sweep("fur_bat", [(sg * 0.2, 0.55, -0.3), (sg * 0.28, 0.9, -0.45)], [0.07, 0.04], seg=5)
    m.blob("nose", 0.07, loc=(0, -1.5, 0.28), scale=(1.2, 0.7, 0.8), subdiv=1)


def bat_wing(m):
    """Right wing (Roblox +X = Blender -X). Joint at local x = +1.6."""
    poly = [(1.62, -0.3), (0.3, -0.52), (-1.1, -0.62), (-2.95, -0.42), (-2.2, 0.08), (-2.4, 0.8),
            (-1.55, 0.42), (-1.0, 1.0), (-0.3, 0.52), (0.5, 0.78), (1.55, 0.45)]
    membrane(m, poly, 0.05)
    arm = [(1.7, -0.3, 0.0), (0.3, -0.52, 0.0), (-1.1, -0.62, 0.0)]
    m.sweep("fur_bat", arm, [0.12, 0.09, 0.07], seg=5)
    for tip in ((-2.95, -0.42), (-2.4, 0.8), (-1.0, 1.0)):
        m.sweep("membrane", [(-1.1, -0.62, 0.0), (tip[0], tip[1], 0.0)], [0.05, 0.02], seg=4)
    m.cone("bone", 0.05, 0.22, seg=4, loc=(-1.1, -0.66, 0.0), rot=(90, 0, 0))


# ------------------------------------------------------------ registration

SPECIES = ["Wolf", "Bear", "Deer", "Rabbit", "Boar"]
DENSITY = {"Wolf": 1.6, "Bear": 2.4, "Deer": 1.5, "Rabbit": 0.7, "Boar": 1.6, "Bat": 1.2}
BUILDERS = {
    "Wolf": dict(Body=wolf_body, Head=wolf_head, LegF=lambda m, r: wolf_leg_f(m, r),
                 LegB=lambda m, r: wolf_leg_b(m, r), Tail=wolf_tail),
    "Bear": dict(Body=bear_body, Head=bear_head, LegF=lambda m, r: bear_leg(m, r, True),
                 LegB=lambda m, r: bear_leg(m, r, False), Tail=bear_tail),
    "Deer": dict(Body=deer_body, Head=lambda m: deer_head(m, False), Head_Antlered=lambda m: deer_head(m, True),
                 LegF=lambda m, r: deer_leg(m, r, True), LegB=lambda m, r: deer_leg(m, r, False), Tail=deer_tail),
    "Rabbit": dict(Body=rabbit_body, Head=rabbit_head, LegF=lambda m, r: rabbit_leg(m, r, True),
                   LegB=lambda m, r: rabbit_leg(m, r, False), Tail=rabbit_tail),
    "Boar": dict(Body=boar_body, Head=boar_head, LegF=lambda m, r: boar_leg(m, r, True),
                 LegB=lambda m, r: boar_leg(m, r, False), Tail=boar_tail),
}
RIG_PART = {"Body": "Torso", "Head": "Head", "Head_Antlered": "Head", "LegF": "LegFL, LegFR",
            "LegB": "LegBL, LegBR", "Tail": "TailPart"}


def _register(sp, piece, fn):
    rig = Rig(sp) if sp in RIGS else None
    takes_rig = piece in ("LegF", "LegB")

    def build(m):
        fn(m, rig) if takes_rig else fn(m)
    P.asset(f"SM_{sp}_{piece}", CAT, "RigPart", density=DENSITY[sp], smooth=70, grain=(0, 1, 0),
            uv_box=True, dummy=False, preview=False, fidelity="Box",
            pivot=f"Centre of the {sp} rig's {RIG_PART.get(piece, piece)} part (Animals.luau).",
            use=f"{sp} rig: weld onto {RIG_PART.get(piece, piece)} (Models/Animals.luau).")(build)


for _sp in SPECIES:
    for _piece, _fn in BUILDERS[_sp].items():
        _register(_sp, _piece, _fn)
P.asset("SM_Bat_Body", CAT, "RigPart", density=DENSITY["Bat"], smooth=70, grain=(0, 1, 0), uv_box=True,
        dummy=False, preview=False, pivot="Centre of the bat rig's Body ball (Animals.luau).",
        use="Bat rig: weld onto Body (covers head, ears and eyes).")(bat_body)
P.asset("SM_Bat_Wing", CAT, "RigPart", density=DENSITY["Bat"], smooth=70, grain=(1, 0, 0), uv_box=True,
        dummy=False, preview=False, pivot="Centre of the bat rig's WingRPart (Animals.luau).",
        use="Bat rig: weld onto WingRPart; WingLPart uses it turned 180 deg about the forward axis.")(bat_wing)


# ----------------------------------------------------------------- previews

def T(v):
    return Matrix.Translation(Vector(v))


def Rx(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def Ry(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")


def Rz(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


def quad_pose(sp, stride=0.0, neck=0.0, look=0.0, tail=0.0, antlers=True):
    """[(asset, Blender matrix)] for a quadruped standing on z=0, posed the way
    Creatures.luau poses the Motor6Ds (angles in Roblox degrees)."""
    r = Rig(sp)
    torso = T((0, 0, -r.ground))
    head = torso @ T(r.neck) @ Rz(look) @ Rx(-neck) @ T(-r.neck_in_head)
    hname = f"SM_{sp}_Head_Antlered" if sp == "Deer" and antlers else f"SM_{sp}_Head"
    out = [(f"SM_{sp}_Body", torso), (hname, head)]
    for piece, hip, v in (("LegF", r.hip_f, 1), ("LegF", r.hip_f * Vector((-1, 1, 1)), -1),
                          ("LegB", r.hip_b, -1), ("LegB", r.hip_b * Vector((-1, 1, 1)), 1)):
        out.append((f"SM_{sp}_{piece}", torso @ T(hip) @ Rx(-v * stride) @ T((0, 0, -r.leg / 2))))
    out.append((f"SM_{sp}_Tail", torso @ T(r.tail_joint) @ Rz(tail) @ Rx(-25) @ T((0, r.tail / 2, 0))))
    return out


def bat_pose(flap=0.0, hover=3.0):
    body = T((0, 0, hover))
    return [("SM_Bat_Body", body),
            ("SM_Bat_Wing", body @ T((-0.7, 0, 0.2)) @ Ry(-flap) @ T((-1.6, 0, 0))),
            ("SM_Bat_Wing", body @ T((0.7, 0, 0.2)) @ Ry(flap) @ T((1.6, 0, 0)) @ Ry(180))]


def _tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


@P.asset("Animals_Preview", CAT, "Reference", special=True)
def previews(ctx):
    """Renders every species assembled from its part meshes (rest pose with the
    R15 dummy, plus an in-game walk/graze pose) and the Animals contact sheet."""
    if not ctx.renderer:
        return []
    col = ctx.collection("Animals_Preview")
    out = os.path.join(P.OUT["render"], CAT)
    dummy = ctx.objects["SH_Dummy"]
    poses = []
    for sp in SPECIES:
        poses.append((sp, "Rest", quad_pose(sp), True))
        walk = dict(stride=30, tail=15, antlers=False) if sp == "Deer" else dict(stride=30, tail=15)
        poses.append((sp, "Walk", quad_pose(sp, **walk), False))
        if sp in ("Deer", "Rabbit"):
            poses.append((sp, "Graze", quad_pose(sp, neck=-40, look=12), False))
        if sp == "Bear":
            poses.append((sp, "Roar", quad_pose(sp, neck=35, look=0), False))
    poses.append(("Bat", "Rest", bat_pose(0), True))
    poses.append(("Bat", "Flap", bat_pose(45), False))
    entries = []
    for sp, label, parts, with_dummy in poses:
        if any(n not in ctx.objects for n, _ in parts):
            continue
        objs = []
        for n, mat in parts:
            o = ctx.objects[n].copy()
            col.objects.link(o)
            o.matrix_world = mat
            objs.append(o)
        vis = list(objs)
        if with_dummy:
            maxx = max((o.matrix_world @ Vector(c)).x for o in objs for c in o.bound_box)
            dummy.location = (maxx + 1.5, 0.8, 0)
            vis.append(dummy)
        path = ctx.renderer.render(vis, os.path.join(out, f"{sp}_{label}.png"),
                                   direction=(1.1, -1.25, 0.6))
        dummy.location = (0, 0, 0)
        tris = sum(_tris(o) for o in objs)
        entries.append((path, f"{sp} {label}", f"{tris} tris, {len(objs)} parts" if with_dummy
                        else "Motor6D pose from Creatures.luau"))
        for o in objs:
            bpy.data.objects.remove(o)
    P.contact_sheet(entries, os.path.join(P.OUT["render"], f"ContactSheet_{CAT}.png"),
                    "Survival Hour - Animals: part meshes on the game rigs (dummy = R15, 5.25 studs)",
                    cols=5, cell=300)
    return []
