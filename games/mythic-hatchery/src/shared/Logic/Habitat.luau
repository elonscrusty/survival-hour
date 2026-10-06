--!strict
-- Server-owned slot snapshots. Settle before assignment, removal or upgrade.
local Gameplay = require("../Gameplay")
local Level = require("./Level")
local Tuning = Gameplay.Habitat
export type Slot = { Level: number, Creature: string?, Power: number, Coins: number, UpdatedAt: number }
local Habitat = {}
function Habitat.New(now: number): Slot
	assert(Level.IsFinite(now), "Invalid time")
	return { Level = 1, Creature = nil, Power = 0, Coins = 0, UpdatedAt = now }
end
function Habitat.Capacity(slot: Slot): number
	return Tuning.BaseCapacity * Tuning.UpgradeCapacity ^ (slot.Level - 1)
end
function Habitat.Rate(slot: Slot): number
	return if slot.Creature then slot.Power * Tuning.CoinsPerPowerSecond * Tuning.UpgradeRate ^ (slot.Level - 1) else 0
end
function Habitat.Accrue(slot: Slot, now: number)
	if not Level.IsFinite(now) or now <= slot.UpdatedAt then return end
	slot.Coins = math.min(Habitat.Capacity(slot), slot.Coins + (now - slot.UpdatedAt) * Habitat.Rate(slot))
	slot.UpdatedAt = now
end
function Habitat.Assign(slot: Slot, c: Level.Creature, now: number): boolean
	if slot.Creature ~= nil or not Level.IsFinite(now) or now < slot.UpdatedAt then return false end
	local power = Level.Power(c)
	Habitat.Accrue(slot, now)
	slot.Creature = c.Uid; slot.Power = power
	return true
end
function Habitat.Remove(slot: Slot, now: number): boolean
	if not Level.IsFinite(now) or now < slot.UpdatedAt then return false end
	Habitat.Accrue(slot, now)
	slot.Creature = nil; slot.Power = 0
	return true
end
function Habitat.Collect(slot: Slot, now: number): number
	if not Level.IsFinite(now) or now < slot.UpdatedAt then return 0 end
	Habitat.Accrue(slot, now)
	local coins = math.floor(slot.Coins)
	slot.Coins -= coins
	return coins
end
function Habitat.UpgradeCost(slot: Slot): number
	return math.floor(Tuning.UpgradeCost * Tuning.UpgradeCostMult ^ (slot.Level - 1))
end
-- Returns the amount to charge; only the server can debit the player's wallet.
function Habitat.Upgrade(slot: Slot, wallet: number, now: number): (boolean, number)
	if not Level.IsFinite(wallet) or not Level.IsFinite(now) or now < slot.UpdatedAt or slot.Level >= Tuning.MaxUpgrade then return false, 0 end
	local cost = Habitat.UpgradeCost(slot)
	if wallet < cost then return false, 0 end
	Habitat.Accrue(slot, now)
	slot.Level += 1
	return true, cost
end
return Habitat
