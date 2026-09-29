"""Fit a Meshy (or other AI-made) GLB/FBX to the game's size, pivot and axes, then
export an upload-ready FBX (texture embedded) to Export/Meshy/<Name>.fbx.

    python3 tools/fit_meshy.py model.glb SM_Axe_Crude --held --height 3.6 --grip 0.7
    python3 tools/fit_meshy.py model.glb SM_Lobby_Bench --size 5 1.8 1.6

--held    hand tool/weapon: longest axis becomes the handle (up +Y in Roblox), the
          handle is straightened, the head goes on top, the blade/striking side faces
          forward (-Z), the thin side runs sideways, and the origin sits on the handle
          --grip studs above its bottom end (same layout as the Blender-built tools).
          Scaled evenly so the height is --height.
--size    prop: kept upright, turned so its long side runs along X when the target is
          wider than deep, scaled evenly to fit inside W x H x D (Roblox studs), origin
          at the bottom centre.
--stretch with --size: stretch to exactly W x H x D instead of keeping proportions.
--tris    decimate above this many triangles (default 8000; Roblox caps a mesh at 20000).

Runs with the bpy module (SH_WITH_BPY=1 bash tools/setup_env.sh). Prints the final
Roblox size and origin offset for AssetIds.
"""
import argparse, math, os, sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "NONE"
    if path.lower().endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=path)
    elif path.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.wm.obj_import(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    for o in list(bpy.data.objects):
        if o != obj:
            bpy.data.objects.remove(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def verts(obj):
    return [v.co.copy() for v in obj.data.vertices]


def bounds(obj):
    vs = verts(obj)
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def apply(obj, m):
    obj.data.transform(m)
    obj.data.update()


def rot(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def decimate(obj, limit):
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris <= limit:
        return tris
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = limit / tris
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def long_axis_up(obj):
    lo, hi = bounds(obj)
    d = hi - lo
    i = max(range(3), key=lambda k: d[k])
    if i == 0:
        apply(obj, rot("Y", 90))
    elif i == 1:
        apply(obj, rot("X", 90))


def fit_held(obj, height, grip):
    long_axis_up(obj)
    # thin side along X, wide side (blade plane) along Y
    lo, hi = bounds(obj)
    if hi.x - lo.x > hi.y - lo.y:
        apply(obj, rot("Z", 90))

    def slices(n=12):
        vs = verts(obj)
        lo, hi = bounds(obj)
        out = []
        for s in range(n):
            a = lo.z + (hi.z - lo.z) * s / n
            b = lo.z + (hi.z - lo.z) * (s + 1) / n
            sl = [v for v in vs if a <= v.z <= b]
            if sl:
                ys = [v.y for v in sl]
                out.append(((a + b) / 2, min(ys), max(ys), sum(v.x for v in sl) / len(sl)))
        return out

    # head on top: the wider end
    sl = slices()
    k = len(sl) // 4
    width = lambda group: max(s[2] - s[1] for s in group)
    if width(sl[:k]) > width(sl[-k:]):
        apply(obj, rot("X", 180))

    # straighten: fit a line through the handle's mid points (lower half) in the YZ plane
    for _ in range(3):
        sl = slices()
        hs = sl[: len(sl) // 2]
        zs = [s[0] for s in hs]
        ys = [(s[1] + s[2]) / 2 for s in hs]
        zm, ym = sum(zs) / len(zs), sum(ys) / len(ys)
        slope = sum((z - zm) * (y - ym) for z, y in zip(zs, ys)) / max(1e-9, sum((z - zm) ** 2 for z in zs))
        apply(obj, rot("X", math.degrees(math.atan(slope))))
        long_axis_up(obj)

    # handle axis and bottom end
    sl = slices()
    hs = sl[: len(sl) // 2]
    hy = sum((s[1] + s[2]) / 2 for s in hs) / len(hs)
    hx = sum(s[3] for s in hs) / len(hs)
    lo, hi = bounds(obj)
    # blade/striking side faces -Y (Roblox forward -Z): the side reaching further from the handle
    if hi.y - hy > hy - lo.y:
        apply(obj, rot("Z", 180))
        hy, hx = -hy, -hx
    lo, hi = bounds(obj)
    apply(obj, Matrix.Translation((-hx, -hy, -lo.z)))
    s = height / (hi.z - lo.z)
    apply(obj, Matrix.Scale(s, 4))
    apply(obj, Matrix.Translation((0, 0, -grip)))


def fit_prop(obj, size, stretch):
    # size is Roblox W x H x D -> Blender x, z, y
    w, h, d = size
    lo, hi = bounds(obj)
    if (hi.x - lo.x < hi.y - lo.y) != (w < d):
        apply(obj, rot("Z", 90))
    lo, hi = bounds(obj)
    ext = hi - lo
    if stretch:
        sc = (w / ext.x, d / ext.y, h / ext.z)
    else:
        s = min(w / ext.x, d / ext.y, h / ext.z)
        sc = (s, s, s)
    c = (lo + hi) / 2
    apply(obj, Matrix.Translation((-c.x, -c.y, -lo.z)))
    apply(obj, Matrix.Diagonal((*sc, 1)))


def export(obj, name):
    out = os.path.join(ROOT, "Export", "Meshy", name + ".fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    obj.name = obj.data.name = name
    for o in bpy.data.objects:
        o.select_set(o == obj)
    bpy.ops.export_scene.fbx(
        filepath=out, use_selection=True, object_types={"MESH"},
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS", global_scale=1.0,
        axis_forward="Z", axis_up="Y", mesh_smooth_type="FACE",
        path_mode="COPY", embed_textures=True)
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("name")
    ap.add_argument("--held", action="store_true")
    ap.add_argument("--height", type=float, default=3.6)
    ap.add_argument("--grip", type=float, default=0.7)
    ap.add_argument("--size", type=float, nargs=3)
    ap.add_argument("--stretch", action="store_true")
    ap.add_argument("--tris", type=int, default=8000)
    a = ap.parse_args(argv)
    obj = load(a.src)
    tris = decimate(obj, a.tris)
    if a.held:
        fit_held(obj, a.height, a.grip)
    else:
        fit_prop(obj, a.size, a.stretch)
    out = export(obj, a.name)
    lo, hi = bounds(obj)
    c = (lo + hi) / 2
    size = (hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)
    offset = (c.x, -c.z, -c.y)  # -(Roblox centre); Roblox = (-x, z, y)
    print(f"{a.name}: {tris} tris -> {os.path.relpath(out, ROOT)}")
    print("  Size   = {%s}" % ", ".join(f"{v:.3g}" for v in size))
    print("  Offset = {%s}" % ", ".join(f"{v + 0.0:.3g}" for v in offset))


if __name__ == "__main__":
    main()
