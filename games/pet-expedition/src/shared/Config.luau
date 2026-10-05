--!strict
-- Tuning numbers for Pet Expedition. Everything a designer might tweak lives
-- here; pure rules in Logic/ read these values instead of hard-coding them.

export type RewardSpec = { Coins: number?, Gems: number?, Boost: string?, Equip: number?, Storage: number?, Minutes: number?, Fraction: number? }

local Config = {}

Config.Version = 1 -- profile schema version (Logic/Profile migrates older saves)

-- Rarities, weakest first. Order matters (index used for sorting / colours).
Config.Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

Config.RarityPower = {
	Common = 1,
	Uncommon = 1.6,
	Rare = 2.6,
	Epic = 4.5,
	Legendary = 8,
	Mythic = 15,
} :: { [string]: number }

-- Rarity colours live in client UI/Theme.luau (Config must stay Roblox-type free for CLI tests).

-- Pet variants. Power multiplier; crafting N of the previous variant makes one.
Config.Variants = { "Normal", "Golden", "Rainbow" }
Config.VariantPower = { Normal = 1, Golden = 2.5, Rainbow = 6 } :: { [string]: number }
Config.CraftCost = 5 -- pets of the same species+variant consumed per craft
Config.CraftSuccess = { Golden = 1, Rainbow = 1 } :: { [string]: number } -- always succeeds (no gambling)
Config.ShinyChance = 1 / 150 -- rolled on every hatch / expedition find
Config.ShinyPower = 1.5

-- Pet levels: pets earn XP while breaking things.
Config.PetMaxLevel = 25
Config.PetLevelPower = 0.03 -- +3% power per level above 1
Config.PetXpForLevel = function(level: number): number
	return math.floor(20 * level ^ 1.6)
end

-- Inventory
Config.BaseEquip = 3
Config.BaseStorage = 60
Config.MaxEquipCap = 12 -- hard cap after every bonus
Config.DeleteRefund = 0.1 -- coins refunded = power * area coin mult * this (min 1)

-- Hatching
Config.HatchCooldown = 0.9 -- seconds between hatch requests (server-enforced)
Config.HatchAnimSeconds = 3.2
Config.FastHatchAnimSeconds = 1.2
Config.LuckyPassMult = 1.5 -- weight multiplier for Rare and above
Config.LuckBoostMult = 2 -- 2x Luck boost weight multiplier for Rare and above
Config.ServerLuckMult = 2 -- server-wide luck boost (stacks multiplicatively, capped)
Config.MaxLuckMult = 6

-- Breakables / farming
Config.PetDamageInterval = 0.5 -- seconds between pet damage ticks
Config.PetDamagePerPower = 10 -- damage per tick = power * this
Config.MaxTargetDistance = 90 -- studs from player to the breakable they target
Config.BreakableRespawn = { 6, 14 } -- seconds (random in range)
Config.XpPerBreak = 4

-- Coins
Config.VipCoinMult = 1.2
Config.CoinBoostMult = 2
Config.PremiumCoinMult = 1.1
Config.RebirthCoinBonus = 0.25 -- +25% coins per rebirth (additive)

-- Rebirth: resets coins and opened gates; keeps pets, gems, passes.
Config.RebirthBaseCost = 1e7
Config.RebirthCostGrowth = 3
Config.RebirthGems = 150
Config.MaxRebirths = 50

-- Expeditions
Config.BaseExpeditionSlots = 1
Config.MaxPetsPerExpedition = 3
Config.ExpeditionDurations = {
	{ Key = "Short", Seconds = 5 * 60, Mult = 1, FindChance = 0.04, GemChance = 0.15 },
	{ Key = "Medium", Seconds = 30 * 60, Mult = 5, FindChance = 0.12, GemChance = 0.4 },
	{ Key = "Long", Seconds = 2 * 3600, Mult = 16, FindChance = 0.3, GemChance = 0.8 },
	{ Key = "Epic", Seconds = 8 * 3600, Mult = 50, FindChance = 0.65, GemChance = 1 },
}
Config.ExpeditionCoinsPerPower = 40 -- coins = sum(power) * this * area coin mult * duration mult
Config.ExpeditionEggChance = 0.35 -- chance (scaled by duration mult, capped at 1) to bring back a free egg
Config.ExpeditionGems = { 5, 25 } -- gem range when GemChance hits (scaled by sqrt(duration mult))
Config.ExpeditionSkipGemsPerMinute = 2 -- gems to finish early (min 5)
Config.FastExpeditionMult = 0.75 -- duration multiplier with the Swift Expeditions perk (not sold; reserved)

-- Daily, playtime, quests
Config.DailyRewards = { -- streak day -> reward (loops after the last day)
	{ Coins = 500, Gems = 10 },
	{ Coins = 1500, Gems = 15 },
	{ Coins = 4000, Gems = 25 },
	{ Coins = 10000, Gems = 35 },
	{ Coins = 25000, Gems = 50 },
	{ Coins = 60000, Gems = 75 },
	{ Coins = 150000, Gems = 150, Boost = "Luck2x" },
} :: { RewardSpec }
Config.PlaytimeGifts = { -- minutes in this session -> reward
	{ Minutes = 3, Coins = 300 },
	{ Minutes = 8, Gems = 10 },
	{ Minutes = 15, Coins = 2500 },
	{ Minutes = 25, Gems = 20 },
	{ Minutes = 40, Boost = "Coins2x" },
	{ Minutes = 60, Gems = 40 },
} :: { RewardSpec }
Config.QuestsPerDay = 3
Config.QuestPool = {
	{ Kind = "Break", Goals = { 150, 300, 600 }, Gems = { 15, 25, 40 } },
	{ Kind = "Hatch", Goals = { 20, 50, 100 }, Gems = { 15, 25, 40 } },
	{ Kind = "Expedition", Goals = { 2, 4, 8 }, Gems = { 15, 25, 40 } },
	{ Kind = "Coins", Goals = { 50000, 250000, 1000000 }, Gems = { 15, 25, 40 } },
	{ Kind = "Craft", Goals = { 1, 2, 4 }, Gems = { 20, 35, 55 } },
}
Config.IndexRewards = { -- fraction of species discovered -> reward
	{ Fraction = 0.25, Gems = 50, Equip = 1 },
	{ Fraction = 0.5, Gems = 100, Equip = 1 },
	{ Fraction = 0.75, Gems = 200, Storage = 50 },
	{ Fraction = 1, Gems = 500, Equip = 1 },
} :: { RewardSpec }

-- Boost durations (seconds), stack by extending.
Config.Boosts = {
	Coins2x = { Seconds = 30 * 60, Name = "2x Coins" },
	Luck2x = { Seconds = 30 * 60, Name = "2x Luck" },
} :: { [string]: { Seconds: number, Name: string } }
Config.ServerLuckSeconds = 15 * 60
Config.MaxBoostSeconds = 24 * 3600

-- Trading
Config.TradeMaxPets = 8
Config.TradeMaxGems = 100000
Config.TradeConfirmSeconds = 4 -- countdown after both ready; any change cancels it
Config.TradeRequestTimeout = 20
Config.TradeMinAccountAgeDays = 3
Config.TradeCooldown = 10 -- seconds between trade requests from one player

-- Saving
Config.AutosaveSeconds = 90
Config.SessionLockSeconds = 300 -- a lock older than this is treated as dead
Config.DataStoreName = "PetExpedition_v1"

-- Group bonus (set GroupId to the owner's group to enable; 0 = off)
Config.GroupId = 0
Config.GroupCoinMult = 1.05

return Config
