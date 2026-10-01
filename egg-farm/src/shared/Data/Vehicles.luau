--!strict
-- Shipping vehicles. Each owned vehicle loads eggs from the warehouse (shipping stock), drives
-- off the farm, sells the load at the market and returns. The reference confirms the flow
-- ("Your vehicle will sell these eggs to give you cash", fleet slots, fleet-size upgrade).
-- NAMES AND NUMBERS ARE ORIGINAL DESIGN VALUES. Cash prices x egg costScale.

export type Tier = {
	name: string,
	capacity: number, -- eggs per trip
	trip: number, -- seconds for a full round trip (sale happens halfway)
	cost: number, -- price to upgrade INTO this tier (buying a slot gives tier 1)
	unlockEgg: number,
}

local tiers: { Tier } = {
	{ name = "Farm Pickup", capacity = 40, trip = 10, cost = 0, unlockEgg = 1 },
	{ name = "Delivery Van", capacity = 120, trip = 10, cost = 300, unlockEgg = 1 },
	{ name = "Box Truck", capacity = 400, trip = 12, cost = 3500, unlockEgg = 1 },
	{ name = "Egg Hauler", capacity = 1500, trip = 12, cost = 40000, unlockEgg = 1 },
	{ name = "Double Trailer", capacity = 5000, trip = 14, cost = 400000, unlockEgg = 2 },
	{ name = "Road Train", capacity = 18000, trip = 14, cost = 4e6, unlockEgg = 4 },
	{ name = "Hover Freighter", capacity = 60000, trip = 12, cost = 4e7, unlockEgg = 6 },
	{ name = "Sky Barge", capacity = 200000, trip = 12, cost = 4e8, unlockEgg = 8 },
}

return {
	Tiers = tiers,
	MaxTier = #tiers,
	BaseSlots = 4, -- slots available without upgrades (the Fleet Permit upgrade adds more)
	MaxSlots = 8,
	SlotCost = { 0, 600, 8000, 90000, 900000, 9e6, 9e7, 9e8 },
	LoadWait = 3, -- seconds a vehicle waits at the dock for a fuller load before leaving
}
