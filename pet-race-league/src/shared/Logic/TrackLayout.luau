-- Pure track maths: turns a track's segment list into positioned pieces and
-- checkpoints (numbers only, so it can be unit tested without Roblox).
-- X runs along the track from 0 (start line) to Length (finish line). Y is the
-- floor height relative to the start floor.
local TrackLayout = {}

export type Piece = {
	Kind: string,
	X0: number,
	X1: number,
	Y0: number, -- floor height at X0
	Y1: number, -- floor height at X1
	H: number?,
	Count: number?,
	Rise: number?,
}

export type Checkpoint = { X: number, Y: number }

export type Layout = {
	Pieces: { Piece },
	Checkpoints: { Checkpoint }, -- [1] is the start line
	Length: number,
	MinY: number,
	MaxY: number,
}

function TrackLayout.Build(segments: { any }): Layout
	local pieces = {}
	local checkpoints = { { X = 0, Y = 0 } }
	local x, y = 0, 0
	local minY, maxY = 0, 0
	for i, seg in segments do
		local y1 = y
		if seg.Kind == "Ramp" then
			y1 = y + (seg.Rise or 0)
		elseif seg.Kind == "Steps" then
			y1 = y + (seg.Rise or 0) * (seg.Count or 1)
		end
		table.insert(pieces, {
			Kind = seg.Kind,
			X0 = x,
			X1 = x + seg.L,
			Y0 = y,
			Y1 = y1,
			H = seg.H,
			Count = seg.Count,
			Rise = seg.Rise,
		})
		-- A checkpoint where each segment with a floor starts (never over a gap), so
		-- respawning just past it always lands on solid ground.
		if i > 1 and seg.Kind ~= "Gap" then
			table.insert(checkpoints, { X = x, Y = y })
		end
		x += seg.L
		y = y1
		minY = math.min(minY, y)
		maxY = math.max(maxY, y)
	end
	return { Pieces = pieces, Checkpoints = checkpoints, Length = x, MinY = minY, MaxY = maxY }
end

-- Floor height under x (nil over a gap or off the track).
function TrackLayout.FloorAt(layout: Layout, x: number): number?
	for _, p in layout.Pieces do
		if x >= p.X0 and x <= p.X1 then
			if p.Kind == "Gap" then
				return nil
			elseif p.Kind == "Steps" then
				local n = p.Count or 1
				local step = math.min(n - 1, math.floor((x - p.X0) / ((p.X1 - p.X0) / n)))
				return p.Y0 + (p.Rise or 0) * (step + 1)
			end
			local t = (x - p.X0) / math.max(p.X1 - p.X0, 1e-6)
			return p.Y0 + (p.Y1 - p.Y0) * t
		end
	end
	return nil
end

-- "Boost", "Mud" or nil for the piece under x.
function TrackLayout.ZoneAt(layout: Layout, x: number): string?
	for _, p in layout.Pieces do
		if x >= p.X0 and x < p.X1 then
			if p.Kind == "Boost" or p.Kind == "Mud" then
				return p.Kind
			end
			return nil
		end
	end
	return nil
end

-- Index of the furthest checkpoint at or behind x.
function TrackLayout.CheckpointAt(layout: Layout, x: number): number
	local best = 1
	for i, cp in layout.Checkpoints do
		if cp.X <= x then
			best = i
		end
	end
	return best
end

return TrackLayout
