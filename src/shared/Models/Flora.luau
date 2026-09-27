--!nonstrict
-- Flora: procedural vegetation and rock models for SURVIVAL WARS, built only
-- from Roblox primitives (no asset ids, no MeshParts).
--
-- Contract (see docs/OVERHAUL.md):
--  * Every builder is `(cf, rng, [extra args], parent?) -> Model`.
--  * Models are built around the origin with the pivot at ground centre (y = 0),
--    finished with Build.SetPivot(m, primary, CFrame.new()) then m:PivotTo(cf).
--  * All variation (variant, scale jitter, colour jitter) comes from `rng`.
--  * Resource models expose the part roles Root / Top / Stump / Notch / Yield.
--  * Only trunks, stumps, logs and rocks collide; everything else is Decor.
--  * Parts smaller than 1.5 studs never cast shadows.

local Build = require("./Build")
local Skins = require("./Skins")

local Flora = {}

local M = Enum.Material
local TAU = math.pi * 2

--------------------------------------------------------------------------------
-- Palettes
--------------------------------------------------------------------------------

local BARK = Color3.fromRGB(92, 66, 46)
local BARK_DARK = Color3.fromRGB(70, 50, 36)
local BARK_PINE = Color3.fromRGB(108, 70, 48)
local BARK_OAK = Color3.fromRGB(104, 84, 64)
local BARK_GREY = Color3.fromRGB(124, 120, 112)
local BIRCH_BARK = Color3.fromRGB(226, 222, 208)
local ASPEN_BARK = Color3.fromRGB(204, 208, 190)
local BARK_MARK = Color3.fromRGB(46, 42, 38)
local CUT_WOOD = Color3.fromRGB(214, 180, 130)

local NEEDLE = { Color3.fromRGB(30, 66, 42), Color3.fromRGB(40, 84, 50), Color3.fromRGB(54, 102, 58) }
local SPRUCE = { Color3.fromRGB(26, 58, 44), Color3.fromRGB(34, 70, 52), Color3.fromRGB(44, 82, 60) }
local SPRUCE_BLUE = { Color3.fromRGB(56, 88, 86), Color3.fromRGB(70, 104, 102), Color3.fromRGB(84, 116, 112) }
local LEAF = { Color3.fromRGB(56, 104, 46), Color3.fromRGB(78, 132, 56), Color3.fromRGB(106, 154, 64) }
local LEAF_DEEP = { Color3.fromRGB(44, 86, 42), Color3.fromRGB(60, 108, 48), Color3.fromRGB(82, 128, 54) }
local BIRCH_LEAF = { Color3.fromRGB(112, 156, 62), Color3.fromRGB(138, 176, 74), Color3.fromRGB(162, 190, 86) }
local ASPEN_LEAF = { Color3.fromRGB(128, 168, 66), Color3.fromRGB(156, 182, 72), Color3.fromRGB(178, 190, 80) }
local ASPEN_GOLD = { Color3.fromRGB(214, 186, 70), Color3.fromRGB(226, 168, 58), Color3.fromRGB(196, 194, 84) }
local BUSH = { Color3.fromRGB(50, 96, 46), Color3.fromRGB(70, 120, 52), Color3.fromRGB(94, 140, 60) }
local GRASS = { Color3.fromRGB(84, 138, 58), Color3.fromRGB(106, 158, 66), Color3.fromRGB(128, 168, 74) }
local GRASS_DRY = { Color3.fromRGB(150, 156, 82), Color3.fromRGB(172, 162, 92), Color3.fromRGB(128, 146, 72) }
local FERN = { Color3.fromRGB(88, 146, 62), Color3.fromRGB(106, 162, 70), Color3.fromRGB(72, 128, 54) }
local MOSS = { Color3.fromRGB(74, 112, 54), Color3.fromRGB(92, 128, 60), Color3.fromRGB(62, 98, 50) }
local LITTER = { Color3.fromRGB(150, 92, 44), Color3.fromRGB(176, 124, 52), Color3.fromRGB(124, 76, 42), Color3.fromRGB(162, 146, 70) }
local ROCK = { Color3.fromRGB(112, 114, 118), Color3.fromRGB(126, 124, 120), Color3.fromRGB(96, 98, 104) }
local ROCK_WARM = { Color3.fromRGB(122, 114, 104), Color3.fromRGB(106, 100, 94), Color3.fromRGB(136, 130, 120) }
local DIRT = Color3.fromRGB(92, 72, 52)
local FLOWER = {
	Color3.fromRGB(236, 90, 110),
	Color3.fromRGB(246, 214, 90),
	Color3.fromRGB(172, 120, 232),
	Color3.fromRGB(244, 244, 240),
	Color3.fromRGB(120, 170, 245),
	Color3.fromRGB(246, 150, 70),
}
local BERRY = { Color3.fromRGB(200, 34, 48), Color3.fromRGB(110, 40, 124), Color3.fromRGB(56, 72, 170) }
local CAP_RED = Color3.fromRGB(196, 44, 38)
local CAP_BROWN = Color3.fromRGB(146, 100, 62)
local CAP_TAN = Color3.fromRGB(196, 164, 116)
local STEM = Color3.fromRGB(234, 226, 206)
local WATER = Color3.fromRGB(150, 204, 236)

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function pick(rng: Random, list)
	return list[rng:NextInteger(1, #list)]
end

-- Colour with +-amt brightness jitter.
local function vary(rng: Random, c: Color3, amt: number?): Color3
	local a = amt or 0.08
	return Build.Tint(c, 1 + rng:NextNumber(-a, a))
end

-- Random palette entry with brightness jitter.
local function shade(rng: Random, list, amt: number?): Color3
	return vary(rng, pick(rng, list), amt)
end

local function spin(rng: Random): CFrame
	return CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
end

-- Rotation-only frame (for cylinders) whose Y axis runs from `a` to `b`.
local function segment(a: Vector3, b: Vector3): (CFrame, number)
	local dir = b - a
	local len = dir.Magnitude
	local mid = (a + b) / 2
	local up = if math.abs(dir.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(mid, b, up) * CFrame.Angles(-math.pi / 2, 0, 0), len
end

-- Cylinder from point a to point b.
local function limb(name: string, a: Vector3, b: Vector3, d: number, color: Color3, mat: Enum.Material, parent: Instance, collide: boolean?): BasePart
	local cf, len = segment(a, b)
	return Build.Cyl(name, len, d, cf, color, mat, parent, collide == true)
end

-- Decorative block/wedge.
local function block(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance, class: string?): BasePart
	return Build.Decor({ Name = name, Class = class, Size = size, CFrame = cf, Color = color, Material = mat, Parent = parent })
end

-- Colliding block/wedge (rocks, logs).
local function solid(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance, class: string?): BasePart
	return Build.Part({ Name = name, Class = class, Size = size, CFrame = cf, Color = color, Material = mat, Parent = parent })
end

local function markYield(p: BasePart): BasePart
	p:SetAttribute("Yield", true)
	return p
end

-- Invisible, queryable, non-colliding footprint part (resource PrimaryPart).
local function makeRoot(m: Model, w: number, h: number, depth: number?): BasePart
	return Build.Part({
		Name = "Root",
		Size = Vector3.new(w, h, depth or w),
		CFrame = CFrame.new(0, h / 2, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = true,
		CanTouch = false,
		CastShadow = false,
		Parent = m,
	})
end

-- Shadow pass, pivot at ground centre, move and parent.
local function finish(m: Model, primary: BasePart, cf: CFrame, parent: Instance?, noShadow: boolean?): Model
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local s = d.Size
			if noShadow or math.max(s.X, s.Y, s.Z) < 1.5 then
				d.CastShadow = false
			end
		end
	end
	Build.SetPivot(m, primary, CFrame.new())
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	return m
end

-- Stack of needle tiers (cylinders of decreasing diameter) along `axis`
-- (a rotation-only CFrame). `drift` pushes upper tiers sideways (wind).
local function tierStack(parent: Instance, rng: Random, axis: CFrame, y0: number, y1: number, n: number, d0: number, d1: number, thick: number, palette, drift: Vector3?, jitter: number)
	for i = 1, n do
		local t = if n <= 1 then 0 else (i - 1) / (n - 1)
		local y = y0 + (y1 - y0) * t
		local d = (d0 + (d1 - d0) * t) * rng:NextNumber(0.9, 1.08)
		local pos = axis * Vector3.new(0, y, 0)
		if drift then
			pos += drift * t
		end
		pos += Vector3.new(rng:NextNumber(-jitter, jitter), 0, rng:NextNumber(-jitter, jitter))
		local tilt = CFrame.Angles(rng:NextNumber(-0.07, 0.07), rng:NextNumber(0, TAU), rng:NextNumber(-0.07, 0.07))
		Build.Cyl("Needles", thick * rng:NextNumber(0.88, 1.1), d, CFrame.new(pos) * tilt, shade(rng, palette, 0.06), M.Grass, parent, false)
	end
end

-- Lush broadleaf crown: one core ball plus `n - 1` overlapping blobs around it.
local function crown(parent: Instance, rng: Random, center: Vector3, r: number, n: number, palette, squash: number?)
	local sq = squash or 0.45
	Build.Ball("Canopy", r * 2 * rng:NextNumber(0.9, 1.05), CFrame.new(center + Vector3.new(0, r * 0.1, 0)), shade(rng, palette, 0.05), M.LeafyGrass, parent)
	local a0 = rng:NextNumber(0, TAU)
	for i = 2, n do
		local a = a0 + (i - 2) * TAU / math.max(1, n - 1) + rng:NextNumber(-0.4, 0.4)
		local dist = r * rng:NextNumber(0.55, 0.85)
		local off = Vector3.new(math.cos(a) * dist, r * rng:NextNumber(-sq, sq * 0.6), math.sin(a) * dist)
		Build.Ball("Canopy", r * rng:NextNumber(1.0, 1.4), CFrame.new(center + off), shade(rng, palette, 0.06), M.LeafyGrass, parent)
	end
end

-- Dark bark marks on a birch/aspen trunk (thin decor slivers).
local function barkMarks(parent: Instance, rng: Random, base: CFrame, radius: number, y0: number, y1: number, n: number)
	for i = 1, n do
		local y = y0 + (y1 - y0) * (i - 0.5) / n + rng:NextNumber(-0.5, 0.5)
		block("Mark", Vector3.new(0.2, rng:NextNumber(0.25, 0.45), radius * rng:NextNumber(0.7, 1.1)),
			base * CFrame.new(0, y, 0) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.new(radius * 0.94, 0, 0),
			BARK_MARK, M.SmoothPlastic, parent)
	end
end

-- Chop notches just above the hinge (hidden until the tree is Damaged).
local function addNotches(m: Model, rng: Random, hingeY: number, d: number)
	local a = rng:NextNumber(0, TAU)
	for i = 0, 1 do
		local n = block("Notch", Vector3.new(0.4, 0.75, d * 0.6),
			CFrame.new(0, hingeY + 0.4 + i * 0.2, 0) * CFrame.Angles(0, a + i * (math.pi * 0.85), 0) * CFrame.new(d * 0.4, 0, 0),
			CUT_WOOD, M.Wood, m)
		n.Transparency = 1
	end
end

local function newScale(rng: Random, scale: number?): number
	return (scale or 1) * rng:NextNumber(0.88, 1.12)
end


--------------------------------------------------------------------------------
-- Mesh-pack skins for resource nodes (see Skins.luau). The procedural parts stay
-- as invisible colliders/yield markers; meshes follow the same state rules:
--   * trees: mesh inside Top (falls with it), stump mesh tagged SkinStump
--   * harvest nodes: full mesh tagged Yield, depleted mesh always visible
--------------------------------------------------------------------------------

local TREE_SKINS = {
	Pine = { Small = "SM_Tree_Pine_Small01", Medium = "SM_Tree_Pine_Medium01", Large = "SM_Tree_Pine_Large01" },
	Oak = { Small = "SM_Tree_Oak_Small01", Medium = "SM_Tree_Oak_Medium01", Large = "SM_Tree_Oak_Large01" },
	Birch = { Small = "SM_Tree_Birch_Small01", Medium = "SM_Tree_Birch_Medium01", Large = "SM_Tree_Birch_Medium01" },
}
local STUMP_SKINS = { Pine = "SM_Tree_Pine_Small01_Stump", Oak = "SM_Tree_Oak_Small01_Stump", Birch = "SM_Tree_Birch_Small01_Stump", Dead = "SM_Stump_Old02" }

local function skinTree(m: Model, top: Model, treeName: string, stumpName: string, height: number)
	if not Skins.Enabled() then
		return
	end
	local k = height / Skins.Height(treeName)
	Skins.Hide(m)
	Skins.Dress(m, treeName, { scale = k, parent = top, noHide = true })
	-- stump mesh: hidden while the tree stands, shown once it is felled
	Skins.Dress(m, stumpName, { scale = math.max(0.8, k), noHide = true, transparency = 1, attrs = { SkinStump = true } })
end

local function skinHarvest(m: Model, full: string, depleted: string?, scale: number, keep: { [string]: boolean }?)
	if not Skins.Enabled() then
		return
	end
	Skins.Hide(m, keep)
	Skins.Dress(m, full, { scale = scale, noHide = true, attrs = { Yield = true } })
	if depleted then
		Skins.Dress(m, depleted, { scale = scale, noHide = true })
	end
end

--------------------------------------------------------------------------------
-- Resource models
--------------------------------------------------------------------------------

local TREE_SIZES = {
	Small = { h0 = 10, h1 = 14, d = 1.4, g0 = 0.9, g1 = 1.1 },
	Medium = { h0 = 18, h1 = 24, d = 2.2, g0 = 1.1, g1 = 1.3 },
	Large = { h0 = 28, h1 = 36, d = 3.2, g0 = 1.3, g1 = 1.5 },
}

--- Choppable tree. `size` "Small"|"Medium"|"Large", `species` "Pine"|"Oak"|"Birch".
--- Roles: Root (PrimaryPart), Stump, 2x Notch, Top (Model, pivot at hinge) with
--- a colliding Trunk plus decor canopy. Attributes: HingeY, TreeSize, Species.
--- Parts: Pine <= 12, Oak <= 13, Birch <= 12.
function Flora.ResourceTree(cf: CFrame, rng: Random, size: string, species: string, parent: Instance?): Model
	local spec = TREE_SIZES[size] or TREE_SIZES.Medium
	local sp = if species == "Oak" or species == "Birch" then species else "Pine"
	local tier = if size == "Small" then 1 elseif size == "Large" then 3 else 2
	local H = rng:NextNumber(spec.h0, spec.h1)
	local d = spec.d * rng:NextNumber(0.94, 1.06)
	local hingeY = rng:NextNumber(spec.g0, spec.g1)

	local m = Build.Model(sp .. "Tree")
	m:SetAttribute("HingeY", hingeY)
	m:SetAttribute("TreeSize", size)
	m:SetAttribute("Species", sp)

	local root = makeRoot(m, d + 1, hingeY + 3) -- 1
	local barkBase = if sp == "Birch" then BIRCH_BARK elseif sp == "Oak" then BARK_OAK else BARK_PINE
	local bark = vary(rng, barkBase, 0.06)
	Build.Cyl("Stump", hingeY, d * 1.1, CFrame.new(0, hingeY / 2, 0), Build.Tint(bark, 0.9), M.Wood, m, true) -- 2
	addNotches(m, rng, hingeY, d) -- 4

	local top = Build.Model("Top", m)
	local trunk: BasePart

	if sp == "Pine" then
		local trunkTop = H * 0.9
		trunk = Build.Cyl("Trunk", trunkTop - hingeY, d * 0.94, CFrame.new(0, (trunkTop + hingeY) / 2, 0), bark, M.Wood, top, true) -- 5
		local n = 3 + tier -- 4 / 5 / 6 tiers
		local baseD = H * rng:NextNumber(0.38, 0.46)
		local y0 = math.max(H * 0.28, hingeY + 2.5)
		local y1 = H * 0.82
		local thick = (y1 - y0) / (n - 1) * 1.45
		tierStack(top, rng, CFrame.new(), y0, y1, n, baseD, baseD * 0.3, thick, NEEDLE, nil, d * 0.12) -- <= 11
		Build.Cyl("Tip", H - y1, math.max(0.8, baseD * 0.14), CFrame.new(0, (y1 + H) / 2, 0), shade(rng, NEEDLE, 0.05), M.Grass, top, false) -- <= 12
	elseif sp == "Oak" then
		local trunkTop = H * 0.58
		trunk = Build.Cyl("Trunk", trunkTop - hingeY, d, CFrame.new(0, (trunkTop + hingeY) / 2, 0), bark, M.Wood, top, true) -- 5
		local r = H * 0.26
		local cy = H - r * 1.1
		local a = rng:NextNumber(0, TAU)
		for i = 0, 1 do -- 7
			local aa = a + i * math.pi + rng:NextNumber(-0.5, 0.5)
			local from = Vector3.new(0, trunkTop * rng:NextNumber(0.7, 0.9), 0)
			local to = Vector3.new(math.cos(aa) * r * 0.8, cy - r * 0.2, math.sin(aa) * r * 0.8)
			limb("Branch", from, to, d * 0.45, bark, M.Wood, top, false)
		end
		local nBalls = if tier == 1 then 3 elseif tier == 2 then 5 else 6
		crown(top, rng, Vector3.new(0, cy, 0), r, nBalls, LEAF) -- <= 13
	else -- Birch
		local trunkTop = H * 0.9
		local td = d * 0.8
		trunk = Build.Cyl("Trunk", trunkTop - hingeY, td, CFrame.new(0, (trunkTop + hingeY) / 2, 0), bark, M.Wood, top, true) -- 5
		barkMarks(top, rng, CFrame.new(), td / 2, hingeY + 1, H * 0.5, 2) -- 7
		local a = rng:NextNumber(0, TAU)
		limb("Branch", Vector3.new(0, H * 0.55, 0), Vector3.new(math.cos(a) * H * 0.14, H * 0.7, math.sin(a) * H * 0.14), td * 0.4, bark, M.Wood, top, false) -- 8
		local n = if tier == 1 then 3 else 4
		local r = H * 0.13
		for i = 1, n do -- <= 12
			local t = (i - 1) / (n - 1)
			local y = H * 0.56 + (H - r * 1.4 - H * 0.56) * t
			local w = r * (1.25 - 0.35 * t) * rng:NextNumber(0.9, 1.1)
			local off = Vector3.new(rng:NextNumber(-r, r) * 0.45, 0, rng:NextNumber(-r, r) * 0.45)
			Build.Ball("Canopy", w * 2, CFrame.new(Vector3.new(0, y, 0) + off), shade(rng, BIRCH_LEAF, 0.05), M.LeafyGrass, top)
		end
	end

	Build.SetPivot(top, trunk, CFrame.new(0, hingeY, 0))
	finish(m, root, cf, parent)
	skinTree(m, top, TREE_SKINS[sp][size] or TREE_SKINS[sp].Medium, STUMP_SKINS[sp], H)
	return m
end

--- Dead tree (dry wood resource): grey leafless snag with Root/Stump/Notch/Top roles.
--- Parts: 9-10.
function Flora.DeadTree(cf: CFrame, rng: Random, parent: Instance?): Model
	local H = rng:NextNumber(14, 22)
	local d = rng:NextNumber(1.7, 2.2)
	local hingeY = rng:NextNumber(1.0, 1.3)
	local m = Build.Model("DeadTree")
	m:SetAttribute("HingeY", hingeY)
	m:SetAttribute("Species", "Dead")

	local root = makeRoot(m, d + 1, hingeY + 3) -- 1
	local bark = vary(rng, BARK_GREY, 0.08)
	Build.Cyl("Stump", hingeY, d * 1.1, CFrame.new(0, hingeY / 2, 0), Build.Tint(bark, 0.88), M.Wood, m, true) -- 2
	addNotches(m, rng, hingeY, d) -- 4

	local top = Build.Model("Top", m)
	local lean = rng:NextNumber(0, 0.08)
	local axis = CFrame.Angles(0, rng:NextNumber(0, TAU), lean)
	local trunk = Build.Cyl("Trunk", H - hingeY, d, axis * CFrame.new(0, (H + hingeY) / 2, 0), bark, M.Wood, top, true) -- 5
	-- snapped top: a pale jagged wedge
	block("Snap", Vector3.new(d * 0.7, d * 1.2, d * 0.8), axis * CFrame.new(0, H + d * 0.5, 0) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
		Build.Tint(CUT_WOOD, 0.8), M.Wood, top, "WedgePart") -- 6
	local nb = rng:NextInteger(3, 4)
	local a0 = rng:NextNumber(0, TAU)
	for i = 1, nb do -- <= 10
		local y = H * (0.35 + 0.5 * (i - 1) / (nb - 1)) * rng:NextNumber(0.95, 1.05)
		local from = axis * Vector3.new(0, y, 0)
		local a = a0 + i * 2.3
		local len = H * rng:NextNumber(0.14, 0.24) * (1.1 - 0.4 * (i - 1) / (nb - 1))
		local to = from + Vector3.new(math.cos(a) * len, len * rng:NextNumber(0.3, 0.9), math.sin(a) * len)
		limb("Branch", from, to, d * rng:NextNumber(0.22, 0.32), vary(rng, BARK_GREY, 0.06), M.Wood, top, false)
	end

	Build.SetPivot(top, trunk, CFrame.new(0, hingeY, 0))
	finish(m, root, cf, parent)
	skinTree(m, top, "SM_Tree_Dead_Large01", STUMP_SKINS.Dead, H)
	return m
end

--- Berry bush: 2-3 leafy balls with 6-8 berries (Yield) of one colour.
--- Parts: <= 12.
function Flora.BerryBush(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("BerryBush")
	local root = makeRoot(m, 4.5, 3) -- 1
	local berryCol = pick(rng, BERRY)
	local balls = {}
	local nb = rng:NextInteger(2, 3)
	for i = 1, nb do -- <= 4
		local r = if i == 1 then rng:NextNumber(1.7, 2.1) else rng:NextNumber(1.2, 1.6)
		local a = rng:NextNumber(0, TAU)
		local off = if i == 1 then Vector3.zero else Vector3.new(math.cos(a) * 1.5, 0, math.sin(a) * 1.5)
		local c = off + Vector3.new(0, r * 0.8, 0)
		Build.Ball("Leaves", r * 2, CFrame.new(c), shade(rng, BUSH, 0.06), M.LeafyGrass, m)
		table.insert(balls, { c = c, r = r })
	end
	local n = rng:NextInteger(6, 8)
	for _ = 1, n do -- <= 12
		local b = balls[rng:NextInteger(1, #balls)]
		local a = rng:NextNumber(0, TAU)
		local el = rng:NextNumber(0.05, 1.1)
		local dir = Vector3.new(math.cos(el) * math.cos(a), math.sin(el), math.cos(el) * math.sin(a))
		markYield(Build.Ball("Berry", rng:NextNumber(0.42, 0.55), CFrame.new(b.c + dir * b.r * 0.94), vary(rng, berryCol, 0.1), M.SmoothPlastic, m))
	end
	finish(m, root, cf, parent)
	if Skins.Enabled() then
		Skins.Dress(m, "SM_Bush01", { scale = 4.5 / 3.4, keep = { Berry = true } }) -- berries stay procedural (they are the yield)
	end
	return m
end

--- Mushroom patch: a mossy base with 4-5 mushrooms; stems and caps are Yield.
--- Parts: <= 12.
function Flora.MushroomPatch(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("MushroomPatch")
	local root = makeRoot(m, 3.5, 1.5) -- 1
	Build.Cyl("Moss", 0.2, rng:NextNumber(2.8, 3.4), CFrame.new(0, 0.08, 0), shade(rng, MOSS, 0.06), M.Grass, m, false) -- 2
	local capCol = if rng:NextNumber() < 0.5 then CAP_BROWN else CAP_TAN
	local n = rng:NextInteger(4, 5)
	for i = 1, n do -- <= 12
		local a = rng:NextNumber(0, TAU)
		local dist = if i == 1 then 0.2 else rng:NextNumber(0.5, 1.3)
		local h = rng:NextNumber(0.5, 1.0)
		local pos = Vector3.new(math.cos(a) * dist, 0, math.sin(a) * dist)
		local stem = Build.Cyl("Stem", h, rng:NextNumber(0.22, 0.32), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), STEM, M.SmoothPlastic, m, false)
		markYield(stem)
		local cd = rng:NextNumber(0.6, 1.0)
		markYield(Build.Cyl("Cap", 0.28, cd, CFrame.new(pos + Vector3.new(0, h, 0)) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12)), vary(rng, capCol, 0.1), M.SmoothPlastic, m, false))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_Mushrooms01", nil, 2.2)
	return m
end

--- Loose stones on a dirt patch; the stones are Yield. Parts: <= 8.
function Flora.LooseStones(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("LooseStones")
	local root = makeRoot(m, 3.5, 1.2) -- 1
	Build.Cyl("Dirt", 0.16, rng:NextNumber(2.8, 3.4), CFrame.new(0, 0.06, 0), vary(rng, DIRT, 0.08), M.Ground, m, false) -- 2
	local n = rng:NextInteger(4, 6)
	for _ = 1, n do -- <= 8
		local a = rng:NextNumber(0, TAU)
		local dist = rng:NextNumber(0, 1.2)
		local s = Vector3.new(rng:NextNumber(0.5, 0.9), rng:NextNumber(0.3, 0.55), rng:NextNumber(0.45, 0.8))
		markYield(block("Stone", s, CFrame.new(math.cos(a) * dist, s.Y * 0.4, math.sin(a) * dist) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, TAU), rng:NextNumber(-0.3, 0.3)),
			shade(rng, ROCK, 0.1), if rng:NextNumber() < 0.5 then M.Slate else M.Rock, m))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_StreamRocks01", "SM_StreamRocks03", 1.0)
	return m
end

--- Rock pile: a colliding main boulder (+ optional side rock) that stays, with
--- 4-6 small loose chunks marked Yield. Parts: <= 9.
local function rockPile(cf: CFrame, rng: Random, parent: Instance?, k: number, name: string): Model
	local m = Build.Model(name)
	local root = makeRoot(m, 6 * k, 3.5 * k) -- 1
	local mat = if rng:NextNumber() < 0.5 then M.Rock else M.Slate
	local main = Vector3.new(rng:NextNumber(3.6, 4.6), rng:NextNumber(2.4, 3.2), rng:NextNumber(3.2, 4.2)) * k
	solid("Boulder", main, CFrame.new(0, main.Y * 0.42, 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, TAU), rng:NextNumber(-0.15, 0.15)), shade(rng, ROCK, 0.08), mat, m) -- 2
	if rng:NextNumber() < 0.6 or k > 1 then -- 3
		local s = Vector3.new(rng:NextNumber(1.8, 2.4), rng:NextNumber(1.2, 1.8), rng:NextNumber(1.6, 2.2)) * k
		local a = rng:NextNumber(0, TAU)
		solid("Rock", s, CFrame.new(math.cos(a) * 2.2 * k, s.Y * 0.4, math.sin(a) * 2.2 * k) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, TAU), rng:NextNumber(-0.3, 0.3)), shade(rng, ROCK, 0.08), mat, m)
	end
	local n = rng:NextInteger(4, 6)
	local a0 = rng:NextNumber(0, TAU)
	for i = 1, n do -- <= 9
		local a = a0 + i * TAU / n + rng:NextNumber(-0.3, 0.3)
		local dist = rng:NextNumber(2.2, 2.9) * k
		local s = Vector3.new(rng:NextNumber(0.7, 1.2), rng:NextNumber(0.5, 0.9), rng:NextNumber(0.7, 1.1)) * math.sqrt(k)
		markYield(block("Chunk", s, CFrame.new(math.cos(a) * dist, s.Y * 0.4, math.sin(a) * dist) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, TAU), rng:NextNumber(-0.4, 0.4)),
			shade(rng, ROCK, 0.1), mat, m))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_StoneDeposit01", "SM_StoneDeposit01_Depleted", 1.05 * k)
	return m
end

--- Small stone deposit (Crude Pickaxe+): boulder + chunks (Yield). Parts: <= 9.
function Flora.RockPile(cf: CFrame, rng: Random, parent: Instance?): Model
	return rockPile(cf, rng, parent, 1, "RockPile")
end

--- Large stone deposit (Stone Pickaxe+): the same pile at double size.
function Flora.LargeRockPile(cf: CFrame, rng: Random, parent: Instance?): Model
	return rockPile(cf, rng, parent, 2, "LargeRockPile")
end

--- Scrap pile (POI node, pickaxe): rusted sheets, a wheel rim and cans (Yield). Parts: <= 10.
function Flora.ScrapPile(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("ScrapPile")
	local root = makeRoot(m, 5, 2.5) -- 1
	local rust = { Color3.fromRGB(128, 84, 58), Color3.fromRGB(110, 96, 84), Color3.fromRGB(90, 96, 104) }
	block("Base", Vector3.new(4.4, 0.4, 3.8), CFrame.new(0, 0.2, 0) * spin(rng), Color3.fromRGB(70, 60, 52), M.Ground, m) -- 2
	for i = 1, 6 do -- 8
		local s = Vector3.new(rng:NextNumber(1.2, 2.4), rng:NextNumber(0.15, 0.5), rng:NextNumber(0.8, 1.8))
		local a = rng:NextNumber(0, TAU)
		markYield(block("Scrap", s, CFrame.new(math.cos(a) * rng:NextNumber(0, 1.4), 0.4 + i * 0.18, math.sin(a) * rng:NextNumber(0, 1.2)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, TAU), rng:NextNumber(-0.6, 0.6)),
			rust[(i % #rust) + 1], M.CorrodedMetal, m))
	end
	markYield(Build.Cyl("Rim", 0.4, 1.6, CFrame.new(1.2, 0.9, -0.6) * CFrame.Angles(0.4, 0, 1.2), Color3.fromRGB(60, 60, 64), M.Metal, m, false)) -- 9
	finish(m, root, cf, parent)
	return m
end

-- Ore deposits (POI / cave nodes, Stone Pickaxe+): a rock hump with coloured seams (Yield).
local function oreDeposit(cf: CFrame, rng: Random, parent: Instance?, name: string, seam: Color3, seamMat: Enum.Material, k: number): Model
	local m = Build.Model(name)
	local root = makeRoot(m, 5 * k, 3.5 * k) -- 1
	local main = Vector3.new(rng:NextNumber(3.8, 4.6), rng:NextNumber(2.6, 3.2), rng:NextNumber(3.2, 4)) * k
	solid("Rock", main, CFrame.new(0, main.Y * 0.42, 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, TAU), 0), shade(rng, ROCK, 0.08), M.Slate, m) -- 2
	for i = 1, 5 do -- 7
		local a = i * TAU / 5 + rng:NextNumber(-0.3, 0.3)
		local s = Vector3.new(rng:NextNumber(0.6, 1.1), rng:NextNumber(0.4, 0.8), rng:NextNumber(0.6, 1)) * k
		markYield(block("Seam", s, CFrame.new(math.cos(a) * main.X * 0.42, main.Y * rng:NextNumber(0.35, 0.7), math.sin(a) * main.Z * 0.42) * CFrame.Angles(rng:NextNumber(0, 1), a, 0), seam, seamMat, m))
	end
	finish(m, root, cf, parent)
	return m
end

function Flora.CoalDeposit(cf: CFrame, rng: Random, parent: Instance?): Model
	return oreDeposit(cf, rng, parent, "CoalDeposit", Color3.fromRGB(34, 34, 38), M.Basalt, 1)
end

function Flora.IronDeposit(cf: CFrame, rng: Random, parent: Instance?): Model
	return oreDeposit(cf, rng, parent, "IronDeposit", Color3.fromRGB(170, 104, 76), M.CorrodedMetal, 1)
end

function Flora.RichIronDeposit(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = oreDeposit(cf, rng, parent, "RichIronDeposit", Color3.fromRGB(200, 120, 80), M.CorrodedMetal, 1.3)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Seam" then
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 170, 110)
			glow.Range = 6
			glow.Brightness = 0.6
			glow.Parent = d
			break
		end
	end
	return m
end

--- Twig pile: a leaf-litter patch with 5-7 crossed twigs (Yield). Parts: <= 9.
function Flora.TwigPile(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("TwigPile")
	local root = makeRoot(m, 3.5, 1.2) -- 1
	block("Litter", Vector3.new(rng:NextNumber(2.6, 3.2), 0.1, rng:NextNumber(2.4, 3.0)), CFrame.new(0, 0.05, 0) * spin(rng), shade(rng, LITTER, 0.08), M.Ground, m) -- 2
	local n = rng:NextInteger(5, 7)
	for i = 1, n do -- <= 9
		local len = rng:NextNumber(1.6, 2.6)
		local a = rng:NextNumber(0, TAU)
		local y = 0.12 + i * 0.07
		local c = Vector3.new(rng:NextNumber(-0.5, 0.5), y, rng:NextNumber(-0.5, 0.5))
		local dir = Vector3.new(math.cos(a), rng:NextNumber(-0.08, 0.12), math.sin(a)) * (len / 2)
		markYield(limb("Twig", c - dir, c + dir, rng:NextNumber(0.14, 0.22), vary(rng, if i % 2 == 0 then BARK else BARK_GREY, 0.1), M.Wood, m, false))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_Sticks_Loose01", nil, 1.3, { Litter = true })
	return m
end

--- Fibre plant: dark basal fronds that stay, plus tall pale fibre fronds and
--- seed buds that are Yield. Parts: <= 12.
function Flora.FibrePlant(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("FibrePlant")
	local root = makeRoot(m, 3, 2) -- 1
	Build.Ball("Tuft", 1.4, CFrame.new(0, 0.3, 0), shade(rng, FERN, 0.05), M.Grass, m) -- 2
	local a0 = rng:NextNumber(0, TAU)
	for i = 0, 2 do -- 5: low fronds (stay)
		local a = a0 + i * TAU / 3
		block("Frond", Vector3.new(0.2, 2.0, 1.0), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.7, 0.9) * CFrame.Angles(math.rad(62), 0, 0),
			vary(rng, FERN[3], 0.08), M.Grass, m, "WedgePart")
	end
	local nTall = 4
	for i = 0, nTall - 1 do -- 9: tall fibre fronds (Yield)
		local a = a0 + math.pi / 3 + i * TAU / nTall + rng:NextNumber(-0.2, 0.2)
		local h = rng:NextNumber(2.6, 3.4)
		markYield(block("Fibre", Vector3.new(0.18, h, 0.8), CFrame.Angles(0, a, 0) * CFrame.new(0, h * 0.45, 0.45) * CFrame.Angles(math.rad(rng:NextNumber(14, 26)), 0, 0),
			vary(rng, Color3.fromRGB(160, 178, 104), 0.08), M.Grass, m, "WedgePart"))
	end
	local budCol = vary(rng, Color3.fromRGB(236, 214, 120), 0.06)
	for i = 0, 2 do -- 12: buds (Yield)
		local a = a0 + i * TAU / 3 + 0.5
		markYield(Build.Ball("Bud", rng:NextNumber(0.45, 0.6), CFrame.Angles(0, a, 0) * CFrame.new(0, rng:NextNumber(2.3, 2.9), 0.9), budCol, M.SmoothPlastic, m))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_FiberPlant01", "SM_FiberPlant01_Harvested", 1.0)
	return m
end

--------------------------------------------------------------------------------
-- Decorative trees  (cf, rng, scale?, parent)
--------------------------------------------------------------------------------

--- Pine. Variants: tall-slim tiered, broad layered (with dead lower stubs),
--- lopsided windswept. Parts: 8 / 10 / 8.
function Flora.Pine(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Pine")
	local bark = vary(rng, BARK_PINE, 0.07)
	local v = rng:NextInteger(1, 3)
	local trunk: BasePart
	if v == 1 then -- tall & slim
		local H = 34 * s
		trunk = Build.Cyl("Trunk", H * 0.9, 1.8 * s, CFrame.new(0, H * 0.45, 0), bark, M.Wood, m, true)
		tierStack(m, rng, CFrame.new(), H * 0.3, H * 0.84, 6, 11 * s, 3 * s, H * 0.14, NEEDLE, nil, 0.3 * s)
		Build.Cyl("Tip", H * 0.14, 1.4 * s, CFrame.new(0, H * 0.92, 0), shade(rng, NEEDLE, 0.05), M.Grass, m, false)
	elseif v == 2 then -- broad, layered, tiers with gaps
		local H = 28 * s
		trunk = Build.Cyl("Trunk", H * 0.88, 2.3 * s, CFrame.new(0, H * 0.44, 0), bark, M.Wood, m, true)
		tierStack(m, rng, CFrame.new(), H * 0.3, H * 0.86, 5, 17 * s, 5 * s, H * 0.08, NEEDLE, nil, 0.6 * s)
		Build.Cyl("Tip", H * 0.12, 2 * s, CFrame.new(0, H * 0.93, 0), shade(rng, NEEDLE, 0.05), M.Grass, m, false)
		local a = rng:NextNumber(0, TAU)
		for i = 0, 1 do
			local aa = a + i * 2.4
			local y = H * rng:NextNumber(0.14, 0.24)
			limb("DeadBranch", Vector3.new(0, y, 0), Vector3.new(math.cos(aa) * 3 * s, y - 0.8 * s, math.sin(aa) * 3 * s), 0.35 * s, BARK_GREY, M.Wood, m, false)
		end
	else -- lopsided windswept
		local H = 30 * s
		local a = rng:NextNumber(0, TAU)
		local lean = rng:NextNumber(0.06, 0.12)
		local axis = CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, lean)
		local leanDir = CFrame.Angles(0, a, 0):VectorToWorldSpace(Vector3.new(-1, 0, 0))
		trunk = Build.Cyl("Trunk", H * 0.88, 2 * s, axis * CFrame.new(0, H * 0.44, 0), bark, M.Wood, m, true)
		tierStack(m, rng, axis, H * 0.34, H * 0.86, 6, 13 * s, 3.5 * s, H * 0.1, NEEDLE, leanDir * 3.5 * s, 0.4 * s)
		Build.Cyl("Tip", H * 0.1, 1.4 * s, CFrame.new(axis * Vector3.new(0, H * 0.92, 0) + leanDir * 3.5 * s),shade(rng, NEEDLE, 0.05), M.Grass, m, false)
	end
	return finish(m, trunk, cf, parent)
end

--- Spruce: dense tiers starting near the ground. Variants: dense cone, blue
--- spruce, narrow subalpine spire. Parts: 10 / 10 / 11.
function Flora.Spruce(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Spruce")
	local bark = vary(rng, BARK_DARK, 0.07)
	local v = rng:NextInteger(1, 3)
	local trunk: BasePart
	if v == 1 then
		local H = 30 * s
		trunk = Build.Cyl("Trunk", H * 0.9, 1.9 * s, CFrame.new(0, H * 0.45, 0), bark, M.Wood, m, true)
		tierStack(m, rng, CFrame.new(), H * 0.1, H * 0.85, 8, 14 * s, 2.5 * s, H * 0.13, SPRUCE, nil, 0.25 * s)
		Build.Cyl("Tip", H * 0.12, 1.2 * s, CFrame.new(0, H * 0.93, 0), shade(rng, SPRUCE, 0.05), M.Grass, m, false)
	elseif v == 2 then
		local H = 26 * s
		trunk = Build.Cyl("Trunk", H * 0.9, 2 * s, CFrame.new(0, H * 0.45, 0), bark, M.Wood, m, true)
		Build.Cyl("Flare", 1.2 * s, 3 * s, CFrame.new(0, 0.6 * s, 0), Build.Tint(bark, 0.9), M.Wood, m, true)
		tierStack(m, rng, CFrame.new(), H * 0.12, H * 0.84, 7, 15 * s, 3 * s, H * 0.14, SPRUCE_BLUE, nil, 0.3 * s)
		Build.Cyl("Tip", H * 0.12, 1.4 * s, CFrame.new(0, H * 0.93, 0), shade(rng, SPRUCE_BLUE, 0.05), M.Grass, m, false)
	else
		local H = 38 * s
		trunk = Build.Cyl("Trunk", H * 0.9, 1.6 * s, CFrame.new(0, H * 0.45, 0), bark, M.Wood, m, true)
		tierStack(m, rng, CFrame.new(), H * 0.08, H * 0.86, 9, 8 * s, 2 * s, H * 0.11, SPRUCE, nil, 0.2 * s)
		Build.Cyl("Tip", H * 0.12, 0.9 * s, CFrame.new(0, H * 0.93, 0), shade(rng, SPRUCE, 0.05), M.Grass, m, false)
	end
	return finish(m, trunk, cf, parent)
end

--- Oak. Variants: round crown, wide spreading, two-trunk. Parts: <= 11 / 11 / 10.
function Flora.Oak(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Oak")
	local bark = vary(rng, BARK_OAK, 0.07)
	local pal = if rng:NextNumber() < 0.5 then LEAF else LEAF_DEEP
	local v = rng:NextInteger(1, 3)
	local trunk: BasePart
	if v == 1 then -- round crown
		local H = 24 * s
		local tTop = H * 0.55
		trunk = Build.Cyl("Trunk", tTop, 2.8 * s, CFrame.new(0, tTop / 2, 0), bark, M.Wood, m, true)
		Build.Cyl("Flare", 1.4 * s, 3.8 * s, CFrame.new(0, 0.7 * s, 0), Build.Tint(bark, 0.9), M.Wood, m, true)
		local r = 6.5 * s
		local cy = H - r * 1.1
		local a0 = rng:NextNumber(0, TAU)
		for i = 0, 2 do
			local a = a0 + i * TAU / 3 + rng:NextNumber(-0.3, 0.3)
			limb("Limb", Vector3.new(0, tTop * 0.85, 0), Vector3.new(math.cos(a) * r * 0.6, cy - r * 0.1, math.sin(a) * r * 0.6), 1.1 * s, bark, M.Wood, m, false)
		end
		crown(m, rng, Vector3.new(0, cy, 0), r, 6, pal)
	elseif v == 2 then -- wide spreading
		local H = 20 * s
		local tTop = H * 0.45
		trunk = Build.Cyl("Trunk", tTop, 3.2 * s, CFrame.new(0, tTop / 2, 0), bark, M.Wood, m, true)
		local a0 = rng:NextNumber(0, TAU)
		local ends = {}
		for i = 0, 3 do
			local a = a0 + i * TAU / 4 + rng:NextNumber(-0.35, 0.35)
			local reach = rng:NextNumber(7, 9.5) * s
			local e = Vector3.new(math.cos(a) * reach, tTop + rng:NextNumber(2.5, 4) * s, math.sin(a) * reach)
			limb("Limb", Vector3.new(0, tTop * 0.9, 0), e, 1.2 * s, bark, M.Wood, m, false)
			table.insert(ends, e)
		end
		for i, e in ends do
			Build.Ball("Canopy", rng:NextNumber(7, 9) * s, CFrame.new(e + Vector3.new(0, 1.5 * s, 0)), shade(rng, pal, 0.06), M.LeafyGrass, m)
			if i <= 2 then
				local mid = e * Vector3.new(0.45, 1, 0.45) + Vector3.new(0, 3 * s, 0)
				Build.Ball("Canopy", rng:NextNumber(8, 10) * s, CFrame.new(mid), shade(rng, pal, 0.06), M.LeafyGrass, m)
			end
		end
		-- 1 + 4 + 6 = 11
	else -- two-trunk fork
		local H = 24 * s
		trunk = Build.Cyl("Flare", 2.4 * s, 4.2 * s, CFrame.new(0, 1.2 * s, 0), bark, M.Wood, m, true)
		local a = rng:NextNumber(0, TAU)
		for i = 0, 1 do
			local aa = a + i * math.pi
			local topP = Vector3.new(math.cos(aa) * 4.5 * s, H * rng:NextNumber(0.5, 0.6), math.sin(aa) * 4.5 * s)
			limb("Trunk", Vector3.new(0, 1.8 * s, 0), topP, 2 * s, bark, M.Wood, m, true)
			crown(m, rng, topP + Vector3.new(math.cos(aa) * 1.5 * s, 4 * s, math.sin(aa) * 1.5 * s), 4.8 * s, if i == 0 then 4 else 3, pal)
		end
		-- 1 + 2 + 7 = 10
	end
	return finish(m, trunk, cf, parent)
end

--- Birch. Variants: single slender, clump of 3 stems, leaning. Parts: 9 / 11 / 8.
function Flora.Birch(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Birch")
	local bark = vary(rng, BIRCH_BARK, 0.04)
	local v = rng:NextInteger(1, 3)
	local trunk: BasePart
	local function column(axis: CFrame, H: number, td: number, n: number, marks: number, r: number)
		local t = Build.Cyl("Trunk", H * 0.9, td, axis * CFrame.new(0, H * 0.45, 0), bark, M.Wood, m, true)
		barkMarks(m, rng, axis, td / 2, 1.5 * s, H * 0.55, marks)
		for i = 1, n do
			local k = (i - 1) / math.max(1, n - 1)
			local y = H * 0.55 + (H - r * 1.3 - H * 0.55) * k
			local w = r * (1.25 - 0.35 * k) * rng:NextNumber(0.9, 1.1)
			local p = axis * Vector3.new(0, y, 0) + Vector3.new(rng:NextNumber(-0.5, 0.5) * r, 0, rng:NextNumber(-0.5, 0.5) * r)
			Build.Ball("Canopy", w * 2, CFrame.new(p), shade(rng, BIRCH_LEAF, 0.05), M.LeafyGrass, m)
		end
		return t
	end
	if v == 1 then
		local H = 26 * s
		trunk = column(CFrame.new(), H, 1.3 * s, 4, 3, 3.4 * s)
		local a = rng:NextNumber(0, TAU)
		limb("Branch", Vector3.new(0, H * 0.5, 0), Vector3.new(math.cos(a) * 3 * s, H * 0.64, math.sin(a) * 3 * s), 0.5 * s, bark, M.Wood, m, false)
	elseif v == 2 then
		local a0 = rng:NextNumber(0, TAU)
		for i = 0, 2 do
			local H = 22 * s * rng:NextNumber(0.85, 1.1)
			local axis = CFrame.Angles(0, a0 + i * TAU / 3, 0) * CFrame.Angles(0, 0, rng:NextNumber(0.1, 0.18))
			local t = column(axis, H, 1.0 * s, 2, if i == 0 then 2 else 0, 2.8 * s)
			if i == 0 then
				trunk = t
			end
		end
	else
		local H = 24 * s
		local axis = CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.Angles(0, 0, rng:NextNumber(0.14, 0.22))
		trunk = column(axis, H, 1.3 * s, 4, 3, 3.2 * s)
	end
	return finish(m, trunk, cf, parent)
end

--- Aspen: tall pale trunk with a narrow columnar crown. Variants: green
--- column, golden column, twin grove pair. Parts: 8 / 8 / 11.
function Flora.Aspen(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Aspen")
	local bark = vary(rng, ASPEN_BARK, 0.04)
	local v = rng:NextInteger(1, 3)
	local pal = if v == 2 then ASPEN_GOLD else ASPEN_LEAF
	local function stem(base: Vector3, H: number, n: number, marks: number)
		local t = Build.Cyl("Trunk", H * 0.92, 1.1 * s, CFrame.new(base + Vector3.new(0, H * 0.46, 0)), bark, M.Wood, m, true)
		barkMarks(m, rng, CFrame.new(base), 0.55 * s, 1.5 * s, H * 0.5, marks)
		local r = 2.3 * s
		for i = 1, n do
			local k = (i - 1) / math.max(1, n - 1)
			local y = H * 0.5 + (H - r - H * 0.5) * k
			local p = base + Vector3.new(rng:NextNumber(-0.6, 0.6) * s, y, rng:NextNumber(-0.6, 0.6) * s)
			Build.Ball("Canopy", r * 2 * (1.15 - 0.3 * k) * rng:NextNumber(0.9, 1.1), CFrame.new(p), shade(rng, pal, 0.06), M.LeafyGrass, m)
		end
		return t
	end
	local trunk: BasePart
	if v <= 2 then
		trunk = stem(Vector3.zero, 28 * s, 5, 2)
	else
		local a = rng:NextNumber(0, TAU)
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * 2.2 * s
		trunk = stem(off, 28 * s * rng:NextNumber(0.95, 1.05), 4, 1)
		stem(-off, 22 * s * rng:NextNumber(0.9, 1.05), 3, 1)
	end
	return finish(m, trunk, cf, parent)
end

--- Giant landmark tree: massive trunk, buttress roots, 4 limbs and a layered
--- two-tier canopy. Parts: 20 (budget 22).
function Flora.GiantTree(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("GiantTree")
	local bark = vary(rng, BARK, 0.06)
	local pal = if rng:NextNumber() < 0.5 then LEAF else LEAF_DEEP
	local tTop = 34 * s
	local trunk = Build.Cyl("Trunk", tTop, 7 * s, CFrame.new(0, tTop / 2, 0), bark, M.Wood, m, true) -- 1
	Build.Cyl("Flare", 3 * s, 10 * s, CFrame.new(0, 1.5 * s, 0), Build.Tint(bark, 0.9), M.Wood, m, true) -- 2
	local a0 = rng:NextNumber(0, TAU)
	for i = 0, 3 do -- 6: buttress roots
		local a = a0 + i * TAU / 4 + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		limb("Root", dir * 2.5 * s + Vector3.new(0, 5 * s, 0), dir * 8.5 * s + Vector3.new(0, -0.5 * s, 0), 2.2 * s, Build.Tint(bark, 0.95), M.Wood, m, true)
	end
	local ends = {}
	for i = 0, 3 do -- 10: limbs
		local a = a0 + math.pi / 4 + i * TAU / 4 + rng:NextNumber(-0.3, 0.3)
		local reach = rng:NextNumber(11, 15) * s
		local e = Vector3.new(math.cos(a) * reach, tTop + rng:NextNumber(3, 7) * s, math.sin(a) * reach)
		limb("Limb", Vector3.new(0, tTop * rng:NextNumber(0.78, 0.9), 0), e, 2.4 * s, bark, M.Wood, m, false)
		table.insert(ends, e)
	end
	for _, e in ends do -- 14: lower canopy blobs at limb ends
		Build.Ball("Canopy", rng:NextNumber(12, 15) * s, CFrame.new(e + Vector3.new(0, 1.5 * s, 0)), shade(rng, pal, 0.06), M.LeafyGrass, m)
	end
	-- 20: upper crown
	crown(m, rng, Vector3.new(0, tTop + 11 * s, 0), 9 * s, 6, pal, 0.3)
	return finish(m, trunk, cf, parent)
end

--- Dead snag. Variants: tall broken snag, short jagged stub with fungus,
--- leaning snag with one big branch. Parts: <= 6.
function Flora.DeadSnag(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("DeadSnag")
	local bark = vary(rng, BARK_GREY, 0.08)
	local v = rng:NextInteger(1, 3)
	local trunk: BasePart
	if v == 1 then
		local H = 18 * s
		trunk = Build.Cyl("Trunk", H, 2 * s, CFrame.new(0, H / 2, 0), bark, M.Wood, m, true)
		block("Snap", Vector3.new(1.4 * s, 2.4 * s, 1.6 * s), CFrame.new(0, H + 1.1 * s, 0) * spin(rng), Build.Tint(CUT_WOOD, 0.75), M.Wood, m, "WedgePart")
		local a0 = rng:NextNumber(0, TAU)
		for i = 1, 3 do
			local y = H * (0.3 + i * 0.18)
			local a = a0 + i * 2.2
			local len = rng:NextNumber(2.5, 4) * s
			limb("Branch", Vector3.new(0, y, 0), Vector3.new(math.cos(a) * len, y + len * 0.6, math.sin(a) * len), 0.45 * s, bark, M.Wood, m, false)
		end
	elseif v == 2 then
		local H = 6 * s
		trunk = Build.Cyl("Trunk", H, 2.8 * s, CFrame.new(0, H / 2, 0), bark, M.Wood, m, true)
		local a = rng:NextNumber(0, TAU)
		block("Jag", Vector3.new(1.4 * s, 2.2 * s, 1.2 * s), CFrame.new(0, H + 1 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0.5 * s, 0, 0), Build.Tint(CUT_WOOD, 0.7), M.Wood, m, "WedgePart")
		block("Jag", Vector3.new(1.2 * s, 1.4 * s, 1.2 * s), CFrame.new(0, H + 0.6 * s, 0) * CFrame.Angles(0, a + 2.5, 0) * CFrame.new(0.6 * s, 0, 0), Build.Tint(CUT_WOOD, 0.65), M.Wood, m, "WedgePart")
		for i = 0, 1 do
			Build.Cyl("Fungus", 0.3 * s, rng:NextNumber(1.4, 2) * s, CFrame.new(0, H * (0.35 + i * 0.3), 0) * CFrame.Angles(0, a + 1 + i, 0) * CFrame.new(1.3 * s, 0, 0), vary(rng, CAP_TAN, 0.1), M.SmoothPlastic, m, false)
		end
	else
		local H = 16 * s
		local axis = CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.Angles(0, 0, rng:NextNumber(0.2, 0.3))
		trunk = Build.Cyl("Trunk", H, 2.2 * s, axis * CFrame.new(0, H / 2, 0), bark, M.Wood, m, true)
		local from = axis * Vector3.new(0, H * 0.6, 0)
		local a = rng:NextNumber(0, TAU)
		limb("Branch", from, from + Vector3.new(math.cos(a) * 5 * s, 4 * s, math.sin(a) * 5 * s), 0.8 * s, bark, M.Wood, m, false)
		block("Snap", Vector3.new(1.6 * s, 2 * s, 1.6 * s), axis * CFrame.new(0, H + 0.9 * s, 0), Build.Tint(CUT_WOOD, 0.75), M.Wood, m, "WedgePart")
	end
	return finish(m, trunk, cf, parent)
end

--------------------------------------------------------------------------------
-- Logs, stumps, saplings, bushes
--------------------------------------------------------------------------------

--- Fallen log. Variants: mossy, with branch stubs, with shelf fungus. Parts: <= 5.
function Flora.FallenLog(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("FallenLog")
	local len = rng:NextNumber(10, 18) * s
	local d = rng:NextNumber(2.2, 3.2) * s
	local bark = vary(rng, pick(rng, { BARK, BARK_OAK, BARK_GREY }), 0.08)
	local lay = CFrame.new(0, d * 0.42, 0) * CFrame.Angles(0, 0, math.pi / 2) -- axis along -X
	local log = Build.Cyl("Log", len, d, lay, bark, M.Wood, m, true)
	Build.Cyl("Cut", 0.12, d * 0.86, lay * CFrame.new(0, len / 2 + 0.02, 0), vary(rng, CUT_WOOD, 0.08), M.Wood, m, false)
	local v = rng:NextInteger(1, 3)
	if v == 1 then
		block("Moss", Vector3.new(len * 0.6, 0.3, d * 0.6), CFrame.new(rng:NextNumber(-1, 1) * s, d * 0.42 + d * 0.45, 0), shade(rng, MOSS, 0.06), M.Grass, m)
		block("Moss", Vector3.new(len * 0.25, 0.3, d * 0.5), CFrame.new(-len * 0.3, d * 0.42 + d * 0.4, 0.2 * d) * CFrame.Angles(0.3, 0, 0), shade(rng, MOSS, 0.06), M.Grass, m)
	elseif v == 2 then
		for i = 0, 1 do
			local x = (i - 0.5) * len * 0.5 + rng:NextNumber(-1, 1) * s
			local side = if rng:NextNumber() < 0.5 then 1 else -1
			local p = Vector3.new(x, d * 0.6, side * d * 0.35)
			limb("Stub", p, p + Vector3.new(rng:NextNumber(-0.8, 0.8), 1.4 * s, side * 1.8 * s), 0.45 * s, bark, M.Wood, m, false)
		end
	else
		for i = 0, 2 do
			local x = (i - 1) * len * 0.22 + rng:NextNumber(-0.5, 0.5)
			Build.Cyl("Fungus", 0.25, rng:NextNumber(1.0, 1.6) * s, CFrame.new(x, d * 0.42 + rng:NextNumber(-0.1, 0.25) * d, d * 0.5), vary(rng, if i == 1 then CAP_BROWN else CAP_TAN, 0.1), M.SmoothPlastic, m, false)
		end
	end
	return finish(m, log, cf, parent)
end

--- Tree stump. Variants: clean cut (pale top ring + roots), broken jagged,
--- mossy. Parts: <= 5.
function Flora.Stump(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Stump")
	local d = rng:NextNumber(2.2, 3.4) * s
	local h = rng:NextNumber(1.2, 2.2) * s
	local bark = vary(rng, pick(rng, { BARK, BARK_OAK, BARK_PINE }), 0.08)
	local st = Build.Cyl("Stump", h, d, CFrame.new(0, h / 2, 0), bark, M.Wood, m, true)
	local v = rng:NextInteger(1, 3)
	if v == 1 then
		Build.Cyl("Cut", 0.1, d * 0.88, CFrame.new(0, h + 0.03, 0), vary(rng, CUT_WOOD, 0.08), M.Wood, m, false)
		local a0 = rng:NextNumber(0, TAU)
		for i = 0, 2 do
			local a = a0 + i * TAU / 3 + rng:NextNumber(-0.3, 0.3)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			limb("Root", dir * d * 0.3 + Vector3.new(0, h * 0.5, 0), dir * d * 0.95 + Vector3.new(0, -0.2, 0), d * 0.28, bark, M.Wood, m, false)
		end
	elseif v == 2 then
		local a = rng:NextNumber(0, TAU)
		for i = 0, 2 do
			block("Jag", Vector3.new(d * 0.35, rng:NextNumber(0.8, 1.6) * s, d * 0.4), CFrame.new(0, h + 0.4 * s, 0) * CFrame.Angles(0, a + i * 2.1, 0) * CFrame.new(d * 0.25, 0, 0),
				Build.Tint(CUT_WOOD, rng:NextNumber(0.65, 0.8)), M.Wood, m, "WedgePart")
		end
	else
		Build.Cyl("Moss", 0.35, d * 1.02, CFrame.new(0, h + 0.1, 0), shade(rng, MOSS, 0.06), M.Grass, m, false)
		Build.Cyl("Moss", 0.25, d * 1.5, CFrame.new(0, 0.1, 0), shade(rng, MOSS, 0.06), M.Grass, m, false)
		Build.Cyl("Fungus", 0.22, 1.1 * s, CFrame.new(0, h * 0.5, 0) * spin(rng) * CFrame.new(d * 0.5, 0, 0), vary(rng, CAP_TAN, 0.1), M.SmoothPlastic, m, false)
	end
	return finish(m, st, cf, parent)
end

--- Sapling: young broadleaf (stem + leaf balls) or young conifer (stem + tiers).
--- Parts: <= 4.
function Flora.Sapling(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Sapling")
	local H = rng:NextNumber(4, 6.5) * s
	local stem = Build.Cyl("Stem", H, 0.35 * s, CFrame.new(0, H / 2, 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)), vary(rng, BARK, 0.1), M.Wood, m, false)
	if rng:NextNumber() < 0.5 then
		for i = 1, 3 do
			Build.Ball("Leaves", rng:NextNumber(1.4, 2.2) * s, CFrame.new(rng:NextNumber(-0.6, 0.6) * s, H * (0.6 + i * 0.13), rng:NextNumber(-0.6, 0.6) * s), shade(rng, LEAF, 0.06), M.LeafyGrass, m)
		end
	else
		tierStack(m, rng, CFrame.new(), H * 0.3, H * 0.9, 3, 3 * s, 1.1 * s, H * 0.25, NEEDLE, nil, 0.1)
	end
	return finish(m, stem, cf, parent, true)
end

--- Bush. Variants: round (3-4 balls), spiky (fanned leaf blades), flowering
--- (2 balls + 3 blossoms). Parts: <= 5.
function Flora.Bush(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Bush")
	local v = rng:NextInteger(1, 3)
	local main: BasePart
	if v == 1 then
		main = Build.Ball("Bush", 4.4 * s, CFrame.new(0, 1.6 * s, 0), shade(rng, BUSH, 0.06), M.LeafyGrass, m)
		local n = rng:NextInteger(2, 3)
		local a0 = rng:NextNumber(0, TAU)
		for i = 1, n do
			local a = a0 + i * TAU / n + rng:NextNumber(-0.3, 0.3)
			local r = rng:NextNumber(2.8, 3.6) * s
			Build.Ball("Bush", r, CFrame.new(math.cos(a) * 1.8 * s, r * 0.38, math.sin(a) * 1.8 * s), shade(rng, BUSH, 0.08), M.LeafyGrass, m)
		end
	elseif v == 2 then
		main = Build.Ball("Bush", 2.4 * s, CFrame.new(0, 0.8 * s, 0), shade(rng, BUSH, 0.06), M.Grass, m)
		local a0 = rng:NextNumber(0, TAU)
		for i = 0, 3 do
			local h = rng:NextNumber(3, 4.2) * s
			block("Blade", Vector3.new(0.3 * s, h, 1.6 * s), CFrame.Angles(0, a0 + i * TAU / 4, 0) * CFrame.new(0, h * 0.45, 0.5 * s) * CFrame.Angles(math.rad(rng:NextNumber(18, 32)), 0, 0),
				shade(rng, GRASS, 0.08), M.Grass, m, "WedgePart")
		end
	else
		main = Build.Ball("Bush", 3.8 * s, CFrame.new(0, 1.4 * s, 0), shade(rng, BUSH, 0.06), M.LeafyGrass, m)
		Build.Ball("Bush", 2.8 * s, CFrame.new(1.5 * s, 1.0 * s, 0.6 * s), shade(rng, BUSH, 0.08), M.LeafyGrass, m)
		local fc = pick(rng, FLOWER)
		for _ = 1, 3 do
			local a = rng:NextNumber(0, TAU)
			local el = rng:NextNumber(0.3, 1.2)
			local dir = Vector3.new(math.cos(el) * math.cos(a), math.sin(el), math.cos(el) * math.sin(a))
			Build.Ball("Flower", 0.7 * s, CFrame.new(Vector3.new(0, 1.4 * s, 0) + dir * 1.85 * s), vary(rng, fc, 0.08), M.SmoothPlastic, m)
		end
	end
	return finish(m, main, cf, parent, true)
end

--------------------------------------------------------------------------------
-- Ground cover (<= 4 parts, no shadows, no collision)
--------------------------------------------------------------------------------

--- Fern: arching wedge fronds. Variants: upright, spreading, fiddlehead. Parts: 4.
function Flora.Fern(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Fern")
	local v = rng:NextInteger(1, 3)
	local tilt = if v == 1 then 28 else 55
	local n = if v == 3 then 3 else 4
	local a0 = rng:NextNumber(0, TAU)
	local first: BasePart
	for i = 0, n - 1 do
		local len = rng:NextNumber(2.4, 3.2)
		local f = block("Frond", Vector3.new(0.18, len, 1.1), CFrame.Angles(0, a0 + i * TAU / n + rng:NextNumber(-0.25, 0.25), 0) * CFrame.new(0, len * 0.4, 0.7) * CFrame.Angles(math.rad(tilt + rng:NextNumber(-8, 8)), 0, 0),
			shade(rng, FERN, 0.07), M.Grass, m, "WedgePart")
		first = first or f
	end
	if v == 3 then
		Build.Ball("Fiddlehead", 0.6, CFrame.new(0.1, 1.2, 0), vary(rng, FERN[1], 0.08), M.Grass, m)
	end
	return finish(m, first, cf, parent, true)
end

--- Tall grass tuft: 3-4 blade wedges; green or dry. Parts: <= 4.
function Flora.TallGrass(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("TallGrass")
	local pal = if rng:NextNumber() < 0.25 then GRASS_DRY else GRASS
	local n = rng:NextInteger(3, 4)
	local first: BasePart
	for i = 1, n do
		local h = rng:NextNumber(1.8, 3.2)
		local b = block("Blade", Vector3.new(0.12, h, rng:NextNumber(0.6, 1.0)),
			CFrame.new(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.Angles(math.rad(rng:NextNumber(-14, 14)), 0, 0) * CFrame.new(0, h / 2, 0),
			shade(rng, pal, 0.08), M.Grass, m, "WedgePart")
		first = first or b
	end
	return finish(m, first, cf, parent, true)
end

--- Flower patch: a leafy clump with 3 blossoms of one or two colours. Parts: 4.
function Flora.FlowerPatch(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("FlowerPatch")
	local base = Build.Cyl("Leaves", 0.4, rng:NextNumber(1.8, 2.4), CFrame.new(0, 0.2, 0), shade(rng, GRASS, 0.06), M.Grass, m, false)
	local c1, c2 = pick(rng, FLOWER), pick(rng, FLOWER)
	for i = 1, 3 do
		local a = rng:NextNumber(0, TAU)
		local dist = rng:NextNumber(0.2, 0.8)
		Build.Ball("Flower", rng:NextNumber(0.45, 0.65), CFrame.new(math.cos(a) * dist, rng:NextNumber(0.6, 1.1), math.sin(a) * dist), vary(rng, if i == 3 then c2 else c1, 0.08), M.SmoothPlastic, m)
	end
	return finish(m, base, cf, parent, true)
end

--- Mushrooms: red toadstool pair, or brown flat-cap pair. Parts: 4.
function Flora.Mushrooms(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Mushrooms")
	local red = rng:NextNumber() < 0.4
	local first: BasePart
	for i = 0, 1 do
		local h = if i == 0 then rng:NextNumber(0.8, 1.2) else rng:NextNumber(0.4, 0.7)
		local p = if i == 0 then Vector3.zero else Vector3.new(rng:NextNumber(-0.7, 0.7), 0, rng:NextNumber(0.4, 0.7))
		local st = Build.Cyl("Stem", h, 0.28, CFrame.new(p + Vector3.new(0, h / 2, 0)), STEM, M.SmoothPlastic, m, false)
		first = first or st
		if red then
			Build.Ball("Cap", h * 0.9 + 0.3, CFrame.new(p + Vector3.new(0, h, 0)), vary(rng, CAP_RED, 0.08), M.SmoothPlastic, m)
		else
			Build.Cyl("Cap", 0.25, h + 0.3, CFrame.new(p + Vector3.new(0, h, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), vary(rng, CAP_BROWN, 0.1), M.SmoothPlastic, m, false)
		end
	end
	return finish(m, first, cf, parent, true)
end

--- Surface roots: 3-4 half-buried arcs radiating from a point. Parts: <= 4.
function Flora.Roots(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Roots")
	local n = rng:NextInteger(3, 4)
	local bark = vary(rng, BARK, 0.1)
	local a0 = rng:NextNumber(0, TAU)
	local first: BasePart
	for i = 1, n do
		local a = a0 + i * TAU / n + rng:NextNumber(-0.4, 0.4)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local r = limb("Root", dir * 0.3 + Vector3.new(0, 0.5, 0), dir * rng:NextNumber(2.5, 4) + Vector3.new(0, -0.3, 0), rng:NextNumber(0.4, 0.7), bark, M.Wood, m, false)
		first = first or r
	end
	return finish(m, first, cf, parent, true)
end

--- Moss patch: 2-3 overlapping flat pads. Parts: <= 3.
function Flora.MossPatch(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("MossPatch")
	local n = rng:NextInteger(2, 3)
	local first: BasePart
	for i = 1, n do
		local p = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		local pad = Build.Cyl("Moss", 0.18 + i * 0.03, rng:NextNumber(1.8, 3.2), CFrame.new(p + Vector3.new(0, 0.06, 0)), shade(rng, MOSS, 0.08), if i == 2 then M.LeafyGrass else M.Grass, m, false)
		first = first or pad
	end
	return finish(m, first, cf, parent, true)
end

--- Leaf litter: 3-4 thin autumn-coloured flakes. Parts: <= 4.
function Flora.LeafLitter(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("LeafLitter")
	local n = rng:NextInteger(3, 4)
	local first: BasePart
	for _ = 1, n do
		local b = block("Leaves", Vector3.new(rng:NextNumber(1.2, 2.2), 0.08, rng:NextNumber(1.0, 1.8)),
			CFrame.new(rng:NextNumber(-1, 1), 0.05, rng:NextNumber(-1, 1)) * spin(rng) * CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05)),
			shade(rng, LITTER, 0.1), M.Grass, m)
		first = first or b
	end
	return finish(m, first, cf, parent, true)
end

--- Twigs: 3-4 thin sticks lying on the ground. Parts: <= 4.
function Flora.Twigs(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Twigs")
	local n = rng:NextInteger(3, 4)
	local first: BasePart
	for _ = 1, n do
		local c = Vector3.new(rng:NextNumber(-0.8, 0.8), 0.1, rng:NextNumber(-0.8, 0.8))
		local a = rng:NextNumber(0, TAU)
		local half = Vector3.new(math.cos(a), 0.03, math.sin(a)) * rng:NextNumber(0.6, 1.2)
		local t = limb("Twig", c - half, c + half, rng:NextNumber(0.12, 0.2), vary(rng, pick(rng, { BARK, BARK_GREY, BARK_DARK }), 0.1), M.Wood, m, false)
		first = first or t
	end
	return finish(m, first, cf, parent, true)
end

--- Pebbles: 3-4 small stones. Parts: <= 4.
function Flora.Pebbles(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Pebbles")
	local n = rng:NextInteger(3, 4)
	local pal = if rng:NextNumber() < 0.5 then ROCK else ROCK_WARM
	local first: BasePart
	for _ = 1, n do
		local s = Vector3.new(rng:NextNumber(0.4, 0.9), rng:NextNumber(0.25, 0.5), rng:NextNumber(0.4, 0.8))
		local p = block("Pebble", s, CFrame.new(rng:NextNumber(-1, 1), s.Y * 0.35, rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, TAU), rng:NextNumber(-0.3, 0.3)),
			shade(rng, pal, 0.1), pick(rng, { M.Pebble, M.Slate, M.Rock }), m)
		first = first or p
	end
	return finish(m, first, cf, parent, true)
end

--------------------------------------------------------------------------------
-- Rocks and water
--------------------------------------------------------------------------------

--- Boulder. Variants: rounded (ball + block), flat slab, stacked, mossy cap.
--- All rock parts collide. Parts: <= 4.
function Flora.Boulder(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Boulder")
	local pal = if rng:NextNumber() < 0.6 then ROCK else ROCK_WARM
	local mat = pick(rng, { M.Rock, M.Slate, M.Basalt })
	local v = rng:NextInteger(1, 4)
	local main: BasePart
	local function rot()
		return CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, TAU), rng:NextNumber(-0.25, 0.25))
	end
	if v == 1 then
		local d = rng:NextNumber(4.5, 6) * s
		main = Build.Ball("Rock", d, CFrame.new(0, d * 0.3, 0), shade(rng, pal, 0.06), mat, m, true)
		solid("Rock", Vector3.new(d * 0.7, d * 0.5, d * 0.6), CFrame.new(d * 0.3, d * 0.2, d * 0.1) * rot(), shade(rng, pal, 0.08), mat, m)
	elseif v == 2 then
		local sz = Vector3.new(rng:NextNumber(6, 9), rng:NextNumber(1.6, 2.4), rng:NextNumber(4, 6)) * s
		main = solid("Rock", sz, CFrame.new(0, sz.Y * 0.4, 0) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, TAU), rng:NextNumber(-0.12, 0.12)), shade(rng, pal, 0.06), mat, m)
		solid("Rock", sz * Vector3.new(0.45, 0.8, 0.5), CFrame.new(sz.X * 0.35, sz.Y * 0.35, sz.Z * 0.25) * rot(), shade(rng, pal, 0.08), mat, m, "WedgePart")
	elseif v == 3 then
		local base = Vector3.new(rng:NextNumber(4, 5.5), rng:NextNumber(2.6, 3.4), rng:NextNumber(3.6, 5)) * s
		main = solid("Rock", base, CFrame.new(0, base.Y * 0.42, 0) * rot(), shade(rng, pal, 0.06), mat, m)
		local up = base * Vector3.new(0.6, 0.7, 0.6)
		solid("Rock", up, CFrame.new(rng:NextNumber(-0.5, 0.5) * s, base.Y * 0.85 + up.Y * 0.4, rng:NextNumber(-0.5, 0.5) * s) * rot(), shade(rng, pal, 0.08), mat, m)
		solid("Rock", base * Vector3.new(0.35, 0.4, 0.35), CFrame.new(base.X * 0.55, base.Y * 0.15, -base.Z * 0.3) * rot(), shade(rng, pal, 0.08), mat, m)
	else
		local d = rng:NextNumber(5, 7) * s
		main = Build.Ball("Rock", d, CFrame.new(0, d * 0.28, 0), shade(rng, pal, 0.06), mat, m, true)
		solid("Rock", Vector3.new(d * 0.8, d * 0.45, d * 0.7), CFrame.new(-d * 0.25, d * 0.15, 0) * rot(), shade(rng, pal, 0.08), mat, m)
		Build.Ball("Moss", d * 0.72, CFrame.new(d * 0.05, d * 0.47, 0), shade(rng, MOSS, 0.06), M.LeafyGrass, m)
	end
	return finish(m, main, cf, parent)
end

--- Cliff rock: a jagged wall segment of roughly `size` (X = length, Y = height,
--- Z = thickness), bottom slightly buried. Parts: <= 10.
function Flora.CliffRock(cf: CFrame, rng: Random, size: Vector3, parent: Instance?): Model
	local m = Build.Model("CliffRock")
	local mat = pick(rng, { M.Slate, M.Rock, M.Basalt })
	local pal = if mat == M.Basalt then { Color3.fromRGB(78, 78, 84), Color3.fromRGB(92, 90, 94), Color3.fromRGB(70, 70, 76) } else ROCK
	local W, H, D = size.X, size.Y, size.Z
	local core = solid("Rock", Vector3.new(W * 0.9, H * 0.82, D * 0.8), CFrame.new(0, H * 0.82 / 2 - 0.5, 0), shade(rng, pal, 0.05), mat, m) -- 1
	local k = rng:NextInteger(5, 7)
	local topY = 0
	for i = 1, k do -- <= 8: jagged faces/crags
		local x = -W / 2 + (i - 0.5) * W / k + rng:NextNumber(-0.15, 0.15) * W / k
		local h = H * rng:NextNumber(0.55, 1.05)
		topY = math.max(topY, h)
		local sz = Vector3.new(W / k * rng:NextNumber(1.1, 1.5), h, D * rng:NextNumber(0.6, 1.05))
		local z = rng:NextNumber(-0.2, 0.2) * D
		solid("Rock", sz, CFrame.new(x, h / 2 - 0.6, z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.1, 0.1)),
			shade(rng, pal, 0.08), mat, m, if rng:NextNumber() < 0.2 then "WedgePart" else nil)
	end
	block("Moss", Vector3.new(W * 0.7, 0.5, D * 0.5), CFrame.new(rng:NextNumber(-0.1, 0.1) * W, H * 0.82 - 0.35, 0), shade(rng, MOSS, 0.06), M.Grass, m) -- 9
	solid("Scree", Vector3.new(W * 0.4, math.min(H * 0.25, 3), D * 0.5), CFrame.new(rng:NextNumber(-0.25, 0.25) * W, math.min(H * 0.25, 3) / 2 - 0.2, D * 0.55) * CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi, 0),
		shade(rng, pal, 0.08), mat, m, "WedgePart") -- 10
	return finish(m, core, cf, parent)
end

--- Waterfall rocks: 2-4 stepped rock ledges descending toward +Z, each with a
--- side boulder and a thin translucent water sheet over its lip, a pool rim at
--- the bottom and a mist ParticleEmitter. `height` = top ledge height.
--- Parts: 3 per step + 2 (<= 14).
function Flora.WaterfallRocks(cf: CFrame, rng: Random, height: number, parent: Instance?): Model
	local m = Build.Model("WaterfallRocks")
	local mat = if rng:NextNumber() < 0.5 then M.Slate else M.Rock
	local n = math.clamp(math.floor(height / 4 + 0.5), 2, 4)
	local stepD = rng:NextNumber(4, 5.5)
	local W = rng:NextNumber(9, 12)
	local waterW = W * rng:NextNumber(0.35, 0.5)
	local z0 = -(n * stepD) / 2
	local first: BasePart
	for i = 1, n do
		local top = height * (1 - (i - 1) / n)
		local nextTop = if i < n then height * (1 - i / n) else 0
		local z = z0 + (i - 0.5) * stepD
		local ledge = solid("Rock", Vector3.new(W * rng:NextNumber(0.9, 1.05), top + 0.6, stepD * 1.08),
			CFrame.new(rng:NextNumber(-0.3, 0.3), (top + 0.6) / 2 - 0.6, z) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), 0),
			shade(rng, ROCK, 0.06), mat, m)
		first = first or ledge
		local side = if rng:NextNumber() < 0.5 then 1 else -1
		local bs = Vector3.new(rng:NextNumber(2.5, 3.5), top * 0.35 + rng:NextNumber(1.5, 2.5), rng:NextNumber(2.5, 3.5))
		solid("Rock", bs, CFrame.new(side * W * 0.42, top + bs.Y * 0.3, z + rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, TAU), rng:NextNumber(-0.2, 0.2)),
			shade(rng, ROCK, 0.08), mat, m)
		local drop = top - nextTop + 0.4
		local sheet = block("Water", Vector3.new(waterW, drop, 0.25), CFrame.new(0, nextTop + drop / 2 - 0.2, z + stepD * 0.54 + 0.15), WATER, M.Glass, m)
		sheet.Transparency = 0.35
		sheet.CastShadow = false
	end
	local zEnd = z0 + n * stepD
	local pool = block("PoolRim", Vector3.new(W * 0.9, 0.5, 3), CFrame.new(0, 0.1, zEnd + 3.2), shade(rng, ROCK, 0.08), mat, m)
	pool.CastShadow = false
	local mistPart = block("Mist", Vector3.new(waterW, 0.2, 1), CFrame.new(0, 0.3, zEnd + 1), WATER, M.SmoothPlastic, m)
	mistPart.Transparency = 1
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Mist"
	pe.Rate = 14
	pe.Lifetime = NumberRange.new(1.5, 2.8)
	pe.Speed = NumberRange.new(1.5, 3.5)
	pe.SpreadAngle = Vector2.new(50, 50)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Acceleration = Vector3.new(0, 0.8, 0)
	pe.Drag = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	pe.LightEmission = 0.2
	pe.Parent = mistPart
	return finish(m, first, cf, parent)
end

--- Decorative tree builder names (all take `(cf, rng, scale?, parent)`), for random picking.
Flora.DecorKinds = { "Pine", "Spruce", "Oak", "Birch", "Aspen" }

return Flora
