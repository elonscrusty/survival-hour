"""Wildlife: wolf, bear, bat. Skinned meshes with rigs and animation clips.

Rig rules (Roblox rigging/skinning specs):
  * Root bone at (0,0,0) with no skin influence.
  * <= 4 bone influences per vertex (we use <= 3).
  * Bones rest at identity pose; animations exported one clip per FBX.
Body: one connected mesh from a Skin-modifier skeleton (+1 subdivision),
with face details (ears, eyes, jaw, teeth) rigidly bound to their bone.
"""

import math
import os

import bmesh
import bpy
from mathutils import Quaternion, Vector

from sh import pipeline as P
from sh.kit import Model

FPS = 30


# ------------------------------------------------------------------ builder

class Creature:
    def __init__(self, name, density=1.6):
        self.name = name
        self.m = Model("SK_" + name, seed=sum(map(ord, name)), density=density, smooth_angle=70,
                       grain=(0, 1, 0), uv_box=True)
        self.l_bone = self.m.bm.verts.layers.int.new("bone")
        self.bones = []  # (name, head, tail, parent, auto, side, bias)
        self.nodes, self.edges = [], []

    # skeleton ---------------------------------------------------------
    def bone(self, name, head, tail, parent=None, auto=True, side=0, bias=1.0):
        self.bones.append((name, Vector(head), Vector(tail), parent, auto, side, bias))

    def bone_index(self, name):
        return [b[0] for b in self.bones].index(name) + 1

    # skin body ------------------------------------------------------------
    def node(self, pos, r, link=None):
        self.nodes.append((Vector(pos), r))
        i = len(self.nodes) - 1
        if link is not None:
            self.edges.append((link, i))
        return i

    def chain(self, start, pts):
        prev = start
        for p, r in pts:
            prev = self.node(p, r, prev)
        return prev

    def skin_body(self, paint):
        me = bpy.data.meshes.new(self.name + "_skin")
        me.from_pydata([tuple(p) for p, _ in self.nodes], self.edges, [])
        o = bpy.data.objects.new(self.name + "_skin", me)
        bpy.context.scene.collection.objects.link(o)
        o.modifiers.new("Skin", "SKIN")
        if len(me.skin_vertices) == 0:
            me.skin_vertices.new()
        for d, (_, r) in zip(me.skin_vertices[0].data, self.nodes):
            d.radius = (r, r)
        me.skin_vertices[0].data[0].use_root = True
        o.modifiers.new("Sub", "SUBSURF").levels = 1
        dg = bpy.context.evaluated_depsgraph_get()
        ev = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        tmp = bmesh.new()
        tmp.from_mesh(ev)
        bm = self.m.bm
        vmap = {v: bm.verts.new(v.co) for v in tmp.verts}
        for f in tmp.faces:
            nf = bm.faces.new([vmap[v] for v in f.verts])
            nf.normal_update()
        tmp.free()
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
        bpy.data.meshes.remove(ev)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        from sh import textures as tx
        for f in bm.faces:
            f[self.m.l_mat] = tx.TILE_INDEX[paint(f.calc_center_median(), f.normal)]

    def tag(self, verts, bone):
        i = self.bone_index(bone)
        for v in verts:
            v[self.l_bone] = i
        return verts

    # rig ----------------------------------------------------------------
    def build(self, ctx, col):
        obj = self.m.build(ctx.full, col)
        arm_data = bpy.data.armatures.new("SK_" + self.name + "_Rig")
        arm = bpy.data.objects.new("SK_" + self.name + "_Armature", arm_data)
        col.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        eb = {}
        for name, h, t, parent, *_ in self.bones:
            b = arm_data.edit_bones.new(name)
            b.head, b.tail = h, t
            b.roll = 0.0
            if parent:
                b.parent = eb[parent]
            eb[name] = b
        bpy.ops.object.mode_set(mode="OBJECT")
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
        self._weights(obj)
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        obj.parent = arm
        self.obj, self.arm = obj, arm
        return obj, arm

    def _weights(self, obj):
        me = obj.data
        tags = [d.value for d in me.attributes["bone"].data]
        groups = {b[0]: obj.vertex_groups.new(name=b[0]) for b in self.bones if b[0] != "Root"}
        segs = [(b[0], b[1], b[2], b[5], b[6]) for b in self.bones if b[4] and b[0] != "Root"]
        names = [b[0] for b in self.bones]
        self.max_influences = 0
        for v, tag in zip(me.vertices, tags):
            if tag:
                groups[names[tag - 1]].add([v.index], 1.0, "REPLACE")
                self.max_influences = max(self.max_influences, 1)
                continue
            p = v.co
            cands = []
            for name, a, b, side, bias in segs:
                if side and p.x * side < -0.06:
                    continue
                ab = b - a
                t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
                d = (p - (a + ab * t)).length * bias
                cands.append((d, name))
            cands.sort()
            best = cands[:3]
            ws = [1.0 / (d + 0.04) ** 4 for d, _ in best]
            top = max(ws)
            keep = [(w, n) for w, (d, n) in zip(ws, best) if w > top * 0.08]
            total = sum(w for w, _ in keep)
            for w, n in keep:
                groups[n].add([v.index], w / total, "REPLACE")
            self.max_influences = max(self.max_influences, len(keep))
        me.attributes.remove(me.attributes["bone"])

    # animation ------------------------------------------------------------
    def clip(self, name, frames, fn, loop):
        arm = self.arm
        if arm.animation_data is None:
            arm.animation_data_create()
        act = bpy.data.actions.new(f"A_{self.name}_{name}")
        arm.animation_data.action = act
        rest = {b.name: b.matrix_local.to_3x3() for b in arm.data.bones}
        restinv = {k: v.inverted() for k, v in rest.items()}
        axes = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}
        step = 1 if frames <= 24 else 2
        keys = list(range(0, frames + 1, step))
        if keys[-1] != frames:
            keys.append(frames)
        for f in keys:
            t = f / frames
            pose = fn(t)
            locs = pose.pop("_loc", {})
            for pb in arm.pose.bones:
                q = Quaternion()
                for ax, deg in pose.get(pb.name, []):
                    la = (restinv[pb.name] @ axes[ax]).normalized()
                    q = Quaternion(la, math.radians(deg)) @ q
                pb.rotation_quaternion = q
                pb.location = restinv[pb.name] @ Vector(locs.get(pb.name, (0, 0, 0)))
                pb.keyframe_insert("rotation_quaternion", frame=f)
                pb.keyframe_insert("location", frame=f)
        self.clips.append(dict(name=name, action=act, frames=frames, loop=loop))
        return act


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def seg(t, a, b):
    """0 before a, eases to 1 at b."""
    return ease((t - a) / (b - a)) if b > a else float(t >= a)


def bump(t, a, b, c):
    """Rises a->b, falls b->c."""
    return seg(t, a, b) * (1 - seg(t, b, c))


def S(t, phase=0.0, k=1):
    return math.sin(2 * math.pi * (k * t + phase))


def add(pose, bone, ax, deg):
    pose.setdefault(bone, []).append((ax, deg))


def gait(pose, t, legs, amp_u, amp_l, amp_p=0.5, lift=1.0):
    """legs: {prefix: (upper, lower, paw, phase)}. Forward swing = -X."""
    for upper, lower, paw, ph in legs.values():
        s = S(t, ph)
        c = math.cos(2 * math.pi * (t + ph))
        u = -amp_u * s
        l = amp_l * max(0.0, c) * lift
        add(pose, upper, "x", u)
        add(pose, lower, "x", l)
        add(pose, paw, "x", -(u + l) * amp_p)


# --------------------------------------------------------------- quadrupeds

def quad_legs(c, prefix_sides=(("L", 1), ("R", -1))):
    return {}


def wolf_rig(c):
    c.bone("Root", (0, 0, 0), (0, 0, 0.6), auto=False)
    c.bone("Hips", (0, 1.05, 2.55), (0, 0.0, 2.62), "Root")
    c.bone("Spine", (0, 0.0, 2.62), (0, -0.95, 2.72), "Hips")
    c.bone("Neck", (0, -0.95, 2.72), (0, -1.6, 3.15), "Spine")
    c.bone("Head", (0, -1.6, 3.15), (0, -2.95, 3.3), "Neck")
    c.bone("Jaw", (0, -1.95, 3.18), (0, -2.8, 3.06), "Head", auto=False)
    for s, sg in (("L", 1), ("R", -1)):
        c.bone("Ear_" + s, (sg * 0.25, -1.85, 3.75), (sg * 0.3, -1.85, 4.25), "Head", auto=False)
        c.bone("FrontUpperLeg_" + s, (sg * 0.4, -1.05, 2.4), (sg * 0.42, -0.95, 1.35), "Spine",
               side=sg, bias=1.25)
        c.bone("FrontLowerLeg_" + s, (sg * 0.42, -0.95, 1.35), (sg * 0.42, -1.02, 0.42),
               "FrontUpperLeg_" + s, side=sg)
        c.bone("FrontPaw_" + s, (sg * 0.42, -1.02, 0.42), (sg * 0.42, -1.4, 0.1),
               "FrontLowerLeg_" + s, side=sg)
        c.bone("HindUpperLeg_" + s, (sg * 0.4, 1.1, 2.3), (sg * 0.42, 0.75, 1.45), "Hips",
               side=sg, bias=1.25)
        c.bone("HindLowerLeg_" + s, (sg * 0.42, 0.75, 1.45), (sg * 0.42, 1.25, 0.62),
               "HindUpperLeg_" + s, side=sg)
        c.bone("HindFoot_" + s, (sg * 0.42, 1.25, 0.62), (sg * 0.42, 0.95, 0.1),
               "HindLowerLeg_" + s, side=sg)
    c.bone("Tail1", (0, 1.5, 2.6), (0, 2.25, 2.25), "Hips")
    c.bone("Tail2", (0, 2.25, 2.25), (0, 2.9, 1.85), "Tail1")
    c.bone("Tail3", (0, 2.9, 1.85), (0, 3.4, 1.55), "Tail2")


def build_wolf(ctx):
    c = Creature("Wolf")
    wolf_rig(c)
    hips = c.node((0, 1.05, 2.5), 0.68)
    mid = c.node((0, 0.0, 2.58), 0.66, hips)
    chest = c.node((0, -0.95, 2.66), 0.86, mid)
    c.chain(chest, [((0, -1.55, 3.1), 0.66), ((0, -2.0, 3.42), 0.46), ((0, -2.5, 3.36), 0.27),
                    ((0, -2.95, 3.3), 0.14)])
    c.chain(hips, [((0, 1.55, 2.6), 0.22), ((0, 2.25, 2.25), 0.34), ((0, 2.9, 1.85), 0.3),
                   ((0, 3.4, 1.55), 0.08)])
    for sg in (1, -1):
        c.chain(chest, [((sg * 0.4, -1.05, 2.25), 0.38), ((sg * 0.43, -0.95, 1.35), 0.26),
                        ((sg * 0.43, -1.02, 0.42), 0.17), ((sg * 0.43, -1.22, 0.14), 0.2)])
        c.chain(hips, [((sg * 0.42, 1.1, 2.2), 0.5), ((sg * 0.44, 0.75, 1.45), 0.32),
                       ((sg * 0.44, 1.25, 0.62), 0.17), ((sg * 0.44, 1.05, 0.14), 0.2)])

    def paint(cn, n):
        if cn.y > 3.05:
            return "fur_bat"
        if (n.z < -0.25 and cn.z < 2.7) or cn.z < 0.8 or (cn.y < -2.3 and n.z < 0.2):
            return "fur_light"
        if n.z > 0.72 and -0.7 < cn.y < 1.2:
            return "fur_bat"
        return "fur_grey"
    c.skin_body(paint)
    m = c.m
    for sg, s in ((1, "L"), (-1, "R")):
        c.tag(m.cone("fur_grey", 0.2, 0.55, seg=4, loc=(sg * 0.25, -1.85, 3.66),
                     rot=(8, sg * 16, 45), scale=(1, 0.45, 1)), "Ear_" + s)
        c.tag(m.blob("eye_glow", 0.09, loc=(sg * 0.2, -2.28, 3.58), scale=(1, 0.6, 0.8)), "Head")
        c.tag(m.blob("eye", 0.05, loc=(sg * 0.215, -2.34, 3.585)), "Head")
        c.tag(m.box("fur_bat", (0.26, 0.2, 0.08), loc=(sg * 0.2, -2.22, 3.7), rot=(0, sg * -18, 0)),
              "Head")
        c.tag(m.cone("bone", 0.04, 0.16, seg=4, loc=(sg * 0.09, -2.78, 3.24), rot=(180, 0, 0)), "Head")
        c.tag(m.cone("bone", 0.035, 0.12, seg=4, loc=(sg * 0.08, -2.7, 3.06)), "Jaw")
    c.tag(m.blob("nose", 0.12, loc=(0, -3.0, 3.34), scale=(1.1, 0.9, 0.8)), "Head")
    c.tag(m.blob("nose", 0.2, loc=(0, -2.45, 3.2), scale=(0.9, 2.2, 0.5)), "Head")
    c.tag(m.sweep("fur_light", [(0, -1.95, 3.14), (0, -2.45, 3.08), (0, -2.85, 3.06)],
                  [0.22, 0.16, 0.09], 7, flat=0.55), "Jaw")
    return c


def bear_rig(c):
    c.bone("Root", (0, 0, 0), (0, 0, 0.8), auto=False)
    c.bone("Hips", (0, 1.8, 3.1), (0, 0.2, 3.4), "Root")
    c.bone("Spine", (0, 0.2, 3.4), (0, -1.4, 3.6), "Hips")
    c.bone("Neck", (0, -1.4, 3.6), (0, -2.6, 3.7), "Spine")
    c.bone("Head", (0, -2.6, 3.7), (0, -4.45, 3.45), "Neck")
    c.bone("Jaw", (0, -3.0, 3.35), (0, -4.2, 3.15), "Head", auto=False)
    for s, sg in (("L", 1), ("R", -1)):
        c.bone("Ear_" + s, (sg * 0.55, -3.0, 4.3), (sg * 0.6, -3.0, 4.75), "Head", auto=False)
        c.bone("FrontUpperLeg_" + s, (sg * 0.9, -1.6, 3.0), (sg * 1.0, -1.5, 1.55), "Spine",
               side=sg, bias=1.3)
        c.bone("FrontLowerLeg_" + s, (sg * 1.0, -1.5, 1.55), (sg * 1.0, -1.6, 0.45),
               "FrontUpperLeg_" + s, side=sg)
        c.bone("FrontPaw_" + s, (sg * 1.0, -1.6, 0.45), (sg * 1.0, -2.2, 0.2), "FrontLowerLeg_" + s,
               side=sg)
        c.bone("HindUpperLeg_" + s, (sg * 0.9, 2.0, 3.0), (sg * 1.0, 1.5, 1.65), "Hips", side=sg,
               bias=1.3)
        c.bone("HindLowerLeg_" + s, (sg * 1.0, 1.5, 1.65), (sg * 1.0, 2.0, 0.6), "HindUpperLeg_" + s,
               side=sg)
        c.bone("HindFoot_" + s, (sg * 1.0, 2.0, 0.6), (sg * 1.0, 1.5, 0.2), "HindLowerLeg_" + s,
               side=sg)
    c.bone("Tail1", (0, 2.8, 3.4), (0, 3.25, 3.15), "Hips")


def build_bear(ctx):
    c = Creature("Bear", density=2.2)
    bear_rig(c)
    hips = c.node((0, 1.8, 3.1), 1.3)
    mid = c.node((0, 0.2, 3.35), 1.4, hips)
    chest = c.node((0, -1.4, 3.45), 1.45, mid)
    c.node((0, -0.8, 4.35), 0.9, chest)  # shoulder hump
    c.chain(chest, [((0, -2.55, 3.6), 1.0), ((0, -3.3, 3.72), 0.85), ((0, -4.0, 3.48), 0.46),
                    ((0, -4.45, 3.42), 0.22)])
    c.chain(hips, [((0, 2.85, 3.4), 0.32), ((0, 3.2, 3.2), 0.12)])
    for sg in (1, -1):
        c.chain(chest, [((sg * 0.9, -1.6, 2.8), 0.72), ((sg * 1.0, -1.5, 1.55), 0.52),
                        ((sg * 1.0, -1.6, 0.48), 0.44), ((sg * 1.0, -1.95, 0.24), 0.46)])
        c.chain(hips, [((sg * 0.9, 2.0, 2.8), 0.88), ((sg * 1.0, 1.5, 1.65), 0.6),
                       ((sg * 1.0, 2.0, 0.62), 0.44), ((sg * 1.0, 1.7, 0.24), 0.46)])

    def paint(cn, n):
        if cn.y < -3.7 and cn.z < 3.7:
            return "fur_light"
        if cn.z < 0.6:
            return "fur_bat"
        return "fur_brown"
    c.skin_body(paint)
    m = c.m
    for sg, s in ((1, "L"), (-1, "R")):
        c.tag(m.blob("fur_brown", 0.28, loc=(sg * 0.58, -3.0, 4.38), scale=(1, 0.55, 1)), "Ear_" + s)
        c.tag(m.blob("fur_bat", 0.15, loc=(sg * 0.58, -3.05, 4.38), scale=(0.8, 0.4, 0.8)), "Ear_" + s)
        c.tag(m.blob("eye_glow", 0.1, loc=(sg * 0.36, -3.72, 3.95), scale=(1, 0.6, 0.8)), "Head")
        c.tag(m.blob("eye", 0.06, loc=(sg * 0.375, -3.78, 3.955)), "Head")
        c.tag(m.box("fur_bat", (0.34, 0.25, 0.1), loc=(sg * 0.35, -3.66, 4.08), rot=(0, sg * -15, 0)), "Head")
        c.tag(m.cone("bone", 0.06, 0.22, seg=4, loc=(sg * 0.15, -4.3, 3.28), rot=(180, 0, 0)), "Head")
        c.tag(m.cone("bone", 0.05, 0.17, seg=4, loc=(sg * 0.13, -4.12, 3.12)), "Jaw")
        for k in (-1, 0, 1):  # front claws
            c.tag(m.cone("bone", 0.07, 0.35, seg=4, loc=(sg * 1.0 + k * 0.2, -2.12, 0.2),
                         rot=(-100, 0, 0)), "FrontPaw_" + ("L" if sg > 0 else "R"))
    c.tag(m.blob("nose", 0.2, loc=(0, -4.52, 3.47), scale=(1.2, 0.9, 0.8)), "Head")
    c.tag(m.blob("nose", 0.3, loc=(0, -3.8, 3.3), scale=(1, 2.2, 0.5)), "Head")
    c.tag(m.sweep("fur_light", [(0, -3.0, 3.3), (0, -3.7, 3.2), (0, -4.25, 3.12)],
                  [0.4, 0.28, 0.16], 8, flat=0.55), "Jaw")
    return c


QUAD_LEGS = lambda fl, fr, hl, hr: {
    "FL": ("FrontUpperLeg_L", "FrontLowerLeg_L", "FrontPaw_L", fl),
    "FR": ("FrontUpperLeg_R", "FrontLowerLeg_R", "FrontPaw_R", fr),
    "HL": ("HindUpperLeg_L", "HindLowerLeg_L", "HindFoot_L", hl),
    "HR": ("HindUpperLeg_R", "HindLowerLeg_R", "HindFoot_R", hr),
}


def quad_clips(c, big=False, special=None):
    k = 0.7 if big else 1.0  # bears move with less leg swing

    def idle(t):
        p = {}
        add(p, "Spine", "x", 1.5 * S(t))
        add(p, "Neck", "x", 3 * S(t, 0.2))
        add(p, "Head", "z", 10 * S(t, 0.1))
        add(p, "Tail1", "z", 10 * S(t))
        if "Tail2" in [b[0] for b in c.bones]:
            add(p, "Tail2", "z", 12 * S(t, -0.1))
        add(p, "Ear_L", "x", -18 * bump(t, 0.3, 0.34, 0.4))
        return p

    def walk(t):
        p = {"_loc": {"Hips": (0, 0, 0.06 * S(t, 0.1, 2))}}
        gait(p, t, QUAD_LEGS(0.25, 0.75, 0.0, 0.5), 22 * k, 34 * k)
        add(p, "Neck", "x", 3 * S(t, 0.3, 2))
        add(p, "Head", "z", 3 * S(t))
        add(p, "Tail1", "z", 8 * S(t))
        add(p, "Spine", "z", 3 * S(t))
        return p

    def run(t):
        p = {"_loc": {"Hips": (0, 0, 0.22 * abs(S(t, 0.1)))}}
        gait(p, t, QUAD_LEGS(0.0, 0.1, 0.5, 0.6), 40 * k, 55 * k)
        add(p, "Spine", "x", 8 * S(t, 0.25))
        add(p, "Hips", "x", -6 * S(t, 0.25))
        add(p, "Neck", "x", 6 * S(t, 0.5))
        add(p, "Tail1", "x", 10 + 8 * S(t))
        return p

    def alert(t):
        e = seg(t, 0, 0.5)
        p = {"_loc": {"Hips": (0, 0.1 * e, -0.12 * e)}}
        add(p, "Neck", "x", -14 * e)
        add(p, "Head", "x", 6 * e)
        add(p, "Head", "z", 12 * bump(t, 0.5, 0.75, 1.0))
        add(p, "Ear_L", "x", -12 * e)
        add(p, "Ear_R", "x", -12 * e)
        add(p, "Tail1", "x", 25 * e)
        add(p, "Jaw", "x", (8 + 3 * S(t, 0, 6)) * e)
        for leg in ("FrontUpperLeg_L", "FrontUpperLeg_R"):
            add(p, leg, "x", -6 * e)
        return p

    def attack(t):
        crouch = bump(t, 0.0, 0.3, 0.45)
        lunge = bump(t, 0.3, 0.5, 0.9)
        dist = 1.8 if not big else 1.4
        p = {"_loc": {"Hips": (0, 0.35 * crouch - dist * lunge, -0.3 * crouch + 0.45 * lunge)}}
        for s in ("L", "R"):
            add(p, "FrontUpperLeg_" + s, "x", 18 * crouch - 45 * lunge)
            add(p, "FrontLowerLeg_" + s, "x", 30 * crouch + 20 * lunge)
            add(p, "HindUpperLeg_" + s, "x", -25 * crouch + 30 * lunge)
            add(p, "HindLowerLeg_" + s, "x", 35 * crouch - 10 * lunge)
        add(p, "Neck", "x", 10 * crouch - 12 * lunge)
        add(p, "Jaw", "x", 38 * bump(t, 0.35, 0.5, 0.62))
        add(p, "Ear_L", "x", 30 * (crouch + lunge))
        add(p, "Ear_R", "x", 30 * (crouch + lunge))
        return p

    def hit(t):
        h = bump(t, 0.0, 0.2, 1.0)
        p = {"_loc": {"Hips": (0.15 * h, 0.35 * h, -0.1 * h)}}
        add(p, "Spine", "z", 14 * h)
        add(p, "Neck", "x", 14 * h)
        add(p, "Head", "z", -18 * h)
        add(p, "Ear_L", "x", 30 * h)
        add(p, "Ear_R", "x", 30 * h)
        add(p, "Jaw", "x", 15 * h)
        return p

    body_drop = -1.95 if not big else -2.35

    def death(t):
        buckle = seg(t, 0.0, 0.4)
        roll = seg(t, 0.3, 0.8)
        p = {"_loc": {"Hips": (0.2 * roll, 0, body_drop * seg(t, 0.05, 0.75))}}
        add(p, "Hips", "y", 82 * roll)
        for s in ("L", "R"):
            add(p, "FrontUpperLeg_" + s, "x", -30 * buckle)
            add(p, "FrontLowerLeg_" + s, "x", 60 * buckle - 30 * roll)
            add(p, "HindUpperLeg_" + s, "x", -35 * buckle)
            add(p, "HindLowerLeg_" + s, "x", 50 * buckle - 20 * roll)
        add(p, "Neck", "x", 18 * roll)
        add(p, "Head", "y", 25 * roll)
        add(p, "Jaw", "x", 12 * roll)
        add(p, "Tail1", "x", -15 * roll)
        return p

    clips = [("Idle", 60, idle, True), ("Walk", 36, walk, True), ("Run", 20, run, True),
             ("Alert", 30, alert, False), ("Attack", 26, attack, False), ("Hit", 16, hit, False),
             ("Death", 46, death, False)]
    return clips + (special or [])


def wolf_howl(t):
    e = seg(t, 0, 0.25) * (1 - seg(t, 0.85, 1.0))
    p = {"_loc": {"Hips": (0, 0.25 * e, -0.55 * e)}}
    add(p, "Hips", "x", -24 * e)
    for s in ("L", "R"):
        add(p, "HindUpperLeg_" + s, "x", -30 * e)
        add(p, "HindLowerLeg_" + s, "x", 75 * e)
        add(p, "HindFoot_" + s, "x", -20 * e)
        add(p, "FrontUpperLeg_" + s, "x", 24 * e)
        add(p, "FrontPaw_" + s, "x", -10 * e)
    add(p, "Neck", "x", -36 * e)
    add(p, "Head", "x", -26 * e)
    add(p, "Jaw", "x", (26 + 3 * S(t, 0, 10)) * bump(t, 0.3, 0.4, 0.85))
    add(p, "Ear_L", "x", 20 * e)
    add(p, "Ear_R", "x", 20 * e)
    add(p, "Tail1", "x", -10 * e)
    return p


def bear_rear(t):
    e = seg(t, 0, 0.3) * (1 - seg(t, 0.75, 1.0))
    p = {"_loc": {"Hips": (0, -0.2 * e, 0.35 * e)}}
    add(p, "Hips", "x", -62 * e)
    for s in ("L", "R"):
        add(p, "HindUpperLeg_" + s, "x", 55 * e)
        add(p, "HindLowerLeg_" + s, "x", 10 * e)
        add(p, "HindFoot_" + s, "x", -8 * e)
        add(p, "FrontUpperLeg_" + s, "x", -30 * e + 12 * S(t, 0, 3) * bump(t, 0.3, 0.45, 0.75))
        add(p, "FrontLowerLeg_" + s, "x", 45 * e)
        add(p, "FrontPaw_" + s, "x", 20 * e)
    add(p, "Neck", "x", 38 * e)
    add(p, "Head", "x", 14 * e)
    add(p, "Jaw", "x", 34 * bump(t, 0.3, 0.42, 0.7))
    add(p, "Ear_L", "x", 20 * e)
    add(p, "Ear_R", "x", 20 * e)
    return p


def bear_attack(t):
    """Right-paw swipe (bear's attack replaces the lunge-bite)."""
    wind = bump(t, 0.0, 0.35, 0.5)
    swipe = bump(t, 0.35, 0.55, 0.95)
    p = {"_loc": {"Hips": (0, -0.5 * swipe, 0.25 * wind)}}
    add(p, "Hips", "x", -12 * wind)
    add(p, "FrontUpperLeg_R", "x", -70 * wind + 30 * swipe)
    add(p, "FrontUpperLeg_R", "z", -25 * swipe)
    add(p, "FrontLowerLeg_R", "x", 40 * wind)
    add(p, "Spine", "z", 10 * wind - 18 * swipe)
    add(p, "Neck", "x", 12 * swipe)
    add(p, "Jaw", "x", 28 * bump(t, 0.3, 0.5, 0.8))
    return p


# --------------------------------------------------------------------- bat

def membrane(c, poly, thickness, z, bone_side, mat="membrane"):
    """Thin, subdivided, watertight wing membrane in the XY plane."""
    from sh import textures as tx
    tmp = bmesh.new()
    vs = [tmp.verts.new((x, y, z)) for x, y in poly]
    tmp.faces.new(vs)
    bmesh.ops.triangulate(tmp, faces=tmp.faces[:], ngon_method="BEAUTY")
    bmesh.ops.subdivide_edges(tmp, edges=tmp.edges[:], cuts=1, use_grid_fill=True)
    bm = c.m.bm
    top = {v: bm.verts.new(v.co + Vector((0, 0, thickness / 2))) for v in tmp.verts}
    bot = {v: bm.verts.new(v.co - Vector((0, 0, thickness / 2))) for v in tmp.verts}
    for f in tmp.faces:
        a = bm.faces.new([top[v] for v in f.verts])
        b = bm.faces.new([bot[v] for v in reversed(f.verts)])
        a[c.m.l_mat] = b[c.m.l_mat] = tx.TILE_INDEX[mat]
    for e in tmp.edges:
        if len(e.link_faces) == 1:
            v0, v1 = e.verts
            f = bm.faces.new((top[v0], top[v1], bot[v1], bot[v0]))
            f[c.m.l_mat] = tx.TILE_INDEX[mat]
    tmp.free()
    return list(top.values()) + list(bot.values())


def build_bat(ctx):
    c = Creature("Bat", density=1.0)
    c.bone("Root", (0, 0, 0), (0, 0, 0.3), auto=False)
    c.bone("Body", (0, 0.4, 0), (0, -0.25, 0.04), "Root")
    c.bone("Head", (0, -0.25, 0.04), (0, -0.78, 0.06), "Body")
    c.bone("Jaw", (0, -0.42, -0.02), (0, -0.72, -0.02), "Head", auto=False)
    for s, sg in (("L", 1), ("R", -1)):
        c.bone("Ear_" + s, (sg * 0.12, -0.42, 0.18), (sg * 0.22, -0.4, 0.55), "Head", auto=False)
        c.bone("UpperArm_" + s, (sg * 0.15, -0.15, 0.05), (sg * 0.8, -0.05, 0.15), "Body", side=sg,
               bias=1.2)
        c.bone("Forearm_" + s, (sg * 0.8, -0.05, 0.15), (sg * 1.7, 0.05, 0.1), "UpperArm_" + s, side=sg)
        c.bone("Finger1_" + s, (sg * 1.7, 0.05, 0.1), (sg * 2.6, 0.12, 0.02), "Forearm_" + s, side=sg)
        c.bone("Finger2_" + s, (sg * 1.7, 0.05, 0.1), (sg * 2.05, 0.85, 0.0), "Forearm_" + s, side=sg)
        c.bone("Finger3_" + s, (sg * 1.7, 0.05, 0.1), (sg * 1.2, 1.05, 0.0), "Forearm_" + s, side=sg)
        c.bone("Leg_" + s, (sg * 0.12, 0.3, -0.05), (sg * 0.25, 0.78, -0.12), "Body", side=sg, bias=1.4)
    body = c.node((0, 0.35, 0), 0.19)
    chest = c.node((0, -0.12, 0.03), 0.25, body)
    c.chain(chest, [((0, -0.48, 0.07), 0.2), ((0, -0.72, 0.04), 0.09)])
    for sg in (1, -1):
        c.node((sg * 0.2, -0.14, 0.05), 0.1, chest)  # shoulder bulge in the body skin
        c.chain(body, [((sg * 0.25, 0.78, -0.12), 0.04)])
    c.skin_body(lambda cn, n: "fur_bat")
    m = c.m
    for sg in (1, -1):  # wing arm + finger bones as light tubes (auto-weighted)
        m.sweep("fur_bat", [(sg * 0.18, -0.14, 0.05), (sg * 0.8, -0.05, 0.15), (sg * 1.7, 0.05, 0.1)],
                [0.08, 0.06, 0.05], 5)
        for tip in ((2.6, 0.12, 0.02), (2.05, 0.85, 0.0), (1.2, 1.05, 0.0)):
            m.sweep("fur_bat", [(sg * 1.7, 0.05, 0.1), (sg * tip[0], tip[1], tip[2])], [0.04, 0.015], 4)
    for sg, s in ((1, "L"), (-1, "R")):
        poly = [(0.16, -0.12), (0.8, -0.05), (1.7, 0.05), (2.6, 0.12), (2.15, 0.45), (2.05, 0.85),
                (1.62, 0.78), (1.2, 1.05), (0.75, 0.82), (0.25, 0.78), (0.14, 0.35)]
        if sg < 0:
            poly = [(-x, y) for x, y in reversed(poly)]
        membrane(c, poly, 0.04, 0.06, sg)
        c.tag(m.cone("membrane", 0.13, 0.42, seg=4, loc=(sg * 0.12, -0.42, 0.15),
                     rot=(-10, sg * 20, 45), scale=(1, 0.5, 1)), "Ear_" + s)
        c.tag(m.blob("eye_glow", 0.045, loc=(sg * 0.1, -0.64, 0.12)), "Head")
        c.tag(m.cone("bone", 0.025, 0.1, seg=4, loc=(sg * 0.04, -0.74, 0.02), rot=(180, 0, 0)), "Head")
    c.tag(m.blob("nose", 0.05, loc=(0, -0.8, 0.06)), "Head")
    c.tag(m.sweep("fur_bat", [(0, -0.42, -0.03), (0, -0.7, -0.03)], [0.08, 0.05], 6, flat=0.5), "Jaw")
    return c


def bat_clips(c):
    def flap(pose, t, amp=45, fold=0.0, speed=1):
        for s, sg in (("L", 1), ("R", -1)):
            w = S(t, 0, speed)
            add(pose, "UpperArm_" + s, "y", sg * -amp * w)
            add(pose, "Forearm_" + s, "y", sg * -amp * 0.45 * S(t, -0.12, speed))
            add(pose, "Finger1_" + s, "y", sg * -amp * 0.3 * S(t, -0.2, speed))
            if fold:
                add(pose, "UpperArm_" + s, "z", sg * 30 * fold)
                add(pose, "Forearm_" + s, "z", sg * -50 * fold)
                for f in ("Finger1_", "Finger2_", "Finger3_"):
                    add(pose, f + s, "z", sg * 25 * fold)
        pose.setdefault("_loc", {})["Body"] = (0, 0, -0.18 * S(t, 0, speed))

    def idle(t):
        p = {}
        flap(p, t, 32)
        add(p, "Head", "z", 12 * S(t, 0.1))
        add(p, "Ear_L", "x", -15 * bump(t, 0.5, 0.55, 0.62))
        return p

    def fly(t):
        p = {}
        flap(p, t, 48, speed=2)
        add(p, "Body", "x", 10)
        return p

    def fast(t):
        p = {}
        flap(p, t, 38, fold=0.45, speed=3)
        add(p, "Body", "x", 18)
        return p

    def alert(t):
        e = seg(t, 0, 0.4)
        p = {}
        flap(p, t, 38, speed=2)
        add(p, "Head", "x", -12 * e)
        add(p, "Head", "z", 20 * bump(t, 0.4, 0.7, 1.0))
        add(p, "Ear_L", "x", -20 * e)
        add(p, "Ear_R", "x", -20 * e)
        add(p, "Jaw", "x", 20 * e)
        return p

    def attack(t):
        dive = bump(t, 0.1, 0.45, 0.95)
        p = {"_loc": {"Body": (0, -1.8 * dive, -0.9 * dive)}}
        flap(p, t, 30 * (1 - dive) + 10, fold=dive, speed=2)
        add(p, "Body", "x", 35 * dive)
        add(p, "Jaw", "x", 40 * bump(t, 0.3, 0.45, 0.6))
        return p

    def hit(t):
        h = bump(t, 0, 0.2, 1)
        p = {"_loc": {"Body": (0.3 * h, 0.4 * h, 0.2 * h)}}
        flap(p, t, 20)
        add(p, "Body", "y", 35 * h)
        add(p, "Head", "x", 20 * h)
        return p

    def death(t):
        fall = seg(t, 0.1, 1.0)
        p = {"_loc": {"Body": (0, 0, -3.0 * fall * fall)}}
        flap(p, t * (1 - fall), 25 * (1 - fall), fold=fall)
        add(p, "Body", "y", 160 * fall)
        add(p, "Body", "x", 50 * fall)
        add(p, "Head", "x", 25 * fall)
        add(p, "Jaw", "x", 15 * fall)
        return p

    return [("Idle", 24, idle, True), ("Fly", 24, fly, True), ("FastFly", 24, fast, True),
            ("Alert", 30, alert, False), ("Attack", 26, attack, False), ("Hit", 16, hit, False),
            ("Death", 40, death, False)]


# ------------------------------------------------------------------- export

SPECS = {
    "Wolf": dict(build=build_wolf,
                 clips=lambda c: quad_clips(c, special=[("Howl", 70, wolf_howl, False)]),
                 hitboxes=[("Body", (0, 0.25, 2.35), (1.4, 4.2, 1.7)),
                           ("Head", (0, -2.3, 3.35), (0.9, 1.5, 0.95))],
                 collider=((0, 0.2, 1.85), (1.5, 6.4, 3.7)),
                 use="Pack hunter. Fast, low HP. Idle/Walk/Run/Alert/Attack/Hit/Death/Howl.",
                 renders=[("Idle", 0), ("Walk", 9), ("Run", 5), ("Attack", 12), ("Howl", 40),
                          ("Death", 46)]),
    "Bear": dict(build=build_bear,
                 clips=lambda c: [cl for cl in quad_clips(c, big=True) if cl[0] != "Attack"] +
                 [("Attack", 30, bear_attack, False), ("RearUp", 72, bear_rear, False)],
                 hitboxes=[("Body", (0, 0.2, 3.1), (2.9, 5.6, 2.9)),
                           ("Head", (0, -3.6, 3.6), (1.6, 2.0, 1.6))],
                 collider=((0, -0.3, 2.6), (3.0, 9.0, 5.2)),
                 use="Heavy threat: slow, tanky. Idle/Walk/Run/Alert/Attack(swipe)/Hit/Death/RearUp.",
                 renders=[("Idle", 0), ("Walk", 9), ("Run", 5), ("Attack", 16), ("RearUp", 36),
                          ("Death", 46)]),
    "Bat": dict(build=build_bat, clips=bat_clips,
                hitboxes=[("Body", (0, 0.0, 0.0), (1.2, 1.6, 0.8))],
                collider=((0, 0.2, 0), (5.4, 1.8, 1.0)),
                use="Night swarm flyer. Pivot = body centre (hovers; not ground-based). "
                    "Idle(hover)/Fly/FastFly/Alert/Attack(dive)/Hit/Death(fall).",
                renders=[("Idle", 0), ("Fly", 6), ("FastFly", 4), ("Attack", 12), ("Death", 20)],
                hover=3.0),
}


def build_creature(ctx, name):
    spec = SPECS[name]
    col = ctx.collection("Wildlife")
    c = spec["build"](ctx)
    c.clips = []
    obj, arm = c.build(ctx, col)
    rig_path = os.path.join(P.OUT["rig"], f"SK_{name}.fbx")
    arm.animation_data_create()
    P.export_fbx([arm, obj], rig_path, (ctx.full, ctx.embed))
    scene = bpy.context.scene
    anim_files = []
    for cname, frames, fn, loop in spec["clips"](c):
        c.clip(cname, frames, fn, loop)
        scene.frame_start, scene.frame_end = 0, frames
        path = os.path.join(P.OUT["anim"], name, f"A_{name}_{cname}.fbx")
        P.export_fbx([arm, obj], path, (ctx.full, ctx.embed), anim=True)
        anim_files.append(dict(name=cname, file=P.rel(path), frames=frames, fps=FPS,
                               seconds=round(frames / FPS, 2), loop=loop))
    # hitbox / collider mesh
    hb = Model("COL_" + name)
    for _, cen, size in spec["hitboxes"]:
        hb.box("stone", size, loc=cen)
    hb.collision = [(cen, size, (0, 0, 0)) for _, cen, size in spec["hitboxes"]]
    col_path = P.export_collision(hb, os.path.join(P.OUT["col"], "Wildlife", f"COL_{name}_Hitboxes.fbx"),
                                  ctx.full)
    st = c.m.stats
    rec = dict(
        name=f"SK_{name}", category="Wildlife", kind="Rig", kind_note=P.KINDS["Rig"], use=spec["use"],
        notes=(f"{len(c.bones)} bones, max {c.max_influences} influences/vertex, Root has no "
               f"influence. Front faces -Z."),
        size_studs_roblox_XYZ=P.roblox_size(st["size"]), footprint_studs=[st["size"][0], st["size"][1]],
        tris=st["tris"], verts=st["verts"], materials=1, texture_tiles=st["tiles"], team_colored=False,
        origin_offset=[0.0, 0.0, 0.0],
        pivot="Root bone at the origin: between the feet on the ground (Bat: body centre).",
        collision_fidelity="Use the hitbox parts (CanCollide off on the skinned mesh).",
        attachments=[], parts=[],
        collision_boxes=[dict(name=n, cframe=P.to_roblox_cframe(cen), size=P.roblox_size(sz))
                         for n, cen, sz in spec["hitboxes"]],
        movement_collider=dict(cframe=P.to_roblox_cframe(spec["collider"][0]),
                               size=P.roblox_size(spec["collider"][1])),
        bones=[dict(name=b[0], parent=b[3]) for b in c.bones],
        animations=anim_files, lod1_tris=None,
        files=dict(fbx=P.rel(rig_path), collision=P.rel(col_path)),
        checks=dict(duplicate_faces=st["duplicate_faces"], open_edges=st["open_edges"],
                    nonmanifold_edges=st["nonmanifold_edges"], removed_degenerate=st["removed_degenerate"],
                    max_influences=c.max_influences),
        meta={},
    )
    ctx.objects["SK_" + name] = arm
    if ctx.renderer:
        rec["renders"] = render_poses(ctx, c, name, spec)
    print(f"SK_{name}: {st['tris']} tris, {len(c.bones)} bones, {len(anim_files)} clips, "
          f"max influences {c.max_influences}, open={st['open_edges']}")
    return [rec]


def render_poses(ctx, c, name, spec):
    r = ctx.renderer
    arm, obj = c.arm, c.obj
    out = os.path.join(P.OUT["render"], "Wildlife")
    dummy = ctx.objects["SH_Dummy"]
    hover = spec.get("hover", 0)
    arm.location.z = hover
    renders = {}
    clips = {cl["name"]: cl["action"] for cl in c.clips}
    for clip, frame in spec["renders"]:
        arm.animation_data.action = clips[clip]
        bpy.context.scene.frame_set(frame)
        dummy.location = (3.2 if name != "Bear" else 4.2, 1.0, 0)
        path = os.path.join(out, f"SK_{name}_{clip}.png")
        vis = [obj, dummy] if clip in ("Idle",) else [obj]
        renders[clip] = P.rel(r.render(vis, path, direction=(1.1, -1.25, 0.6)))
    dummy.location = (0, 0, 0)
    arm.animation_data.action = clips["Idle"]
    bpy.context.scene.frame_set(0)
    renders["preview"] = renders["Idle"]
    arm.location.z = 0
    return renders


@P.asset("SK_Wolf", "Wildlife", "Rig")
def wolf(ctx):
    return build_creature(ctx, "Wolf")


@P.asset("SK_Bear", "Wildlife", "Rig")
def bear(ctx):
    return build_creature(ctx, "Bear")


@P.asset("SK_Bat", "Wildlife", "Rig")
def bat(ctx):
    return build_creature(ctx, "Bat")
