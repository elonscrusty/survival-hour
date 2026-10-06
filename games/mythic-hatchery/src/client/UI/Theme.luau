--!strict
-- Pet Expedition look: bright, rounded, cheerful. Light cream panels, candy
-- coloured buttons with a darker rim, chunky rounded font with outlines.

local Theme = {}

local rgb = Color3.fromRGB

Theme.Colors = {
	Panel = rgb(250, 247, 240),
	PanelAlt = rgb(236, 242, 252),
	PanelDark = rgb(214, 224, 240),
	Header = rgb(88, 156, 255),
	HeaderDark = rgb(48, 104, 210),
	Stroke = rgb(44, 58, 96),
	Text = rgb(40, 46, 74),
	TextDim = rgb(110, 118, 146),
	TextLight = rgb(255, 255, 255),
	Backdrop = rgb(18, 22, 40),
	Coins = rgb(255, 205, 50),
	Gems = rgb(90, 220, 255),
	Good = rgb(76, 200, 90),
	Bad = rgb(240, 84, 84),
	Info = rgb(88, 156, 255),
	Warn = rgb(255, 176, 50),
	Luck = rgb(90, 220, 120),
	Locked = rgb(150, 156, 170),
}

-- Rarity colours (Config.Rarities order).
Theme.Rarity = {
	Common = rgb(170, 176, 186),
	Uncommon = rgb(88, 204, 92),
	Rare = rgb(64, 150, 255),
	Epic = rgb(170, 90, 255),
	Legendary = rgb(255, 196, 40),
	Mythic = rgb(255, 64, 110),
} :: { [string]: Color3 }

Theme.Variant = {
	Normal = rgb(255, 255, 255),
	Golden = rgb(255, 200, 40),
	Rainbow = rgb(255, 120, 200),
} :: { [string]: Color3 }

-- Button tones: Top (face colour) and Rim (outline / darker shade).
export type Tone = { Top: Color3, Rim: Color3, Text: Color3 }
Theme.Tones = {
	Green = { Top = rgb(90, 214, 96), Rim = rgb(36, 132, 48), Text = rgb(255, 255, 255) },
	Blue = { Top = rgb(80, 164, 255), Rim = rgb(32, 92, 196), Text = rgb(255, 255, 255) },
	Yellow = { Top = rgb(255, 204, 60), Rim = rgb(196, 128, 16), Text = rgb(255, 255, 255) },
	Red = { Top = rgb(255, 96, 96), Rim = rgb(176, 40, 52), Text = rgb(255, 255, 255) },
	Purple = { Top = rgb(176, 108, 255), Rim = rgb(100, 48, 186), Text = rgb(255, 255, 255) },
	Pink = { Top = rgb(255, 120, 190), Rim = rgb(186, 48, 120), Text = rgb(255, 255, 255) },
	Cyan = { Top = rgb(70, 214, 236), Rim = rgb(20, 128, 160), Text = rgb(255, 255, 255) },
	White = { Top = rgb(255, 255, 255), Rim = rgb(150, 164, 196), Text = rgb(40, 46, 74) },
	Grey = { Top = rgb(176, 182, 196), Rim = rgb(110, 116, 132), Text = rgb(255, 255, 255) },
} :: { [string]: Tone }

Theme.Font = Enum.Font.FredokaOne
Theme.FontBody = Enum.Font.GothamBold
Theme.FontLight = Enum.Font.GothamMedium

Theme.Corner = UDim.new(0, 14)
Theme.TouchMin = 60 -- reference px; with UIScale ~0.7 on phones this is ~42 pt

-- Reference canvas the UI is designed for; UIScale shrinks/grows from here.
Theme.RefWidth = 900
Theme.RefHeight = 560

Theme.Icons = {
	Coins = "🪙",
	Gems = "💎",
	Pets = "🐾",
	Shop = "🛒",
	Expeditions = "🧭",
	Quests = "📜",
	Index = "📖",
	Trade = "🤝",
	Settings = "⚙️",
	Islands = "🗺️",
	Rebirth = "🌀",
	Craft = "⚒️",
	Luck = "🍀",
	Lock = "🔒",
	Equipped = "✅",
	Shiny = "✨",
	Close = "✕",
	Star = "⭐",
	Gift = "🎁",
	Clock = "⏱️",
	Boost = "⚡",
	Egg = "🥚",
}

function Theme.RarityColor(rarity: string): Color3
	return Theme.Rarity[rarity] or Theme.Rarity.Common
end

-- Darker shade for strokes and gradients.
function Theme.Darken(c: Color3, amount: number?): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount or 0.35)
end

function Theme.Lighten(c: Color3, amount: number?): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount or 0.35)
end

return Theme
