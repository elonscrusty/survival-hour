--!nonstrict
-- Survival Hour button kit (docs/ui/button_reference.png).
--
-- Six styles, one look: dark steel plates with a bevel gradient, a coloured
-- rim and a soft outer glow.
--   Buttons.primary  big green call-to-action (ENTER THE REFUGE, READY UP)
--   Buttons.tile     square menu tile: icon + TITLE + subtitle
--   Buttons.round    round mobile action button (ATTACK, AIM/BLOCK, HEAL, SWAP, RUN)
--   Buttons.action   small action button (EQUIP, UNLOCK ◆ 250, BUY ● 500, CLAIM, LOCKED)
--   Buttons.tab      tab (OUTFITS, BACKPACKS...)
--   Buttons.icon     icon-only square (✖, ◀, ▶, +)
-- States (all styles): Normal · Hover/Pressed (green rim + glow) · Disabled
-- (grey, ignores clicks) · Selected/Equipped (gold rim + glow, ✓).
-- Tones pick the resting colour: Neutral, Green, Gold, Red, Blue.

local TweenService = game:GetService("TweenService")

local Theme = require("./Theme")
local Icons = require("./Icons")

local Buttons = {}

-- click sound hook (UI.luau points this at UI.ClickSound)
Buttons.GetClickSound = function(): (() -> ())?
	return nil
end

type Tone = { Top: Color3, Rim: Color3, Text: Color3, Glow: number }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Buttons.Tones = {
	Neutral = { Top = rgb(44, 53, 61), Rim = rgb(88, 100, 110), Text = rgb(236, 240, 242), Glow = 1 },
	Green = { Top = rgb(58, 150, 40), Rim = rgb(134, 255, 90), Text = rgb(255, 255, 255), Glow = 0.55 },
	Gold = { Top = rgb(66, 54, 26), Rim = rgb(242, 193, 78), Text = rgb(255, 231, 160), Glow = 0.5 },
	Red = { Top = rgb(160, 44, 34), Rim = rgb(255, 106, 90), Text = rgb(255, 240, 236), Glow = 0.6 },
	Blue = { Top = rgb(40, 96, 180), Rim = rgb(106, 184, 255), Text = rgb(240, 248, 255), Glow = 0.6 },
	Disabled = { Top = rgb(58, 62, 66), Rim = rgb(92, 96, 100), Text = rgb(138, 142, 146), Glow = 1 },
} :: { [string]: Tone }

local HOVER_RIM = rgb(134, 255, 90)

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className :: any)
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
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

-- Price text: Coins ● gold, Diamonds ◆ cyan, Robux R$.
function Buttons.priceText(kind: string?, amount: number?): string
	if not kind or not amount then
		return ""
	end
	local n = tostring(amount)
	n = string.reverse((string.gsub(string.reverse(n), "(%d%d%d)", "%1,")))
	if string.sub(n, 1, 1) == "," then
		n = string.sub(n, 2)
	end
	if kind == "Coins" then
		return ' <font color="#F2C14E">●</font> ' .. n
	elseif kind == "Diamonds" then
		return ' <font color="#7EE0FF">◆</font> ' .. n
	elseif kind == "Robux" then
		return " R$ " .. n
	end
	return " " .. n
end

-- Applies the kit look to any GuiButton and wires hover/press feedback.
-- Stores Tone/State as attributes so setState/setTone can restyle later.
function Buttons.decorate(b: GuiButton, tone: string?, radius: UDim?)
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b:SetAttribute("Tone", tone or "Neutral")
	b:SetAttribute("State", b:GetAttribute("State") or "Normal")
	if not b:FindFirstChildOfClass("UICorner") then
		new("UICorner", { CornerRadius = radius or UDim.new(0, 8), Parent = b })
	end
	local stroke = b:FindFirstChildOfClass("UIStroke") or new("UIStroke", { Parent = b })
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 2
	stroke.Transparency = 0
	if not b:FindFirstChild("Bevel") then
		new("UIGradient", {
			Name = "Bevel",
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.5, rgb(200, 200, 200)),
				ColorSequenceKeypoint.new(1, rgb(120, 120, 120)),
			}),
			Parent = b,
		})
	end
	if not b:FindFirstChild("Glow") then
		-- a ring just outside the plate: reads as a soft glow and never covers content
		local glow = new("Frame", {
			Name = "Glow",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 8, 1, 8),
			Position = UDim2.fromOffset(-4, -4),
			ZIndex = b.ZIndex,
			Active = false,
			Parent = b,
		}, {
			new("UICorner", { CornerRadius = if radius and radius.Scale > 0 then radius else UDim.new(0, (radius and radius.Offset or 8) + 4) }),
			new("UIStroke", { Thickness = 4, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		glow:SetAttribute("Deco", true)
	end
	Buttons.refresh(b)
	if b:GetAttribute("Wired") then
		return
	end
	b:SetAttribute("Wired", true)
	b.MouseEnter:Connect(function()
		b:SetAttribute("Hover", true)
		Buttons.refresh(b)
	end)
	b.MouseLeave:Connect(function()
		b:SetAttribute("Hover", nil)
		b:SetAttribute("Down", nil)
		Buttons.refresh(b)
		local ps = b:FindFirstChild("Press") :: UIScale?
		if ps then
			ps.Scale = 1
		end
	end)
	-- press feedback: a quick squash to 95% and back
	local press = new("UIScale", { Name = "Press", Parent = b })
	local quick = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	b.MouseButton1Down:Connect(function()
		b:SetAttribute("Down", true)
		Buttons.refresh(b)
		if b:GetAttribute("State") ~= "Disabled" then
			TweenService:Create(press, quick, { Scale = 0.95 }):Play()
		end
	end)
	b.MouseButton1Up:Connect(function()
		b:SetAttribute("Down", nil)
		Buttons.refresh(b)
		TweenService:Create(press, quick, { Scale = 1 }):Play()
	end)
end

-- Recolours a decorated button from its Tone / State / hover attributes.
function Buttons.refresh(b: GuiButton)
	local state = b:GetAttribute("State") or "Normal"
	local toneName = if state == "Disabled" then "Disabled" elseif state == "Selected" then "Gold" else (b:GetAttribute("Tone") or "Neutral")
	local tone = Buttons.Tones[toneName] or Buttons.Tones.Neutral
	local hot = state ~= "Disabled" and (b:GetAttribute("Hover") or b:GetAttribute("Down"))
	local top = tone.Top
	if b:GetAttribute("Down") and state ~= "Disabled" then
		top = top:Lerp(Color3.new(0, 0, 0), 0.25)
	elseif hot then
		top = top:Lerp(Color3.new(1, 1, 1), 0.08)
	end
	b.BackgroundColor3 = top
	b.BackgroundTransparency = 0
	local stroke = b:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if hot and toneName ~= "Red" then HOVER_RIM else tone.Rim
	end
	local glow = b:FindFirstChild("Glow")
	local gs = glow and glow:FindFirstChildOfClass("UIStroke")
	if gs then
		gs.Color = if hot and toneName ~= "Red" then HOVER_RIM else tone.Rim
		gs.Transparency = if hot then 0.45 else tone.Glow
	end
	-- skinned buttons (UI.skin): the image is the plate; hover / press tint it, the rim
	-- only shows when selected or hovered
	local skin = b:FindFirstChild("Skin")
	if skin and skin:IsA("ImageLabel") and skin.IsLoaded then
		b.BackgroundTransparency = 1
		skin.ImageColor3 = if b:GetAttribute("Down") then Color3.fromRGB(190, 190, 190) elseif hot then Color3.new(1, 1, 1) else Color3.fromRGB(232, 232, 232)
		if stroke then
			stroke.Transparency = if state == "Selected" or hot then 0 else 1
		end
		if gs then
			gs.Transparency = 1
		end
	end
	if b:IsA("TextButton") and b.Text ~= "" then
		b.TextColor3 = tone.Text
	end
	for _, d in b:GetDescendants() do
		if d:IsA("TextLabel") and d:GetAttribute("Tinted") then
			d.TextColor3 = if d:GetAttribute("Sub") then tone.Text:Lerp(tone.Top, 0.35) else tone.Text
		end
	end
	b.Active = state ~= "Disabled"
	local ps = b:FindFirstChild("Press") :: UIScale?
	if ps and state ~= "Disabled" then
		ps.Scale = if b:GetAttribute("Down") then 0.95 else 1
	end
end

function Buttons.setState(b: GuiButton, state: string)
	b:SetAttribute("State", state)
	Buttons.refresh(b)
end

function Buttons.setTone(b: GuiButton, tone: string)
	b:SetAttribute("Tone", tone)
	Buttons.refresh(b)
end

local function wireClick(b: GuiButton, onClick: (() -> ())?)
	if not onClick then
		return
	end
	b.Activated:Connect(function()
		if b:GetAttribute("State") == "Disabled" then
			return
		end
		local sfx = Buttons.GetClickSound()
		if sfx then
			sfx()
		end
		onClick()
	end)
end

local function label(parent: Instance, text: string, props: { [string]: any }): TextLabel
	local p = table.clone(props)
	p.BackgroundTransparency = 1
	p.Text = text
	p.Font = p.Font or Theme.FontBlack
	p.TextScaled = if p.TextScaled == nil then true else p.TextScaled
	p.RichText = true
	p.Parent = parent
	local l = new("TextLabel", p)
	l:SetAttribute("Tinted", true)
	return l
end

local function base(className: string, props: { [string]: any }?): { [string]: any }
	local p = props and table.clone(props) or {}
	p.Tone = nil
	p.State = nil
	p.Price = nil
	p.Sub = nil
	p.Glyph = nil
	p.Icon = nil -- uploaded icon key (Shared/IconIds), applied by the builder
	return p
end

--- Big primary button. Returns the button and setter(text, sub?, state?).
function Buttons.primary(text: string, props: { [string]: any }?, onClick: (() -> ())?): (TextButton, (string, string?, string?) -> ())
	local p = base("TextButton", props)
	p.Text = ""
	p.Size = p.Size or UDim2.fromOffset(420, 72)
	local b = new("TextButton", p)
	Buttons.decorate(b, (props and props.Tone) or "Green", UDim.new(0, 12))
	-- pine silhouettes at both ends, like the reference plate
	for _, side in { 0, 1 } do
		local trees = label(b, "▲▲", { Name = "Trees" .. side, Size = UDim2.new(0.16, 0, 0.7, 0), Position = UDim2.new(if side == 0 then 0.02 else 0.82, 0, 0.15, 0), TextTransparency = 0.55, Font = Theme.FontBlack })
		trees:SetAttribute("Tinted", nil)
		trees.TextColor3 = rgb(10, 40, 8)
	end
	local main = label(b, text, { Name = "Main", Size = UDim2.new(0.68, 0, 0.62, 0), Position = UDim2.fromScale(0.16, 0.19), TextStrokeTransparency = 0.5 })
	local sub = label(b, "", { Name = "Sub", Size = UDim2.new(0.6, 0, 0.26, 0), Position = UDim2.fromScale(0.2, 0.66), Font = Theme.FontBold, Visible = false })
	sub:SetAttribute("Sub", true)
	local function set(t: string, s: string?, state: string?)
		main.Text = t
		sub.Text = s or ""
		sub.Visible = s ~= nil and s ~= ""
		main.Size = if sub.Visible then UDim2.new(0.68, 0, 0.48, 0) else UDim2.new(0.68, 0, 0.62, 0)
		main.Position = if sub.Visible then UDim2.fromScale(0.16, 0.12) else UDim2.fromScale(0.16, 0.19)
		b:SetAttribute("State", state or "Normal")
		Buttons.refresh(b)
	end
	set(text, props and props.Sub, props and props.State)
	wireClick(b, onClick)
	return b, set
end

--- Square menu tile: glyph + TITLE + subtitle.
function Buttons.tile(title: string, sub: string?, glyph: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local p = base("TextButton", props)
	p.Text = ""
	p.Size = p.Size or UDim2.fromOffset(104, 104)
	local b = new("TextButton", p)
	Buttons.decorate(b, (props and props.Tone) or "Neutral", UDim.new(0, 10))
	local hasSub = sub ~= nil and sub ~= ""
	local g = label(b, glyph, { Name = "Glyph", Size = UDim2.fromScale(0.8, if hasSub then 0.42 else 0.5), Position = UDim2.fromScale(0.1, 0.08), Font = Theme.FontBlack })
	Icons.Apply(g, props and props.Icon)
	label(b, title, { Name = "Title", Size = UDim2.fromScale(0.9, if hasSub then 0.2 else 0.24), Position = UDim2.fromScale(0.05, if hasSub then 0.52 else 0.64) })
	if hasSub then
		local s = label(b, sub :: string, { Name = "Subtitle", Size = UDim2.fromScale(0.9, 0.15), Position = UDim2.fromScale(0.05, 0.74), Font = Theme.FontBold })
		s:SetAttribute("Sub", true)
	end
	if props and props.State then
		Buttons.setState(b, props.State)
	end
	wireClick(b, onClick)
	return b
end

--- Menu pill: icon on the left, bold title on the right (the lobby menu). With the
--- green pill background uploaded (IconIds UI_Pill) the plate is replaced by it.
function Buttons.pill(title: string, glyph: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local p = base("TextButton", props)
	p.Text = ""
	p.Size = p.Size or UDim2.fromOffset(190, 46)
	local b = new("TextButton", p)
	Buttons.decorate(b, (props and props.Tone) or "Neutral", UDim.new(0.5, 0))
	local h = b.Size.Y.Offset
	local g = label(b, glyph, { Name = "Glyph", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(h * 0.62, h * 0.62), Position = UDim2.new(0, h * 0.34, 0.5, 0), Font = Theme.FontBlack })
	Icons.Apply(g, props and props.Icon)
	local t = label(b, title, { Name = "Title", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, -h * 1.25, 0.46, 0), Position = UDim2.new(0, h * 1.05, 0.5, 0), Font = Theme.FontBlack, TextXAlignment = Enum.TextXAlignment.Left })
	t.TextStrokeTransparency = 0.6
	if props and props.State then
		Buttons.setState(b, props.State)
	end
	wireClick(b, onClick)
	return b
end

--- Round mobile action button (caller wires touch input). Label sits under the disc.
function Buttons.round(glyph: string, text: string, size: number, tone: string, props: { [string]: any }?): TextButton
	local p = base("TextButton", props)
	p.Text = ""
	p.Size = UDim2.fromOffset(size, size)
	local b = new("TextButton", p)
	Buttons.decorate(b, tone, UDim.new(0.5, 0))
	local stroke = b:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 3
	end
	local g = label(b, glyph, { Name = "Glyph", Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.19) })
	Icons.Apply(g, props and props.Icon)
	local cap = label(b, text, { Name = "Caption", Size = UDim2.new(1.4, 0, 0, math.max(12, size * 0.2)), Position = UDim2.new(-0.2, 0, 1, 4), Font = Theme.FontBlack, TextStrokeTransparency = 0.3 })
	cap:SetAttribute("Tinted", nil)
	cap.TextColor3 = Color3.new(1, 1, 1)
	return b
end

--- Small action button, optional price: props.Price = { Kind = "Coins"|"Diamonds"|"Robux", Amount = n }.
--- props.State "Selected" adds ✓; "Locked" shows a padlock (and is disabled).
function Buttons.action(text: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local p = base("TextButton", props)
	local price = props and props.Price
	local state = props and props.State
	local shown = string.upper(text)
	if price then
		shown ..= Buttons.priceText(price.Kind, price.Amount)
	end
	if state == "Selected" then
		shown ..= " ✓"
	elseif state == "Locked" then
		shown = "🔒 " .. shown
	end
	p.Text = shown
	p.RichText = true
	p.Font = p.Font or Theme.FontBlack
	p.TextSize = p.TextSize or 15
	p.Size = p.Size or UDim2.fromOffset(140, 40)
	local b = new("TextButton", p)
	Buttons.decorate(b, (props and props.Tone) or "Green", UDim.new(0, 8))
	if state then
		Buttons.setState(b, if state == "Locked" then "Disabled" else state)
	end
	wireClick(b, onClick)
	return b
end

--- Tab button; selected tabs are gold.
function Buttons.tab(text: string, glyph: string?, selected: boolean, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local p = base("TextButton", props)
	p.Size = p.Size or UDim2.fromOffset(110, 36)
	if glyph then
		p.Text = ""
	else
		p.Text = string.upper(text)
		p.Font = Theme.FontBlack
		p.TextSize = p.TextSize or 13
	end
	local b = new("TextButton", p)
	Buttons.decorate(b, "Neutral", UDim.new(0, 6))
	if glyph then
		local g = label(b, glyph, { Name = "Glyph", Size = UDim2.fromScale(0.8, 0.52), Position = UDim2.fromScale(0.1, 0.06) })
		Icons.Apply(g, props and props.Icon)
		local t = label(b, text, { Name = "Title", Size = UDim2.fromScale(0.92, 0.28), Position = UDim2.fromScale(0.04, 0.64), Font = Theme.FontBold })
		t:SetAttribute("Sub", true)
	end
	Buttons.setState(b, if selected then "Selected" else "Normal")
	wireClick(b, onClick)
	return b
end

--- Icon-only square button (✖ ◀ ▶ +). tone "Red" for close/cancel.
function Buttons.icon(glyph: string, props: { [string]: any }?, onClick: (() -> ())?, tone: string?): TextButton
	local p = base("TextButton", props)
	p.Text = glyph
	p.Font = Theme.FontBlack
	p.TextSize = p.TextSize or 22
	p.Size = p.Size or UDim2.fromOffset(44, 44)
	local b = new("TextButton", p)
	Buttons.decorate(b, tone or "Neutral", UDim.new(0, 8))
	wireClick(b, onClick)
	return b
end

-- Picks a tone from a legacy BackgroundColor3 (so older call sites keep their meaning).
function Buttons.toneFor(color: Color3?): string
	if not color then
		return "Neutral"
	end
	local r, g, bl = color.R * 255, color.G * 255, color.B * 255
	if r > g + 30 and r > bl + 20 and g < 90 then
		return "Red"
	elseif g > r + 20 and g > bl then
		return "Green"
	elseif bl > r + 25 then
		return "Blue"
	elseif r > 150 and g > 90 and bl < 90 then
		return "Gold"
	end
	return "Neutral"
end

return Buttons
