--!nonstrict
-- Points of interest (spec: "caves, cabins/houses, ranger structures, shelters,
-- campsites, ruins, supply areas, hidden locations"), built from primitives with
-- real collision. The mesh pack dresses them when a matching asset exists
-- (Skins); the procedural parts stay as colliders.
--
-- Contract (see docs/OVERHAUL.md):
--   * builder(cf, rng, parent) -> Model, PrimaryPart "Root" (invisible, no collide),
--     pivot = ground centre, entrance on local +Z (LayoutGen turns +Z toward the camp).
--   * Chest spots are Attachments named "ChestMount" on Root (WorldService spawns chests).
--   * Walkable interiors: door gaps >= 5 wide x 7 tall; clutter never collides.
-- Caves are the exception: the interior runs along local +Z (into the cliff) and
-- the terrain tunnel is carved by WorldService.

local Build = require("./Build")
local Skins = require("./Skins")

local Landmarks = {}

local WOOD = Color3.fromRGB(128, 92, 60)
local WOOD_DARK = Color3.fromRGB(88, 62, 40)
local WOOD_OLD = Color3.fromRGB(110, 100, 86)
local ROOF = Color3.fromRGB(86, 70, 58)
local STONE = Color3.fromRGB(122, 120, 116)
local CONCRETE = Color3.fromRGB(150, 148, 140)
local RUST = Color3.fromRGB(128, 84, 58)
local CANVAS = Color3.fromRGB(110, 120, 84)
local STEEL = Color3.fromRGB(96, 100, 108)

local M = Enum.Material

local function root(m: Model, w: number, h: number, d: number): BasePart
	local r = Build.Part({ Name = "Root", Size = Vector3.new(w, h, d), CFrame = CFrame.new(0, h / 2, 0), Transparency = 1, CanCollide = false, CanQuery = true, Parent = m })
	m.PrimaryPart = r
	return r
end

local function place(m: Model, cf: CFrame, parent: Instance?): Model
	Build.SetPivot(m, m.PrimaryPart :: BasePart, CFrame.new())
	m:PivotTo(cf)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if parent then
		m.Parent = parent
	end
	return m
end

local function solid(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material): BasePart
	return Build.Part({ Name = name, Size = size, CFrame = cf, Color = color, Material = mat, Parent = m })
end

local function decor(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material): BasePart
	return Build.Decor({ Name = name, Size = size, CFrame = cf, Color = color, Material = mat, Parent = m })
end

local function mount(m: Model, x: number, y: number, z: number, yaw: number?)
	local r = m.PrimaryPart :: BasePart
	local a = Instance.new("Attachment")
	a.Name = "ChestMount"
	-- Root's centre is at h/2; mounts are given from the ground centre
	a.CFrame = CFrame.new(x, y - r.Size.Y / 2, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	a.Parent = r
end

-- A walled room on a floor, door gap centred on the +Z wall (and optional window gaps).
local function room(m: Model, w: number, d: number, h: number, color: Color3, mat: Enum.Material, opts: { [string]: any }?)
	local o = opts or {}
	local t = o.Thick or 0.8
	local doorW, doorH = o.DoorW or 5.5, o.DoorH or 7.5
	local ox, oz = o.X or 0, o.Z or 0
	local floorY = o.FloorY or 0
	solid(m, "Floor", Vector3.new(w, 0.6, d), CFrame.new(ox, floorY + 0.3, oz), o.FloorColor or WOOD_DARK, M.WoodPlanks)
	-- back (-Z) and sides
	local function wall(name: string, size: Vector3, cf: CFrame)
		if o.Broken and o.Broken[name] then
			-- partially collapsed: keep a low course
			solid(m, name, Vector3.new(size.X, size.Y * 0.35, size.Z), cf * CFrame.new(0, -size.Y * 0.325, 0), Build.Tint(color, 0.9), mat)
		else
			solid(m, name, size, cf, color, mat)
		end
	end
	wall("WallBack", Vector3.new(w, h, t), CFrame.new(ox, floorY + h / 2, oz - d / 2 + t / 2))
	if o.Window then
		-- side walls with a window hole (collider in 4 pieces)
		for _, sx in { -1, 1 } do
			local x = ox + sx * (w / 2 - t / 2)
			wall("WallSide" .. sx, Vector3.new(t, h * 0.42, d), CFrame.new(x, floorY + h * 0.21, oz))
			wall("WallSideTop" .. sx, Vector3.new(t, h * 0.28, d), CFrame.new(x, floorY + h - h * 0.14, oz))
			wall("WallSideL" .. sx, Vector3.new(t, h * 0.3, d * 0.35), CFrame.new(x, floorY + h * 0.57, oz - d * 0.325))
			wall("WallSideR" .. sx, Vector3.new(t, h * 0.3, d * 0.35), CFrame.new(x, floorY + h * 0.57, oz + d * 0.325))
		end
	else
		for _, sx in { -1, 1 } do
			wall("WallSide" .. sx, Vector3.new(t, h, d), CFrame.new(ox + sx * (w / 2 - t / 2), floorY + h / 2, oz))
		end
	end
	-- front (+Z) with door gap
	local side = (w - doorW) / 2
	for _, sx in { -1, 1 } do
		wall("WallFront" .. sx, Vector3.new(side, h, t), CFrame.new(ox + sx * (doorW / 2 + side / 2), floorY + h / 2, oz + d / 2 - t / 2))
	end
	solid(m, "Lintel", Vector3.new(doorW, h - doorH, t), CFrame.new(ox, floorY + doorH + (h - doorH) / 2, oz + d / 2 - t / 2), Build.Tint(color, 0.85), mat)
end

-- Gable roof over a w x d room at height y.
local function roof(m: Model, w: number, d: number, y: number, color: Color3, mat: Enum.Material?, ox: number?, oz: number?, broken: boolean?)
	local x0, z0 = ox or 0, oz or 0
	local rise = w * 0.32
	for _, sx in { -1, 1 } do
		if broken and sx == 1 then
			-- caved-in half: a slanted slab lying inside
			decor(m, "RoofFallen", Vector3.new(w / 2, 0.4, d * 0.6), CFrame.new(x0 + w * 0.2, y * 0.45, z0 - d * 0.1) * CFrame.Angles(0, 0, math.rad(35)), Build.Tint(color, 0.8), mat or M.WoodPlanks)
		else
			local part = Build.Part({ Class = "WedgePart", Name = "Roof", Size = Vector3.new(d + 1, rise, w / 2 + 0.6), CFrame = CFrame.new(x0 + sx * (w / 4 + 0.15), y + rise / 2, z0) * CFrame.Angles(0, math.rad(90 * sx), 0), Color = color, Material = mat or M.WoodPlanks, Parent = m })
			part.CanCollide = true
		end
	end
end

local function crate(m: Model, cf: CFrame, s: number)
	decor(m, "Crate", Vector3.new(2, 2, 2) * s, cf, WOOD, M.WoodPlanks)
end

local function logSeat(m: Model, cf: CFrame)
	local p = Build.Cyl("LogSeat", 4, 1.1, cf * CFrame.Angles(0, 0, math.rad(90)), WOOD_DARK, M.Wood, m, false)
	p.CanQuery = false
end

local function firePit(m: Model, cf: CFrame, rng: Random)
	for i = 0, 7 do
		local a = i * math.pi / 4
		decor(m, "PitStone", Vector3.new(0.9, 0.6, 0.9), cf * CFrame.new(math.cos(a) * 1.6, 0.3, math.sin(a) * 1.6) * CFrame.Angles(0, a, 0), Build.Tint(STONE, rng:NextNumber(0.85, 1.05)), M.Slate)
	end
	decor(m, "Ash", Vector3.new(2.4, 0.15, 2.4), cf * CFrame.new(0, 0.08, 0), Color3.fromRGB(50, 46, 44), M.Slate)
end

local function tent(m: Model, cf: CFrame, color: Color3)
	for _, sx in { -1, 1 } do
		local part = Build.Part({ Class = "WedgePart", Name = "Tent", Size = Vector3.new(5, 3.4, 2.6), CFrame = cf * CFrame.new(sx * 1.3, 1.7, 0) * CFrame.Angles(0, math.rad(-90 * sx), 0), Color = color, Material = M.Fabric, Parent = m })
		part.CanCollide = true
	end
end

-- Lights and markers stay visible when a pack mesh replaces the procedural look.
local KEEP = { Lantern = true, Crystal = true, Lamp = true, Flag = true, Map = true }

-- Dress with a pack mesh if it exists (procedural parts stay as colliders).
local function dress(m: Model, name: string)
	if Skins.Has(name) then
		Skins.Dress(m, name, { keep = KEEP })
	end
end

-- Common ---------------------------------------------------------------------------------------

function Landmarks.Campsite(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Campsite")
	root(m, 22, 4, 22)
	firePit(m, CFrame.new(0, 0, 1), rng)
	tent(m, CFrame.new(-6, 0, -5) * CFrame.Angles(0, math.rad(20), 0), CANVAS)
	tent(m, CFrame.new(6, 0, -6) * CFrame.Angles(0, math.rad(-15), 0), Color3.fromRGB(150, 90, 60))
	logSeat(m, CFrame.new(0, 0.5, 5))
	logSeat(m, CFrame.new(-4.5, 0.5, 2) * CFrame.Angles(0, math.rad(70), 0))
	crate(m, CFrame.new(3, 1, -2), 0.8)
	decor(m, "Backpack", Vector3.new(1.2, 1.6, 0.8), CFrame.new(-3, 0.8, -1), Color3.fromRGB(90, 110, 70), M.Fabric)
	mount(m, 4, 0, -4, 180)
	return place(m, cf, parent)
end

function Landmarks.Shed(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Shed")
	root(m, 10, 7, 8)
	room(m, 8, 6, 6.5, WOOD_OLD, M.WoodPlanks, { DoorW = 5, DoorH = 6 })
	local lean = Build.Part({ Class = "WedgePart", Name = "Roof", Size = Vector3.new(9, 1.6, 7), CFrame = CFrame.new(0, 7.3, 0) * CFrame.Angles(0, math.rad(180), 0), Color = ROOF, Material = M.CorrodedMetal, Parent = m })
	lean.CanCollide = true
	crate(m, CFrame.new(-2.5, 0.9, -1.5), 0.7)
	decor(m, "Shovel", Vector3.new(0.2, 3.5, 0.6), CFrame.new(3.2, 2, -2) * CFrame.Angles(0, 0, math.rad(12)), WOOD, M.Wood)
	mount(m, 1.5, 0.6, -1.2, 180)
	return place(m, cf, parent)
end

function Landmarks.HuntingBlind(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("HuntingBlind")
	root(m, 9, 10, 9)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			Build.Cyl("Post", 6, 0.6, CFrame.new(x, 3, z), WOOD_DARK, M.Wood, m)
		end
	end
	solid(m, "Platform", Vector3.new(6.4, 0.5, 6.4), CFrame.new(0, 6, 0), WOOD, M.WoodPlanks)
	for _, s in { { 0, -3, 6.4, 0.3 }, { -3, 0, 0.3, 6.4 }, { 3, 0, 0.3, 6.4 } } do
		solid(m, "Screen", Vector3.new(s[3], 2.4, s[4]), CFrame.new(s[1], 7.4, s[2]), Color3.fromRGB(96, 110, 70), M.Fabric)
	end
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, 6, 2)
	ladder.CFrame = CFrame.new(0, 3, 3.6)
	ladder.Color = WOOD_DARK
	ladder.Material = M.Wood
	ladder.Anchored = true
	ladder.Style = Enum.Style.NoSupports
	ladder.Parent = m
	mount(m, 0, 6.25, -1.5, 180)
	return place(m, cf, parent)
end

function Landmarks.BrokenVehicle(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("BrokenVehicle")
	root(m, 16, 6, 12)
	local body = CFrame.new(0, 0, -2) * CFrame.Angles(0, math.rad(15), math.rad(6))
	solid(m, "Chassis", Vector3.new(12, 1.2, 5), body * CFrame.new(0, 1.4, 0), RUST, M.CorrodedMetal)
	solid(m, "Bed", Vector3.new(7, 2.4, 5), body * CFrame.new(-2.5, 3.2, 0), Build.Tint(RUST, 0.9), M.CorrodedMetal)
	solid(m, "Cab", Vector3.new(3.6, 3.2, 4.6), body * CFrame.new(3.6, 3.6, 0), Color3.fromRGB(70, 90, 80), M.CorrodedMetal)
	decor(m, "Windshield", Vector3.new(0.2, 1.6, 4), body * CFrame.new(5.4, 4.2, 0) * CFrame.Angles(0, 0, math.rad(-15)), Color3.fromRGB(150, 170, 170), M.Glass)
	for _, p in { { -4, -2.6 }, { 4, -2.6 }, { -4, 2.6 }, { 4, 2.6 } } do
		Build.Cyl("Tire", 1, 2.2, body * CFrame.new(p[1], 1.1, p[2]) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(30, 30, 30), M.Rubber, m, false)
	end
	decor(m, "Door", Vector3.new(2.6, 2.4, 0.2), CFrame.new(5, 0.25, 3) * CFrame.Angles(math.rad(85), math.rad(20), 0), Color3.fromRGB(70, 90, 80), M.CorrodedMetal)
	mount(m, -2, 0, 4.2, 0)
	return place(m, cf, parent)
end

function Landmarks.SmallCabin(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("SmallCabin")
	root(m, 13, 10, 11)
	room(m, 10, 8, 7.5, WOOD, M.Wood, { Window = true })
	roof(m, 10, 8, 7.5, ROOF, M.WoodPlanks)
	Build.Cyl("StovePipe", 3, 0.6, CFrame.new(3, 10, -2), Color3.fromRGB(60, 60, 64), M.Metal, m, false)
	solid(m, "Porch", Vector3.new(10, 0.4, 2.4), CFrame.new(0, 0.2, 5.2), WOOD_DARK, M.WoodPlanks)
	decor(m, "Bed", Vector3.new(3, 1, 6), CFrame.new(-3, 1, -0.5), Color3.fromRGB(110, 60, 50), M.Fabric)
	mount(m, 3, 0.6, -2.4, 180)
	return place(m, cf, parent)
end

-- Uncommon -------------------------------------------------------------------------------------

function Landmarks.Cabin(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Cabin")
	root(m, 18, 11, 14)
	room(m, 14, 10, 8, WOOD, M.Wood, { Window = true })
	roof(m, 14, 10, 8, ROOF, M.WoodPlanks)
	solid(m, "Porch", Vector3.new(14, 0.4, 3), CFrame.new(0, 0.2, 6.4), WOOD_DARK, M.WoodPlanks)
	for _, x in { -6.6, 6.6 } do
		Build.Cyl("PorchPost", 7, 0.5, CFrame.new(x, 3.5, 7.6), WOOD_DARK, M.Wood, m)
	end
	Build.Cyl("Chimney", 11, 1.8, CFrame.new(-5, 5.5, -4), STONE, M.Cobblestone, m)
	decor(m, "Table", Vector3.new(4, 0.3, 2.4), CFrame.new(2, 2.6, -1), WOOD_DARK, M.WoodPlanks)
	decor(m, "Bed", Vector3.new(3.2, 1, 6), CFrame.new(-4.2, 1, 0), Color3.fromRGB(90, 60, 50), M.Fabric)
	mount(m, 4.5, 0.6, -3.2, 180)
	mount(m, -4.5, 0.6, 3, 90)
	return place(m, cf, parent)
end

function Landmarks.RangerStation(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("RangerStation")
	root(m, 20, 16, 16)
	room(m, 14, 11, 8, Color3.fromRGB(96, 110, 84), M.WoodPlanks, { Window = true })
	roof(m, 14, 11, 8, Color3.fromRGB(70, 80, 64), M.CorrodedMetal)
	-- lookout on stilts behind
	for _, x in { -2.4, 2.4 } do
		for _, z in { -8, -12.8 } do
			Build.Cyl("Stilt", 12, 0.6, CFrame.new(x, 6, z), WOOD_DARK, M.Wood, m)
		end
	end
	solid(m, "Lookout", Vector3.new(6, 0.5, 6), CFrame.new(0, 12, -10.4), WOOD, M.WoodPlanks)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, 12, 2)
	ladder.CFrame = CFrame.new(3.8, 6, -10.4)
	ladder.Color = WOOD_DARK
	ladder.Material = M.Wood
	ladder.Anchored = true
	ladder.Style = Enum.Style.NoSupports
	ladder.Parent = m
	Build.Cyl("Flagpole", 12, 0.3, CFrame.new(8, 6, 6), Color3.fromRGB(200, 200, 200), M.Metal, m, false)
	decor(m, "Flag", Vector3.new(0.1, 1.6, 2.6), CFrame.new(8, 11, 7.4), Color3.fromRGB(70, 110, 70), M.Fabric)
	decor(m, "Desk", Vector3.new(4, 0.3, 2), CFrame.new(-3, 2.7, -3.5), WOOD_DARK, M.WoodPlanks)
	decor(m, "Map", Vector3.new(3, 2, 0.1), CFrame.new(-3, 5, -5.05), Color3.fromRGB(220, 210, 170), M.SmoothPlastic)
	mount(m, 4, 0.6, -3.5, 180)
	mount(m, 0, 12.25, -11.5, 180)
	return place(m, cf, parent)
end

function Landmarks.LoggingCamp(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("LoggingCamp")
	root(m, 24, 8, 24)
	room(m, 8, 7, 6.5, WOOD_OLD, M.WoodPlanks, { X = -6, Z = -5 })
	roof(m, 8, 7, 6.5, ROOF, M.CorrodedMetal, -6, -5)
	for row = 0, 2 do
		for i = 0, 3 - row do
			local p = Build.Cyl("Log", 9, 1.3, CFrame.new(6 + (i - (3 - row) / 2) * 1.35, 0.65 + row * 1.15, -4) * CFrame.Angles(0, math.rad(90), 0), Build.Tint(WOOD, rng:NextNumber(0.85, 1.05)), M.Wood, m)
			p.CanQuery = false
		end
	end
	decor(m, "Sawhorse", Vector3.new(3, 2.4, 0.4), CFrame.new(3, 1.2, 5), WOOD_DARK, M.Wood)
	decor(m, "Saw", Vector3.new(4, 0.1, 0.8), CFrame.new(3, 2.5, 5), Color3.fromRGB(190, 190, 196), M.Metal)
	mount(m, -6, 0.6, -6.5, 180)
	mount(m, 8, 0, 6, 0)
	return place(m, cf, parent)
end

function Landmarks.AbandonedHouse(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("AbandonedHouse")
	root(m, 22, 12, 18)
	room(m, 16, 12, 8.5, WOOD_OLD, M.WoodPlanks, { Window = true, Broken = { WallBack = rng:NextNumber() < 0.5, ["WallSide1"] = true } })
	roof(m, 16, 12, 8.5, Build.Tint(ROOF, 0.8), M.WoodPlanks, 0, 0, true)
	-- interior wall splitting two rooms (door gap)
	solid(m, "Partition", Vector3.new(0.6, 8.5, 5), CFrame.new(0, 4.25, -3.2), WOOD_OLD, M.WoodPlanks)
	decor(m, "BrokenChair", Vector3.new(1.4, 1.2, 1.4), CFrame.new(4, 0.9, 1) * CFrame.Angles(0, 0, math.rad(70)), WOOD_DARK, M.Wood)
	decor(m, "Rubble", Vector3.new(3, 0.8, 2.4), CFrame.new(6, 0.7, -4), STONE, M.Slate)
	mount(m, -5, 0.6, -4, 180)
	mount(m, 5, 0.6, -4.5, 180)
	return place(m, cf, parent)
end

function Landmarks.MineEntrance(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("MineEntrance")
	root(m, 18, 12, 14)
	-- rock mound with a timbered mouth facing +Z
	for i = 0, 5 do
		local a = math.rad(-150 + i * 60)
		local s = rng:NextNumber(5, 7)
		solid(m, "Mound", Vector3.new(s, s * 0.9, s), CFrame.new(math.cos(a) * 5, s * 0.4, -3 + math.sin(a) * 3) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), Build.Tint(STONE, rng:NextNumber(0.8, 1)), M.Slate)
	end
	for _, x in { -2.8, 2.8 } do
		solid(m, "Timber", Vector3.new(0.8, 7, 0.8), CFrame.new(x, 3.5, 2), WOOD_DARK, M.Wood)
	end
	solid(m, "Header", Vector3.new(6.8, 0.9, 0.9), CFrame.new(0, 7.2, 2), WOOD_DARK, M.Wood)
	decor(m, "Dark", Vector3.new(4.8, 6.4, 0.2), CFrame.new(0, 3.3, 1.2), Color3.fromRGB(12, 10, 10), M.SmoothPlastic)
	for _, x in { -0.9, 0.9 } do
		decor(m, "Rail", Vector3.new(0.2, 0.2, 10), CFrame.new(x, 0.1, 6.5), STEEL, M.Metal)
	end
	decor(m, "Cart", Vector3.new(2.4, 1.6, 3), CFrame.new(0, 1.2, 8), RUST, M.CorrodedMetal)
	mount(m, 4.5, 0, 5.5, 0)
	return place(m, cf, parent)
end

-- Rare -----------------------------------------------------------------------------------------

function Landmarks.Bunker(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Bunker")
	root(m, 18, 9, 16)
	room(m, 13, 11, 7, CONCRETE, M.Concrete, { Thick = 1.4, DoorW = 5, DoorH = 6.4, FloorColor = CONCRETE })
	solid(m, "Slab", Vector3.new(14.4, 1.4, 12.4), CFrame.new(0, 7.7, 0), Build.Tint(CONCRETE, 0.9), M.Concrete)
	decor(m, "Moss", Vector3.new(14.6, 0.2, 12.6), CFrame.new(0, 8.5, 0), Color3.fromRGB(80, 110, 60), M.Grass)
	for i = -2, 2 do
		decor(m, "Sandbag", Vector3.new(2, 0.8, 1), CFrame.new(i * 2.1, 0.4, 8.2), Color3.fromRGB(170, 150, 110), M.Fabric)
	end
	decor(m, "Lamp", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 6.4, 0), Color3.fromRGB(255, 220, 150), M.Neon)
	mount(m, -4, 0.6, -3.5, 180)
	mount(m, 4, 0.6, -3.5, 180)
	mount(m, 0, 0.6, -4.2, 180)
	return place(m, cf, parent)
end

function Landmarks.Outpost(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Outpost")
	root(m, 30, 14, 30)
	-- palisade ring, open toward +Z
	for i = 0, 17 do
		local a = math.rad(i * 20)
		local x, z = math.sin(a) * 13, -math.cos(a) * 13
		if z < 9 then
			local st = Build.Cyl("Stake", 7, 1.1, CFrame.new(x, 3.5, z), WOOD_DARK, M.Wood, m)
			st.CanQuery = true
		end
	end
	for _, x in { -4, 4 } do
		tent(m, CFrame.new(x, 0, -4) * CFrame.Angles(0, 0, 0), CANVAS)
	end
	for _, x in { -1.6, 1.6 } do
		for _, z in { -8.4, -11.6 } do
			Build.Cyl("TowerLeg", 9, 0.6, CFrame.new(x + 7, 4.5, z), WOOD_DARK, M.Wood, m)
		end
	end
	solid(m, "TowerDeck", Vector3.new(4.4, 0.4, 4.4), CFrame.new(7, 9, -10), WOOD, M.WoodPlanks)
	firePit(m, CFrame.new(0, 0, 2), rng)
	mount(m, -8, 0, -2, 90)
	mount(m, 8, 0, 2, -90)
	mount(m, 0, 0, -8, 180)
	return place(m, cf, parent)
end

function Landmarks.IndustrialSite(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("IndustrialSite")
	root(m, 34, 14, 30)
	-- steel shed frame (no walls on +Z)
	for _, x in { -9, 0, 9 } do
		for _, z in { -8, 4 } do
			solid(m, "Beam", Vector3.new(0.8, 10, 0.8), CFrame.new(x, 5, z), STEEL, M.Metal)
		end
	end
	solid(m, "ShedRoof", Vector3.new(20, 0.6, 14), CFrame.new(0, 10.3, -2), Build.Tint(STEEL, 0.8), M.CorrodedMetal)
	solid(m, "ShedBack", Vector3.new(19, 9, 0.6), CFrame.new(0, 4.5, -8.6), Build.Tint(STEEL, 0.9), M.CorrodedMetal)
	-- containers and tanks
	solid(m, "Container", Vector3.new(6, 6, 14), CFrame.new(-14, 3, 2), Color3.fromRGB(150, 70, 50), M.CorrodedMetal)
	solid(m, "Container", Vector3.new(6, 6, 14), CFrame.new(14, 3, 0) * CFrame.Angles(0, math.rad(8), 0), Color3.fromRGB(60, 90, 120), M.CorrodedMetal)
	Build.Cyl("Tank", 8, 5, CFrame.new(-6, 4, 11) * CFrame.Angles(0, 0, 0), RUST, M.CorrodedMetal, m)
	decor(m, "Barrels", Vector3.new(2, 2.6, 2), CFrame.new(5, 1.3, 9), Color3.fromRGB(70, 90, 70), M.Metal)
	mount(m, -4, 0, -5, 180)
	mount(m, 4, 0, -5, 180)
	mount(m, -14, 0, 11, 0)
	return place(m, cf, parent)
end

function Landmarks.LargeMine(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Landmarks.MineEntrance(CFrame.new(), rng, nil)
	m.Name = "LargeMine"
	local r = m.PrimaryPart :: BasePart
	r.Size = Vector3.new(22, 14, 20)
	r.CFrame = CFrame.new(0, 7, 0)
	-- headframe tower and an ore shed
	for _, x in { -8, -4 } do
		solid(m, "Headframe", Vector3.new(0.7, 12, 0.7), CFrame.new(x, 6, -6), WOOD_DARK, M.Wood)
	end
	solid(m, "Wheel", Vector3.new(0.4, 3, 3), CFrame.new(-6, 12, -6), STEEL, M.Metal)
	solid(m, "OreShed", Vector3.new(6, 5, 5), CFrame.new(8, 2.5, -2), WOOD_OLD, M.WoodPlanks)
	mount(m, -6, 0, 7, 0)
	return place(m, cf, parent)
end

-- Caves ----------------------------------------------------------------------------------------

-- Rock arch around the mouth (local -Z faces the forest, the tunnel runs along +Z).
-- `length` = tunnel depth; lanterns and chest mounts run along it.
function Landmarks.CaveEntrance(cf: CFrame, rng: Random, length: number, size: string, parent: Instance?): Model
	local m = Build.Model("Cave")
	root(m, 20, 12, length + 6)
	local rootPart = m.PrimaryPart :: BasePart
	rootPart.CFrame = CFrame.new(0, 6, length / 2)
	for i = 0, 6 do
		local a = math.rad(-10 + i * 33.3) -- arch from right to left
		local s = rng:NextNumber(4, 6)
		solid(m, "ArchRock", Vector3.new(s, s, s * 0.9), CFrame.new(math.cos(a) * 7, math.sin(a) * 7.5 + 1, rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Build.Tint(STONE, rng:NextNumber(0.7, 0.95)), M.Slate)
	end
	-- moss and hanging roots on the arch
	decor(m, "Moss", Vector3.new(10, 0.3, 3), CFrame.new(0, 8.8, 0), Color3.fromRGB(70, 110, 60), M.Grass)
	-- lanterns (and blue crystals deeper in medium/large caves)
	local lights = math.max(2, math.floor(length / 10))
	for i = 1, lights do
		local z = i * length / (lights + 0.5)
		local side = if i % 2 == 0 then 1 else -1
		local deep = z > length * 0.6 and size ~= "Small"
		local lamp = decor(m, if deep then "Crystal" else "Lantern", if deep then Vector3.new(0.8, 2.2, 0.8) else Vector3.new(0.7, 1, 0.7), CFrame.new(side * 3.6, if deep then 1.1 else 4.5, z) * CFrame.Angles(0, 0, if deep then math.rad(15 * side) else 0),
			if deep then Color3.fromRGB(110, 190, 255) else Color3.fromRGB(255, 200, 120), M.Neon)
		local pl = Instance.new("PointLight")
		pl.Range = if deep then 14 else 18
		pl.Brightness = if deep then 1.4 else 1.8
		pl.Color = lamp.Color
		pl.Shadows = false
		pl.Parent = lamp
	end
	-- chest mounts deep inside
	mount(m, 0, 0.2, length - 3, 180)
	mount(m, -3, 0.2, length * 0.6, 90)
	mount(m, 3, 0.2, length * 0.8, -90)
	mount(m, 0, 0.2, length * 0.45, 180)
	Build.SetPivot(m, rootPart, CFrame.new())
	m:PivotTo(cf)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if parent then
		m.Parent = parent
	end
	dress(m, "SM_CaveEntrance")
	return m
end

-- Chests ------------------------------------------------------------------------------------------

Landmarks.ChestTiers = {
	Common = { Body = WOOD, Trim = Color3.fromRGB(90, 90, 96), Glow = nil, Mesh = "SM_Chest_Common" },
	Uncommon = { Body = Color3.fromRGB(96, 120, 84), Trim = Color3.fromRGB(150, 150, 160), Glow = nil, Mesh = "SM_Chest_Uncommon" },
	Rare = { Body = Color3.fromRGB(70, 90, 140), Trim = Color3.fromRGB(210, 180, 90), Glow = Color3.fromRGB(120, 160, 255), Mesh = "SM_Chest_Rare" },
	VeryRare = { Body = Color3.fromRGB(110, 60, 140), Trim = Color3.fromRGB(240, 200, 90), Glow = Color3.fromRGB(220, 140, 255), Mesh = "SM_Chest_VeryRare" },
}

function Landmarks.Chest(cf: CFrame, tier: string, parent: Instance?): Model
	local spec = Landmarks.ChestTiers[tier] or Landmarks.ChestTiers.Common
	local m = Build.Model("Chest")
	local r = Build.Part({ Name = "Root", Size = Vector3.new(3.6, 2.6, 2.4), CFrame = CFrame.new(0, 1.3, 0), Transparency = 1, CanCollide = false, CanQuery = true, Parent = m })
	m.PrimaryPart = r
	Build.Part({ Name = "Body", Size = Vector3.new(3.4, 1.6, 2.2), CFrame = CFrame.new(0, 0.8, 0), Color = spec.Body, Material = M.WoodPlanks, Parent = m })
	local lid = Build.Part({ Name = "Lid", Size = Vector3.new(3.5, 0.7, 2.3), CFrame = CFrame.new(0, 1.95, 0), Color = Build.Tint(spec.Body, 0.85), Material = M.WoodPlanks, Parent = m })
	lid.CanCollide = false
	for _, x in { -1.2, 1.2 } do
		Build.Decor({ Name = "Trim", Size = Vector3.new(0.3, 2.4, 2.35), CFrame = CFrame.new(x, 1.2, 0), Color = spec.Trim, Material = M.Metal, Parent = m })
	end
	Build.Decor({ Name = "Lock", Size = Vector3.new(0.5, 0.6, 0.2), CFrame = CFrame.new(0, 1.5, -1.2), Color = spec.Trim, Material = M.Metal, Parent = m })
	if spec.Glow then
		local g = Instance.new("PointLight")
		g.Color = spec.Glow
		g.Range = 10
		g.Brightness = 0.9
		g.Parent = r
	end
	m:SetAttribute("Tier", tier)
	Build.SetPivot(m, r, CFrame.new())
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	if Skins.Has(spec.Mesh) then
		Skins.Dress(m, spec.Mesh, { keep = { Lid = true } })
	end
	return m
end

-- Opens a chest lid (server; replicates).
function Landmarks.OpenChest(m: Model)
	local lid = m:FindFirstChild("Lid") :: BasePart?
	local r = m.PrimaryPart
	if lid and r and not m:GetAttribute("Open") then
		lid.CFrame = r.CFrame * CFrame.new(0, 1.1, 1.3) * CFrame.Angles(math.rad(-70), 0, 0)
		m:SetAttribute("Open", true)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("PointLight") then
			d.Enabled = false
		end
	end
end

-- Dispatcher --------------------------------------------------------------------------------------

function Landmarks.Build(kind: string, cf: CFrame, rng: Random, parent: Instance?): Model?
	local f = (Landmarks :: any)[kind]
	if type(f) ~= "function" or kind == "Chest" or kind == "CaveEntrance" or kind == "Build" or kind == "OpenChest" then
		return nil
	end
	local m = f(cf, rng, parent)
	dress(m, "SM_POI_" .. kind)
	return m
end

return Landmarks
