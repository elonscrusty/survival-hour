"""Pet Expedition model generator (single source of truth for every model).

  python3 models/gen_models.py          # writes src/shared/Models/ModelData.luau and WorldData.luau

Every pet, egg, breakable, prop and the world layout are lists of primitive
parts (see lib.py). This script writes them as plain Luau data tables (no
Roblox types) that Models/init.luau and Models/World.luau build at runtime.
render.py imports this module to render previews of exactly the same data.

Pet, egg and area ids are read from src/shared/{Pets,Eggs,Areas}.luau so the
generator fails loudly if the catalogue gains an entry without a model.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib as L  # noqa: E402
import pets as PETS  # noqa: E402
import items as ITEMS  # noqa: E402
import world as WORLD  # noqa: E402

ROOT = os.path.dirname(HERE)
SHARED = os.path.join(ROOT, "src", "shared")
OUT_MODELS = os.path.join(SHARED, "Models", "ModelData.luau")
OUT_WORLD = os.path.join(SHARED, "Models", "WorldData.luau")

RARITY_HEIGHT = {"Common": 2.6, "Uncommon": 2.9, "Rare": 3.2, "Epic": 3.6, "Legendary": 4.0, "Mythic": 4.5}
MAX_PET_PARTS = 45
BREAKABLE_KINDS = ["CoinPile", "Crate", "Chest", "GemRock", "BigChest"]
EGG_STAND_SCALE = ITEMS.EGG_STAND_SCALE
T2, T3 = "\t\t", "\t\t\t"


# ------------------------------------------------------------------ catalogue
def _read(name):
    with open(os.path.join(SHARED, name), encoding="utf-8") as f:
        return f.read()


def parse_pets():
    out = {}
    for m in re.finditer(r'\{\s*Id\s*=\s*"(\w+)",\s*Name\s*=\s*"([^"]+)",\s*Rarity\s*=\s*"(\w+)",\s*Area\s*=\s*"(\w+)"', _read("Pets.luau")):
        out[m.group(1)] = {"Name": m.group(2), "Rarity": m.group(3), "Area": m.group(4)}
    return out


def parse_eggs():
    return re.findall(r'\{\s*Id\s*=\s*"(\w+)",\s*Name\s*=\s*"[^"]+",\s*Area', _read("Eggs.luau"))


def parse_areas():
    return re.findall(r'\{\s*Id\s*=\s*"(\w+)",\s*Index\s*=', _read("Areas.luau"))


PET_INFO = parse_pets()
EGG_IDS = parse_eggs()
AREAS = parse_areas()


# ------------------------------------------------------------------ build
_cache = {}


def build_all():
    if _cache:
        return _cache
    pets = {}
    missing = [p for p in PET_INFO if p not in PETS.BUILDERS]
    if missing:
        raise SystemExit(f"pets without a model builder: {missing}")
    for pid, info in PET_INFO.items():
        parts = PETS.BUILDERS[pid]()
        pets[pid] = L.normalize(parts, RARITY_HEIGHT[info["Rarity"]])
    eggs = {}
    for eid in EGG_IDS:
        if eid not in ITEMS.EGGS:
            print(f"WARNING: egg without a model: {eid}")
            continue
        eggs[eid] = L.normalize(ITEMS.EGGS[eid](), 3.0)
    breakables = {}
    for area in AREAS:
        for kind in BREAKABLE_KINDS:
            breakables[(kind, area)] = L.normalize(ITEMS.breakable(kind, area))
    props = {}
    for name, (fn, collide) in ITEMS.props().items():
        props[name] = {"parts": L.normalize(fn()), "collide": collide}
    world = WORLD.build(AREAS, props)
    _cache.update(pets=pets, eggs=eggs, breakables=breakables, props=props, world=world)
    return _cache


def egg_spot(parts):
    for p in parts:
        if p.tag == "EggSpot":
            return p.pos
    return (0, 4, 0)


# ------------------------------------------------------------------ variants (preview copy of Models/init.luau)
def _lum(c):
    r, g, b = L.hexc(c)
    return (0.3 * r + 0.59 * g + 0.11 * b) / 255


RAINBOW_HUES = [0.0, 0.08, 0.15, 0.33, 0.58, 0.76]


def variant_parts(parts, variant, shiny):
    """Python mirror of the runtime recolour in Models/init.luau (used only for previews)."""
    lo, hi = L.bounds(parts)
    h = max(0.01, hi[1] - lo[1])
    out = []
    for p in parts:
        q = p
        if p.tag != "Eye":
            if variant == "Golden" and p.tag != "Collar":
                t = max(0.0, min(1.0, _lum(p.col) * 0.6 + 0.3))
                col = L.mix(0xA66C0A, 0xFFCE4A, t)
                q = p.copy(col=0xFFD54A if p.mat == "N" else col, mat="N" if p.mat == "N" else "F")
            elif variant == "Rainbow" and p.tag not in ("Collar", "Face"):
                band = int((1 - (p.pos[1] - lo[1]) / h) / 0.15) % 6
                col = L.hsv(RAINBOW_HUES[band], 0.75, 0.97)
                q = p.copy(col=col, mat="N" if p.mat == "N" else "P")
            if shiny:
                q = q.copy(col=L.mix(q.col, 0xFFF6E0, 0.15))
        out.append(q)
    if shiny:
        import random
        rnd = random.Random(7)
        for _ in range(10):
            pos = (rnd.uniform(lo[0], hi[0]), rnd.uniform(lo[1], hi[1]) + 0.3, rnd.uniform(lo[2], hi[2]))
            out.append(L.ball(0.12, pos, 0xFFE680, "N"))
            out.append(L.box((0.03, 0.4, 0.03), pos, 0xFFD23C, "N"))
            out.append(L.box((0.4, 0.03, 0.03), pos, 0xFFD23C, "N"))
    return out


# ------------------------------------------------------------------ emit
def num(v, nd=3):
    s = f"{v:.{nd}f}".rstrip("0").rstrip(".")
    if s in ("-0", ""):
        s = "0"
    return s


def part_row(p):
    code, size, pos, R = p.native()
    ax, ay, az = L.to_euler_xyz(R)
    vals = [num(x) for x in size] + [num(x) for x in pos] + [num(ax, 1), num(ay, 1), num(az, 1)]
    row = f'{{"{code}",{",".join(vals)},0x{p.col:06X},"{p.mat}"'
    if p.tag or p.tr:
        row += f',"{p.tag or ""}"'
    if p.tr:
        row += f",{num(p.tr, 2)}"
    return row + "}"


def parts_block(parts, indent="\t\t"):
    return "{\n" + "".join(f"{indent}\t{part_row(p)},\n" for p in parts) + indent + "}"


def model_entry(parts, indent="\t\t", extra=""):
    lo, hi = L.bounds([p for p in parts if p.tr < 1] or parts)
    b = ",".join(num(hi[i] - lo[i]) for i in range(3))
    return f"{{ B = {{{b}}},{extra} P = {parts_block(parts, indent)} }}"


HEADER = """--!nocheck
-- GENERATED by models/gen_models.py. Do not edit by hand; edit the generator and re-run it.
-- Pure data (no Roblox types). Each part row:
--   { shape, sizeX, sizeY, sizeZ, posX, posY, posZ, rotX, rotY, rotZ, colour, material, tag?, transparency? }
-- shape: "B" block, "S" sphere mesh (ellipsoid), "C" cylinder (axis X), "W" wedge.
-- rot: degrees for CFrame.fromEulerAnglesXYZ. material: code, see MATS in Models/init.luau.
-- Positions are relative to the model pivot (bottom centre, facing -Z). B = bounding box size.
"""


def write_models(data):
    out = [HEADER, "return {\n"]
    out.append("\tPets = {\n")
    for pid in PET_INFO:
        out.append(f"\t\t{pid} = {model_entry(data['pets'][pid], T2)},\n")
    out.append("\t},\n\tEggs = {\n")
    for eid in EGG_IDS:
        out.append(f"\t\t{eid} = {model_entry(data['eggs'][eid], T2)},\n")
    out.append("\t},\n\tBreakables = {\n")
    for area in AREAS:
        out.append(f"\t\t{area} = {{\n")
        for kind in BREAKABLE_KINDS:
            out.append(f"\t\t\t{kind} = {model_entry(data['breakables'][(kind, area)], T3)},\n")
        out.append("\t\t},\n")
    out.append("\t},\n\tProps = {\n")
    for name, prop in data["props"].items():
        out.append(f"\t\t{name} = {model_entry(prop['parts'], T2, ' C = ' + ('true' if prop['collide'] else 'false') + ',')},\n")
    out.append("\t},\n}\n")
    text = "".join(out)
    with open(OUT_MODELS, "w", encoding="utf-8") as f:
        f.write(text)
    return len(text)


def v3(v):
    return "{" + ",".join(num(x, 2) for x in v) + "}"


def write_world(data):
    w = data["world"]
    out = [HEADER.replace("Positions are relative to the model pivot (bottom centre, facing -Z). B = bounding box size.",
                          "World coordinates. Ground top is y = 0."), "return {\n"]
    out.append(f"\tIslandSpacing = {num(w['spacing'])},\n")
    out.append("\tWater = { " + ", ".join(f"{k} = {num(v)}" for k, v in w["water"].items()) + " },\n")
    out.append("\tCenters = { " + ", ".join(f"{a} = {num(w['centers'][a])}" for a in AREAS) + " },\n")
    out.append("\tRadius = { " + ", ".join(f"{a} = {num(w['radius'][a])}" for a in AREAS) + " },\n")
    out.append("\tSpawns = {\n")
    for a in AREAS:
        out.append(f"\t\t{a} = {v3(w['spawns'][a])},\n")
    out.append("\t},\n\tSpawnLocation = " + v3(w["spawn_location"]) + ",\n")
    ar = w["arena"]
    out.append("\tArena = { C = " + v3(ar["center"]) + ", R = " + num(ar["radius"]) + " },\n")
    out.append("\tZones = {\n")
    for a in AREAS:
        zs = ", ".join("{ C = " + v3(z["center"]) + ", S = " + v3(z["size"]) + " }" for z in w["zones"][a])
        out.append(f"\t\t{a} = {{ {zs} }},\n")
    out.append("\t},\n\tBounds = {\n")
    for a in AREAS:
        lo, hi = w["bounds"][a]
        out.append(f"\t\t{a} = {{ Min = {v3(lo)}, Max = {v3(hi)} }},\n")
    out.append("\t},\n\tParts = {\n")
    for group, parts in w["parts"].items():
        out.append(f"\t\t{group} = {parts_block(parts, T2)},\n")
    out.append("\t},\n\t-- { prop, x, y, z, yawDegrees, scale, area }\n\tPlace = {\n")
    for pl in w["place"]:
        name, x, y, z, yaw, s, area = pl
        out.append(f'\t\t{{"{name}",{num(x, 2)},{num(y, 2)},{num(z, 2)},{num(yaw, 1)},{num(s, 2)},"{area}"}},\n')
    out.append("\t},\n\tInteract = {\n")
    for it in w["interact"]:
        attrs = ", ".join(f'{k} = "{v}"' for k, v in it["attrs"].items())
        out.append(f'\t\t{{ Kind = "{it["kind"]}", Prop = "{it["prop"]}", Area = "{it["area"]}", P = {v3(it["pos"])}, '
                   f'Yaw = {num(it["yaw"], 1)}, A = {{ {attrs} }} }},\n')
    out.append("\t},\n}\n")
    text = "".join(out)
    with open(OUT_WORLD, "w", encoding="utf-8") as f:
        f.write(text)
    return len(text)


def report(data):
    lines = []
    worst = max(len(v) for v in data["pets"].values())
    lines.append(f"pets: {len(data['pets'])} (max {worst} parts)")
    for pid, parts in data["pets"].items():
        if len(parts) > MAX_PET_PARTS:
            raise SystemExit(f"{pid} has {len(parts)} parts (limit {MAX_PET_PARTS})")
    lines.append(f"eggs: {len(data['eggs'])} (max {max(len(v) for v in data['eggs'].values())} parts)")
    lines.append(f"breakables: {len(data['breakables'])} (max {max(len(v) for v in data['breakables'].values())} parts)")
    lines.append(f"props: {len(data['props'])}")
    lines.append(f"world parts (estimated, incl. props): {WORLD.count_parts(data['world'], data['props'], data['eggs'])}")
    return "\n".join(lines)


def main():
    data = build_all()
    n1 = write_models(data)
    n2 = write_world(data)
    print(report(data))
    print(f"wrote {os.path.relpath(OUT_MODELS, ROOT)} ({n1 // 1024} KB), {os.path.relpath(OUT_WORLD, ROOT)} ({n2 // 1024} KB)")


if __name__ == "__main__":
    main()
