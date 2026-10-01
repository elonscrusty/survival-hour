--!strict
-- Coloured tab strip. Each tab is a button; the selected one is raised and bright.
-- Tabs can be hidden (tutorial reveal) without rebuilding the strip.

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Button = require(script.Parent.Button)

local TabStrip = {}

export type Tab = { id: string, label: string, color: Color3? }

export type Handle = {
	Instance: Frame,
	Selected: string?,
	Select: (Handle, string) -> (),
	SetVisible: (Handle, string, boolean) -> (),
	SetBadge: (Handle, string, string?) -> (),
}

function TabStrip.new(o: {
	tabs: { Tab },
	onSelect: (string) -> (),
	size: UDim2?,
	position: UDim2?,
	parent: Instance?,
}): Handle
	local strip = Instance.new("Frame")
	strip.Name = "Tabs"
	strip.BackgroundTransparency = 1
	strip.Size = o.size or UDim2.new(1, 0, 0, 52)
	strip.Position = o.position or UDim2.new()
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.ScrollBarThickness = 0
	scroll.Parent = strip
	Util.List(scroll, 6, true, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)

	local buttons: { [string]: TextButton } = {}
	local colors: { [string]: Color3 } = {}
	local badges: { [string]: TextLabel } = {}
	local h: any = { Instance = strip, Selected = nil }

	local function paint()
		for id, b in buttons do
			local on = h.Selected == id
			b.BackgroundColor3 = if on then colors[id] else Theme.Darken(colors[id], 0.35)
			b.Size = UDim2.new(0, b.Size.X.Offset, 0, if on then 50 else 44)
			local lbl = b:FindFirstChild("Label") :: TextLabel?
			if lbl then
				lbl.TextTransparency = if on then 0 else 0.2
			end
		end
	end

	for i, t in o.tabs do
		local c = t.color or Theme.Color.Blue
		colors[t.id] = c
		local width = math.max(110, 22 + #t.label * 14)
		local b = Instance.new("TextButton")
		b.Name = t.id
		b.Text = ""
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(width, 44)
		b.BackgroundColor3 = c
		Util.Corner(b, 12)
		Util.Stroke(b, 3, Theme.Color.Ink, true)
		Util.Gradient(b)
		local lbl = Util.Text({
			text = t.label,
			size = UDim2.new(1, -12, 1, -6),
			position = UDim2.fromOffset(6, 0),
			textSize = Theme.Text.M,
			font = Theme.Font.Title,
			outline = true,
			z = 2,
			parent = b,
		})
		lbl.Name = "Label"
		local badge = Util.Text({
			text = "!",
			size = UDim2.fromOffset(26, 26),
			position = UDim2.new(1, -6, 0, -6),
			anchor = Vector2.new(0.5, 0.5),
			textSize = Theme.Text.S,
			font = Theme.Font.Number,
			outline = true,
			z = 4,
			parent = b,
		})
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = Theme.Color.Red
		Util.Corner(badge, nil, 0.5)
		badge.Visible = false
		badges[t.id] = badge
		b.Activated:Connect(function()
			local hook = Button.ClickHook
			if hook then
				hook()
			end
			o.onSelect(t.id)
		end)
		b.Parent = scroll
		buttons[t.id] = b
	end

	function h.Select(self: Handle, id: string)
		self.Selected = id
		paint()
	end

	function h.SetVisible(self: Handle, id: string, on: boolean)
		local b = buttons[id]
		if b then
			b.Visible = on
		end
	end

	function h.SetBadge(self: Handle, id: string, text: string?)
		local badge = badges[id]
		if badge then
			badge.Visible = text ~= nil
			badge.Text = text or ""
		end
	end

	strip.Parent = o.parent
	return h :: Handle
end

return TabStrip
