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
}

WorldService.Map = nil :: MapInfo?
WorldService.LobbySpawn = CFrame.new()

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
		WorldService.BuildLobby()
	end
	WorldService.ApplyLighting("Day", true)
end

-- Height -------------------------------------------------------------------------------

function WorldService.GroundY(x: number, z: number): number
	local map = WorldService.Map
	if not map then
		return 0
	end
	return map.Origin.Y + LayoutGen.Height(map.Layout, x - map.Origin.X, z - map.Origin.Z)
end

-- Raycast down onto terrain/geometry (used for dynamic spawns).
function WorldService.RaycastGround(pos: Vector3, ignore: { Instance }?): (Vector3?, Vector3?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = false
	local r = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	if r then
		return r.Position, r.Normal
	end
	return nil, nil
end

-- Lighting -------------------------------------------------------------------------------

local atmosphere: Atmosphere? = nil
local colorFx: ColorCorrectionEffect? = nil

function WorldService.ApplyLighting(phase: string, instant: boolean?)
	local L = if phase == "Night" then Config.Lighting.Night else Config.Lighting.Day
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
		TweenService:Create(atmosphere, info, {
			Density = if phase == "Night" then 0.38 else 0.3,
			Color = if phase == "Night" then Color3.fromRGB(70, 84, 120) else Color3.fromRGB(199, 214, 210),
			Decay = if phase == "Night" then Color3.fromRGB(40, 44, 70) else Color3.fromRGB(120, 130, 110),
		}):Play()
	end
	if colorFx then
		TweenService:Create(colorFx, info, {
			Saturation = if phase == "Night" then -0.15 else 0.08,
			Contrast = if phase == "Night" then 0.08 else 0.05,
			TintColor = if phase == "Night" then Color3.fromRGB(220, 228, 255) else Color3.fromRGB(255, 250, 240),
		}):Play()
	end
end

-- Terrain ---------------------------------------------------------------------------------

local function writeTerrain(map: MapInfo)
	local layout = map.Layout
	local O = map.Origin
	local H = layout.HalfSize + 24
	local RES = 4
	local YCELLS = 9 -- 36 studs of terrain column
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
					local surface = Enum.Material.Grass
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
					-- water carving
					local waterDepth = 0
					for _, s in streams do
						local d = LayoutGen.DistToPolyline(wx, wz, s.Points)
						local half = s.Width / 2 + 2
						if d < half then
							local t = d / half
							waterDepth = math.max(waterDepth, s.Depth * (1 - t * t))
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
						if occ > 0 then
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

	-- Build-zone boundary markers: short stakes with team-colour tips on the zone edge.
	for i = 0, 23 do
		local a = math.rad(i * 15)
		local px = firePos.X + math.cos(a) * Config.Build.ZoneRadius
		local pz = firePos.Z + math.sin(a) * Config.Build.ZoneRadius
		local py = WorldService.GroundY(px, pz)
		local stake = Build.Part({ Name = "ZoneStake", Size = Vector3.new(0.5, 2.2, 0.5), CFrame = CFrame.new(px, py + 1.1, pz), Color = Color3.fromRGB(110, 80, 50), Material = Enum.Material.Wood, CanCollide = false, CanQuery = false, Parent = folder })
		stake.CastShadow = false
		Build.Decor({ Name = "Tip", Size = Vector3.new(0.6, 0.5, 0.6), CFrame = CFrame.new(px, py + 2.4, pz), Color = team.Color, Material = Enum.Material.Neon, Parent = folder, CastShadow = false })
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
	}
	WorldService.Map = map

	writeTerrain(map)

	local decor = Instance.new("Folder")
	decor.Name = "Forest"
	decor.Parent = folder

	local function ground(x: number, z: number): CFrame
		return CFrame.new(x + O.X, WorldService.GroundY(x + O.X, z + O.Z) - 0.3, z + O.Z)
	end

	for i, t in layout.Trees do
		local cf = ground(t.X, t.Z) * CFrame.Angles(0, math.rad((i * 67) % 360), 0)
		local m
		if t.Kind == "Pine" then
			m = Nature.Pine(cf, t.Scale, decor)
		elseif t.Kind == "Oak" then
			m = Nature.Oak(cf, t.Scale, decor)
		else
			m = Nature.Birch(cf, t.Scale, decor)
		end
		atomic(m)
		if i % 60 == 0 then
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
		terrain:FillBlock(CFrame.new(O + Vector3.new(0, 20, 0)), Vector3.new(2 * H, 48, 2 * H), Enum.Material.Air)
	end
	WorldService.Map = nil
end

-- Lobby -----------------------------------------------------------------------------------

function WorldService.BuildLobby()
	local O = Config.Map.LobbyOrigin
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace

	-- Island base: layered cylinders with rock underside.
	local top = Build.Cyl("Ground", 4, 150, CFrame.new(O + Vector3.new(0, -2, 0)), Color3.fromRGB(96, 150, 72), Enum.Material.Grass, folder)
	top.Name = "LobbyGround"
	Build.Cyl("Soil", 10, 146, CFrame.new(O + Vector3.new(0, -9, 0)), Color3.fromRGB(110, 84, 60), Enum.Material.Ground, folder)
	for i = 0, 15 do
		local a = math.rad(i * 22.5)
		Build.Part({ Name = "UnderRock", Size = Vector3.new(24, 30, 24), CFrame = CFrame.new(O + Vector3.new(math.cos(a) * 50, -26, math.sin(a) * 50)) * CFrame.Angles(0.3, a, 0.2), Color = Color3.fromRGB(104, 100, 96), Material = Enum.Material.Rock, Parent = folder, CanCollide = false })
	end
	-- Paths (cross)
	for _, rot in { 0, 90 } do
		Build.Part({ Name = "Path", Size = Vector3.new(10, 0.2, 130), CFrame = CFrame.new(O + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, math.rad(rot), 0), Color = Color3.fromRGB(150, 120, 86), Material = Enum.Material.Ground, Parent = folder, CanCollide = false })
	end
	-- Edge trees and rail
	for i = 0, 27 do
		local a = math.rad(i * (360 / 28) + 6)
		local cf = CFrame.new(O + Vector3.new(math.cos(a) * 68, 0, math.sin(a) * 68))
		local m = if i % 3 == 0 then Nature.Oak(cf, 0.9, folder) elseif i % 3 == 1 then Nature.Pine(cf, 1, folder) else Nature.Birch(cf, 1, folder)
		atomic(m)
	end
	Build.Part({ Name = "Rail", Shape = Enum.PartType.Cylinder, Size = Vector3.new(60, 152, 152), CFrame = CFrame.new(O + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 1, CanCollide = false, Parent = folder })
	for i = 0, 35 do
		local a = math.rad(i * 10)
		Build.Part({ Name = "EdgeWall", Size = Vector3.new(14, 40, 2), CFrame = CFrame.lookAt(O + Vector3.new(math.cos(a) * 75, 18, math.sin(a) * 75), O + Vector3.new(0, 18, 0)), Transparency = 1, Parent = folder })
	end

	-- Central campfire (decor)
	local fire = Camp.Campfire(CFrame.new(O), Color3.fromRGB(255, 200, 120), folder)
	fire.Name = "LobbyFire"
	local ring = fire:FindFirstChild("SafeRing") :: BasePart?
	if ring then
		ring:Destroy()
	end
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		Build.Cyl("LogSeat", 6, 1.8, CFrame.new(O + Vector3.new(math.cos(a) * 9, 0.9, math.sin(a) * 9)) * CFrame.Angles(0, -a, 0) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(120, 84, 54), Enum.Material.Wood, folder)
	end

	-- Ready ring (stand inside to ready up)
	local readyCenter = O + Vector3.new(0, 0, -38)
	local readyPad = Build.Cyl("ReadyPad", 0.4, 22, CFrame.new(readyCenter + Vector3.new(0, 0.2, 0)), Color3.fromRGB(70, 90, 70), Enum.Material.Slate, folder)
	readyPad.Name = "ReadyPad"
	local glow = Build.Cyl("ReadyGlow", 0.2, 24, CFrame.new(readyCenter + Vector3.new(0, 0.1, 0)), Color3.fromRGB(120, 255, 160), Enum.Material.Neon, folder, false)
	glow.Name = "ReadyGlow"
	glow.Transparency = 0.35
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local post = Build.Cyl("Torch", 5, 0.6, CFrame.new(readyCenter + Vector3.new(math.cos(a) * 12.5, 2.5, math.sin(a) * 12.5)), Color3.fromRGB(96, 66, 42), Enum.Material.Wood, folder)
		local flame = Instance.new("Fire")
		flame.Size = 2.5
		flame.Heat = 6
		flame.Parent = post
	end
	local sign = Build.Part({ Name = "ReadySign", Size = Vector3.new(16, 4, 0.5), CFrame = CFrame.new(readyCenter + Vector3.new(0, 9, -13)), Color = Color3.fromRGB(60, 44, 30), Material = Enum.Material.WoodPlanks, Parent = folder })
	Build.Label(sign, "STAND HERE TO READY UP", Vector3.new(0, 0, 0), Color3.fromRGB(180, 255, 190), 150)
	folder:SetAttribute("ReadyCenter", readyCenter)
	folder:SetAttribute("ReadyRadius", 11)

	-- Stations: Shop (east), Powerups (west), Party board (south)
	local function station(name: string, pos: Vector3, color: Color3, label: string, promptText: string)
		local m = Build.Model(name, folder)
		local counter = Build.Part({ Name = "Counter", Size = Vector3.new(10, 3.4, 3), CFrame = CFrame.lookAt(pos + Vector3.new(0, 1.7, 0), O + Vector3.new(0, 1.7, 0)), Color = Color3.fromRGB(120, 84, 54), Material = Enum.Material.WoodPlanks, Parent = m })
		for _, x in { -4.6, 4.6 } do
			Build.Part({ Name = "Post", Size = Vector3.new(0.8, 9, 0.8), CFrame = counter.CFrame * CFrame.new(x, 2.8, 1.2), Color = Color3.fromRGB(90, 62, 40), Material = Enum.Material.Wood, Parent = m })
		end
		Build.Part({ Class = "WedgePart", Name = "Awning", Size = Vector3.new(11, 1.6, 5), CFrame = counter.CFrame * CFrame.new(0, 7.6, 0) * CFrame.Angles(0, math.rad(180), 0), Color = color, Material = Enum.Material.Fabric, Parent = m })
		Build.Label(counter, label, Vector3.new(0, 9, 0), Color3.new(1, 1, 1), 120)
		m.PrimaryPart = counter
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StationPrompt"
		prompt.ActionText = promptText
		prompt.ObjectText = label
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Station", name)
		prompt:SetAttribute("Action", "Station")
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Parent = counter
		return m
	end
	station("Shop", O + Vector3.new(40, 0, 0), Color3.fromRGB(230, 170, 60), "TRADING POST", "Open Shop")
	local shrine = station("Powerups", O + Vector3.new(-40, 0, 0), Color3.fromRGB(120, 200, 180), "POWERUP SHRINE", "Choose Powerup")
	local Powerups = require(Shared:WaitForChild("Powerups"))
	for i, def in Powerups.List do
		local a = math.rad(-75 + (i - 1) * 30)
		local pos = O + Vector3.new(-40 + math.cos(a + math.pi) * -9, 0, math.sin(a) * 12)
		local ped = Build.Cyl("Pedestal", 3, 2.4, CFrame.new(pos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(140, 136, 128), Enum.Material.Marble, shrine)
		local orb = Build.Ball("Orb", 1.6, CFrame.new(pos + Vector3.new(0, 4, 0)), Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]), Enum.Material.Neon, shrine)
		orb.CanQuery = false
		Build.Label(ped, def.Glyph .. " " .. def.Name, Vector3.new(0, 5.4, 0), Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]), 60)
	end
	station("Party", O + Vector3.new(0, 0, 40), Color3.fromRGB(110, 150, 230), "PARTY BOARD", "Manage Party")

	-- Title
	local title = Build.Part({ Name = "Title", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(O + Vector3.new(0, 26, -50)), Transparency = 1, CanCollide = false, Parent = folder })
	local bb = Build.Label(title, "SURVIVAL HOUR", Vector3.new(0, 0, 0), Color3.fromRGB(255, 200, 120), 400)
	bb.Size = UDim2.fromOffset(700, 110)
	bb.AlwaysOnTop = false

	WorldService.LobbySpawn = CFrame.new(O + Vector3.new(0, 4, 18)) * CFrame.Angles(0, math.rad(180), 0)
	return folder
end

return WorldService
