--!nonstrict
-- Builds the lobby and the procedural match map (terrain + forest + camps).
-- All match content lives under workspace.Match and is removed by ClearMatch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = Shared:WaitForChild("Logic")
local LayoutGen = require(Logic:WaitForChild("LayoutGen"))
local Models = Shared:WaitForChild("Models")
local Build = require(Models:WaitForChild("Build"))
local Nature = require(Models:WaitForChild("Nature"))
local Camp = require(Models:WaitForChild("Camp"))
local Flora = require(Models:WaitForChild("Flora"))
local Decor = require(Models:WaitForChild("Decor"))
local Landmarks = require(Models:WaitForChild("Landmarks"))

local WorldService = {}

local ctx: any
local terrain = workspace.Terrain

export type CampInfo = {
	Team: number,
	Origin: CFrame, -- fire position, -Z faces the map centre
	Fire: Model,
	FirePos: Vector3,
	Workbench: Model,
	WorkbenchCF: CFrame,
	SpawnPads: { CFrame },
	Clearances: { { X: number, Z: number, R: number } },
	StaticRects: { { X: number, Z: number, HX: number, HZ: number, Yaw: number } },
	Folder: Folder,
}

export type MapInfo = {
	Seed: number,
	Layout: LayoutGen.Layout,
	Origin: Vector3,
	Folder: Folder,
	Camps: { CampInfo },
	WaterPoints: { { Pos: Vector3, Part: BasePart } },
	DropPoints: { Vector3 },
	Brush: { { Pos: Vector3, R: number } },
	-- Survival Wars world layers
	ChestSpots: { { CF: CFrame, Tier: string, Poi: string, Key: string } },
	NoBuild: { { X: number, Z: number, R: number, Label: string } },
	Caves: { { Feature: any, CF: CFrame, Length: number, Width: number, FloorY: number, Size: string } },
	Pois: { { Type: string, Tier: string, Pos: Vector3 } },
	TerrainReady: boolean?, -- terrain written: GroundY snaps to the real surface
}

WorldService.Map = nil :: MapInfo?
WorldService.LobbySpawn = CFrame.new()
WorldService.LobbyBoard = nil :: TextLabel?

function WorldService.Init(c)
	ctx = c
	local PhysicsService = game:GetService("PhysicsService")
	for _, g in { "Characters", "Animals" } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(g)
		end)
	end
	-- Bats and wolves shouldn't get wedged inside each other.
	PhysicsService:CollisionGroupSetCollidable("Animals", "Animals", false)
end

function WorldService.Start()
	if ctx.Mode == "Lobby" then
		(WorldService :: any).BuildLobby()
	end
	WorldService.ApplyLighting(if ctx.Mode == "Lobby" then "Lobby" else "Day", true)
end

-- Height -------------------------------------------------------------------------------

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
terrainOnly.IgnoreWater = true

function WorldService.GroundY(x: number, z: number): number
	local map = WorldService.Map
	if not map then
		return 0
	end
	-- inside a carved cave: the flat cave floor, not the cliff top above it
	for _, cave in map.Caves or {} do
		local l = cave.CF:PointToObjectSpace(Vector3.new(x, cave.FloorY, z))
		if l.Z > -2 and l.Z < cave.Length + 6 and math.abs(l.X) < cave.Width / 2 + 6 then
			return cave.FloorY
		end
	end
	local h = map.Origin.Y + LayoutGen.Height(map.Layout, x - map.Origin.X, z - map.Origin.Z)
	if map.TerrainReady then
		-- Voxel terrain smooths the heightfield, so objects placed at `h` can end up
		-- half-buried or floating: use the actual surface (water ignored).
		local r = workspace:Raycast(Vector3.new(x, h + 24, z), Vector3.new(0, -48, 0), terrainOnly)
		if r then
			return r.Position.Y
		end
	end
	return h
end

-- Raycast down onto terrain/geometry (used for dynamic spawns).
-- `up` = how far above `pos` the ray starts (default 60). Use a small value for things
-- dropped indoors, so they land on the floor under them, not on the roof.
function WorldService.RaycastGround(pos: Vector3, ignore: { Instance }?, up: number?): (Vector3?, Vector3?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = false
	local from = up or 60
	local r = workspace:Raycast(pos + Vector3.new(0, from, 0), Vector3.new(0, -(from + 140), 0), params)
	if r then
		return r.Position, r.Normal
	end
	return nil, nil
end

-- Lighting -------------------------------------------------------------------------------

local atmosphere: Atmosphere? = nil
local colorFx: ColorCorrectionEffect? = nil

WorldService.Weather = "Clear"
local lastPreset = "Day"

-- Weather reshapes the current preset: storms darken and close in, fog swallows the distance.
-- Returns a modified copy; the preset table itself is never changed.
local function weathered(L: any, weather: string, preset: string): any
	if weather == "Clear" or preset == "Lobby" then
		return L
	end
	local o = table.clone(L)
	local grey = Color3.fromRGB(150, 158, 162)
	if weather == "Cloudy" then
		o.Brightness = L.Brightness * 0.88
		o.Saturation = L.Saturation - 0.05
	elseif weather == "Rain" then
		o.Brightness = L.Brightness * 0.8
		o.Density = L.Density + 0.06
		o.Saturation = L.Saturation - 0.08
	elseif weather == "Storm" then
		o.Brightness = L.Brightness * 0.55
		o.OutdoorAmbient = L.OutdoorAmbient:Lerp(Color3.fromRGB(70, 76, 86), 0.5)
		o.FogStart = L.FogStart * 0.5
		o.FogEnd = L.FogEnd * 0.55
		o.Density = L.Density + 0.14
		o.Haze = L.Haze + 1
		o.AtmoColor = L.AtmoColor:Lerp(grey, 0.5)
		o.Saturation = L.Saturation - 0.14
	elseif weather == "Fog" then
		o.FogStart = 8
		o.FogEnd = math.min(L.FogEnd, if preset == "Night" then 140 else 190)
		o.Density = math.max(L.Density, 0.62)
		o.Haze = L.Haze + 2.5
		o.AtmoColor = L.AtmoColor:Lerp(Color3.fromRGB(205, 210, 212), 0.6)
		o.FogColor = L.FogColor:Lerp(grey, if preset == "Night" then 0.15 else 0.5)
		o.Saturation = L.Saturation - 0.06
	end
	return o
end

-- Sets the match weather (MatchState.Weather for clients) and re-grades the current lighting.
function WorldService.SetWeather(weather: string)
	if weather == WorldService.Weather then
		return
	end
	WorldService.Weather = weather
	local state = game:GetService("ReplicatedStorage"):FindFirstChild("MatchState")
	if state then
		state:SetAttribute("Weather", weather)
	end
	WorldService.ApplyLighting(lastPreset, false)
end

-- `preset` is a Config.Lighting key: Dawn | Day | Sunset | Night | Lobby.
function WorldService.ApplyLighting(preset: string, instant: boolean?)
	lastPreset = preset
	local L = weathered((Config.Lighting :: any)[preset] or Config.Lighting.Day, WorldService.Weather, preset)
	if not atmosphere then
		local a = Instance.new("Atmosphere")
		a.Density = 0.32
		a.Offset = 0.1
		a.Parent = Lighting
		atmosphere = a
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Parent = Lighting
		colorFx = cc
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.4
		bloom.Size = 20
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
		local sun = Instance.new("SunRaysEffect")
		sun.Intensity = 0.04
		sun.Parent = Lighting
	end
	Lighting:SetAttribute("Preset", preset)
	local TweenService = game:GetService("TweenService")
	local info = TweenInfo.new(if instant then 0 else Config.Lighting.TransitionTime, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = L.ClockTime,
		Brightness = L.Brightness,
		Ambient = L.Ambient,
		OutdoorAmbient = L.OutdoorAmbient,
		FogColor = L.FogColor,
		FogStart = L.FogStart,
		FogEnd = L.FogEnd,
		ColorShift_Top = L.ColorShift,
	}):Play()
	if atmosphere then
		TweenService:Create(atmosphere, info, { Density = L.Density, Color = L.AtmoColor, Decay = L.Decay, Haze = L.Haze }):Play()
	end
	if colorFx then
		TweenService:Create(colorFx, info, { Saturation = L.Saturation, Contrast = L.Contrast, TintColor = L.Tint }):Play()
	end
end

-- Terrain ---------------------------------------------------------------------------------

local function writeTerrain(map: MapInfo)
	local layout = map.Layout
	local O = map.Origin
	local H = layout.HalfSize + 24
	local RES = 4
	local YCELLS = 12 -- 48 studs of terrain column (cliff rim tops out ~45)
	local CHUNK = 16 -- cells per chunk side

	local pathLists = layout.Paths
	local streams = layout.Streams
	local ponds = {}
	local glades = {}
	for _, f in layout.Features do
		if f.Type == "Pond" then
			table.insert(ponds, f)
		elseif f.Type == "Glade" then
			table.insert(glades, f)
		end
	end

	-- Forest palette: mossy LeafyGrass, leaf-litter Ground, dark Mud, cool Slate.
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(88, 122, 62))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(70, 106, 52))
		terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(104, 84, 60))
		terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(74, 60, 46))
		terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(96, 98, 102))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(118, 114, 108))
	end)

	local total = math.ceil(2 * H / RES)
	for cx0 = 0, total - 1, CHUNK do
		for cz0 = 0, total - 1, CHUNK do
			local nx = math.min(CHUNK, total - cx0)
			local nz = math.min(CHUNK, total - cz0)
			local mats = table.create(nx)
			local occs = table.create(nx)
			for ix = 1, nx do
				local mcol = table.create(YCELLS)
				local ocol = table.create(YCELLS)
				for iy = 1, YCELLS do
					mcol[iy] = table.create(nz, Enum.Material.Air)
					ocol[iy] = table.create(nz, 0)
				end
				mats[ix] = mcol
				occs[ix] = ocol
				local wx = -H + (cx0 + ix - 0.5) * RES
				for iz = 1, nz do
					local wz = -H + (cz0 + iz - 0.5) * RES
					local h = LayoutGen.Height(layout, wx, wz)
					-- Forest floor variety (spec: moss, leaf litter, dirt, grass patches; not one
					-- stretched green): two noise fields pick the ground material.
					local nA = math.noise(wx / 38, wz / 38, 5.3)
					local nB = math.noise(wx / 17 + 40, wz / 17, 9.1)
					local surface = if nA > 0.28 then Enum.Material.LeafyGrass
						elseif nA < -0.3 then Enum.Material.Ground -- leaf litter / dirt
						elseif nB > 0.35 then Enum.Material.Mud -- damp hollows
						else Enum.Material.Grass
					-- cliff rim: bare rock and slate on the slopes
					local rim = LayoutGen.RimFactor(wx, wz)
					if rim > 0.35 then
						surface = if nB > 0 then Enum.Material.Rock else Enum.Material.Slate
					end
					-- camps: packed earth
					for _, c in layout.Camps do
						local d = math.sqrt((wx - c.X) ^ 2 + (wz - c.Z) ^ 2)
						if d < 26 then
							surface = Enum.Material.Ground
						elseif d < 60 then
							surface = Enum.Material.LeafyGrass
						end
					end
					local dc = math.sqrt(wx * wx + wz * wz)
					if dc < 30 then
						surface = Enum.Material.Cobblestone
					elseif dc < 60 then
						surface = Enum.Material.Ground
					end
					for _, p in pathLists do
						if LayoutGen.DistToPolyline(wx, wz, p.Points) < p.Width / 2 then
							surface = Enum.Material.Mud
							break
						end
					end
					for _, g in glades do
						if (wx - g.X) ^ 2 + (wz - g.Z) ^ 2 < g.R * g.R then
							surface = Enum.Material.LeafyGrass
						end
					end
					-- water carving (+ muddy, rocky banks: forest -> grass/moss -> mud/rock -> water)
					local waterDepth = 0
					for _, s in streams do
						local d = LayoutGen.DistToPolyline(wx, wz, s.Points)
						local half = s.Width / 2 + 2
						if d < half then
							local t = d / half
							waterDepth = math.max(waterDepth, s.Depth * (1 - t * t))
						elseif d < half + 3 then
							surface = if nB > 0.2 then Enum.Material.Rock else Enum.Material.Mud
						elseif d < half + 7 and surface == Enum.Material.Grass then
							surface = Enum.Material.LeafyGrass
						end
					end
					for _, pd in ponds do
						local d = math.sqrt((wx - pd.X) ^ 2 + (wz - pd.Z) ^ 2)
						if d < pd.R then
							local t = d / pd.R
							waterDepth = math.max(waterDepth, 4 * (1 - t * t))
						end
					end
					local waterTop = h - 0.6
					local bed = h - waterDepth - 0.6
					if waterDepth > 0.3 then
						surface = Enum.Material.Sand
					end
					if math.abs(wx) > layout.HalfSize or math.abs(wz) > layout.HalfSize then
						surface = Enum.Material.LeafyGrass
					end
					for iy = 1, YCELLS do
						local y0 = (iy - 1) * RES
						local solidTop = if waterDepth > 0.3 then bed else h
						local occ = math.clamp((solidTop - y0) / RES, 0, 1)
						if occ > 0 and occ < 1 and waterDepth > 0.3 and waterTop - y0 >= RES * 0.4 then
							-- the bed and the water top share this voxel: a voxel can't be both, so
							-- fill it with water (otherwise the river shows a dry sand gap here)
							mats[ix][iy][iz] = Enum.Material.Water
							occs[ix][iy][iz] = 1
						elseif occ > 0 then
							mats[ix][iy][iz] = if y0 + RES >= solidTop - 1 then surface elseif y0 < 4 then Enum.Material.Rock else Enum.Material.Ground
							occs[ix][iy][iz] = occ
						elseif waterDepth > 0.3 and y0 < waterTop then
							mats[ix][iy][iz] = Enum.Material.Water
							occs[ix][iy][iz] = 1
						end
					end
				end
			end
			local minV = Vector3.new(-H + cx0 * RES, 0, -H + cz0 * RES) + O
			local region = Region3.new(minV, minV + Vector3.new(nx * RES, YCELLS * RES, nz * RES))
			terrain:WriteVoxels(region, RES, mats, occs)
		end
		task.wait() -- keep the server responsive while building
	end
end

-- Match map -----------------------------------------------------------------------------

local function atomic(m: Model)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

local function buildCamp(map: MapInfo, c: any): CampInfo
	local team = Config.Teams[c.Team]
	local O = map.Origin
	local y = WorldService.GroundY(c.X + O.X, c.Z + O.Z)
	local firePos = Vector3.new(c.X + O.X, y, c.Z + O.Z)
	-- -Z of origin faces the centre
	local origin = CFrame.lookAt(firePos, Vector3.new(O.X, y, O.Z))
	local folder = Instance.new("Folder")
	folder.Name = "Camp" .. c.Team
	folder.Parent = map.Folder

	local fire = Camp.Campfire(origin, team.Color, folder)
	fire.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	fire:SetAttribute("Team", c.Team)

	local wbCF = origin * CFrame.new(0, 0, 14) * CFrame.Angles(0, math.rad(180), 0)
	wbCF = CFrame.new(wbCF.Position) * wbCF.Rotation
	local wb = Camp.Workbench(wbCF, 1, team.Color, folder)
	wb.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	wb:SetAttribute("Team", c.Team)

	local pads = {}
	for _, off in { Vector3.new(-12, 0, 8), Vector3.new(12, 0, 8), Vector3.new(-18, 0, -2), Vector3.new(18, 0, -2) } do
		local cf = origin * CFrame.new(off)
		cf = CFrame.new(cf.Position.X, WorldService.GroundY(cf.Position.X, cf.Position.Z), cf.Position.Z) * origin.Rotation
		Camp.SpawnPad(cf, team.Color, folder)
		table.insert(pads, cf + Vector3.new(0, 3.5, 0))
	end

	local hutCF = origin * CFrame.new(0, 0, 34) * CFrame.Angles(0, math.rad(180), 0)
	local hut = Camp.Hut(CFrame.new(hutCF.Position.X, WorldService.GroundY(hutCF.Position.X, hutCF.Position.Z), hutCF.Position.Z) * hutCF.Rotation, team.Motif, team.Color, folder)
	atomic(hut)
	local bannerCF = origin * CFrame.new(9, 0, -14)
	local banner = Camp.Banner(CFrame.new(bannerCF.Position.X, WorldService.GroundY(bannerCF.Position.X, bannerCF.Position.Z), bannerCF.Position.Z) * origin.Rotation, team.Color, team.Symbol, folder)
	banner.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for _, x in { -26, 26 } do
		local lcf = origin * CFrame.new(x, 0, -22)
		atomic(Camp.Lantern(CFrame.new(lcf.Position.X, WorldService.GroundY(lcf.Position.X, lcf.Position.Z), lcf.Position.Z) * origin.Rotation, team.Color, folder))
	end

	local function toLocal2D(cf: CFrame): (number, number)
		return cf.Position.X, cf.Position.Z
	end
	local wbFront = origin * CFrame.new(0, 0, 10)
	local clearances = {
		{ X = firePos.X, Z = firePos.Z, R = Config.Build.FireClearance },
	}
	local fx, fz = toLocal2D(wbFront)
	table.insert(clearances, { X = fx, Z = fz, R = Config.Build.WorkbenchClearance })
	for _, p in pads do
		table.insert(clearances, { X = p.Position.X, Z = p.Position.Z, R = Config.Build.SpawnClearance })
	end
	local _, yawRad = origin:ToOrientation()
	local yaw = math.deg(yawRad)
	local hx, hz = toLocal2D(hutCF)
	local wx, wz = toLocal2D(wbCF)
	local bx, bz = toLocal2D(bannerCF)
	local rects = {
		{ X = hx, Z = hz, HX = 6.5, HZ = 5.5, Yaw = -yaw },
		{ X = wx, Z = wz, HX = 5, HZ = 2.5, Yaw = -yaw },
		{ X = bx, Z = bz, HX = 1.5, HZ = 1.5, Yaw = 0 },
	}

	return {
		Team = c.Team,
		Origin = origin,
		Fire = fire,
		FirePos = firePos,
		Workbench = wb,
		WorkbenchCF = wbCF,
		SpawnPads = pads,
		Clearances = clearances,
		StaticRects = rects,
		Folder = folder,
	}
end

-- Points of interest ----------------------------------------------------------------------

-- Chest spots come from the model's ChestMount attachments (in order), one per chest
-- tier that LayoutGen rolled for this POI.
local chestCounter = 0
local function addChests(map: MapInfo, model: Model, f: any)
	local mounts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "ChestMount" then
			table.insert(mounts, d)
		end
	end
	for i, tier in f.Chests or {} do
		local mnt = mounts[((i - 1) % math.max(1, #mounts)) + 1]
		if mnt then
			chestCounter += 1
			table.insert(map.ChestSpots, { CF = mnt.WorldCFrame, Tier = tier, Poi = f.Type, Key = "C" .. chestCounter })
		end
	end
end

-- Natural clustering: small ground-cover companions gathered around the props
-- they'd really grow by (mushrooms and moss on fallen logs, pebbles and ferns at
-- boulders, twigs round stumps, ferns and roots at tree bases, stones along the
-- water) instead of everything spread evenly. Non-colliding, capped.
local COMPANIONS = {
	FallenLog = { "Mushrooms", "MossPatch", "Fern" },
	Boulder = { "Pebbles", "Fern", "MossPatch" },
	Stump = { "Twigs", "Mushrooms", "Fern" },
	DeadSnag = { "Twigs", "Roots" },
	Roots = { "LeafLitter", "Mushrooms" },
}
local COMPANION_CAP = 700

function WorldService._companions(layout: any, ground: (number, number) -> CFrame, rng: Random, parent: Instance)
	local placed = 0
	local function near(kind: string, x: number, z: number, r0: number, r1: number)
		if placed >= COMPANION_CAP then
			return
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(r0, r1)
		local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
		if math.abs(px) > layout.HalfSize - 4 or math.abs(pz) > layout.HalfSize - 4 then
			return
		end
		Decor.Place(kind, ground(px, pz) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) + Vector3.new(0, 0.2, 0), rng, 1, parent)
		placed += 1
	end
	for i, d in layout.Middle do
		local list = COMPANIONS[d.Kind]
		if list then
			for _ = 1, rng:NextInteger(1, 3) do
				near(list[rng:NextInteger(1, #list)], d.X, d.Z, 1.5 * (d.Scale or 1), 3.5 * (d.Scale or 1))
			end
		end
		if i % 100 == 0 then
			task.wait()
		end
	end
	for i, t in layout.Trees do
		if rng:NextNumber() < 0.3 then
			near(if rng:NextNumber() < 0.5 then "Fern" else "Roots", t.X, t.Z, 1.8, 3)
		end
		if i % 150 == 0 then
			task.wait()
		end
	end
	for _, st in layout.Streams do
		local pts = st.Points
		for i = 1, #pts - 1, 2 do
			local p = pts[i]
			near(if rng:NextNumber() < 0.6 then "Pebbles" else "Fern", p.X, p.Z, st.Width / 2 + 2, st.Width / 2 + 5)
		end
	end
end

local POI_SCALE = 1.35

-- Distant cues that make players wonder "what's over there?": a thin smoke
-- column over lived-in buildings by day, and a lantern glow at the bigger
-- sites that reads through the trees at night. No map markers — just curiosity.
local SMOKE_POIS = { Cabin = true, SmallCabin = true, RangerStation = true, AbandonedHouse = true, Campsite = true, LoggingCamp = true }
local LIGHT_POIS = { RangerStation = true, Outpost = true, Bunker = true, IndustrialSite = true, LargeMine = true, MineEntrance = true, Campsite = true }

function WorldService._poiBeacon(m: Model, kind: string)
	local cf, size = m:GetBoundingBox()
	if SMOKE_POIS[kind] then
		local anchor = Build.Part({ Name = "BeaconSmoke", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = cf * CFrame.new(size.X * 0.2, size.Y / 2 + 1, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = m })
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205), Color3.fromRGB(150, 150, 160))
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 7) })
		pe.Lifetime = NumberRange.new(6, 9)
		pe.Speed = NumberRange.new(3, 5)
		pe.Rate = 2.5
		pe.Acceleration = Vector3.new(1.2, 0.6, 0)
		pe.SpreadAngle = Vector2.new(8, 8)
		pe.LightInfluence = 1
		pe.Parent = anchor
	end
	if LIGHT_POIS[kind] then
		local lamp = Build.Part({ Name = "BeaconLamp", Size = Vector3.new(0.6, 0.8, 0.6), CFrame = cf * CFrame.new(0, size.Y * 0.1, -size.Z / 2 - 0.4), Color = Color3.fromRGB(255, 196, 120), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = m })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 180, 110)
		light.Range = 22
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = lamp
	end
end

function WorldService._buildPoi(map: MapInfo, f: any, cf: CFrame, rng: Random, parent: Instance)
	local m = Landmarks.Build(f.Type, cf, rng, parent)
	if not m then
		return
	end
	-- Buildings were a bit small next to players: scale the whole POI (colliders,
	-- meshes and chest mounts together) about its ground pivot.
	m:ScaleTo(POI_SCALE)
	WorldService._poiBeacon(m, f.Type)
	m:SetAttribute("Poi", f.Type)
	m:SetAttribute("Tier", f.Tier)
	addChests(map, m, f)
	local O = map.Origin
	table.insert(map.NoBuild, { X = f.X + O.X, Z = f.Z + O.Z, R = f.R * POI_SCALE + 4, Label = "a " .. f.Type })
	table.insert(map.Pois, { Type = f.Type, Tier = f.Tier or "Common", Pos = cf.Position })
	-- lived-in surroundings: a woodpile of stumps and logs, scattered twigs and
	-- overgrowth creeping back in around the edge of the site
	local SITE = { "Stump", "Twigs", "FallenLog", "Twigs", "Fern", "Mushrooms", "Bush" }
	for k = 1, rng:NextInteger(4, 7) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = (f.R or 10) * POI_SCALE * rng:NextNumber(0.95, 1.35)
		local x, z = f.X + math.cos(a) * d, f.Z + math.sin(a) * d
		if math.abs(x) < map.Layout.HalfSize - 6 and math.abs(z) < map.Layout.HalfSize - 6 then
			local gy = WorldService.GroundY(x + map.Origin.X, z + map.Origin.Z)
			local pcf = CFrame.new(x + map.Origin.X, gy - 0.3, z + map.Origin.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			Decor.Place(SITE[(k % #SITE) + 1], pcf, rng, rng:NextNumber(0.8, 1.1), parent)
		end
	end
end

-- Caves: carve the tunnel (and chambers) into the cliff rim before anything is placed.
local CAVE_WIDTH = { Small = 9, Medium = 11, Large = 13 }
function WorldService._carveCaves(map: MapInfo)
	local O = map.Origin
	for _, f in map.Layout.Features do
		if f.Type == "Cave" then
			local floorY = O.Y + LayoutGen.Height(map.Layout, f.X, f.Z) - 0.2
			local cf = CFrame.new(f.X + O.X, floorY, f.Z + O.Z) * CFrame.Angles(0, math.rad(f.Rot), 0)
			-- Slide the mouth along the cave axis to where the cliff face really is, so the
			-- entrance arch sits against the wall instead of out on the open ground.
			for z = -10, 40 do
				local p = (cf * CFrame.new(0, 0, z)).Position
				if O.Y + LayoutGen.Height(map.Layout, p.X - O.X, p.Z - O.Z) > floorY + 9 then
					cf = cf * CFrame.new(0, 0, z - 1.5)
					break
				end
			end
			local w = CAVE_WIDTH[f.Size] or 9
			local len = f.Length or 22
			for z = 0, len, 4 do
				terrain:FillBlock(cf * CFrame.new(0, 5.2, z), Vector3.new(w, 10.4, 4.6), Enum.Material.Air)
			end
			terrain:FillBall((cf * CFrame.new(0, 5, len)).Position, w * 0.75, Enum.Material.Air)
			if f.Size == "Large" then
				-- side chambers
				terrain:FillBall((cf * CFrame.new(-w * 0.8, 5, len * 0.6)).Position, w * 0.7, Enum.Material.Air)
				terrain:FillBall((cf * CFrame.new(w * 0.8, 5, len * 0.85)).Position, w * 0.6, Enum.Material.Air)
			end
			-- flat slate floor all the way in
			terrain:FillBlock(cf * CFrame.new(0, -1, len / 2), Vector3.new(w + 6, 2, len + 12), Enum.Material.Slate)
			table.insert(map.Caves, { Feature = f, CF = cf, Length = len, Width = w + (if f.Size == "Large" then 10 else 0), FloorY = floorY, Size = f.Size or "Small" })
		end
	end
end

function WorldService._buildCave(map: MapInfo, f: any, rng: Random, parent: Instance)
	local cave
	for _, c in map.Caves do
		if c.Feature == f then
			cave = c
		end
	end
	if not cave then
		return
	end
	local m = Landmarks.CaveEntrance(cave.CF, rng, cave.Length, cave.Size, parent)
	m:SetAttribute("Poi", "Cave")
	m:SetAttribute("Tier", f.Tier)
	m:SetAttribute("CaveSize", cave.Size)
	addChests(map, m, f)
	table.insert(map.NoBuild, { X = f.X + map.Origin.X, Z = f.Z + map.Origin.Z, R = f.R + 6, Label = "the cave" })
	table.insert(map.Pois, { Type = "Cave", Tier = f.Tier or "Common", Pos = cave.CF.Position })
end

function WorldService.BuildMatch(seed: number): MapInfo
	WorldService.ClearMatch()
	local layout = LayoutGen.Generate(seed)
	local folder = Instance.new("Folder")
	folder.Name = "Match"
	folder.Parent = workspace
	local O = Config.Map.MatchOrigin
	local map: MapInfo = {
		Seed = seed,
		Layout = layout,
		Origin = O,
		Folder = folder,
		Camps = {},
		WaterPoints = {},
		DropPoints = {},
		Brush = {},
		ChestSpots = {},
		NoBuild = {},
		Caves = {},
		Pois = {},
	}
	WorldService.Map = map

	writeTerrain(map)
	WorldService._carveCaves(map)
	map.TerrainReady = true

	local decor = Instance.new("Folder")
	decor.Name = "Forest"
	decor.Parent = folder

	local function ground(x: number, z: number): CFrame
		return CFrame.new(x + O.X, WorldService.GroundY(x + O.X, z + O.Z) - 0.3, z + O.Z)
	end

	local drng = Random.new(seed)
	for i, t in layout.Trees do
		local cf = ground(t.X, t.Z) * CFrame.Angles(0, math.rad((i * 67) % 360), 0)
		local m
		if t.Kind == "Pine" then
			m = Nature.Pine(cf, t.Scale, decor)
		elseif t.Kind == "Oak" then
			m = Nature.Oak(cf, t.Scale, decor)
		elseif t.Kind == "Birch" then
			m = Nature.Birch(cf, t.Scale, decor)
		else
			-- Spruce, Aspen, DeadSnag, GiantTree: more silhouettes (mesh-first, Flora fallback)
			m = Decor.Place(t.Kind, cf, drng, t.Scale, decor)
		end
		if m and m:IsA("Model") then
			atomic(m)
		end
		if i % 60 == 0 then
			task.wait()
		end
	end
	-- Layered forest: middle (logs/boulders/stumps/roots), low (ferns/bushes/grass/saplings),
	-- ground cover (litter/moss/flowers/mushrooms/pebbles/twigs). Mesh-first, cheap.
	for i, d in layout.Middle do
		Decor.Place(d.Kind, ground(d.X, d.Z) * CFrame.Angles(0, math.rad(d.Rot), 0), drng, d.Scale, decor)
		if i % 80 == 0 then
			task.wait()
		end
	end
	WorldService._companions(layout, ground, drng, decor)
	for i, d in layout.Undergrowth do
		Decor.Place(d.Kind, ground(d.X, d.Z) * CFrame.Angles(0, math.rad(d.Rot), 0), drng, d.Scale, decor)
		if i % 150 == 0 then
			task.wait()
		end
	end
	for i, d in layout.GroundCover do
		Decor.Place(d.Kind, ground(d.X, d.Z) * CFrame.Angles(0, math.rad(d.Rot), 0) + Vector3.new(0, 0.25, 0), drng, 1, decor)
		if i % 200 == 0 then
			task.wait()
		end
	end
	-- Cliff rim faces (Blender cliff kit when loaded, procedural otherwise)
	local Skins = require(Models:WaitForChild("Skins"))
	for i, c in layout.Cliffs do
		local cf = ground(c.X, c.Z) * CFrame.Angles(0, math.rad(c.Rot), 0)
		if Skins.Has("SM_Cliff_Face01") then
			Decor.Place("Cliff", cf, drng, c.H / 26, decor)
		else
			atomic(Flora.CliffRock(cf, drng, Vector3.new(c.W, c.H, 8), decor))
		end
		if i % 20 == 0 then
			task.wait()
		end
	end
	for _, r in layout.Rocks do
		atomic(Nature.BigRock(ground(r.X, r.Z) * CFrame.Angles(0, math.rad(r.Rot), 0), r.Scale, decor))
	end
	for i, b in layout.Bushes do
		atomic(Nature.Bush(ground(b.X, b.Z) * CFrame.Angles(0, i, 0), b.Scale, decor))
	end
	for _, s in layout.Stones do
		atomic(Nature.StandingStone(ground(s.X, s.Z) * CFrame.Angles(0, math.rad(s.Rot), 0), decor))
	end
	for _, f in layout.Features do
		local cf = ground(f.X, f.Z) * CFrame.Angles(0, math.rad(f.Rot), 0)
		if f.Type == "Ruins" then
			atomic(Nature.Ruins(cf, decor))
		elseif f.Type == "FallenGiant" then
			atomic(Nature.FallenGiant(cf, decor))
		elseif f.Type == "RockOutcrop" then
			for k = 0, 4 do
				local a = math.rad(k * 72 + f.Rot)
				local d = if k == 0 then 0 else f.R * 0.5
				atomic(Nature.BigRock(ground(f.X + math.cos(a) * d, f.Z + math.sin(a) * d) * CFrame.Angles(0, a, 0), if k == 0 then 2.2 else 1.3, decor))
			end
		elseif f.Type == "Glade" then
			local colors = { Color3.fromRGB(240, 220, 110), Color3.fromRGB(230, 130, 170), Color3.fromRGB(170, 150, 240), Color3.fromRGB(250, 250, 250) }
			for k = 1, 18 do
				local a = k * 2.39996
				local d = math.sqrt(k / 18) * f.R * 0.9
				Nature.Flower(ground(f.X + math.cos(a) * d, f.Z + math.sin(a) * d), colors[(k % #colors) + 1], decor)
			end
		elseif f.Type == "Thicket" then
			-- handled with brush below
		elseif f.Type == "Waterfall" then
			atomic(Flora.WaterfallRocks(cf, drng, LayoutGen.RimHeight * 0.7, decor))
		elseif f.Type == "Cave" then
			WorldService._buildCave(map, f, drng, decor)
		elseif LayoutGen.LandmarkRadius[f.Type] then
			WorldService._buildPoi(map, f, cf, drng, decor)
		end
	end
	for _, b in layout.Brush do
		local count = math.floor(b.R * 0.9)
		for k = 1, count do
			local a = k * 2.39996
			local d = math.sqrt(k / count) * b.R
			Nature.GrassClump(ground(b.X + math.cos(a) * d, b.Z + math.sin(a) * d) * CFrame.Angles(0, k, 0), decor)
		end
		table.insert(map.Brush, { Pos = Vector3.new(b.X + O.X, 0, b.Z + O.Z), R = b.R })
	end

	-- Water refill points
	local waterFolder = Instance.new("Folder")
	waterFolder.Name = "Water"
	waterFolder.Parent = folder
	for _, w in layout.WaterPoints do
		local y = WorldService.GroundY(w.X + O.X, w.Z + O.Z) - 0.6
		local p = Build.Part({ Name = "WaterPoint", Size = Vector3.new(3, 1, 3), CFrame = CFrame.new(w.X + O.X, y, w.Z + O.Z), Transparency = 1, CanCollide = false, CanQuery = false, Parent = waterFolder })
		local ring = Build.Decor({ Name = "Ripple", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 4, 4), CFrame = CFrame.new(w.X + O.X, y + 0.05, w.Z + O.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(170, 220, 255), Material = Enum.Material.Neon, Transparency = 0.6, Parent = p, CastShadow = false })
		ring.Name = "Ripple"
		table.insert(map.WaterPoints, { Pos = p.Position, Part = p })
	end

	for _, d in layout.DropPoints do
		table.insert(map.DropPoints, Vector3.new(d.X + O.X, WorldService.GroundY(d.X + O.X, d.Z + O.Z), d.Z + O.Z))
	end

	for _, c in layout.Camps do
		map.Camps[c.Team] = buildCamp(map, c)
	end

	-- Boundary: invisible walls plus a ring of edge pines.
	local H = layout.HalfSize
	for _, w in { { 0, -H - 6, 2 * H + 40, 4 }, { 0, H + 6, 2 * H + 40, 4 }, { -H - 6, 0, 4, 2 * H + 40 }, { H + 6, 0, 4, 2 * H + 40 } } do
		Build.Part({ Name = "Boundary", Size = Vector3.new(w[3], 300, w[4]), CFrame = CFrame.new(w[1] + O.X, 140 + O.Y, w[2] + O.Z), Transparency = 1, Parent = folder })
	end
	for i = 0, 79 do
		local t = i / 80 * 4
		local side = math.floor(t)
		local f = (t - side) * 2 - 1
		local x, z
		if side == 0 then
			x, z = f * (H + 14), -H - 14
		elseif side == 1 then
			x, z = H + 14, f * (H + 14)
		elseif side == 2 then
			x, z = -f * (H + 14), H + 14
		else
			x, z = -H - 14, -f * (H + 14)
		end
		atomic(Nature.Pine(CFrame.new(x + O.X, O.Y + LayoutGen.Height(layout, math.clamp(x, -H, H), math.clamp(z, -H, H)) - 0.5, z + O.Z), 1.5, decor))
	end

	return map
end

function WorldService.ClearMatch()
	local old = workspace:FindFirstChild("Match")
	if old then
		old:Destroy()
	end
	local map = WorldService.Map
	if map then
		local H = map.Layout.HalfSize + 32
		local O = map.Origin
		terrain:FillBlock(CFrame.new(O + Vector3.new(0, 28, 0)), Vector3.new(2 * H, 64, 2 * H), Enum.Material.Air)
	end
	WorldService.Map = nil
end

-- Lobby (refuge island, board): see WorldLobby.luau
require(script.Parent:WaitForChild("WorldLobby"))(WorldService)

return WorldService
