"""Build the Survival Hour asset pack.

    blender --background --python blender/build.py -- [options]
    python blender/build.py [options]          (bpy module, Python 3.11)

Options:
    --only a,b,c     only these asset names or categories
    --no-render      skip preview renders
    --samples N      render samples (default 20)
"""

import argparse
import importlib
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from sh import kit, pipeline as P, reference, textures as tx  # noqa: E402

ASSET_MODULES = ["reference_assets", "world", "stream", "camp", "crafting", "pickups", "loot",
                 "firearms", "armor", "lobby", "wildlife", "scenes", "survival_wars"]

CATEGORY_ORDER = ["Reference", "Forest", "Stream", "Camp", "Crafting_L1", "Crafting_L2",
                  "Crafting_L3", "Armor", "Pickups", "Loot", "Firearms", "Wildlife", "Lobby",
                  "SW_Landscape", "SW_POI", "SW_Loot", "SW_Tools", "SW_Base"]


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--no-render", action="store_true")
    ap.add_argument("--samples", type=int, default=20)
    return ap.parse_args(argv)


class Ctx:
    """Handed to special builders (rigs, scenes)."""

    def __init__(self, full, embed, tex_files, renderer, do_render):
        self.full, self.embed, self.tex_files = full, embed, tex_files
        self.renderer, self.do_render = renderer, do_render
        self.objects = {}

    def collection(self, name):
        c = bpy.data.collections.get(name)
        if not c:
            c = bpy.data.collections.new(name)
            bpy.context.scene.collection.children.link(c)
        return c


def origin_offset(stats):
    """Asset origin expressed in the imported MeshPart's space (Roblox puts
    the MeshPart CFrame at the bounding-box centre)."""
    c = [(a + b) / 2 for a, b in zip(stats["bounds_min"], stats["bounds_max"])]
    r = P.to_roblox_cframe(c)[:3]
    return [round(-v, 4) + 0.0 for v in r]


def entry_record(e, m, obj, files, parts, lod_stats):
    st = m.stats
    size_b = st["size"]
    rec = dict(
        name=e["name"], category=e["category"], kind=e["kind"], kind_note=P.KINDS[e["kind"]],
        use=e["use"], notes=e["notes"],
        size_studs_roblox_XYZ=P.roblox_size(size_b),
        footprint_studs=e["footprint"] or [size_b[0], size_b[1]],
        tris=st["tris"], verts=st["verts"], materials=1, texture_tiles=st["tiles"],
        origin_offset=origin_offset(st),
        team_colored=any(t.startswith("team_") for t in st["tiles"]),
        pivot=e["pivot"], collision_fidelity=e["fidelity"],
        attachments=[dict(name=n + "_Att", cframe=P.to_roblox_cframe(l, r))
                     for n, l, r in m.attachments],
        collision_boxes=[dict(cframe=P.to_roblox_cframe(c, r), size=P.roblox_size(s))
                         for c, s, r in m.collision],
        parts=parts, lod1_tris=lod_stats.get("tris") if lod_stats else None,
        files={k: P.rel(v) for k, v in files.items() if v},
        checks=dict(duplicate_faces=st["duplicate_faces"], open_edges=st["open_edges"],
                    nonmanifold_edges=st["nonmanifold_edges"],
                    removed_degenerate=st["removed_degenerate"]),
        meta=m.meta,
    )
    return rec


def main():
    args = parse()
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.system_rotation = "DEGREES"
    scene.render.fps = 30

    tex_files = tx.build_atlas(P.OUT["tex"])
    full, embed = P.make_materials(tex_files)

    for mod in ASSET_MODULES:
        try:
            importlib.import_module("assets." + mod)
        except ModuleNotFoundError as err:
            if err.name != "assets." + mod:
                raise
    only = {s for s in args.only.split(",") if s}
    entries = [e for e in P.REGISTRY
               if not only or e["name"] in only or e["category"] in only]

    renderer = P.Renderer(scene, samples=args.samples) if not args.no_render else None
    ctx = Ctx(full, embed, tex_files, renderer, not args.no_render)

    dummy_col = ctx.collection("Reference_Dummies")
    dummy = reference.build_dummy("idle", "SH_Dummy").build(full, dummy_col)
    dummy_hold = reference.build_dummy("hold", "SH_Dummy_Hold").build(full, dummy_col)
    ctx.objects["SH_Dummy"], ctx.objects["SH_Dummy_Hold"] = dummy, dummy_hold

    catalog, sheets = [], {}
    special = []
    for e in entries:
        if e["kind"] == "Rig" or e["category"] == "Scenes":
            special.append(e)
            continue
        col = ctx.collection(e["category"])
        m = kit.Model(e["name"], seed=e["seed"], density=e["density"], grain=e["grain"],
                      smooth_angle=e["smooth"], uv_box=e["uv_box"])
        e["fn"](m)
        obj = m.build(full, col)
        if "r15_attachment" in m.meta:
            obj["r15_attachment"] = m.meta["r15_attachment"]
        ctx.objects[e["name"]] = obj
        cat = e["category"]
        files = {"fbx": P.export_fbx([obj], os.path.join(P.OUT["mesh"], cat, e["name"] + ".fbx"),
                                     (full, embed))}
        parts = []
        part_objs = []
        for p, placement in m.parts:
            pobj = p.build(full, col)
            ppath = P.export_fbx([pobj], os.path.join(P.OUT["mesh"], cat, p.name + ".fbx"),
                                 (full, embed))
            pobj.matrix_world = placement
            pobj["sh_part_of"] = obj.name
            part_objs.append(pobj)
            ctx.objects[p.name] = pobj
            loc = placement.to_translation()
            rot = [math.degrees(a) for a in placement.to_euler()]
            parts.append(dict(name=p.name, file=P.rel(ppath), tris=p.stats["tris"],
                              origin_offset=origin_offset(p.stats),
                              size_studs_roblox_XYZ=P.roblox_size(p.stats["size"]),
                              pivot=p.meta.get("pivot", "Hinge/slide axis at origin."),
                              placement_cframe=P.to_roblox_cframe(loc, rot),
                              attachments=[dict(name=n + "_Att", cframe=P.to_roblox_cframe(l, r))
                                           for n, l, r in p.attachments],
                              collision_boxes=[dict(cframe=P.to_roblox_cframe(c, r),
                                                    size=P.roblox_size(s))
                                               for c, s, r in p.collision]))
            if p.collision:
                P.export_collision(p, os.path.join(P.OUT["col"], cat,
                                                   "COL_" + p.name.replace("SM_", "") + ".fbx"), full)
        lod_stats = None
        if e["lod"]:
            m2 = kit.Model(e["name"] + "_LOD1", seed=e["seed"], density=e["density"],
                           grain=e["grain"], smooth_angle=e["smooth"], lod=1, uv_box=e["uv_box"])
            e["fn"](m2)
            lobj = m2.build(full, col)
            files["lod1"] = P.export_fbx([lobj], os.path.join(P.OUT["lod"], cat,
                                                              e["name"] + "_LOD1.fbx"), (full, embed))
            lod_stats = m2.stats
            ctx.objects[e["name"] + "_LOD1"] = lobj
            lobj.hide_render = True
            for c in lobj.children:
                bpy.data.objects.remove(c)
        if m.collision:
            files["collision"] = P.export_collision(
                m, os.path.join(P.OUT["col"], cat, "COL_" + e["name"].replace("SM_", "") + ".fbx"),
                full)
        rec = entry_record(e, m, obj, files, parts, lod_stats)
        catalog.append(rec)
        print(f"[{time.time() - t0:6.1f}s] {e['name']:<34} {m.stats['tris']:>6} tris  "
              f"size {rec['size_studs_roblox_XYZ']}  open={m.stats['open_edges']} "
              f"dup={m.stats['duplicate_faces']}")

        if renderer:
            render_entry(ctx, e, obj, part_objs, rec)

    for e in special:
        res = e["fn"](ctx)
        for rec in res:
            catalog.append(rec)

    # data outputs
    existing = {}
    cat_path = os.path.join(P.OUT["data"], "catalog.json")
    if only and os.path.exists(cat_path):
        import json
        with open(cat_path) as f:
            existing = {r["name"]: r for r in json.load(f)}
    if not only and os.path.exists(cat_path) and args.no_render:
        import json
        with open(cat_path) as f:
            old = {r["name"]: r for r in json.load(f)}
        for r in catalog:  # keep renders from the last rendered build
            if "renders" in old.get(r["name"], {}):
                r["renders"] = old[r["name"]]["renders"]
        existing = {n: r for n, r in old.items() if r["category"] == "Scenes"}
    for r in catalog:
        existing[r["name"]] = r
    merged = list(existing.values())
    order = {n: i for i, n in enumerate(CATEGORY_ORDER)}
    merged.sort(key=lambda r: order.get(r["category"], 99))
    P.write_json(cat_path, merged)

    if renderer:
        make_sheets(merged)

    blend = os.path.join(P.OUT["src"], "SH_AssetPack.blend")
    if args.no_render and os.path.exists(blend):
        print("--no-render: keeping the existing .blend (it holds the sample scenes)")
    else:
        layout_and_save(ctx)
    print(f"done in {time.time() - t0:.0f}s, {len(catalog)} assets")


def render_entry(ctx, e, obj, part_objs, rec):
    r = ctx.renderer
    out = os.path.join(P.OUT["render"], e["category"])
    vis = [obj] + part_objs
    dummy = ctx.objects["SH_Dummy"]
    lift = 0.0
    low = min((o.matrix_world @ Vector(c)).z for o in vis for c in o.bound_box)
    if e["kind"] in ("Equippable", "Projectile", "Accessory") or low < -0.3:  # preview only: rest on the ground
        lift = -low
        for o in vis:
            o.location.z += lift
    if e["dummy"]:
        maxx = max((o.matrix_world @ Vector(c)).x for o in vis for c in o.bound_box)
        dummy.location = (maxx + 1.8, 0.5, 0)
        vis.append(dummy)
    rec.setdefault("renders", {})["preview"] = P.rel(r.render(vis, os.path.join(out, e["name"] + ".png")))
    dummy.location = (0, 0, 0)
    for o in [obj] + part_objs:
        o.location.z -= lift
    if e["kind"] == "Equippable":
        hold = ctx.objects["SH_Dummy_Hold"]
        old = obj.matrix_world.copy()
        obj.location = reference.hold_grip()
        rec["renders"]["held"] = P.rel(r.render([hold, obj], os.path.join(out, e["name"] + "_Held.png"),
                                                direction=(1.2, -0.9, 0.55)))
        obj.matrix_world = old
    if e["kind"] == "Accessory":
        att = obj.get("r15_attachment") or e.get("attach")
        old = obj.matrix_world.copy()
        obj.location = reference.R15[att]
        rec["renders"]["worn"] = P.rel(r.render([dummy, obj], os.path.join(out, e["name"] + "_Worn.png"),
                                                direction=(1.1, -1.2, 0.5)))
        obj.matrix_world = old
    if e["icon"]:
        s = ctx.renderer.scene
        rx = s.render.resolution_x
        s.render.resolution_x = s.render.resolution_y = 256
        rec["renders"]["icon"] = P.rel(r.render([obj], os.path.join(P.OUT["icons"], "ICON_" + e["name"].replace("SM_", "") + ".png"),
                                                direction=(0.8, -1.0, 1.1), margin=1.05))
        s.render.resolution_x = s.render.resolution_y = rx


def make_sheets(catalog):
    by_cat = {}
    for r in catalog:
        by_cat.setdefault(r["category"], []).append(r)
    for cat, recs in by_cat.items():
        if cat == "Scenes":
            items = [(os.path.join(P.ROOT, path), f"{r['name']} ({k})", "")
                     for r in recs for k, path in r.get("renders", {}).items()]
            if items:
                P.contact_sheet(items, os.path.join(P.OUT["render"], "ContactSheet_Scenes.png"),
                                "Survival Hour - sample scenes", cols=2, cell=560)
            continue
        items = []
        for r in recs:
            if "renders" not in r:
                continue
            X, Y, Z = r["size_studs_roblox_XYZ"]
            sub = f"{r['tris']} tris  {X:.1f}x{Y:.1f}x{Z:.1f}"
            items.append((os.path.join(P.ROOT, r["renders"]["preview"]), r["name"], sub))
            for key in ("held", "worn"):
                if key in r["renders"]:
                    items.append((os.path.join(P.ROOT, r["renders"][key]), r["name"] + f" ({key})",
                                  "on R15 reference"))
            if r["kind"] == "Rig":
                for clip, path in r["renders"].items():
                    if clip not in ("preview", "Idle"):
                        items.append((os.path.join(P.ROOT, path), r["name"] + f" {clip}", "pose frame"))
        if items:
            P.contact_sheet(items, os.path.join(P.OUT["render"], f"ContactSheet_{cat}.png"),
                            f"Survival Hour - {cat.replace('_', ' ')}  (dummy = R15 reference, 5.25 studs)")


def layout_and_save(ctx):
    """Spread assets out by category for the editable .blend, then save."""
    y = 0.0
    for col in bpy.context.scene.collection.children:
        objs = [o for o in col.objects if o.parent is None and o.type in {"MESH", "ARMATURE"}]
        if not objs or col.name.startswith("Scene_"):
            continue
        x, depth = 0.0, 0.0
        roots = [o for o in objs if not o.get("sh_part_of")]
        for o in roots:
            bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
            minx = min(v.x for v in bb)
            w = max(v.x for v in bb) - minx
            d = max(v.y for v in bb) - min(v.y for v in bb)
            dx = x - minx
            o.location.x += dx
            o.location.y += y
            for p in objs:
                if p.get("sh_part_of") == o.name:
                    p.location.x += dx
                    p.location.y += y
            x += w + 3
            depth = max(depth, d)
        y += depth + 8
    os.makedirs(P.OUT["src"], exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(P.OUT["src"], "SH_AssetPack.blend"),
                                compress=True, relative_remap=True)


if __name__ == "__main__":
    main()
