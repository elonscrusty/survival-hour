--!strict
-- Power-ups (spec): permanent Diamond unlocks; equip ONE before a match (no
-- mid-match buying or swapping). New players: Survivor class + no power-up.

export type Def = {
	Id: string,
	Name: string,
	Price: number, -- Diamonds
	Order: number,
	Glyph: string,
	Color: { number },
	Text: string,
	Effects: { [string]: number },
}

local Perks = {}

Perks.List = {
	{ Id = "StrongBack", Name = "Strong Back", Price = 40, Order = 1, Glyph = "🎒", Color = { 180, 140, 90 }, Text = "+2 pack slots", Effects = { BonusSlots = 2 } },
	{ Id = "Endurance", Name = "Endurance", Price = 50, Order = 2, Glyph = "💨", Color = { 110, 190, 130 }, Text = "+10% max stamina", Effects = { StaminaMax = 0.10 } },
	{ Id = "Toolsmith", Name = "Toolsmith", Price = 60, Order = 3, Glyph = "⚒", Color = { 160, 160, 170 }, Text = "Tools wear 10% slower", Effects = { ToolWear = -0.10 } },
	{ Id = "QuickHeal", Name = "Quick Heal", Price = 75, Order = 4, Glyph = "✚", Color = { 220, 90, 90 }, Text = "Healing takes 10% less time", Effects = { HealSpeed = 0.10 } },
	{ Id = "Runner", Name = "Runner", Price = 90, Order = 5, Glyph = "»", Color = { 90, 200, 220 }, Text = "+5% sprint speed", Effects = { SprintSpeed = 0.05 } },
	{ Id = "Firekeeper", Name = "Firekeeper", Price = 100, Order = 6, Glyph = "🔥", Color = { 240, 150, 60 }, Text = "Wood adds 20% more fire fuel", Effects = { FireFuel = 0.20 } },
	{ Id = "Craftsman", Name = "Craftsman", Price = 125, Order = 7, Glyph = "🔧", Color = { 200, 170, 110 }, Text = "Crafting is 10% faster", Effects = { CraftSpeed = 0.10 } },
	{ Id = "NightOwl", Name = "Night Owl", Price = 150, Order = 8, Glyph = "🦉", Color = { 120, 130, 220 }, Text = "Slightly better night visibility", Effects = { NightSight = 1 } },
	{ Id = "Hardy", Name = "Hardy", Price = 175, Order = 9, Glyph = "🛡", Color = { 140, 120, 90 }, Text = "Take 10% less damage from wildlife", Effects = { WildlifeDamage = -0.10 } },
	{ Id = "SecondWind", Name = "Second Wind", Price = 200, Order = 10, Glyph = "❤", Color = { 240, 110, 150 }, Text = "Once per life, dropping below 25 HP refills stamina and gives +20% speed for 5 s", Effects = { SecondWind = 1 } },
} :: { Def }

Perks.ById = {} :: { [string]: Def }
for _, d in Perks.List do
	Perks.ById[d.Id] = d
end

return Perks
