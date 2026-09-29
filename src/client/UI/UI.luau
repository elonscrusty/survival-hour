--!nonstrict
-- Tiny declarative helpers for building Roblox GUIs in code.

local Theme = require("./Theme")
local Buttons = require("./Buttons")
local Icons = require("./Icons")

local UI = {}

-- UI.new("Frame", { Size = ..., Parent = ... }, { children... })
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className :: any)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			elseif type(k) == "string" then
				(inst :: any)[k] = v
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

function UI.corner(radius: UDim?): UICorner
	return UI.new("UICorner", { CornerRadius = radius or Theme.Corner })
end

function UI.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return UI.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UI.list(dir: Enum.FillDirection?, pad: number?, halign: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): UIListLayout
	return UI.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, pad or 6),
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UI.panel(props: { [string]: any }, children: { Instance }?): Frame
	local p = table.clone(props)
	p.BackgroundColor3 = p.BackgroundColor3 or Theme.Colors.Panel
	p.BackgroundTransparency = p.BackgroundTransparency or 0.12
	p.BorderSizePixel = 0
	local kids = children or {}
	table.insert(kids, UI.corner())
	table.insert(kids, UI.stroke())
	return UI.new("Frame", p, kids)
end

-- Puts an uploaded background image (Shared/IconIds `key`, e.g. "UI_Pill") behind a
-- frame's contents. The drawn fill, gradient and outline are dropped only once the image
-- has loaded, so a missing or blocked image leaves the drawn look. Returns true when an
-- image is listed for `key`.
-- `visible` (optional) is the part of the image that is actually drawn (e.g. a pill with
-- transparent margins): the image is enlarged so that part fills the frame.
function UI.skin(frame: GuiObject, key: string, visible: Vector2?): boolean
	if not Icons.Image(key) then
		return false
	end
	local v = visible or Vector2.one
	if not frame:IsA("GuiButton") then
		-- until (or unless) the art loads, use the same forest green instead of grey
		frame.BackgroundColor3 = Theme.Colors.Forest
		local st = frame:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = Theme.Colors.ForestRim
		end
	end
	local il = Instance.new("ImageLabel")
	il.Name = "Skin"
	il.BackgroundTransparency = 1
	il.AnchorPoint = Vector2.new(0.5, 0.5)
	il.Position = UDim2.fromScale(0.5, 0.5)
	il.Size = UDim2.fromScale(1 / v.X, 1 / v.Y)
	il.ScaleType = Enum.ScaleType.Stretch
	il.ZIndex = 0
	il.Parent = frame
	Icons.Bind(il, key, function()
		frame.BackgroundTransparency = 1
		for _, c in frame:GetChildren() do
			if c:IsA("UIStroke") then
				c.Transparency = 1
			elseif c:IsA("UIGradient") then
				c.Enabled = false
			elseif c:IsA("Frame") and c.Name == "Glow" then
				c.Visible = false -- no grey plate or ring around the image
			end
		end
		if frame:IsA("GuiButton") and frame:GetAttribute("Tone") ~= nil then
			Buttons.refresh(frame)
		end
	end)
	return true
end

function UI.text(text: string, props: { [string]: any }?): TextLabel
	local p = props and table.clone(props) or {}
	p.Text = text
	p.BackgroundTransparency = 1
	p.Font = p.Font or Theme.Font
	p.TextColor3 = p.TextColor3 or Theme.Colors.Text
	p.TextSize = p.TextSize or 16
	p.TextWrapped = if p.TextWrapped == nil then true else p.TextWrapped
	p.Size = p.Size or UDim2.new(1, 0, 0, (p.TextSize :: number) + 6)
	p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
	return UI.new("TextLabel", p)
end

-- Button in the Survival Hour kit style (UI/Buttons): steel plate, coloured rim,
-- green hover glow. `props.Tone` (Neutral/Green/Gold/Red/Blue) and `props.State`
-- (Normal/Selected/Disabled) are optional; a legacy BackgroundColor3 still maps
-- to the matching tone. `onClick` receives nothing.
function UI.button(text: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local p = props and table.clone(props) or {}
	local tone = p.Tone or Buttons.toneFor(p.BackgroundColor3)
	local state = p.State
	p.Tone = nil
	p.State = nil
	p.Text = text
	p.Font = p.Font or Theme.FontBold
	p.TextSize = p.TextSize or 16
	p.Size = p.Size or UDim2.new(0, 140, 0, 44)
	local b: TextButton = UI.new("TextButton", p)
	Buttons.decorate(b, tone)
	if state then
		Buttons.setState(b, state)
	end
	if onClick then
		b.Activated:Connect(function()
			if b:GetAttribute("State") == "Disabled" then
				return
			end
			local sfx = UI.ClickSound
			if sfx then
				sfx()
			end
			onClick()
		end)
	end
	return b
end

UI.ClickSound = nil :: (() -> ())?
Buttons.GetClickSound = function()
	return UI.ClickSound
end
UI.Buttons = Buttons

-- Item/powerup icon badge drawn from primitives: shaped background + glyph.
-- `key` (optional) names an uploaded image in Shared/IconIds; it replaces the glyph.
function UI.icon(glyph: string, color: Color3, size: number, shape: string?, key: string?): Frame
	local f = UI.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45),
		BorderSizePixel = 0,
	}, {
		UI.corner(if shape == "Square" then UDim.new(0, math.floor(size * 0.18)) else UDim.new(0.5, 0)),
		UI.new("UIStroke", { Color = color, Thickness = math.max(1.5, size / 22), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		UI.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
		}),
		UI.new("TextLabel", {
			Name = "Glyph",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = glyph,
			TextScaled = true,
			Font = Theme.FontBlack,
			TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55),
		}, { UI.new("UITextSizeConstraint", { MaxTextSize = math.floor(size * 0.62) }) }),
	})
	Icons.Apply(f:FindFirstChild("Glyph") :: TextLabel, key)
	return f
end

-- Horizontal progress bar; returns frame + setter(fraction, text?)
function UI.bar(props: { [string]: any }, fill: Color3): (Frame, (number, string?) -> ())
	local frame = UI.new("Frame", {
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.fromRGB(20, 18, 16),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = props.Parent,
		Name = props.Name,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder or 0,
	}, { UI.corner(UDim.new(0, 6)), UI.stroke(Theme.Colors.Stroke, 1, 0.5) })
	local inner = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = fill, BorderSizePixel = 0, Parent = frame, ZIndex = props.ZIndex }, { UI.corner(UDim.new(0, 6)) })
	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.FontBold,
		TextColor3 = Theme.Colors.Text,
		TextStrokeTransparency = 0.5,
		TextScaled = true,
		Text = "",
		Parent = frame,
		ZIndex = (props.ZIndex or 1) + 1,
	}, { UI.new("UITextSizeConstraint", { MaxTextSize = 16 }), UI.padding(2) })
	local function set(frac: number, text: string?)
		inner.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		if text then
			label.Text = text
		end
	end
	return frame, set
end

function UI.clear(container: Instance, keepClass: { string }?)
	for _, c in container:GetChildren() do
		local keep = false
		if keepClass then
			for _, cls in keepClass do
				if c:IsA(cls) then
					keep = true
				end
			end
		end
		if not keep and not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") and not c:IsA("UICorner") and not c:IsA("UIStroke") then
			c:Destroy()
		end
	end
end

function UI.fmtTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return UI
