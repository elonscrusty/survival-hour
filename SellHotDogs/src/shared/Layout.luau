--!strict
-- Plot geometry in plot-local studs. +Z runs away from the road, X across the plot.
-- Shared so the client can point guidance arrows at the same spots the server builds.
local Layout = {}

Layout.PLOT_SPACING = 240 -- along the road (world X)
Layout.PLOT_HALF_WIDTH = 105
Layout.PLOT_DEPTH = 410
Layout.ROAD_Z = -26 -- road centre line, in front of every plot

-- Lot centre and footprint per business (stand closest to the road, HotDogX at the back).
Layout.lots = ({
	stand = { pos = Vector3.new(0, 0, 34), size = Vector2.new(40, 30) },
	dash = { pos = Vector3.new(-62, 0, 100), size = Vector2.new(60, 56) },
	depot = { pos = Vector3.new(62, 0, 100), size = Vector2.new(60, 56) },
	trading = { pos = Vector3.new(-62, 0, 180), size = Vector2.new(60, 56) },
	labs = { pos = Vector3.new(62, 0, 180), size = Vector2.new(60, 56) },
	robotics = { pos = Vector3.new(-62, 0, 260), size = Vector2.new(60, 56) },
	republic = { pos = Vector3.new(62, 0, 260), size = Vector2.new(60, 56) },
	hotdogx = { pos = Vector3.new(0, 0, 340), size = Vector2.new(60, 50) },
} :: { [string]: { pos: Vector3, size: Vector2 } })

Layout.spawn = Vector3.new(0, 3, 6)
Layout.portal = Vector3.new(0, 0, 220) -- Void Evolution portal on the path between rows
Layout.staircase = Vector3.new(0, 0, 388) -- Ascension staircase behind HotDogX
Layout.investorDesk = Vector3.new(10, 0, 140) -- Alien Investors kiosk (placed 10 studs left of this)

-- Ingredient racks (pickup spots) sit beside the path, never on a pad or doorway.
Layout.racks = {
	Vector3.new(30, 0, 12),
	Vector3.new(-30, 0, 12),
	Vector3.new(-22, 0, 150),
	Vector3.new(22, 0, 150),
}

-- Pad k (1-based) of a business: rows of four in front of the lot, facing the road.
function Layout.padPos(bizId: string, k: number): Vector3
	local lot = Layout.lots[bizId]
	local col = (k - 1) % 4
	local row = (k - 1) // 4
	local front = lot.pos.Z - lot.size.Y / 2 - 7 - row * 9
	if bizId == "stand" then
		-- the stand's pads wrap both sides so the walkway to the road stays clear
		local side = if col < 2 then -1 else 1
		local x = side * (lot.size.X / 2 + 6 + (col % 2) * 9)
		return lot.pos + Vector3.new(x, 0, -8 + row * 10)
	end
	return Vector3.new(lot.pos.X + (col - 1.5) * 10, 0, front)
end

-- Unlock pad of a business: right at the front edge of its lot.
function Layout.unlockPos(bizId: string): Vector3
	local lot = Layout.lots[bizId]
	return lot.pos - Vector3.new(0, 0, lot.size.Y / 2 + 6)
end

Layout.PROP_SLOT = 8 -- studs; props larger than this are scaled down to fit

-- Where the prop of owned pad k (of n props) stands: two tidy columns along the lot's side
-- edges, front to back, clear of the building in the middle and the pads in front.
function Layout.propPos(bizId: string, k: number, n: number): Vector3
	local lot = Layout.lots[bizId]
	local perSide = math.max(1, math.ceil(n / 2))
	local side = if k % 2 == 1 then -1 else 1
	local idx = (k - 1) // 2
	local x = side * (lot.size.X / 2 - Layout.PROP_SLOT / 2 - 1)
	local depth = lot.size.Y - Layout.PROP_SLOT
	local step = if perSide <= 1 then 0 else math.min(Layout.PROP_SLOT + 1, depth / (perSide - 1))
	local z = -lot.size.Y / 2 + Layout.PROP_SLOT / 2 + idx * step
	return lot.pos + Vector3.new(x, 0, z)
end

-- Level-milestone prop `tier` (1-4) of a business: front strip of the lot (stand: behind it).
function Layout.tierPos(bizId: string, tier: number): Vector3
	local lot = Layout.lots[bizId]
	local side = if tier % 2 == 1 then -1 else 1
	if bizId == "stand" then
		return lot.pos + Vector3.new(side * (if tier <= 2 then 14 else 7), 0, 11)
	end
	local inset = if tier <= 2 then lot.size.X / 2 - 14 else lot.size.X / 2 - 22
	return lot.pos + Vector3.new(side * inset, 0, -lot.size.Y / 2 + 5)
end

-- Where each looks-only decoration goes (clear of lots, pads, paths' centre and racks).
Layout.decorSpots = {
	planter = Vector3.new(-12, 0, 12),
	bench = Vector3.new(12, 0, 12),
	lamps = Vector3.new(-10, 0, 84),
	picnic = Vector3.new(-22, 0, 136),
	umbrella = Vector3.new(-40, 0, 134),
	balloons = Vector3.new(-26, 0, 0),
	lights = Vector3.new(0, 0, 58),
	arch = Vector3.new(0, 0, 112),
	neon = Vector3.new(-26, 0, 58),
	topiary = Vector3.new(-45, 0, 300),
	fountain = Vector3.new(22, 0, 136),
	statue = Vector3.new(-20, 0, 302),
} :: { [string]: Vector3 }

function Layout.plotOrigin(index: number): CFrame
	return CFrame.new((index - 1) * Layout.PLOT_SPACING, 0, 0)
end

return Layout
