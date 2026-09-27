--!nonstrict
-- Runs every skinned model builder against a mocked Roblox environment and a
-- fake mesh library generated from the pack catalog. Usage (project root):
--   luau tests/skins/run_skins.luau
-- Checks: meshes are added, procedural parts are hidden but keep collision,
-- state hooks (stump, yield, extinguish, damage, gate, parachute) work, held
-- items weld, and with the library disabled nothing changes.

local Mock = require("./RobloxMock")
local Data = require("./LibraryData")

Random = {
	new = function(seed)
		local s = seed or 1
		local function nxt()
			s = (s * 1103515245 + 12345) % 2147483648
			return s / 2147483648
		end
		return {
			NextNumber = function(_, a, b)
				a, b = a or 0, b or 1
				return a + (b - a) * nxt()
			end,
			NextInteger = function(_, a, b)
				return a + math.floor(nxt() * (b - a + 1))
			end,
		}
	end,
}

local RS = game:GetService("ReplicatedStorage")

-- fake library ----------------------------------------------------------------
local lib = Instance.new("Folder")
lib.Name = "SurvivalHourAssets"
lib.Parent = RS
local cats = {}
local function mesh(name, size, oo, at)
	local mp = Instance.new("MeshPart")
	mp.Name = name
	mp.Size = Vector3.new(size[1], size[2], size[3])
	mp.CFrame = at * CFrame.new(-oo[1], -oo[2], -oo[3])
	mp.PivotOffset = CFrame.new(oo[1], oo[2], oo[3])
	return mp
end
for _, e in Data do
	local cat = cats[e.cat]
	if not cat then
		cat = Instance.new("Folder")
		cat.Name = e.cat
		cat.Parent = lib
		cats[e.cat] = cat
	end
	if e.kind == "Equippable" then
		local t = Instance.new("Tool")
		t.Name = (string.gsub(e.name, "^SM_", ""))
		mesh("Handle", e.size, e.oo, CFrame.new()).Parent = t
		t.Grip = CFrame.new(e.oo[1], e.oo[2], e.oo[3])
		for _, p in e.parts do
			mesh(p.name, p.size, p.oo, CFrame.new(table.unpack(p.place))).Parent = t
		end
		t.Parent = cat
	elseif e.kind == "Accessory" then
		local a = Instance.new("Accessory")
		a.Name = (string.gsub(e.name, "^ACC_", ""))
		local h = mesh("Handle", e.size, e.oo, CFrame.new())
		h.Parent = a
		local att = Instance.new("Attachment")
		att.Name = e.r15
		att.CFrame = CFrame.new(e.oo[1], e.oo[2], e.oo[3])
		att.Parent = h
		a.Parent = cat
	else
		local m = Instance.new("Model")
		m.Name = e.name
		local mp = mesh(e.name, e.size, e.oo, CFrame.new())
		mp.Parent = m
		m.PrimaryPart = mp
		local col = Instance.new("Part")
		col.Name = "Collision1"
		col.Parent = m
		for _, p in e.parts do
			mesh(p.name, p.size, p.oo, CFrame.new(table.unpack(p.place))).Parent = m
		end
		m.Parent = cat
	end
end

local Skins = require("../../src/shared/Models/Skins")
local Nature = require("../../src/shared/Models/Nature")
local Flora = require("../../src/shared/Models/Flora")
local Camp = require("../../src/shared/Models/Camp")
local Structures = require("../../src/shared/Models/Structures")
local ItemModels = require("../../src/shared/Models/ItemModels")
local LootModels = require("../../src/shared/Models/LootModels")
local Animals = require("../../src/shared/Models/Animals")
local Refuge = require("../../src/shared/Models/Refuge")
local Decor = require("../../src/shared/Models/Decor")
local Landmarks = require("../../src/shared/Models/Landmarks")

-- helpers -----------------------------------------------------------------------
local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. " -> " .. tostring(err))
	end
end
local function check(v, msg)
	if not v then
		error(msg or "check failed", 2)
	end
end
local function skins(m)
	local out = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Skin") then
			table.insert(out, d)
		end
	end
	return out
end
local function visibleProcedural(m, keep)
	local n = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not d:GetAttribute("Skin") and d.Transparency < 1 and not d:GetAttribute("TeamTint")
			and not (keep and keep[d.Name]) then
			n += 1
		end
	end
	return n
end
local function skinOf(m, name)
	for _, d in skins(m) do
		if d:GetAttribute("SkinOf") == name then
			return d
		end
	end
	return nil
end
local function near(a, b, tol, msg)
	check(math.abs(a - b) <= (tol or 0.05), string.format("%s: %.3f vs %.3f", msg or "near", a, b))
end
local at = CFrame.new(20, 3, -7) * CFrame.Angles(0, 0.7, 0)

-- decor -------------------------------------------------------------------------
for _, case in {
	{ "Pine", function() return Nature.Pine(at, 1, workspace) end, 30 },
	{ "Oak", function() return Nature.Oak(at, 1, workspace) end, 28 },
	{ "Birch", function() return Nature.Birch(at, 1, workspace) end, 27 },
	{ "GrassClump", function() return Nature.GrassClump(at, workspace) end, 4 },
} do
	test("decor " .. case[1], function()
		local m = case[2]()
		local s = skins(m)
		check(#s >= 1, "no mesh")
		check(visibleProcedural(m) == 0, "procedural parts still visible")
		near(s[1].Size.Y, case[3], 0.05, "height")
		-- sits on the model's ground pivot
		near(s[1].Position.Y - s[1].Size.Y / 2, 3, 1.2, "mesh base on ground")
		check(not s[1].CanCollide and not s[1].CanQuery, "mesh must not collide/query")
	end)
end
test("decor Pine keeps trunk collision", function()
	local m = Nature.Pine(at, 1, workspace)
	check(m:FindFirstChild("Trunk").CanCollide, "trunk collision lost")
end)
test("decor Bush/BigRock/FallenGiant dressed", function()
	check(#skins(Nature.Bush(at, 1, workspace)) == 1, "bush")
	check(#skins(Nature.BigRock(at, 1, workspace)) == 1, "rock")
	check(skinOf(Nature.FallenGiant(at, workspace), "SM_Landmark_GiantLog"), "giant log")
end)

-- resource nodes ------------------------------------------------------------------
test("ResourceTree mesh in Top + hidden stump", function()
	for _, sp in { "Pine", "Oak", "Birch" } do
		for _, size in { "Small", "Medium", "Large" } do
			local m = Flora.ResourceTree(at, Random.new(3), size, sp, workspace)
			local top = m:FindFirstChild("Top")
			check(#skins(top) == 1, sp .. size .. ": tree mesh not inside Top")
			local stump
			for _, d in m:GetChildren() do
				if d:IsA("BasePart") and d:GetAttribute("SkinStump") then
					stump = d
				end
			end
			check(stump and stump.Transparency == 1, "stump mesh should start hidden")
			Skins.SetTagged(m, "SkinStump", true)
			check(stump.Transparency == 0, "stump not shown")
			check(visibleProcedural(m) == 0, "procedural visible")
			check(m:FindFirstChild("Stump") and m:FindFirstChild("Stump").CanCollide, "stump collider lost")
		end
	end
end)
test("DeadTree dressed", function()
	local m = Flora.DeadTree(at, Random.new(4), workspace)
	check(#skins(m:FindFirstChild("Top")) == 1, "dead tree mesh")
end)
test("RockPile: yield mesh + depleted mesh", function()
	local m = Flora.RockPile(at, Random.new(5), workspace)
	local full, dep = skinOf(m, "SM_StoneDeposit01"), skinOf(m, "SM_StoneDeposit01_Depleted")
	check(full and full:GetAttribute("Yield"), "deposit must be Yield")
	check(dep and not dep:GetAttribute("Yield"), "depleted rubble must stay")
	check(m:FindFirstChild("Boulder").CanCollide, "boulder collision lost")
end)
test("FibrePlant / TwigPile / Mushrooms / LooseStones / BerryBush", function()
	local f = Flora.FibrePlant(at, Random.new(6), workspace)
	check(skinOf(f, "SM_FiberPlant01"):GetAttribute("Yield") and skinOf(f, "SM_FiberPlant01_Harvested"), "fibre")
	local t = Flora.TwigPile(at, Random.new(7), workspace)
	check(skinOf(t, "SM_Sticks_Loose01"):GetAttribute("Yield"), "twigs")
	check(t:FindFirstChild("Litter").Transparency < 1, "litter should stay visible")
	check(skinOf(Flora.MushroomPatch(at, Random.new(8), workspace), "SM_Mushrooms01"), "mushrooms")
	check(skinOf(Flora.LooseStones(at, Random.new(9), workspace), "SM_StreamRocks01"), "stones")
	local b = Flora.BerryBush(at, Random.new(10), workspace)
	check(skinOf(b, "SM_Bush01") and not skinOf(b, "SM_Bush01"):GetAttribute("Yield"), "berry bush mesh")
	check(visibleProcedural(b, { Berry = true }) == 0 and b:FindFirstChild("Berry").Transparency == 0, "berries stay visible")
end)

-- camp ---------------------------------------------------------------------------
test("Campfire: mesh, effects kept, extinguish swap", function()
	local m = Camp.Campfire(at, Color3.new(1, 0, 0), workspace)
	check(skinOf(m, "SM_Campfire_Burning"), "burning mesh")
	check(m:FindFirstChild("FireCore"):FindFirstChild("Flame"), "fire effect")
	check(m:FindFirstChild("SafeRing").Transparency < 1, "safe ring hidden")
	Camp.Extinguish(m)
	check(skinOf(m, "SM_Campfire_Extinguished") and not skinOf(m, "SM_Campfire_Burning"), "extinguish swap")
end)
test("Campfire: level/fuel visuals", function()
	local m = Camp.Campfire(at, Color3.new(1, 0, 0), workspace)
	local core = m:FindFirstChild("FireCore")
	local flame, glow = core:FindFirstChild("Flame"), core:FindFirstChild("Glow")
	Camp.SetFire(m, 1, 1)
	local s1, r1 = flame.Size, glow.Range
	Camp.SetFire(m, 5, 1)
	check(flame.Size > s1 and glow.Range > r1, "level 5 bigger and brighter")
	check(core:FindFirstChild("Smoke").Enabled, "higher fires smoke")
	Camp.SetFire(m, 5, 0.05)
	check(flame.Size < s1 * 2, "low fuel shrinks")
end)
test("Workbench levels", function()
	for lvl = 1, 3 do
		local m = Camp.Workbench(at, lvl, Color3.new(0, 0, 1), workspace)
		check(skinOf(m, "SM_Workbench_Level0" .. lvl), "level " .. lvl)
		check(m:FindFirstChild("Top").CanCollide, "bench top collision")
	end
	check(skinOf(Camp.Lantern(at, Color3.new(1, 1, 1), workspace), "SM_Camp_Lantern"), "lantern")
end)
test("Workbench tiers IV-V keep their upgrades visible", function()
	local m4 = Camp.Workbench(at, 4, Color3.new(0, 0, 1), workspace)
	check(skinOf(m4, "SM_Workbench_Level04"), "tier 4 mesh")
	check(m4:FindFirstChild("Forge") and m4:FindFirstChild("Forge").CanCollide, "forge collider kept")
	check(m4:FindFirstChild("ForgeCoals").Transparency == 0, "coals glow stays visible")
	local m5 = Camp.Workbench(at, 5, Color3.new(0, 0, 1), workspace)
	check(skinOf(m5, "SM_Workbench_Level05"), "tier 5 mesh")
end)
test("LargeRockPile: bigger yield mesh", function()
	local m = Flora.LargeRockPile(at, Random.new(5), workspace)
	check(skinOf(m, "SM_StoneDeposit01"), "deposit mesh")
	check(m.PrimaryPart.Size.X > 10, "double-size root")
end)
test("POIs: every landmark builds with a Root and chest mounts", function()
	for _, kind in { "Campsite", "Shed", "HuntingBlind", "BrokenVehicle", "SmallCabin", "Cabin", "RangerStation", "LoggingCamp", "AbandonedHouse", "MineEntrance", "Bunker", "Outpost", "IndustrialSite", "LargeMine" } do
		local m = Landmarks.Build(kind, at, Random.new(4), workspace)
		check(m and m.PrimaryPart and m.PrimaryPart.Name == "Root", kind .. " root")
		local mounts = 0
		for _, d in m:GetDescendants() do
			if d:IsA("Attachment") and d.Name == "ChestMount" then
				mounts += 1
			end
		end
		check(mounts >= 1, kind .. " chest mounts")
	end
	check(skinOf(Landmarks.Build("Cabin", at, Random.new(4), workspace), "SM_POI_Cabin"), "cabin mesh")
	check(skinOf(Landmarks.Chest(at, "Rare", workspace), "SM_Chest_Rare"), "rare chest mesh")
	local cave = Landmarks.CaveEntrance(at, Random.new(2), 34, "Medium", workspace)
	check(skinOf(cave, "SM_CaveEntrance"), "cave arch mesh")
	check(cave:FindFirstChild("Crystal") or cave:FindFirstChild("Lantern"), "cave lights")
	for _, tier in { "Common", "Uncommon", "Rare", "VeryRare" } do
		local c = Landmarks.Chest(at, tier, workspace)
		check(c:FindFirstChild("Lid"), tier .. " chest lid")
		Landmarks.OpenChest(c)
		check(c:GetAttribute("Open"), tier .. " opens")
	end
end)
test("Decor: mesh-first with colliders for solid kinds", function()
	local log = Decor.Place("FallenLog", at, Random.new(1), 1, workspace)
	check(log and log:FindFirstChild("Collider"), "log collider")
	local fern = Decor.Place("Fern", at, Random.new(1), 1, workspace)
	check(fern and not fern:FindFirstChild("Collider"), "fern is decor only")
	check(Decor.Place("FlowerPatch", at, Random.new(1), 1, workspace), "flowers")
	check(Decor.Place("Spruce", at, Random.new(1), 1, workspace):FindFirstChild("Collider"), "spruce trunk collider")
	for _, id in { "ScrapWall", "MetalWall", "WoodFloor", "ReinforcedChest", "MetalLocker", "SurvivalSafe", "BearTrap", "Snare", "TripwireAlarm" } do
		check(#skins(Structures.Build(id, at, Color3.new(1, 0, 0), workspace)) >= 1, id .. " mesh")
	end
	for _, id in { "StonePickaxe", "IronAxe", "Crowbar", "Sledgehammer", "Crossbow", "HuntingBow" } do
		check(#skins(ItemModels.Held(id)) >= 1, id .. " held mesh")
	end
	for _, id in { "ScrapPile", "CoalDeposit", "IronDeposit", "RichIronDeposit" } do
		local m = Flora[id](at, Random.new(3), workspace)
		local yields = 0
		for _, d in m:GetDescendants() do
			if d:GetAttribute("Yield") then
				yields += 1
			end
		end
		check(yields > 0, id .. " yield parts")
	end
end)
test("Wildlife rigs: deer, rabbit, boar", function()
	for _, sp in { "Deer", "Rabbit", "Boar", "Wolf", "Bear" } do
		local m = Animals.Build(sp)
		check(m:FindFirstChildOfClass("Humanoid"), sp .. " humanoid")
		check(m:FindFirstChild("HumanoidRootPart"), sp .. " root")
	end
	check(Animals.Build("Deer"):FindFirstChild("Antler"), "deer antlers")
	check(Animals.Build("Boar"):FindFirstChild("Tusk"), "boar tusks")
end)
test("Ranged tiers + armour pieces build", function()
	for _, id in { "HuntingBow", "Crossbow", "Bolt" } do
		check(ItemModels.Held(id), id)
	end
end)
test("Tiered tools build (axes, pickaxes, crude spear, meds)", function()
	for _, tn in { "Crude", "Stone", "Iron", "Steel" } do
		for _, kind in { "Axe", "Pickaxe" } do
			local m = ItemModels.Held(tn .. kind)
			check(m and m.PrimaryPart and m.PrimaryPart.Name == "Handle", tn .. kind)
		end
	end
	check(skinOf(ItemModels.Held("CrudeAxe"), "StoneAxe"), "crude axe uses the stone axe mesh")
	check(ItemModels.Held("CrudeSpear"), "crude spear")
	check(ItemModels.Pickup("Medkit", 1, at, workspace), "medkit pickup")
end)

-- structures -------------------------------------------------------------------------
test("Survival Wars structures build (tiers, storage, traps)", function()
	for _, id in { "WoodFloor", "WindowWall", "ScrapWall", "MetalWall", "ReinforcedDoor", "HeavyGate", "ReinforcedChest", "MetalLocker", "SurvivalSafe", "TripwireAlarm", "Snare", "BearTrap", "AdvancedAlarm" } do
		local m = Structures.Build(id, at, Color3.new(1, 0, 0), workspace)
		check(m.PrimaryPart and m.PrimaryPart.Name == "Root", id .. " root")
	end
	local win = Structures.Build("WindowWall", at, Color3.new(1, 0, 0), workspace)
	check(#skins(win) == 0, "window wall shows the procedural wall (the pack wall has no window)")
	local door = Structures.Build("ReinforcedDoor", at, Color3.new(1, 0, 0), workspace)
	check(door:FindFirstChild("Door") and door:FindFirstChild("Door").PrimaryPart, "door panel")
	Structures.SetGateOpen(door, true)
	check(door:GetAttribute("Open") == true, "tiered doors open")
	local crate = Structures.Build("StorageBox", at, Color3.new(1, 0, 0), workspace)
	Structures.SetBreached(crate, true)
	check(crate:FindFirstChild("BreachTag"), "breach tag")
	Structures.SetBreached(crate, false)
	check(not crate:FindFirstChild("BreachTag"), "resecured")
	for _, id in { "Snare", "BearTrap", "TripwireAlarm" } do
		check(Structures.Build(id, at, Color3.new(1, 0, 0), workspace):FindFirstChild("Trigger"), id .. " trigger")
	end
end)
test("Structures dressed + collision intact", function()
	for _, id in { "WoodWall", "ReinforcedWall", "Gate", "Spikes", "StorageBox", "Watchtower" } do
		local m = Structures.Build(id, at, Color3.new(1, 0, 0), workspace)
		check(#skins(m) >= 1, id .. " no mesh")
		check(visibleProcedural(m, { Lock = true }) == 0, id .. " procedural visible")
	end
end)
test("WoodWall stretched to the 10-stud grid", function()
	local m = Structures.WoodWall(CFrame.new(), workspace)
	local s = skinOf(m, "SM_WoodenWall")
	near(s.Size.X, 8.59 * 1.25, 0.02, "wall width")
	check(m:FindFirstChild("Collider").CanCollide, "collider lost")
end)
test("Damage swap and repair", function()
	local m = Structures.WoodWall(at, workspace)
	Structures.ApplyDamageState(m, 0.5)
	check(skinOf(m, "SM_WoodenWall_Damaged") and not skinOf(m, "SM_WoodenWall"), "damaged mesh")
	Structures.ApplyDamageState(m, 1)
	check(skinOf(m, "SM_WoodenWall") and not skinOf(m, "SM_WoodenWall_Damaged"), "repaired mesh")
	near(skinOf(m, "SM_WoodenWall").Size.X, 8.59 * 1.25, 0.02, "stretch kept after swap")
	local box = Structures.StorageBox(at, Color3.new(1, 1, 1), workspace)
	Structures.ApplyDamageState(box, 0.2)
	check(skinOf(box, "SM_StorageBox_Damaged"), "box damaged")
end)
test("Gate door mesh rides the Door model", function()
	local m = Structures.Gate(CFrame.new(), Color3.new(1, 0, 0), workspace)
	local door = m:FindFirstChild("Door")
	local dm = door:FindFirstChild("SM_Gate_Door")
	check(dm and dm:GetAttribute("Skin"), "door mesh not in Door")
	local y0 = dm.Position.Y
	Structures.SetGateOpen(m, true)
	near(dm.Position.Y - y0, 7.4, 0.05, "door mesh opens with the door")
	check(skinOf(m, "SM_WallPost"), "second post")
end)
test("Watchtower ladder follows the mesh", function()
	local m = Structures.Watchtower(CFrame.new(), Color3.new(1, 0, 0), workspace)
	local l = m:FindFirstChild("Ladder")
	near(l.Position.Z, -3.0, 0.01, "ladder z")
end)

-- items & loot --------------------------------------------------------------------
test("Held items: mesh welded to Handle", function()
	for _, id in { "Spear", "Bow", "Sword", "Shield", "Pistol", "Rifle", "StoneAxe", "RepairHammer", "Canteen", "Bandage", "Arrow", "Bullet" } do
		local m = ItemModels.Held(id)
		local s = skins(m)
		check(#s >= 1, id .. " no mesh")
		for _, p in s do
			check(not p.Anchored, id .. " mesh anchored")
			local w = p:FindFirstChildOfClass("WeldConstraint")
			check(w and w.Part0 == m.PrimaryPart and w.Part1 == p, id .. " not welded to Handle")
		end
		check(m.PrimaryPart.Transparency == 1, id .. " procedural handle visible")
	end
	check(#skins(ItemModels.Held("Armor")) == 0, "armor stays procedural")
end)
test("Pistol slide comes along", function()
	check(skinOf(ItemModels.Held("Pistol"), "Pistol") and ItemModels.Held("Pistol"):FindFirstChild("SM_Pistol_Slide"), "slide")
end)
test("StoneAxe head points up along the haft", function()
	local m = ItemModels.Held("StoneAxe")
	local h = m.PrimaryPart
	local s = skinOf(m, "StoneAxe")
	local rel = h.CFrame:ToObjectSpace(s.CFrame)
	-- pack axe: haft along +Y; here the haft must run along -Z from the grip
	check(rel.Position.Z < -0.5, "haft should extend along -Z, got z=" .. rel.Position.Z)
end)
test("Pickups", function()
	check(skinOf(ItemModels.Pickup("Wood", 3, at, workspace), "SM_Pickup_Wood"), "wood pickup")
	check(#skins(ItemModels.Pickup("Sword", 1, at, workspace)) >= 1, "sword pickup")
end)
test("Care package + parachute + land", function()
	local m = LootModels.CarePackage(at, workspace)
	local chute = m:FindFirstChild("Parachute")
	check(skinOf(chute, "SM_Parachute_Canopy") and skinOf(chute, "SM_Parachute_Lines"), "parachute meshes in Parachute")
	check(skinOf(m, "SM_CarePackage_Crate"), "crate")
	LootModels.Land(m)
	check(m:FindFirstChild("Parachute") == nil and not skinOf(m, "SM_Parachute_Canopy"), "parachute removed on landing")
	check(#skins(LootModels.ForestCrate(at, workspace)) >= 1, "forest crate")
end)

-- lobby refuge ----------------------------------------------------------------------
local function lobbyStations(folder)
	local O = Vector3.new(0, 0, 0)
	local out = {}
	for name, pos in { Shop = Vector3.new(40, 0, 0), Classes = Vector3.new(-40, 0, 0), Party = Vector3.new(0, 0, 40), Locker = Vector3.new(30, 0, 30), Profile = Vector3.new(-30, 0, 30) } do
		local m = Instance.new("Model")
		m.Name = name
		local c = Instance.new("Part")
		c.Name = "Counter"
		c.Size = Vector3.new(10, 3.4, 3)
		c.CFrame = CFrame.lookAt(pos + Vector3.new(0, 1.7, 0), O + Vector3.new(0, 1.7, 0))
		c.Parent = m
		m.PrimaryPart = c
		if name == "Classes" then
			for i = 1, 3 do
				local ped = Instance.new("Part")
				ped.Name = "Pedestal"
				ped.Size = Vector3.new(2.4, 3, 2.4)
				ped.CFrame = CFrame.new(pos + Vector3.new(i * 3, 1.5, 0))
				ped.Parent = m
			end
		end
		m.Parent = folder
		out[name] = m
	end
	return out
end
test("Lobby refuge: forest, props, signs, board", function()
	local folder = Instance.new("Folder")
	folder.Parent = workspace
	local st = lobbyStations(folder)
	local water = { Ponds = { { X = 34, Z = -30, R = 9 } }, Stream = { { 50, -41 } } }
	local board = Refuge.Dress(folder, Vector3.new(0, 0, 0), Vector3.new(0, 0, -38), st, water)
	check(board ~= nil and board:IsA("TextLabel"), "hall of fame board label")
	local forest = folder:FindFirstChild("Forest")
	check(forest ~= nil, "forest folder")
	local n, deck, arch, wet = 0, false, false, 0
	for _, c in forest:GetChildren() do
		n += 1
		if c.Name == "GatheringDeck" then
			deck = true
		elseif c.Name == "ReadyArch" then
			arch = true
		end
		if c:IsA("Model") and c.Name ~= "GatheringDeck" and c.Name ~= "ReadyArch" then
			local p = c:GetPivot().Position
			if (p - Vector3.new(34, 0, -30)).Magnitude < 9 then
				wet += 1
			end
		end
	end
	check(n > 60, "layered forest placed (" .. n .. ")")
	check(deck and arch, "deck + ready arch")
	check(wet == 0, "no decoration placed in the pond (" .. wet .. ")")
	check(skinOf(st.Shop, "SM_Lobby_ShopDisplay") and skinOf(st.Party, "SM_Lobby_PartyArea"), "station props")
	check(skinOf(st.Classes, "SM_Lobby_PowerupStand"), "class stands")
	check(st.Shop.PrimaryPart.CanCollide ~= false, "counter keeps collision")
	local signs = 0
	for _, d in forest:GetDescendants() do
		if d:IsA("SurfaceGui") then
			signs += 1
		end
	end
	check(signs == 6, "six signposts (" .. signs .. ")")
end)
test("Lobby refuge without the pack stays procedural", function()
	RS:SetAttribute("MeshSkins", false)
	local folder = Instance.new("Folder")
	folder.Parent = workspace
	local st = lobbyStations(folder)
	local board = Refuge.Dress(folder, Vector3.new(0, 0, 0), Vector3.new(0, 0, -38), st)
	check(board ~= nil, "board without pack")
	check(#skins(st.Shop) == 0 and st.Shop.PrimaryPart.Transparency < 1, "shop stays procedural")
	RS:SetAttribute("MeshSkins", nil)
end)

-- disabled library ------------------------------------------------------------------
test("MeshSkins=false leaves the procedural look", function()
	RS:SetAttribute("MeshSkins", false)
	local m = Nature.Pine(at, 1, workspace)
	check(#skins(m) == 0, "mesh added while disabled")
	check(visibleProcedural(m) > 0, "procedural hidden while disabled")
	local w = Structures.WoodWall(at, workspace)
	Structures.ApplyDamageState(w, 0.2)
	check(#skins(w) == 0, "damage swap while disabled")
	RS:SetAttribute("MeshSkins", nil)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("skins tests failed")
end
