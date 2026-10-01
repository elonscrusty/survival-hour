--!strict
-- Original icons drawn natively (Frames + UICorner + UIGradient + UIStroke + glyph labels).
-- No uploaded images. Icon.new(kind, size) returns a transparent Frame of `size` logical px;
-- every shape inside is positioned in scale units so the icon resizes cleanly.

local Theme = require(script.Parent.Theme)

local Icon = {}

local rgb = Color3.fromRGB
local INK = Theme.Color.Ink

type Shape = {
	c: Color3, -- colour
	x: number, -- centre x (0..1)
	y: number, -- centre y (0..1)
	w: number,
	h: number,
	r: number?, -- corner radius as scale (0.5 = round), default 0.2
	rot: number?,
	stroke: boolean?, -- default true
	z: number?,
	glyph: string?, -- text drawn instead of a filled shape
	tc: Color3?, -- glyph colour
	ring: boolean?, -- transparent fill with a thick outline (handles, rings)
	grad: boolean?, -- default true
}

local function S(c: Color3, x: number, y: number, w: number, h: number, extra: { [string]: any }?): Shape
	local s: any = { c = c, x = x, y = y, w = w, h = h }
	if extra then
		for k, v in extra do
			s[k] = v
		end
	end
	return s
end

local function egg(c: Color3, x: number?, y: number?, sc: number?): Shape
	local k = sc or 1
	return S(c, x or 0.5, y or 0.52, 0.66 * k, 0.86 * k, { r = 0.5 })
end

local CASH = rgb(98, 200, 80)
local GOLD = rgb(255, 200, 40)
local CREAM = rgb(255, 244, 220)
local BROWN = rgb(150, 98, 58)
local RED = rgb(220, 70, 56)
local BLUE = rgb(70, 150, 235)
local YELLOW = rgb(255, 214, 60)
local ORANGE = rgb(255, 140, 40)
local PURPLE = rgb(168, 96, 236)
local GREEN = rgb(80, 190, 90)
local GRAY = rgb(160, 160, 170)
local WHITE = rgb(255, 255, 255)

local DEFS: { [string]: { Shape } } = {
	egg = { egg(CREAM) },
	gold = { egg(GOLD), S(WHITE, 0.38, 0.34, 0.14, 0.2, { r = 0.5, stroke = false, grad = false, z = 3 }) },
	star = { S(GOLD, 0.5, 0.5, 1, 1, { glyph = "★", tc = GOLD }) },
	cash = {
		S(CASH, 0.5, 0.5, 0.92, 0.62, { r = 0.15, rot = -10 }),
		S(CASH, 0.5, 0.5, 0.5, 0.5, { glyph = "$", tc = WHITE, z = 3, rot = -10 }),
	},
	chick = {
		S(YELLOW, 0.5, 0.56, 0.78, 0.78, { r = 0.5 }),
		S(ORANGE, 0.82, 0.55, 0.2, 0.2, { rot = 45, r = 0.15, z = 1 }),
		S(INK, 0.62, 0.44, 0.1, 0.1, { r = 0.5, stroke = false, grad = false, z = 3 }),
		S(rgb(255, 180, 40), 0.36, 0.64, 0.34, 0.2, { r = 0.5, z = 3 }),
	},
	house = {
		S(RED, 0.5, 0.42, 0.62, 0.62, { rot = 45, r = 0.08, z = 1 }),
		S(rgb(240, 220, 180), 0.5, 0.7, 0.72, 0.5, { r = 0.06, z = 2 }),
		S(BROWN, 0.5, 0.78, 0.22, 0.34, { r = 0.1, z = 3 }),
	},
	truck = {
		S(BLUE, 0.38, 0.48, 0.62, 0.46, { r = 0.1 }),
		S(RED, 0.8, 0.56, 0.3, 0.32, { r = 0.15 }),
		S(rgb(190, 230, 255), 0.84, 0.5, 0.14, 0.12, { r = 0.2, stroke = false, z = 3 }),
		S(rgb(60, 60, 70), 0.28, 0.8, 0.22, 0.22, { r = 0.5, z = 3 }),
		S(rgb(60, 60, 70), 0.76, 0.8, 0.22, 0.22, { r = 0.5, z = 3 }),
	},
	worker = {
		S(BLUE, 0.5, 0.76, 0.62, 0.44, { r = 0.3 }),
		S(rgb(255, 214, 170), 0.5, 0.4, 0.42, 0.42, { r = 0.5, z = 2 }),
		S(YELLOW, 0.5, 0.2, 0.5, 0.16, { r = 0.4, z = 3 }),
	},
	silo = {
		S(rgb(200, 210, 220), 0.5, 0.62, 0.5, 0.66, { r = 0.1 }),
		S(RED, 0.5, 0.3, 0.5, 0.4, { r = 0.5, z = 0 }),
		S(rgb(150, 160, 170), 0.5, 0.62, 0.5, 0.06, { stroke = false, grad = false, z = 3 }),
	},
	crown = {
		S(GOLD, 0.5, 0.68, 0.8, 0.34, { r = 0.1, z = 2 }),
		S(GOLD, 0.18, 0.46, 0.22, 0.22, { rot = 45, r = 0.1 }),
		S(GOLD, 0.5, 0.38, 0.26, 0.26, { rot = 45, r = 0.1 }),
		S(GOLD, 0.82, 0.46, 0.22, 0.22, { rot = 45, r = 0.1 }),
		S(RED, 0.5, 0.68, 0.14, 0.14, { r = 0.5, z = 3 }),
	},
	feed = {
		S(rgb(222, 190, 130), 0.5, 0.58, 0.66, 0.74, { r = 0.3 }),
		S(rgb(190, 150, 90), 0.5, 0.22, 0.4, 0.14, { r = 0.4, z = 2 }),
		S(YELLOW, 0.4, 0.62, 0.12, 0.12, { r = 0.5, z = 3 }),
		S(YELLOW, 0.6, 0.56, 0.12, 0.12, { r = 0.5, z = 3 }),
		S(YELLOW, 0.52, 0.76, 0.12, 0.12, { r = 0.5, z = 3 }),
	},
	hatch = {
		egg(CREAM, 0.5, 0.6, 0.85),
		S(YELLOW, 0.5, 0.28, 0.4, 0.4, { r = 0.5, z = 0 }),
		S(INK, 0.56, 0.24, 0.07, 0.07, { r = 0.5, stroke = false, grad = false, z = 3 }),
	},
	booster = {
		S(PURPLE, 0.5, 0.64, 0.66, 0.6, { r = 0.5 }),
		S(rgb(220, 220, 240), 0.5, 0.28, 0.26, 0.3, { r = 0.15, z = 0 }),
		S(BROWN, 0.5, 0.12, 0.3, 0.12, { r = 0.2, z = 1 }),
		S(WHITE, 0.4, 0.56, 0.1, 0.14, { r = 0.5, stroke = false, grad = false, z = 3 }),
	},
	lab = {
		S(GREEN, 0.5, 0.64, 0.66, 0.6, { r = 0.5 }),
		S(rgb(220, 240, 230), 0.5, 0.28, 0.26, 0.3, { r = 0.15, z = 0 }),
		S(WHITE, 0.4, 0.56, 0.1, 0.14, { r = 0.5, stroke = false, grad = false, z = 3 }),
	},
	shine = {
		S(GOLD, 0.5, 0.5, 0.2, 0.9, { r = 0.5 }),
		S(GOLD, 0.5, 0.5, 0.9, 0.2, { r = 0.5 }),
		S(WHITE, 0.5, 0.5, 0.2, 0.2, { r = 0.5, stroke = false, z = 3 }),
	},
	basket = {
		S(INK, 0.5, 0.42, 0.66, 0.6, { r = 0.5, ring = true, z = 0 }),
		S(rgb(196, 140, 80), 0.5, 0.68, 0.86, 0.46, { r = 0.25, z = 2 }),
		S(rgb(150, 100, 56), 0.5, 0.66, 0.86, 0.06, { stroke = false, grad = false, z = 3 }),
	},
	nest = {
		egg(CREAM, 0.32, 0.46, 0.55),
		egg(CREAM, 0.68, 0.46, 0.55),
		egg(CREAM, 0.5, 0.4, 0.6),
		S(BROWN, 0.5, 0.72, 0.9, 0.36, { r = 0.5, z = 3 }),
	},
	clock = {
		S(WHITE, 0.5, 0.5, 0.86, 0.86, { r = 0.5 }),
		S(INK, 0.5, 0.36, 0.08, 0.3, { stroke = false, grad = false, z = 3 }),
		S(INK, 0.6, 0.5, 0.26, 0.08, { stroke = false, grad = false, z = 3 }),
	},
	bunk = {
		S(BROWN, 0.5, 0.5, 0.8, 0.8, { r = 0.1 }),
		S(BLUE, 0.5, 0.32, 0.66, 0.2, { r = 0.2, z = 2 }),
		S(BLUE, 0.5, 0.7, 0.66, 0.2, { r = 0.2, z = 2 }),
	},
	boot = {
		S(BROWN, 0.4, 0.42, 0.34, 0.6, { r = 0.15 }),
		S(BROWN, 0.55, 0.78, 0.64, 0.26, { r = 0.3 }),
	},
	yolk = {
		S(WHITE, 0.5, 0.5, 0.92, 0.8, { r = 0.5 }),
		S(GOLD, 0.48, 0.5, 0.42, 0.42, { r = 0.5, z = 3 }),
	},
	auto = {
		S(INK, 0.5, 0.5, 0.8, 0.8, { r = 0.5, ring = true }),
		S(GREEN, 0.5, 0.5, 0.6, 0.6, { r = 0.5 }),
		S(WHITE, 0.53, 0.5, 0.5, 0.5, { glyph = "▶", tc = WHITE, z = 3 }),
	},
	combo = {
		S(ORANGE, 0.5, 0.5, 0.86, 0.86, { r = 0.3, rot = 45 }),
		S(WHITE, 0.5, 0.5, 0.7, 0.7, { glyph = "x", tc = WHITE, z = 3 }),
	},
	gift = {
		S(RED, 0.5, 0.64, 0.78, 0.56, { r = 0.12 }),
		S(RED, 0.5, 0.36, 0.88, 0.2, { r = 0.15, z = 2 }),
		S(GOLD, 0.5, 0.6, 0.16, 0.64, { stroke = false, z = 3 }),
		S(GOLD, 0.36, 0.18, 0.22, 0.18, { r = 0.5, rot = -20, z = 1 }),
		S(GOLD, 0.64, 0.18, 0.22, 0.18, { r = 0.5, rot = 20, z = 1 }),
	},
	quest = {
		S(rgb(250, 236, 200), 0.5, 0.52, 0.7, 0.86, { r = 0.1 }),
		S(BROWN, 0.5, 0.12, 0.36, 0.14, { r = 0.3, z = 2 }),
		S(GRAY, 0.5, 0.38, 0.46, 0.06, { stroke = false, grad = false, z = 3 }),
		S(GRAY, 0.5, 0.54, 0.46, 0.06, { stroke = false, grad = false, z = 3 }),
		S(GREEN, 0.42, 0.72, 0.3, 0.06, { stroke = false, grad = false, z = 3 }),
	},
	daily = {
		S(WHITE, 0.5, 0.56, 0.84, 0.74, { r = 0.12 }),
		S(RED, 0.5, 0.26, 0.84, 0.22, { r = 0.12, z = 2 }),
		S(INK, 0.5, 0.62, 0.5, 0.5, { glyph = "7", tc = INK, z = 3 }),
	},
	settings = {
		S(GRAY, 0.5, 0.5, 0.24, 0.92, { r = 0.15 }),
		S(GRAY, 0.5, 0.5, 0.24, 0.92, { r = 0.15, rot = 45 }),
		S(GRAY, 0.5, 0.5, 0.24, 0.92, { r = 0.15, rot = 90 }),
		S(GRAY, 0.5, 0.5, 0.24, 0.92, { r = 0.15, rot = 135 }),
		S(GRAY, 0.5, 0.5, 0.66, 0.66, { r = 0.5, z = 2 }),
		S(rgb(80, 80, 90), 0.5, 0.5, 0.26, 0.26, { r = 0.5, z = 3 }),
	},
	shop = {
		S(INK, 0.5, 0.3, 0.42, 0.4, { r = 0.5, ring = true, z = 0 }),
		S(rgb(255, 120, 150), 0.5, 0.62, 0.78, 0.6, { r = 0.15, z = 2 }),
		S(WHITE, 0.5, 0.64, 0.4, 0.4, { glyph = "$", tc = WHITE, z = 3 }),
	},
	lock = {
		S(INK, 0.5, 0.32, 0.44, 0.46, { r = 0.5, ring = true, z = 0 }),
		S(GOLD, 0.5, 0.66, 0.68, 0.5, { r = 0.15, z = 2 }),
		S(INK, 0.5, 0.64, 0.1, 0.18, { r = 0.5, stroke = false, grad = false, z = 3 }),
	},
	code = {
		S(PURPLE, 0.5, 0.5, 0.9, 0.6, { r = 0.15, rot = -8 }),
		S(WHITE, 0.5, 0.5, 0.5, 0.5, { glyph = "#", tc = WHITE, z = 3, rot = -8 }),
	},
	farm = {
		S(RED, 0.5, 0.44, 0.6, 0.6, { rot = 45, r = 0.08, z = 1 }),
		S(RED, 0.5, 0.7, 0.76, 0.52, { r = 0.06, z = 2 }),
		S(WHITE, 0.5, 0.74, 0.3, 0.38, { r = 0.06, z = 3 }),
	},
	upgrades = {
		S(GREEN, 0.5, 0.36, 0.56, 0.56, { rot = 45, r = 0.1 }),
		S(GREEN, 0.5, 0.7, 0.3, 0.46, { r = 0.1, z = 2 }),
	},
	close = { S(WHITE, 0.5, 0.5, 0.9, 0.9, { glyph = "X", tc = WHITE }) },
	back = { S(WHITE, 0.5, 0.5, 0.9, 0.9, { glyph = "<", tc = WHITE }) },
	check = {
		S(GREEN, 0.36, 0.62, 0.18, 0.42, { rot = -45, r = 0.4 }),
		S(GREEN, 0.6, 0.48, 0.18, 0.74, { rot = 40, r = 0.4 }),
	},
	rebirth = {
		S(INK, 0.5, 0.5, 0.9, 0.9, { r = 0.5, ring = true }),
		egg(GOLD, 0.5, 0.52, 0.7),
	},
	prestige = {
		S(PURPLE, 0.5, 0.5, 0.9, 0.9, { r = 0.5 }),
		S(GOLD, 0.5, 0.5, 0.8, 0.8, { glyph = "★", tc = GOLD, z = 3 }),
	},
	skip = {
		S(BLUE, 0.5, 0.5, 0.9, 0.9, { r = 0.5 }),
		S(WHITE, 0.52, 0.5, 0.7, 0.7, { glyph = "»", tc = WHITE, z = 3 }),
	},
	cart = {
		S(INK, 0.5, 0.3, 0.42, 0.4, { r = 0.5, ring = true, z = 0 }),
		S(rgb(255, 120, 150), 0.5, 0.62, 0.78, 0.6, { r = 0.15, z = 2 }),
	},
	music = {
		S(BLUE, 0.36, 0.74, 0.32, 0.26, { r = 0.5 }),
		S(BLUE, 0.48, 0.42, 0.1, 0.62, { r = 0.3 }),
		S(BLUE, 0.62, 0.18, 0.32, 0.12, { r = 0.3, rot = 20 }),
	},
}
DEFS.house_buy = DEFS.house
DEFS.robux = DEFS.gold

function Icon.Has(kind: string): boolean
	return DEFS[kind] ~= nil
end

-- size: logical px (square). kind: see DEFS; unknown kinds draw a plain egg.
function Icon.new(kind: string, size: number?, parent: Instance?): Frame
	local f = Instance.new("Frame")
	f.Name = "Icon_" .. kind
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(size or 40, size or 40)
	local shapes = DEFS[kind] or DEFS.egg
	for i, s in shapes do
		local obj: GuiObject
		if s.glyph then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Text = s.glyph
			t.TextScaled = true
			t.Font = Theme.Font.Number
			t.TextColor3 = s.tc or WHITE
			t.TextStrokeTransparency = 0
			t.TextStrokeColor3 = INK
			obj = t
		else
			local fr = Instance.new("Frame")
			fr.BorderSizePixel = 0
			if s.ring then
				fr.BackgroundTransparency = 1
			else
				fr.BackgroundColor3 = s.c
			end
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(s.r or 0.2, 0)
			c.Parent = fr
			if s.ring then
				local st = Instance.new("UIStroke")
				st.Thickness = 3
				st.Color = s.c
				st.Parent = fr
			elseif s.stroke ~= false then
				local st = Instance.new("UIStroke")
				st.Thickness = 2
				st.Color = INK
				st.Parent = fr
			end
			if not s.ring and s.grad ~= false then
				local g = Instance.new("UIGradient")
				g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
				g.Rotation = 90
				g.Parent = fr
			end
			obj = fr
		end
		obj.AnchorPoint = Vector2.new(0.5, 0.5)
		obj.Position = UDim2.fromScale(s.x, s.y)
		obj.Size = UDim2.fromScale(s.w, s.h)
		obj.Rotation = s.rot or 0
		obj.ZIndex = s.z or 1
		obj.LayoutOrder = i
		obj.Parent = f
	end
	if parent then
		f.Parent = parent
	end
	return f
end

return Icon
