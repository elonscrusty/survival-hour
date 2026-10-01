"""Upload Egg Farm's original models (FBX) and sounds (WAV) to Roblox with Open Cloud.

    python3 tools/upload_assets.py [--creator-user-id N] [--only Name,Name]

Needs an Open Cloud API key with asset write permission (the cloud build environment injects it
through its proxy; elsewhere set ROBLOX_API_KEY). Results go to assets/uploaded_ids.json
(name -> asset id); names already listed there are skipped, so re-running is safe.
"""
import argparse, json, os, subprocess, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "uploaded_ids.json")
API = "https://apis.roblox.com/assets/v1"


def curl(args):
    key = os.environ.get("ROBLOX_API_KEY")
    hdr = ["-H", "x-api-key: " + key] if key else []
    r = subprocess.run(["curl", "-sS", "--retry", "3"] + hdr + args, capture_output=True, text=True)
    try:
        return json.loads(r.stdout)
    except Exception:
        return {"error": (r.stdout + r.stderr)[:400]}


def wait(op_id):
    for _ in range(100):
        time.sleep(3)
        st = curl([API + "/operations/" + op_id])
        if st.get("done"):
            return (st.get("response") or {}).get("assetId"), st
    return None, {"error": "timed out", "operation": op_id}


def upload(path, kind, name, creator):
    ctype = {"Model": "model/fbx", "Audio": "audio/wav"}[kind]
    req = {"assetType": kind, "displayName": "EggFarm " + name,
           "description": "Egg Farm original asset (" + name + ")",
           "creationContext": {"creator": {"userId": str(creator)}}}
    op = curl(["-X", "POST", API + "/assets",
               "-F", "request=" + json.dumps(req) + ";type=application/json",
               "-F", "fileContent=@" + path + ";type=" + ctype])
    if "operationId" not in op:
        return None, op
    return wait(op["operationId"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--creator-user-id", default="20194281")  # kcdrewcarter
    ap.add_argument("--only", default="")
    ap.add_argument("--operation", default="", help="name=operationId of an earlier upload to resolve")
    a = ap.parse_args()
    only = set(filter(None, a.only.split(",")))
    done = json.load(open(OUT)) if os.path.exists(OUT) else {"models": {}, "audio": {}}

    if a.operation:
        name, op_id = a.operation.split("=", 1)
        aid, info = wait(op_id)
        if aid:
            done["models"][name] = int(aid)
            json.dump(done, open(OUT, "w"), indent=2, sort_keys=True)
            print("ok   Model", name, aid, "(earlier upload)", flush=True)
        else:
            print("FAIL Model", name, json.dumps(info)[:300], flush=True)

    jobs = []
    exp = os.path.join(ROOT, "assets", "export")
    for f in sorted(os.listdir(exp)):
        if f.endswith(".fbx"):
            jobs.append(("Model", "models", f[:-4], os.path.join(exp, f)))
    aud = os.path.join(ROOT, "assets", "audio")
    for f in sorted(os.listdir(aud)):
        if f.endswith(".wav"):
            jobs.append(("Audio", "audio", f[:-4], os.path.join(aud, f)))
    for kind, group, name, path in jobs:
        if (only and name not in only) or name in done[group]:
            continue
        aid, info = upload(path, kind, name, a.creator_user_id)
        if aid:
            done[group][name] = int(aid)
            json.dump(done, open(OUT, "w"), indent=2, sort_keys=True)
            print("ok  ", kind, name, aid, flush=True)
        else:
            print("FAIL", kind, name, json.dumps(info)[:300], flush=True)


if __name__ == "__main__":
    main()
