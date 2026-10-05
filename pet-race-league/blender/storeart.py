"""Render the game icon and store thumbnails from the real models.

    python3 blender/storeart.py [--samples 24]

Writes models/storeart/Icon.png (512x512) and Thumb1..3.png (1920x1080), ready to
upload on the Creator Dashboard (experience icon / thumbnails). Uses the same
bright toon look as the model previews: true colours, blue sky, black outlines.
"""
import argparse
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import build as B  # noqa: E402
from build import T, S, Rx  # noqa: E402

OUT = os.path.join(B.OUT, "storeart")
SKIN = (255, 205, 150)
RIDERS = [((255, 70, 90), (40, 90, 200)), ((60, 200, 255), (60, 60, 80)), ((255, 200, 40), (90, 60, 160)), ((120, 230, 90), (40, 60, 120))]


def build_rider(i, shirt, pants):
    """A generic blocky rider in a sitting pose. Pivot = the seat (bottom of the hips)."""
    m = B.Mesh(f"Rider{i}", "Art")
    m.box(pants, T(0, 0.5, 0) @ S(2, 1, 1), 0.08)  # hips
    for side in (-0.5, 0.5):
        m.box(pants, T(side, 0.5, -1.0) @ S(1, 1, 2), 0.08)  # thighs forward
        m.box(pants, T(side, -0.5, -1.6) @ S(1, 1.8, 1), 0.08)  # shins down
        m.box((60, 50, 50), T(side, -1.45, -1.75) @ S(1, 0.4, 1.3), 0.08)  # shoes
    m.box(shirt, T(0, 2.0, 0) @ S(2, 2, 1), 0.1)  # torso
    for side in (-1.5, 1.5):  # arms reaching forward to hold on
        m.box(shirt, T(side, 2.45, -0.5) @ Rx(55) @ S(1, 1.1, 1), 0.08)
        m.box(SKIN, T(side, 2.0, -1.45) @ Rx(80) @ S(1, 1.2, 1), 0.08)
    m.box(SKIN, T(0, 3.75, 0) @ S(1.25, 1.25, 1.25), 0.25)  # head
    for side in (-0.25, 0.25):
        m.box((30, 30, 40), T(side, 3.9, -0.64) @ S(0.16, 0.26, 0.05))
    for k in range(5):
        x = -0.24 + k * 0.12
        m.box((30, 30, 40), T(x, 3.5 - 0.06 * (1 - ((k - 2) / 2) ** 2), -0.64) @ S(0.13, 0.06, 0.05))
    return m


def build_track_strip():
    m = B.Mesh("ArtTrack", "Art")
    m.box((255, 205, 130), T(0, -0.5, 0) @ S(34, 1, 140))
    for side in (-1, 1):
        for i in range(14):
            c = (255, 255, 255) if i % 2 == 0 else (255, 80, 110)
            m.box(c, T(side * 16.5, 0.6, -65 + i * 10) @ S(1, 1.2, 10), 0.1)
    for i in range(4):  # boost arrows
        m.box((255, 220, 40), T(-4, 0.05, -18 + i * 6) @ S(6, 0.1, 2.2))
        m.box((255, 220, 40), T(4, 0.05, -18 + i * 6) @ S(6, 0.1, 2.2))
    return m


def build_stars():
    m = B.Mesh("ArtStars", "Art")
    rng = random.Random(4)
    for _ in range(40):
        p = (rng.uniform(-14, 14), rng.uniform(2, 14), rng.uniform(-6, 6))
        m.sphere((255, 240, 120) if rng.random() < 0.6 else (255, 255, 255), T(p) @ S(rng.uniform(0.15, 0.4)), 6, 4)
    return m


def to_blender(x, y, z):
    return Vector((-x, z, y))


def place(meshes, name, x, z, yaw=0.0, scale=1.0, y=0.0):
    obj = bpy.data.objects.new(name, meshes[name])
    obj.location = to_blender(x, y, z)
    obj.rotation_euler = (0, 0, math.radians(-yaw))
    obj.scale = (scale, scale, scale)
    bpy.context.scene.collection.objects.link(obj)
    return obj


SPECIES = {sp["Id"].replace(" ", ""): sp for sp in B.lua_species()}


def ridden(meshes, pet, rider, x, z, yaw=0.0, y=0.0):
    """A pet with a rider sitting on its back (same seat maths as PetService.mount)."""
    sp = SPECIES[pet]
    bx, by, bz = sp["Body"]
    back = sp["Legs"] + by
    seat_z = (bz + sp["Head"] * 0.3) * 0.12
    place(meshes, "Pet_" + pet, x, z, yaw, 1.0, y)
    a = math.radians(yaw)
    # rotate the seat offset (pet-space +Z) by the pet's yaw
    rx, rz = -seat_z * math.sin(a), seat_z * math.cos(a)
    place(meshes, rider, x + rx, z + rz, yaw, 0.95, y + back - 0.35)


def ground(color=(0.3, 0.82, 0.22), size=600):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    g = bpy.context.active_object
    mat = bpy.data.materials.new("Grass")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 0.8
    g.data.materials.append(mat)


def camera(loc, target, lens=40):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = lens
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam


def clear_scene():
    for o in list(bpy.context.scene.collection.objects):
        if o.type in ("MESH", "CAMERA"):
            bpy.data.objects.remove(o)


def shot(path, w, h, outline):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.line_thickness = outline
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("wrote", path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples", type=int, default=24)
    ap.add_argument("--icon-only", action="store_true")
    args = ap.parse_args(argv)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    # Same build order as build.py first, so palette cells match; then the art-only meshes.
    built = [B.build_pet(sp) for sp in B.lua_species()]
    built += [B.build_egg(eid, c) for eid, c in B.lua_eggs()]
    built += B.build_props()
    built += [build_rider(i, s, p) for i, (s, p) in enumerate(RIDERS)]
    built += [build_track_strip(), build_stars()]
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

    # Icon: a Dragon leaping toward you with its rider, a Unicorn racing behind.
    ground()
    ridden(meshes, "Dragon", "Rider0", 0, 0, -22, y=0.4)
    ridden(meshes, "Unicorn", "Rider1", -8, 10, 20)
    place(meshes, "Egg_Sky", 9, 11, -20, 1.0)
    place(meshes, "Tree_Round", -14, 26, 0, 1.3)
    place(meshes, "Tree_Blossom", 13, 28, 0, 1.3)
    camera(to_blender(2.5, 7.2, -15.5), to_blender(0, 6.0, 0), 36)
    shot(os.path.join(OUT, "Icon.png"), 512, 512, 1.3)
    if args.icon_only:
        os.remove(pal)
        return

    # Thumb 1: a race, four ridden pets charging down the track under the arch.
    clear_scene()
    ground()
    place(meshes, "ArtTrack", 0, 30, 0, 1.0, y=0.06)
    place(meshes, "RaceArch", 0, 6, 0, 1.15)
    for i, (pet, z, x) in enumerate((("Tiger", 0, -9), ("Phoenix", -6, -1.5), ("Wolf", 3, 6), ("Fox", 8, 12))):
        ridden(meshes, pet, f"Rider{i}", x, z, (-8, 4, -4, 10)[i], y=0.6 if i == 1 else 0)
    for x in (-30, 30):
        place(meshes, "Tree_Pine", x, 20, 0, 1.6)
        place(meshes, "Tree_Round", x * 1.2, 45, 0, 1.6)
    place(meshes, "Cloud", -40, 120, 0, 1.6, y=45)
    place(meshes, "Cloud", 45, 140, 0, 1.4, y=55)
    camera(to_blender(4, 5, -34), to_blender(1, 5, 8), 30)
    shot(os.path.join(OUT, "Thumb1.png"), 1920, 1080, 2.4)

    # Thumb 2: egg stands with freshly hatched pets.
    clear_scene()
    ground()
    for i, e in enumerate(["Egg_Meadow", "Egg_Forest", "Egg_Sky"]):
        x = -16 + i * 16
        place(meshes, "Pedestal", x, 10, 0, 1.0)
        place(meshes, e, x, 10, 15 * (i - 1), 1.0, y=2.8)
    ridden(meshes, "Panda", "Rider2", -10, -3, 25)
    for n, x, z, yaw in (("Pet_CosmicCat", 0, -6, 0), ("Pet_Penguin", 9, -3, -20), ("Pet_Bunny", 17, 1, -35), ("Pet_Piggy", -18, 2, 30)):
        place(meshes, n, x, z, yaw, 1.0)
    for x, z in ((-6, -12), (12, -11), (-20, -8)):
        place(meshes, "Flowers", x, z, 0, 1.2)
    place(meshes, "Tree_Blossom", -32, 24, 0, 1.4)
    place(meshes, "Tree_Round", 32, 24, 0, 1.4)
    camera(to_blender(0, 9, -36), to_blender(0, 5, 4), 28)
    shot(os.path.join(OUT, "Thumb2.png"), 1920, 1080, 2.4)

    # Thumb 3: the whole collection in front of the race portal.
    clear_scene()
    ground()
    pets = sorted(n for n in meshes if n.startswith("Pet_"))
    for i, n in enumerate(pets):
        row, col = divmod(i, 5)
        place(meshes, n, -20 + col * 10 + row * 2.5, row * 9, (col - 2) * -8, 1.0)
    place(meshes, "PortalArch", 0, 38, 0, 1.2)
    place(meshes, "TrophyStatue", -34, 30, 20, 1.5)
    place(meshes, "TrophyStatue", 34, 30, -20, 1.5)
    camera(to_blender(0, 20, -48), to_blender(0, 7, 14), 30)
    shot(os.path.join(OUT, "Thumb3.png"), 1920, 1080, 2.4)
    os.remove(pal)


if __name__ == "__main__":
    main()
