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

The geometry is the owner's blocky animal models (blender/source_models/animals/
<Species>_Basic.blend), split into those pieces and fitted to the bounds each
part was first published with, so the uploaded IDs take the new look as new
versions. Every mesh's origin is its rig part's centre (Motor6D C1 space), so
the game places it with part.CFrame and welds it. The rig numbers below mirror
Animals.luau: change both together. Blender axes: -Y forward, +Z up, X side
(Roblox X = -Blender X, Roblox Y = Blender Z, Roblox Z = Blender Y).
"""

import math
import os

import bpy
from mathutils import Matrix, Vector

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


# ------------------------------------------------------------ owner models

# The owner's six blocky animals (one .blend each: an empty <Species>_Root with
# separate child meshes, head facing -Y, flat materials). Their parts are split
# into the rig's pieces below.
SRC_DIR = os.path.join(P.ROOT, "blender", "source_models", "animals")

# Published bounds (Blender lo / hi) of every part mesh, from AssetIds.luau. Each
# rebuilt part is fitted to exactly this box so the uploaded asset IDs keep
# working as new versions (tools/check_bounds.py).
BOUNDS = {
    "SM_Wolf_Body": ((-0.74, -2.12, -0.8), (0.74, 2.08, 0.8)),
    "SM_Wolf_Head": ((-0.465, -1.632, -0.6105), (0.465, 0.878, 1.0895)),
    "SM_Wolf_LegF": ((-0.305, -0.3115, -1.348), (0.305, 0.2985, 1.562)),
    "SM_Wolf_LegB": ((-0.375, -0.4855, -1.35), (0.375, 0.4245, 1.56)),
    "SM_Wolf_Tail": ((-0.265, -1.5865, -0.548), (0.265, 1.2835, 0.192)),
    "SM_Bear_Body": ((-1.9, -3.85, -1.75), (1.9, 3.65, 1.95)),
    "SM_Bear_Head": ((-1.25, -2.622, -1.08), (1.25, 1.458, 1.37)),
    "SM_Bear_LegF": ((-0.815, -0.8075, -2.162), (0.815, 0.8225, 2.538)),
    "SM_Bear_LegB": ((-0.905, -1.0395, -2.161), (0.905, 0.7705, 2.529)),
    "SM_Bear_Tail": ((-0.29, -0.55, -0.3325), (0.29, 0.42, 0.2775)),
    "SM_Deer_Body": ((-0.66, -2.15, -0.74), (0.66, 2.1, 0.78)),
    "SM_Deer_Head": ((-0.74, -1.199, -0.6155), (0.74, 0.941, 0.9745)),
    "SM_Deer_Head_Antlered": ((-0.84, -1.199, -0.613), (0.84, 0.941, 2.137)),
    "SM_Deer_LegF": ((-0.235, -0.22, -1.927), (0.235, 0.25, 2.123)),
    "SM_Deer_LegB": ((-0.325, -0.4185, -1.926), (0.325, 0.4215, 2.124)),
    "SM_Deer_Tail": ((-0.125, -0.29, -0.09), (0.125, 0.25, 0.09)),
    "SM_Rabbit_Body": ((-0.3, -0.56, -0.3), (0.3, 0.54, 0.3)),
    "SM_Rabbit_Head": ((-0.1755, -0.384, -0.149), (0.1745, 0.146, 0.621)),
    "SM_Rabbit_LegF": ((-0.09, -0.1095, -0.3145), (0.09, 0.0805, 0.3855)),
    "SM_Rabbit_LegB": ((-0.175, -0.134, -0.3165), (0.175, 0.226, 0.4035)),
    "SM_Rabbit_Tail": ((-0.0985, -0.224, -0.1115), (0.1015, -0.014, 0.0785)),
    "SM_Boar_Body": ((-0.9, -1.95, -0.8475), (0.9, 1.85, 1.1225)),
    "SM_Boar_Head": ((-0.49, -1.3355, -0.53), (0.49, 0.6545, 0.81)),
    "SM_Boar_LegF": ((-0.355, -0.35, -0.9435), (0.355, 0.36, 1.1665)),
    "SM_Boar_LegB": ((-0.42, -0.4895, -0.9455), (0.42, 0.3505, 1.1645)),
    "SM_Boar_Tail": ((-0.09, -0.5865, -0.5355), (0.09, 0.0835, 0.1145)),
    "SM_Bat_Body": ((-0.72, -1.541, -0.6205), (0.72, 0.949, 1.3295)),
    "SM_Bat_Wing": ((-2.952, -0.8795, -0.0985), (1.718, 1.0005, 0.1215)),
}

# Atlas tiles a source colour may not snap to (team-tinted, emissive, metallic).
SWATCH_SKIP = {"team_cloth", "team_paint", "fire", "embers", "glow", "water", "diamond", "metal", "metal_dark",
               "gunmetal", "brass"}
# Hand picks (source material name -> (tile, lightness percentile)) where the
# nearest swatch loses the look: the atlas has no pink or blue-grey fur.
SWATCH_PICK = {
    "Rabbit ears and nose": ("leather_stitch", 100),
    "Bat wing": ("stone", 20),
    "Bat inner ear": ("membrane", 98),
    "Ivory tusks": ("bone", 50),
}


def _lab(rgb_lin):
    x, y, z = (Matrix(((0.4124, 0.3576, 0.1805), (0.2126, 0.7152, 0.0722), (0.0193, 0.1192, 0.9505)))
               @ Vector(rgb_lin))

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x / 0.9505), f(y), f(z / 1.089)
    return Vector((116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)))


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


_SWATCHES = None


def swatch(name, rgb_lin):
    """Nearest atlas swatch (tile, lightness percentile) to a linear source colour."""
    global _SWATCHES
    if name in SWATCH_PICK:
        return SWATCH_PICK[name]
    if _SWATCHES is None:
        _SWATCHES = [(t, q, _lab([_lin(c) for c in tx.tone_rgb(i, q)]))
                     for i, t in enumerate(tx.TILE_NAMES) if t not in SWATCH_SKIP for q in range(0, 101, 2)]
    lab = _lab(rgb_lin)

    def dist(s):  # lightness counts a little less than hue (the atlas is muted)
        d = s[2] - lab
        return (0.6 * d.x) ** 2 + d.y ** 2 + d.z ** 2
    t, q, _ = min(_SWATCHES, key=dist)
    return t, q


class Piece:
    """One source mesh: world-space verts and (vertex indices, tile, percentile) faces."""

    def __init__(self, name, verts, faces):
        self.name, self.v, self.f = name, verts, faces

    def copy(self):
        return Piece(self.name, [v.copy() for v in self.v], list(self.f))


_SRC = {}


def _world(o):
    m = o.matrix_basis.copy()
    while o.parent:
        m = o.parent.matrix_basis @ o.matrix_parent_inverse @ m
        o = o.parent
    return m


def source(sp):
    """{object name: Piece} of the owner's model (animal parts only, no floor/lights)."""
    if sp in _SRC:
        return _SRC[sp]
    path = os.path.join(SRC_DIR, f"{sp}_Basic.blend")
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        names = [str(n) for n in src.objects]
        dst.objects = list(names)
    parts = {}
    for name, o in zip(names, dst.objects):
        if o is None or o.type != "MESH" or o.parent is None:
            continue
        mw = _world(o)
        tones = []
        for slot in o.material_slots:
            mat = slot.material
            col = mat.diffuse_color[:3]
            if mat.node_tree:
                for n in mat.node_tree.nodes:
                    if n.type == "BSDF_PRINCIPLED":
                        col = n.inputs["Base Color"].default_value[:3]
            tile, q = swatch(mat.name, col)
            tones.append((tx.TILE_INDEX[tile], q))
        parts[name] = Piece(name, [mw @ v.co for v in o.data.vertices],
                            [(tuple(p.vertices), *tones[p.material_index]) for p in o.data.polygons])
    loaded = [o for o in dst.objects if o is not None]
    datas = [o.data for o in loaded if o.data is not None]
    mats = {mt for d in datas if isinstance(d, bpy.types.Mesh) for mt in d.materials if mt}
    for o in loaded:
        bpy.data.objects.remove(o)
    for d in datas:
        try:
            if d.users == 0:
                {bpy.types.Mesh: bpy.data.meshes, bpy.types.Camera: bpy.data.cameras}.get(
                    type(d), bpy.data.lights).remove(d)
        except ReferenceError:  # already freed with its object
            pass
    for mt in mats:
        if mt.users == 0:
            bpy.data.materials.remove(mt)
    _SRC[sp] = parts
    return parts


def pick(sp, names):
    src = source(sp)
    return [src[n].copy() for n in names]


def bbox(pieces):
    vs = [v for p in pieces for v in p.v]
    return (Vector([min(v[i] for v in vs) for i in range(3)]),
            Vector([max(v[i] for v in vs) for i in range(3)]))


def xform(pieces, mat, about=(0, 0, 0)):
    c = Vector(about)
    for p in pieces:
        p.v = [mat @ (v - c) + c for v in p.v]
    return pieces


def remap(pieces, src_box, dst_box, axes=(0, 1, 2)):
    """Per-axis linear map of src_box onto dst_box (the source box is usually the
    pieces' own bounds, so the result exactly fills dst_box)."""
    (a0, a1), (b0, b1) = src_box, dst_box
    for p in pieces:
        for v in p.v:
            for i in axes:
                v[i] = b0[i] + (v[i] - a0[i]) / (a1[i] - a0[i]) * (b1[i] - b0[i])
    return pieces


def emit(m, pieces, name):
    """Adds the pieces to Model m (flat atlas colours) and snaps m to the published box."""
    bm = m.bm
    lay = bm.faces.layers.int.get("tone") or bm.faces.layers.int.new("tone")
    for p in pieces:
        vs = [bm.verts.new(v) for v in p.v]
        for idx, tile, q in p.f:
            try:
                f = bm.faces.new([vs[i] for i in idx])
            except ValueError:
                continue
            f[m.l_mat] = tile
            f[lay] = int(q) + 1
    m.fit_bounds(*BOUNDS[name])


def fill(m, name, pieces):
    remap(pieces, bbox(pieces), BOUNDS[name])
    emit(m, pieces, name)


# ------------------------------------------------------------------ pieces

def body(m, sp, names):
    fill(m, f"SM_{sp}_Body", pick(sp, names))


def head(m, sp, names, extra=None, name=None, antlers=None):
    """Head group mapped onto the published head box. extra(sp) adds pieces
    (e.g. a neck) in source space first. With antlers, the head keeps the plain
    head's mapping and the antlers alone stretch up to the antlered box."""
    pcs = pick(sp, names)
    if extra:
        pcs += extra(sp)
    plain = BOUNDS[f"SM_{sp}_Head"]
    box = bbox(pcs)
    remap(pcs, box, plain)
    if antlers:
        lo, hi = BOUNDS[name]
        ant = remap(pick(sp, antlers), box, plain)
        a0, a1 = bbox(ant)
        sx = hi[0] / max(abs(a0[0]), a1[0])
        for p in ant:
            for v in p.v:
                v.x *= sx
                v.z = a0.z + (v.z - a0.z) * (hi[2] - a0.z) / (a1.z - a0.z)
        pcs += ant
    emit(m, pcs, name or f"SM_{sp}_Head")


def leg(m, sp, name, shaft, foot, extra=None):
    """Leg + paw/hoof filling the leg box: x/y stretch to the box, the paw keeps
    about its proportions at the bottom and the shaft stretches up to the hip."""
    lo, hi = BOUNDS[name]
    sh = pick(sp, shaft)
    ft = pick(sp, foot)
    if extra:
        sh += extra(sp, ft)
    pcs = sh + ft
    b0, b1 = bbox(pcs)
    remap(pcs, (b0, b1), (lo, hi), axes=(0, 1))
    if not ft:
        remap(pcs, (b0, b1), (lo, hi), axes=(2,))
    else:
        s = ((hi[0] - lo[0]) / (b1.x - b0.x) + (hi[1] - lo[1]) / (b1.y - b0.y)) / 2
        f1 = bbox(ft)[1].z
        s = min(s, 0.2 * (hi[2] - lo[2]) / (f1 - b0.z))
        for p in ft:
            for v in p.v:
                v.z = lo[2] + (v.z - b0.z) * s
        s0 = bbox(sh)[0].z
        z0 = lo[2] + (s0 - b0.z) * s
        for p in sh:
            for v in p.v:
                v.z = z0 + (v.z - s0) / (b1.z - s0) * (hi[2] - z0)
    emit(m, pcs, name)


def tail(m, sp, names, ref, angle=0.0):
    """Tail turned so its long axis (of piece `ref`) points back (+Y) at `angle`
    degrees above the horizontal (negative = hanging), then fitted to the box."""
    pcs = pick(sp, names)
    r = [p for p in pcs if p.name == ref][0]
    c = sum(r.v, Vector()) / len(r.v)
    syy = sum((v.y - c.y) ** 2 for v in r.v)
    szz = sum((v.z - c.z) ** 2 for v in r.v)
    syz = sum((v.y - c.y) * (v.z - c.z) for v in r.v)
    cur = 0.5 * math.atan2(2 * syz, syy - szz)  # principal axis angle in the YZ plane
    xform(pcs, Matrix.Rotation(math.radians(angle) - cur, 3, "X"), c)
    fill(m, f"SM_{sp}_Tail", pcs)


def block(sp, like, scale, centre):
    """Extra block cut from one of the source pieces (same colours), rescaled
    about its own centre and moved to `centre` (source space)."""
    p = pick(sp, [like])[0]
    c = sum(p.v, Vector()) / len(p.v)
    p.v = [Vector(centre) + Vector([(v - c)[i] * scale[i] for i in range(3)]) for v in p.v]
    p.name = like + "_extra"
    return p


FACE = ["Ear_L", "Ear_R", "InnerEar_L", "InnerEar_R", "Eye_L", "Eye_R"]


def wolf_head(m):
    head(m, "Wolf", ["Head", "Muzzle", "Nose", "Neck"] + FACE)


def bear_neck(sp):
    # the owner's bear has no neck; the head box reaches back over the shoulders
    return [block(sp, "Head", (0.8, 0.9, 0.75), (0, -1.0, 2.55))]


def bear_head(m):
    head(m, "Bear", ["Head", "Muzzle", "Nose", "Mouth"] + FACE, extra=bear_neck)


DEER_HEAD = ["Head", "Muzzle", "Nose", "Neck", "ChestPatch"] + FACE
DEER_ANTLERS = ["AntlerStem_L", "AntlerStem_R", "AntlerTine_L", "AntlerTine_R", "AntlerOuter_L", "AntlerOuter_R"]


def rabbit_thigh(sp, ft):
    # the owner's rabbit has paws only: a haunch block rises from the back paw
    return [block(sp, "BackPaw_R", (0.8, 0.55, 2.2), (0.56, 1.0, 0.6))]


BAT_HEAD_SHIFT = (0, -0.1, -0.55)


def bat_body(m):
    """The owner's bat hangs upright; the rig flies level, head first (-Y). The
    body and feet pitch forward and the head sits on the front, looking ahead."""
    sp = "Bat"
    trunk = pick(sp, ["Body", "Foot_L", "Foot_R"])
    xform(trunk, Matrix.Rotation(math.radians(90), 3, "X"), (0, 0, 1.53))
    hd = pick(sp, ["Head", "Muzzle", "Nose"] + FACE)
    for p in hd:
        p.v = [v + Vector(BAT_HEAD_SHIFT) for v in p.v]
    fill(m, "SM_Bat_Body", trunk + hd)


def bat_wing(m):
    """Right wing of the rig = the owner's Wing_L (Blender -X), laid flat with the
    arm on the leading (-Y) edge; the joint side is +X."""
    pcs = pick("Bat", ["Wing_L", "WingArm_L"])
    xform(pcs, Matrix.Rotation(math.radians(90), 3, "X"))
    fill(m, "SM_Bat_Wing", pcs)


# ------------------------------------------------------------ registration

SPECIES = ["Wolf", "Bear", "Deer", "Rabbit", "Boar"]
BUILDERS = {
    "Wolf": dict(Body=lambda m: body(m, "Wolf", ["Body", "Chest"]), Head=wolf_head,
                 LegF=lambda m: leg(m, "Wolf", "SM_Wolf_LegF", ["FrontLeg_R"], ["FrontPaw_R"]),
                 LegB=lambda m: leg(m, "Wolf", "SM_Wolf_LegB", ["BackLeg_R"], ["BackPaw_R"]),
                 Tail=lambda m: tail(m, "Wolf", ["Tail", "TailTip"], "Tail")),
    "Bear": dict(Body=lambda m: body(m, "Bear", ["Body", "Chest"]), Head=bear_head,
                 LegF=lambda m: leg(m, "Bear", "SM_Bear_LegF", ["FrontLeg_R"], ["FrontPaw_R"]),
                 LegB=lambda m: leg(m, "Bear", "SM_Bear_LegB", ["BackLeg_R"], ["BackPaw_R"]),
                 Tail=lambda m: fill(m, "SM_Bear_Tail", pick("Bear", ["Tail"]))),
    "Deer": dict(Body=lambda m: body(m, "Deer", ["Body"]),
                 Head=lambda m: head(m, "Deer", DEER_HEAD),
                 Head_Antlered=lambda m: head(m, "Deer", DEER_HEAD, name="SM_Deer_Head_Antlered",
                                              antlers=DEER_ANTLERS),
                 LegF=lambda m: leg(m, "Deer", "SM_Deer_LegF", ["FrontLeg_R"], ["FrontHoof_R"]),
                 LegB=lambda m: leg(m, "Deer", "SM_Deer_LegB", ["BackLeg_R"], ["BackHoof_R"]),
                 Tail=lambda m: fill(m, "SM_Deer_Tail", pick("Deer", ["Tail"]))),
    "Rabbit": dict(Body=lambda m: body(m, "Rabbit", ["Body", "Chest"]),
                   Head=lambda m: head(m, "Rabbit", ["Head", "Muzzle_L", "Muzzle_R", "Nose"] + FACE),
                   LegF=lambda m: leg(m, "Rabbit", "SM_Rabbit_LegF", ["FrontPaw_R"], []),
                   LegB=lambda m: leg(m, "Rabbit", "SM_Rabbit_LegB", [], ["BackPaw_R"], extra=rabbit_thigh),
                   Tail=lambda m: fill(m, "SM_Rabbit_Tail", pick("Rabbit", ["Tail"]))),
    "Boar": dict(Body=lambda m: body(m, "Boar", ["Body", "Shoulders"]),
                 Head=lambda m: head(m, "Boar", ["Head", "Snout", "SnoutTip", "Nostril_L", "Nostril_R",
                                                 "Tusk_L", "Tusk_R", "Ear_L", "Ear_R", "Eye_L", "Eye_R"]),
                 LegF=lambda m: leg(m, "Boar", "SM_Boar_LegF", ["FrontLeg_R"], ["FrontHoof_R"]),
                 LegB=lambda m: leg(m, "Boar", "SM_Boar_LegB", ["BackLeg_R"], ["BackHoof_R"]),
                 Tail=lambda m: tail(m, "Boar", ["Tail", "TailTuft"], "Tail", angle=-50)),
}
RIG_PART = {"Body": "Torso", "Head": "Head", "Head_Antlered": "Head", "LegF": "LegFL, LegFR",
            "LegB": "LegBL, LegBR", "Tail": "TailPart"}
SMOOTH = 35  # blocky owner models: keep the bevels crisp


def _register(sp, piece, fn):
    P.asset(f"SM_{sp}_{piece}", CAT, "RigPart", density=1.6, smooth=SMOOTH, grain=(0, 1, 0),
            uv_box=True, dummy=False, preview=False, fidelity="Box",
            pivot=f"Centre of the {sp} rig's {RIG_PART.get(piece, piece)} part (Animals.luau).",
            use=f"{sp} rig: weld onto {RIG_PART.get(piece, piece)} (Models/Animals.luau).")(fn)


for _sp in SPECIES:
    for _piece, _fn in BUILDERS[_sp].items():
        _register(_sp, _piece, _fn)
P.asset("SM_Bat_Body", CAT, "RigPart", density=1.2, smooth=SMOOTH, grain=(0, 1, 0), uv_box=True,
        dummy=False, preview=False, pivot="Centre of the bat rig's Body ball (Animals.luau).",
        use="Bat rig: weld onto Body (covers head, ears and eyes).")(bat_body)
P.asset("SM_Bat_Wing", CAT, "RigPart", density=1.2, smooth=SMOOTH, grain=(1, 0, 0), uv_box=True,
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
