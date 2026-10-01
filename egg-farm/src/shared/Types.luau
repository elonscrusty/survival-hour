--!strict
-- The shared contract between server, client and tests.
--   FarmState    : the saved, server-owned record of one player's farm (plain tables only, so it
--                  can be stored by ProfileStore). Only the server ever writes it.
--   FarmAction   : what a client may ASK for. It names an intent and, where it matters, the level
--                  the client believes is current (`expect`) so double taps and stale menus are
--                  rejected instead of buying twice. It never carries prices, rewards or balances.
--   FarmSnapshot : what the owner's client is shown. Derived from FarmState + modifiers.
-- Field-by-field reset/keep rules for rebirth and prestige are in Logic/Progression.luau.

export type HouseSlot = {
	tier: number, -- 0 = slot not bought yet
	eggs: number, -- whole eggs stored, waiting to be collected
	partial: number, -- fraction of the next egg (0 <= partial < 1)
}

export type VehicleSlot = {
	tier: number, -- 0 = empty slot
	load: number, -- eggs aboard (left the warehouse, not sold yet)
	phase: string, -- "dock" | "out" | "back"
	t: number, -- seconds spent in the current phase
}

export type WorkerSlot = {
	tier: number, -- 0 = not hired
	load: number, -- eggs carried (left a house, not deposited yet)
	t: number, -- seconds into the current cycle
	house: number, -- house slot targeted this cycle
}

export type ActiveBoost = { id: string, endsAt: number }

export type Settings = {
	music: boolean,
	sfx: boolean,
	autoSpawn: boolean,
	effects: boolean,
	flock: string, -- "low" | "normal" | "high" visible chickens
	notation: string, -- "short" | "scientific"
	confirmSpend: boolean, -- ask before Gold Egg purchases
}

export type FarmState = {
	version: number,
	createdAt: number,
	lastSeen: number, -- server time of the last save/step (offline earnings)
	cash: number,
	gold: number,
	stars: number, -- Star Eggs from prestige (permanent multiplier)
	population: number,
	hatchPartial: number,
	egg: number, -- current egg index (Data/Eggs)
	rebirths: number,
	prestiges: number,
	invested: number, -- cash spent on this farm (part of Farm Value)
	housing: { HouseSlot },
	carried: number,
	warehouse: number,
	vehicles: { VehicleSlot },
	workers: { WorkerSlot },
	silos: number,
	common: { [string]: number },
	epic: { [string]: number },
	boosts: { inventory: { [string]: number }, active: { ActiveBoost } },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
	daily: { streak: number, lastDay: number },
	gifts: { day: number, playtime: number, claimed: { [string]: boolean } }, -- keys "1".."6"
	codes: { [string]: boolean },
	settings: Settings,
	tutorial: { step: number, done: boolean },
	passes: { [string]: boolean },
	receipts: { [string]: number }, -- processed purchase ids -> time (replay protection)
	offline: { pending: number, seconds: number }, -- silo earnings waiting to be claimed
	stats: { [string]: number }, -- lifetime counters (spawned, laid, collected, deposited, sold, cashEarned, discarded, ...)
}

-- Every action a client can request. `seq` is a per-session increasing number: the server drops
-- anything not newer than the last one it handled (replays and duplicates).
export type FarmAction = {
	type: string,
	seq: number?,
	slot: number?, -- housing / vehicle / worker slot
	expect: number?, -- level/tier the client believes is current
	id: string?, -- upgrade / boost / quest / product id
	index: number?, -- gift index
	text: string?, -- code text
	value: any?, -- setting value
}

export type ActionResult = { ok: boolean, code: string, message: string? }

export type FarmSnapshot = {
	serverNow: number,
	cash: number,
	gold: number,
	stars: number,
	population: number,
	capacity: number,
	egg: number,
	eggValue: number,
	farmValue: number,
	nextRequirement: number,
	canRebirth: boolean,
	canPrestige: boolean,
	skipCost: number,
	rebirths: number,
	prestiges: number,
	combo: number, -- cash multiplier from tapping (1 = none)
	comboMax: number,
	spawnPerTap: number,
	autoSpawnRate: number,
	rates: { lay: number, hatch: number, ship: number, workers: number, cash: number },
	mods: { [string]: number },
	housing: { { tier: number, eggs: number, storage: number, capacity: number, occupants: number } },
	carried: number,
	carryCap: number,
	warehouse: number,
	vehicles: { { tier: number, load: number, phase: string, t: number, trip: number, cap: number } },
	vehicleSlots: number,
	workers: { { tier: number, load: number, t: number, cycle: number, house: number } },
	workerSlots: number,
	silos: number,
	permanentSilos: number,
	common: { [string]: number },
	epic: { [string]: number },
	boosts: { inventory: { [string]: number }, active: { ActiveBoost }, maxActive: number },
	quests: { day: number, list: { { id: string, progress: number, target: number, claimed: boolean } } },
	daily: { streak: number, canClaim: boolean, nextDay: number, resetsIn: number },
	gifts: { playtime: number, claimed: { [string]: boolean } },
	settings: Settings,
	tutorial: { step: number, done: boolean },
	passes: { [string]: boolean },
	offline: { pending: number, seconds: number },
	walkSpeed: number,
}

return {}
