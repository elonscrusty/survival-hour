--!strict
-- Visual flock planner. PURE (no Roblox APIs): the client asks how many chicken models to show
-- per house, and steps each chicken's wander state here. Chickens are decoration only; the real
-- population lives in the snapshot and can be astronomically large (1e9+), so what is drawn is a
-- bounded, representative sample.
--
-- Cap (documented contract, tested in tests/Flock.spec.luau):
--   own plot  low:    up to  6 per house, 24 per plot
--             normal: up to 15 per house, 60 per plot
--             high:   up to 30 per house, 120 per plot
--   other players' plots: 1 per occupied house (4 per plot), only within OTHER_RADIUS studs.
--   Any occupied house always shows at least 1 chicken (within range).
--   Growth is logarithmic: 1 chicken at 1 occupant, the per-house cap at FULL_AT occupants
--   (1e5, a full late-game house), so every 10x in population adds the same number of birds.
-- Why these numbers: a fully upgraded own plot at "high" is 120 chickens x 7 parts = 840 moving
-- parts, moved in one BulkMoveTo per frame (cheap on phones); "low" stays under 200 parts.
-- Others' plots are only a hint of life, so 4 birds each keeps 7 neighbours under 200 parts.

local Flock = {}

export type Cap = { house: number, plot: number }

Flock.Caps = {
	low = { house = 6, plot = 24 },
	normal = { house = 15, plot = 60 },
	high = { house = 30, plot = 120 },
} :: { [string]: Cap }
Flock.Other = { house = 1, plot = 4 } :: Cap
Flock.OTHER_RADIUS = 200
Flock.FULL_AT = 1e5

local function finite(n: any): number
	if type(n) ~= "number" or n ~= n then
		return 0
	end
	if n == math.huge then
		return 1e308
	end
	return math.max(0, n)
end

function Flock.CapFor(setting: string?, own: boolean): Cap
	if not own then
		return Flock.Other
	end
	return Flock.Caps[setting or "normal"] or Flock.Caps.normal
end

-- Chickens shown for one house with `occupants` real chickens, before the per-plot cap.
function Flock.ForHouse(occupants: number, houseCap: number): number
	local occ = math.floor(finite(occupants) + 0.5)
	if occ < 1 or houseCap < 1 then
		return 0
	end
	local f = math.clamp(math.log10(occ) / math.log10(Flock.FULL_AT), 0, 1)
	return math.min(houseCap, 1 + math.floor((houseCap - 1) * f + 1e-9))
end

export type PlanInput = {
	occupants: { number },
	setting: string?,
	own: boolean,
	distance: number?, -- studs from the camera/character to the plot (others' plots only)
}

-- Count of chickens to draw per house.
function Flock.Plan(input: PlanInput): { number }
	local out = {}
	local n = #input.occupants
	for i = 1, n do
		out[i] = 0
	end
	if not input.own and finite(input.distance or 0) > Flock.OTHER_RADIUS then
		return out
	end
	local cap = Flock.CapFor(input.setting, input.own)
	local total = 0
	local occupied = {}
	for i = 1, n do
		out[i] = Flock.ForHouse(input.occupants[i], cap.house)
		total += out[i]
		if out[i] > 0 then
			table.insert(occupied, i)
		end
	end
	if total <= cap.plot then
		return out
	end
	-- Over the plot cap: every occupied house keeps 1 (largest houses first if even that is too
	-- many), the remaining budget is shared in proportion to each house's extra birds.
	table.sort(occupied, function(a, b)
		return finite(input.occupants[a]) > finite(input.occupants[b])
	end)
	local base = math.min(#occupied, cap.plot)
	local extraTotal = 0
	for k, i in occupied do
		if k <= base then
			extraTotal += out[i] - 1
		end
	end
	local budget = cap.plot - base
	local result = {}
	local rema: { { i: number, r: number } } = {}
	local used = 0
	for i = 1, n do
		result[i] = 0
	end
	for k, i in occupied do
		if k > base then
			continue
		end
		local share = if extraTotal > 0 then (out[i] - 1) * budget / extraTotal else 0
		local whole = math.floor(share)
		result[i] = 1 + whole
		used += whole
		table.insert(rema, { i = i, r = share - whole })
	end
	table.sort(rema, function(a, b)
		if a.r == b.r then
			return a.i < b.i
		end
		return a.r > b.r
	end)
	local left = budget - used
	for _, e in rema do
		if left <= 0 then
			break
		end
		if result[e.i] < out[e.i] then
			result[e.i] += 1
			left -= 1
		end
	end
	return result
end

-- Spread a plot's population over its houses in proportion to house capacity (for other
-- players' plots, where only the Population and HouseTiers attributes are known).
function Flock.Distribute(population: number, capacities: { number }): { number }
	local pop = finite(population)
	local sum = 0
	for _, c in capacities do
		sum += finite(c)
	end
	local out = {}
	for i, c in capacities do
		out[i] = if sum > 0 then pop * finite(c) / sum else 0
	end
	return out
end

-- How often (seconds) a chicken at `distance` studs should be re-posed. 0 = every frame.
function Flock.UpdateInterval(distance: number): number
	if distance < 70 then
		return 0
	elseif distance < 140 then
		return 1 / 15
	end
	return 1 / 6
end

-- ------------------------------------------------------------------ wander state machine
export type Bird = {
	x: number, -- offset from the yard centre (plot axes)
	z: number,
	tx: number,
	tz: number,
	heading: number, -- radians about +y (0 = facing -z)
	mode: string, -- "walk" | "peck" | "idle"
	timer: number,
	phase: number,
	speed: number,
	hop: number, -- output: body lift (studs)
	peck: number, -- output: 0..1 head dip
}

function Flock.NewBird(hx: number, hz: number, rand: () -> number): Bird
	local x = (rand() * 2 - 1) * hx
	local z = (rand() * 2 - 1) * hz
	return {
		x = x,
		z = z,
		tx = x,
		tz = z,
		heading = rand() * math.pi * 2,
		mode = "idle",
		timer = rand() * 1.5,
		phase = rand() * 10,
		speed = 3 + rand() * 2.5,
		hop = 0,
		peck = 0,
	}
end

-- Advance one bird by dt inside the yard box [-hx, hx] x [-hz, hz]. Mutates and returns it.
function Flock.Wander(b: Bird, dt: number, hx: number, hz: number, rand: () -> number): Bird
	dt = math.clamp(finite(dt), 0, 1)
	b.phase += dt
	b.timer -= dt
	if b.mode == "walk" then
		local dx, dz = b.tx - b.x, b.tz - b.z
		local dist = math.sqrt(dx * dx + dz * dz)
		local step = b.speed * dt
		if dist <= step or dist < 0.05 then
			b.x, b.z = b.tx, b.tz
			if rand() < 0.6 then
				b.mode, b.timer = "peck", 0.6 + rand() * 1.4
			else
				b.mode, b.timer = "idle", 0.4 + rand() * 1.6
			end
		else
			b.x += dx / dist * step
			b.z += dz / dist * step
			b.heading = math.atan2(-dx, -dz)
		end
		b.hop = math.abs(math.sin(b.phase * 14)) * 0.22
		b.peck = 0
	else
		b.hop = 0
		if b.mode == "peck" then
			b.peck = math.max(0, math.sin(b.phase * 9))
		else
			b.peck = 0
		end
		if b.timer <= 0 then
			b.mode = "walk"
			b.tx = (rand() * 2 - 1) * hx
			b.tz = (rand() * 2 - 1) * hz
		end
	end
	b.x = math.clamp(b.x, -hx, hx)
	b.z = math.clamp(b.z, -hz, hz)
	return b
end

return Flock
