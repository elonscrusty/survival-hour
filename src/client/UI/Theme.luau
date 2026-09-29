--!nonstrict
-- Visual language for all Survival Hour interfaces: warm campfire accents on
-- dark, slightly transparent wood-toned panels. High contrast text, and every
-- colour cue is paired with a symbol or label.

local Theme = {}

Theme.Colors = {
	-- dark steel-slate panels to match the button kit (docs/ui/button_reference.png)
	Panel = Color3.fromRGB(20, 26, 32),
	PanelLight = Color3.fromRGB(30, 38, 46),
	PanelLighter = Color3.fromRGB(44, 54, 64),
	Stroke = Color3.fromRGB(84, 98, 110),
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
	-- green UI kit (uploaded backgrounds) and its drawn fallback
	Forest = Color3.fromRGB(40, 74, 50),
	ForestRim = Color3.fromRGB(96, 150, 92),
	ForestText = Color3.fromRGB(238, 226, 190), -- soft cream, not bright white
	ForestStroke = Color3.fromRGB(18, 36, 22),
}

-- Overall UI size (owner: 20% smaller, then icons back up a bit: 90%). Every ScreenGui scales by this; text scales with it.
Theme.UiScale = 0.9
-- Text is scaled back up (owner: fonts too small after the shrink): text keeps its old size
-- while icons and plates stay 20% smaller.
Theme.TextScale = 1.2

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
