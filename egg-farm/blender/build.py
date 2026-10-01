"""Egg Farm asset build: procedurally models every mesh, exports FBX + OBJ, renders previews
and saves one editable .blend per category.

    python3 blender/build.py                 # everything
    python3 blender/build.py --only Chicken  # one asset (or a category name, e.g. Vehicles)
    python3 blender/build.py --no-render     # skip preview renders

Outputs (relative to egg-farm/):
    assets/export/<Name>.fbx, assets/export/obj/<Name>.obj (+ .mtl)
    assets/blend/<Category>.blend   (only when a whole category is built)
    docs/renders/<Name>.png         (320 px, Cycles CPU, transparent background)
    assets/export/manifest.json     (triangle counts + sizes, merged across runs)
"""

import argparse
import json
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import assets_buildings  # noqa: E402
import assets_living  # noqa: E402
import assets_props  # noqa: E402
import assets_vehicles  # noqa: E402
from lib import ROOT, STUD, Builder, dims_studs, tri_count  # noqa: E402

TRI_BUDGET = 10000

EXPORT = os.path.join(ROOT, "assets", "export")
OBJDIR = os.path.join(EXPORT, "obj")
BLEND = os.path.join(ROOT, "assets", "blend")
RENDERS = os.path.join(ROOT, "docs", "renders")
MANIFEST_JSON = os.path.join(EXPORT, "manifest.json")


def categories():
    cats = {}
    for mod in (assets_living, assets_buildings, assets_vehicles, assets_props):
        cats.update(mod.ASSETS)
    return cats


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0


def select_only(ob):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def export(ob):
    select_only(ob)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(EXPORT, ob.name + ".fbx"),
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        bake_space_transform=True,
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        path_mode="STRIP",
        embed_textures=False,
    )
    bpy.ops.wm.obj_export(
        filepath=os.path.join(OBJDIR, ob.name + ".obj"),
        export_selected_objects=True,
        forward_axis="NEGATIVE_Z",
        up_axis="Y",
        export_materials=True,
        export_uv=False,
        export_normals=True,
        apply_modifiers=True,
        path_mode="STRIP",
    )


# ------------------------------------------------------------------ rendering
def setup_render_scene():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 3
    sc.render.resolution_x = 320
    sc.render.resolution_y = 320
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.compression = 90
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("EF_Sky")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.55, 0.72, 0.95, 1)
    bg.inputs["Strength"].default_value = 0.9
    sc.world = world
    sun_data = bpy.data.lights.new("EF_Sun", "SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(8)
    sun = bpy.data.objects.new("EF_Sun", sun_data)
    sun.rotation_euler = (math.radians(50), math.radians(-10), math.radians(-35))
    sc.collection.objects.link(sun)
    cam_data = bpy.data.cameras.new("EF_PreviewCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("EF_PreviewCam", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def frame_camera(cam, ob):
    """3/4 front view from above (finished meshes face +Y); ortho scale fitted to the projected mesh."""
    direction = Vector((-0.75, 1.0, 0.62)).normalized()
    quat = (-direction).to_track_quat("-Z", "Y")
    cam.rotation_euler = quat.to_euler()
    right = quat @ Vector((1, 0, 0))
    up = quat @ Vector((0, 1, 0))
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    xs = [p.dot(right) for p in pts]
    ys = [p.dot(up) for p in pts]
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    cam.data.ortho_scale = span * 1.12
    centre = right * cx + up * cy
    depth = max(p.dot(direction) for p in pts)
    cam.location = centre + direction * (depth - centre.dot(direction) + 20)
    cam.data.clip_end = 1000


def render(cam, ob):
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.hide_render = o is not ob
    frame_camera(cam, ob)
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(RENDERS, ob.name + ".png")
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None, help="asset or category name (comma separated)")
    ap.add_argument("--no-render", action="store_true")
    args = ap.parse_args(sys.argv[1:] if "--" not in sys.argv else sys.argv[sys.argv.index("--") + 1:])

    for d in (EXPORT, OBJDIR, BLEND, RENDERS):
        os.makedirs(d, exist_ok=True)

    wanted = set(s.strip() for s in args.only.split(",")) if args.only else None
    manifest = {}
    if os.path.exists(MANIFEST_JSON):
        with open(MANIFEST_JSON) as fh:
            manifest = json.load(fh)

    failures = []
    t0 = time.time()
    for cat, items in categories().items():
        whole = wanted is None or cat in wanted
        todo = [(n, fn) for n, fn in items if whole or n in wanted]
        if not todo:
            continue
        reset()
        cam = setup_render_scene()
        coll = bpy.data.collections.new(cat)
        bpy.context.scene.collection.children.link(coll)
        built = []
        for name, fn in todo:
            t = time.time()
            try:
                b = Builder(name)
                fn(b)
                ob = b.finish(coll)
                tris = tri_count(ob)
                if tris > TRI_BUDGET:
                    failures.append(f"{name}: {tris} tris > {TRI_BUDGET}")
                export(ob)
                if not args.no_render:
                    render(cam, ob)
                w, h, d = dims_studs(ob)
                manifest[name] = {
                    "category": cat,
                    "tris": tris,
                    "studs": [round(w, 2), round(h, 2), round(d, 2)],
                    "materials": [m.name for m in ob.data.materials],
                }
                built.append(ob)
                print(f"[build] {cat}/{name}: {tris} tris, {w:.1f} x {h:.1f} x {d:.1f} studs ({time.time() - t:.1f}s)")
            except Exception as exc:  # keep going; report at the end
                import traceback

                traceback.print_exc()
                failures.append(f"{name}: {exc}")

        if whole and built:
            # lay the editable scene out in a row and save it
            x = 0.0
            for ob in built:
                w = ob.dimensions.x
                ob.location.x = x + w / 2
                x += w + 2.0
            for o in bpy.context.scene.objects:
                o.hide_render = False
            path = os.path.join(BLEND, cat + ".blend")
            bpy.context.preferences.filepaths.save_version = 0  # no .blend1 backups
            bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
            print(f"[build] saved {os.path.relpath(path, ROOT)}")

    with open(MANIFEST_JSON, "w") as fh:
        json.dump(dict(sorted(manifest.items())), fh, indent=1)
    print(f"[build] done in {time.time() - t0:.0f}s; {len(manifest)} assets in manifest")
    if failures:
        print("[build] FAILURES:\n  " + "\n  ".join(failures))
        sys.exit(1)


if __name__ == "__main__":
    main()
