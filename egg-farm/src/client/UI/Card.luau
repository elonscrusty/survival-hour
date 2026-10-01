--!strict
-- Card: rounded white tile with an outline and soft gradient, the building block of every grid
-- and list. Card.Row builds a full-width list row (icon | title + detail | action area).

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Icon = require(script.Parent.Icon)

local Card = {}

function Card.new(o: { size: UDim2?, color: Color3?, order: number?, parent: Instance?, name: string? }): Frame
	local f = Instance.new("Frame")
	f.Name = o.name or "Card"
	f.BackgroundColor3 = o.color or Theme.Color.Card
	f.Size = o.size or UDim2.fromOffset(200, 220)
	f.LayoutOrder = o.order or 0
	Util.Corner(f, 16)
	Util.Stroke(f, 3, Theme.Color.Ink, true)
	Util.Gradient(f, Color3.new(1, 1, 1), Color3.fromRGB(232, 226, 214))
	f.Parent = o.parent
	return f
end

export type Row = {
	Frame: Frame,
	Icon: Frame,
	Title: TextLabel,
	Detail: TextLabel,
	Action: Frame, -- right-hand area for buttons (width set by actionWidth)
}

-- A full-width row with automatic height: icon on the left, wrapped text in the middle,
-- an action area on the right. Long text grows the row instead of being cut off.
function Card.Row(o: {
	icon: string,
	title: string,
	detail: string?,
	actionWidth: number?,
	minHeight: number?,
	color: Color3?,
	order: number?,
	parent: Instance?,
}): Row
	local aw = o.actionWidth or 170
	local f = Card.new({ size = UDim2.new(1, -8, 0, o.minHeight or 96), color = o.color, order = o.order, parent = nil })
	f.AutomaticSize = Enum.AutomaticSize.Y
	Util.Pad(f, 10)
	local min = Instance.new("UISizeConstraint")
	min.MinSize = Vector2.new(0, o.minHeight or 96)
	min.Parent = f

	local ic = Icon.new(o.icon, 56)
	ic.Position = UDim2.fromOffset(0, 8)
	ic.Parent = f

	local mid = Instance.new("Frame")
	mid.Name = "Text"
	mid.BackgroundTransparency = 1
	mid.Position = UDim2.fromOffset(66, 0)
	mid.Size = UDim2.new(1, -(66 + aw + 8), 0, 0)
	mid.AutomaticSize = Enum.AutomaticSize.Y
	Util.List(mid, 2, false, Enum.HorizontalAlignment.Left)
	mid.Parent = f

	local title = Util.Text({
		text = o.title,
		size = UDim2.new(1, 0, 0, 0),
		textSize = Theme.Text.M,
		color = Theme.Color.TextDark,
		font = Theme.Font.Title,
		xAlign = Enum.TextXAlignment.Left,
		wrap = true,
		order = 1,
		parent = mid,
	})
	local detail = Util.Text({
		text = o.detail or "",
		size = UDim2.new(1, 0, 0, 0),
		textSize = Theme.Text.S,
		color = Theme.Color.TextMuted,
		xAlign = Enum.TextXAlignment.Left,
		wrap = true,
		order = 2,
		parent = mid,
	})

	local action = Instance.new("Frame")
	action.Name = "Action"
	action.BackgroundTransparency = 1
	action.AnchorPoint = Vector2.new(1, 0)
	action.Position = UDim2.new(1, 0, 0, 0)
	action.Size = UDim2.new(0, aw, 0, (o.minHeight or 96) - 20)
	action.Parent = f

	f.Parent = o.parent
	return { Frame = f, Icon = ic, Title = title, Detail = detail, Action = action }
end

return Card
