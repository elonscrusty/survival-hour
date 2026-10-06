--!strict
-- Tuning numbers for Mythic Hatchery. Everything a designer might tweak lives
-- here; pure rules in Logic/ read these values instead of hard-coding them.
-- Content (species, elements, eggs, potions, cosmetics) lives in its own data
-- modules so new content is a data change only.

export type RewardSpec = { Coins: number?, Gems: number?, Boost: string?, Equip: number?, Storage: number?, Minutes: number?, Fraction: number? }

local Config = {}

Config.Version = 1 -- profile schema version (Logic/Profile migrates older saves)

-- Rarities, weakest first. Order matters (index used for sorting, colours and fusion upgrades).
Config.Rarities = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

-- Coin-farming power = RarityPower * StagePower * region TierPower (Areas) * bonuses.
Config.RarityPower = {
	Common = 1,
	Rare = 2,
	Epic = 4,
	Legendary = 8,
	Mythic = 16,
} :: { [string]: number }

-- Rarity colours live in client UI/Theme.luau (Config must stay Roblox-type free for CLI tests).

-- Growth: Baby -> Teen -> Adult -> Ancient. Care tasks give growth points; a stage is reached
-- when the creature's total growth reaches the threshold. Neglect only pauses growth.
Config.Stages = { "Baby", "Teen", "Adult", "Ancient" }
Config.StageGrowth = { Baby = 0, Teen = 6, Adult = 18, Ancient = 48 } :: { [string]: number }
Config.StagePower = { Baby = 1, Teen = 1.6, Adult = 2.5, Ancient = 4 } :: { [string]: number }
Config.StageScale = { Baby = 0.7, Teen = 0.85, Adult = 1, Ancient = 1.25 } :: { [string]: number } -- model size
Config.RideStage = "Adult" -- minimum stage to ride or fly (with the matching potion)
Config.FuseStage = "Adult" -- minimum stage for both fusion parents

-- Care tasks: each can be done once per Cooldown seconds per creature and gives Growth points.
-- Feed costs FeedCost coins x CoinMult of the owner's highest opened region.
Config.Care = {
	Feed = { Cooldown = 15 * 60, Growth = 1 },
	Play = { Cooldown = 25 * 60, Growth = 1 },
	Sleep = { Cooldown = 60 * 60, Growth = 2 },
} :: { [string]: { Cooldown: number, Growth: number } }
Config.CareOrder = { "Feed", "Play", "Sleep" }
Config.FeedCost = 25
Config.CareCooldownMin = 0.5 -- server rate limit between any two care actions (seconds)

-- Inventory
Config.BaseEquip = 3 -- creatures that follow you and farm coins
Config.BaseStorage = 60 -- creatures
Config.MaxEquipCap = 12 -- hard cap after every bonus
Config.EggStorage = 50 -- unhatched eggs
Config.DeleteRefund = 0.1 -- coins refunded = power * this (min 1); "release" a creature

-- Incubation: eggs are bought into the egg bag, then placed in an incubator slot.
Config.BaseHatchSlots = 3
Config.PassHatchSlots = 2 -- "+2 Hatch Slots" game pass
Config.FastIncubationMult = 0.5 -- "2x Incubation" game pass
Config.IncubateSkipGemsPer30s = 1 -- gems to finish early (min IncubateSkipMinGems)
Config.IncubateSkipMinGems = 3
Config.BuyCooldown = 0.5 -- seconds between egg purchases (server-enforced)
Config.HatchAnimSeconds = 3.2

-- Luck multiplies the weight of every rarity above an egg's lowest (Logic/Hatch renormalises).
Config.LuckyPassMult = 1.5
Config.LuckBoostMult = 2
Config.ServerLuckMult = 2
Config.MaxLuckMult = 6

-- Elements: an region's own eggs roll its element with HomeElementWeight%, the rest share
-- the remainder. A creature farming on an region of its element gets ElementBonus.
Config.HomeElementWeight = 60
Config.ElementBonus = 1.25

-- Fusion: two Adult+ creatures (both consumed) -> one fused egg.
Config.Fusion = {
	CoinCost = 500, -- x CoinMult of the owner's highest opened region
	UpgradeChance = 0.35, -- chance the egg's rarity is one tier above the better parent
	SameRarityBonus = 0.1, -- added when both parents share a rarity
	AncientBonus = 0.075, -- added per Ancient parent
	MaxUpgradeChance = 0.75,
	HybridChance = 0.08, -- cross-species pair with a hidden hybrid
	RandomElementChance = 0.1, -- otherwise the egg takes one parent's element at random
	IncubateSeconds = 15 * 60,
}

-- Riding and flying (Adult+ with the Ride or Fly potion). Speeds in studs/second.
Config.Ride = {
	WalkSpeed = 30,
	FlySpeed = 44,
	StageSpeed = { Adult = 0, Ancient = 6 } :: { [string]: number },
	RaritySpeed = 1.5, -- per rarity tier above Common
	NeonSpeed = 0,
	MaxAltitude = 600,
	SpeedTolerance = 1.35, -- server allows this much over the expected speed before correcting
}

-- Sky race (arena floating above the Meadow hub).
Config.Race = {
	QueueSeconds = 15, -- lobby countdown once someone joins
	MaxRacers = 8,
	MinCheckpointSeconds = 0.6, -- fastest legal gap between checkpoints
	TimeLimit = 180,
	Coins = { 400, 250, 150, 100 }, -- by finishing place (then the last value), x CoinMult of highest region
	Trophies = { 3, 2, 1 },
	DailyRewardRaces = 15, -- races per UTC day that pay out (stops AFK farming)
}

-- Breakables / farming
Config.PetDamageInterval = 0.5 -- seconds between pet damage ticks
Config.PetDamagePerPower = 10 -- damage per tick = power * this
Config.MaxTargetDistance = 90 -- studs from player to the breakable they target
Config.BreakableRespawn = { 6, 14 } -- seconds (random in range)
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
Config.ExpeditionMaxRelPower = 12 -- caps strong pets sent to cheap regions
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
	{ Kind = "Fuse", Goals = { 1, 2, 3 }, Gems = { 20, 35, 55 } },
	{ Kind = "Care", Goals = { 10, 25, 50 }, Gems = { 15, 25, 40 } },
	{ Kind = "Race", Goals = { 1, 3, 5 }, Gems = { 15, 25, 40 } },
}
Config.IndexRewards = { -- fraction of Index entries (species x element) discovered -> reward
	{ Fraction = 0.25, Gems = 50, Equip = 1 },
	{ Fraction = 0.5, Gems = 100, Equip = 1 },
	{ Fraction = 0.75, Gems = 200, Storage = 50 },
	{ Fraction = 1, Gems = 500, Equip = 1 },
} :: { RewardSpec }

-- Boost durations (seconds), stack by extending.
Config.Boosts = {
	Coins2x = { Seconds = 30 * 60, Name = "2x Coins" },
	Luck2x = { Seconds = 30 * 60, Name = "2x Luck" },
	Growth2x = { Seconds = 30 * 60, Name = "2x Growth" },
} :: { [string]: { Seconds: number, Name: string } }
Config.ServerLuckSeconds = 15 * 60
Config.MaxBoostSeconds = 24 * 3600

-- Trading
Config.TradeMaxCreatures = 8
Config.VipTradeMaxCreatures = 16 -- VIP Trader pass
Config.VipTradeCooldown = 3
Config.TradeMaxGems = 0 -- creatures only (stops alt gem funnelling and real-money gem sales)
Config.TradeConfirmSeconds = 4 -- countdown after both ready; any change cancels it
Config.TradeRequestTimeout = 20
Config.TradeMinAccountAgeDays = 7
Config.TradeCooldown = 10 -- seconds between trade requests from one player

-- Creature Ring (walk-in free-for-all next to the Meadow hub; see docs/CONTRACTS.md).
-- Ring strength = min(RarityFactor * NeonFactor, MaxGearFactor) * StageFactor * ElementEdge.
-- Island tiers are ignored, so growth (time spent caring) matters most and paid help
-- (rarer creatures, Growth boosts, an extra fighter) never exceeds ~2x.
Config.Ring = {
	TickSeconds = 0.2,
	ReplicateSeconds = 0.1,
	Fighters = 3,
	PassFighters = 1, -- RingChampion pass
	MoveSpeed = 18,
	AttackRange = 4.5,
	AttackInterval = 0.9,
	BaseHp = 100,
	BaseDamage = 11,
	CritChance = 0.1,
	CritMult = 1.75,
	RarityFactor = { Common = 1, Rare = 1.15, Epic = 1.3, Legendary = 1.5, Mythic = 1.75 } :: { [string]: number },
	StageFactor = { Baby = 1, Teen = 1.35, Adult = 1.8, Ancient = 2.4 } :: { [string]: number },
	NeonFactor = 1.05,
	MaxGearFactor = 2,
	ElementEdge = 1.25, -- damage multiplier against the element yours beats (Elements.Beats)
	EnterGraceSeconds = 2,
	KoTrophies = 1,
	KoCoins = 40,
	GrowthPerKo = 0, -- KOs don't grow creatures (growth comes from care)
	SameVictimLimit = 3,
	SameVictimWindow = 600,
	KingMinStreak = 3,
	WildWhenAlone = true,
	WildDelay = 3,
	WildStrength = 0.9,
	WildCoins = 0.25,
}

-- Saving
Config.AutosaveSeconds = 300
Config.SessionLockSeconds = 300 -- a lock older than this is treated as dead
Config.DataStoreName = "MythicHatchery_v1"

-- Group bonus (set GroupId to the owner's group to enable; 0 = off)
Config.GroupId = 0
Config.GroupCoinMult = 1.05

return Config
