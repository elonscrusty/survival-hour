"""Sample scenes built from instances of the exported assets:
assembled team camp (day + night), forest clearing, lobby layout."""

import math
import os

import bpy
from mathutils import Matrix, Vector

from sh import pipeline as P
from sh import reference


class SceneBuilder:
    def __init__(self, ctx, name):
        self.ctx = ctx
        self.col = ctx.collection("Scene_" + name)
        self.objs = []

    def put(self, name, loc, rz=0.0, rx=0.0):
        src = self.ctx.objects.get(name)
        if src is None:
            print("scene: missing", name)
            return None
        o = src.copy()
        self.col.objects.link(o)
        o.parent = None
        o.matrix_world = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.radians(rz), 4, "Z") @ \
            Matrix.Rotation(math.radians(rx), 4, "X")
        o.hide_render = False
        self.objs.append(o)
        base = o.matrix_world.copy()
        for p in list(src.users_collection[0].objects):
            if p.get("sh_part_of") == name:
                q = p.copy()
                self.col.objects.link(q)
                q.matrix_world = base @ p.matrix_world
                q.hide_render = False
                self.objs.append(q)
        return o

    def rig(self, name, loc, rz=0.0, clip="Idle", frame=0):
        arm = self.ctx.objects.get(name)
        if arm is None:
            return
        mesh = [c for c in arm.children if c.type == "MESH"][0]
        a2 = arm.copy()
        m2 = mesh.copy()
        self.col.objects.link(a2)
        self.col.objects.link(m2)
        m2.parent = a2
        m2.modifiers["Armature"].object = a2
        a2.location = loc
        a2.rotation_euler = (0, 0, math.radians(rz))
        acts = [a for a in bpy.data.actions if a.name == f"A_{name[3:]}_{clip}"]
        if acts:
            a2.animation_data.action = acts[0]
        self.objs += [a2, m2]

    def ring_walls(self, R_apothem, n, names, gate_index, rot0=0.0):
        for k in range(n):
            th = math.radians(rot0 + k * 360 / n)
            pos = (math.cos(th) * R_apothem, math.sin(th) * R_apothem, 0)
            name = "SM_Gate" if k == gate_index else names[k % len(names)]
            self.put(name, pos, math.degrees(th) + 90)


def glow_material():
    m = bpy.data.materials.get("M_Preview_Glow")
    if m:
        return m
    m = bpy.data.materials.new("M_Preview_Glow")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1.0, 0.45, 0.12, 1)
    em.inputs["Strength"].default_value = 12
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def scatter(sb, rng, names, n, rmin, rmax, center=(0, 0), avoid=None):
    for i in range(n):
        for _ in range(20):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(rmin, rmax)
            p = (center[0] + math.cos(a) * r, center[1] + math.sin(a) * r)
            if not avoid or all(math.hypot(p[0] - q[0], p[1] - q[1]) > d for q, d in avoid):
                break
        sb.put(names[i % len(names)], (p[0], p[1], 0), rng.uniform(0, 360))


def camera(ctx, loc, target, lens=30, res=(1600, 900)):
    s = bpy.context.scene
    s.render.resolution_x, s.render.resolution_y = res
    cam = ctx.renderer.cam
    cam.data.type = "PERSP"
    cam.data.lens = lens
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def render_scene(ctx, sb, path, film_transparent=False):
    r = ctx.renderer
    s = bpy.context.scene
    s.render.film_transparent = film_transparent
    vis = set(sb.objs)
    for o in s.objects:
        if o in r.fixed:
            continue
        o.hide_render = o not in vis
    os.makedirs(os.path.dirname(path), exist_ok=True)
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)
    s.render.film_transparent = True
    return P.rel(path)


def ground(sb, size=400, mat_name="forest_floor"):
    """Big flat ground plane (preview only, not exported)."""
    me = bpy.data.meshes.new("PreviewGround")
    me.from_pydata([(-size, -size, -0.02), (size, -size, -0.02), (size, size, -0.02), (-size, size, -0.02)], [],
                   [(0, 1, 2, 3)])
    mat = bpy.data.materials.get("M_PreviewGround")
    if not mat:
        mat = bpy.data.materials.new("M_PreviewGround")
        mat.use_nodes = True
        b = mat.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (0.13, 0.14, 0.07, 1)
        b.inputs["Roughness"].default_value = 1.0
    me.materials.append(mat)
    o = bpy.data.objects.new("PreviewGround_" + sb.col.name, me)
    sb.col.objects.link(o)
    sb.objs.append(o)


@P.asset("Scene_Camp", "Scenes", "Reference")
def scene_camp(ctx):
    if not ctx.renderer:
        return []
    import random
    rng = random.Random(7)
    sb = SceneBuilder(ctx, "Camp")
    ground(sb)
    sb.put("SM_Clearing_GroundPatch", (0, 0, 0))
    sb.put("SM_Campfire_Burning", (0, 0, 0))
    flames = sb.put("SM_Campfire_Flames", (0, 0, 0))
    sb.put("SM_Workbench_Level01", (0, 8, 0))
    sb.put("SM_StorageBox", (-6.5, 6.5, 0), 30)
    sb.put("SM_Camp_LogBench", (-5, -2.5, 0), 70)
    sb.put("SM_Camp_LogBench", (5, -2.5, 0), -70)
    sb.put("SM_Camp_FirewoodStack", (6.5, 6.5, 0), -30)
    sb.put("SM_Camp_Bedroll", (-9, -1, 0), 80)
    sb.put("SM_Camp_Bedroll", (-9.5, 3, 0), 95)
    sb.put("SM_Camp_Lantern", (-4, 10.5, 0))
    sb.put("SM_Camp_DryingRack", (9.5, 0, 0), 90)
    sb.put("SM_Camp_TeamBanner", (3.5, 11, 0))
    sb.put("SM_Watchtower", (8.5, 8.5, 0), -45)
    walls = ["SM_WoodenWall"] * 8 + ["SM_ReinforcedWall"] * 3
    sb.ring_walls(14.93, 12, walls, gate_index=9, rot0=0)
    for k, ang in enumerate((255, 285)):
        th = math.radians(ang)
        sb.put("SM_Spikes", (math.cos(th) * 19.5, math.sin(th) * 19.5, 0), ang + 90)
    # players (team of four) + one holding the stone axe
    for k, (x, y, rz) in enumerate(((-2.5, -5, 20), (2.5, -5.5, -25), (-1, 4.5, 180))):
        sb.put("SH_Dummy", (x, y, 0), rz)
    sb.put("SH_Dummy_Hold", (3.5, 4, 0), 200)
    g = reference.hold_grip()
    rot = Matrix.Rotation(math.radians(200), 4, "Z")
    p = rot @ g
    sb.put("SM_StoneAxe", (3.5 + p.x, 4 + p.y, p.z), 200)
    trees = ["SM_Tree_Pine_Medium01", "SM_Tree_Pine_Medium02", "SM_Tree_Oak_Medium01", "SM_Tree_Birch_Medium01",
             "SM_Tree_Pine_Large01", "SM_Tree_Oak_Medium02", "SM_Tree_Pine_Small01", "SM_Tree_Birch_Small01"]
    scatter(sb, rng, trees, 26, 24, 50)
    scatter(sb, rng, ["SM_Bush01", "SM_Bush02", "SM_Fern01", "SM_Grass_Clump01", "SM_Grass_Clump03",
                      "SM_Rock_Small02", "SM_Boulder03", "SM_FiberPlant01"], 30, 19, 40)
    sb.put("SM_StoneDeposit01", (-22, -12, 0), 40)
    sb.rig("SK_Wolf", (16, -27, 0), 150, "Alert", 30)
    renders = {}
    camera(ctx, (34, -46, 26), (0, 0, 2), lens=30)
    ctx.renderer.day()
    renders["day"] = render_scene(ctx, sb, os.path.join(P.OUT["render"], "Scenes", "Scene_Camp_Day.png"))
    # night: warm fire light + glowing flames
    ctx.renderer.night()
    glow = glow_material()
    old = flames.data.materials[0]
    flames.data = flames.data.copy()
    flames.data.materials[0] = glow
    light = bpy.data.objects.new("CampfireLight", bpy.data.lights.new("CampfireLight", "POINT"))
    light.data.energy = 9000
    light.data.color = (1.0, 0.55, 0.25)
    light.data.shadow_soft_size = 1.5
    light.location = (0, 0, 3.2)
    sb.col.objects.link(light)
    sb.objs.append(light)
    for i, (x, y) in enumerate(((-4, 10.5),)):
        l2 = bpy.data.objects.new("LanternLight", bpy.data.lights.new("LanternLight", "POINT"))
        l2.data.energy = 600
        l2.data.color = (1.0, 0.7, 0.4)
        l2.location = (x + 0.9, y, 4.3)
        sb.col.objects.link(l2)
        sb.objs.append(l2)
    renders["night"] = render_scene(ctx, sb, os.path.join(P.OUT["render"], "Scenes", "Scene_Camp_Night.png"))
    ctx.renderer.day()
    light.hide_render = True
    return [dict(name="Scene_Camp", category="Scenes", kind="Reference", kind_note="Preview scene",
                 use="Assembled team camp: fire, L1 bench, chest, 12-piece wall ring with gate, spikes, tower, "
                     "4 R15 dummies, forest edge, wolf.", renders=renders, tris=0, size_studs_roblox_XYZ=[0, 0, 0],
                 files={"blend": "Source/SH_AssetPack.blend (collection Scene_Camp)"})]


@P.asset("Scene_Clearing", "Scenes", "Reference")
def scene_clearing(ctx):
    if not ctx.renderer:
        return []
    import random
    rng = random.Random(11)
    sb = SceneBuilder(ctx, "Clearing")
    ox = 300
    ground(sb)
    sb.objs[-1].location.x = ox
    sb.put("SM_Stream_Straight", (ox - 20, 8, 0))
    sb.put("SM_Stream_Water_Straight", (ox - 20, 8, 0))
    sb.put("SM_Stream_Straight", (ox - 20, -8, 0))
    sb.put("SM_Stream_Water_Straight", (ox - 20, -8, 0))
    sb.put("SM_Stream_PoolEnd", (ox - 20, 24, 0))
    sb.put("SM_Stream_Water_PoolEnd", (ox - 20, 24, 0))
    sb.put("SM_StreamRocks02", (ox - 20, -2, -1.6))
    sb.put("SM_StreamRocks01", (ox - 21, 10, -1.6))
    sb.put("SM_Landmark_StandingStones", (ox + 8, 10, 0))
    sb.put("SM_Tree_Oak_Large01", (ox + 8, 10, 0))
    sb.put("SM_StoneDeposit01", (ox + 4, -8, 0), 20)
    sb.put("SM_StoneDeposit01_Depleted", (ox + 12, -10, 0))
    sb.put("SM_FiberPlant01", (ox - 4, -4, 0))
    sb.put("SM_FiberPlant01", (ox - 6, -2, 0), 60)
    sb.put("SM_FiberPlant01_Harvested", (ox - 5, -7, 0))
    sb.put("SM_Tree_Pine_Small01", (ox - 8, 4, 0))
    sb.put("SM_Tree_Pine_Small01_Stump", (ox - 4, 6, 0))
    sb.put("SM_Tree_Birch_Small01", (ox + 0, -14, 0))
    sb.put("SM_FallenLog01", (ox + 18, -4, 0), 30)
    sb.put("SM_Landmark_AntlerTotem", (ox + 20, 12, 0), -30)
    sb.put("SM_SupplyCrate_Small01", (ox + 2, 2, 0), 20)
    sb.put("SH_Dummy", (ox - 1, -6, 0), 30)
    sb.put("SH_Dummy", (ox + 6, -2, 0), -10)
    scatter(sb, rng, ["SM_Tree_Pine_Medium01", "SM_Tree_Pine_Medium02", "SM_Tree_Oak_Medium01",
                      "SM_Tree_Birch_Medium01", "SM_Tree_Dead_Large01", "SM_Tree_Pine_Large01"], 22, 30, 55,
            center=(ox, 0))
    scatter(sb, rng, ["SM_Fern01", "SM_Fern02", "SM_Bush01", "SM_Bush03_Berry", "SM_Grass_Clump02",
                      "SM_Mushrooms01", "SM_Rock_Small01", "SM_Branch01", "SM_Stump_Old01", "SM_Boulder01"],
            40, 14, 34, center=(ox, 0), avoid=[((ox - 20, 0), 9)])
    sb.rig("SK_Wolf", (ox + 14, 4, 0), 110, "Howl", 40)
    sb.rig("SK_Bear", (ox + 22, -16, 0), 140, "RearUp", 36)
    sb.rig("SK_Bat", (ox + 4, 6, 9), 200, "Fly", 6)
    camera(ctx, (ox + 34, -44, 24), (ox, 0, 2), lens=28)
    ctx.renderer.day()
    renders = {"day": render_scene(ctx, sb, os.path.join(P.OUT["render"], "Scenes", "Scene_Clearing_Day.png"))}
    return [dict(name="Scene_Clearing", category="Scenes", kind="Reference", kind_note="Preview scene",
                 use="Forest clearing: stream kit, landmarks, harvestables + depleted states, wildlife, R15 dummies.",
                 renders=renders, tris=0, size_studs_roblox_XYZ=[0, 0, 0],
                 files={"blend": "Source/SH_AssetPack.blend (collection Scene_Clearing)"})]


@P.asset("Scene_Lobby", "Scenes", "Reference")
def scene_lobby(ctx):
    if not ctx.renderer:
        return []
    sb = SceneBuilder(ctx, "Lobby")
    ox, oy = -300, 0
    ground(sb)
    sb.objs[-1].location.x = ox
    sb.put("SM_Lobby_GatheringArea", (ox, oy, 0))
    sb.put("SM_Campfire_Flames", (ox, oy, 0.6))
    sb.put("SM_Lobby_ReadyStation", (ox, oy + 20, 0))
    sb.put("SM_Sign_Hanging", (ox, oy + 20, 7.5))
    sb.put("SM_Lobby_PartyArea", (ox - 22, oy + 2, 0))
    sb.put("SM_Lobby_ShopDisplay", (ox + 22, oy + 4, 0), 90)
    sb.put("SM_Sign_Board", (ox + 10, oy + 22, 0), -20)
    sb.put("SM_Sign_Post", (ox - 9, oy - 15, 0), 20)
    emblems = ["Trailblazer", "Scavenger", "Hunter", "Climber", "Craftsman", "Sharpshooter"]
    for i, e in enumerate(emblems):
        x = ox - 12.5 + i * 5
        y = oy - 20
        sb.put("SM_Lobby_PowerupStand", (x, y, 0))
        sb.put(f"SM_Emblem_{e}", (x, y - 0.05, 4.4))
        sb.put("SM_Sign_Plaque", (x, y - 1.32, 0.62), 0, -30)
    for k, (x, y) in enumerate(((ox - 3, oy - 7), (ox + 3, oy - 8), (ox - 20, oy + 5), (ox - 24, oy - 1))):
        sb.put("SH_Dummy", (x, y, 0.6 if k < 2 else 0.5), k * 40)
    sb.put("SM_Tree_Pine_Large01", (ox - 32, oy + 24, 0))
    sb.put("SM_Tree_Oak_Large01", (ox + 34, oy + 26, 0))
    sb.put("SM_Tree_Pine_Medium01", (ox + 36, oy - 20, 0))
    sb.put("SM_Tree_Birch_Medium01", (ox - 34, oy - 18, 0))
    camera(ctx, (ox + 28, oy - 56, 34), (ox, oy - 2, 2), lens=28)
    ctx.renderer.day()
    renders = {"day": render_scene(ctx, sb, os.path.join(P.OUT["render"], "Scenes", "Scene_Lobby_Day.png"))}
    return [dict(name="Scene_Lobby", category="Scenes", kind="Reference", kind_note="Preview scene",
                 use="Lobby layout: gathering deck, ready arch, party platform, six powerup stands with emblems, "
                     "shop stall, signs.", renders=renders, tris=0, size_studs_roblox_XYZ=[0, 0, 0],
                 files={"blend": "Source/SH_AssetPack.blend (collection Scene_Lobby)"})]
