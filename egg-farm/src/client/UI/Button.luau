--!strict
-- Chunky game button: rounded, thick outline, top-light gradient, darker "lip" underneath,
-- press squish. Works with touch and mouse (Activated). Minimum size is Theme.Size.Touch.

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Icon = require(script.Parent.Icon)

local Button = {}

-- Set by Controllers/Sound so every button clicks without the kit knowing about audio.
Button.ClickHook = nil :: (() -> ())?

export type Opts = {
	text: string?,
	color: Color3?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	icon: string?,
	iconSize: number?,
	textSize: number?,
	textColor: Color3?,
	order: number?,
	parent: Instance?,
	name: string?,
	onClick: (() -> ())?,
	radius: number?,
	z: number?,
}

export type Handle = {
	Instance: TextButton,
	Label: TextLabel,
	Icon: Frame?,
	SetText: (Handle, string) -> (),
	SetColor: (Handle, Color3) -> (),
	SetEnabled: (Handle, boolean) -> (),
	SetVisible: (Handle, boolean) -> (),
	Enabled: boolean,
	Color: Color3,
}

function Button.new(o: Opts): Handle
	local color = o.color or Theme.Color.Green
	local b = Instance.new("TextButton")
	b.Name = o.name or "Button"
	b.AutoButtonColor = false
	b.Text = ""
	b.Active = true
	b.BackgroundColor3 = color
	b.Size = o.size or UDim2.fromOffset(160, Theme.Size.Touch)
	b.Position = o.position or UDim2.new()
	b.AnchorPoint = o.anchor or Vector2.zero
	b.LayoutOrder = o.order or 0
	b.ZIndex = o.z or 1
	Util.Corner(b, o.radius)
	Util.Stroke(b, Theme.Size.Stroke, Theme.Color.Ink, true)
	Util.Gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(210, 210, 210))
	local min = Instance.new("UISizeConstraint")
	min.MinSize = Vector2.new(Theme.Size.Touch * 0.75, Theme.Size.Touch * 0.75)
	min.Parent = b

	-- darker lip along the bottom edge
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.BorderSizePixel = 0
	lip.BackgroundColor3 = Theme.Darken(color, 0.3)
	lip.AnchorPoint = Vector2.new(0.5, 1)
	lip.Position = UDim2.new(0.5, 0, 1, 0)
	lip.Size = UDim2.new(1, 0, 0, 6)
	lip.ZIndex = b.ZIndex
	Util.Corner(lip, o.radius)
	lip.Parent = b

	local iconFrame: Frame? = nil
	local hasText = o.text ~= nil and o.text ~= ""
	if o.icon then
		local isz = o.iconSize or 34
		local ic = Icon.new(o.icon, isz)
		ic.AnchorPoint = Vector2.new(0, 0.5)
		ic.Position = if hasText then UDim2.new(0, 8, 0.5, -2) else UDim2.new(0.5, -isz / 2, 0.5, -2)
		ic.ZIndex = b.ZIndex + 1
		ic.Parent = b
		iconFrame = ic
	end
	local textLeft = if o.icon and hasText then (o.iconSize or 34) + 12 else 8
	local label = Util.Text({
		text = o.text or "",
		size = UDim2.new(1, -(textLeft + 8), 1, -10),
		position = UDim2.new(0, textLeft, 0, 2),
		textSize = o.textSize or Theme.Text.L,
		color = o.textColor or Theme.Color.Text,
		font = Theme.Font.Title,
		outline = true,
		z = b.ZIndex + 2,
		parent = b,
	})
	label.Name = "Label"
	label.Visible = hasText

	local h: any = {
		Instance = b,
		Label = label,
		Icon = iconFrame,
		Enabled = true,
		Color = color,
	}

	function h.SetText(self: Handle, text: string)
		self.Label.Text = text
		self.Label.Visible = text ~= ""
	end

	function h.SetColor(self: Handle, c: Color3)
		self.Color = c
		self.Instance.BackgroundColor3 = c
		lip.BackgroundColor3 = Theme.Darken(c, 0.3)
	end

	function h.SetEnabled(self: Handle, on: boolean)
		self.Enabled = on
		self.Instance.Active = true -- still sinks input; taps on a disabled button do nothing
		self.Instance.BackgroundTransparency = if on then 0 else 0.15
	end

	function h.SetVisible(self: Handle, on: boolean)
		self.Instance.Visible = on
	end

	local scaleObj = Instance.new("UIScale")
	scaleObj.Parent = b
	b.MouseButton1Down:Connect(function()
		Util.Tween(scaleObj, Theme.Tween.Fast, { Scale = 0.93 })
	end)
	local function release()
		Util.Tween(scaleObj, Theme.Tween.Pop, { Scale = 1 })
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
	local fn = o.onClick
	b.Activated:Connect(function()
		local hook = Button.ClickHook
		if hook then
			hook()
		end
		if fn then
			fn()
		end
	end)
	b.Parent = o.parent
	return h :: Handle
end

return Button
