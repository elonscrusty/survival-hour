"""Generate Docs/CATALOG.md and Roblox/SurvivalHourAssetData.lua from
Roblox/catalog.json (written by build.py). Plain Python, no Blender needed.

    python blender/make_docs.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAT = os.path.join(ROOT, "Roblox", "catalog.json")

ORDER = ["Reference", "Forest", "Stream", "Camp", "Crafting_L1", "Crafting_L2", "Crafting_L3", "Armor",
         "Pickups", "Loot", "Firearms", "Wildlife", "Lobby",
         "SW_Landscape", "SW_POI", "SW_Loot", "SW_Tools", "SW_Base"]
TITLES = {
    "Reference": "Reference", "Forest": "Forest kit", "Stream": "Stream kit", "Camp": "Starting camp",
    "Crafting_L1": "Workbench level 1 craftables", "Crafting_L2": "Workbench level 2 craftables",
    "Crafting_L3": "Workbench level 3 craftables", "Armor": "Level 3 armour (rigid R15 accessories)",
    "Pickups": "Resource pickups", "Loot": "Loot and special equipment", "Firearms": "Firearms",
    "Wildlife": "Wildlife (rigged)", "Lobby": "Lobby kit",
    "SW_Landscape": "Survival Wars: landscape, cave and forest-variety kit",
    "SW_POI": "Survival Wars: points of interest", "SW_Loot": "Survival Wars: POI chests",
    "SW_Tools": "Survival Wars: tiered and breaching tools, bows",
    "SW_Base": "Survival Wars: storage tiers, walls, floor, traps, Workbench IV/V",
}


def fmt_size(s):
    return f"{s[0]:.1f} × {s[1]:.1f} × {s[2]:.1f}"


def catalog_md(recs):
    out = ["# Survival Hour: model catalog", "",
           "Generated from `Roblox/catalog.json` by `blender/make_docs.py`. Sizes are Roblox studs "
           "(X width × Y height × Z depth), measured on the exported mesh. Every mesh uses **1 material** "
           "(the shared atlas). *Tris* is after triangulation; *LOD1* is the lower-detail file where one exists.",
           "", "Kinds: " + "; ".join(sorted({f"**{r['kind']}**: {r['kind_note']}" for r in recs
                                              if r.get('kind_note') and r['category'] != 'Scenes'})), ""]
    total = 0
    for cat in ORDER:
        rs = [r for r in recs if r["category"] == cat]
        if not rs:
            continue
        out += [f"## {TITLES.get(cat, cat)}", "",
                "| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |",
                "|---|---|---|---|---|---|---|"]
        for r in rs:
            total += r["tris"]
            lod = str(r["lod1_tris"]) if r.get("lod1_tris") else "—"
            team = "yes" if r.get("team_colored") else ""
            use = r.get("use", "").replace("|", "/")
            out.append(f"| `{r['name']}` | {r['kind']} | {fmt_size(r['size_studs_roblox_XYZ'])} | {r['tris']} | "
                       f"{lod} | {team} | {use} |")
            for p in r.get("parts", []):
                out.append(f"| ↳ `{p['name']}` | MovingPart | {fmt_size(p['size_studs_roblox_XYZ'])} | {p['tris']} | "
                           f"— | | {p['pivot']} |")
        out.append("")
        notes = [r for r in rs if r.get("notes")]
        if notes:
            out.append("<details><summary>Notes</summary>\n")
            for r in notes:
                out.append(f"- `{r['name']}`: {r['notes']}")
            out.append("\n</details>\n")
    out.insert(3, f"**{sum(1 for r in recs if r['category'] != 'Scenes')} assets** "
                  f"(+ {sum(len(r.get('parts', [])) for r in recs)} separate moving parts), "
                  f"{total:,} triangles in total.\n")
    return "\n".join(out) + "\n"


def pivots_md(recs):
    out = ["# Pivots, attachments and collision", "",
           "All positions below are in the asset's own Roblox space (studs; X right, Y up, -Z front). "
           "Attachment objects are exported as `<Name>_Att` meshes, which Roblox's importer turns into "
           "`Attachment` instances. `Roblox/SurvivalHourAssetData.lua` has the same data as CFrames, "
           "so `SurvivalHourSetup.lua` can rebuild any that are missing.", ""]
    for cat in ORDER:
        rs = [r for r in recs if r["category"] == cat]
        if not rs:
            continue
        out += [f"## {TITLES.get(cat, cat)}", ""]
        for r in rs:
            out.append(f"### `{r['name']}`")
            out.append(f"- Pivot: {r.get('pivot', '')}")
            fp = r.get("footprint_studs")
            if fp and r["kind"] in ("Structure", "WorldProp", "Harvestable", "Lobby"):
                out.append(f"- Footprint: {fp[0]:.1f} × {fp[1]:.1f} studs (X × Z)")
            if r.get("attachments"):
                out.append("- Attachments: " + ", ".join(
                    f"`{a['name']}` ({a['cframe'][0]:.2f}, {a['cframe'][1]:.2f}, {a['cframe'][2]:.2f})"
                    for a in r["attachments"]))
            if r.get("collision_boxes"):
                out.append(f"- Collision: {len(r['collision_boxes'])} box(es) → `{r['files'].get('collision', 'data only')}`; "
                           f"fallback CollisionFidelity **{r.get('collision_fidelity')}**")
            else:
                out.append(f"- Collision: CollisionFidelity **{r.get('collision_fidelity')}**"
                           + (" (or CanCollide off for decor)" if r['kind'] in ('WorldProp', 'Effect') else ""))
            for p in r.get("parts", []):
                c = p["placement_cframe"]
                out.append(f"- Part `{p['name']}` rests at ({c[0]:.2f}, {c[1]:.2f}, {c[2]:.2f}): {p['pivot']}")
            if r.get("meta", {}).get("climb_volume"):
                out.append("- Climb volume (TrussPart): see catalog.json `meta.climb_volume`")
            out.append("")
    return "\n".join(out) + "\n"


def rigs_md(recs):
    out = ["# Rigs and animations", "",
           "Each creature is one skinned mesh plus an armature. Following Roblox's rigging specs, the root bone "
           "`Root` is at (0,0,0) and has no skin influence, each vertex has at most 4 influences (these rigs use "
           "3 or fewer), and bones rest at identity. Roblox allows one animation track per FBX, so every clip is "
           "its own file under `Export/Animations/<Creature>/`. Clips are 30 fps.", ""]
    for r in [r for r in recs if r["kind"] == "Rig"]:
        out += [f"## `{r['name']}`", "", r["use"], "",
                f"- Mesh: {r['tris']} tris, 1 material. {r['notes']}",
                f"- Rig file: `{r['files']['fbx']}`",
                f"- Hitboxes (`{r['files'].get('collision')}`): " + ", ".join(
                    f"{b['name']} {fmt_size(b['size'])} at ({b['cframe'][0]:.1f}, {b['cframe'][1]:.1f}, {b['cframe'][2]:.1f})"
                    for b in r["collision_boxes"]),
                f"- Movement collider suggestion: {fmt_size(r['movement_collider']['size'])} at "
                f"({r['movement_collider']['cframe'][0]:.1f}, {r['movement_collider']['cframe'][1]:.1f}, "
                f"{r['movement_collider']['cframe'][2]:.1f})",
                "- Bones: " + ", ".join(f"`{b['name']}`" for b in r["bones"]), "",
                "| Clip | Frames | Seconds | Loop | File |", "|---|---|---|---|---|"]
        for a in r["animations"]:
            out.append(f"| {a['name']} | {a['frames']} | {a['seconds']} | {'yes' if a['loop'] else 'no'} | `{a['file']}` |")
        out.append("")
    return "\n".join(out) + "\n"


def lua_value(v, ind=1):
    pad = "\t" * ind
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(v, 4)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        if all(isinstance(x, (int, float)) for x in v):
            return "{" + ", ".join(lua_value(x) for x in v) + "}"
        return "{\n" + ",\n".join(pad + lua_value(x, ind + 1) for x in v) + "\n" + "\t" * (ind - 1) + "}"
    if isinstance(v, dict):
        items = []
        for k, x in v.items():
            key = k if k.isidentifier() else f"[{json.dumps(k)}]"
            items.append(f"{pad}{key} = {lua_value(x, ind + 1)}")
        return "{\n" + ",\n".join(items) + "\n" + "\t" * (ind - 1) + "}"
    return "nil"


def data_table(recs):
    keep = {}
    for r in recs:
        if r["category"] == "Scenes":
            continue
        e = dict(Kind=r["kind"], Category=r["category"], Size=r["size_studs_roblox_XYZ"], Tris=r["tris"],
                 OriginOffset=r.get("origin_offset", [0, 0, 0]),
                 CollisionFidelity=r.get("collision_fidelity", "Box"), TeamColored=bool(r.get("team_colored")),
                 Attachments={a["name"][:-4]: a["cframe"] for a in r.get("attachments", [])},
                 CollisionBoxes=[dict(CFrame=b["cframe"], Size=b["size"], **({"Name": b["name"]} if "name" in b else {}))
                                 for b in r.get("collision_boxes", [])],
                 Parts={p["name"]: dict(Placement=p["placement_cframe"], OriginOffset=p.get("origin_offset", [0, 0, 0]),
                                        Attachments={a["name"][:-4]: a["cframe"] for a in p.get("attachments", [])},
                                        CollisionBoxes=[dict(CFrame=b["cframe"], Size=b["size"])
                                                        for b in p.get("collision_boxes", [])])
                        for p in r.get("parts", [])})
        if r.get("meta", {}).get("r15_attachment"):
            e["R15Attachment"] = r["meta"]["r15_attachment"]
        if r["kind"] == "Rig":
            e["Animations"] = {a["name"]: dict(Frames=a["frames"], Loop=a["loop"]) for a in r["animations"]}
            e["MovementCollider"] = dict(CFrame=r["movement_collider"]["cframe"], Size=r["movement_collider"]["size"])
        keep[r["name"]] = e
    return keep


def data_lua(recs):
    keep = data_table(recs)
    head = ("--!strict\n-- Survival Hour asset data. GENERATED by blender/make_docs.py; do not edit by hand.\n"
            "-- CFrames are {x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22} in the asset's local space.\n"
            "-- Build one with CFrame.new(table.unpack(t)).\n\n")
    return head + "return " + lua_value(keep) + "\n"


def lua_compact(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        x = round(float(v), 3)
        return str(int(x)) if x == int(x) else repr(x)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "{" + ",".join(lua_compact(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ",".join((k if k.isidentifier() else f"[{json.dumps(k)}]") + "=" + lua_compact(x)
                              for k, x in v.items()) + "}"
    return "nil"


def command_bar_script(data_table):
    with open(os.path.join(ROOT, "blender", "roblox_setup_template.lua")) as f:
        tpl = f.read()
    return tpl.replace("--@@DATA@@", lua_compact(data_table))


def main():
    with open(CAT) as f:
        recs = json.load(f)
    os.makedirs(os.path.join(ROOT, "Docs"), exist_ok=True)
    with open(os.path.join(ROOT, "Docs", "CATALOG.md"), "w") as f:
        f.write(catalog_md(recs))
    with open(os.path.join(ROOT, "Docs", "PIVOTS_ATTACHMENTS.md"), "w") as f:
        f.write(pivots_md(recs))
    with open(os.path.join(ROOT, "Docs", "RIGS_ANIMATIONS.md"), "w") as f:
        f.write(rigs_md(recs))
    with open(os.path.join(ROOT, "Roblox", "SurvivalHourAssetData.lua"), "w") as f:
        f.write(data_lua(recs))
    full = command_bar_script(data_table(recs))
    with open(os.path.join(ROOT, "Roblox", "SurvivalHour_CommandBarSetup.lua"), "w") as f:
        f.write(full)
    # same script without the instruction header, for pasting straight into the Command Bar
    body = full[full.index("]]") + 2:].lstrip()
    with open(os.path.join(ROOT, "Roblox", "SurvivalHour_Paste.lua"), "w") as f:
        f.write(body)
    print("docs written for", len(recs), "records")


if __name__ == "__main__":
    main()
