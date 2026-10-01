--!strict
-- The farm world: hub, boulevard, hills, lighting and the 8 player plots, all native parts.
-- Layout numbers live in Shared/Logic/PlotLayout (pure, unit-tested); this module turns them
-- into instances that follow the World contract in docs/ARCHITECTURE.md.
--
--   World.Init()                 once: hub, roads, ridges, lighting, Workspace.Plots/Plot1..Plot8
--   World.PlotCount              8
--   World.GetPlot(index) -> Model
--   World.ApplyState(plot, info) idempotent; info = { egg, houses{4}, vehicles{8}, workers{8},
--                                silos, permanentSilos, ownerName? }. Only changed pieces are
--                                rebuilt: house tier swaps (old model destroyed, build puff),
--                                theme recolour when the egg changes, silos, bay lamps, nameplate.
--   World.ResetPlot(plot)        back to an empty, unowned farm ("Free plot")
--   World.Zones(plot) -> { collect = { [slot]: BasePart }, deposit: BasePart,
--                          foxSpots: { Vector3 }, spawn: SpawnLocation }
-- Ring zone parts are unrotated, invisible blocks: radius = Size.X / 2 (= Size.Z / 2), as
-- ZoneService expects; the glow is drawn by their child parts.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Kit = require(Shared:WaitForChild("Models"):WaitForChild("Kit"))
local Layout = require(Logic:WaitForChild("PlotLayout"))
local Eggs = require(Shared:WaitForChild("Data"):WaitForChild("Eggs"))
local GameInfo = require(Shared:WaitForChild("GameInfo"))
local Houses = require(script.Parent:WaitForChild("Houses"))
local Props = require(script.Parent:WaitForChild("Props"))

local World = {}
World.PlotCount = Layout.PlotCount

type Vec = Layout.Vec

type PlotState = {
	index: number,
	cf: CFrame,
	theme: string,
	decor: string,
	houses: { number },
	silos: { string }, -- per silo spot: "" (empty), "b" (built) or "p" (permanent)
	bays: { boolean },
	owner: string?,
	buildings: { Model? },
	houseModels: { Model },
	rings: { [number]: BasePart },
	deposit: BasePart,
	spawn: SpawnLocation,
	gateFront: TextLabel,
	gateBack: TextLabel,
	siloFolder: Folder,
	decorModel: Model,
	dock: Model,
	foxSpots: { Vector3 },
}

local plots: { Model } = {}
local states: { [Model]: PlotState } = {}
local initialized = false

local F = Kit.Fixed

local function v3(p: Vec): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function themeOf(egg: number?): string
	local e = Eggs.List[math.clamp(math.floor(tonumber(egg) or 1), 1, Eggs.Count)]
	return e.theme
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function marker(parent: Instance, name: string, cf: CFrame, size: Vector3?): BasePart
	return Kit.Part(parent, {
		name = name,
		size = size or Vector3.new(1, 1, 1),
		cf = cf,
		transparency = 1,
		collide = false,
		shadow = false,
	})
end

-- ------------------------------------------------------------------ lighting & sky
local function setupLighting()
	local palette = Kit.Palette("meadow")
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.28
	atmo.Offset = 0.2
	atmo.Color = palette.fog
	atmo.Decay = Color3.fromRGB(150, 170, 200)
	atmo.Glare = 0.2
	atmo.Haze = 1.2
	atmo.Parent = Lighting
	local function ensure(class: string, name: string): Instance
		local e = Lighting:FindFirstChild(name)
		if not e then
			e = Instance.new(class)
			e.Name = name
			e.Parent = Lighting
		end
		return e :: Instance
	end
	local bloom = ensure("BloomEffect", "WorldBloom") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 1.4
	local cc = ensure("ColorCorrectionEffect", "WorldGrade") :: ColorCorrectionEffect
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	local rays = ensure("SunRaysEffect", "WorldSunRays") :: SunRaysEffect
	rays.Intensity = 0.04
	rays.Spread = 0.6
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.55
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end
end

-- ------------------------------------------------------------------ hub, boulevard, hills
local function buildCommons(root: Folder)
	local stone = Color3.fromRGB(196, 190, 176)
	local grass = Color3.fromRGB(104, 176, 80)
	Kit.SetPalette(Kit.Palette("meadow"))
	local P = Props.P
	P(root, "Baseplate", Vector3.new(1100, 4, 860), CFrame.new(0, -2.4, 0), grass, { material = Enum.Material.Grass, collide = true, shadow = false })
	-- boulevard along x with sidewalks and lane dashes
	local half = 4 * Layout.COLUMN_SPACING / 2 + 30
	P(root, "Boulevard", Vector3.new(half * 2, 0.3, 20), CFrame.new(0, -0.1, 0), F.asphalt, { collide = true, shadow = false })
	for _, z in { -14, 14 } do
		P(root, "Sidewalk", Vector3.new(half * 2, 0.5, 8), CFrame.new(0, 0, z), stone, { collide = true, shadow = false })
	end
	for x = -half + 15, half - 15, 30 do
		if math.abs(x) > 34 then
			P(root, "Dash", Vector3.new(8, 0.06, 0.8), CFrame.new(x, 0.08, 0), F.white, { collide = false, shadow = false })
		end
	end
	-- lamp posts
	for x = -half + 40, half - 40, 100 do
		for _, z in { -17, 17 } do
			P(root, "LampPost", Vector3.new(0.6, 10, 0.6), CFrame.new(x, 5, z), F.darkMetal, { collide = true, shadow = false })
			P(root, "Lamp", Vector3.new(1.6, 1.2, 1.6), CFrame.new(x, 10.4, z), Color3.fromRGB(255, 236, 180), { material = Enum.Material.Neon, shadow = false })
		end
	end
	-- side paths between neighbouring plots, from the boulevard to the hills
	for c = 1, 3 do
		local x = (c - 2) * Layout.COLUMN_SPACING
		for _, sign in { -1, 1 } do
			local z0, z1 = 18, Layout.ROW_Z + Layout.HALF_D
			P(root, "SidePath", Vector3.new(10, 0.3, z1 - z0), CFrame.new(x, -0.05, sign * (z0 + z1) / 2), stone, { collide = true, shadow = false })
		end
	end
	-- hub plaza with the hub spawn and a giant egg statue
	Kit.Column(root, CFrame.new(0, -0.2, 0), 0.6, 64, { name = "Plaza", color = stone, collide = true })
	Kit.Column(root, CFrame.new(0, 0.1, 0), 0.4, 50, { name = "PlazaInner", color = Color3.fromRGB(230, 214, 170), collide = true })
	Kit.Column(root, CFrame.new(0, 0.5, 0), 2.4, 16, { name = "Pedestal", color = F.white, collide = true, shadow = true })
	Kit.Column(root, CFrame.new(0, 2.9, 0), 0.6, 16.6, { name = "PedestalRing", color = Color3.fromRGB(255, 200, 60) })
	Kit.Egg(root, CFrame.new(0, 11.5, 0), Vector3.new(10, 14, 10), { name = "GoldenEgg", color = Color3.fromRGB(255, 210, 70), reflect = 0.2, shadow = true, collide = true })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.1, -20)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 214, 74)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = root
	local sign = P(root, "HubSign", Vector3.new(30, 6, 1), CFrame.new(0, 22, 0) * CFrame.Angles(0, 0, 0), Color3.fromRGB(230, 70, 60), { shadow = true })
	Kit.Label(sign, GameInfo.Name, Enum.NormalId.Front, Color3.new(1, 1, 1), 20)
	Kit.Label(sign, GameInfo.Name, Enum.NormalId.Back, Color3.new(1, 1, 1), 20)
	P(root, "SignPole", Vector3.new(0.6, 4, 0.6), CFrame.new(0, 17.6, 0), F.darkMetal)
	for i = 0, 7 do
		local a = i * math.pi / 4
		local x, z = math.cos(a) * 27, math.sin(a) * 27
		if math.abs(z) > 8 then
			P(root, "Planter", Vector3.new(4, 1.6, 4), CFrame.new(x, 0.8, z), F.trunk, { collide = true })
			P(root, "Bush", Vector3.one * 4, CFrame.new(x, 2.6, z), F.leaf, { shape = "Ball" })
		end
	end
	-- hills behind each row, with one tunnel per plot for the market road
	for _, north in { true, false } do
		local dir = if north then 1 else -1
		local faceZ = dir * (Layout.ROW_Z - Layout.RIDGE_LOCAL_Z)
		local face = CFrame.lookAt(Vector3.new(0, 0, faceZ), Vector3.new(0, 0, faceZ + dir))
		local tunnels = {}
		for i = 1, Layout.PlotCount do
			if (i <= 4) == north then
				local p = Layout.ToWorld(i, { x = Layout.ROAD_X, y = 0, z = Layout.RIDGE_LOCAL_Z })
				table.insert(tunnels, CFrame.lookAt(Vector3.new(p.x, 0, p.z), Vector3.new(p.x, 0, p.z + dir)))
			end
		end
		Props.Ridge(root, face, half * 2 + 200, Layout.RIDGE_DEPTH, tunnels)
	end
end

-- ------------------------------------------------------------------ one plot
local function buildDecor(st: PlotState, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Decor"
	for i, d in Layout.Decor do
		local cf = st.cf * CFrame.new(d.x, 0, d.z)
		Props.Decor(m, st.decor, cf, st.index * 100 + i)
	end
	m.Parent = parent
	st.decorModel = m
end

local function puff(at: Vector3, palette: Kit.Palette, scale: number?)
	local s = scale or 1
	local holder = Kit.Part(Workspace, {
		name = "BuildPuff",
		size = Vector3.new(1, 1, 1),
		cf = CFrame.new(at),
		transparency = 1,
		collide = false,
		shadow = false,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), palette.accent)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3 * s), NumberSequenceKeypoint.new(1, 7 * s) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(8 * s, 16 * s)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 120
	emitter.Drag = 4
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = holder
	holder.Size = Vector3.new(14, 2, 14) * s
	task.delay(0.3, function()
		emitter.Enabled = false
	end)
	Debris:AddItem(holder, 2.5)
end

local function houseCF(st: PlotState, slot: number): CFrame
	local h = Layout.Houses[slot]
	local pos = (st.cf * CFrame.new(h.building.x, 0, h.building.z)).Position
	local dir = st.cf:VectorToWorldSpace(v3(h.facing))
	return CFrame.lookAt(pos, pos + dir)
end

local function setHouse(st: PlotState, slot: number, tier: number, palette: Kit.Palette, withPuff: boolean)
	local old = st.buildings[slot]
	if old and st.houses[slot] == tier then
		return
	end
	if old then
		old:Destroy()
	end
	local model = Houses.Build(tier, palette)
	model.Name = "Building"
	model:PivotTo(houseCF(st, slot))
	model.Parent = st.houseModels[slot]
	st.buildings[slot] = model
	st.houses[slot] = tier
	if withPuff and old then
		puff(houseCF(st, slot).Position + Vector3.new(0, 4, 0), palette, if tier >= 6 then 1.6 else 1)
	end
end

local function setSilo(st: PlotState, i: number, code: string, palette: Kit.Palette)
	if st.silos[i] == code then
		return
	end
	local existing = st.siloFolder:FindFirstChild("Silo" .. i)
	if existing then
		existing:Destroy()
	end
	Kit.SetPalette(palette)
	local s = Layout.Silos[i]
	Props.Silo(st.siloFolder, "Silo" .. i, st.cf * CFrame.new(s.x, 0, s.z), Layout.SiloRadius, code ~= "", code == "p")
	st.silos[i] = code
end

local function setBay(st: PlotState, i: number, owned: boolean, palette: Kit.Palette)
	if st.bays[i] == owned then
		return
	end
	st.bays[i] = owned
	local bay = st.dock:FindFirstChild("Bay" .. i)
	local lamp = bay and bay:FindFirstChild("Lamp")
	if lamp and lamp:IsA("BasePart") then
		lamp.Color = if owned then palette.accent else F.darkStone
		lamp:SetAttribute("Role", if owned then "accent" else nil)
	end
end

local function setOwner(st: PlotState, name: string?)
	if st.owner == name then
		return
	end
	st.owner = name
	local text = if name and name ~= "" then name .. "'s Farm" else "Free plot"
	st.gateFront.Text = text
	st.gateBack.Text = text
end

local function buildPlot(index: number, parent: Instance): Model
	local o, yaw = Layout.Origin(index)
	local plotCF = CFrame.new(o.x, 0, o.z) * CFrame.Angles(0, yaw, 0)
	local function L(x: number, z: number, y: number?): CFrame
		return plotCF * CFrame.new(x, y or 0, z)
	end
	local function look(from: Vec, to: Vec): CFrame
		local a = L(from.x, from.z).Position
		local b = L(to.x, to.z).Position
		return CFrame.lookAt(a, b)
	end
	local themeKey = "meadow"
	local palette = Kit.Palette(themeKey)
	Kit.SetPalette(palette)

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("PlotIndex", index)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("Egg", 1)
	plot:SetAttribute("Population", 0)
	plot:SetAttribute("HouseTiers", "0,0,0,0")
	plot:SetAttribute("VehicleTiers", "0,0,0,0,0,0,0,0")
	plot:SetAttribute("WorkerTiers", "0,0,0,0,0,0,0,0")
	plot:SetAttribute("Silos", 0)

	local P = Props.P
	-- ground, paths, lots and road surfaces
	local ground = Instance.new("Model")
	ground.Name = "Ground"
	P(ground, "Field", Vector3.new(Layout.PLOT_W, 1, Layout.PLOT_D), L(0, 0, -0.5), "ground", { material = Enum.Material.Grass, collide = true, shadow = false })
	P(ground, "Border", Vector3.new(Layout.PLOT_W + 4, 0.6, Layout.PLOT_D + 4), L(0, 0, -0.55), "groundEdge", { collide = true, shadow = false })
	for _, r in Layout.Paths do
		P(ground, "Path", Vector3.new(r.x1 - r.x0, 0.2, r.z1 - r.z0), L((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, 0.0), "path", { collide = true, shadow = false })
	end
	for _, r in Layout.RoadRects do
		P(ground, "Road", Vector3.new(r.x1 - r.x0, 0.24, r.z1 - r.z0), L((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, 0.0), F.asphalt, { collide = true, shadow = false })
	end
	P(ground, "RoadLine", Vector3.new(120, 0.05, 0.6), L(15, Layout.ROAD_Z, 0.14), F.yellow, { collide = false, shadow = false })
	ground.Parent = plot

	local st: PlotState = {
		index = index,
		cf = plotCF,
		theme = themeKey,
		decor = Kit.Decor(themeKey),
		houses = {},
		silos = {},
		bays = {},
		owner = "\0",
		buildings = {},
		houseModels = {},
		rings = {},
		deposit = nil :: any,
		spawn = nil :: any,
		gateFront = nil :: any,
		gateBack = nil :: any,
		siloFolder = nil :: any,
		decorModel = nil :: any,
		dock = nil :: any,
		foxSpots = {},
	}

	-- houses: lot pad, yard anchor, collect ring; the tier model is added by setHouse
	local housesFolder = folder(plot, "Houses")
	for _, h in Layout.Houses do
		local hm = Instance.new("Model")
		hm.Name = "House" .. h.slot
		hm:SetAttribute("Slot", h.slot)
		local lot = h.lot
		P(hm, "Lot", Vector3.new(lot.x1 - lot.x0, 0.3, lot.z1 - lot.z0), L((lot.x0 + lot.x1) / 2, (lot.z0 + lot.z1) / 2, 0.0), "groundEdge", { collide = true, shadow = false })
		local anchor = marker(hm, "Anchor", L(h.anchor.x, h.anchor.z, 0.2), Vector3.new(h.anchorSize.x, 0.4, h.anchorSize.z))
		anchor:SetAttribute("Slot", h.slot)
		-- a low hay strip marks the yard where the flock wanders
		P(hm, "Yard", Vector3.new(h.anchorSize.x + 1, 0.12, h.anchorSize.z + 1), L(h.anchor.x, h.anchor.z, 0.17), F.hay, { collide = false, shadow = false, transparency = 0.35 })
		local ring = Props.Ring(hm, "CollectRing", L(h.ring.x, h.ring.z, 0.0), h.ringRadius)
		ring:SetAttribute("Slot", h.slot)
		st.rings[h.slot] = ring
		hm.Parent = housesFolder
		st.houseModels[h.slot] = hm
	end

	-- warehouse + deposit ring
	local wh = Layout.Warehouse
	local warehouse = Props.Warehouse(plot, look(wh.center, { x = wh.center.x, y = 0, z = wh.center.z + 1 }), wh.w, wh.d)
	st.deposit = Props.Ring(warehouse, "DepositRing", L(Layout.Deposit.pos.x, Layout.Deposit.pos.z), Layout.Deposit.radius)

	-- dock with bays, road waypoints
	local bayCFs = {}
	for i, b in Layout.Bays do
		bayCFs[i] = look(b, { x = b.x, y = 0, z = b.z - 1 })
	end
	local dc = Layout.Dock.center
	st.dock = Props.Dock(plot, look(dc, { x = dc.x, y = 0, z = dc.z - 1 }), Layout.Dock.w, Layout.Dock.d, bayCFs)
	local road = folder(plot, "Road")
	road:SetAttribute("TunnelAt", Layout.TunnelAt)
	for k, p in Layout.Road do
		local nxt = Layout.Road[k + 1] or { x = p.x, y = 0, z = p.z - 1 }
		local part = marker(road, "P" .. k, look(p, nxt))
		part:SetAttribute("Index", k)
	end

	-- worker shed and path start
	local shed = Layout.Shed
	Props.Shed(plot, look(shed.center, { x = shed.center.x - 1, y = 0, z = shed.center.z }), shed.d, shed.w)
	local wp = Instance.new("Model")
	wp.Name = "WorkerPath"
	local start = marker(wp, "Start", L(Layout.WorkerStart.x, Layout.WorkerStart.z, 0.5))
	wp.PrimaryPart = start
	wp.Parent = plot

	-- silos (spots 1..10, built on demand)
	st.siloFolder = folder(plot, "Silos")
	for i = 1, Layout.SiloCount do
		setSilo(st, i, "", palette)
	end

	-- boards
	local boards = folder(plot, "Boards")
	local titles = { Housing = "HOUSING", Shipping = "SHIPPING", Workers = "WORKERS", Silos = "SILOS", Upgrades = "UPGRADES", Eggs = "EGGS" }
	for _, b in Layout.Boards do
		local title = titles[b.menu] or b.menu
		if b.slot then
			title = "HOUSE " .. b.slot
		end
		Props.Board(boards, b.name, look(b.pos, b.look), title, b.menu, b.slot)
	end

	-- fox spots
	local fox = folder(plot, "FoxSpots")
	for i, p in Layout.FoxSpots do
		local part = marker(fox, "FoxSpot" .. i, L(p.x, p.z, 0.5))
		table.insert(st.foxSpots, part.Position)
	end

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = look(Layout.Spawn, { x = 0, y = 0, z = Layout.Spawn.z - 1 }) * CFrame.new(0, -0.3, 0)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.CanTouch = true
	spawn:SetAttribute("Role", "accent")
	spawn.Color = palette.accent
	spawn.Parent = plot
	st.spawn = spawn

	-- gate with nameplate, fences, decor
	local gate, front, back = Props.Gate(plot, look(Layout.Gate.pos, { x = 0, y = 0, z = Layout.Gate.pos.z + 1 }), Layout.Gate.width)
	local _ = gate
	st.gateFront, st.gateBack = front, back
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	for _, seg in Layout.Fence do
		Props.Fence(fence, L(seg.a.x, seg.a.z).Position, L(seg.b.x, seg.b.z).Position)
	end
	fence.Parent = plot
	buildDecor(st, plot)

	plot.WorldPivot = plotCF
	states[plot] = st
	plot.Parent = parent
	return plot
end

-- ------------------------------------------------------------------ public API
function World.Init()
	if initialized then
		return
	end
	initialized = true
	setupLighting()
	local commons = Workspace:FindFirstChild("Commons") or folder(Workspace, "Commons")
	buildCommons(commons :: Folder)
	local root = Workspace:FindFirstChild("Plots") or folder(Workspace, "Plots")
	for i = 1, World.PlotCount do
		plots[i] = buildPlot(i, root)
		World.ResetPlot(plots[i])
	end
end

function World.GetPlot(index: number): Model
	local p = plots[index]
	assert(p, "World.GetPlot: no plot " .. tostring(index))
	return p
end

export type Info = {
	egg: number,
	houses: { number },
	vehicles: { number }?,
	workers: { number }?,
	silos: number?,
	permanentSilos: number?,
	ownerName: string?,
}

local function apply(plot: Model, info: Info, withPuff: boolean)
	local st = states[plot]
	assert(st, "World.ApplyState: unknown plot")
	local themeKey = themeOf(info.egg)
	local palette = Kit.Palette(themeKey)
	Kit.SetPalette(palette)
	if themeKey ~= st.theme then
		st.theme = themeKey
		Kit.Recolor(plot, palette)
		local kind = Kit.Decor(themeKey)
		if kind ~= st.decor then
			st.decor = kind
			if st.decorModel then
				st.decorModel:Destroy()
			end
			buildDecor(st, plot)
		end
	end
	for slot = 1, #Layout.Houses do
		local tier = math.clamp(math.floor(tonumber(info.houses[slot]) or 0), 0, Houses.MaxTier)
		setHouse(st, slot, tier, palette, withPuff)
	end
	local built = math.clamp(math.max(tonumber(info.silos) or 0, tonumber(info.permanentSilos) or 0), 0, Layout.SiloCount)
	local perma = math.clamp(tonumber(info.permanentSilos) or 0, 0, Layout.SiloCount)
	for i = 1, Layout.SiloCount do
		setSilo(st, i, if i <= perma then "p" elseif i <= built then "b" else "", palette)
	end
	local vehicles = info.vehicles or {}
	for i = 1, #Layout.Bays do
		setBay(st, i, (tonumber(vehicles[i]) or 0) > 0, palette)
	end
	setOwner(st, info.ownerName)
end

function World.ApplyState(plot: Model, info: Info)
	apply(plot, info, true)
end

function World.ResetPlot(plot: Model)
	apply(plot, {
		egg = 1,
		houses = { 0, 0, 0, 0 },
		vehicles = { 0, 0, 0, 0, 0, 0, 0, 0 },
		workers = { 0, 0, 0, 0, 0, 0, 0, 0 },
		silos = 0,
		permanentSilos = 0,
		ownerName = nil,
	}, false)
end

function World.Zones(plot: Model)
	local st = states[plot]
	assert(st, "World.Zones: unknown plot")
	return {
		collect = table.clone(st.rings),
		deposit = st.deposit,
		foxSpots = table.clone(st.foxSpots),
		spawn = st.spawn,
	}
end

return World
