"""Re-imports every exported FBX into a fresh scene and checks it:
triangle budget, origin at the base centre, size matches assets/export/manifest.json,
and that the OBJ twin has the same triangle count. Also reports which way the model's front
faces in the exported (Y-up) space.

    python3 blender/verify.py
"""

import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

from lib import ROOT, STUD  # noqa: E402

EXPORT = os.path.join(ROOT, "assets", "export")
TRI_BUDGET = 10000
TOL = 0.05  # studs


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mesh_stats(objs):
    tris = 0
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for ob in objs:
        me = ob.data
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        for v in me.vertices:
            p = ob.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], p[i])
                hi[i] = max(hi[i], p[i])
    return tris, lo, hi


def headlight_z(path):
    """Mean OBJ z (Y-up export space) of the faces using EF_Light (a vehicle's headlights = its front)."""
    verts, cur, zs = [], None, []
    with open(path) as fh:
        for line in fh:
            if line.startswith("v "):
                verts.append(float(line.split()[3]))
            elif line.startswith("usemtl"):
                cur = line.split()[1]
            elif line.startswith("f ") and cur == "EF_Light":
                zs += [verts[int(t.split("/")[0]) - 1] for t in line.split()[1:]]
    return sum(zs) / len(zs) if zs else None


def obj_tris(path):
    n = 0
    with open(path) as fh:
        for line in fh:
            if line.startswith("f "):
                n += len(line.split()) - 3
    return n


def main():
    with open(os.path.join(EXPORT, "manifest.json")) as fh:
        manifest = json.load(fh)
    files = sorted(glob.glob(os.path.join(EXPORT, "*.fbx")))
    problems = []
    for path in files:
        name = os.path.splitext(os.path.basename(path))[0]
        fresh()
        bpy.ops.import_scene.fbx(filepath=path, axis_forward="-Z", axis_up="Y")
        objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        if len(objs) != 1:
            problems.append(f"{name}: expected 1 mesh, got {len(objs)}")
            continue
        tris, lo, hi = mesh_stats(objs)
        size = [(hi[i] - lo[i]) / STUD for i in range(3)]  # Blender X, Y(depth), Z(up)
        studs = [size[0], size[2], size[1]]
        cx, cy = (lo[0] + hi[0]) / 2 / STUD, (lo[1] + hi[1]) / 2 / STUD
        base = lo[2] / STUD
        status = []
        if tris > TRI_BUDGET:
            status.append(f"{tris} tris > {TRI_BUDGET}")
        if abs(cx) > TOL or abs(cy) > TOL or abs(base) > TOL:
            status.append(f"origin off base centre (dx={cx:.2f}, dy={cy:.2f}, base={base:.2f})")
        m = manifest.get(name)
        if not m:
            status.append("missing from manifest.json")
        else:
            if m["tris"] != tris:
                status.append(f"tri count {tris} != manifest {m['tris']}")
            if any(abs(a - b) > 0.1 for a, b in zip(studs, m["studs"])):
                status.append(f"size {studs} != manifest {m['studs']}")
        objp = os.path.join(EXPORT, "obj", name + ".obj")
        if not os.path.exists(objp):
            status.append("OBJ missing")
        elif obj_tris(objp) != tris:
            status.append(f"OBJ tris {obj_tris(objp)} != FBX {tris}")
        mats = len(objs[0].data.materials)
        flag = "OK " if not status else "BAD"
        print(f"{flag} {name:<14} {tris:>5} tris  {studs[0]:6.1f} x {studs[1]:5.1f} x {studs[2]:5.1f} studs  {mats} mats"
              + ("  <- " + "; ".join(status) if status else ""))
        if status:
            problems.append(name + ": " + "; ".join(status))
    # orientation probe: the pickup's headlights are on its front
    probe = os.path.join(EXPORT, "obj", "FarmPickup.obj")
    if os.path.exists(probe):
        z = headlight_z(probe)
        if z is not None:
            front = "+Z" if z > 0 else "-Z (Roblox LookVector)"
            if z > 0:
                problems.append("orientation: fronts face +Z, expected -Z")
            print(f"orientation: model fronts face {front} in the exported Y-up space "
                  f"(FarmPickup headlights at z={z:.2f} m)")
    # every category scene opens and holds its meshes
    cats = {}
    for name, m in manifest.items():
        cats.setdefault(m["category"], set()).add(name)
    for cat, names in sorted(cats.items()):
        path = os.path.join(ROOT, "assets", "blend", cat + ".blend")
        if not os.path.exists(path):
            problems.append(f"{cat}.blend missing")
            continue
        bpy.ops.wm.open_mainfile(filepath=path)
        have = {o.name for o in bpy.data.objects if o.type == "MESH"}
        missing = names - have
        print(f"{'OK ' if not missing else 'BAD'} {cat}.blend: {len(have)} meshes" + (f", missing {sorted(missing)}" if missing else ""))
        if missing:
            problems.append(f"{cat}.blend missing {sorted(missing)}")
    print(f"{len(files)} FBX checked, {len(problems)} problem(s)")
    if problems:
        sys.exit(1)


if __name__ == "__main__":
    main()
