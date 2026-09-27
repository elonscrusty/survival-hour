"""Build every Survival Hour asset, export it for Roblox and render previews.

Run with Blender:
    blender --background --python blender/build_all.py
or with the `bpy` Python module (pip install bpy, Python 3.11):
    python blender/build_all.py

Add `-- --no-render` (Blender) or `--no-render` (Python) to skip previews.

Outputs (relative to the repo root):
    models/fbx/<Name>.fbx               one file per asset, texture embedded
    models/textures/survival_palette.png
    models/survival_hour_assets.blend   all assets laid out for editing
    renders/<Name>.png, renders/contact_sheet.png
"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import assets  # noqa: E402
import lowpoly  # noqa: E402

ROOT = os.path.dirname(HERE)
FBX_DIR = os.path.join(ROOT, "models", "fbx")
TEX_PATH = os.path.join(ROOT, "models", "textures", "survival_palette.png")
BLEND_PATH = os.path.join(ROOT, "models", "survival_hour_assets.blend")
RENDER_DIR = os.path.join(ROOT, "renders")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def export_fbx(obj, path):
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        path_mode="COPY",
        embed_textures=True,
        bake_anim=False,
    )


def triangle_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# --- Rendering ---------------------------------------------------------------

def setup_render(scene):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    try:
        scene.cycles.use_denoising = True
    except AttributeError:
        pass
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"  # show palette colours as-is

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.65, 0.8, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(45), math.radians(10), math.radians(35))
    scene.collection.objects.link(sun)

    ground = bpy.data.meshes.new("Ground")
    ground.from_pydata([(-500, -500, 0), (500, -500, 0), (500, 500, 0), (-500, 500, 0)],
                       [], [(0, 1, 2, 3)])
    ground_obj = bpy.data.objects.new("ShadowCatcher", ground)
    ground_obj.is_shadow_catcher = True
    scene.collection.objects.link(ground_obj)

    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.type = "ORTHO"
    cam.data.clip_end = 2000
    scene.collection.objects.link(cam)
    scene.camera = cam
    return ground_obj


def frame_camera(cam, objs):
    corners = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector([min(c[i] for c in corners) for i in range(3)])
    hi = Vector([max(c[i] for c in corners) for i in range(3)])
    center = (lo + hi) / 2
    direction = Vector((1.0, -1.3, 0.9)).normalized()
    rot = (-direction).to_track_quat("-Z", "Y")
    inv = rot.to_matrix().inverted()
    extent = 0.0
    for c in corners:
        p = inv @ (c - center)
        extent = max(extent, abs(p.x), abs(p.y))
    cam.rotation_euler = rot.to_euler()
    cam.location = center + direction * (extent * 4 + 50)
    cam.data.ortho_scale = extent * 2 * 1.12


def render_all(scene, objs):
    os.makedirs(RENDER_DIR, exist_ok=True)
    ground = setup_render(scene)
    for obj in objs:
        ground.location.z = obj.location.z = 0
        for o in objs:
            o.hide_render = o is not obj
        frame_camera(scene.camera, [obj])
        scene.render.filepath = os.path.join(RENDER_DIR, obj.name + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", obj.name)
    make_contact_sheet([o.name for o in objs])


def make_contact_sheet(names, cols=5, cell=256):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("Pillow not installed; skipping contact sheet")
        return
    rows = math.ceil(len(names) / cols)
    label_h = 28
    sheet = Image.new("RGB", (cols * cell, rows * (cell + label_h)), (46, 58, 50))
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(names):
        x, y = (i % cols) * cell, (i // cols) * (cell + label_h)
        draw.rectangle([x + 6, y + 6, x + cell - 6, y + cell - 6], fill=(214, 224, 206))
        img = Image.open(os.path.join(RENDER_DIR, name + ".png")).convert("RGBA")
        img = img.resize((cell - 16, cell - 16), Image.LANCZOS)
        sheet.paste(img, (x + 8, y + 8), img)
        draw.text((x + 10, y + cell + 6), name, fill=(240, 240, 230))
    sheet.save(os.path.join(RENDER_DIR, "contact_sheet.png"))


# --- Main --------------------------------------------------------------------

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    do_render = "--no-render" not in argv

    scene = reset_scene()
    scene.unit_settings.system = "NONE"  # 1 unit = 1 stud
    os.makedirs(FBX_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(TEX_PATH), exist_ok=True)

    image = lowpoly.make_palette_image(TEX_PATH)
    material = lowpoly.make_palette_material(image)

    objs = []
    print(f"{'asset':<12} {'tris':>6}")
    for name in assets.ASSETS:
        obj = assets.make(name).build(material, scene.collection)
        export_fbx(obj, os.path.join(FBX_DIR, name + ".fbx"))
        print(f"{name:<12} {triangle_count(obj):>6}")
        objs.append(obj)

    if do_render:
        render_all(scene, objs)
        for o in objs:
            o.hide_render = False
        for o in list(scene.objects):
            if o.type != "MESH" or o.name == "ShadowCatcher":
                bpy.data.objects.remove(o)

    # Lay everything out in a row for the editable .blend file.
    x = 0.0
    for obj in objs:
        min_x = min(c[0] for c in obj.bound_box)
        obj.location.x = x - min_x
        x += obj.dimensions.x + 3
    image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH, compress=True)


if __name__ == "__main__":
    main()
