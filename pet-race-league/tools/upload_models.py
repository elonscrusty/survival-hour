"""Upload the model FBX files to Roblox with Open Cloud, then regenerate Models.luau.

    ROBLOX_API_KEY=... ROBLOX_USER_ID=... python3 tools/upload_models.py [--only Pet_Pup,Rock] [--force]
    (or ROBLOX_GROUP_ID=... instead of ROBLOX_USER_ID if the game belongs to a group)

The API key needs the "Assets: read + write" permission (Creator Dashboard →
Open Cloud → API Keys). Upload from the same account or group that owns the game:
the game can only load models its owner uploaded. Ids are saved to
models/uploaded_ids.json as each upload finishes, so a rerun skips finished ones.
Delete the API key when you're done.
"""
import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FBX_DIR = os.path.join(ROOT, "models", "fbx")
IDS = os.path.join(ROOT, "models", "uploaded_ids.json")
API = "https://apis.roblox.com/assets/v1"


def request(method, url, key, body=None, ctype=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if ctype:
        req.add_header("Content-Type", ctype)
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode() or "{}")
        except urllib.error.HTTPError as e:
            text = e.read().decode(errors="replace")
            if e.code == 429 or e.code >= 500:
                time.sleep(2 ** attempt * 2)
                continue
            raise RuntimeError(f"HTTP {e.code}: {text}")
        except urllib.error.URLError:
            time.sleep(2 ** attempt * 2)
    raise RuntimeError("gave up after retries")


def upload(name, path, key, creator):
    meta = {
        "assetType": "Model",
        "displayName": f"PRL {name}",
        "description": "Pet Race League model",
        "creationContext": {"creator": creator},
    }
    boundary = uuid.uuid4().hex
    data = open(path, "rb").read()
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n"
        f"Content-Type: application/json\r\n\r\n{json.dumps(meta)}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.fbx\"\r\n"
        f"Content-Type: model/fbx\r\n\r\n"
    ).encode() + data + f"\r\n--{boundary}--\r\n".encode()
    op = request("POST", f"{API}/assets", key, body, f"multipart/form-data; boundary={boundary}")
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", f"{API}/operations/{op_id}", key)
    if not op.get("done"):
        raise RuntimeError("upload still processing after 2 minutes; rerun later")
    if "error" in op:
        raise RuntimeError(json.dumps(op["error"]))
    return int(op["response"]["assetId"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true", help="re-upload models that already have an id")
    args = ap.parse_args()
    key = os.environ.get("ROBLOX_API_KEY")
    user, group = os.environ.get("ROBLOX_USER_ID"), os.environ.get("ROBLOX_GROUP_ID")
    if not key or not (user or group):
        sys.exit("Set ROBLOX_API_KEY and ROBLOX_USER_ID (or ROBLOX_GROUP_ID).")
    creator = {"groupId": str(group)} if group else {"userId": str(user)}
    only = {s.strip() for s in args.only.split(",") if s.strip()}
    ids = json.load(open(IDS)) if os.path.exists(IDS) else {}
    names = sorted(f[:-4] for f in os.listdir(FBX_DIR) if f.endswith(".fbx"))
    failed = []
    for name in names:
        if only and name not in only:
            continue
        if name in ids and not args.force:
            continue
        try:
            ids[name] = upload(name, os.path.join(FBX_DIR, name + ".fbx"), key, creator)
            print(f"  {name:<16} -> {ids[name]}")
            with open(IDS, "w") as f:
                json.dump(ids, f, indent=1, sort_keys=True)
        except Exception as e:  # keep going; report at the end
            failed.append(name)
            print(f"  {name:<16} FAILED: {e}")
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gen_models.py")], check=True)
    if failed:
        sys.exit(f"{len(failed)} failed: {', '.join(failed)} (rerun to retry)")


if __name__ == "__main__":
    main()
