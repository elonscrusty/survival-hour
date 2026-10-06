"""Preview renders for Pet Expedition models (Blender's Python module, bpy).

Uses the exact same part specs as gen_models.py (so previews match the game)
and writes PNG/JPG files to games/pet-expedition/renders/.

  python3 models/render.py                    # everything
  python3 models/render.py --only pets --ids Dragon,Griffin
  python3 models/render.py --only eggs,breakables,props,world,sheet,marketing
  python3 models/render.py --samples 16 --res 320

Needs bpy (SH_WITH_BPY=1 bash tools/setup_env.sh from the repo root) and
Pillow (for contact sheets, backgrounds and JPG output).
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_models as G  # noqa: E402
from lib import hexc, MATERIALS  # noqa: E402

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:  # previews still render, sheets are skipped
    Image = None

OUT = os.path.join(os.path.dirname(HERE), "renders")

# Roblox (x, y, z) -> Blender (x, -z, y)
C3 = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def srgb_to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# ------------------------------------------------------------------ meshes
def _mesh(name, verts, faces, smooth=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    return me


def build_unit_meshes():
    m = {}
    v = [(x, y, z) for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)]
    # index = xi*4 + yi*2 + zi
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    m["B"] = _mesh("U_Block", v, f)
    # UV sphere radius .5
    seg, rings = 28, 14
    verts = [(0, .5, 0)]
    for i in range(1, rings):
        th = math.pi * i / rings
        for j in range(seg):
            ph = 2 * math.pi * j / seg
            verts.append((.5 * math.sin(th) * math.cos(ph), .5 * math.cos(th), .5 * math.sin(th) * math.sin(ph)))
    verts.append((0, -.5, 0))
    faces = []
    for j in range(seg):
        faces.append((0, 1 + (j + 1) % seg, 1 + j))
    for i in range(rings - 2):
        for j in range(seg):
            a = 1 + i * seg + j
            b = 1 + i * seg + (j + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    last = len(verts) - 1
    base = 1 + (rings - 2) * seg
    for j in range(seg):
        faces.append((last, base + j, base + (j + 1) % seg))
    m["S"] = _mesh("U_Sphere", verts, faces, smooth=True)
    # Cylinder along local X, radius .5, length 1
    seg = 28
    verts = []
    for side in (-.5, .5):
        for j in range(seg):
            a = 2 * math.pi * j / seg
            verts.append((side, .5 * math.cos(a), .5 * math.sin(a)))
    faces = [tuple(range(seg - 1, -1, -1)), tuple(range(seg, 2 * seg))]
    for j in range(seg):
        faces.append((j, (j + 1) % seg, seg + (j + 1) % seg, seg + j))
    me = _mesh("U_Cyl", verts, faces)
    for p in me.polygons:
        p.use_smooth = len(p.vertices) == 4
    m["C"] = me
    # Wedge: tall face at +Z, slope down towards -Z
    verts = [(-.5, -.5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (-.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5)]
    faces = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    m["W"] = _mesh("U_Wedge", verts, faces)
    for me in m.values():
        # make normals consistent outward
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(None)
    return m


# ------------------------------------------------------------------ materials
_mats = {}


def material(col, code, tr):
    key = (col, code, round(tr, 2))
    if key in _mats:
        return _mats[key]
    name = MATERIALS.get(code, "SmoothPlastic")
    mat = bpy.data.materials.new(f"{name}_{col:06x}_{tr:.2f}")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    r, g, b = hexc(col)
    lin = (srgb_to_lin(r), srgb_to_lin(g), srgb_to_lin(b), 1)
    bsdf.inputs["Base Color"].default_value = lin
    rough = 0.42
    metal = 0.0
    if name in ("Foil", "Metal", "DiamondPlate"):
        metal, rough = 1.0, 0.28 if name == "Foil" else 0.35
    elif name in ("Glass", "Ice", "Glacier"):
        rough = 0.08
        try:
            bsdf.inputs["Transmission Weight"].default_value = 0.35 if name == "Glass" else 0.15
        except KeyError:
            pass
    elif name in ("SmoothPlastic", "Marble", "Neon"):
        rough = 0.35
    else:
        rough = 0.85
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if name == "Neon":
        bsdf.inputs["Emission Color"].default_value = lin
        bsdf.inputs["Emission Strength"].default_value = 2.2
    if name == "ForceField":
        tr = max(tr, 0.5)
        bsdf.inputs["Emission Color"].default_value = lin
        bsdf.inputs["Emission Strength"].default_value = 1.0
    if tr > 0:
        bsdf.inputs["Alpha"].default_value = max(0.0, 1 - tr)
    _mats[key] = mat
    return mat


# ------------------------------------------------------------------ scene
class Scene:
    def __init__(self, res=384, samples=20):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        _mats.clear()  # materials from a previous scene were freed
        s = bpy.context.scene
        self.s = s
        s.render.engine = "CYCLES"
        s.cycles.device = "CPU"
        s.cycles.samples = samples
        s.cycles.use_denoising = True
        s.cycles.max_bounces = 6
        s.cycles.transparent_max_bounces = 12
        s.render.resolution_x = s.render.resolution_y = res
        s.render.film_transparent = True
        s.view_settings.view_transform = "Standard"
        s.render.image_settings.file_format = "PNG"
        s.render.image_settings.color_mode = "RGBA"
        world = bpy.data.worlds.new("W")
        s.world = world
        self.bg = world.node_tree.nodes["Background"]
        self.bg.inputs["Color"].default_value = (0.75, 0.82, 0.95, 1)
        self.bg.inputs["Strength"].default_value = 1.0
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy = 3.0
        sun.data.angle = math.radians(8)
        sun.rotation_euler = (math.radians(40), math.radians(-12), math.radians(-35))
        s.collection.objects.link(sun)
        self.sun = sun
        fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))
        fill.data.energy = 0.8
        fill.rotation_euler = (math.radians(60), math.radians(10), math.radians(150))
        s.collection.objects.link(fill)
        g = _mesh("Ground", [(-500, -500, 0), (500, -500, 0), (500, 500, 0), (-500, 500, 0)], [(0, 1, 2, 3)])
        self.ground = bpy.data.objects.new("ShadowCatcher", g)
        self.ground.is_shadow_catcher = True
        s.collection.objects.link(self.ground)
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        cam.data.clip_end = 20000
        cam.data.clip_start = 0.05
        s.collection.objects.link(cam)
        s.camera = cam
        self.cam = cam
        self.meshes = build_unit_meshes()
        self.objs = []
        self.coll = bpy.data.collections.new("Model")
        s.collection.children.link(self.coll)

    def clear(self):
        for o in self.objs:
            bpy.data.objects.remove(o, do_unlink=True)
        self.objs = []

    def add_parts(self, parts, offset=(0, 0, 0), yaw=0.0, scale=1.0):
        base = Matrix.Translation(Vector(offset)) @ Matrix.Rotation(math.radians(yaw), 4, "Y") @ Matrix.Scale(scale, 4)
        C4 = C3.to_4x4()
        for p in parts:
            if p.tr >= 1 or p.tag in ("Wall", "Root", "Prompt", "Zone"):
                continue
            code, size, pos, R = p.native()
            M = Matrix(R).to_4x4()
            M.translation = Vector(pos)
            S = Matrix.Diagonal((size[0], size[1], size[2], 1))
            o = bpy.data.objects.new("p", self.meshes[code])
            o.matrix_world = C4 @ base @ M @ S
            self.coll.objects.link(o)
            # Object-linked material so the unit meshes stay shared.
            o.material_slots[0].link = "OBJECT"
            o.material_slots[0].material = material(p.col, p.mat, p.tr)
            self.objs.append(o)

    def frame(self, direction=(0.6, 1.0, 0.38), margin=1.12, ortho=True, lens=50, target=None):
        corners = []
        for o in self.objs:
            corners += [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector([min(c[i] for c in corners) for i in range(3)])
        hi = Vector([max(c[i] for c in corners) for i in range(3)])
        center = (lo + hi) / 2 if target is None else Vector(target)
        d = Vector(direction).normalized()
        rotq = (-d).to_track_quat("-Z", "Y")
        inv = rotq.to_matrix().inverted()
        ext = 0
        for c in corners:
            q = inv @ (c - center)
            ext = max(ext, abs(q.x), abs(q.y))
        dist = (hi - lo).length * 2 + 10
        self.cam.rotation_euler = rotq.to_euler()
        if ortho:
            self.cam.data.type = "ORTHO"
            aspect = self.s.render.resolution_x / self.s.render.resolution_y
            self.cam.data.ortho_scale = ext * 2 * margin * max(1, aspect if aspect < 1 else 1)
            self.cam.location = center + d * dist
        else:
            self.cam.data.type = "PERSP"
            self.cam.data.lens = lens
            fov = 2 * math.atan(18 / lens)
            self.cam.location = center + d * (ext * margin / math.tan(fov / 2) + ext)
        self.ground.location = (0, 0, lo.z)

    def render(self, path):
        self.s.render.filepath = path
        bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ post
def on_background(png, out, top=(255, 247, 226), bottom=(255, 214, 222), jpg=False, label=None):
    if Image is None:
        return
    im = Image.open(png).convert("RGBA")
    w, h = im.size
    bg = Image.new("RGBA", (w, h))
    dr = ImageDraw.Draw(bg)
    for y in range(h):
        t = y / max(1, h - 1)
        dr.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    bg.alpha_composite(im)
    if label:
        f = font(max(14, w // 18))
        d = ImageDraw.Draw(bg)
        tw = d.textlength(label, font=f)
        d.text(((w - tw) / 2, h - w // 12 - 6), label, font=f, fill=(60, 50, 80), stroke_width=2, stroke_fill=(255, 255, 255))
    if jpg:
        bg.convert("RGB").save(out, quality=86)
    else:
        bg.convert("RGB").save(out, optimize=True)
    if os.path.abspath(out) != os.path.abspath(png):
        os.remove(png)


FONT_CANDIDATES = [
    os.environ.get("PE_FONT", ""),
    "/mnt/skills/examples/canvas-design/canvas-fonts/EricaOne-Regular.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
]


def font(size, plain=False):
    cands = FONT_CANDIDATES[2:] if plain else FONT_CANDIDATES
    for p in cands:
        if p and os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


# ------------------------------------------------------------------ jobs
RARITY_BG = {
    "Common": ((236, 240, 244), (205, 214, 224)),
    "Uncommon": ((226, 250, 226), (170, 225, 175)),
    "Rare": ((222, 238, 255), (150, 195, 250)),
    "Epic": ((240, 226, 255), (200, 160, 245)),
    "Legendary": ((255, 244, 214), (255, 200, 120)),
    "Mythic": ((255, 224, 240), (240, 140, 200)),
}


def render_one(sc, parts, path, label=None, bg=None, direction=(0.6, 1.0, 0.38), jpg=False):
    sc.clear()
    sc.add_parts(parts)
    sc.frame(direction=direction)
    tmp = path + ".tmp.png"
    sc.render(tmp)
    top, bottom = bg or ((255, 247, 226), (255, 214, 222))
    on_background(tmp, path, top, bottom, jpg=jpg, label=label)


def job_pets(sc, ids=None):
    os.makedirs(os.path.join(OUT, "pets"), exist_ok=True)
    data = G.build_all()
    for pid, parts in data["pets"].items():
        if ids and pid not in ids:
            continue
        info = G.PET_INFO[pid]
        render_one(sc, parts, os.path.join(OUT, "pets", f"{pid}.png"), label=info["Name"], bg=RARITY_BG[info["Rarity"]])
        print("pet", pid, len(parts))


def job_eggs(sc, ids=None):
    os.makedirs(os.path.join(OUT, "eggs"), exist_ok=True)
    data = G.build_all()
    for eid, parts in data["eggs"].items():
        if ids and eid not in ids:
            continue
        render_one(sc, parts, os.path.join(OUT, "eggs", f"{eid}.png"), label=eid, direction=(0.3, 1, 0.25))
    # each egg on its pedestal, side by side like reference/eggs.jpg
    stand_for = {e: f"EggStand_{a}" for a, e in G.WORLD.EGG_FOR.items()}
    stand_for["PrismEgg"] = "PrismStand"
    sc.clear()
    for i, eid in enumerate(data["eggs"]):
        prop = data["props"][stand_for[eid]]["parts"]
        stand = [q for q in prop if q.tag != "SignFace" and q.pos[2] > -3.5]  # leave out the name board
        x = (3 - i) * 9
        sc.add_parts(G.L.T(stand, (x, 0, 0)))
        sc.add_parts(G.L.T(data["eggs"][eid], G.L.add(G.egg_spot(prop), (x, 0, 0)), s=G.EGG_STAND_SCALE))
    sc.s.render.resolution_x, sc.s.render.resolution_y = 1800, 520
    sc.frame(direction=(0, 1, 0.22), margin=1.04)
    tmp = os.path.join(OUT, "eggs_sheet.tmp.png")
    sc.render(tmp)
    on_background(tmp, os.path.join(OUT, "eggs_sheet.jpg"), (255, 255, 255), (240, 236, 250), jpg=True)
    sc.s.render.resolution_x = sc.s.render.resolution_y = 320


def job_breakables(sc, ids=None):
    os.makedirs(os.path.join(OUT, "breakables"), exist_ok=True)
    data = G.build_all()
    files = []
    for (kind, area), parts in data["breakables"].items():
        if ids and area not in ids and kind not in ids:
            continue
        p = os.path.join(OUT, "breakables", f"{area}_{kind}.png")
        render_one(sc, parts, p, label=f"{area} {kind}")
        files.append(p)
    if not ids:
        sheet(files, os.path.join(OUT, "breakables_sheet.jpg"), cols=5, cell=256)


def job_props(sc, ids=None):
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    data = G.build_all()
    files = []
    for name, prop in data["props"].items():
        if ids and name not in ids:
            continue
        p = os.path.join(OUT, "props", f"{name}.png")
        render_one(sc, prop["parts"], p, label=name, bg=((215, 236, 255), (190, 225, 200)))
        files.append(p)
    if not ids:
        sheet(files, os.path.join(OUT, "props_sheet.jpg"), cols=8, cell=220)


def world_parts(data):
    w = data["world"]
    out = []
    for area, parts in w["parts"].items():
        out += parts
    props = data["props"]
    for pl in w["place"]:
        name, x, y, z, yaw, s = pl[:6]
        out += G.L.T(props[name]["parts"], (x, y, z), r=(0, yaw, 0), s=s)
    for it in w["interact"]:
        out += G.L.T(props[it["prop"]]["parts"], it["pos"], r=(0, it["yaw"], 0))
        if it["kind"] == "EggStand":
            spot = G.egg_spot(props[it["prop"]]["parts"])
            egg = G.L.T(data["eggs"][it["attrs"]["EggId"]], spot, s=G.EGG_STAND_SCALE)
            out += G.L.T(egg, it["pos"], r=(0, it["yaw"], 0))
    return out


def _shot(sc, path, loc, look, lens=30, res=(1280, 720), quality=82):
    sc.s.render.resolution_x, sc.s.render.resolution_y = res
    sc.cam.data.type = "PERSP"
    sc.cam.data.lens = lens
    loc, look = Vector(loc), Vector(look)
    sc.cam.location = loc
    sc.cam.rotation_euler = (look - loc).to_track_quat("-Z", "Y").to_euler()
    tmp = path + ".tmp.png"
    sc.render(tmp)
    Image.open(tmp).convert("RGB").save(path, quality=quality)
    os.remove(tmp)


def bl(x, y, z):
    """Roblox position -> Blender position."""
    return (x, -z, y)


def job_world(sc, only_top=False):
    data = G.build_all()
    parts = world_parts(data)
    w = data["world"]
    wl = w["water"]
    water = G.L.box((wl["maxx"] - wl["minx"], 1, wl["maxz"] - wl["minz"]),
                    ((wl["minx"] + wl["maxx"]) / 2, wl["level"] - 0.5, (wl["minz"] + wl["maxz"]) / 2), 0x3FA9E0, "P")
    sc.clear()
    sc.add_parts(parts + [water])
    sc.ground.hide_render = True
    sc.bg.inputs["Color"].default_value = (0.55, 0.75, 1.0, 1)
    sc.s.render.film_transparent = False
    os.makedirs(os.path.join(OUT, "world"), exist_ok=True)
    # Top-down map (north = -Z up)
    xs = [w["centers"][a] for a in G.AREAS]
    x0, x1 = min(xs) - 180, max(xs) + 180
    sc.s.render.resolution_x, sc.s.render.resolution_y = 2400, 600
    sc.cam.data.type = "ORTHO"
    sc.cam.data.ortho_scale = x1 - x0
    sc.cam.location = ((x0 + x1) / 2, -40, 600)
    sc.cam.rotation_euler = (0, 0, 0)
    tmp = os.path.join(OUT, "world", "map_top.tmp.png")
    sc.render(tmp)
    Image.open(tmp).convert("RGB").save(os.path.join(OUT, "world", "map_top.jpg"), quality=84)
    os.remove(tmp)
    if only_top:
        return
    # Overview from the south-west, high up
    mid = (x0 + x1) / 2
    _shot(sc, os.path.join(OUT, "world", "overview.jpg"), bl(mid - 300, 650, 900), bl(mid - 50, 0, 0), lens=26, res=(1920, 1080))
    # One view per island, plus the Meadow hub up close
    for a in G.AREAS:
        cx = w["centers"][a]
        _shot(sc, os.path.join(OUT, "world", f"{a}.jpg"), bl(cx - 120, 150, 260), bl(cx + 5, 0, -10), lens=24)
    hx, _, hz = G.WORLD.HUB
    _shot(sc, os.path.join(OUT, "world", "MeadowHub.jpg"), bl(hx + 75, 38, 0), bl(hx - 10, 4, 0), lens=24)
    ax, _, az = G.WORLD.ARENA
    _shot(sc, os.path.join(OUT, "world", "PetRing.jpg"), bl(ax - 30, 34, az + 62), bl(ax, 2, az), lens=24)


def sheet(files, out, cols=8, cell=256):
    if Image is None:
        return
    files = [f for f in files if os.path.exists(f)]
    if not files:
        return
    rows = (len(files) + cols - 1) // cols
    im = Image.new("RGB", (cols * cell, rows * cell), (250, 248, 255))
    for i, f in enumerate(files):
        t = Image.open(f).convert("RGB").resize((cell, cell), Image.LANCZOS)
        im.paste(t, ((i % cols) * cell, (i // cols) * cell))
    im.save(out, quality=85)


def job_sheet():
    data = G.build_all()
    files = [os.path.join(OUT, "pets", f"{p}.png") for p in data["pets"]]
    sheet(files, os.path.join(OUT, "pets_sheet.png"), cols=8, cell=200)


def job_marketing(sc):
    from marketing import make_marketing
    make_marketing(sc, G, OUT)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="pets,eggs,breakables,props,sheet,world,marketing")
    ap.add_argument("--ids", default="")
    ap.add_argument("--samples", type=int, default=20)
    ap.add_argument("--res", type=int, default=320)
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    ids = set(x for x in a.ids.split(",") if x)
    jobs = a.only.split(",")
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.join(OUT, "world"), exist_ok=True)
    sc = Scene(res=a.res, samples=a.samples)
    if "pets" in jobs:
        job_pets(sc, ids)
    if "eggs" in jobs:
        job_eggs(sc, ids)
    if "breakables" in jobs:
        job_breakables(sc, ids)
    if "props" in jobs:
        job_props(sc, ids)
    if "sheet" in jobs:
        job_sheet()
    if "marketing" in jobs:
        sc = Scene(res=a.res, samples=a.samples)
        job_marketing(sc)
    if "world" in jobs:
        sc = Scene(res=a.res, samples=max(8, a.samples // 2))
        job_world(sc)


if __name__ == "__main__":
    main()
