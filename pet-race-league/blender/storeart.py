"""Render the game icon and store thumbnails from the real models.

    python3 blender/marketing.py [--samples 24]

Writes models/storeart/Icon.png (512x512) and Thumb1..3.png (1920x1080), ready to
upload on the Creator Dashboard (Places → Thumbnails / Experience icon).
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import build as B  # noqa: E402

OUT = os.path.join(B.OUT, "storeart")


def to_blender(x, y, z):
    return Vector((-x, z, y))


def place(meshes, name, x, z, yaw=0.0, scale=1.0, y=0.0):
    """Adds a copy of model `name` with its feet at Roblox (x, y, z), turned yaw degrees."""
    me = meshes[name]
    obj = bpy.data.objects.new(name, me)
    obj.location = to_blender(x, y, z)
    obj.rotation_euler = (0, 0, math.radians(-yaw))
    obj.scale = (scale, scale, scale)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def ground(color=(0.35, 0.72, 0.3), size=400):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    g = bpy.context.active_object
    mat = bpy.data.materials.new("Grass")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    g.data.materials.append(mat)
    return g


def camera(loc, target, lens=40):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = lens
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def clear_scene():
    for o in list(bpy.context.scene.collection.objects):
        if o.type in ("MESH", "CAMERA"):
            bpy.data.objects.remove(o)


def shot(path, w, h):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("wrote", path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples", type=int, default=24)
    args = ap.parse_args(argv)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    built = [B.build_pet(sp) for sp in B.lua_species()]
    built += [B.build_egg(eid, c) for eid, c in B.lua_eggs()]
    built += B.build_props()
    meshes = {}
    for m in built:
        obj, rec = m.finish()
        meshes[rec["name"]] = obj.data
        bpy.data.objects.remove(obj)
    pal = os.path.join(OUT, "_palette.png")
    B.write_palette(pal)
    mat = B.make_material(pal)
    for me in meshes.values():
        me.materials.append(mat)

    B.setup_render(args.samples)
    sc = bpy.context.scene
    sc.cycles.use_denoising = True
    for o in list(sc.collection.objects):
        if o.type == "CAMERA":
            bpy.data.objects.remove(o)
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.78, 1.0, 1)
    sc.world.node_tree.nodes["Background"].inputs[1].default_value = 1.1

    # Icon: Dragon, Unicorn and Pup in front of a Sky egg.
    ground()
    place(meshes, "Egg_Sky", 0, 6, 20, 1.3)
    place(meshes, "Pet_Dragon", -4.5, 0, 35, 0.9)
    place(meshes, "Pet_Unicorn", 4.2, -0.5, -30, 1.0)
    place(meshes, "Pet_Pup", 0, -4.5, 5, 1.3)
    place(meshes, "Tree_Round", -12, 14, 0, 1.2)
    place(meshes, "Tree_Blossom", 12, 13, 0, 1.2)
    camera(to_blender(0, 6.5, -24), to_blender(0, 4, 2), 42)
    shot(os.path.join(OUT, "Icon.png"), 512, 512)

    # Thumb 1: the race start, pets lined up under the arch.
    clear_scene()
    ground((0.42, 0.78, 0.35))
    place(meshes, "RaceArch", 0, 4, 0, 1.0)
    lineup = ["Pet_Fox", "Pet_Tiger", "Pet_Phoenix", "Pet_Wolf", "Pet_Bunny"]
    for i, n in enumerate(lineup):
        place(meshes, n, -10 + i * 5, -2 + (i % 2) * 1.5, 0, 1.0)
    for x in (-24, 24):
        place(meshes, "Tree_Pine", x, 12, 0, 1.3)
    place(meshes, "Pillar", 18, 24, 90, 0.6)
    place(meshes, "Cloud", -20, 60, 0, 1.2, y=28)
    place(meshes, "Cloud", 25, 70, 0, 1.0, y=34)
    camera(to_blender(4, 9, -44), to_blender(0, 7, 4), 30)
    shot(os.path.join(OUT, "Thumb1.png"), 1920, 1080)

    # Thumb 2: egg stands with freshly hatched pets.
    clear_scene()
    ground()
    for i, e in enumerate(["Egg_Meadow", "Egg_Forest", "Egg_Sky"]):
        x = -14 + i * 14
        place(meshes, "Pedestal", x, 6, 0, 1.0)
        place(meshes, e, x, 6, 15 * (i - 1), 1.0, y=2.8)
    for n, x, z, yaw in (("Pet_Panda", -9, -4, 20), ("Pet_CosmicCat", 0, -6, 0), ("Pet_Penguin", 8, -4, -25), ("Pet_Kitty", 15, -1, -40), ("Pet_Piggy", -16, -1, 35)):
        place(meshes, n, x, z, yaw, 1.0)
    place(meshes, "Flowers", -6, -10, 0, 1.0)
    place(meshes, "Flowers", 11, -9, 0, 1.0)
    camera(to_blender(0, 8, -30), to_blender(0, 4, 2), 30)
    shot(os.path.join(OUT, "Thumb2.png"), 1920, 1080)

    # Thumb 3: the whole collection.
    clear_scene()
    ground((0.45, 0.8, 0.38))
    pets = [n for n in meshes if n.startswith("Pet_")]
    for i, n in enumerate(pets):
        row, col = divmod(i, 5)
        place(meshes, n, -16 + col * 8 + row * 2, row * 7, 0, 1.0)
    place(meshes, "PortalArch", 0, 30, 0, 1.0)
    place(meshes, "TrophyStatue", -30, 34, 20, 1.3)
    camera(to_blender(0, 22, -48), to_blender(0, 8, 14), 30)
    shot(os.path.join(OUT, "Thumb3.png"), 1920, 1080)
    os.remove(pal)


if __name__ == "__main__":
    main()
