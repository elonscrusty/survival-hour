--!strict
-- Shared data shapes (see docs/CONTRACTS.md for the full contract).

export type Creature = {
	Uid: string, -- unique per creature, never reused (traded creatures get a new uid)
	Species: string, -- Species id (may be a hybrid)
	Rarity: string, -- Config.Rarities
	Element: string, -- Elements id
	Tier: number, -- island index it hatched on (fused: the better parent's); sets farming power
	Growth: number, -- growth points; stage derives from Config.StageGrowth
	Stage: string, -- cached from Growth (Logic/Growth.StageFor), sent to clients for convenience
	Care: { [string]: number }, -- care task -> os.time it was last done
	Potions: { [string]: boolean }, -- Ride / Fly / Neon
	Cosmetics: { [string]: string }, -- slot -> cosmetic id (must be owned by the current owner)
	Edition: string?, -- Limited egg edition tag (collectible, kept through trades)
	Name: string?, -- player nickname (filtered with TextService; server-only set)
	Locked: boolean, -- locked creatures can't be released, fused or traded
	HatchedAt: number,
}

-- An egg in the bag or in an incubator.
export type EggItem = {
	Uid: string,
	Egg: string, -- Eggs id
	Tier: number, -- island tier the creature will get
	-- Fused eggs carry their pre-rolled odds/parents (Logic/Fusion); nil for shop eggs.
	Fused: {
		Rarity: { { Id: string, Weight: number } },
		Species: { { Id: string, Weight: number } },
		Element: { { Id: string, Weight: number } },
		Hybrid: string?,
		HybridChance: number,
	}?,
}

export type Incubator = {
	Egg: EggItem,
	StartAt: number, -- os.time
	EndAt: number,
	Seed: number, -- hatch roll fixed when the egg goes in (no re-rolls)
}

export type Expedition = {
	Area: string,
	Duration: string, -- Config.ExpeditionDurations[i].Key
	Creatures: { string }, -- uids (busy until claimed)
	StartAt: number,
	EndAt: number,
	Seed: number,
}

export type Reward = {
	Coins: number?,
	Gems: number?,
	Creatures: { Creature }?,
	Eggs: { EggItem }?,
	Boost: string?,
	Equip: number?,
	Storage: number?,
}

export type Quest = {
	Kind: string,
	Goal: number,
	Progress: number,
	Gems: number,
	Claimed: boolean,
}

-- What the client receives (Net "State"). Server-only fields are stripped.
export type PlayerState = {
	Coins: number,
	Gems: number,
	Rebirths: number,
	CoinMult: number,
	LuckMult: number,
	Areas: { [string]: boolean }, -- opened islands
	Creatures: { Creature },
	Equipped: { string }, -- uids following the player (farming)
	Riding: string?, -- uid of the creature being ridden, if any
	MaxEquip: number,
	MaxStorage: number,
	EggBag: { EggItem },
	Incubators: { [string]: Incubator }, -- key = tostring(slot)
	HatchSlots: number,
	Cosmetics: { [string]: boolean }, -- owned
	Expeditions: { [string]: Expedition },
	ExpeditionSlots: number,
	Passes: { [string]: boolean },
	Boosts: { [string]: number },
	ServerLuckUntil: number,
	Index: { [string]: boolean }, -- "Species|Element" discovered
	IndexClaimed: { [string]: boolean },
	Daily: { Streak: number, LastDay: number, CanClaim: boolean },
	Quests: { Quest },
	Playtime: { SessionMinutes: number, Claimed: { [string]: boolean } },
	Stats: { Hatched: number, Broken: number, Expeditions: number, CoinsEarned: number, Fused: number, Cared: number, Races: number, RaceWins: number, BestLap: number, Trophies: number, RingKOs: number, BestStreak: number },
	Settings: { [string]: any },
	RebirthCost: number,
	CanBuyGemEggs: boolean, -- false when PolicyService restricts paid random items
	CanTrade: boolean,
	ServerTime: number,
}

export type TradeSide = { UserId: number, Name: string, Creatures: { Creature }, Gems: number, Ready: boolean, Vip: boolean }
export type TradeView = {
	Id: string,
	Me: TradeSide,
	Them: TradeSide,
	MaxCreatures: number, -- this player's own offer limit
	Countdown: number?,
	Status: string, -- "Open" | "Confirming" | "Done" | "Cancelled"
}

export type RaceView = {
	Id: string,
	Status: string, -- "Queue" | "Countdown" | "Running" | "Done"
	StartsAt: number?, -- workspace:GetServerTimeNow() when the race starts
	Racers: { { UserId: number, Name: string, Checkpoint: number, Finished: number? } },
	Checkpoints: number,
}

return {}
