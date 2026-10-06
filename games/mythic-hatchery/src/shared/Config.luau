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
Config.BreakGemsPerHour = 15 -- per-player cap on gems from breakables (rolling hour)

-- Coins
Config.VipCoinMult = 1.2
Config.CoinBoostMult = 2
Config.PremiumCoinMult = 1.1
Config.RebirthCoinBonus = 1 -- +100% coins per rebirth (additive)

-- Rebirth: resets coins and opened gates; keeps pets, gems, passes.
Config.RebirthBaseCost = 6e9
Config.RebirthCostGrowth = 2
Config.RebirthGems = 150
Config.MaxRebirths = 16 -- cost passes the coin cap (1e15) after this

-- Expeditions
Config.BaseExpeditionSlots = 1
Config.MaxPetsPerExpedition = 3
Config.ExpeditionDurations = {
	{ Key = "Short", Seconds = 5 * 60, Mult = 1, FindChance = 0.04, GemChance = 0.05 },
	{ Key = "Medium", Seconds = 30 * 60, Mult = 5, FindChance = 0.12, GemChance = 0.25 },
	{ Key = "Long", Seconds = 2 * 3600, Mult = 16, FindChance = 0.3, GemChance = 0.5 },
	{ Key = "Epic", Seconds = 8 * 3600, Mult = 50, FindChance = 0.65, GemChance = 1 },
}
Config.ExpeditionCoinsPerPower = 75 -- coins = sum(min(power / area PowerMult, ExpeditionMaxRelPower)) * this * area coin mult * duration mult
Config.ExpeditionMaxRelPower = 12 -- caps strong pets sent to cheap islands
Config.ExpeditionEggChance = 0.35 -- chance (scaled by duration mult, capped at 1) to bring back a free egg
Config.ExpeditionGems = { 3, 15 } -- gem range when GemChance hits (scaled by sqrt(duration mult))
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
Config.PlaytimeGifts = { -- minutes played today (UTC day) -> reward, each once per day
	{ Minutes = 3, Coins = 300 },
	{ Minutes = 8, Gems = 5 },
	{ Minutes = 15, Coins = 2500 },
	{ Minutes = 25, Gems = 15 },
	{ Minutes = 40, Boost = "Coins2x" },
	{ Minutes = 60, Gems = 25 },
} :: { RewardSpec }
Config.QuestsPerDay = 3
Config.QuestPool = {
	{ Kind = "Break", Goals = { 150, 300, 600 }, Gems = { 15, 25, 40 } },
	{ Kind = "Hatch", Goals = { 20, 50, 100 }, Gems = { 15, 25, 40 } },
	{ Kind = "Expedition", Goals = { 2, 4, 8 }, Gems = { 15, 25, 40 } },
	{ Kind = "Coins", Goals = { 5000, 12000, 25000 } --[[ x CoinMult of highest opened area ]], Gems = { 15, 25, 40 } },
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
	Xp2x = { Seconds = 30 * 60, Name = "2x Pet XP" },
} :: { [string]: { Seconds: number, Name: string } }
Config.ServerLuckSeconds = 15 * 60
Config.MaxBoostSeconds = 24 * 3600

-- Trading
Config.TradeMaxPets = 8
Config.TradeMaxGems = 0 -- pets only (stops alt gem funnelling and real-money gem sales)
Config.TradeConfirmSeconds = 4 -- countdown after both ready; any change cancels it
Config.TradeRequestTimeout = 20
Config.TradeMinAccountAgeDays = 7
Config.TradeCooldown = 10 -- seconds between trade requests from one player

-- Pet Ring (walk-in free-for-all in the Meadow hub; see docs/CONTRACTS.md "Pet Ring").
-- Ring strength = RarityFactor * VariantFactor * ShinyFactor (capped at MaxGearFactor)
--                 * (1 + LevelBonus * (level - 1)).
-- Island power multipliers are ignored here, so levels (time spent) matter most and paid
-- advantages (rarer pets, XP boosts, an extra fighter) help but never exceed ~2x.
Config.Ring = {
	TickSeconds = 0.2, -- server simulation step
	ReplicateSeconds = 0.1, -- fighter attribute updates
	Fighters = 3, -- pets that fight for you (your strongest equipped)
	PassFighters = 1, -- extra fighter with the RingChampion pass
	MoveSpeed = 18, -- studs per second
	AttackRange = 4.5,
	AttackInterval = 0.9,
	BaseHp = 100,
	BaseDamage = 11,
	CritChance = 0.1,
	CritMult = 1.75,
	LevelBonus = 0.06, -- +6% strength per level above 1 (level 25 = 2.44x)
	RarityFactor = { Common = 1, Uncommon = 1.12, Rare = 1.25, Epic = 1.4, Legendary = 1.6, Mythic = 1.8 } :: { [string]: number },
	VariantFactor = { Normal = 1, Golden = 1.1, Rainbow = 1.2 } :: { [string]: number },
	ShinyFactor = 1.05,
	MaxGearFactor = 2, -- cap on rarity * variant * shiny
	EnterGraceSeconds = 2, -- new arrivals can't be hit for this long
	KoTrophies = 1,
	KoCoins = 40, -- x CoinMult of the winner's highest opened island
	XpPerHit = 2,
	XpPerKo = 30,
	SameVictimLimit = 3, -- KO rewards per victim player per window (stops alt farming)
	SameVictimWindow = 600,
	KingMinStreak = 3, -- KOs in a row needed before you can wear the crown
	-- Wild challengers keep the ring fun when you're alone in it.
	WildWhenAlone = true,
	WildDelay = 3, -- seconds alone before a wild pet jumps in
	WildStrength = 0.9, -- relative to the player's average fighter
	WildCoins = 0.25, -- fraction of KoCoins for beating a wild pet; no trophies
}

-- Saving
Config.AutosaveSeconds = 90
Config.SessionLockSeconds = 300 -- a lock older than this is treated as dead
Config.DataStoreName = "PetExpedition_v1"

-- Group bonus (set GroupId to the owner's group to enable; 0 = off)
Config.GroupId = 0
Config.GroupCoinMult = 1.05

return Config
