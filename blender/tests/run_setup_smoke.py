"""Build and run a Luau smoke test of Roblox/SurvivalHour_CommandBarSetup.lua
against the Roblox API mock (needs the `luau` CLI on PATH or LUAU env var)."""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
recs = [r for r in json.load(open(os.path.join(ROOT, "Roblox", "catalog.json"))) if r["category"] != "Scenes"]
mock = open(os.path.join(ROOT, "blender", "tests", "mock_roblox.luau")).read()
mock = mock[:mock.rindex("return {")]
script = open(os.path.join(ROOT, "Roblox", "SurvivalHour_Paste.lua")).read()
mapscript = open(os.path.join(ROOT, "Roblox", "SurvivalHour_BuildMap.lua")).read()

skip = {"SM_Pickup_Rope", "SM_Rifle"}  # deliberately 'not imported' on the first run
def populate(r, lines):
    n = r["name"]
    if r["kind"] in ("Equippable", "Accessory"):
        # importer variant: Tool/Accessory named after the file, mesh called Handle, in StarterPack
        cls = "Tool" if r["kind"] == "Equippable" else "Accessory"
        lines.append(f'do local m = new("{cls}", "{n}"); m.Parent = game:GetService("StarterPack"); '
                     f'local mp = new("MeshPart", "Handle"); mp.Parent = m')
    elif n == "SM_Sword":
        lines.append(f'do local mp = new("MeshPart", "SM_Sword.001"); mp.Parent = workspace')
    else:
        lines.append(f'do local m = new("Model", "{n}"); m.Parent = workspace; local mp = new("MeshPart", "{n}"); mp.Parent = m')
    return lines

pop = ["-- populate a fake import"]
second = ["-- second import: the files that were missing"]
for r in recs:
    n = r["name"]
    target = second if n in skip else pop
    populate(r, target)
    for a in r.get("attachments", []):
        target.append(f'  new("Attachment", "{a["name"]}").Parent = mp')
    if r["kind"] == "Rig":
        target.append('  local rp = new("Part", "RootPart"); rp.Parent = m')
        target.append('  local b = new("Bone", "Root"); b.Parent = rp')
        for bn in ("Hips", "Body", "Head"):
            target.append(f'  new("Bone", "{bn}").Parent = b')
    target.append("end")
    for p in r.get("parts", []):
        target.append(f'do local m = new("Model", "{p["name"]}"); m.Parent = workspace; new("MeshPart", "{p["name"]}").Parent = m end')
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
local sword = root.Crafting_L3:FindFirstChild("Sword")
assert(sword and sword:FindFirstChild("Handle"), "renamed SM_Sword.001 not picked up")
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
mapcheck = """
local map = workspace:FindFirstChild("SurvivalHourMap")
assert(map and map:FindFirstChild("Camp_Red") and map:FindFirstChild("Forest"), "map not built")
local camp = map.Camp_Red
assert(camp:FindFirstChild("SM_Campfire_Burning") and camp:FindFirstChild("SM_Workbench_Level01"), "camp incomplete")
local n = #map:GetDescendants()
print("SMOKE: map built, " .. n .. " instances; forest items " .. #map.Forest:GetChildren())
"""
rerun = """
local stock = #game:GetService("ServerStorage").SurvivalHour.Firearms:GetChildren()
assert(stock == 2, "first run should have 2 firearms (rifle missing), got " .. stock)
"""
recheck = """
assert(#game:GetService("ServerStorage").SurvivalHour.Firearms:GetChildren() == 3, "rerun should add the rifle only")
assert(#game:GetService("ServerStorage").SurvivalHour.Crafting_L3:GetChildren() == 5, "rerun must not duplicate")
print("SMOKE: rerun picked up the missing files without duplicates")
"""
src = (mock + "\n" + "\n".join(pop) + "\ndo\n" + script + "\nend\n" + rerun + "\n".join(second)
       + "\ndo\n" + script + "\nend\n" + recheck + checks + "\ndo\n" + mapscript + "\nend\n" + mapcheck)
path = os.path.join(ROOT, "blender", "tests", "_smoke_run.luau")
open(path, "w").write(src)
luau = os.environ.get("LUAU", "luau")
res = subprocess.run([luau, path], capture_output=True, text=True)
print(res.stdout[-3000:], res.stderr[-3000:])
os.remove(path)
sys.exit(res.returncode)
