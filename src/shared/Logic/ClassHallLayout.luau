--!strict
-- Class Hall screen layout maths (pure, tested in tests/ClassHallLayout.spec.luau).
-- Input is the hall's size in UI units (after the Panels UIScale), so a phone in
-- landscape (~800x400 px) arrives as roughly 1100x490. Wide screens get three
-- columns (card grid | avatar | perks); narrow ones (portrait) stack the avatar
-- on top with the grid and perks side by side below.

export type Rect = { X: number, Y: number, W: number, H: number }
export type Layout = {
	Stacked: boolean,
	Left: Rect,
	Centre: Rect,
	Right: Rect,
	Cols: number,
	CardW: number,
	CardH: number,
}

local ClassHallLayout = {}

ClassHallLayout.Gap = 10 -- between columns and around the edge
ClassHallLayout.Pad = 10 -- inside the grid column
ClassHallLayout.Scroll = 8 -- scroll bar width
ClassHallLayout.CardGap = 8
ClassHallLayout.MinCard = 118
ClassHallLayout.WideFrom = 820

local function rect(x: number, y: number, w: number, h: number): Rect
	return { X = x, Y = y, W = math.max(0, w), H = math.max(0, h) }
end

-- Card grid for a grid column of width `colW`: 2-4 columns of roughly square cards.
function ClassHallLayout.Grid(colW: number): (number, number, number)
	local L = ClassHallLayout
	local inner = colW - 2 * L.Pad - L.Scroll
	local cols = math.clamp(math.floor((inner + L.CardGap) / (L.MinCard + L.CardGap)), 2, 4)
	local cardW = math.max(60, math.floor((inner - L.CardGap * (cols - 1)) / cols))
	return cols, cardW, math.floor(cardW * 1.3)
end

function ClassHallLayout.Compute(w: number, h: number): Layout
	local g = ClassHallLayout.Gap
	local left, centre, right
	local stacked = w < ClassHallLayout.WideFrom
	if not stacked then
		local leftW = math.clamp(math.floor(w * 0.38), 300, 560)
		local rightW = math.clamp(math.floor(w * 0.25), 220, 340)
		local centreW = w - leftW - rightW - 4 * g
		left = rect(g, g, leftW, h - 2 * g)
		centre = rect(2 * g + leftW, g, centreW, h - 2 * g)
		right = rect(3 * g + leftW + centreW, g, rightW, h - 2 * g)
	else
		local centreH = math.clamp(math.floor(h * 0.42), 260, 420)
		local rowY = 2 * g + centreH
		local rowH = h - rowY - g
		local leftW = math.floor((w - 3 * g) * 0.6)
		centre = rect(g, g, w - 2 * g, centreH)
		left = rect(g, rowY, leftW, rowH)
		right = rect(2 * g + leftW, rowY, w - 3 * g - leftW, rowH)
	end
	local cols, cardW, cardH = ClassHallLayout.Grid(left.W)
	return { Stacked = stacked, Left = left, Centre = centre, Right = right, Cols = cols, CardW = cardW, CardH = cardH }
end

return ClassHallLayout
