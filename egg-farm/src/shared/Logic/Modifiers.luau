--!strict
-- Turns a FarmState (plus passes, active boosts and the session context) into the numbers the
-- economy runs on. Pure: the same inputs always give the same outputs, so the client can show
-- exactly what the server will charge and produce.

local Eggs = require("../Data/Eggs")
local Housing = require("../Data/Housing")
local Vehicles = require("../Data/Vehicles")
local Workers = require("../Data/Workers")
local Upgrades = require("../Data/Upgrades")
local Boosts = require("../Data/Boosts")
local Silos = require("../Data/Silos")

local Modifiers = {}

Modifiers.BASE_LAY = 0.1 -- eggs per chicken per second
Modifiers.BASE_CARRY = 100
Modifiers.BASE_WALK = 20
Modifiers.BASE_AUTOSPAWN = 0.5 -- chickens per second with Auto Spawn on and no Auto Clicker levels
Modifiers.BASE_COMBO_MAX = 5
Modifiers.COMBO_PER_TAP = 0.08
Modifiers.PREMIUM_CASH = 1.2 -- verified for the reference: Premium players get +20% cash
Modifiers.STAR_BONUS = 0.05 -- +5% cash per Star Egg
Modifiers.CAP = 1e300 -- currencies are clamped here so arithmetic never reaches infinity

export type Mods = {
	layRate: number, -- eggs per chicken per second
	eggValue: number, -- cash per egg before the sale multiplier
	saleMult: number, -- every multiplier applied at sale time except the tap combo
	capacityMult: number,
	storageMult: number,
	carryCap: number,
	hatchPerHouse: number, -- chickens per second per owned house
	spawnPerTap: number,
	autoSpawnRate: number,
	tripMult: number,
	workerMult: number,
	vehicleSlots: number,
	workerSlots: number,
	comboMax: number,
	commonPriceMult: number,
	siloMinutes: number,
	walkSpeed: number,
	maxBoosts: number,
	goldMult: number,
	offlineMult: number,
}

local function lvl(t: { [string]: number }, id: string): number
	return t[id] or 0
end

local function stat(state: any, group: { Upgrades.Upgrade }, levels: { [string]: number }, name: string): number
	local total = 0
	for _, u in group do
		if u.stat == name then
			total += u.per * lvl(levels, u.id)
		end
	end
	return total
end

-- Boost multipliers by stat. "booster" doubles the bonus part (mult - 1) of the others.
function Modifiers.BoostMults(active: { { id: string, endsAt: number } }, now: number): { [string]: number }
	local out = { earn = 1, lay = 1, hatch = 1 }
	local booster = 1
	for _, a in active do
		local b = Boosts.ById[a.id]
		if b and a.endsAt > now and b.stat == "booster" then
			booster = b.mult
		end
	end
	for _, a in active do
		local b = Boosts.ById[a.id]
		if b and a.endsAt > now and b.stat ~= "booster" then
			out[b.stat] = (out[b.stat] or 1) * (1 + (b.mult - 1) * booster)
		end
	end
	return out
end

function Modifiers.Compute(state: any, now: number, ctx: { premium: boolean? }?, noBoosts: boolean?): Mods
	local common, epic, passes = state.common, state.epic, state.passes
	local egg = Eggs.List[state.egg] or Eggs.List[1]
	local boosts = if noBoosts then { earn = 1, lay = 1, hatch = 1 } else Modifiers.BoostMults(state.boosts.active, now)

	local layValue = stat(state, Upgrades.Common, common, "layValuePct")
	local layRate = Modifiers.BASE_LAY
		* (1 + stat(state, Upgrades.Common, common, "layPct") + layValue)
		* (1 + stat(state, Upgrades.Epic, epic, "epicLayPct"))
		* boosts.lay

	local valueMul = 1
	for _, u in Upgrades.Common do
		if u.stat == "valueMul" and lvl(common, u.id) > 0 then
			valueMul *= u.per ^ lvl(common, u.id)
		end
	end
	local eggValue = egg.value
		* (1 + stat(state, Upgrades.Common, common, "valuePct") + layValue)
		* valueMul
		* (1 + stat(state, Upgrades.Epic, epic, "epicValuePct"))

	local saleMult = boosts.earn
		* (if passes.x2cash then 2 else 1)
		* (if ctx and ctx.premium then Modifiers.PREMIUM_CASH else 1)
		* (1 + Modifiers.STAR_BONUS * (state.stars or 0))

	local carryLevels = lvl(common, "basket")
	local carryCap = Modifiers.BASE_CARRY * 2 ^ carryLevels * (1 + stat(state, Upgrades.Epic, epic, "epicCarryPct"))

	return {
		layRate = layRate,
		eggValue = eggValue,
		saleMult = saleMult,
		capacityMult = (1 + stat(state, Upgrades.Common, common, "capacityPct")) * (if passes.x2housing then 2 else 1),
		storageMult = 1 + stat(state, Upgrades.Common, common, "storagePct"),
		carryCap = math.floor(carryCap),
		hatchPerHouse = stat(state, Upgrades.Common, common, "hatchPerHouse")
			* (1 + stat(state, Upgrades.Epic, epic, "hatchPct"))
			* boosts.hatch,
		spawnPerTap = (1 + stat(state, Upgrades.Common, common, "spawnPerTap")) * (if passes.x2chickens then 2 else 1),
		autoSpawnRate = (Modifiers.BASE_AUTOSPAWN + stat(state, Upgrades.Epic, epic, "autoSpawnRate"))
			* (if passes.x2chickens then 2 else 1),
		tripMult = (1 - stat(state, Upgrades.Common, common, "tripPct")) * (if passes.x2shipping then 0.5 else 1),
		workerMult = (1 + stat(state, Upgrades.Common, common, "workerPct")) * (if passes.x2workers then 2 else 1),
		vehicleSlots = math.min(Vehicles.MaxSlots, Vehicles.BaseSlots + stat(state, Upgrades.Common, common, "vehicleSlots")),
		workerSlots = math.min(
			Workers.MaxSlots,
			Workers.BaseSlots + stat(state, Upgrades.Common, common, "workerSlots") + (if passes.worker_slots then 2 else 0)
		),
		comboMax = Modifiers.BASE_COMBO_MAX + stat(state, Upgrades.Epic, epic, "comboMax"),
		commonPriceMult = egg.costScale
			* (1 - stat(state, Upgrades.Epic, epic, "commonDiscount"))
			* (if passes.cheap_upgrades then 0.5 else 1),
		siloMinutes = Silos.MinutesPerSilo + stat(state, Upgrades.Epic, epic, "siloMinutes"),
		walkSpeed = Modifiers.BASE_WALK * (1 + stat(state, Upgrades.Common, common, "speedPct")),
		maxBoosts = if passes.vip then Boosts.MaxActiveVip else Boosts.MaxActive,
		goldMult = if passes.x2gold then 2 else 1,
		offlineMult = if passes.x2offline then 2 else 1,
	}
end

-- Chickens a house of `tier` holds.
function Modifiers.HouseCapacity(tier: number, m: Mods): number
	local t = Housing.Tiers[tier]
	return if t then math.floor(t.capacity * m.capacityMult) else 0
end

function Modifiers.HouseStorage(tier: number, m: Mods): number
	local t = Housing.Tiers[tier]
	return if t then math.floor(t.capacity * Housing.StoragePerChicken * m.storageMult) else 0
end

function Modifiers.TotalCapacity(state: any, m: Mods): number
	local total = 0
	for _, h in state.housing do
		total += Modifiers.HouseCapacity(h.tier, m)
	end
	return total
end

function Modifiers.VehicleCap(tier: number): number
	local t = Vehicles.Tiers[tier]
	return if t then t.capacity else 0
end

function Modifiers.VehicleTrip(tier: number, m: Mods): number
	local t = Vehicles.Tiers[tier]
	return if t then t.trip * m.tripMult else math.huge
end

function Modifiers.WorkerCarry(tier: number, m: Mods): number
	local t = Workers.Tiers[tier]
	return if t then math.floor(t.carry * m.workerMult) else 0
end

function Modifiers.WorkerCycle(tier: number): number
	local t = Workers.Tiers[tier]
	return if t then t.cycle else math.huge
end

-- Eggs per second each part of the chain can handle (for the HUD and the steady cash rate).
function Modifiers.Rates(state: any, m: Mods): { lay: number, ship: number, workers: number }
	local ship, workers = 0, 0
	for _, v in state.vehicles do
		if v.tier > 0 then
			ship += Modifiers.VehicleCap(v.tier) / Modifiers.VehicleTrip(v.tier, m)
		end
	end
	for _, w in state.workers do
		if w.tier > 0 then
			workers += Modifiers.WorkerCarry(w.tier, m) / Modifiers.WorkerCycle(w.tier)
		end
	end
	return { lay = state.population * m.layRate, ship = ship, workers = workers }
end

-- Cash per second the farm sustains (laying limited by shipping), with no temporary boosts and
-- no tap combo. Used for offline earnings and "minutes of earnings" rewards.
function Modifiers.SteadyCashRate(state: any, now: number, ctx: any?): number
	local m = Modifiers.Compute(state, now, ctx, true)
	local r = Modifiers.Rates(state, m)
	local flow = math.min(r.lay, r.ship)
	return flow * m.eggValue * m.saleMult
end

return Modifiers
