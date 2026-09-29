"""Map uploaded icon images (Astra's file names) to game icon keys and merge them into
src/shared/IconIds.luau.

    python3 tools/map_icons.py icons.txt      # lines like "weapon_sword.png = 1019..."

Unknown names are listed at the end; existing entries are kept (a new id replaces an old one).
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "src", "shared")
OUT = os.path.join(SHARED, "IconIds.luau")


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def read(name):
    return open(os.path.join(SHARED, name), encoding="utf-8").read()


# name -> id tables from the game data
def items():
    s = read("Items.luau")
    out = {norm(n): i for i, n in re.findall(r'Id = "([A-Za-z0-9]+)", Name = "([^"]+)"', s)}
    for t in ("Crude", "Stone", "Iron", "Steel"):  # generated tool tiers
        out[norm(t + " Axe")] = t + "Axe"
        out[norm(t + " Pickaxe")] = t + "Pickaxe"
    return out


def simple(fname, pat=r'Id = "([A-Za-z0-9]+)", Name = "([^"]+)"'):
    return {norm(n): i for i, n in re.findall(pat, read(fname))}


def cosmetics():
    s = read("Cosmetics.luau")
    out = {}
    for i, n, t in re.findall(r'[cm]\("([A-Za-z0-9]+)", "([^"]+)", "([A-Za-z]+)"', s):
        out[norm(n)] = (i, t)
    for n, t in re.findall(r'Name = "([^"]+)", Type = "([A-Za-z]+)"', s):
        m = re.search(r'Id = "([A-Za-z0-9]+)", Name = "' + re.escape(n) + '"', s)
        if m:
            out[norm(n)] = (m.group(1), t)
    return out


ITEMS, CLASSES, PERKS, COSM = items(), simple("Classes.luau"), simple("Perks.luau"), cosmetics()
PRODUCTS = {norm(t): k for k, t in re.findall(r'Key = "([A-Za-z0-9]+)"[^\n]*Title = "([^"]+)"', read("Products.luau"))}
LOBBY = {"party": "Party", "class": "Class", "powerup": "PowerUp", "locker": "Locker", "profile": "Profile",
         "shop": "Shop", "howtoplay": "HowToPlay", "buycoins": "BuyCoins"}
HUD = {"aimblock": "Aim", "aim": "Aim", "attack": "Attack", "bag": "Bag", "build": "Build", "craft": "Craft",
       "heal": "Heal", "map": "Map", "run": "Run", "swap": "Swap"}
COSM_PREFIX = {"outfit": "", "nameplate": "nameplate", "toolskin": "", "backpackskin": "", "campfireskin": "",
               "workbenchskin": "", "storageskin": "", "emote": "", "eliminationfx": "", "victory": ""}


def key_for(stem):
    parts = stem.lower().split("_")
    # longest matching prefix first
    for n in range(min(3, len(parts) - 1), 0, -1):
        pre, rest = "".join(parts[:n]), parts[n:]
        r = "".join(rest)
        if pre in ("resource", "weapon", "tool", "ammo", "medical", "healing", "backpack", "pack", "structure",
                   "build", "armour", "armor", "explosive", "item"):
            cands = [r, r + "pack" if pre in ("backpack", "pack") else r]
            if pre in ("armour", "armor"):
                cands.append(r)
            for c in cands:
                if c in ITEMS:
                    return "Item_" + ITEMS[c]
        if pre in ("pickaxe", "axe"):
            c = r + pre
            if c in ITEMS:
                return "Item_" + ITEMS[c]
        if pre == "class" and r in CLASSES:
            return "Class_" + CLASSES[r]
        if pre in ("powerup", "perk") and r in PERKS:
            return "Perk_" + PERKS[r]
        if pre == "product":
            if r in PRODUCTS:
                return "Product_" + PRODUCTS[r]
            m = re.match(r"(\d+)coins", r)
            if m and norm(f"{int(m.group(1)):,} coins") in PRODUCTS:
                return "Product_" + PRODUCTS[norm(f"{int(m.group(1)):,} coins")]
        if pre == "lobby" and r in LOBBY:
            return "Lobby_" + LOBBY[r]
        if pre in ("match", "hud") and r in HUD:
            return "Hud_" + HUD[r]
        if pre == "currency":
            return "Currency_" + rest[0].capitalize()
        if pre in COSM_PREFIX:
            order = (r + "nameplate", r) if pre == "nameplate" else (r, r + "nameplate")
            for c in order:
                if c in COSM:
                    return "Cosmetic_" + COSM[c][0]
        # recorded for later hooks (no UI slot yet)
        extra = {"lockertab": "LockerTab_", "mapmarker": "MapMarker_", "notification": "Notify_",
                 "rarity": "Rarity_", "status": "Status_"}
        if pre in extra:
            return extra[pre] + "".join(p.capitalize() for p in rest)
    if stem.lower() == "title_scroll":
        return "Title_Scroll"
    return None


def main(path):
    existing = {}
    if os.path.exists(OUT):
        existing = dict(re.findall(r'\["([A-Za-z0-9_]+)"\] = (\d+)', open(OUT).read()))
    unknown = []
    for line in open(path, encoding="utf-8"):
        m = re.match(r"\s*([\w\-]+)\.png\s*=\s*(\d+)", line)
        if not m:
            continue
        k = key_for(m.group(1))
        if k:
            existing[k] = m.group(2)
        else:
            unknown.append(m.group(1))
    body = "\n".join(f'\t["{k}"] = {v},' for k, v in sorted(existing.items()))
    src = open(OUT).read()
    head = src.split("local IconIds")[0]
    open(OUT, "w").write(head + "local IconIds: { [string]: number } = {\n" + body + "\n}\n\nreturn IconIds\n")
    print(f"{len(existing)} icon ids in IconIds.luau")
    if unknown:
        print("unmatched:", ", ".join(unknown))


if __name__ == "__main__":
    main(sys.argv[1])
