--!strict
-- Upgrades saved data to the current FarmState version, fills in fields added since it was saved,
-- and repairs impossible numbers (NaN, infinity, negatives) instead of letting them spread.
-- Never downgrades: data written by a NEWER version of the game is refused (the player is asked to
-- rejoin a newer server) so an old server can't overwrite fields it doesn't understand.

local State = require("./State")
local Housing = require("../Data/Housing")
local Vehicles = require("../Data/Vehicles")
local Workers = require("../Data/Workers")
local Eggs = require("../Data/Eggs")

local Migrations = {}

Migrations.CURRENT = State.VERSION

-- steps[n] upgrades a version-n record to version n+1.
-- Version 0 = records saved before the version field existed (pre-release test saves).
local steps: { [number]: (any) -> () } = {
	[0] = function(d)
		-- v0 stored the shipping stock as `stock` and had no workers list
		if d.stock ~= nil and d.warehouse == nil then
			d.warehouse = d.stock
		end
		d.stock = nil
	end,
}

local function fill(target: any, template: any)
	for k, v in template do
		if target[k] == nil then
			if type(v) == "table" then
				target[k] = {}
				fill(target[k], v)
			else
				target[k] = v
			end
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil and #v == 0 then
			fill(target[k], v) -- records: fill nested defaults (not lists)
		end
	end
end

local function num(v: any, lo: number, hi: number, default: number): number
	if type(v) ~= "number" or v ~= v then
		return default
	end
	return math.clamp(v, lo, hi)
end

local function whole(v: any, lo: number, hi: number, default: number): number
	return math.floor(num(v, lo, hi, default))
end

local function fixSlots(list: any, count: number, make: () -> { any }, maxTier: number): { any }
	local fresh = make()
	if type(list) ~= "table" then
		return fresh
	end
	for i = 1, count do
		local e = list[i]
		if type(e) ~= "table" then
			list[i] = fresh[i]
		else
			for k, v in fresh[i] do
				if e[k] == nil or type(e[k]) ~= type(v) then
					e[k] = v
				end
			end
			e.tier = whole(e.tier, 0, maxTier, fresh[i].tier)
			if e.load ~= nil then
				e.load = whole(e.load, 0, 1e15, 0)
			end
			if e.eggs ~= nil then
				e.eggs = whole(e.eggs, 0, 1e15, 0)
				e.partial = num(e.partial, 0, 0.999999, 0)
			end
			if e.t ~= nil then
				e.t = num(e.t, 0, 1e6, 0)
			end
		end
	end
	for i = #list, count + 1, -1 do
		list[i] = nil
	end
	return list
end

function Migrations.Sanitize(d: any)
	local CAP = 1e300
	d.cash = num(d.cash, 0, CAP, 0)
	d.gold = num(d.gold, 0, CAP, 0)
	d.stars = num(d.stars, 0, CAP, 0)
	d.invested = num(d.invested, 0, CAP, 0)
	d.population = whole(d.population, 0, 1e15, 0)
	d.hatchPartial = num(d.hatchPartial, 0, 0.999999, 0)
	d.carried = whole(d.carried, 0, 1e15, 0)
	d.warehouse = whole(d.warehouse, 0, 1e15, 0)
	d.silos = whole(d.silos, 0, 10, 0)
	d.egg = whole(d.egg, 1, Eggs.Count, 1)
	d.rebirths = whole(d.rebirths, 0, 1e9, 0)
	d.prestiges = whole(d.prestiges, 0, 1e9, 0)
	d.housing = fixSlots(d.housing, Housing.Slots, State.EmptyHousing, Housing.MaxTier)
	if d.housing[1].tier == 0 then
		d.housing[1].tier = 1 -- the first coop is always owned
	end
	d.vehicles = fixSlots(d.vehicles, Vehicles.MaxSlots, State.EmptyVehicles, Vehicles.MaxTier)
	d.workers = fixSlots(d.workers, Workers.MaxSlots, State.EmptyWorkers, Workers.MaxTier)
	for _, group in { d.common, d.epic, d.boosts.inventory, d.stats } do
		for k, v in group do
			group[k] = num(v, 0, CAP, 0)
		end
	end
	local active = {}
	for _, a in d.boosts.active do
		if type(a) == "table" and type(a.id) == "string" and type(a.endsAt) == "number" and a.endsAt == a.endsAt then
			table.insert(active, a)
		end
	end
	d.boosts.active = active
end

-- Returns ok, data (migrated in place) or ok=false, reason.
function Migrations.Migrate(d: any, now: number): (boolean, any)
	if type(d) ~= "table" then
		return false, "corrupt"
	end
	local v = d.version
	if v == nil then
		v = 0
	end
	if type(v) ~= "number" or v ~= math.floor(v) or v < 0 then
		return false, "corrupt"
	end
	if v > Migrations.CURRENT then
		return false, "newer"
	end
	while v < Migrations.CURRENT do
		local step = steps[v]
		if not step then
			return false, "no_migration"
		end
		step(d)
		v += 1
	end
	d.version = Migrations.CURRENT
	fill(d, State.New(now))
	Migrations.Sanitize(d)
	return true, d
end

return Migrations
