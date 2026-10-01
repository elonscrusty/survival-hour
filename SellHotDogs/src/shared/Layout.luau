--!strict
-- Plot geometry in plot-local studs. +Z runs away from the road, X across the plot.
-- Shared so the client can point guidance arrows at the same spots the server builds.
local Layout = {}

Layout.PLOT_SPACING = 240 -- along the road (world X)
Layout.PLOT_HALF_WIDTH = 105
Layout.PLOT_DEPTH = 330
Layout.ROAD_Z = -26 -- road centre line, in front of every plot

-- Lot centre and footprint per business (stand closest to the road, HotDogX at the back).
Layout.lots = ({
	stand = { pos = Vector3.new(0, 0, 34), size = Vector2.new(40, 30) },
	dash = { pos = Vector3.new(-58, 0, 92), size = Vector2.new(46, 40) },
	depot = { pos = Vector3.new(58, 0, 92), size = Vector2.new(46, 40) },
	trading = { pos = Vector3.new(-58, 0, 160), size = Vector2.new(46, 40) },
	labs = { pos = Vector3.new(58, 0, 160), size = Vector2.new(46, 40) },
	robotics = { pos = Vector3.new(-58, 0, 228), size = Vector2.new(46, 40) },
	republic = { pos = Vector3.new(58, 0, 228), size = Vector2.new(46, 40) },
	hotdogx = { pos = Vector3.new(0, 0, 290), size = Vector2.new(56, 40) },
} :: { [string]: { pos: Vector3, size: Vector2 } })

Layout.spawn = Vector3.new(0, 3, 6)
Layout.portal = Vector3.new(0, 0, 196) -- Void Evolution portal in the central plaza
Layout.staircase = Vector3.new(0, 0, 318) -- Ascension staircase behind HotDogX
Layout.investorDesk = Vector3.new(0, 0, 140) -- Alien Investors kiosk

-- Ingredient racks (pickup spots) sit beside the path, never on a pad or doorway.
Layout.racks = {
	Vector3.new(30, 0, 12),
	Vector3.new(-30, 0, 12),
	Vector3.new(-22, 0, 126),
	Vector3.new(22, 0, 126),
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

-- Where the prop of owned pad k stands (around the lot so it never blocks the front).
function Layout.propPos(bizId: string, k: number, n: number): Vector3
	local lot = Layout.lots[bizId]
	local hw, hd = lot.size.X / 2 - 4, lot.size.Y / 2 - 4
	-- walk the back and side edges
	local t = if n <= 1 then 0.5 else (k - 1) / (n - 1)
	local perim = hd * 2 + hw * 2
	local d = t * perim
	if d < hd then
		return lot.pos + Vector3.new(-hw, 0, -hd * 0.2 + d)
	elseif d < hd + hw * 2 then
		return lot.pos + Vector3.new(-hw + (d - hd), 0, hd)
	else
		return lot.pos + Vector3.new(hw, 0, hd - (d - hd - hw * 2))
	end
end

function Layout.plotOrigin(index: number): CFrame
	return CFrame.new((index - 1) * Layout.PLOT_SPACING, 0, 0)
end

return Layout
