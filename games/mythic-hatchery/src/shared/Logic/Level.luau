--!strict
local Config = require("../Config")
local Gameplay = require("../Gameplay")
export type Creature = {
	Uid: string, Species: string, Element: string, Rarity: string,
	Level: number, Xp: number, Neon: boolean,
}
local Level = {}
function Level.IsFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end
function Level.XpToNext(level: number): number
	assert(Level.IsFinite(level) and level >= 1 and level <= Gameplay.MaxLevel, "Invalid level")
	return math.floor(Gameplay.XpBase * Gameplay.XpGrowth ^ (math.floor(level) - 1))
end
function Level.Power(c: Creature): number
	local rarity = Config.RarityPower[c.Rarity]
	assert(rarity ~= nil, "Unknown rarity")
	assert(Level.IsFinite(c.Level) and c.Level >= 1 and c.Level <= Gameplay.MaxLevel and c.Level % 1 == 0, "Invalid level")
	return rarity * (1 + (c.Level - 1) * Gameplay.LevelPowerPerLevel)
end
function Level.AddXp(c: Creature, amount: number): boolean
	if not Level.IsFinite(amount) or amount < 0 then return false end
	amount = math.floor(amount)
	if c.Level >= Gameplay.MaxLevel then c.Xp = 0; return true end
	c.Xp += amount
	while c.Level < Gameplay.MaxLevel and c.Xp >= Level.XpToNext(c.Level) do
		c.Xp -= Level.XpToNext(c.Level)
		c.Level += 1
	end
	if c.Level >= Gameplay.MaxLevel then c.Xp = 0 end
	return true
end
return Level
