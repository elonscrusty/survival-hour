--!strict
-- Workers walk between the houses and the warehouse, carrying eggs automatically.
-- The reference confirms the role ("hire workers to move eggs automatically") and named tiers.
-- NAMES AND NUMBERS ARE ORIGINAL DESIGN VALUES. Cash prices x egg costScale.

export type Tier = {
	name: string,
	carry: number, -- eggs per trip
	cycle: number, -- seconds per round trip (pick-up halfway, drop-off at the end)
	cost: number, -- price to upgrade INTO this tier (hiring gives tier 1)
	unlockEgg: number,
}

local tiers: { Tier } = {
	{ name = "Farmhand", carry = 25, cycle = 12, cost = 0, unlockEgg = 1 },
	{ name = "Egg Runner", carry = 80, cycle = 12, cost = 2000, unlockEgg = 1 },
	{ name = "Rancher", carry = 250, cycle = 12, cost = 20000, unlockEgg = 1 },
	{ name = "Foreman", carry = 800, cycle = 12, cost = 250000, unlockEgg = 2 },
	{ name = "Robo Picker", carry = 3000, cycle = 10, cost = 2.5e6, unlockEgg = 3 },
	{ name = "Jet Courier", carry = 10000, cycle = 10, cost = 2.5e7, unlockEgg = 5 },
	{ name = "Mech Hauler", carry = 35000, cycle = 10, cost = 2.5e8, unlockEgg = 7 },
	{ name = "Star Porter", carry = 120000, cycle = 10, cost = 2.5e9, unlockEgg = 9 },
}

return {
	Tiers = tiers,
	MaxTier = #tiers,
	BaseSlots = 2, -- the Bunkhouse upgrade and the +2 Worker Slots pass add more
	MaxSlots = 8,
	HireCost = { 1500, 6000, 40000, 300000, 2e6, 1.5e7, 1e8, 7e8 },
	TutorialEgg = 1,
}
