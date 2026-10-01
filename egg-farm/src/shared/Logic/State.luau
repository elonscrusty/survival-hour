--!strict
-- Default FarmState and the farm reset used by rebirth and prestige.
-- RESET_FIELDS / KEPT_FIELDS are the single source of truth for what a new farm clears; the
-- Progression spec checks every FarmState field is in exactly one list.

local Housing = require("../Data/Housing")
local Vehicles = require("../Data/Vehicles")
local Workers = require("../Data/Workers")

local State = {}

State.VERSION = 1

-- Cleared when a new farm starts (rebirth, skip, prestige).
State.RESET_FIELDS = {
	"cash", "population", "hatchPartial", "invested", "housing", "carried", "warehouse",
	"vehicles", "workers", "silos", "common",
}
-- Kept across every new farm. (`egg`, `rebirths`, `prestiges` and `stars` are changed by the
-- action itself, not reset.)
State.KEPT_FIELDS = {
	"version", "createdAt", "lastSeen", "gold", "stars", "egg", "rebirths", "prestiges", "epic",
	"boosts", "quests", "daily", "gifts", "codes", "settings", "tutorial", "passes", "receipts",
	"offline", "stats",
}

function State.EmptyHousing(): { any }
	local list = {}
	for i = 1, Housing.Slots do
		list[i] = { tier = if i == 1 then 1 else 0, eggs = 0, partial = 0 }
	end
	return list
end

function State.EmptyVehicles(): { any }
	local list = {}
	for i = 1, Vehicles.MaxSlots do
		list[i] = { tier = if i == 1 then 1 else 0, load = 0, phase = "dock", t = 0 }
	end
	return list
end

function State.EmptyWorkers(): { any }
	local list = {}
	for i = 1, Workers.MaxSlots do
		list[i] = { tier = 0, load = 0, t = 0, house = 1 }
	end
	return list
end

-- Fields of a brand-new farm.
function State.ApplyFreshFarm(s: any)
	s.cash = 0
	s.population = 0
	s.hatchPartial = 0
	s.invested = 0
	s.housing = State.EmptyHousing()
	s.carried = 0
	s.warehouse = 0
	s.vehicles = State.EmptyVehicles()
	s.workers = State.EmptyWorkers()
	s.silos = 0
	s.common = {}
end

function State.New(now: number): any
	local s: any = {
		version = State.VERSION,
		createdAt = now,
		lastSeen = now,
		gold = 0,
		stars = 0,
		egg = 1,
		rebirths = 0,
		prestiges = 0,
		epic = {},
		boosts = { inventory = {}, active = {} },
		quests = { day = -1, progress = {}, claimed = {} },
		daily = { streak = 0, lastDay = -1 },
		gifts = { day = -1, playtime = 0, claimed = {} },
		codes = {},
		settings = {
			music = true,
			sfx = true,
			autoSpawn = false,
			effects = true,
			flock = "normal",
			notation = "short",
			confirmSpend = true,
		},
		tutorial = { step = 1, done = false },
		passes = {},
		receipts = {},
		offline = { pending = 0, seconds = 0 },
		stats = {},
	}
	State.ApplyFreshFarm(s)
	return s
end

-- Eggs currently anywhere on the farm (houses, basket, warehouse, workers, vehicles).
function State.EggsOnFarm(s: any): number
	local n = s.carried + s.warehouse
	for _, h in s.housing do
		n += h.eggs
	end
	for _, v in s.vehicles do
		n += v.load
	end
	for _, w in s.workers do
		n += w.load
	end
	return n
end

return State
