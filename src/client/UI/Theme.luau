--!nonstrict
-- Visual language for all Survival Hour interfaces: warm campfire accents on
-- dark, slightly transparent wood-toned panels. High contrast text, and every
-- colour cue is paired with a symbol or label.

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(26, 23, 20),
	PanelLight = Color3.fromRGB(44, 38, 32),
	PanelLighter = Color3.fromRGB(62, 54, 45),
	Stroke = Color3.fromRGB(120, 96, 68),
	Text = Color3.fromRGB(246, 238, 224),
	TextDim = Color3.fromRGB(190, 178, 160),
	Accent = Color3.fromRGB(245, 160, 70),
	AccentDark = Color3.fromRGB(180, 104, 40),
	Good = Color3.fromRGB(112, 210, 120),
	Bad = Color3.fromRGB(235, 88, 78),
	Warn = Color3.fromRGB(240, 200, 80),
	Info = Color3.fromRGB(120, 180, 240),
	Diamond = Color3.fromRGB(120, 220, 255),
	Robux = Color3.fromRGB(90, 200, 120),
	Night = Color3.fromRGB(110, 130, 220),
	Day = Color3.fromRGB(255, 205, 90),
	Dev = Color3.fromRGB(200, 120, 255),
}

Theme.Font = Enum.Font.GothamMedium
Theme.FontBold = Enum.Font.GothamBold
Theme.FontBlack = Enum.Font.GothamBlack

Theme.Corner = UDim.new(0, 10)
Theme.TouchMin = 56 -- px; minimum touch target

Theme.KindColor = {
	info = Theme.Colors.Info,
	success = Theme.Colors.Good,
	gain = Theme.Colors.Good,
	error = Theme.Colors.Bad,
	danger = Theme.Colors.Bad,
	warn = Theme.Colors.Warn,
	dev = Theme.Colors.Dev,
}

Theme.KindGlyph = {
	info = "i",
	success = "✓",
	gain = "+",
	error = "!",
	danger = "‼",
	warn = "!",
	dev = "⚙",
}

return Theme
