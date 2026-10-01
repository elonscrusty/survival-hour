--!strict
-- Colours, fonts and sizes for every screen. All sizes are LOGICAL pixels: the UIScale on each
-- root (UI/Layout) turns them into screen pixels, so a 60 px button stays >= 44 px on phones.

local Theme = {}

local rgb = Color3.fromRGB

Theme.Color = {
	Ink = rgb(43, 30, 22), -- outlines and dark text
	Text = rgb(255, 255, 255),
	TextDark = rgb(58, 42, 30),
	TextMuted = rgb(128, 108, 92),
	Panel = rgb(255, 246, 226),
	PanelEdge = rgb(242, 222, 186),
	Card = rgb(255, 255, 255),
	CardAlt = rgb(250, 238, 214),
	Dim = rgb(0, 0, 0),

	Red = rgb(232, 64, 56),
	RedDark = rgb(170, 34, 34),
	Green = rgb(82, 196, 72),
	GreenDark = rgb(46, 138, 46),
	Blue = rgb(64, 156, 240),
	BlueDark = rgb(36, 96, 186),
	Gold = rgb(255, 196, 40),
	GoldDark = rgb(204, 132, 16),
	Orange = rgb(255, 140, 40),
	Purple = rgb(160, 92, 232),
	PurpleDark = rgb(104, 52, 170),
	Pink = rgb(255, 104, 160),
	Teal = rgb(40, 196, 186),
	Gray = rgb(150, 150, 156),
	GrayDark = rgb(96, 96, 104),
	Cash = rgb(98, 210, 86),
	Bad = rgb(255, 90, 80),
	Good = rgb(120, 240, 110),
}

Theme.Font = {
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.FredokaOne,
	Number = Enum.Font.GothamBlack,
}

Theme.Text = {
	Min = 19, -- 19 logical px * 0.75 (smallest phone scale) ~= 14 px on screen
	S = 19,
	M = 22,
	L = 28,
	XL = 40,
	Huge = 56,
}

Theme.Size = {
	Touch = 60, -- minimum button height / width (>= 44 px at the smallest scale)
	Nav = 68,
	Stroke = 3,
	Radius = 14,
	Gap = 8,
	PanelMax = Vector2.new(780, 560),
}

Theme.Tween = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Med = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

-- Lighter / darker variants for gradients and pressed states.
function Theme.Lighten(c: Color3, a: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), a)
end

function Theme.Darken(c: Color3, a: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), a)
end

return Theme
