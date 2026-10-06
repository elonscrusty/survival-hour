--!strict
-- Server-owned slot snapshots. Settle before assignment, removal or upgrade.
local Gameplay = require("../Gameplay")
local Level = require("./Level")
local Potions = require("../Potions")
local Tuning = Gameplay.Habitat
export type Slot = { Level: number, Creature: string?, Power: number, Coins: number, UpdatedAt: number, BasePower: number?, RateMult: number?, BoostUntil: number?, BoostMult: number? }
local Habitat = {}
function Habitat.New(now: number): Slot
	assert(Level.IsFinite(now), "Invalid time")
	return { Level = 1, Creature = nil, Power = 0, Coins = 0, UpdatedAt = now }
end
function Habitat.Capacity(slot: Slot): number
	return Tuning.BaseCapacity * Tuning.UpgradeCapacity ^ (slot.Level - 1)
end
local function baseRate(slot: Slot): number
	return if slot.Creature then slot.Power * (slot.RateMult or 1) * Tuning.CoinsPerPowerSecond * Tuning.UpgradeRate ^ (slot.Level - 1) else 0
end
function Habitat.Rate(slot: Slot): number
	local boost = if (slot.BoostUntil or 0) > slot.UpdatedAt then (slot.BoostMult or 1) else 1
	return baseRate(slot) * boost
end
function Habitat.Accrue(slot: Slot, now: number)
	if not Level.IsFinite(now) or now <= slot.UpdatedAt then return end
	local seconds = now - slot.UpdatedAt
	local boostedSeconds = math.max(0, math.min(now, slot.BoostUntil or 0) - slot.UpdatedAt)
	local effectiveSeconds = seconds + boostedSeconds * ((slot.BoostMult or 1) - 1)
	slot.Coins = math.min(Habitat.Capacity(slot), slot.Coins + effectiveSeconds * baseRate(slot))
	slot.UpdatedAt = now
end
function Habitat.Power(c: Level.Creature): number
	return Level.Power(c) * (if c.Neon then Potions.NeonCoinMult else 1)
end
function Habitat.Assign(slot: Slot, c: Level.Creature, now: number): boolean
	if slot.Creature ~= nil or not Level.IsFinite(now) or now < slot.UpdatedAt then return false end
	local power = Habitat.Power(c)
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
