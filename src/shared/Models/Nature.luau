--!nonstrict
-- Forest models built from primitives. Every model is built around the origin
-- with its pivot at ground level, then moved with PivotTo.

local Build = require("./Build")
local Skins = require("./Skins")

local Nature = {}

-- Mesh-pack look (see Skins.luau): pick a variant by position and size it to
-- roughly match the procedural silhouette it replaces.
local function skinHeight(m: Model, names: { string }, height: number, opts: Skins.Opts?)
	if not Skins.Enabled() then
		return
	end
	local name = Skins.Pick(names, m:GetPivot())
	local o = opts or {}
	o.scale = height / Skins.Height(name)
	Skins.Dress(m, name, o)
end

local function skinWidth(m: Model, names: { string }, width: number, opts: Skins.Opts?)
	if not Skins.Enabled() then
		return
	end
	local name = Skins.Pick(names, m:GetPivot())
	local o = opts or {}
	o.scale = width / Skins.Width(name)
	Skins.Dress(m, name, o)
end

local BARK = Color3.fromRGB(94, 66, 44)
local BARK_LIGHT = Color3.fromRGB(122, 90, 62)
local BIRCH = Color3.fromRGB(226, 222, 206)
local PINE = Color3.fromRGB(46, 96, 58)
local PINE_DARK = Color3.fromRGB(34, 74, 46)
local LEAF = Color3.fromRGB(78, 132, 62)
local LEAF_LIGHT = Color3.fromRGB(112, 160, 72)
local ROCK = Color3.fromRGB(118, 120, 124)
local ROCK_DARK = Color3.fromRGB(92, 94, 100)
local MOSS = Color3.fromRGB(84, 118, 64)

local function finish(m: Model, primary: BasePart, cf: CFrame, parent: Instance?): Model
	Build.SetPivot(m, primary, CFrame.new(primary.Position.X, 0, primary.Position.Z))
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	return m
end

-- Tall pine built from tiered discs so it reads as a conifer silhouette.
function Nature.Pine(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Build.Model("Pine")
	local s = scale
	local trunk = Build.Cyl("Trunk", 30 * s, 2.4 * s, CFrame.new(0, 15 * s, 0), BARK, Enum.Material.Wood, m)
	local tiers = 4
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1)
		local d = (15 - 10 * t) * s
		local y = (10 + 4.6 * (i - 1)) * s
		local disc = Build.Cyl("Needles", 3.4 * s, d, CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(i * 37), 0),
			if i % 2 == 0 then PINE else PINE_DARK, Enum.Material.Grass, m, false)
		disc.CastShadow = true

	end
	Build.Ball("Tip", 3 * s, CFrame.new(0, (10 + 4.6 * tiers) * s, 0), PINE, Enum.Material.Grass, m)
	finish(m, trunk, cf, parent)
	skinHeight(m, { "SM_Tree_Pine_Medium01", "SM_Tree_Pine_Medium02", "SM_Tree_Pine_Large01" }, 30 * s)
	return m
end

function Nature.Oak(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Build.Model("Oak")
	local s = scale
	local trunk = Build.Cyl("Trunk", 16 * s, 3.2 * s, CFrame.new(0, 8 * s, 0), BARK_LIGHT, Enum.Material.Wood, m)
	-- two limbs
	Build.Cyl("Limb", 8 * s, 1.4 * s, CFrame.new(2.2 * s, 15 * s, 0) * CFrame.Angles(0, 0, math.rad(-35)), BARK_LIGHT, Enum.Material.Wood, m, false)
	Build.Cyl("Limb", 7 * s, 1.2 * s, CFrame.new(-2 * s, 14 * s, 1 * s) * CFrame.Angles(math.rad(20), 0, math.rad(30)), BARK_LIGHT, Enum.Material.Wood, m, false)
	local blobs = {
		{ 0, 22, 0, 14 }, { 5, 19, 2, 10 }, { -5, 19, -2, 10 }, { 2, 18, -5, 9 }, { -2, 20, 5, 9 },
	}
	for i, b in blobs do
		Build.Ball("Canopy", b[4] * s, CFrame.new(b[1] * s, b[2] * s, b[3] * s), if i % 2 == 0 then LEAF else LEAF_LIGHT, Enum.Material.LeafyGrass, m)
	end
	finish(m, trunk, cf, parent)
	skinHeight(m, { "SM_Tree_Oak_Medium01", "SM_Tree_Oak_Medium02", "SM_Tree_Oak_Large01" }, 28 * s)
	return m
end

function Nature.Birch(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Build.Model("Birch")
	local s = scale
	local trunk = Build.Cyl("Trunk", 24 * s, 1.6 * s, CFrame.new(0, 12 * s, 0), BIRCH, Enum.Material.SmoothPlastic, m)
	-- bark marks
	for i = 1, 3 do
		Build.Decor({ Name = "Mark", Size = Vector3.new(0.3, 0.4 * s, 1.0 * s), CFrame = CFrame.new(0, (3 + i * 3.8) * s, 0) * CFrame.Angles(0, math.rad(i * 70), 0) * CFrame.new(0.72 * s, 0, 0), Color = Color3.fromRGB(50, 46, 42), Material = Enum.Material.SmoothPlastic, Parent = m, CastShadow = false })
	end
	for i, b in { { 0, 23, 0, 9 }, { 2.5, 20, 1, 7 }, { -2.5, 19, -1, 7 } } do
		Build.Ball("Canopy", b[4] * s, CFrame.new(b[1] * s, b[2] * s, b[3] * s), if i == 1 then Color3.fromRGB(150, 180, 80) else Color3.fromRGB(128, 168, 74), Enum.Material.LeafyGrass, m)
	end
	finish(m, trunk, cf, parent)
	skinHeight(m, { "SM_Tree_Birch_Medium01" }, 27 * s)
	return m
end

-- Choppable small tree (wood node). `Stage` attribute switches between full and stump.
function Nature.SmallTree(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("SmallTree")
	local trunk = Build.Cyl("Trunk", 10, 1.5, CFrame.new(0, 5, 0), BARK, Enum.Material.Wood, m)
	local stump = Build.Cyl("Stump", 1.4, 1.7, CFrame.new(0, 0.7, 0), BARK_LIGHT, Enum.Material.Wood, m)
	stump.Transparency = 1
	stump.CanCollide = false
	local c1 = Build.Ball("Leaves", 7, CFrame.new(0, 10.5, 0), LEAF, Enum.Material.LeafyGrass, m)
	local c2 = Build.Ball("Leaves", 5, CFrame.new(1.4, 8.6, 0.8), LEAF_LIGHT, Enum.Material.LeafyGrass, m)
	c1:SetAttribute("Canopy", true)
	c2:SetAttribute("Canopy", true)
	trunk:SetAttribute("Canopy", true)
	-- Notch marks that show chopping progress
	local notch = Build.Decor({ Name = "Notch", Size = Vector3.new(0.4, 0.8, 1.2), CFrame = CFrame.new(0.7, 2.5, 0), Color = Color3.fromRGB(214, 180, 130), Material = Enum.Material.Wood, Parent = m, CastShadow = false })
	notch.Transparency = 1
	return finish(m, trunk, cf, parent)
end

function Nature.SetSmallTreeStage(m: Model, stage: string)
	local full = stage == "Full"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("Canopy") then
				d.Transparency = if full then 0 else 1
				d.CanCollide = full and d.Name == "Trunk"
				d.CanQuery = full
			elseif d.Name == "Stump" then
				d.Transparency = if full then 1 else 0
				d.CanCollide = not full
			end
		end
	end
end

function Nature.Bush(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Build.Model("Bush")
	local s = scale
	local main = Build.Ball("Bush", 4.5 * s, CFrame.new(0, 1.6 * s, 0), LEAF, Enum.Material.LeafyGrass, m)
	Build.Ball("Bush", 3.4 * s, CFrame.new(1.8 * s, 1.2 * s, 0.6 * s), LEAF_LIGHT, Enum.Material.LeafyGrass, m)
	Build.Ball("Bush", 3 * s, CFrame.new(-1.6 * s, 1.1 * s, -0.8 * s), PINE, Enum.Material.LeafyGrass, m)
	for _, d in m:GetChildren() do
		(d :: BasePart).CastShadow = false
	end
	finish(m, main, cf, parent)
	skinWidth(m, { "SM_Bush01", "SM_Bush02", "SM_Bush03_Berry" }, 7 * s)
	return m
end

-- Plant fibre node: a fern cluster with pale fronds.
function Nature.Fern(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("Fern")
	local base = Build.Decor({ Name = "Base", Size = Vector3.new(2, 0.6, 2), CFrame = CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(70, 110, 50), Material = Enum.Material.Grass, Parent = m })
	base.CanQuery = true
	for i = 0, 6 do
		local a = math.rad(i * (360 / 7))
		Build.Decor({
			Name = "Frond",
			Class = "WedgePart",
			Size = Vector3.new(0.3, 3.2, 1.3),
			CFrame = CFrame.Angles(0, a, 0) * CFrame.new(0, 1.5, 1.2) * CFrame.Angles(math.rad(35), 0, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(120, 176, 84) else Color3.fromRGB(96, 150, 70),
			Material = Enum.Material.Grass,
			Parent = m,
			CastShadow = false,
		})
	end
	-- flower buds that disappear when picked
	for i = 0, 2 do
		local a = math.rad(i * 120 + 20)
		local b = Build.Ball("Bud", 0.6, CFrame.Angles(0, a, 0) * CFrame.new(0, 2.4, 0.9), Color3.fromRGB(236, 214, 120), Enum.Material.SmoothPlastic, m)
		b.CastShadow = false
	end
	return finish(m, base, cf, parent)
end

function Nature.TwigPile(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("TwigPile")
	local base = Build.Decor({ Name = "Base", Size = Vector3.new(3, 0.3, 3), CFrame = CFrame.new(0, 0.15, 0), Color = Color3.fromRGB(96, 76, 52), Material = Enum.Material.Ground, Parent = m })
	base.CanQuery = true
	for i = 0, 6 do
		local a = math.rad(i * 53)
		Build.Decor({
			Name = "Twig",
			Size = Vector3.new(3.2, 0.3, 0.3),
			CFrame = CFrame.new(0, 0.4 + (i % 3) * 0.22, 0) * CFrame.Angles(0, a, math.rad((i % 2) * 8)),
			Color = if i % 2 == 0 then BARK_LIGHT else BARK,
			Material = Enum.Material.Wood,
			Parent = m,
			CastShadow = false,
		})
	end
	return finish(m, base, cf, parent)
end

function Nature.RockPile(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("RockPile")
	local base = Build.Part({ Name = "Base", Size = Vector3.new(2.6, 1.4, 2.2), CFrame = CFrame.new(0, 0.6, 0) * CFrame.Angles(0.2, 0.5, 0.1), Color = ROCK, Material = Enum.Material.Slate, Parent = m })
	Build.Part({ Name = "Chunk", Size = Vector3.new(1.4, 1, 1.4), CFrame = CFrame.new(1.4, 0.5, 0.6) * CFrame.Angles(0.3, 1.1, 0.2), Color = ROCK_DARK, Material = Enum.Material.Slate, Parent = m, CanCollide = false })
	Build.Part({ Name = "Chunk", Size = Vector3.new(1.1, 0.8, 1.2), CFrame = CFrame.new(-1.2, 0.4, -0.7) * CFrame.Angles(0.1, 0.4, 0.4), Color = ROCK, Material = Enum.Material.Slate, Parent = m, CanCollide = false })
	return finish(m, base, cf, parent)
end

function Nature.BigRock(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Build.Model("BigRock")
	local s = scale
	local main = Build.Part({ Name = "Rock", Size = Vector3.new(8, 5.5, 7) * s, CFrame = CFrame.new(0, 2.2 * s, 0) * CFrame.Angles(0.15, 0.3, 0.08), Color = ROCK, Material = Enum.Material.Rock, Parent = m })
	Build.Part({ Name = "Rock", Size = Vector3.new(5, 4, 5) * s, CFrame = CFrame.new(3 * s, 1.6 * s, 2 * s) * CFrame.Angles(0.3, 0.9, 0.2), Color = ROCK_DARK, Material = Enum.Material.Rock, Parent = m })
	Build.Part({ Class = "WedgePart", Name = "Rock", Size = Vector3.new(4, 3, 5) * s, CFrame = CFrame.new(-3.5 * s, 1.2 * s, -1 * s) * CFrame.Angles(0, math.rad(80), 0), Color = ROCK, Material = Enum.Material.Rock, Parent = m })
	Build.Decor({ Name = "Moss", Size = Vector3.new(6, 0.5, 5) * s, CFrame = CFrame.new(0, 5 * s, 0) * CFrame.Angles(0.15, 0.3, 0.08), Color = MOSS, Material = Enum.Material.Grass, Parent = m, CastShadow = false })
	finish(m, main, cf, parent)
	skinWidth(m, { "SM_Boulder01", "SM_Boulder02", "SM_Boulder03" }, 10 * s)
	return m
end

function Nature.StandingStone(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("StandingStone")
	local main = Build.Part({ Name = "Stone", Size = Vector3.new(3.5, 12, 2.2), CFrame = CFrame.new(0, 5.5, 0) * CFrame.Angles(0.05, 0, 0.04), Color = Color3.fromRGB(128, 126, 120), Material = Enum.Material.Slate, Parent = m })
	Build.Decor({ Name = "Rune", Size = Vector3.new(1.4, 1.4, 0.15), CFrame = CFrame.new(0, 7, -1.12) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(120, 200, 190), Material = Enum.Material.Neon, Parent = m, CastShadow = false })
	Build.Decor({ Name = "Moss", Size = Vector3.new(3.7, 0.4, 2.4), CFrame = CFrame.new(0, 11.4, 0), Color = MOSS, Material = Enum.Material.Grass, Parent = m })
	return finish(m, main, cf, parent)
end

function Nature.FallenGiant(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("FallenGiant")
	local log = Build.Cyl("Log", 24, 4.5, CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(90), 0, 0), BARK, Enum.Material.Wood, m)
	Build.Cyl("Ring", 0.4, 4.2, CFrame.new(0, 2, 12.1) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(200, 164, 118), Enum.Material.Wood, m, false)
	Build.Cyl("Stump", 5, 5.5, CFrame.new(0, 2.5, -15), BARK, Enum.Material.Wood, m)
	for i = 1, 4 do
		Build.Decor({ Name = "Moss", Size = Vector3.new(3, 0.6, 3), CFrame = CFrame.new(0, 4.2, -9 + i * 4.5), Color = MOSS, Material = Enum.Material.Grass, Parent = m })
	end
	for i = 1, 3 do
		Build.Ball("Mushroom", 1.2, CFrame.new(2.3, 1 + i * 0.6, -6 + i * 5), Color3.fromRGB(220, 90, 70), Enum.Material.SmoothPlastic, m)
	end
	finish(m, log, cf, parent)
	-- the pack's giant log runs along X; this one runs along Z
	if Skins.Enabled() then
		Skins.Dress(m, "SM_Landmark_GiantLog", { scale = 1.1, offset = CFrame.Angles(0, math.rad(90), 0) })
	end
	return m
end

function Nature.Ruins(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("Ruins")
	local STONE = Color3.fromRGB(150, 146, 136)
	local floor = Build.Part({ Name = "Floor", Size = Vector3.new(22, 0.8, 16), CFrame = CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(120, 116, 108), Material = Enum.Material.Cobblestone, Parent = m })
	-- two broken wall stubs + columns
	Build.Part({ Name = "Wall", Size = Vector3.new(1.6, 7, 9), CFrame = CFrame.new(7, 3.5, -2), Color = STONE, Material = Enum.Material.Brick, Parent = m })
	Build.Part({ Class = "WedgePart", Name = "Wall", Size = Vector3.new(1.6, 4, 5), CFrame = CFrame.new(7, 9, -4.5), Color = STONE, Material = Enum.Material.Brick, Parent = m })
	Build.Part({ Name = "Wall", Size = Vector3.new(1.6, 5, 7), CFrame = CFrame.new(-7, 2.5, 3), Color = STONE, Material = Enum.Material.Brick, Parent = m })
	for i, x in { -9, -3, 3, 9 } do
		local h = if i % 2 == 0 then 10 else 6
		Build.Cyl("Column", h, 2, CFrame.new(x, h / 2, 7), STONE, Enum.Material.Marble, m)
	end
	Build.Part({ Name = "Lintel", Size = Vector3.new(8, 1.2, 2.2), CFrame = CFrame.new(-3, 10.6, 7) * CFrame.Angles(0, 0, math.rad(-6)), Color = STONE, Material = Enum.Material.Marble, Parent = m })
	for i = 1, 5 do
		Build.Part({ Name = "Rubble", Size = Vector3.new(1.5, 1, 1.2), CFrame = CFrame.new(-4 + i * 2, 0.9, -5 + (i % 2) * 2) * CFrame.Angles(0.3 * i, i, 0.2), Color = STONE, Material = Enum.Material.Slate, Parent = m, CanCollide = false })
	end
	return finish(m, floor, cf, parent)
end

-- Tall grass clumps for thickets (non-colliding; slows movement via server zone).
function Nature.GrassClump(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("Grass")
	local base = Build.Decor({ Name = "Base", Size = Vector3.new(1, 0.2, 1), CFrame = CFrame.new(0, 0.1, 0), Color = LEAF, Material = Enum.Material.Grass, Parent = m, CastShadow = false })
	for i = 0, 4 do
		Build.Decor({ Name = "Blade", Class = "WedgePart", Size = Vector3.new(0.2, 4.5, 1), CFrame = CFrame.Angles(0, math.rad(i * 72), 0) * CFrame.new(0, 2.2, 0.4) * CFrame.Angles(math.rad(10), 0, 0), Color = if i % 2 == 0 then Color3.fromRGB(130, 170, 80) else Color3.fromRGB(104, 146, 66), Material = Enum.Material.Grass, Parent = m, CastShadow = false })
	end
	finish(m, base, cf, parent)
	skinHeight(m, { "SM_Grass_Clump03", "SM_Grass_Clump01", "SM_Fern01" }, 4)
	return m
end

function Nature.Flower(cf: CFrame, color: Color3, parent: Instance?): Model
	local m = Build.Model("Flower")
	local stem = Build.Decor({ Name = "Stem", Size = Vector3.new(0.2, 1.4, 0.2), CFrame = CFrame.new(0, 0.7, 0), Color = LEAF, Material = Enum.Material.Grass, Parent = m, CastShadow = false })
	local head = Build.Ball("Head", 0.8, CFrame.new(0, 1.5, 0), color, Enum.Material.SmoothPlastic, m)
	head.CastShadow = false
	return finish(m, stem, cf, parent)
end

return Nature
