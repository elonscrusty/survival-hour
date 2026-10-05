"""Render a preview video of the pet animations (the same maths as the game).

    python3 blender/animate.py [--samples 8] [--seconds 9]

Writes models/storeart/PetAnimations.mp4 (needs ffmpeg). The pets idle (breathe,
look around, wag, twitch ears), break into a gallop down the track with riders on
their backs, leap and squash on landing, then hop happily at the finish.
PetAnim below is a line-for-line port of src/shared/Logic/PetAnim.luau.
"""
import argparse
import math
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import build as B  # noqa: E402
import storeart as A  # noqa: E402

OUT = os.path.join(B.OUT, "storeart")
FPS = 24
sin = math.sin


def clamp(x, a, b):
    return max(a, min(b, x))


def cycle_speed(run):
    return 4 + 9 * clamp(run, 0, 1)


def sample(s, t, phase):
    """Port of PetAnim.Sample: {joint: (rx, ry, rz, x, y, z)} in Roblox axes."""
    run, air, land, happy = (clamp(s[k], 0, 1) for k in ("Run", "Air", "Land", "Happy"))
    ground = 1 - air
    idle = (1 - run) * ground
    k = max(s["Size"], 1) / 4
    p = {}
    p["Body"] = (
        0.07 * sin(phase * 2) * run * ground - 0.16 * air + 0.12 * land,
        0,
        0.05 * sin(phase) * run * ground + 0.06 * sin(t * 9) * happy,
        0,
        (0.05 * sin(t * 2.2) * idle + 0.32 * abs(sin(phase)) * run * ground - 0.3 * land + 0.7 * abs(sin(t * 9)) * happy) * k,
        -0.08 * run * k,
    )
    p["Head"] = (
        0.06 * sin(t * 2.2 + 0.7) * idle - 0.1 * sin(phase * 2 + 0.6) * run * ground + 0.12 * air - 0.15 * land,
        s["Look"] * idle,
        0.18 * sin(t * 4.5) * happy + 0.05 * sin(t * 0.9) * idle,
        0, 0, 0,
    )
    for i, j in ((1, "EarL"), (2, "EarR")):
        side = 1 if i == 1 else -1
        twitch = max(0.0, sin(t * 1.3 + i * 2.1)) ** 12
        p[j] = (0.45 * run + 0.25 * air - 0.2 * land, 0,
                side * (0.12 * twitch * idle + 0.1 * sin(phase * 2) * run + 0.25 * land + 0.2 * sin(t * 9 + i) * happy), 0, 0, 0)
    p["Tail"] = (-0.35 * run - 0.2 * air + 0.1 * sin(t * 2.2) * idle,
                 0.35 * sin(t * 4) * idle + 0.25 * sin(phase) * run + 0.6 * sin(t * 15) * happy, 0, 0, 0, 0)
    for i, j in ((1, "WingL"), (2, "WingR")):
        side = 1 if i == 1 else -1
        p[j] = (0, side * 0.15 * run,
                side * (0.08 * sin(t * 1.8) * idle + 0.55 * sin(phase * 2) * run * ground + (0.75 + 0.45 * sin(t * 14)) * air + 0.5 * sin(t * 12) * happy), 0, 0, 0)
    for j, ph in (("LegFL", 0), ("LegBR", 0), ("LegFR", math.pi), ("LegBL", math.pi)):
        front = j[3] == "F"
        swing = sin(phase + ph)
        p[j] = (0.85 * swing * run * ground + (-0.75 if front else 0.65) * air + 0.15 * sin(t * 9 + ph) * happy, 0,
                (1 if j[4] == "L" else -1) * 0.12 * land, 0, max(0.0, -sin(phase + ph)) * 0.22 * run * ground * k, 0)
    return p


def smooth(a, b, t, t0, t1):
    if t <= t0:
        return a
    if t >= t1:
        return b
    x = (t - t0) / (t1 - t0)
    return a + (b - a) * x * x * (3 - 2 * x)


def timeline(t, total):
    """Story: idle, gallop (with a leap), slow down, happy hops."""
    run = smooth(0, 1, t, 1.6, 2.4) if t < total - 2.6 else smooth(1, 0, t, total - 2.6, total - 2.0)
    jump_t0, jump_len = 4.3, 0.75
    jt = (t - jump_t0) / jump_len
    air = clamp(math.sin(jt * math.pi) * 1.6, 0, 1) if 0 <= jt <= 1 else 0
    height = 4.5 * math.sin(jt * math.pi) if 0 <= jt <= 1 else 0
    land = clamp(1 - (t - (jump_t0 + jump_len)) * 4, 0, 1) if t >= jump_t0 + jump_len else 0
    happy = smooth(0, 1, t, total - 1.9, total - 1.5)
    return run, air, land, happy, height


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples", type=int, default=8)
    ap.add_argument("--seconds", type=float, default=9)
    args = ap.parse_args(argv)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    frames_dir = os.path.join(OUT, "_frames")
    shutil.rmtree(frames_dir, ignore_errors=True)
    os.makedirs(frames_dir, exist_ok=True)

    species = {sp["Id"]: sp for sp in B.lua_species()}
    pets = [B.build_pet(sp) for sp in B.lua_species()]
    rest = [B.build_egg(eid, c) for eid, c in B.lua_eggs()] + B.build_props()
    rest += [A.build_rider(i, s, p) for i, (s, p) in enumerate(A.RIDERS)] + [A.build_track_strip()]
    meshes = {}
    for m in pets + rest:
        obj, rec = m.finish()
        meshes[rec["name"]] = (m, obj)
    pal = os.path.join(OUT, "_palette.png")
    B.write_palette(pal)
    mat = B.make_material(pal)
    for _, obj in meshes.values():
        obj.data.materials.append(mat)

    cam = B.setup_render(args.samples, 1.6)
    sc = bpy.context.scene
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 960, 540
    coll = sc.collection
    A.ground()

    def static(name, x, z, yaw=0.0, scale=1.0, y=0.0):
        me = meshes[name][1].data
        o = bpy.data.objects.new(name, me)
        o.location = A.to_blender(x, y, z)
        o.rotation_euler = (0, 0, math.radians(-yaw))
        o.scale = (scale,) * 3
        coll.objects.link(o)
        return o

    # The track runs toward -Z (the way pets face). Scenery along both sides.
    for i in range(6):
        static("ArtTrack", 0, -i * 140 + 40, y=0.06)
    for i in range(14):
        z = 30 - i * 30
        static("Tree_Pine" if i % 2 else "Tree_Round", -30, z, 0, 1.5)
        static("Tree_Blossom" if i % 3 == 0 else "Tree_Round", 30, z - 15, 0, 1.5)
        if i % 4 == 1:
            static("RaceArch", 0, z, 0, 1.15)
    static("Cloud", -60, -200, 0, 2, y=60)
    static("Cloud", 70, -320, 0, 2, y=70)

    # Five pets in a line, two with riders. Each pet: its mesh skinned to its own rig.
    lineup = [("Pup", -11, None), ("Unicorn", -5.5, 1), ("Dragon", 0.5, 0), ("Bunny", 6.5, None), ("Cosmic Cat", 12, 2)]
    actors = []
    for i, (pid, x, rider) in enumerate(lineup):
        m, obj = meshes[B.model_name(pid)]
        coll.objects.link(obj)
        rig = m.make_armature(obj, coll)
        rig.location = A.to_blender(x, 0, 0)
        for pb in rig.pose.bones:
            pb.rotation_mode = "ZYX"  # = Roblox CFrame.Angles order
        if rider is not None:
            sp = species[pid]
            r = bpy.data.objects.new(f"Rider{rider}", meshes[f"Rider{rider}"][1].data)
            coll.objects.link(r)
            back = sp["Legs"] + sp["Body"][1]
            seat_z = (sp["Body"][2] + sp["Head"] * 0.3) * 0.12
            body_y = sp["Legs"] + sp["Body"][1] / 2
            r.parent = rig
            r.parent_type = "BONE"
            r.parent_bone = "Body"
            # bone-parented children are placed relative to the bone's tail
            # (bone space: X, Y = up, Z = Roblox -Z; the rider mesh is Blender Z-up, so
            # turn it -90 degrees about X to stand it up in bone space)
            r.location = (0, back - 0.35 - body_y - 0.4, -seat_z)
            r.rotation_euler = (math.radians(-90), 0, 0)
            r.scale = (0.95,) * 3
        actors.append({"rig": rig, "x": x, "phase": i * 1.3, "seed": i * 37.0, "size": species[pid]["Legs"] + species[pid]["Body"][1]})

    total = args.seconds
    nframes = int(total * FPS)
    dist = 0.0
    for f in range(nframes):
        t = f / FPS
        run, air, land, happy, height = timeline(t, total)
        speed = 30 * run
        dist += speed / FPS
        for a in actors:
            a["phase"] += cycle_speed(run) / FPS
            look = 0.45 * sin(t * 0.8 + a["seed"])
            pose = sample({"Run": run, "Air": air, "Land": land, "Happy": happy, "Look": look, "Size": a["size"]}, t + a["seed"], a["phase"])
            rig = a["rig"]
            rig.location = A.to_blender(a["x"], height, -dist)
            for name, (rx, ry, rz, x, y, z) in pose.items():
                pb = rig.pose.bones.get(name)
                if pb:
                    # Roblox axes -> bone axes: (-X, Y, -Z), see PetAnimator.BONE_AXIS
                    pb.rotation_euler = (-rx, ry, -rz)
                    pb.location = (-x, y, -z)
        # Camera: low and ahead of the pack, looking back at them as they charge.
        target = Vector(A.to_blender(0, 4 + height * 0.3, -dist))
        cam.location = Vector(A.to_blender(6 + 2 * sin(t * 0.4), 6.5, -dist - 30))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 34
        sc.render.filepath = os.path.join(frames_dir, f"f{f:04d}.png")
        bpy.ops.render.render(write_still=True)
        print(f"frame {f + 1}/{nframes}", flush=True)
    os.remove(pal)
    out = os.path.join(OUT, "PetAnimations.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(frames_dir, "f%04d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-movflags", "+faststart", out], check=True)
    shutil.rmtree(frames_dir, ignore_errors=True)
    print("wrote", out)


if __name__ == "__main__":
    main()
