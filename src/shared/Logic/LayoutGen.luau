--!strict
-- Procedural forest layout, pure Luau (tested by tests/LayoutGen.spec.luau).
--
-- Fairness: one quarter "wedge" (the north sector, around camp 1) is generated
-- from the match seed and then rotated 90/180/270 degrees for the other three
-- camps, so every clan gets an identical set of paths, resources, landmarks and
-- crate spots. It is still a different forest every match.
-- The shared centre (clearing + stone circle + ring creek) is symmetric by construction.
--
-- Survival Wars layers (all per wedge, then rotated):
--   Landmarks  cliff rim on the outer flanks, a cave dug into one flank, a
--              waterfall + pool on the other, campsite, cabin and abandoned
--              house (chests), joined to the camp by narrow trails.
--   Upper      decorative canopy trees, denser in noise-driven thickets, with
--              open clearings; a couple of giant landmark trees.
--   Middle     fallen logs, boulders, dead snags, stumps, roots.
--   Low        bushes, ferns, saplings, tall grass (clustered under trees).
--   Ground     flowers, mushrooms, leaf litter, moss, pebbles, twigs.
--   Resources  placed from shared/Resources (counts, near-camp guarantees,
--              centre-distance bands: bigger trees/mushrooms sit deeper).
--
-- Validation: a 4-stud occupancy grid is flood-filled from each camp. Every camp,
-- the centre, every resource node, crate spot, landmark, drop point and water
-- point must be reachable, and nothing solid may sit in camps, the centre
-- clearing, or path corridors. If a seed fails validation, the next seed is tried.

local Rng = require("./Rng")
local Resources = require("../Resources")

export type P = { X: number, Z: number }
export type Layout = {
	Seed: number,
	HalfSize: number,
	Camps: { { X: number, Z: number, Team: number, Facing: number } },
	Paths: { { Points: { P }, Width: number, Kind: string? } },
	Streams: { { Points: { P }, Width: number, Depth: number } },
	Trees: { { X: number, Z: number, Scale: number, Kind: string, R: number } },
	Rocks: { { X: number, Z: number, Scale: number, R: number, Rot: number } },
	Bushes: { { X: number, Z: number, Scale: number } },
	Middle: { { X: number, Z: number, Kind: string, Rot: number, Scale: number } },
	Undergrowth: { { X: number, Z: number, Kind: string, Rot: number, Scale: number } },
	GroundCover: { { X: number, Z: number, Kind: string, Rot: number } },
	Cliffs: { { X: number, Z: number, Rot: number, W: number, H: number } },
	Features: { { Type: string, X: number, Z: number, R: number, Rot: number, Sector: number } },
	Brush: { { X: number, Z: number, R: number } },
	Nodes: { { Type: string, X: number, Z: number, Sector: number, Species: string? } },
	CrateSpots: { { X: number, Z: number, Sector: number } },
	DropPoints: { P },
	WaterPoints: { { X: number, Z: number, Sector: number } },
	Stones: { { X: number, Z: number, Rot: number } },
	Params: { [string]: number },
}

local LayoutGen = {}

LayoutGen.HalfSize = 500
LayoutGen.CampDistance = 400
LayoutGen.CampClear = 64 -- nothing solid inside this radius of a fire (build zone 55)
LayoutGen.CenterClear = 72
LayoutGen.RingStreamRadius = 108
LayoutGen.PathWidth = 14
LayoutGen.TrailWidth = 7
LayoutGen.GridStep = 4

-- Cliff rim on the outer flanks (wedge frame: distance outward = -z, flank = |x|).
LayoutGen.RimStart = 452
LayoutGen.RimWidth = 20
LayoutGen.RimFlank = 130
LayoutGen.RimHeight = 26

LayoutGen.CrateSpotsPerSector = 12
LayoutGen.TreesPerSector = 300 -- decorative canopy trees (attempts are density-filtered)
LayoutGen.MiddlePerSector = 90
LayoutGen.UndergrowthPerSector = 420
LayoutGen.GroundCoverPerSector = 380

-- Landmarks / POIs: type -> footprint radius.
LayoutGen.LandmarkRadius = {
	-- common
	Campsite = 13, Shed = 10, HuntingBlind = 9, BrokenVehicle = 11, SmallCabin = 13,
	-- uncommon
	Cabin = 15, RangerStation = 16, LoggingCamp = 17, AbandonedHouse = 17, MineEntrance = 14,
	-- rare
	Bunker = 15, Outpost = 18, IndustrialSite = 20, LargeMine = 16,
	-- cliff features
	Cave = 16, Waterfall = 14,
}

-- POI pools by rarity (spec: common / uncommon / rare). One near, one mid and one
-- far slot per wedge; the far slot rolls rare (RareChance) before falling back.
LayoutGen.PoiPools = {
	Common = { "Campsite", "Shed", "HuntingBlind", "BrokenVehicle", "SmallCabin" },
	Uncommon = { "Cabin", "RangerStation", "LoggingCamp", "AbandonedHouse", "MineEntrance" },
	Rare = { "Bunker", "Outpost", "IndustrialSite", "LargeMine" },
}
LayoutGen.RareChance = 0.3
-- Cave sizes (spec: small 0-1 chest stone/coal; medium 1-2 chests iron/coal + predators;
-- large rare, multiple chambers, 2-4 chests, rare deposits).
LayoutGen.CaveSizes = { { Name = "Small", Weight = 0.55 }, { Name = "Medium", Weight = 0.35 }, { Name = "Large", Weight = 0.10 } }
LayoutGen.CaveLength = { Small = 22, Medium = 34, Large = 42 }

-- Chest tiers per POI (min, max, tier weights). Best chests are one-time per match.
type ChestSpec = { Min: number, Max: number, Weights: { [string]: number } }
local POI_CHESTS: { [string]: ChestSpec } = {
	Common = { Min = 1, Max = 1, Weights = { Common = 7, Uncommon = 3 } },
	Uncommon = { Min = 1, Max = 2, Weights = { Uncommon = 7, Rare = 2.5, Common = 0.5 } },
	Rare = { Min = 2, Max = 3, Weights = { Rare = 6, VeryRare = 2.5, Uncommon = 1.5 } },
	CaveSmall = { Min = 0, Max = 1, Weights = { Common = 6, Uncommon = 4 } },
	CaveMedium = { Min = 1, Max = 2, Weights = { Uncommon = 6, Rare = 4 } },
	CaveLarge = { Min = 2, Max = 4, Weights = { Rare = 6, VeryRare = 4 } },
}

-- Extra resource nodes at POIs, as local offsets (x, z) in the landmark's frame.
type NodeSpot = { Type: string, X: number, Z: number }
local function spot(t: string, x: number, z: number): NodeSpot
	return { Type = t, X = x, Z = z }
end
local POI_NODES: { [string]: { NodeSpot } } = {
	BrokenVehicle = { spot("ScrapPile", 5, 3), spot("ScrapPile", -5, -2) },
	LoggingCamp = { spot("ScrapPile", 8, 6) },
	MineEntrance = { spot("IronDeposit", 6, 4), spot("CoalDeposit", -6, 4) },
	Bunker = { spot("ScrapPile", 8, -6), spot("ScrapPile", -8, -6) },
	Outpost = { spot("ScrapPile", 10, 8) },
	IndustrialSite = { spot("ScrapPile", 9, 6), spot("ScrapPile", -9, 6), spot("ScrapPile", 0, -10) },
	LargeMine = { spot("IronDeposit", 7, 5), spot("IronDeposit", -7, 5), spot("CoalDeposit", 0, 9), spot("RichIronDeposit", 0, -8) },
}
-- Cave nodes by size: X across the tunnel, Z = depth fraction (local +Z = into the cliff).
local CAVE_NODES: { [string]: { NodeSpot } } = {
	Small = { spot("LargeRockPile", 2.5, 0.5), spot("CoalDeposit", -2.5, 0.85) },
	Medium = { spot("CoalDeposit", 3, 0.4), spot("IronDeposit", -3, 0.7), spot("IronDeposit", 3, 0.95) },
	Large = { spot("CoalDeposit", 3, 0.3), spot("IronDeposit", -3, 0.55), spot("IronDeposit", 5, 0.95), spot("RichIronDeposit", -5, 1.0) },
}
LayoutGen.PoiNodes = POI_NODES
LayoutGen.CaveNodes = CAVE_NODES

-- Roblox CFrame.Angles(0, rot, 0) applied to a local (x, z) offset.
local function localToWorld(x: number, z: number, rotDeg: number, lx: number, lz: number): (number, number)
	local t = math.rad(rotDeg)
	return x + lx * math.cos(t) + lz * math.sin(t), z - lx * math.sin(t) + lz * math.cos(t)
end
LayoutGen.LocalToWorld = localToWorld

local FEATURE_POOL = { "Glade", "RockOutcrop", "Ruins", "Pond", "Thicket", "FallenGiant" }
local FEATURE_RADIUS = { Glade = 26, RockOutcrop = 16, Ruins = 20, Pond = 15, Thicket = 18, FallenGiant = 14 }
-- Features whose footprint blocks movement (validated against the grid)
local FEATURE_SOLID = { RockOutcrop = true, Ruins = false, FallenGiant = false, Pond = false, Glade = false, Thicket = false }

local TREE_KINDS = {
	-- kind, weight in the damp outer forest, weight in the brighter inner forest
	{ "Pine", 5, 2 },
	{ "Spruce", 4, 1 },
	{ "Oak", 1, 4 },
	{ "Birch", 1, 3 },
	{ "Aspen", 1, 3 },
	{ "DeadSnag", 1, 0.6 },
}
local MIDDLE_KINDS = { { "FallenLog", 4 }, { "Boulder", 4 }, { "Stump", 3 }, { "Roots", 2 }, { "DeadSnag", 1 } }
local MIDDLE_SOLID = { FallenLog = 2.2, Boulder = 3, DeadSnag = 1.2 } -- blocker radius (scaled)
local LOW_KINDS = { { "Fern", 5 }, { "Bush", 5 }, { "TallGrass", 4 }, { "Sapling", 2 } }
local GROUND_KINDS = { { "LeafLitter", 5 }, { "FlowerPatch", 3 }, { "Mushrooms", 2 }, { "MossPatch", 3 }, { "Pebbles", 2 }, { "Twigs", 2 } }

-- Geometry helpers -------------------------------------------------------------------

local function rotate(x: number, z: number, k: number): (number, number)
	-- k quarter turns: north (0,-400) -> east (400,0) -> south -> west
	for _ = 1, k % 4 do
		x, z = -z, x
	end
	return x, z
end
LayoutGen.Rotate = rotate

local function inWedge(x: number, z: number): boolean
	return z < 0 and math.abs(x) <= -z
end

local function distPointSeg(px: number, pz: number, a: P, b: P): number
	local dx, dz = b.X - a.X, b.Z - a.Z
	local len2 = dx * dx + dz * dz
	local t = 0
	if len2 > 0 then
		t = math.clamp(((px - a.X) * dx + (pz - a.Z) * dz) / len2, 0, 1)
	end
	local cx, cz = a.X + dx * t, a.Z + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

local function distToPolyline(px: number, pz: number, pts: { P }): number
	local best = math.huge
	for i = 1, #pts - 1 do
		best = math.min(best, distPointSeg(px, pz, pts[i], pts[i + 1]))
	end
	return best
end
LayoutGen.DistToPolyline = distToPolyline

-- Sector index (1..4) of a world point: nearest camp by angle.
function LayoutGen.SectorOf(x: number, z: number): number
	if math.abs(x) <= -z then
		return 1
	elseif x >= math.abs(z) then
		return 2
	elseif z >= math.abs(x) then
		return 3
	end
	return 4
end

-- Rotates a world point into the north wedge frame.
local function toWedge(x: number, z: number): (number, number)
	for k = 0, 3 do
		local rx, rz = rotate(x, z, (4 - k) % 4)
		if inWedge(rx, rz) then
			return rx, rz
		end
	end
	return x, z
end

-- Terrain height ---------------------------------------------------------------------

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0..1 cliff-rim factor in the wedge frame (1 = on top of the rim).
local function rimW(wx: number, wz: number): number
	return smoothstep(LayoutGen.RimStart, LayoutGen.RimStart + LayoutGen.RimWidth, -wz)
		* smoothstep(LayoutGen.RimFlank, LayoutGen.RimFlank + 60, math.abs(wx))
end

function LayoutGen.RimFactor(x: number, z: number): number
	local wx, wz = toWedge(x, z)
	return rimW(wx, wz)
end

-- Height is symmetric under quarter rotation because noise is sampled in the
-- north wedge frame (and mirrored in x so wedge borders match).
function LayoutGen.Height(layout: Layout, x: number, z: number): number
	local base = layout.Params.BaseHeight
	local amp = layout.Params.HillAmplitude
	local wx, wz = toWedge(x, z)
	local seedOff = layout.Params.NoiseOffset
	local n = math.noise(math.abs(wx) / 140 + seedOff, wz / 140, 0.37) * 0.7
		+ math.noise(math.abs(wx) / 55 + seedOff, wz / 55, 1.91) * 0.3
	local h = base + n * amp
	-- flatten camps, centre
	local flat = 0
	local dCamp = math.sqrt(wx * wx + (wz + LayoutGen.CampDistance) ^ 2)
	flat = math.max(flat, 1 - smoothstep(LayoutGen.CampClear, LayoutGen.CampClear + 30, dCamp))
	local dCenter = math.sqrt(x * x + z * z)
	flat = math.max(flat, 1 - smoothstep(LayoutGen.CenterClear, LayoutGen.CenterClear + 30, dCenter))
	h = h * (1 - flat) + base * flat
	-- cliff rim (outer flanks only; never near camps)
	h += rimW(wx, wz) * (LayoutGen.RimHeight + math.noise(math.abs(wx) / 30 + seedOff, 4.2, wz / 30) * 4)
	return h
end

-- Forest density (0 = clearing, 1 = thicket), symmetric like the height.
function LayoutGen.Density(layout: Layout, x: number, z: number): number
	local wx, wz = toWedge(x, z)
	local o = layout.Params.NoiseOffset
	local n = math.noise(math.abs(wx) / 90 + o * 0.7, wz / 90, 7.7) * 0.75 + math.noise(math.abs(wx) / 33 + o, wz / 33, 3.3) * 0.25
	return math.clamp(0.55 + n * 1.3, 0, 1)
end

-- Spatial hash of occupied discs -------------------------------------------------------

type Blocker = { X: number, Z: number, R: number }
type Grid = { Cells: { [number]: { Blocker } }, Size: number, MaxR: number }

local function gridNew(size: number): Grid
	return { Cells = {}, Size = size, MaxR = 0 }
end

local function gridKey(ix: number, iz: number): number
	return (ix + 4096) * 8192 + (iz + 4096)
end

local function gridAdd(g: Grid, b: Blocker)
	local k = gridKey(math.floor(b.X / g.Size), math.floor(b.Z / g.Size))
	local cell = g.Cells[k]
	if not cell then
		cell = {}
		g.Cells[k] = cell
	end
	table.insert(cell, b)
	if b.R > g.MaxR then
		g.MaxR = b.R
	end
end

local function gridFree(g: Grid, x: number, z: number, r: number): boolean
	local reach = r + g.MaxR
	local x0, x1 = math.floor((x - reach) / g.Size), math.floor((x + reach) / g.Size)
	local z0, z1 = math.floor((z - reach) / g.Size), math.floor((z + reach) / g.Size)
	for ix = x0, x1 do
		for iz = z0, z1 do
			local cell = g.Cells[gridKey(ix, iz)]
			if cell then
				for _, b in cell do
					if (b.X - x) ^ 2 + (b.Z - z) ^ 2 < (b.R + r) ^ 2 then
						return false
					end
				end
			end
		end
	end
	return true
end

-- Generation --------------------------------------------------------------------------

local function weighted(rng: Rng.Rng, list: { { any } }, col: number?): string
	local c = col or 2
	local total = 0
	for _, e in list do
		total += e[c] :: number
	end
	local pick = rng:Next() * total
	for _, e in list do
		pick -= e[c] :: number
		if pick < 0 then
			return e[1] :: string
		end
	end
	return list[#list][1] :: string
end

local function makeWedge(rng: Rng.Rng, params: { [string]: number })
	local H = LayoutGen.HalfSize
	local campZ = -LayoutGen.CampDistance
	local W = {
		Paths = {} :: { { Points: { P }, Width: number, Kind: string? } },
		Streams = {} :: { { Points: { P }, Width: number, Depth: number } },
		Trees = {} :: { any },
		Rocks = {} :: { any },
		Bushes = {} :: { any },
		Middle = {} :: { any },
		Undergrowth = {} :: { any },
		GroundCover = {} :: { any },
		Cliffs = {} :: { any },
		Features = {} :: { any },
		Brush = {} :: { any },
		Nodes = {} :: { any },
		CrateSpots = {} :: { any },
		DropPoints = {} :: { P },
		WaterPoints = {} :: { any },
		Blockers = {} :: { Blocker },
	}
	local fakeLayout = { Params = params } :: any

	-- Main path camp -> centre, with a per-match route variant.
	local variant = rng:Int(1, 3)
	local bend = (variant - 2) * rng:Range(50, 95) -- -95..95 lateral
	local main: { P } = { { X = 0, Z = campZ + 40 } }
	local steps = 7
	for i = 1, steps - 1 do
		local t = i / steps
		local z = (campZ + 40) + (-LayoutGen.CenterClear + 10 - (campZ + 40)) * t
		local x = bend * math.sin(t * math.pi) + rng:Range(-10, 10) * math.sin(t * math.pi)
		x = math.clamp(x, -(-z) + 20, -z - 20)
		table.insert(main, { X = x, Z = z })
	end
	table.insert(main, { X = 0, Z = -LayoutGen.CenterClear + 10 })
	table.insert(W.Paths, { Points = main, Width = LayoutGen.PathWidth, Kind = "Road" })

	-- Ring path connecting neighbouring camps' routes (arc between -135 and -45 degrees).
	local ringR = rng:Range(235, 290)
	params.RingRadius = ringR
	local arc: { P } = {}
	for i = 0, 12 do
		local a = math.rad(-135 + 90 * i / 12)
		local wob = if i == 0 or i == 12 then 0 else rng:Range(-12, 12)
		table.insert(arc, { X = math.cos(a) * (ringR + wob), Z = math.sin(a) * (ringR + wob) })
	end
	table.insert(W.Paths, { Points = arc, Width = LayoutGen.PathWidth - 2, Kind = "Road" })

	-- Camp creek (every camp has its own refill point), behind the camp.
	local creekZ = campZ - rng:Range(62, 70)
	local creek: { P } = {}
	for i = 0, 8 do
		local x = -90 + 180 * i / 8
		table.insert(creek, { X = x, Z = creekZ + math.sin(i * 0.9 + params.NoiseOffset) * 5 })
	end
	table.insert(W.Streams, { Points = creek, Width = 9, Depth = 3 })
	table.insert(W.WaterPoints, { X = 0, Z = creekZ })
	table.insert(W.WaterPoints, { X = -60, Z = creekZ })
	table.insert(W.WaterPoints, { X = 60, Z = creekZ })

	-- Ring creek around the centre (shallow, walkable).
	local ring: { P } = {}
	for i = 0, 10 do
		local a = math.rad(-135 + 90 * i / 10)
		table.insert(ring, { X = math.cos(a) * LayoutGen.RingStreamRadius, Z = math.sin(a) * LayoutGen.RingStreamRadius })
	end
	table.insert(W.Streams, { Points = ring, Width = 10, Depth = 2.5 })
	for _, deg in { -115, -65 } do
		local a = math.rad(deg)
		table.insert(W.WaterPoints, { X = math.cos(a) * LayoutGen.RingStreamRadius, Z = math.sin(a) * LayoutGen.RingStreamRadius })
	end

	-- Clearance helpers
	local function nearPath(x: number, z: number, margin: number): boolean
		for _, p in W.Paths do
			if distToPolyline(x, z, p.Points) < p.Width / 2 + margin then
				return true
			end
		end
		return false
	end
	local function nearStream(x: number, z: number, margin: number): boolean
		for _, s in W.Streams do
			if distToPolyline(x, z, s.Points) < s.Width / 2 + margin then
				return true
			end
		end
		return false
	end
	local function campDist(x: number, z: number): number
		return math.sqrt(x * x + (z - campZ) ^ 2)
	end
	local function inBounds(x: number, z: number, margin: number): boolean
		-- Keep a margin from wedge borders so rotated copies don't collide.
		return inWedge(x, z) and math.abs(x) <= -z - margin and -z <= H - margin
	end
	local function offRim(x: number, z: number, r: number): boolean
		-- r studs of flat ground before the cliff starts
		return rimW(x, z - r) < 0.02 and rimW(x + r, z) < 0.02 and rimW(x - r, z) < 0.02
	end
	local taken = gridNew(24)
	local function free(x: number, z: number, r: number): boolean
		return gridFree(taken, x, z, r)
	end
	local function take(x: number, z: number, r: number)
		gridAdd(taken, { X = x, Z = z, R = r })
	end
	local function clearOfCore(x: number, z: number, r: number): boolean
		return campDist(x, z) > LayoutGen.CampClear + r and math.sqrt(x * x + z * z) > LayoutGen.CenterClear + r
	end
	local function spotOk(x: number, z: number, r: number, pathMargin: number): boolean
		return inBounds(x, z, r) and clearOfCore(x, z, r) and offRim(x, z, r) and not nearPath(x, z, r + pathMargin)
			and not nearStream(x, z, r + 1) and free(x, z, r)
	end
	-- Narrow trail from the camp's front edge to a landmark (wobbly polyline).
	local function trail(tx: number, tz: number, stopShort: number)
		local sx, sz = 0, campZ + LayoutGen.CampClear - 6
		local dx, dz = tx - sx, tz - sz
		local len = math.sqrt(dx * dx + dz * dz)
		local ex, ez = tx - dx / len * stopShort, tz - dz / len * stopShort
		local pts: { P } = { { X = sx, Z = sz } }
		local segs = math.max(3, math.floor(len / 45))
		for i = 1, segs - 1 do
			local t = i / segs
			local wob = math.sin(t * math.pi) * rng:Range(-14, 14)
			table.insert(pts, { X = sx + (ex - sx) * t + (-dz / len) * wob, Z = sz + (ez - sz) * t + (dx / len) * wob })
		end
		table.insert(pts, { X = ex, Z = ez })
		table.insert(W.Paths, { Points = pts, Width = LayoutGen.TrailWidth, Kind = "Trail" })
	end
	local function rollChests(key: string): { string }
		local spec = POI_CHESTS[key]
		local out = {}
		if not spec then
			return out
		end
		local n = rng:Int(spec.Min, spec.Max)
		local weights = spec.Weights
		local names = {}
		local total = 0
		for name, w in weights do
			table.insert(names, name)
			total += w
		end
		table.sort(names)
		for _ = 1, n do
			local x = rng:Next() * total
			for _, name in names do
				x -= weights[name]
				if x <= 0 then
					table.insert(out, name)
					break
				end
			end
		end
		return out
	end
	local function addLandmark(ftype: string, x: number, z: number, rot: number, extra: { [string]: any }?): { [string]: any }
		local r = LayoutGen.LandmarkRadius[ftype]
		local f: { [string]: any } = { Type = ftype, X = x, Z = z, R = r, Rot = rot, Sector = 1 }
		if extra then
			for k, v in extra do
				f[k] = v
			end
		end
		table.insert(W.Features, f)
		take(x, z, r)
		return f
	end
	local function addPoiNodes(f: { [string]: any })
		local list = POI_NODES[f.Type]
		if not list then
			return
		end
		for _, nd in list do
			local nx, nz = localToWorld(f.X, f.Z, f.Rot, nd.X, nd.Z)
			table.insert(W.Nodes, { Type = nd.Type, X = nx, Z = nz, Sector = 1, Poi = f.Type })
		end
	end

	-- Cliff-side landmarks (same flank every wedge, so rotation keeps fairness).
	local caveSide = if rng:Next() < 0.5 then 1 else -1
	do
		-- Cave: mouth at the foot of the rim, tunnel dug outward (-z).
		local cx = caveSide * rng:Range(250, 320)
		local cz = -(LayoutGen.RimStart - 3)
		local roll, size = rng:Next(), "Small"
		for _, cs in LayoutGen.CaveSizes do
			roll -= cs.Weight
			if roll <= 0 then
				size = cs.Name
				break
			end
		end
		local cave = addLandmark("Cave", cx, cz, 180, { Size = size, Tier = if size == "Large" then "Rare" elseif size == "Medium" then "Uncommon" else "Common", Chests = rollChests("Cave" .. size), Length = LayoutGen.CaveLength[size] })
		for _, nd in CAVE_NODES[size] do
			local nx, nz = localToWorld(cx, cz, cave.Rot, nd.X, nd.Z * (cave.Length - 4))
			table.insert(W.Nodes, { Type = nd.Type, X = nx, Z = nz, Sector = 1, Poi = "Cave", InCave = true })
		end
		table.insert(W.Blockers, { X = cx - 11, Z = cz - 4, R = 4 })
		table.insert(W.Blockers, { X = cx + 11, Z = cz - 4, R = 4 })
		trail(cx, cz + 8, 10)
	end
	do
		-- Waterfall down the opposite cliff into a pool (a canteen refill point).
		local wx = -caveSide * rng:Range(240, 330)
		local wz = -(LayoutGen.RimStart + LayoutGen.RimWidth * 0.45)
		addLandmark("Waterfall", wx, wz, 0)
		local pr = FEATURE_RADIUS.Pond
		table.insert(W.Features, { Type = "Pond", X = wx, Z = wz + pr + 6, R = pr, Rot = 0, Sector = 1 })
		take(wx, wz + pr + 6, pr)
		table.insert(W.WaterPoints, { X = wx + pr * 0.6, Z = wz + pr + 6 + pr * 0.55 })
		-- the stream the waterfall feeds, winding back toward the forest
		local st: { P } = {}
		for i = 0, 5 do
			local t = i / 5
			table.insert(st, { X = wx + math.sin(t * 3 + params.NoiseOffset) * 10 * t, Z = wz + pr * 2 + 6 + t * 70 })
		end
		table.insert(W.Streams, { Points = st, Width = 6, Depth = 1.8 })
	end

	-- Inland landmarks: campsite (near), cabin (mid), abandoned house (far, toward a sector border).
	local function placeLandmark(ftype: string, tier: string, dMin: number, dMax: number, aMin: number, aMax: number): boolean
		local r = LayoutGen.LandmarkRadius[ftype]
		for _ = 1, 200 do
			local a = math.rad(rng:Range(aMin, aMax))
			local d = rng:Range(dMin, dMax)
			local x, z = math.sin(a) * d, campZ + math.cos(a) * d
			if spotOk(x, z, r + 6, 4) then
				-- face the camp: local +Z points back along the trail
				local rot = math.deg(math.atan2(-x, campZ - z))
				local f = addLandmark(ftype, x, z, rot, { Tier = tier, Chests = rollChests(tier) })
				addPoiNodes(f)
				trail(x, z, r + 2)
				return true
			end
		end
		return false
	end
	local function pickPoi(pool: { string }): string
		return pool[rng:Int(1, #pool)]
	end
	-- Semi-random POIs by rarity: near = common, mid = uncommon, far = rare (sometimes).
	placeLandmark(pickPoi(LayoutGen.PoiPools.Common), "Common", 120, 175, -70, 70)
	placeLandmark(pickPoi(LayoutGen.PoiPools.Uncommon), "Uncommon", 185, 250, -80, 80)
	if rng:Next() < LayoutGen.RareChance then
		placeLandmark(pickPoi(LayoutGen.PoiPools.Rare), "Rare", 250, 320, -75, 75)
	else
		placeLandmark(pickPoi(LayoutGen.PoiPools.Uncommon), "Uncommon", 250, 320, -75, 75)
	end

	-- Classic features (2-3 per wedge, chosen per match).
	local pool = table.clone(FEATURE_POOL)
	rng:Shuffle(pool)
	local featureCount = rng:Int(2, 3)
	-- Glade is always included once so each sector has a care-package drop point.
	if not table.find({ table.unpack(pool, 1, featureCount) }, "Glade") then
		pool[1] = "Glade"
	end
	for i = 1, featureCount do
		local ftype = pool[i]
		local r = FEATURE_RADIUS[ftype]
		for _ = 1, 80 do
			local x = rng:Range(-300, 300)
			local z = rng:Range(-H + 40, -150)
			if inBounds(x, z, r + 10) and clearOfCore(x, z, r + 20) and offRim(x, z, r + 6) and not nearPath(x, z, r + 4)
				and not nearStream(x, z, r + 4) and free(x, z, r + 8) then
				table.insert(W.Features, { Type = ftype, X = x, Z = z, R = r, Rot = rng:Range(0, 360), Sector = 1 })
				take(x, z, r)
				if FEATURE_SOLID[ftype] then
					table.insert(W.Blockers, { X = x, Z = z, R = r * 0.8 })
				end
				if ftype == "Glade" then
					table.insert(W.DropPoints, { X = x, Z = z })
				elseif ftype == "Pond" then
					table.insert(W.WaterPoints, { X = x + r + 2, Z = z })
				elseif ftype == "Thicket" then
					table.insert(W.Brush, { X = x, Z = z, R = r })
				elseif ftype == "Ruins" then
					table.insert(W.Blockers, { X = x + 7, Z = z, R = 3 })
					table.insert(W.Blockers, { X = x - 7, Z = z, R = 3 })
				elseif ftype == "FallenGiant" then
					table.insert(W.Blockers, { X = x, Z = z, R = 3 })
				end
				break
			end
		end
	end

	-- Extra brush patches (slow movement slightly; Trailblazer ignores).
	for _ = 1, 3 do
		for _ = 1, 30 do
			local x, z = rng:Range(-300, 300), rng:Range(-H + 30, -130)
			local r = rng:Range(9, 14)
			if inBounds(x, z, r) and clearOfCore(x, z, r + 10) and offRim(x, z, r) and not nearPath(x, z, r) and free(x, z, r) then
				table.insert(W.Brush, { X = x, Z = z, R = r })
				take(x, z, r)
				break
			end
		end
	end

	-- Cliff faces: jagged rock walls along the rim's inner edge.
	for side = -1, 1, 2 do
		local x = LayoutGen.RimFlank + 50
		while x < H - 10 do
			local w = rng:Range(16, 26)
			local cx = side * (x + w / 2)
			local cz = -(LayoutGen.RimStart + LayoutGen.RimWidth * 0.35)
			if inWedge(cx, cz) and math.abs(cx) <= -cz - 6 then
				local skip = false
				for _, f in W.Features do
					if (f.Type == "Cave" or f.Type == "Waterfall") and math.abs(f.X - cx) < f.R + w / 2 then
						skip = true
					end
				end
				if not skip then
					table.insert(W.Cliffs, { X = cx, Z = cz + rng:Range(-2, 2), Rot = rng:Range(-8, 8), W = w, H = LayoutGen.RimHeight * rng:Range(0.8, 1.05) })
				end
			end
			x += w * 0.85
		end
	end

	-- Resource nodes from shared/Resources: near-camp guarantees, then the wedge.
	local function kindWeight(x: number, z: number): number
		-- 0 = damp outer (pines), 1 = bright inner forest (broadleaf)
		local d = math.sqrt(x * x + z * z)
		return math.clamp((LayoutGen.CampDistance + 40 - d) / 300 + math.noise(x / 80, z / 80, params.NoiseOffset) * 0.4, 0, 1)
	end
	for _, id in Resources.Order do
		local def = Resources.Defs[id]
		local pl = def.Placement
		local placed, attempts = 0, 0
		local minC, maxC = pl.MinCenterDist or 0, pl.MaxCenterDist or math.huge
		while placed < pl.PerSector and attempts < pl.PerSector * 120 do
			attempts += 1
			local near = placed < pl.NearCamp
			local x, z
			if near then
				local a = rng:Range(math.rad(-160), math.rad(-20))
				local d = rng:Range(LayoutGen.CampClear + 4, 130)
				x, z = math.cos(a) * d, campZ - math.sin(a) * d
			else
				x, z = rng:Range(-360, 360), rng:Range(-H + 25, -60)
			end
			local dc = math.sqrt(x * x + z * z)
			local r = pl.Radius
			if (near or (dc >= minC and dc <= maxC)) and spotOk(x, z, r + 1.5, 1) then
				local species: string? = nil
				if def.Kind == "Tree" and def.Model == "ResourceTree" then
					local inner = kindWeight(x, z)
					local roll = rng:Next()
					species = if roll < 0.55 - inner * 0.35 then "Pine" elseif roll < 0.8 then "Oak" else "Birch"
				end
				table.insert(W.Nodes, { Type = id, X = x, Z = z, Sector = 1, Species = species })
				take(x, z, r)
				if def.Kind == "Tree" then
					table.insert(W.Blockers, { X = x, Z = z, R = r * 0.35 })
				end
				placed += 1
			end
		end
	end

	-- Crate spots (hidden, off-path).
	do
		local placed, attempts = 0, 0
		while placed < LayoutGen.CrateSpotsPerSector and attempts < 2000 do
			attempts += 1
			local x, z = rng:Range(-340, 340), rng:Range(-H + 25, -90)
			if inBounds(x, z, 4) and clearOfCore(x, z, 20) and offRim(x, z, 4) and not nearPath(x, z, 6)
				and not nearStream(x, z, 3) and free(x, z, 4) then
				table.insert(W.CrateSpots, { X = x, Z = z, Sector = 1 })
				take(x, z, 3)
				placed += 1
			end
		end
	end

	-- Big rocks (obstacles).
	for _ = 1, 10 do
		for _ = 1, 30 do
			local x, z = rng:Range(-420, 420), rng:Range(-H + 12, -90)
			local s = rng:Range(0.8, 1.8)
			local r = 4 * s
			if spotOk(x, z, r, 2) then
				table.insert(W.Rocks, { X = x, Z = z, Scale = s, R = r, Rot = rng:Range(0, 360) })
				take(x, z, r)
				table.insert(W.Blockers, { X = x, Z = z, R = r })
				break
			end
		end
	end

	-- Giant landmark trees (1-2 per wedge).
	for _ = 1, rng:Int(1, 2) do
		for _ = 1, 60 do
			local x, z = rng:Range(-320, 320), rng:Range(-H + 60, -170)
			if spotOk(x, z, 9, 4) then
				table.insert(W.Trees, { X = x, Z = z, Scale = rng:Range(0.9, 1.15), Kind = "GiantTree", R = 5 })
				take(x, z, 9)
				table.insert(W.Blockers, { X = x, Z = z, R = 3.5 })
				break
			end
		end
	end

	-- Upper layer: canopy trees, filtered by forest density (thickets vs clearings).
	local trees, attempts = 0, 0
	while trees < LayoutGen.TreesPerSector and attempts < LayoutGen.TreesPerSector * 30 do
		attempts += 1
		local x, z = rng:Range(-H, H), rng:Range(-H + 4, -40)
		local dens = LayoutGen.Density(fakeLayout, x, z)
		if rng:Next() < dens * dens then
			local s = rng:Range(0.8, 1.4)
			local r = 2 * s
			-- denser stands allow tighter spacing
			local spacing = 7 - dens * 3.5
			if inBounds(x, z, 3) and clearOfCore(x, z, 8) and offRim(x, z, 2) and not nearPath(x, z, 3)
				and not nearStream(x, z, 2) and free(x, z, r + spacing) then
				local inner = kindWeight(x, z)
				local kind = weighted(rng, TREE_KINDS, if rng:Next() < inner then 3 else 2)
				table.insert(W.Trees, { X = x, Z = z, Scale = s, Kind = kind, R = r })
				take(x, z, r)
				table.insert(W.Blockers, { X = x, Z = z, R = r * 0.5 })
				trees += 1
			end
		end
	end

	-- Middle layer: logs, boulders, stumps, roots, snags.
	local mid, mattempts = 0, 0
	while mid < LayoutGen.MiddlePerSector and mattempts < 4000 do
		mattempts += 1
		local x, z = rng:Range(-H, H), rng:Range(-H + 6, -60)
		local kind = weighted(rng, MIDDLE_KINDS)
		local s = rng:Range(0.8, 1.3)
		local solid = MIDDLE_SOLID[kind]
		local r = (solid or 1.5) * s
		if inBounds(x, z, r + 1) and clearOfCore(x, z, r + 4) and offRim(x, z, r) and not nearPath(x, z, r + 1.5)
			and not nearStream(x, z, r) and free(x, z, r + 1.5) then
			table.insert(W.Middle, { X = x, Z = z, Kind = kind, Rot = rng:Range(0, 360), Scale = s })
			take(x, z, r)
			if solid then
				table.insert(W.Blockers, { X = x, Z = z, R = r * 0.8 })
			end
			mid += 1
		end
	end

	-- Low layer: undergrowth clustered around trees for a layered look.
	local low, lattempts = 0, 0
	local treeList = W.Trees
	while low < LayoutGen.UndergrowthPerSector and lattempts < 6000 and #treeList > 0 do
		lattempts += 1
		local x, z
		if rng:Next() < 0.7 then
			local t = treeList[rng:Int(1, #treeList)]
			local a, d = rng:Range(0, math.pi * 2), rng:Range(2.5, 9)
			x, z = t.X + math.cos(a) * d, t.Z + math.sin(a) * d
		else
			x, z = rng:Range(-H, H), rng:Range(-H + 6, -50)
		end
		if inBounds(x, z, 1) and clearOfCore(x, z, 2) and offRim(x, z, 1) and not nearPath(x, z, 0.5) and not nearStream(x, z, 0.5) and free(x, z, 1) then
			table.insert(W.Undergrowth, { X = x, Z = z, Kind = weighted(rng, LOW_KINDS), Rot = rng:Range(0, 360), Scale = rng:Range(0.75, 1.3) })
			low += 1
		end
	end

	-- Ground layer: flowers in clearings, litter/mushrooms/moss under the canopy.
	local gc, gattempts = 0, 0
	while gc < LayoutGen.GroundCoverPerSector and gattempts < 6000 do
		gattempts += 1
		local x, z = rng:Range(-H, H), rng:Range(-H + 6, -50)
		if inBounds(x, z, 1) and clearOfCore(x, z, 1) and offRim(x, z, 0.5) and not nearPath(x, z, 0) and not nearStream(x, z, 0) and free(x, z, 0.8) then
			local dens = LayoutGen.Density(fakeLayout, x, z)
			local kind = if dens < 0.35 and rng:Next() < 0.6 then "FlowerPatch" else weighted(rng, GROUND_KINDS)
			table.insert(W.GroundCover, { X = x, Z = z, Kind = kind, Rot = rng:Range(0, 360) })
			gc += 1
		end
	end

	-- Legacy bush list kept empty (undergrowth replaces it).
	return W
end

local function rotateP(p: P, k: number): P
	local x, z = rotate(p.X, p.Z, k)
	return { X = x, Z = z }
end

local function rotateList(list: { any }, k: number, out: { any }, extra: ((any, any) -> ())?)
	for _, item in list do
		local c = table.clone(item)
		c.X, c.Z = rotate(item.X, item.Z, k)
		if c.Sector ~= nil then
			c.Sector = k + 1
		end
		if c.Rot ~= nil then
			-- rotate() turns positions by -90° about Y in Roblox's CFrame.Angles convention,
			-- so model yaws turn the same way (keeps landmark entrances facing their trails).
			c.Rot = (item.Rot - 90 * k) % 360
		end
		if extra then
			extra(item, c)
		end
		table.insert(out, c)
	end
end

function LayoutGen.GenerateRaw(seed: number): (Layout, { Blocker })
	local rng = Rng.new(seed)
	local params = {
		BaseHeight = 8,
		HillAmplitude = 7,
		NoiseOffset = rng:Range(0, 500),
	}
	local W = makeWedge(rng, params)

	local layout: Layout = {
		Seed = seed,
		HalfSize = LayoutGen.HalfSize,
		Camps = {},
		Paths = {},
		Streams = {},
		Trees = {},
		Rocks = {},
		Bushes = {},
		Middle = {},
		Undergrowth = {},
		GroundCover = {},
		Cliffs = {},
		Features = {},
		Brush = {},
		Nodes = {},
		CrateSpots = {},
		DropPoints = { { X = 0, Z = 0 } },
		WaterPoints = {},
		Stones = {},
		Params = params,
	}
	local blockers: { Blocker } = {}

	for k = 0, 3 do
		local cx, cz = rotate(0, -LayoutGen.CampDistance, k)
		-- Facing: yaw (degrees) pointing from the camp toward the centre.
		table.insert(layout.Camps, { X = cx, Z = cz, Team = k + 1, Facing = 90 * k })
		for _, path in W.Paths do
			local pts = {}
			for _, p in path.Points do
				table.insert(pts, rotateP(p, k))
			end
			table.insert(layout.Paths, { Points = pts, Width = path.Width, Kind = path.Kind })
		end
		for _, s in W.Streams do
			local pts = {}
			for _, p in s.Points do
				table.insert(pts, rotateP(p, k))
			end
			table.insert(layout.Streams, { Points = pts, Width = s.Width, Depth = s.Depth })
		end
		rotateList(W.Trees, k, layout.Trees)
		rotateList(W.Rocks, k, layout.Rocks)
		rotateList(W.Bushes, k, layout.Bushes)
		rotateList(W.Middle, k, layout.Middle)
		rotateList(W.Undergrowth, k, layout.Undergrowth)
		rotateList(W.GroundCover, k, layout.GroundCover)
		rotateList(W.Cliffs, k, layout.Cliffs)
		rotateList(W.Features, k, layout.Features)
		rotateList(W.Brush, k, layout.Brush)
		rotateList(W.Nodes, k, layout.Nodes)
		rotateList(W.CrateSpots, k, layout.CrateSpots)
		rotateList(W.WaterPoints, k, layout.WaterPoints, function(_, c)
			c.Sector = k + 1
		end)
		for _, d in W.DropPoints do
			table.insert(layout.DropPoints, rotateP(d, k))
		end
		rotateList(W.Blockers, k, blockers)
	end

	-- Centre: stone circle landmark (8 stones, symmetric), a few centre nodes.
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		table.insert(layout.Stones, { X = math.cos(a) * 44, Z = math.sin(a) * 44, Rot = i * 45 })
		table.insert(blockers, { X = math.cos(a) * 44, Z = math.sin(a) * 44, R = 2.5 })
	end
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		table.insert(layout.CrateSpots, { X = math.cos(a) * 62, Z = math.sin(a) * 62, Sector = 0 })
		table.insert(layout.Nodes, { Type = "RockPile", X = math.cos(a) * 30, Z = math.sin(a) * 30, Sector = 0 })
	end

	return layout, blockers
end

-- Flood-fill validation. Returns ok, problems.
function LayoutGen.Validate(layout: Layout, blockers: { Blocker }): (boolean, { string })
	local problems = {}
	local step = LayoutGen.GridStep
	local H = layout.HalfSize
	local n = math.floor(2 * H / step)
	local blocked: { [number]: boolean } = {}
	local function idx(ix: number, iz: number): number
		return iz * (n + 1) + ix
	end
	local function cell(x: number, z: number): (number, number)
		return math.clamp(math.floor((x + H) / step + 0.5), 0, n), math.clamp(math.floor((z + H) / step + 0.5), 0, n)
	end
	for _, b in blockers do
		local r = b.R + 1
		local x0, z0 = cell(b.X - r, b.Z - r)
		local x1, z1 = cell(b.X + r, b.Z + r)
		for iz = z0, z1 do
			for ix = x0, x1 do
				local wx, wz = ix * step - H, iz * step - H
				if (wx - b.X) ^ 2 + (wz - b.Z) ^ 2 <= r * r then
					blocked[idx(ix, iz)] = true
				end
			end
		end
	end

	-- Nothing solid in camps, centre, or path corridors.
	for _, b in blockers do
		for _, c in layout.Camps do
			if math.sqrt((b.X - c.X) ^ 2 + (b.Z - c.Z) ^ 2) < LayoutGen.CampClear then
				table.insert(problems, "blocker inside camp " .. c.Team)
			end
		end
		for _, p in layout.Paths do
			if distToPolyline(b.X, b.Z, p.Points) < p.Width / 2 then
				table.insert(problems, "blocker on path")
				break
			end
		end
	end

	-- Flood fill from camp 1.
	local seen: { [number]: boolean } = {}
	local sx, sz = cell(layout.Camps[1].X, layout.Camps[1].Z)
	local queue = { sx, sz }
	local head = 1
	seen[idx(sx, sz)] = true
	while head < #queue do
		local ix, iz = queue[head], queue[head + 1]
		head += 2
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, nz = ix + d[1], iz + d[2]
			if nx >= 0 and nz >= 0 and nx <= n and nz <= n then
				local id = idx(nx, nz)
				if not seen[id] and not blocked[id] then
					seen[id] = true
					table.insert(queue, nx)
					table.insert(queue, nz)
				end
			end
		end
	end
	local function reachable(x: number, z: number, radius: number): boolean
		-- a target counts as reachable if any free cell within `radius` is reached
		local x0, z0 = cell(x - radius, z - radius)
		local x1, z1 = cell(x + radius, z + radius)
		for iz = z0, z1 do
			for ix = x0, x1 do
				if seen[idx(ix, iz)] then
					return true
				end
			end
		end
		return false
	end
	for _, c in layout.Camps do
		if not reachable(c.X, c.Z, 4) then
			table.insert(problems, "camp unreachable " .. c.Team)
		end
	end
	if not reachable(0, 0, 4) then
		table.insert(problems, "centre unreachable")
	end
	for _, nd in layout.Nodes do
		if not reachable(nd.X, nd.Z, 6) then
			table.insert(problems, "node unreachable " .. nd.Type)
		end
	end
	for _, cs in layout.CrateSpots do
		if not reachable(cs.X, cs.Z, 6) then
			table.insert(problems, "crate spot unreachable")
		end
	end
	for _, f in layout.Features do
		if LayoutGen.LandmarkRadius[f.Type] and not reachable(f.X, f.Z, f.R + 4) then
			table.insert(problems, "landmark unreachable " .. f.Type)
		end
	end
	for _, dp in layout.DropPoints do
		if not reachable(dp.X, dp.Z, 6) then
			table.insert(problems, "drop point unreachable")
		end
	end
	for _, wp in layout.WaterPoints do
		if not reachable(wp.X, wp.Z, 8) then
			table.insert(problems, "water unreachable")
		end
	end
	return #problems == 0, problems
end

-- Generates a validated layout, trying successive seeds.
function LayoutGen.Generate(seed: number): Layout
	for attempt = 0, 20 do
		local layout, blockers = LayoutGen.GenerateRaw(seed + attempt * 7919)
		local ok = LayoutGen.Validate(layout, blockers)
		if ok then
			return layout
		end
	end
	error("LayoutGen: no valid layout found near seed " .. seed)
end

return LayoutGen
