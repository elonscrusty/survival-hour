--!strict
-- UI kit: small helpers for building the whole interface in code.
-- Everything is sized in "reference pixels" (Theme.RefWidth x RefHeight);
-- Kit.autoScale adds a UIScale that fits that canvas to the real screen, so
-- the same layout works on phones, tablets and PC.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require("./Theme")
local Sounds = require("../Core/Sounds")

local Kit = {}

-- Kit.new("Frame", { Size = ..., Parent = ... }, { children })
function Kit.new(className: string, props: { [string]: any }?, children: { any }?): any
	local inst: any = Instance.new(className :: any)
	local parent: Instance? = nil
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

function Kit.corner(radius: (number | UDim)?): any
	local r: UDim
	if typeof(radius) == "UDim" then
		r = radius
	elseif type(radius) == "number" then
		r = UDim.new(0, radius)
	else
		r = Theme.Corner
	end
	return Kit.new("UICorner", { CornerRadius = r })
end

function Kit.stroke(color: Color3?, thickness: number?, transparency: number?): any
	return Kit.new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 3,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

-- Text outline (applies to the text of a TextLabel/TextButton).
function Kit.textStroke(color: Color3?, thickness: number?): any
	return Kit.new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Kit.pad(top: number, right: number?, bottom: number?, left: number?): any
	local r = right or top
	return Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or r),
	})
end

function Kit.list(
	dir: Enum.FillDirection?,
	padding: number?,
	halign: Enum.HorizontalAlignment?,
	valign: Enum.VerticalAlignment?
): any
	return Kit.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Kit.grid(cell: Vector2, padding: number?): any
	local p = padding or 8
	return Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(p, p),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	})
end

-- Vertical gradient that multiplies the background colour (top lighter).
function Kit.shade(amount: number?): any
	local a = amount or 0.25
	return Kit.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - a, 1 - a, 1 - a)),
	})
end

function Kit.gradient(a: Color3, b: Color3, rotation: number?): any
	return Kit.new("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(a, b) })
end

function Kit.tween(inst: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Text label. props may include Color, Size, TextSize, Outline (bool or
-- Color3), Align ("Left"|"Center"|"Right"), Font, Rich.
function Kit.label(text: string, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = if props then table.clone(props) else {}
	local outline = p.Outline
	local align = p.Align
	local color = p.Color
	local rich = p.Rich
	p.Outline = nil
	p.Align = nil
	p.Color = nil
	p.Rich = nil
	p.Text = text
	p.BackgroundTransparency = 1
	p.Font = p.Font or Theme.Font
	p.TextSize = p.TextSize or 20
	p.TextColor3 = color or p.TextColor3 or (if outline then Theme.Colors.TextLight else Theme.Colors.Text)
	p.Size = p.Size or UDim2.new(1, 0, 0, (p.TextSize :: number) + 6)
	p.TextWrapped = if p.TextWrapped == nil then true else p.TextWrapped
	p.RichText = rich == true
	if align == "Left" then
		p.TextXAlignment = Enum.TextXAlignment.Left
	elseif align == "Right" then
		p.TextXAlignment = Enum.TextXAlignment.Right
	end
	local kids: { any } = {}
	if outline then
		table.insert(kids, Kit.textStroke(if typeof(outline) == "Color3" then outline else Theme.Colors.Stroke, 2))
	end
	return Kit.new("TextLabel", p, kids)
end

-- Text label that shrinks to fit its box (TextScaled with a max size).
function Kit.fitLabel(text: string, maxSize: number, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = if props then table.clone(props) else {}
	p.TextScaled = true
	p.TextSize = maxSize
	local l = Kit.label(text, p)
	Kit.new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8, Parent = l })
	return l
end

local function applyTone(b: GuiObject, toneName: string)
	local tone = Theme.Tones[toneName] or Theme.Tones.Blue
	b.BackgroundColor3 = tone.Top
	local rim = b:FindFirstChild("Rim") :: UIStroke?
	if rim then
		rim.Color = tone.Rim
	end
	local label = b:FindFirstChild("Label") :: TextLabel?
	if label then
		label.TextColor3 = tone.Text
		local ts = label:FindFirstChildOfClass("UIStroke")
		if ts then
			ts.Color = tone.Rim
			ts.Enabled = toneName ~= "White"
		end
	end
end

-- Candy button. `text` may contain RichText. Returns the TextButton; the
-- visible text is the child "Label". Use Kit.setButton to change it later.
-- props: Size, Position, AnchorPoint, LayoutOrder, TextSize, Parent, Name, ZIndex.
function Kit.button(text: string, tone: string?, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local p: { [string]: any } = if props then table.clone(props) else {}
	local textSize = p.TextSize or 22
	p.TextSize = nil
	p.Text = ""
	p.AutoButtonColor = false
	p.BorderSizePixel = 0
	p.Size = p.Size or UDim2.fromOffset(160, Theme.TouchMin)
	local b: TextButton = Kit.new("TextButton", p, {
		Kit.corner(12),
		Kit.new("UIStroke", { Name = "Rim", Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }),
		Kit.shade(0.18),
		Kit.new("UIScale", { Name = "Press" }),
		Kit.new("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 1, -6),
			Position = UDim2.fromOffset(6, 2),
			Font = Theme.Font,
			Text = text,
			RichText = true,
			TextScaled = true,
			TextWrapped = true,
			ZIndex = (p.ZIndex or 1) + 1,
		}, {
			Kit.new("UITextSizeConstraint", { MaxTextSize = textSize, MinTextSize = 8 }),
			Kit.textStroke(nil, 2),
		}),
	})
	b:SetAttribute("Tone", tone or "Blue")
	b:SetAttribute("Enabled", true)
	applyTone(b, tone or "Blue")
	local press = b:FindFirstChild("Press") :: UIScale
	b.MouseButton1Down:Connect(function()
		Kit.tween(press, 0.08, { Scale = 0.92 })
	end)
	local function release()
		Kit.tween(press, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
	b.MouseEnter:Connect(function()
		if b:GetAttribute("Enabled") ~= false then
			Kit.tween(press, 0.1, { Scale = 1.04 })
		end
	end)
	if onClick then
		b.Activated:Connect(function()
			if b:GetAttribute("Enabled") == false then
				Sounds.Play("Error")
				return
			end
			Sounds.Play("Click")
			onClick()
		end)
	end
	return b
end

export type ButtonChange = { Text: string?, Tone: string?, Enabled: boolean? }

function Kit.setButton(b: GuiObject, change: ButtonChange)
	if change.Text then
		local label = b:FindFirstChild("Label") :: TextLabel?
		if label then
			label.Text = change.Text
		end
	end
	if change.Tone then
		b:SetAttribute("Tone", change.Tone)
	end
	if change.Enabled ~= nil then
		b:SetAttribute("Enabled", change.Enabled)
	end
	local tone = b:GetAttribute("Tone") :: string?
	applyTone(b, if b:GetAttribute("Enabled") == false then "Grey" else (tone or "Blue"))
end

-- Rounded panel with a dark outline.
function Kit.panel(props: { [string]: any }, children: { any }?): Frame
	local p = table.clone(props)
	p.BackgroundColor3 = p.BackgroundColor3 or Theme.Colors.Panel
	p.BorderSizePixel = 0
	local kids = children or {}
	table.insert(kids, Kit.corner(p.Corner or 14))
	table.insert(kids, Kit.stroke(p.StrokeColor or Theme.Colors.Stroke, p.StrokeThickness or 3))
	p.Corner = nil
	p.StrokeColor = nil
	p.StrokeThickness = nil
	return Kit.new("Frame", p, kids)
end

-- Transparent frame (layout container).
function Kit.box(props: { [string]: any }, children: { any }?): Frame
	local p = table.clone(props)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	return Kit.new("Frame", p, children)
end

function Kit.scroll(props: { [string]: any }, children: { any }?): ScrollingFrame
	local p = table.clone(props)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.ScrollBarThickness = p.ScrollBarThickness or 8
	p.ScrollBarImageColor3 = Theme.Colors.Stroke
	p.ScrollBarImageTransparency = 0.4
	p.CanvasSize = UDim2.new()
	p.AutomaticCanvasSize = p.AutomaticCanvasSize or Enum.AutomaticSize.Y
	p.ScrollingDirection = p.ScrollingDirection or Enum.ScrollingDirection.Y
	p.ElasticBehavior = Enum.ElasticBehavior.Always
	return Kit.new("ScrollingFrame", p, children)
end

-- Progress bar. Returns the frame and a setter(fraction, text?).
function Kit.bar(props: { [string]: any }, fill: Color3): (Frame, (number, string?) -> ())
	local p = table.clone(props)
	p.BackgroundColor3 = Theme.Colors.PanelDark
	p.BorderSizePixel = 0
	local frame: Frame = Kit.new("Frame", p, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(Theme.Colors.Stroke, 2) })
	local inner: Frame = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		Parent = frame,
	}, { Kit.corner(UDim.new(0.5, 0)), Kit.shade(0.2) })
	local label = Kit.fitLabel("", 16, {
		Size = UDim2.fromScale(1, 1),
		Outline = true,
		ZIndex = (p.ZIndex or 1) + 2,
		Parent = frame,
	})
	local function set(frac: number, text: string?)
		local f = math.clamp(if frac ~= frac then 0 else frac, 0, 1)
		inner.Size = UDim2.fromScale(f, 1)
		inner.Visible = f > 0.001
		if text then
			label.Text = text
		end
	end
	return frame, set
end

-- Small rounded pill: icon + text, used for prices, badges and timers.
function Kit.pill(text: string, color: Color3, props: { [string]: any }?): Frame
	local p: { [string]: any } = if props then table.clone(props) else {}
	p.BackgroundColor3 = color
	p.Size = p.Size or UDim2.fromOffset(90, 28)
	local f: Frame = Kit.new("Frame", p, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.stroke(Theme.Darken(color, 0.45), 2),
		Kit.shade(0.15),
	})
	Kit.fitLabel(text, (p.Size :: UDim2).Y.Offset - 8, {
		Name = "Label",
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(5, 0),
		Outline = Theme.Darken(color, 0.5),
		Rich = true,
		Parent = f,
	})
	return f
end

function Kit.setPill(f: Instance, text: string)
	local l = f:FindFirstChild("Label") :: TextLabel?
	if l then
		l.Text = text
	end
end

-- Row of tab buttons. Returns the row and select(name) (which also calls onSelect).
function Kit.tabs(parent: Instance, names: { string }, labels: { [string]: string }?, onSelect: (string) -> ()): (Frame, (string) -> ())
	local row: Frame = Kit.box({
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 56),
		Parent = parent,
	}, { Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left) })
	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for n, b in buttons do
			Kit.setButton(b, { Tone = if n == name then "Blue" else "White" })
		end
		onSelect(name)
	end
	for i, n in names do
		local b = Kit.button(if labels and labels[n] then labels[n] else n, "White", {
			Size = UDim2.fromOffset(150, 52),
			LayoutOrder = i,
			TextSize = 22,
			Parent = row,
		}, function()
			select(n)
		end)
		buttons[n] = b
	end
	return row, select
end

-- Pop-in animation for a newly shown element. Reuses the element's own
-- UIScale when it has one (a GuiObject must never get two UIScales).
function Kit.pop(inst: GuiObject, from: number?)
	local s = inst:FindFirstChildOfClass("UIScale")
	if not s then
		s = Kit.new("UIScale", { Name = "Pop", Parent = inst })
	end
	local scale = s :: UIScale
	local base = 1
	if scale.Name == "AutoScale" then
		local mult = scale:GetAttribute("Mult")
		base = Kit.screenScale() * (if type(mult) == "number" then mult else 1)
	end
	scale.Scale = base * (from or 0.6)
	Kit.tween(scale, 0.25, { Scale = base }, Enum.EasingStyle.Back)
end

-- Removes children except layout helpers.
function Kit.clear(container: Instance)
	for _, c in container:GetChildren() do
		if not (c:IsA("UIListLayout") or c:IsA("UIGridLayout") or c:IsA("UIPadding") or c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient") or c:IsA("UIScale") or c:IsA("UISizeConstraint")) then
			c:Destroy()
		end
	end
end

-- Auto scale ---------------------------------------------------------------

local scales: { [UIScale]: number } = {} -- UIScale -> multiplier

function Kit.screenScale(): number
	local cam = Workspace.CurrentCamera
	local vs = if cam then cam.ViewportSize else Vector2.new(Theme.RefWidth, Theme.RefHeight)
	if vs.X < 2 or vs.Y < 2 then
		return 1
	end
	-- leave room for the Roblox top bar and notches
	local ok, topLeft, bottomRight = pcall(function()
		return GuiService:GetGuiInset()
	end)
	local insetY = if ok and topLeft and bottomRight then (topLeft :: Vector2).Y + (bottomRight :: Vector2).Y else 36
	local h = math.max(100, vs.Y - insetY)
	return math.clamp(math.min(vs.X / Theme.RefWidth, h / Theme.RefHeight), 0.5, 1.4)
end

-- True on small (phone-sized) screens.
function Kit.isSmall(): boolean
	local cam = Workspace.CurrentCamera
	return cam ~= nil and math.min(cam.ViewportSize.X, cam.ViewportSize.Y) < 500
end

local function refreshScales()
	local s = Kit.screenScale()
	for sc, mult in scales do
		sc.Scale = s * mult
	end
end

-- Adds a UIScale that follows the screen size. `mult` tweaks it per element.
function Kit.autoScale(gui: Instance, mult: number?): UIScale
	local m = mult or 1
	local sc: UIScale = Kit.new("UIScale", { Name = "AutoScale", Parent = gui })
	sc:SetAttribute("Mult", m)
	scales[sc] = m
	sc.Destroying:Connect(function()
		scales[sc] = nil
	end)
	sc.Scale = Kit.screenScale() * m
	return sc
end

local camConn: RBXScriptConnection? = nil
local function watchCamera()
	if camConn then
		camConn:Disconnect()
	end
	local cam = Workspace.CurrentCamera
	if cam then
		camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScales)
	end
	refreshScales()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

return Kit
