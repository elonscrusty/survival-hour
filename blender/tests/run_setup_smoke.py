"""Build and run a Luau smoke test of Roblox/SurvivalHour_CommandBarSetup.lua
against the Roblox API mock (needs the `luau` CLI on PATH or LUAU env var)."""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
recs = [r for r in json.load(open(os.path.join(ROOT, "Roblox", "catalog.json"))) if r["category"] != "Scenes"]
mock = open(os.path.join(ROOT, "blender", "tests", "mock_roblox.luau")).read()
mock = mock[:mock.rindex("return {")]
script = open(os.path.join(ROOT, "Roblox", "SurvivalHour_CommandBarSetup.lua")).read()

skip = "SM_Pickup_Rope"  # deliberately 'not imported' to test the missing report
pop = ["-- populate a fake import"]
for r in recs:
    if r["name"] == skip:
        continue
    n = r["name"]
    pop.append(f'do local m = new("Model", "{n}"); m.Parent = workspace; local mp = new("MeshPart", "{n}"); mp.Parent = m')
    for a in r.get("attachments", []):
        pop.append(f'  new("Attachment", "{a["name"]}").Parent = mp')
    if r["kind"] == "Rig":
        pop.append('  local rp = new("Part", "RootPart"); rp.Parent = m')
        pop.append('  local b = new("Bone", "Root"); b.Parent = rp')
        for bn in ("Hips", "Body", "Head"):
            pop.append(f'  new("Bone", "{bn}").Parent = b')
    pop.append("end")
    for p in r.get("parts", []):
        pop.append(f'do local m = new("Model", "{p["name"]}"); m.Parent = workspace; new("MeshPart", "{p["name"]}").Parent = m end')
pop.append('new("MeshPart", "Fire_Att").Parent = workspace  -- stray marker the importer did not convert')

checks = """
local SS = game:GetService("ServerStorage")
local root = SS:FindFirstChild("SurvivalHour")
assert(root, "no ServerStorage.SurvivalHour")
local counts = {Tool = 0, Accessory = 0, Model = 0}
for _, cat in root:GetChildren() do
  for _, item in cat:GetChildren() do
    counts[item.ClassName] = (counts[item.ClassName] or 0) + 1
  end
end
print(string.format("SMOKE: tools=%d accessories=%d models=%d", counts.Tool, counts.Accessory, counts.Model))
local gate = root.Crafting_L2:FindFirstChild("SM_Gate")
assert(gate and gate:FindFirstChild("SM_Gate_Door"), "gate door not placed in gate model")
local axe = root.Crafting_L1:FindFirstChild("StoneAxe")
assert(axe and axe:FindFirstChild("Handle") and axe.Grip, "stone axe tool incomplete")
local pistol = root.Firearms:FindFirstChild("Pistol")
assert(pistol and pistol:FindFirstChild("SM_Pistol_Slide"), "pistol slide missing")
local wolf = root.Wildlife:FindFirstChild("SK_Wolf")
assert(wolf and wolf:FindFirstChildOfClass("AnimationController"), "wolf rig not prepared")
assert(wolf:FindFirstChild("Hitbox_Head"), "wolf head hitbox missing")
local helm = root.Armor:FindFirstChild("Armor_Helmet")
assert(helm and helm.Handle:FindFirstChild("HatAttachment"), "helmet attachment missing")
local wall = root.Crafting_L1:FindFirstChild("SM_WoodenWall")
assert(wall and wall:FindFirstChild("Collision1"), "wall collision missing")
assert(wall.SM_WoodenWall:FindFirstChild("SnapLeft"), "wall attachment not renamed")
assert(workspace:FindFirstChild("SurvivalHour_Showcase"), "showcase missing")
print("SMOKE: all checks passed")
"""
src = mock + "\n" + "\n".join(pop) + "\n" + "do\n" + script + "\nend\n" + checks
path = os.path.join(ROOT, "blender", "tests", "_smoke_run.luau")
open(path, "w").write(src)
luau = os.environ.get("LUAU", "luau")
res = subprocess.run([luau, path], capture_output=True, text=True)
print(res.stdout[-3000:], res.stderr[-3000:])
os.remove(path)
sys.exit(res.returncode)
