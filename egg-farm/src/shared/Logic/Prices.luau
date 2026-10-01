--!strict
-- Every price in the game, computed from state + modifiers. The client uses the same functions to
-- show prices and affordability; the server uses them to charge. Returns nil when the thing
-- can't be bought (locked, maxed, missing slot) together with the reason code.

local Eggs = require("../Data/Eggs")
local Housing = require("../Data/Housing")
local Vehicles = require("../Data/Vehicles")
local Workers = require("../Data/Workers")
local Upgrades = require("../Data/Upgrades")
local Silos = require("../Data/Silos")
local Modifiers = require("./Modifiers")

local Prices = {}

local function scale(state: any): number
	return (Eggs.List[state.egg] or Eggs.List[1]).costScale
end

local function round(n: number): number
	return math.max(1, math.floor(n + 0.5))
end

-- Buying an empty housing slot. Slots must be bought in order.
function Prices.BuyHouse(state: any, slot: number): (number?, string)
	local h = state.housing[slot]
	if not h then
		return nil, "invalid"
	elseif h.tier > 0 then
		return nil, "slot_taken"
	elseif slot > 1 and state.housing[slot - 1].tier == 0 then
		return nil, "slot_locked"
	end
	return round(Housing.SlotCost[slot] * scale(state)), "ok"
end

function Prices.UpgradeHouse(state: any, slot: number): (number?, string)
	local h = state.housing[slot]
	if not h or h.tier == 0 then
		return nil, "invalid"
	elseif h.tier >= Housing.MaxTier then
		return nil, "max_level"
	end
	local nextTier = Housing.Tiers[h.tier + 1]
	if state.egg < nextTier.unlockEgg then
		return nil, "locked"
	end
	return round(nextTier.cost * scale(state)), "ok"
end

function Prices.BuyVehicle(state: any, slot: number, m: Modifiers.Mods): (number?, string)
	local v = state.vehicles[slot]
	if not v or slot > m.vehicleSlots then
		return nil, if v then "locked" else "invalid"
	elseif v.tier > 0 then
		return nil, "slot_taken"
	elseif slot > 1 and state.vehicles[slot - 1].tier == 0 then
		return nil, "slot_locked"
	end
	return round(Vehicles.SlotCost[slot] * scale(state)), "ok"
end

function Prices.UpgradeVehicle(state: any, slot: number): (number?, string)
	local v = state.vehicles[slot]
	if not v or v.tier == 0 then
		return nil, "invalid"
	elseif v.tier >= Vehicles.MaxTier then
		return nil, "max_level"
	end
	local nextTier = Vehicles.Tiers[v.tier + 1]
	if state.egg < nextTier.unlockEgg then
		return nil, "locked"
	end
	return round(nextTier.cost * scale(state)), "ok"
end

function Prices.HireWorker(state: any, slot: number, m: Modifiers.Mods): (number?, string)
	local w = state.workers[slot]
	if not w or slot > m.workerSlots then
		return nil, if w then "locked" else "invalid"
	elseif w.tier > 0 then
		return nil, "slot_taken"
	elseif slot > 1 and state.workers[slot - 1].tier == 0 then
		return nil, "slot_locked"
	end
	return round(Workers.HireCost[slot] * scale(state)), "ok"
end

function Prices.UpgradeWorker(state: any, slot: number): (number?, string)
	local w = state.workers[slot]
	if not w or w.tier == 0 then
		return nil, "invalid"
	elseif w.tier >= Workers.MaxTier then
		return nil, "max_level"
	end
	local nextTier = Workers.Tiers[w.tier + 1]
	if state.egg < nextTier.unlockEgg then
		return nil, "locked"
	end
	return round(nextTier.cost * scale(state)), "ok"
end

function Prices.Silo(state: any): (number?, string)
	if state.silos >= Silos.Max then
		return nil, "max_level"
	end
	return round(Silos.BaseCost * scale(state) * Silos.CostGrowth ^ state.silos), "ok"
end

-- Common upgrades: cash. Epic upgrades: Gold Eggs (never discounted by cash discounts).
function Prices.Upgrade(state: any, id: string, m: Modifiers.Mods): (number?, string, string)
	local u = Upgrades.ById[id]
	if not u then
		return nil, "invalid", "cash"
	end
	local isEpic = table.find(Upgrades.Epic, u) ~= nil
	local levels = if isEpic then state.epic else state.common
	local level = levels[id] or 0
	if level >= u.max then
		return nil, "max_level", if isEpic then "gold" else "cash"
	elseif state.egg < u.unlockEgg then
		return nil, "locked", if isEpic then "gold" else "cash"
	end
	if isEpic then
		return round(u.base * u.growth ^ level), "ok", "gold"
	end
	return round(u.base * u.growth ^ level * m.commonPriceMult), "ok", "cash"
end

-- Gold Egg cost of SKIP: pay to rebirth before reaching the Farm Value goal (DESIGN rule; the
-- reference shows a SKIP button but its rule is unknown). Allowed from 25% of the goal.
function Prices.Skip(state: any, farmValue: number): (number?, string)
	if state.egg >= Eggs.Count then
		return nil, "last_egg"
	end
	local req = Eggs.List[state.egg].requirement
	if farmValue >= req then
		return 0, "ok"
	elseif farmValue < req * 0.25 then
		return nil, "skip_too_early"
	end
	return math.max(1, math.ceil((1 - farmValue / req) * 30 * state.egg)), "ok"
end

return Prices
