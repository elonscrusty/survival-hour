--!strict
-- Small instance helpers used by every component. `New` returns `any` so callers can set any
-- property table without a cast; components keep typed handles for what they expose.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Util = {}

function Util.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst: any = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Util.Corner(parent: Instance, radius: number?, scale: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = if scale then UDim.new(scale, 0) else UDim.new(0, radius or Theme.Size.Radius)
	c.Parent = parent
	return c
end

function Util.Stroke(parent: Instance, thickness: number?, color: Color3?, border: boolean?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or Theme.Size.Stroke
	s.Color = color or Theme.Color.Ink
	s.LineJoinMode = Enum.LineJoinMode.Round
	if border then
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	s.Parent = parent
	return s
end

-- Vertical two-tone gradient: lighter on top (keeps the base colour on the object).
function Util.Gradient(parent: Instance, top: Color3?, bottom: Color3?, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top or Color3.new(1, 1, 1), bottom or Color3.fromRGB(205, 205, 205))
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function Util.Pad(parent: Instance, all: number, top: number?, bottom: number?): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	p.PaddingTop = UDim.new(0, top or all)
	p.PaddingBottom = UDim.new(0, bottom or all)
	p.Parent = parent
	return p
end

function Util.List(parent: Instance, gap: number?, horizontal: boolean?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or Theme.Size.Gap)
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center
	l.VerticalAlignment = vAlign or Enum.VerticalAlignment.Top
	l.Parent = parent
	return l
end

function Util.Grid(parent: Instance, cell: Vector2, gap: number?): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	g.CellPadding = UDim2.fromOffset(gap or 10, gap or 10)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.Parent = parent
	return g
end

-- A text label. Scaled text keeps a readable minimum; wrapped text grows its height instead.
export type TextOpts = {
	text: string?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	textSize: number?,
	color: Color3?,
	font: Enum.Font?,
	xAlign: Enum.TextXAlignment?,
	yAlign: Enum.TextYAlignment?,
	scaled: boolean?, -- TextScaled with a size constraint (default true)
	wrap: boolean?, -- wrapped + AutomaticSize Y (ignores scaled)
	outline: boolean?, -- dark text stroke (game style)
	z: number?,
	order: number?,
	parent: Instance?,
}

function Util.Text(o: TextOpts): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = o.text or ""
	t.Size = o.size or UDim2.fromScale(1, 1)
	t.Position = o.position or UDim2.new()
	t.AnchorPoint = o.anchor or Vector2.zero
	t.Font = o.font or Theme.Font.Body
	t.TextColor3 = o.color or Theme.Color.Text
	t.TextXAlignment = o.xAlign or Enum.TextXAlignment.Center
	t.TextYAlignment = o.yAlign or Enum.TextYAlignment.Center
	t.ZIndex = o.z or 1
	t.LayoutOrder = o.order or 0
	local size = math.max(o.textSize or Theme.Text.M, Theme.Text.Min)
	if o.wrap then
		t.TextWrapped = true
		t.TextSize = size
		t.AutomaticSize = Enum.AutomaticSize.Y
	elseif o.scaled ~= false then
		t.TextScaled = true
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = size
		c.MinTextSize = Theme.Text.Min - 4 -- allow a little squeeze for long words, never tiny
		c.Parent = t
	else
		t.TextSize = size
	end
	if o.outline then
		t.TextStrokeTransparency = 0
		t.TextStrokeColor3 = Theme.Color.Ink
	end
	t.Parent = o.parent
	return t
end

function Util.Tween(inst: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tw = TweenService:Create(inst, info, goal)
	tw:Play()
	return tw
end

-- Brief horizontal shake (rejected purchase). Uses the object's own position as home.
local shaking: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function Util.Shake(obj: GuiObject)
	if shaking[obj] then
		return
	end
	shaking[obj] = true
	local home = obj.Position
	task.spawn(function()
		for _, dx in { 8, -8, 6, -6, 3, 0 } do
			obj.Position = home + UDim2.fromOffset(dx, 0)
			task.wait(0.035)
		end
		obj.Position = home
		shaking[obj] = nil
	end)
end

-- Little "pop" on a UIScale (press feedback, counters).
function Util.Pop(obj: GuiObject, amount: number?)
	local sc = obj:FindFirstChildOfClass("UIScale")
	if not sc then
		local made = Instance.new("UIScale")
		made.Parent = obj
		sc = made
	end
	assert(sc)
	sc.Scale = 1 + (amount or 0.12)
	Util.Tween(sc, Theme.Tween.Pop, { Scale = 1 })
end

function Util.Clear(parent: Instance, keepClasses: { string }?)
	for _, c in parent:GetChildren() do
		if keepClasses and table.find(keepClasses, c.ClassName) then
			continue
		end
		c:Destroy()
	end
end

-- Scrolling container that grows with its content (cards / rows).
function Util.Scroll(parent: Instance, size: UDim2?, position: UDim2?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = size or UDim2.fromScale(1, 1)
	s.Position = position or UDim2.new()
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.ScrollBarThickness = 8
	s.ScrollBarImageColor3 = Theme.Color.Ink
	s.ScrollBarImageTransparency = 0.4
	s.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	s.Parent = parent
	return s
end

return Util
