-- Survival Hour: build a sample map from ServerStorage.SurvivalHour (run SurvivalHour_Paste.lua first).
-- Paste into View > Command Bar in edit mode. Creates Workspace.SurvivalHourMap; run again to rebuild it.
-- Ctrl+Z undoes it.

local MAP_SIZE = 420 -- studs across the playable square
local CAMP_DISTANCE = 130 -- camp centres from the map centre
local SEED = 42

local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local History = game:GetService("ChangeHistoryService")
local lib = ServerStorage:FindFirstChild("SurvivalHour")
assert(lib, "Run SurvivalHour_Paste.lua first (ServerStorage.SurvivalHour not found)")

History:SetWaypoint("Before Survival Hour map")
local old = workspace:FindFirstChild("SurvivalHourMap")
if old then
	old:Destroy()
end
local map = Instance.new("Model")
map.Name = "SurvivalHourMap"
map.Parent = workspace
local rng = Random.new(SEED)
local placed, skipped = 0, {}

local function find(name)
	for _, cat in lib:GetChildren() do
		local item = cat:FindFirstChild(name)
		if item and item:IsA("Model") then
			return item
		end
	end
	return nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { map }
local function groundY(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -1000, 0), rayParams)
	return hit and hit.Position.Y or 0
end

local function put(name, x, z, yaw, parent, yOffset)
	local src = find(name)
	if not src then
		skipped[name] = true
		return nil
	end
	local c = src:Clone()
	c:PivotTo(CFrame.new(x, groundY(x, z) + (yOffset or 0), z) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	c.Parent = parent or map
	placed += 1
	return c
end

local function attachmentIn(model, attName)
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Name == attName then
			return d
		end
	end
	return nil
end

-- camp fire effects on the Fire / Smoke / Light attachments
local function lightFire(fire)
	local a = attachmentIn(fire, "Fire")
	if a then
		local f = Instance.new("Fire")
		f.Size = 6
		f.Heat = 9
		f.Parent = a
	end
	a = attachmentIn(fire, "Smoke")
	if a then
		local s = Instance.new("Smoke")
		s.Opacity = 0.15
		s.RiseVelocity = 4
		s.Size = 3
		s.Parent = a
	end
	a = attachmentIn(fire, "Light")
	if a then
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 160, 80)
		l.Range = 28
		l.Brightness = 2
		l.Shadows = true
		l.Parent = a
	end
end

local function isNearCamp(x, z, camps, radius)
	for _, c in camps do
		if (Vector2.new(x, z) - c).Magnitude < radius then
			return true
		end
	end
	return false
end

-- 1. Team camps: campfire + level 1 workbench (the starting kit), dressing around them
local teams = { "Red", "Blue", "Yellow", "Purple" }
local campCentres = {}
for i, team in teams do
	local ang = math.rad(45 + (i - 1) * 90)
	local cx, cz = math.cos(ang) * CAMP_DISTANCE, math.sin(ang) * CAMP_DISTANCE
	table.insert(campCentres, Vector2.new(cx, cz))
	local camp = Instance.new("Model")
	camp.Name = "Camp_" .. team
	camp.Parent = map
	local facing = math.deg(math.atan2(cx, cz)) -- workbench faces the map centre
	put("SM_Clearing_GroundPatch", cx, cz, 0, camp)
	local fire = put("SM_Campfire_Burning", cx, cz, 0, camp)
	put("SM_Campfire_Flames", cx, cz, 0, camp)
	if fire then
		lightFire(fire)
	end
	local off = CFrame.Angles(0, math.rad(facing), 0)
	local function rel(dx, dz)
		local p = off * Vector3.new(dx, 0, dz)
		return cx + p.X, cz + p.Z
	end
	local bx, bz = rel(0, 8)
	put("SM_Workbench_Level01", bx, bz, facing + 180, camp)
	local sx, sz = rel(-6.5, 6)
	put("SM_StorageBox", sx, sz, facing + 180, camp)
	for k, spot in { { -5, -3, 70 }, { 5, -3, -70 } } do
		local x, z = rel(spot[1], spot[2])
		put("SM_Camp_LogBench", x, z, facing + spot[3], camp)
	end
	for k = 1, 4 do
		local x, z = rel(-10 + k * 4, -9)
		put("SM_Camp_Bedroll", x, z, facing, camp)
	end
	local tx, tz = rel(7, 9)
	put("SM_Camp_TeamBanner", tx, tz, facing, camp)
	local lx, lz = rel(-9, 9)
	put("SM_Camp_Lantern", lx, lz, facing, camp)
	local fx, fz = rel(9, 2)
	put("SM_Camp_FirewoodStack", fx, fz, facing + 90, camp)
	camp:SetAttribute("Team", team)
	-- if team SurfaceAppearances exist (ReplicatedStorage.SurvivalHourAtlas), tint this camp's accents
	local atlas = game:GetService("ReplicatedStorage"):FindFirstChild("SurvivalHourAtlas")
	local sa = atlas and atlas:FindFirstChild(team)
	if sa then
		for _, d in camp:GetDescendants() do
			if d:IsA("MeshPart") and d:GetAttribute("TeamColored") then
				local o = d:FindFirstChildOfClass("SurfaceAppearance")
				if o then
					o:Destroy()
				end
				sa:Clone().Parent = d
			end
		end
	end
end

-- 2. Stream across the middle (straight pieces snap every 16 studs), ending in a pool
local stream = Instance.new("Model")
stream.Name = "Stream"
stream.Parent = map
for i = -6, 5 do
	local z = i * 16 + 8
	put("SM_Stream_Straight", -30, z, 0, stream)
	put("SM_Stream_Water_Straight", -30, z, 0, stream)
end
put("SM_Stream_PoolEnd", -30, 6 * 16 + 8, 0, stream)
put("SM_Stream_Water_PoolEnd", -30, 6 * 16 + 8, 0, stream)
put("SM_StreamRocks02", -30, 0, 0, stream, -1.6)
put("SM_StreamRocks01", -31, -40, 30, stream, -1.6)
put("SM_StreamRocks03", -29, 50, 0, stream, -1.6)

-- 3. Landmarks
local marks = Instance.new("Model")
marks.Name = "Landmarks"
marks.Parent = map
put("SM_Landmark_StandingStones", 40, 10, 0, marks)
put("SM_Tree_Oak_Large01", 40, 10, 0, marks)
put("SM_Landmark_GiantLog", 20, -150, 30, marks)
put("SM_Landmark_AntlerTotem", -150, 20, 90, marks)
put("SM_LandingMarker", 60, -40, 0, marks)
put("SM_Beacon", 66, -46, 0, marks)

-- 4. Forest: decor everywhere, harvestables nearer the camps, clear rings around camps and stream
local forest = Instance.new("Model")
forest.Name = "Forest"
forest.Parent = map
local trees = { "SM_Tree_Pine_Medium01", "SM_Tree_Pine_Medium02", "SM_Tree_Pine_Large01", "SM_Tree_Oak_Medium01",
	"SM_Tree_Oak_Medium02", "SM_Tree_Birch_Medium01", "SM_Tree_Dead_Large01" }
local decor = { "SM_Bush01", "SM_Bush02", "SM_Bush03_Berry", "SM_Fern01", "SM_Fern02", "SM_Grass_Clump01",
	"SM_Grass_Clump02", "SM_Grass_Clump03", "SM_Rock_Small01", "SM_Rock_Small02", "SM_Rock_Small03",
	"SM_Boulder01", "SM_Boulder02", "SM_Boulder03", "SM_FallenLog01", "SM_FallenLog02_Hollow", "SM_Branch01",
	"SM_Branch02", "SM_Stump_Old01", "SM_Stump_Old02", "SM_Mushrooms01", "SM_Mushrooms02_Glow",
	"SM_LeafLitter01", "SM_Pinecones01", "SM_MossPatch01", "SM_Sticks_Loose01" }
local harvest = { "SM_Tree_Pine_Small01", "SM_Tree_Oak_Small01", "SM_Tree_Birch_Small01", "SM_StoneDeposit01",
	"SM_FiberPlant01" }
local half = MAP_SIZE / 2
local function freeSpot(minCampDist)
	for _ = 1, 30 do
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if not isNearCamp(x, z, campCentres, minCampDist) and math.abs(x + 30) > 16
			and (Vector2.new(x, z) - Vector2.new(40, 10)).Magnitude > 16 then
			return x, z
		end
	end
	return nil
end
for _ = 1, 170 do
	local x, z = freeSpot(34)
	if x then
		put(trees[rng:NextInteger(1, #trees)], x, z, rng:NextNumber(0, 360), forest)
	end
end
for _ = 1, 260 do
	local x, z = freeSpot(24)
	if x then
		put(decor[rng:NextInteger(1, #decor)], x, z, rng:NextNumber(0, 360), forest)
	end
end
local res = Instance.new("Model")
res.Name = "Resources"
res.Parent = map
for _, c in campCentres do -- a ring of resources around each camp, so every team starts equal
	for k = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(26, 60)
		put(harvest[(k % #harvest) + 1], c.X + math.cos(a) * d, c.Y + math.sin(a) * d, rng:NextNumber(0, 360), res)
	end
end
for k = 1, 5 do -- supply crates scattered in the wild
	local x, z = freeSpot(50)
	if x then
		put("SM_SupplyCrate_Small0" .. ((k % 3) + 1), x, z, rng:NextNumber(0, 360), res)
	end
end

-- 5. Mood: bright day with light forest haze (set ClockTime ~20 for a dark night)
if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.32
	atm.Haze = 1.2
	atm.Color = Color3.fromRGB(199, 214, 190)
	atm.Decay = Color3.fromRGB(92, 110, 88)
	atm.Parent = Lighting
end
Lighting.ClockTime = 14

History:SetWaypoint("Survival Hour map")
local miss = {}
for n in skipped do
	table.insert(miss, n)
end
table.sort(miss)
print(string.format("[SurvivalHour] Map built: %d objects in Workspace.SurvivalHourMap.", placed))
if #miss > 0 then
	print("[SurvivalHour] Skipped (not in ServerStorage.SurvivalHour): " .. table.concat(miss, ", "))
end
