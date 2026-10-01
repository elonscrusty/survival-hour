#!/usr/bin/env python3
"""Upload the Blender exports (FBX -> Model assets) and icon/sky PNGs (-> Decal assets) to Roblox
with Open Cloud, then regenerate src/shared/AssetIds.luau.

    export ROBLOX_API_KEY=...            # Open Cloud key with asset read+write for the creator
    python3 tools/upload_assets.py --user 20194281 [--only Name,Name] [--images] [--models] [--dry-run]
    # Claude Code cloud: store the key as an environment API credential for apis.roblox.com
    # (header x-api-key, no prefix) and run with --proxy-auth; the key never enters the session.

- Skips files whose SHA-256 matches the last upload (assets/uploaded_ids.json), so reruns are cheap.
- Never prints or stores the key. Delete the key from the Creator Dashboard when finished.
- The game loads models with InsertService, which only works for assets owned by the experience's
  owner: upload with the same account that publishes the game.
"""
import argparse, hashlib, json, mimetypes, os, sys, time, urllib.request, uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IDS = os.path.join(ROOT, "assets", "uploaded_ids.json")
API = "https://apis.roblox.com/assets/v1"


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def multipart(fields, file_field, path, ctype):
    boundary = uuid.uuid4().hex
    body = b""
    for k, v in fields.items():
        body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
    with open(path, "rb") as f:
        data = f.read()
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{file_field}\"; filename=\"{os.path.basename(path)}\"\r\nContent-Type: {ctype}\r\n\r\n".encode() + data + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    return body, f"multipart/form-data; boundary={boundary}"


def call(method, url, key, body=None, ctype=None):
    req = urllib.request.Request(url, data=body, method=method)
    if key:  # empty when the environment's API credential adds the header (key never visible here)
        req.add_header("x-api-key", key)
    if ctype:
        req.add_header("Content-Type", ctype)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode() or "{}")


def upload(path, kind, name, user, key):
    asset_type = "Model" if kind == "models" else "Decal"
    ctype = "model/fbx" if path.endswith(".fbx") else (mimetypes.guess_type(path)[0] or "image/png")
    request = {
        "assetType": asset_type,
        "displayName": f"SellHotDogs {name}"[:50],
        "description": "Sell Hot Dogs original asset",
        "creationContext": {"creator": {"userId": str(user)}},
    }
    body, bct = multipart({"request": json.dumps(request)}, "fileContent", path, ctype)
    op = call("POST", f"{API}/assets", key, body, bct)
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(60):
        res = call("GET", f"{API}/operations/{op_id}", key)
        if res.get("done"):
            return res["response"]["assetId"]
        time.sleep(2)
    raise RuntimeError(f"upload of {name} timed out")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--user", required=True, help="Roblox user id that owns the assets (Carter: 20194281)")
    ap.add_argument("--only", default="")
    ap.add_argument("--models", action="store_true")
    ap.add_argument("--images", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--proxy-auth", action="store_true", help="the cloud environment's API credential adds the x-api-key header")
    a = ap.parse_args()
    both = not a.models and not a.images
    key = os.environ.get("ROBLOX_API_KEY", "")
    if not key and not a.dry_run and not a.proxy_auth:
        sys.exit("Set ROBLOX_API_KEY, or add the key as an API credential for apis.roblox.com and pass --proxy-auth.")
    only = {x for x in a.only.split(",") if x}
    state = json.load(open(IDS)) if os.path.exists(IDS) else {"models": {}, "images": {}}
    jobs = []
    if a.models or both:
        for f in sorted(os.listdir(os.path.join(ROOT, "assets", "exports"))):
            if f.endswith(".fbx"):
                jobs.append(("models", f[:-4], os.path.join(ROOT, "assets", "exports", f)))
    if a.images or both:
        for sub in ("icons", "sky"):
            d = os.path.join(ROOT, "assets", sub)
            if os.path.isdir(d):
                for f in sorted(os.listdir(d)):
                    if f.endswith(".png") and not f.endswith("_sheet.png"):
                        jobs.append(("images", f[:-4], os.path.join(d, f)))
    done = 0
    for kind, name, path in jobs:
        if only and name not in only:
            continue
        h = sha(path)
        prev = state[kind].get(name)
        if prev and prev.get("sha") == h:
            continue
        if a.dry_run:
            print("would upload", kind, name)
            continue
        try:
            asset_id = upload(path, kind, name, a.user, key)
        except Exception as e:  # keep going; report at the end
            print("FAILED", kind, name, e)
            continue
        state[kind][name] = {"id": int(asset_id), "sha": h}
        done += 1
        print("uploaded", kind, name, asset_id)
        json.dump(state, open(IDS, "w"), indent=1, sort_keys=True)
    print(f"{done} uploaded")
    os.system(f"{sys.executable} {os.path.join(ROOT, 'tools', 'gen_asset_ids.py')}")


if __name__ == "__main__":
    main()
