-- Builds the lobby from parts at server start: spawn, egg stands, training area,
-- race portal, leaderboard and decoration. Other services read the positions it
-- publishes (gates, hurdles, treadmill, portal).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Eggs)
local Pets = require(Shared.Pets)
local Hatch = require(Shared.Logic.Hatch)
local Assets = require(Shared.Assets)

local WorldService = {}
local Util

WorldService.SpawnPos = Vector3.new(0, 3, 0)
WorldService.EggStands = {} :: { [string]: Vector3 }
WorldService.SpeedGates = {} :: { Vector3 }
WorldService.Hurdles = {} :: { { Z: number, X0: number, X1: number, H: number } }
WorldService.Treadmill = { Center = Vector3.new(), Size = Vector3.new() }
WorldService.Portal = { Center = Vector3.new(0, 0, 75), Size = Vector3.new(26, 12, 20) }
WorldService.Leaderboard = nil :: BasePart?

local lobby: Folder

local GRASS = Color3.fromRGB(95, 215, 70)

local TREES = { "Tree_Round", "Tree_Pine", "Tree_Blossom" }

local function tree(pos: Vector3, scale: number, rng: Random)
	if Assets.Place(TREES[rng:NextInteger(1, #TREES)], CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), lobby, scale) then
		return
	end
	Util.Part({
		Size = Vector3.new(8, 1.6, 1.6) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 4 * scale, 0)),
		Color = Color3.fromRGB(120, 80, 50),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Cylinder,
		Name = "Trunk",
	}, lobby).CFrame = CFrame.new(pos + Vector3.new(0, 4 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90))
	Util.Part({
		Size = Vector3.new(9, 9, 9) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 10 * scale, 0)),
		Color = Color3.fromRGB(80, 200, 75),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Name = "Leaves",
	}, lobby)
end

local function sign(pos: Vector3, text: string, color: Color3)
	local board = Util.Part({
		Size = Vector3.new(14, 4, 0.6),
		CFrame = CFrame.new(pos),
		Color = color,
		Name = "Sign",
	}, lobby)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Parent = gui
	gui.Parent = board
	local back = gui:Clone()
	back.Face = Enum.NormalId.Back
	back.Parent = board
	Util.Part({
		Size = Vector3.new(0.6, pos.Y, 0.6),
		CFrame = CFrame.new(pos.X, pos.Y / 2, pos.Z),
		Color = Color3.fromRGB(120, 80, 50),
		Name = "Post",
	}, lobby)
end

local function buildGround()
	Util.Part({
		Size = Vector3.new(500, 2, 500),
		CFrame = CFrame.new(0, -1, 0),
		Color = GRASS,
		Material = Enum.Material.SmoothPlastic,
		Name = "Ground",
	}, lobby)
	-- Invisible walls so nobody wanders off the edge.
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		Util.Part({
			Size = if d.X ~= 0 then Vector3.new(2, 80, 500) else Vector3.new(500, 80, 2),
			CFrame = CFrame.new(d * 250 + Vector3.new(0, 40, 0)),
			Transparency = 1,
			Name = "Edge",
		}, lobby)
	end
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Size = Vector3.new(12, 1, 12)
	spawnLoc.CFrame = CFrame.new(0, 0.5, 0)
	spawnLoc.Anchored = true
	spawnLoc.Color = Color3.fromRGB(255, 230, 120)
	spawnLoc.Material = Enum.Material.SmoothPlastic
	spawnLoc.Neutral = true
	spawnLoc.Duration = 0
	spawnLoc.Parent = lobby
	-- Dirt paths from spawn to each area.
	for _, p in { { Vector3.new(0, 0.05, -25), Vector3.new(8, 0.1, 40) }, { Vector3.new(0, 0.05, 40), Vector3.new(8, 0.1, 60) }, { Vector3.new(45, 0.05, 0), Vector3.new(80, 0.1, 8) }, { Vector3.new(-45, 0.05, 0), Vector3.new(80, 0.1, 8) } } do
		Util.Part({
			Size = p[2],
			CFrame = CFrame.new(p[1]),
			Color = Color3.fromRGB(255, 220, 150),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Name = "Path",
		}, lobby)
	end
	local rng = Random.new(7)
	for _ = 1, 40 do
		local x = rng:NextNumber(-230, 230)
		local z = rng:NextNumber(-230, 230)
		-- keep clear of the play areas
		if math.abs(x) > 140 or math.abs(z) > 120 then
			tree(Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.4), rng)
		end
	end
	-- Extra decoration that only exists as 3D models (skipped until they're uploaded).
	for _ = 1, 60 do
		local x = rng:NextNumber(-235, 235)
		local z = rng:NextNumber(-235, 235)
		if math.abs(x) > 130 or math.abs(z) > 110 or (math.abs(x) > 20 and math.abs(z) > 20 and math.abs(x) < 35) then
			local kind = ({ "Bush", "Rock", "Flowers", "Flowers" })[rng:NextInteger(1, 4)]
			Assets.Place(kind, CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), lobby, rng:NextNumber(0.8, 1.3))
		end
	end
	-- Fence around the edge, lamps along the paths, and a trophy by the spawn.
	if Assets.Has("Fence") then
		for i = -20, 20 do
			for _, side in { -1, 1 } do
				Assets.Place("Fence", CFrame.new(i * 12, 0, side * 244), lobby)
				Assets.Place("Fence", CFrame.new(side * 244, 0, i * 12) * CFrame.Angles(0, math.rad(90), 0), lobby)
			end
		end
	end
	for _, p in { Vector3.new(7, 0, -20), Vector3.new(-7, 0, -20), Vector3.new(7, 0, 30), Vector3.new(-7, 0, 30), Vector3.new(30, 0, 7), Vector3.new(60, 0, -7), Vector3.new(-30, 0, 7), Vector3.new(-60, 0, -7) } do
		Assets.Place("LampPost", CFrame.new(p), lobby)
	end
	Assets.Place("TrophyStatue", CFrame.new(22, 0, 18) * CFrame.Angles(0, math.rad(-135), 0), lobby)
end

local function buildEggs()
	local spacing = 26
	local startX = -spacing * (#Eggs.List - 1) / 2
	sign(Vector3.new(0, 14, -38), "EGGS", Color3.fromRGB(255, 170, 60))
	for i, egg in Eggs.List do
		local pos = Vector3.new(startX + (i - 1) * spacing, 0, -55)
		WorldService.EggStands[egg.Id] = pos
		local meshPedestal = Assets.Place("Pedestal", CFrame.new(pos), lobby)
		local pedestalPart = Util.Part({
			Size = Vector3.new(3, 10, 10),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)),
			Color = Color3.fromRGB(240, 240, 240),
			Material = Enum.Material.SmoothPlastic,
			Shape = Enum.PartType.Cylinder,
			Name = "Pedestal",
		}, lobby)
		pedestalPart.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		if meshPedestal then
			pedestalPart.Transparency = 1 -- keep it as the collider/stand height
		end
		local eggMesh = Assets.Place("Egg_" .. egg.Id, CFrame.new(pos + Vector3.new(0, 3, 0)), lobby)
		local e = Util.Part({
			Size = Vector3.new(5, 7, 5),
			CFrame = CFrame.new(pos + Vector3.new(0, 6.5, 0)),
			Color = Util.Rgb(egg.Color),
			Material = Enum.Material.SmoothPlastic,
			Name = egg.Id .. "Egg",
		}, lobby)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = e
		if eggMesh then
			e.Transparency = 1 -- the mesh egg shows; this part still holds the prompt
			e.CanCollide = false
		end
		-- Spots
		for s = 1, if eggMesh then 0 else 5 do
			local a = s * 1.3
			local spot = Util.Part({
				Size = Vector3.new(1.2, 1.2, 0.3),
				CFrame = CFrame.new(pos + Vector3.new(0, 6.5, 0))
					* CFrame.Angles(0, a, 0)
					* CFrame.new(0, (s - 3) * 0.9, -2.4),
				Color = Color3.new(1, 1, 1),
				CanCollide = false,
				Name = "Spot",
			}, e)
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = spot
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Hatch"
		prompt.ObjectText = egg.Name .. " (" .. egg.Price .. " coins)"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Name = "HatchPrompt"
		prompt:SetAttribute("Egg", egg.Id)
		prompt.Parent = e
		-- Odds board above the egg.
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(200, 40 + 22 * #egg.Odds)
		bb.StudsOffset = Vector3.new(0, 7.5, 0)
		bb.MaxDistance = 60
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
		frame.BackgroundTransparency = 0.25
		frame.Parent = bb
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 34)
		title.BackgroundTransparency = 1
		title.Text = egg.Name .. " - " .. egg.Price .. " coins"
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 230, 120)
		title.Parent = frame
		for j, c in Hatch.Chances(egg) do
			local s = Pets.ById[c.Pet]
			local row = Instance.new("TextLabel")
			row.Size = UDim2.new(1, -12, 0, 20)
			row.Position = UDim2.fromOffset(6, 36 + (j - 1) * 22)
			row.BackgroundTransparency = 1
			row.Font = Enum.Font.GothamBold
			row.TextSize = 15
			row.TextXAlignment = Enum.TextXAlignment.Left
			local pct = c.Chance * 100
			row.Text = string.format("%s  %s%%", s.Name, if pct < 1 then string.format("%.1f", pct) else tostring(math.floor(pct + 0.5)))
			row.TextColor3 = Util.Rgb(Pets.Rarities[s.Rarity].Color)
			row.Parent = frame
		end
		bb.Parent = e
	end
end

local function buildTraining()
	-- SPEED: a ring of gates; ride through them in order.
	local center = Vector3.new(120, 0, 10)
	local radius = 45
	sign(Vector3.new(68, 14, 0), "SPEED RING", Color3.fromRGB(60, 160, 255))
	Util.Part({
		Size = Vector3.new(0.2, radius * 2 + 16, radius * 2 + 16),
		CFrame = CFrame.new(center + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(210, 180, 130),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "RingTrack",
	}, lobby)
	Util.Part({
		Size = Vector3.new(0.4, radius * 2 - 16, radius * 2 - 16),
		CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GRASS,
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "RingInfield",
	}, lobby)
	local n = 8
	for i = 1, n do
		local a = (i - 1) / n * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		table.insert(WorldService.SpeedGates, pos)
		-- the opening faces along the ring, so riders go straight through it
		local facing = CFrame.lookAt(pos, center) * CFrame.Angles(0, math.rad(90), 0)
		local gateMesh = Assets.Place("SpeedGate", facing, lobby)
		for _, side in { -1, 1 } do
			if gateMesh then
				break
			end
			Util.Part({
				Size = Vector3.new(1.2, 14, 1.2),
				CFrame = facing * CFrame.new(side * 7, 7, 0),
				Color = Color3.fromRGB(60, 160, 255),
				Material = Enum.Material.Neon,
				Name = "GatePost",
			}, lobby)
		end
		local top = Util.Part({
			Size = Vector3.new(15.2, 1.2, 1.2),
			CFrame = facing * CFrame.new(0, 14, 0),
			Color = Color3.fromRGB(60, 160, 255),
			Material = Enum.Material.Neon,
			Name = "GateTop",
		}, lobby)
		if gateMesh then
			top.Transparency = 1
			top.CanCollide = false
		end
		Util.Label(top, tostring(i), 2)
	end

	-- JUMP: a line of hurdles that get taller.
	sign(Vector3.new(-68, 14, 0), "JUMP HURDLES", Color3.fromRGB(255, 120, 60))
	local hx0, hx1 = -150, -110
	Util.Part({
		Size = Vector3.new(hx1 - hx0 + 6, 0.2, 170),
		CFrame = CFrame.new((hx0 + hx1) / 2, 0.06, 10),
		Color = Color3.fromRGB(210, 180, 130),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Name = "HurdleLane",
	}, lobby)
	for i, h in { 2, 3, 4, 5, 6, 7, 8 } do
		local z = -60 + (i - 1) * 22
		table.insert(WorldService.Hurdles, { Z = z, X0 = hx0, X1 = hx1, H = h })
		local wall = Util.Part({
			Size = Vector3.new(hx1 - hx0, h, 1.5),
			CFrame = CFrame.new((hx0 + hx1) / 2, h / 2, z),
			Color = if i % 2 == 0 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 120, 60),
			Name = "Hurdle",
		}, lobby)
		Util.Label(wall, h .. " studs", 2.5)
	end

	-- STAMINA: a treadmill that pushes you back; keep running to stay on.
	sign(Vector3.new(-40, 14, -95), "STAMINA TREADMILL", Color3.fromRGB(120, 220, 80))
	local tCenter = Vector3.new(-60, 0.5, -120)
	local tSize = Vector3.new(24, 1, 50)
	WorldService.Treadmill = { Center = tCenter, Size = tSize }
	local belt = Util.Part({
		Size = tSize,
		CFrame = CFrame.new(tCenter),
		Color = Color3.fromRGB(50, 50, 60),
		Material = Enum.Material.DiamondPlate,
		Name = "Treadmill",
	}, lobby)
	belt.AssemblyLinearVelocity = Vector3.new(0, 0, 18)
	local tex = Instance.new("Texture")
	tex.Texture = "rbxasset://textures/ui/Controls/DesignSystem/ButtonDefault.png"
	tex.Face = Enum.NormalId.Top
	tex.Transparency = 0.8
	tex.StudsPerTileU = 4
	tex.StudsPerTileV = 4
	tex.Parent = belt
	for _, side in { -1, 1 } do
		Util.Part({
			Size = Vector3.new(1, 4, tSize.Z),
			CFrame = CFrame.new(tCenter + Vector3.new(side * (tSize.X / 2 + 0.5), 1.5, 0)),
			Color = Color3.fromRGB(120, 220, 80),
			Name = "Rail",
		}, lobby)
	end
end

local function buildPortal()
	local c = WorldService.Portal.Center
	sign(Vector3.new(0, 16, 50), "RACE PORTAL", Color3.fromRGB(255, 80, 160))
	Util.Part({
		Size = Vector3.new(WorldService.Portal.Size.X, 0.4, WorldService.Portal.Size.Z),
		CFrame = CFrame.new(c + Vector3.new(0, 0.2, 0)),
		Color = Color3.fromRGB(255, 80, 160),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
		Name = "PortalPad",
	}, lobby)
	local portalMesh = Assets.Place("PortalArch", CFrame.new(c + Vector3.new(0, 0, 10)), lobby)
	for _, side in { -1, 1 } do
		if portalMesh then
			break
		end
		Util.Part({
			Size = Vector3.new(3, 22, 3),
			CFrame = CFrame.new(c + Vector3.new(side * 15, 11, 10)),
			Color = Color3.fromRGB(80, 60, 120),
			Material = Enum.Material.SmoothPlastic,
			Name = "PortalPillar",
		}, lobby)
	end
	local top = Util.Part({
		Size = Vector3.new(33, 3, 3),
		CFrame = CFrame.new(c + Vector3.new(0, 23.5, 10)),
		Color = Color3.fromRGB(80, 60, 120),
		Material = Enum.Material.SmoothPlastic,
		Name = "PortalTop",
	}, lobby)
	if portalMesh then
		top.Transparency = 1 -- the arch mesh shows; the part keeps the status label
		top.CanCollide = false
	end
	local status = Util.Label(top, "Stand here to race!", 6, Color3.fromRGB(255, 230, 255))
	status.Name = "PortalStatus"
	status.MaxDistance = 250
	local swirl = Util.Part({
		Size = Vector3.new(27, 20, 0.5),
		CFrame = CFrame.new(c + Vector3.new(0, 11, 10.5)),
		Color = Color3.fromRGB(200, 100, 255),
		Material = Enum.Material.ForceField,
		CanCollide = false,
		Name = "PortalSwirl",
	}, lobby)
	swirl.Transparency = 0.2
end

local function buildLeaderboard()
	local board = Util.Part({
		Size = Vector3.new(18, 22, 1),
		CFrame = CFrame.new(-45, 12, 60) * CFrame.Angles(0, math.rad(35), 0),
		Color = Color3.fromRGB(40, 40, 60),
		Name = "Leaderboard",
	}, lobby)
	Util.Part({
		Size = Vector3.new(18, 1, 3),
		CFrame = board.CFrame * CFrame.new(0, -11.5, 0),
		Color = Color3.fromRGB(80, 60, 50),
		Name = "LeaderboardBase",
	}, lobby)
	WorldService.Leaderboard = board
end

local function effect(className: string, props: { [string]: any })
	local e = Lighting:FindFirstChildOfClass(className :: any) or Instance.new(className :: any)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = Lighting
end

-- Bright, saturated cartoon look: sunny sky, soft colourful ambient light, a little
-- bloom on the sparkles and neon, and punchier colours.
local function buildLighting()
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(120, 110, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 170, 200)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	effect("Atmosphere", { Density = 0.28, Offset = 0.15, Haze = 0.6, Glare = 0.2, Color = Color3.fromRGB(205, 230, 255), Decay = Color3.fromRGB(120, 170, 255) })
	effect("Sky", { CelestialBodiesShown = true, SunAngularSize = 14, StarCount = 0 })
	effect("ColorCorrectionEffect", { Saturation = 0.28, Contrast = 0.1, Brightness = 0.03, TintColor = Color3.fromRGB(255, 252, 245) })
	effect("BloomEffect", { Intensity = 0.45, Size = 26, Threshold = 0.92 })
	effect("SunRaysEffect", { Intensity = 0.05, Spread = 0.6 })
end

function WorldService.Init(ctx)
	Util = ctx.Util
	lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace
	buildLighting()
	buildGround()
	buildEggs()
	buildTraining()
	buildPortal()
	buildLeaderboard()
end

function WorldService.SetPortalText(text: string)
	local top = lobby:FindFirstChild("PortalTop")
	local gui = top and top:FindFirstChild("PortalStatus")
	local label = gui and gui:FindFirstChild("Text") :: TextLabel?
	if label then
		label.Text = text
	end
end

function WorldService.InBox(pos: Vector3, center: Vector3, size: Vector3): boolean
	local d = pos - center
	return math.abs(d.X) <= size.X / 2 and math.abs(d.Z) <= size.Z / 2 and d.Y >= -2 and d.Y <= size.Y + 12
end

return WorldService
