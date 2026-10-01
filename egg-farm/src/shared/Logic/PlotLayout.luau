--!strict
-- Plot layout math: where every farm piece sits. PURE (plain {x, y, z} tables, no Roblox types),
-- so the CLI tests can check the layout invariants (tests/Plots.spec.luau). World.luau turns these
-- into CFrames.
--
-- Plot-local frame: origin at the plot centre on the ground (y = 0), +z points to the plot FRONT
-- (the boulevard and the entrance), -z to the back (dock, road, tunnel). x is left/right as seen
-- from the back looking at the front. A plot is PLOT_W (x) by PLOT_D (z) studs.
--
-- Collection route (front to back): spawn -> central path with the 4 collect rings on both
-- sides -> deposit ring at the warehouse door -> the dock behind the warehouse loads the vehicles,
-- which drive along the back road out of the plot into a tunnel in the hills.
--
-- World: 8 plots in two rows of 4 facing a central boulevard (along x) with the hub at the
-- origin. Plots 1-4 are the north row (world +z, rotated 180 degrees so their front faces the
-- boulevard), plots 5-8 the south row (world -z, not rotated).

export type Vec = { x: number, y: number, z: number }
export type Rect = { x0: number, z0: number, x1: number, z1: number } -- plot-local, x0 < x1, z0 < z1

export type House = {
	slot: number,
	side: number, -- -1 left column, +1 right column
	lot: Rect, -- the whole slot (pad)
	building: Vec, -- centre of the tier model footprint
	buildingMax: { w: number, d: number }, -- largest footprint a tier model may use: w across the facing, d along it
	facing: Vec, -- unit direction the building's door faces (towards the central path)
	anchor: Vec, -- centre of the flock yard
	anchorSize: { x: number, z: number }, -- yard extents (plot axes)
	ring: Vec,
	ringRadius: number,
	board: Vec,
}

export type Board = { name: string, menu: string, slot: number?, pos: Vec, look: Vec }

local V = function(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local PlotLayout = {}

PlotLayout.PlotCount = 8
PlotLayout.PLOT_W = 180
PlotLayout.PLOT_D = 220
PlotLayout.HALF_W = 90
PlotLayout.HALF_D = 110
PlotLayout.COLUMN_SPACING = 200 -- plot centres along x (20 stud gap between plots)
PlotLayout.ROW_Z = 150 -- |z| of each row's plot centre (front edges at |z| = 40)
PlotLayout.BOULEVARD_HALF = 40 -- boulevard spans |z| < 40
PlotLayout.RIDGE_LOCAL_Z = -130 -- plot-local z of the hill face holding the road tunnel
PlotLayout.RIDGE_DEPTH = 70

-- ---------------------------------------------------------------- houses
local HOUSE_X = 44
local HOUSE_Z = { 58, 0 } -- front row, back row
PlotLayout.RING_RADIUS = 7

local houses: { House } = {}
for slot = 1, 4 do
	local side = if slot % 2 == 1 then -1 else 1
	local cz = HOUSE_Z[if slot <= 2 then 1 else 2]
	local cx = side * HOUSE_X
	houses[slot] = {
		slot = slot,
		side = side,
		lot = { x0 = cx - 22, z0 = cz - 24, x1 = cx + 22, z1 = cz + 24 },
		building = V(side * 50, 0, cz - 2),
		buildingMax = { w = 34, d = 28 },
		facing = V(-side, 0, 0),
		anchor = V(side * 28.5, 0, cz),
		anchorSize = { x = 9, z = 36 },
		ring = V(side * 13, 0, cz),
		ringRadius = PlotLayout.RING_RADIUS,
		board = V(side * 20, 0, cz + 19),
	}
end
PlotLayout.Houses = houses

-- ---------------------------------------------------------------- warehouse, dock, road
PlotLayout.Warehouse = { center = V(0, 0, -54), w = 48, d = 26 }
PlotLayout.Deposit = { pos = V(0, 0, -31), radius = 8 }
PlotLayout.Dock = { center = V(0, 0, -73), w = 100, d = 6 }
PlotLayout.ROAD_Z = -101
PlotLayout.ROAD_WIDTH = 12
PlotLayout.ROAD_X = 80 -- the exit lane runs along x = 80 out of the back of the plot

local bays: { Vec } = {}
for i = 1, 8 do
	bays[i] = V(-42 + 12 * (i - 1), 0, -83)
end
PlotLayout.Bays = bays
PlotLayout.BayFacing = V(0, 0, -1) -- parked vehicles face the road (they back into the dock)
PlotLayout.BayWidth = 10

-- Ordered waypoints after a vehicle has pulled out of its bay onto the road.
PlotLayout.Road = {
	V(56, 0, -101),
	V(74, 0, -101),
	V(80, 0, -107),
	V(80, 0, -120),
	V(80, 0, -140), -- inside the hill tunnel from here on
	V(80, 0, -175),
}
PlotLayout.TunnelAt = 5 -- index of the first waypoint inside the hill (vehicles are hidden past it)

-- Road surface rectangles (asphalt).
PlotLayout.RoadRects = {
	{ x0 = -56, z0 = -107, x1 = 86, z1 = -95 },
	{ x0 = 74, z0 = -132, x1 = 86, z1 = -107 },
}

-- ---------------------------------------------------------------- workers, silos, shed
PlotLayout.WorkerStart = V(14, 0, -34)
PlotLayout.Shed = { center = V(78, 0, -38), w = 18, d = 16 }
PlotLayout.SiloCount = 10
PlotLayout.SiloRadius = 4
local silos: { Vec } = {}
for i = 1, 10 do
	silos[i] = V(-79, 0, -56 + 11 * (i - 1))
end
PlotLayout.Silos = silos

-- ---------------------------------------------------------------- front: spawn, gate, boards
PlotLayout.Spawn = V(0, 0, 92)
PlotLayout.Gate = { pos = V(0, 0, 108), width = 24 }

local boards: { Board } = {}
for _, h in houses do
	table.insert(boards, {
		name = "Housing" .. h.slot,
		menu = "Housing",
		slot = h.slot,
		pos = h.board,
		look = V(0, 0, h.board.z),
	})
end
table.insert(boards, { name = "Shipping", menu = "Shipping", pos = V(58, 0, -80), look = V(30, 0, -60) })
table.insert(boards, { name = "Workers", menu = "Workers", pos = V(70, 0, -24), look = V(30, 0, -28) })
table.insert(boards, { name = "Silos", menu = "Silos", pos = V(-66, 0, -64), look = V(-30, 0, -40) })
table.insert(boards, { name = "Upgrades", menu = "Upgrades", pos = V(-22, 0, 94), look = V(0, 0, 88) })
table.insert(boards, { name = "Eggs", menu = "Eggs", pos = V(22, 0, 94), look = V(0, 0, 88) })
PlotLayout.Boards = boards

PlotLayout.FoxSpots = {
	V(-44, 0, 100),
	V(44, 0, 100),
	V(0, 0, 29),
	V(-80, 0, 72),
	V(80, 0, 10),
	V(80, 0, 62),
}

-- Path rectangles (themed path colour).
PlotLayout.Paths = {
	{ x0 = -8, z0 = -24, x1 = 8, z1 = 110 }, -- central path
	{ x0 = -32, z0 = 84, x1 = 32, z1 = 110 }, -- entrance plaza
	{ x0 = -66, z0 = 25, x1 = 66, z1 = 33 }, -- cross path between the house rows
	{ x0 = -30, z0 = -41, x1 = 30, z1 = -24 }, -- warehouse apron
	{ x0 = 30, z0 = -34, x1 = 69, z1 = -26 }, -- to the worker shed
	{ x0 = -74, z0 = -48, x1 = -24, z1 = -40 }, -- to the silo row
}

-- Decoration spots (trees / props by theme). Kept clear of paths, lots, silos and the road.
PlotLayout.Decor = {
	V(-70, 0, 99),
	V(70, 0, 99),
	V(-56, 0, 104),
	V(56, 0, 104),
	V(-84, 0, 88),
	V(84, 0, 88),
	V(84, 0, 40),
	V(84, 0, -12),
	V(-85, 0, 60),
	V(-84, 0, 100),
	V(-72, 0, -90),
	V(-82, 0, -102),
	V(40, 0, 88),
	V(-40, 0, 88),
}

-- Fence: perimeter segments (plot-local), leaving the entrance and the road exit open.
PlotLayout.Fence = {
	{ a = V(-90, 0, 110), b = V(-12, 0, 110) },
	{ a = V(12, 0, 110), b = V(90, 0, 110) },
	{ a = V(90, 0, 110), b = V(90, 0, -110) },
	{ a = V(-90, 0, -110), b = V(-90, 0, 110) },
	{ a = V(-90, 0, -110), b = V(72, 0, -110) },
	{ a = V(88, 0, -110), b = V(90, 0, -110) },
}

-- ---------------------------------------------------------------- world placement
-- Returns the plot centre and its yaw (radians about +y). Plots 1-4: north row, rotated pi.
function PlotLayout.Origin(index: number): (Vec, number)
	assert(index >= 1 and index <= PlotLayout.PlotCount, "plot index out of range")
	local col = (index - 1) % 4
	local north = index <= 4
	local x = (col - 1.5) * PlotLayout.COLUMN_SPACING
	if north then
		return V(x, 0, PlotLayout.ROW_Z), math.pi
	end
	return V(x, 0, -PlotLayout.ROW_Z), 0
end

-- Plot-local point -> world point (matches CFrame.new(origin) * CFrame.Angles(0, yaw, 0)).
function PlotLayout.ToWorld(index: number, p: Vec): Vec
	local o, yaw = PlotLayout.Origin(index)
	local c, s = math.cos(yaw), math.sin(yaw)
	-- rotation about +y: x' = x c + z s, z' = -x s + z c
	local x = p.x * c + p.z * s
	local z = -p.x * s + p.z * c
	return V(o.x + x, o.y + p.y, o.z + z)
end

-- World-space axis-aligned bounds of a plot.
function PlotLayout.Bounds(index: number): Rect
	local o = PlotLayout.Origin(index)
	return {
		x0 = o.x - PlotLayout.HALF_W,
		z0 = o.z - PlotLayout.HALF_D,
		x1 = o.x + PlotLayout.HALF_W,
		z1 = o.z + PlotLayout.HALF_D,
	}
end

function PlotLayout.InsideLocal(p: Vec, margin: number?): boolean
	local m = margin or 0
	return math.abs(p.x) <= PlotLayout.HALF_W - m and math.abs(p.z) <= PlotLayout.HALF_D - m
end

-- Polyline a vehicle in `bay` follows when it leaves: bay -> road -> waypoints (plot-local).
function PlotLayout.VehiclePath(bay: number): { Vec }
	local b = bays[bay] or bays[1]
	local path = { b, V(b.x, 0, PlotLayout.ROAD_Z) }
	for _, p in PlotLayout.Road do
		table.insert(path, p)
	end
	return path
end

-- Polyline a worker walks from WorkerPath/Start to a house's collect ring (plot-local).
function PlotLayout.WorkerRoute(slot: number): { Vec }
	local h = houses[slot] or houses[1]
	local s = PlotLayout.WorkerStart
	local lane = h.side * 4
	return { s, V(lane, 0, -22), V(lane, 0, h.ring.z), V(h.ring.x, 0, h.ring.z) }
end

-- Length of a polyline and the point/direction at distance d along it (clamped).
function PlotLayout.PolyLength(path: { Vec }): number
	local len = 0
	for i = 2, #path do
		local a, b = path[i - 1], path[i]
		len += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	end
	return len
end

function PlotLayout.PolyPoint(path: { Vec }, d: number): (Vec, Vec, number)
	-- returns point, unit direction of the segment, and the segment index (2..#path)
	local rest = math.max(0, d)
	for i = 2, #path do
		local a, b = path[i - 1], path[i]
		local dx, dz = b.x - a.x, b.z - a.z
		local seg = math.sqrt(dx * dx + dz * dz)
		if seg > 0 and (rest <= seg or i == #path) then
			local f = math.min(1, rest / seg)
			return V(a.x + dx * f, 0, a.z + dz * f), V(dx / seg, 0, dz / seg), i
		end
		rest -= seg
	end
	local last = path[#path]
	return V(last.x, 0, last.z), V(0, 0, -1), #path
end

-- Distance along a vehicle path where the tunnel starts (vehicles are hidden beyond it).
function PlotLayout.TunnelDistance(bay: number): number
	local path = PlotLayout.VehiclePath(bay)
	local upto = {}
	for i = 1, PlotLayout.TunnelAt + 2 do -- bay + road point + waypoints up to TunnelAt
		upto[i] = path[i]
	end
	-- stop at the hill face, a little before the TunnelAt waypoint
	return PlotLayout.PolyLength(upto) - (PlotLayout.RIDGE_LOCAL_Z - PlotLayout.Road[PlotLayout.TunnelAt].z)
end

return PlotLayout
