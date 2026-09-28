"""Check that rebuilt meshes keep the bounds the game was published with.

The loader (AssetLoaderService + Logic/AssetFit) forces every uploaded mesh to the
Size and Offset in src/shared/AssetIds.luau. A reworked model whose bounding box
changes would be stretched or shifted, whichever version is live on Roblox, so
model polish keeps each asset's outer bounds (and its origin inside them) fixed.

    python3 tools/check_bounds.py            # every asset
    python3 tools/check_bounds.py SM_A SM_B  # only these
Exit code 1 when any asset drifts by more than TOL studs.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOL = 0.03


def published():
    src = open(os.path.join(ROOT, "src", "shared", "AssetIds.luau")).read()
    out = {}
    for m in re.finditer(r'\["(\w+)"\] = \{ Id = \d+,.*?Size = \{([^}]*)\}, Offset = \{([^}]*)\}', src):
        out[m.group(1)] = ([float(v) for v in m.group(2).split(",")], [float(v) for v in m.group(3).split(",")])
    return out


def main():
    only = set(sys.argv[1:])
    pub = published()
    cat = {r["name"]: r for r in json.load(open(os.path.join(ROOT, "Roblox", "catalog.json")))
           if "size_studs_roblox_XYZ" in r}
    bad = 0
    for name, (size, off) in sorted(pub.items()):
        if only and name not in only:
            continue
        r = cat.get(name)
        if not r:
            continue
        ds = max(abs(a - b) for a, b in zip(size, r["size_studs_roblox_XYZ"]))
        do = max(abs(a - b) for a, b in zip(off, r["origin_offset"]))
        if ds > TOL or do > TOL:
            bad += 1
            print(f"DRIFT {name}: size {size} -> {r['size_studs_roblox_XYZ']}  offset {off} -> {r['origin_offset']}")
    print(f"{bad} asset(s) drifted" if bad else "bounds OK")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
