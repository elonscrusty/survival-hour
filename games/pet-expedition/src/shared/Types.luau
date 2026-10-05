--!strict
-- Shared data shapes (see docs/CONTRACTS.md for the full contract).

export type PetInstance = {
	Uid: string, -- unique per pet, never reused
	Id: string, -- Pets id
	Variant: string, -- "Normal" | "Golden" | "Rainbow"
	Shiny: boolean,
	Level: number,
	Xp: number,
	Locked: boolean, -- locked pets can't be deleted, crafted or traded
}

export type Expedition = {
	Area: string,
	Duration: string, -- Config.ExpeditionDurations[i].Key
	Pets: { string }, -- uids (busy until claimed)
	StartAt: number, -- os.time()
	EndAt: number,
	Seed: number, -- reward roll seed fixed at start (no re-roll by re-claiming)
}

export type Reward = {
	Coins: number?,
	Gems: number?,
	Pets: { PetInstance }?,
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
	CoinMult: number, -- current total coin multiplier (for UI)
	LuckMult: number, -- current luck multiplier (for UI)
	Areas: { [string]: boolean }, -- opened areas
	Pets: { PetInstance },
	Equipped: { string }, -- uids
	MaxEquip: number,
	MaxStorage: number,
	Expeditions: { [string]: Expedition }, -- key = tostring(slot), slots 1..ExpeditionSlots
	ExpeditionSlots: number,
	Passes: { [string]: boolean },
	Boosts: { [string]: number }, -- key -> expires at (os.time)
	ServerLuckUntil: number, -- os.time, 0 if none
	Index: { [string]: boolean }, -- species discovered
	IndexClaimed: { [string]: boolean }, -- tostring(tier)
	Daily: { Streak: number, LastDay: number, CanClaim: boolean },
	Quests: { Quest },
	Playtime: { SessionMinutes: number, Claimed: { [string]: boolean } }, -- tostring(index)
	Stats: { Hatched: number, Broken: number, Expeditions: number, CoinsEarned: number, Crafted: number },
	Settings: { [string]: any },
	RebirthCost: number,
	CanBuyGemEggs: boolean, -- false when PolicyService restricts paid random items
	CanTrade: boolean,
	ServerTime: number, -- os.time when sent (client clock offset)
}

export type TradeSide = { UserId: number, Name: string, Pets: { PetInstance }, Gems: number, Ready: boolean }
export type TradeView = {
	Id: string,
	Me: TradeSide,
	Them: TradeSide,
	Countdown: number?, -- seconds left once both ready, nil otherwise
	Status: string, -- "Open" | "Confirming" | "Done" | "Cancelled"
}

return {}
