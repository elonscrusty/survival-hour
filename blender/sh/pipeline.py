"""Registry, materials, FBX export, catalog data and preview renders."""

import json
import math
import os

import bpy
from mathutils import Matrix, Vector

from . import kit
from . import textures as tx

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = {
    "tex": os.path.join(ROOT, "Textures"),
    "mesh": os.path.join(ROOT, "Export", "Meshes"),
    "lod": os.path.join(ROOT, "Export", "LOD"),
    "col": os.path.join(ROOT, "Export", "Collision"),
    "rig": os.path.join(ROOT, "Export", "Rigs"),
    "anim": os.path.join(ROOT, "Export", "Animations"),
    "src": os.path.join(ROOT, "Source"),
    "render": os.path.join(ROOT, "Renders"),
    "icons": os.path.join(ROOT, "Renders", "Icons"),
    "data": os.path.join(ROOT, "Roblox"),
}

REGISTRY = []  # list of dicts, in declaration order
KINDS = {
    "WorldProp": "Static world prop (anchor it).",
    "Harvestable": "Static world prop players harvest; pair with its Depleted variant.",
    "Structure": "Player-placed building piece (anchored, collidable).",
    "MovingPart": "Separate moving piece of another asset (door, lid, slide, bolt).",
    "Equippable": "Held item: put in a Tool, rename to Handle.",
    "Pickup": "Small dropped/world pickup and inventory icon model.",
    "Accessory": "Rigid R15 accessory (armor piece).",
    "Effect": "Effect mesh (flames, water surface, target ring): no collision.",
    "Rig": "Skinned, rigged character mesh with animations.",
    "Lobby": "Lobby prop.",
    "Reference": "Scale reference; not for gameplay.",
    "Projectile": "Projectile mesh fired by a weapon (no collision; use raycasts).",
    "Debris": "Lightweight destruction debris: unanchored, short lifetime, CanCollide on, CanTouch off.",
}


def asset(name, category, kind, *, density=4.0, lod=False, grain=None, smooth=38.0, seed=None,
          dummy=True, use="", pivot="Bottom centre, on the ground.", fidelity="Box",
          footprint=None, notes="", icon=False, cast_shadow=True, uv_box=False):
    def reg(fn):
        REGISTRY.append(dict(name=name, category=category, kind=kind, fn=fn, density=density,
                             lod=lod, grain=grain, smooth=smooth,
                             seed=seed if seed is not None else len(REGISTRY) * 7919 + 13,
                             dummy=dummy, uv_box=uv_box, use=use, pivot=pivot, fidelity=fidelity,
                             footprint=footprint, notes=notes, icon=icon))
        return fn
    return reg


# ---------------------------------------------------------------- materials

def make_materials(tex_files):
    def img(path, non_color=False):
        im = bpy.data.images.load(path, check_existing=True)
        if non_color:
            im.colorspace_settings.name = "Non-Color"
        return im

    full = bpy.data.materials.new("M_SurvivalAtlas")
    full.use_nodes = True
    nt = full.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    def texnode(image, x, y):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = image
        n.interpolation = "Linear"
        n.location = (x, y)
        return n
    c = texnode(img(tex_files["Color_Neutral"]), -700, 300)
    r = texnode(img(tex_files["Roughness"], True), -700, 0)
    mt = texnode(img(tex_files["Metalness"], True), -700, -250)
    nm = texnode(img(tex_files["Normal"], True), -700, -500)
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.location = (-350, -500)
    nt.links.new(c.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    nt.links.new(mt.outputs["Color"], bsdf.inputs["Metallic"])
    nt.links.new(nm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    full["color_node"] = c.name

    exp = bpy.data.materials.new("M_SurvivalAtlas_Embed")
    exp.use_nodes = True
    b2 = exp.node_tree.nodes["Principled BSDF"]
    b2.inputs["Roughness"].default_value = 0.8
    t2 = exp.node_tree.nodes.new("ShaderNodeTexImage")
    t2.image = img(tex_files["Embed"])
    exp.node_tree.links.new(t2.outputs["Color"], b2.inputs["Base Color"])
    return full, exp


def set_team_color(full_mat, tex_files, team):
    node = full_mat.node_tree.nodes[full_mat["color_node"]]
    node.image = bpy.data.images.load(tex_files["Color_" + team], check_existing=True)


# ------------------------------------------------------------------- export

def _select_only(objs):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def export_fbx(objs, path, material_swap=None, anim=False):
    """Export with Roblox's documented Blender settings (Export settings +
    Blender guide): FBX Unit Scale, Forward Z, Up Y, no leaf bones, embedded
    textures, bake animation only for animation files."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    allobjs = []
    for o in objs:
        allobjs.append(o)
        allobjs.extend(c for c in o.children if c.name.endswith("_Att"))
    renamed = []
    for o in allobjs:
        if "__" in o.name and o.name.endswith("_Att"):
            old = o.name
            o.name = old.split("__", 1)[1]
            renamed.append((o, old))
    swapped = []
    if material_swap:
        src, dst = material_swap
        for o in allobjs:
            if o.type == "MESH" and o.data.materials and o.data.materials[0] == src:
                o.data.materials[0] = dst
                swapped.append(o)
    _select_only(allobjs)
    try:
        bpy.ops.export_scene.fbx(
            filepath=path, use_selection=True,
            object_types={"MESH", "ARMATURE"},
            apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS", global_scale=1.0,
            axis_forward="Z", axis_up="Y",
            mesh_smooth_type="OFF", use_mesh_modifiers=True, use_triangles=False,
            add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X",
            use_armature_deform_only=False,
            bake_anim=anim, bake_anim_use_all_bones=True, bake_anim_use_nla_strips=False,
            bake_anim_use_all_actions=False, bake_anim_force_startend_keying=True,
            bake_anim_step=1.0, bake_anim_simplify_factor=0.0,
            path_mode="COPY", embed_textures=True)
    finally:
        for o in swapped:
            o.data.materials[0] = material_swap[0]
        # restore unique names in reverse so no clashes
        for o, old in renamed:
            o.name = old
    return path


def export_collision(model, path, material):
    if not model.collision:
        return None
    m = kit.Model("COL_" + model.name[3:] if model.name.startswith("SM_") else "COL_" + model.name)
    for c, s, r in model.collision:
        m.box("stone", s, loc=c, rot=r)
    col = bpy.data.collections.get("_tmp") or bpy.data.collections.new("_tmp")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    o = m.build(material, col)
    export_fbx([o], path)
    bpy.data.objects.remove(o)
    return path


# ------------------------------------------------------------- data helpers

C = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def to_roblox_cframe(loc, rot_deg=(0, 0, 0)):
    """Blender location/rotation -> Roblox CFrame components (x,y,z,R00..R22)."""
    rb = kit.xform((0, 0, 0), rot_deg).to_3x3()
    rr = C @ rb @ C.transposed()
    p = kit.blender_to_roblox(loc)
    vals = [round(v, 4) for v in p] + [round(rr[i][j], 4) for i in range(3) for j in range(3)]
    return [0.0 if v == 0 else v for v in vals]


def roblox_size(size_b):
    """Blender (x,y,z) extents -> Roblox (X,Y,Z) = (x, z, y)."""
    return (size_b[0], size_b[2], size_b[1])


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/") if path else None


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=1)


# ------------------------------------------------------------------ render

class Renderer:
    def __init__(self, scene, res=384, samples=20):
        self.scene = scene
        s = scene
        s.render.engine = "CYCLES"
        s.cycles.device = "CPU"
        s.cycles.samples = samples
        s.cycles.use_denoising = True
        s.render.resolution_x = s.render.resolution_y = res
        s.render.film_transparent = True
        s.view_settings.view_transform = "Standard"
        s.view_settings.look = "None"
        world = bpy.data.worlds.new("SH_World")
        world.use_nodes = True
        s.world = world
        self.bg = world.node_tree.nodes["Background"]
        self.sun = bpy.data.objects.new("SH_Sun", bpy.data.lights.new("SH_Sun", "SUN"))
        s.collection.objects.link(self.sun)
        g = bpy.data.meshes.new("SH_Ground")
        g.from_pydata([(-400, -400, -0.015), (400, -400, -0.015), (400, 400, -0.015), (-400, 400, -0.015)], [],
                      [(0, 1, 2, 3)])
        self.ground = bpy.data.objects.new("SH_ShadowCatcher", g)
        self.ground.is_shadow_catcher = True
        s.collection.objects.link(self.ground)
        cam = bpy.data.objects.new("SH_Camera", bpy.data.cameras.new("SH_Camera"))
        cam.data.clip_end = 5000
        s.collection.objects.link(cam)
        s.camera = cam
        self.cam = cam
        self.fixed = {self.sun, self.ground, cam}
        self.day()

    def day(self):
        self.bg.inputs["Color"].default_value = (0.62, 0.72, 0.85, 1)
        self.bg.inputs["Strength"].default_value = 0.9
        self.sun.data.energy = 3.2
        self.sun.data.color = (1.0, 0.96, 0.88)
        self.sun.data.angle = math.radians(6)
        self.sun.rotation_euler = (math.radians(48), math.radians(8), math.radians(-35))

    def night(self):
        self.bg.inputs["Color"].default_value = (0.05, 0.07, 0.13, 1)
        self.bg.inputs["Strength"].default_value = 0.6
        self.sun.data.energy = 0.25
        self.sun.data.color = (0.6, 0.7, 1.0)

    def frame(self, objs, direction=(0.9, -1.35, 0.75), ortho=True, margin=1.1, lens=45):
        corners = []
        for o in objs:
            if o.type in {"MESH", "ARMATURE"}:
                corners += [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector([min(c[i] for c in corners) for i in range(3)])
        hi = Vector([max(c[i] for c in corners) for i in range(3)])
        center = (lo + hi) / 2
        d = Vector(direction).normalized()
        rot = (-d).to_track_quat("-Z", "Y")
        inv = rot.to_matrix().inverted()
        ext = max(max(abs((inv @ (c - center)).x), abs((inv @ (c - center)).y)) for c in corners)
        cam = self.cam
        cam.rotation_euler = rot.to_euler()
        if ortho:
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = ext * 2 * margin
            cam.location = center + d * (ext * 4 + 60)
        else:
            cam.data.type = "PERSP"
            cam.data.lens = lens
            fov = 2 * math.atan(18 / lens)
            cam.location = center + d * (ext * margin / math.tan(fov / 2) + ext)

    def render(self, visible, path, **frame_kw):
        vis = set(visible)
        for o in self.scene.objects:
            if o in self.fixed:
                continue
            o.hide_render = o not in vis
        self.frame(visible, **frame_kw)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path


def contact_sheet(entries, path, title, cols=6, cell=240):
    """entries: [(png_path, label, sublabel)]. Needs Pillow; skipped otherwise."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Pillow missing: contact sheet skipped", path)
        return None
    rows = math.ceil(len(entries) / cols)
    lh, head = 38, 44
    sheet = Image.new("RGB", (cols * cell, head + rows * (cell + lh)), (34, 40, 36))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 13)
        small = ImageFont.truetype("DejaVuSans.ttf", 11)
        big = ImageFont.truetype("DejaVuSans-Bold.ttf", 20)
    except OSError:
        font = small = big = ImageFont.load_default()
    d.text((12, 11), title, fill=(236, 232, 214), font=big)
    for i, (png, label, sub) in enumerate(entries):
        x, y = (i % cols) * cell, head + (i // cols) * (cell + lh)
        d.rectangle([x + 4, y + 4, x + cell - 4, y + cell - 4], fill=(205, 214, 196))
        if png and os.path.exists(png):
            im = Image.open(png).convert("RGBA")
            im.thumbnail((cell - 12, cell - 12), Image.LANCZOS)
            sheet.paste(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2), im)
        d.text((x + 8, y + cell + 2), label, fill=(240, 238, 226), font=font)
        d.text((x + 8, y + cell + 19), sub, fill=(170, 180, 165), font=small)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    return path
