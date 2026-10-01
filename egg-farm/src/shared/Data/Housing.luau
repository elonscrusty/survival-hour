--!strict
-- Housing: owned slots on each farm, each upgraded through tiers. A house holds chickens
-- (capacity) and stores the eggs they lay until the player (or a worker) collects them.
-- STRUCTURE from the reference (several plots, each upgradeable through named tiers).
-- NAMES AND NUMBERS ARE ORIGINAL DESIGN VALUES. The historical "Shack 250 / Super Shack 500 /
-- Long House 1,000 / Barn 2,000" figures could not be confirmed for the reference and are NOT used.
-- Cash prices are multiplied by the current egg's costScale.

export type Tier = {
	name: string,
	capacity: number, -- chickens
	cost: number, -- price to upgrade INTO this tier (tier 1 comes with the slot)
	unlockEgg: number, -- egg index needed before this tier can be bought
}

local tiers: { Tier } = {
	{ name = "Little Coop", capacity = 100, cost = 0, unlockEgg = 1 },
	{ name = "Twin Coop", capacity = 250, cost = 250, unlockEgg = 1 },
	{ name = "Hen House", capacity = 600, cost = 2500, unlockEgg = 1 },
	{ name = "Red Barn", capacity = 1500, cost = 18000, unlockEgg = 1 },
	{ name = "Big Barn", capacity = 4000, cost = 120000, unlockEgg = 2 },
	{ name = "Poultry Hall", capacity = 10000, cost = 800000, unlockEgg = 3 },
	{ name = "Egg Factory", capacity = 25000, cost = 5e6, unlockEgg = 4 },
	{ name = "Hen Tower", capacity = 60000, cost = 3e7, unlockEgg = 5 },
	{ name = "Sky Roost", capacity = 150000, cost = 2e8, unlockEgg = 7 },
	{ name = "Mega Dome", capacity = 400000, cost = 1.2e9, unlockEgg = 9 },
}

return {
	Tiers = tiers,
	MaxTier = #tiers,
	Slots = 4,
	-- price of buying slot n (slot 1 is free and owned from the start)
	SlotCost = { 0, 400, 6000, 60000 },
	StoragePerChicken = 8, -- eggs a house can hold per chicken of capacity, before upgrades
}
