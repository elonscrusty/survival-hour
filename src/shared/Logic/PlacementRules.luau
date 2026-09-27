--!strict
-- 2D placement rules for base building (pure, tested). The server adds the
-- 3D checks that need the engine (terrain slope, characters, part overlap).
--
-- Footprints are oriented rectangles on the XZ plane: centre, half extents and yaw.

export type Rect = { X: number, Z: number, HX: number, HZ: number, Yaw: number }
export type Circle = { X: number, Z: number, R: number }

local PlacementRules = {}

local function axes(r: Rect): ({ number }, { number })
	local c, s = math.cos(math.rad(r.Yaw)), math.sin(math.rad(r.Yaw))
	return { c, s }, { -s, c }
end

local function corners(r: Rect): { { number } }
	local ax, az = axes(r)
	local out = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(out, {
				r.X + ax[1] * r.HX * sx + az[1] * r.HZ * sz,
				r.Z + ax[2] * r.HX * sx + az[2] * r.HZ * sz,
			})
		end
	end
	return out
end
PlacementRules.Corners = corners

-- Separating axis test; `pad` shrinks both rects slightly so touching walls
-- (snapped end to end) are allowed.
function PlacementRules.RectsOverlap(a: Rect, b: Rect, pad: number?): boolean
	local p = pad or 0.2
	local ca, cb = corners(a), corners(b)
	local axA1, axA2 = axes(a)
	local axB1, axB2 = axes(b)
	for _, ax in { axA1, axA2, axB1, axB2 } do
		local minA, maxA, minB, maxB = math.huge, -math.huge, math.huge, -math.huge
		for _, c in ca do
			local d = c[1] * ax[1] + c[2] * ax[2]
			minA, maxA = math.min(minA, d), math.max(maxA, d)
		end
		for _, c in cb do
			local d = c[1] * ax[1] + c[2] * ax[2]
			minB, maxB = math.min(minB, d), math.max(maxB, d)
		end
		if maxA - p <= minB + p or maxB - p <= minA + p then
			return false
		end
	end
	return true
end

function PlacementRules.RectCircleOverlap(r: Rect, c: Circle): boolean
	local ax, az = axes(r)
	local dx, dz = c.X - r.X, c.Z - r.Z
	local lx = dx * ax[1] + dz * ax[2]
	local lz = dx * az[1] + dz * az[2]
	local qx = math.clamp(lx, -r.HX, r.HX)
	local qz = math.clamp(lz, -r.HZ, r.HZ)
	return (lx - qx) ^ 2 + (lz - qz) ^ 2 < c.R * c.R
end

export type Context = {
	Fire: { X: number, Z: number },
	ZoneRadius: number,
	Clearances: { Circle }, -- fire, workbench front, spawn pads
	Existing: { Rect },
	LimitUsed: number,
	LimitMax: number,
}

-- Returns ok, reason.
function PlacementRules.Check(rect: Rect, ctx: Context): (boolean, string?)
	if ctx.LimitUsed >= ctx.LimitMax then
		return false, "Structure limit reached"
	end
	for _, c in corners(rect) do
		local d = math.sqrt((c[1] - ctx.Fire.X) ^ 2 + (c[2] - ctx.Fire.Z) ^ 2)
		if d > ctx.ZoneRadius then
			return false, "Outside your camp's build zone"
		end
	end
	for _, c in ctx.Clearances do
		if PlacementRules.RectCircleOverlap(rect, c) then
			return false, "Too close to the fire, workbench or spawn"
		end
	end
	for _, e in ctx.Existing do
		if PlacementRules.RectsOverlap(rect, e) then
			return false, "Overlaps another structure"
		end
	end
	return true, nil
end

return PlacementRules
