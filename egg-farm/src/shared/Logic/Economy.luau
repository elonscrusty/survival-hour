--!strict
-- The farm economy: one Farm per player, wrapping that player's FarmState.
--   farm:Apply(action, now)  -> ActionResult    every state change goes through here
--   farm:Step(dt, now)                           production, hatching, workers, vehicles, timers
--   farm:Snapshot(now)       -> FarmSnapshot     what the owner's client is shown
-- Pure Luau with no Roblox APIs: the server owns the clock and passes `now` (server time, seconds).
-- Egg conservation: eggs only appear when hens lay (stats.laid) and only leave by being sold
-- (stats.sold) or discarded by a new farm (stats.discarded). Every other move takes exactly what
-- it adds. Spec: tests/Conservation.spec.luau.

local Eggs = require("../Data/Eggs")
local Housing = require("../Data/Housing")
local Vehicles = require("../Data/Vehicles")
local Workers = require("../Data/Workers")
local Upgrades = require("../Data/Upgrades")
local Boosts = require("../Data/Boosts")
local Silos = require("../Data/Silos")
local RewardData = require("../Data/Rewards")
local Products = require("../Data/Products")
local Contract = require("../Contract")
local Modifiers = require("./Modifiers")
local Prices = require("./Prices")
local Rewards = require("./Rewards")
local State = require("./State")
local Tutorial = require("./Tutorial")
local Validate = require("./Validate")

local CAP = Modifiers.CAP
local MAX_STEP = 5 -- longest single simulation slice (seconds); longer gaps are split

export type Event = { name: string, data: { [string]: any } }
export type Context = {
	premium: boolean?,
	codes: { [string]: any }?, -- server-only code table (Data lives in src/server)
	rng: (() -> number)?,
}

local Economy = {}
Economy.__index = Economy

export type Farm = typeof(setmetatable(
	{} :: {
		state: any,
		ctx: Context,
		events: { Event },
		dirty: boolean,
		combo: number,
		lastTap: number,
		lastSeq: number,
		mods: Modifiers.Mods?,
		modsAt: number,
		notice: { [string]: number },
	},
	Economy
))

function Economy.new(state: any, ctx: Context?): Farm
	local self = setmetatable({
		state = state,
		ctx = ctx or {},
		events = {},
		dirty = true,
		combo = 1,
		lastTap = -math.huge,
		lastSeq = 0,
		mods = nil,
		modsAt = -math.huge,
		notice = {},
	}, Economy)
	return self
end

local function result(code: string, message: string?): { ok: boolean, code: string, message: string? }
	return { ok = code == "ok" or code == "code_ok", code = code, message = message or Contract.Messages[code] }
end

function Economy.Emit(self: Farm, name: string, data: { [string]: any }?)
	table.insert(self.events, { name = name, data = data or {} })
end

-- Throttled one-off notices (e.g. "housing full") so they don't spam the client.
function Economy.Notice(self: Farm, key: string, now: number, every: number, data: { [string]: any }?)
	if (self.notice[key] or -math.huge) + every <= now then
		self.notice[key] = now
		self:Emit(key, data)
	end
end

function Economy.DrainEvents(self: Farm): { Event }
	local e = self.events
	self.events = {}
	return e
end

function Economy.Mods(self: Farm, now: number): Modifiers.Mods
	-- recomputed every call: cheap, and never stale after a purchase or boost
	local m = Modifiers.Compute(self.state, now, self.ctx)
	self.mods = m
	self.modsAt = now
	return m
end

function Economy.FarmValue(self: Farm): number
	return math.min(CAP, self.state.cash + self.state.invested)
end

local function spend(self: Farm, amount: number): boolean
	local s = self.state
	if not Validate.Finite(amount) or amount < 0 or s.cash < amount then
		return false
	end
	s.cash -= amount
	s.invested = math.min(CAP, s.invested + amount)
	return true
end

local function spendGold(self: Farm, amount: number): boolean
	local s = self.state
	if not Validate.Finite(amount) or amount < 0 or s.gold < amount then
		return false
	end
	s.gold -= amount
	return true
end

------------------------------------------------------------------------------------------------
-- Physical interactions (server calls these only after checking the player's position)
------------------------------------------------------------------------------------------------

-- Move stored eggs from house `slot` into the basket, up to the basket's free space.
function Economy.Collect(self: Farm, slot: number, now: number): { ok: boolean, code: string, message: string? }
	local s = self.state
	if not Validate.Int(slot, 1, Housing.Slots) then
		return result("invalid")
	end
	local h = s.housing[slot]
	if h.tier == 0 then
		return result("invalid")
	end
	local m = self:Mods(now)
	local space = m.carryCap - s.carried
	if space <= 0 then
		self:Notice("BasketFull", now, 3)
		return result("basket_full")
	end
	if h.eggs <= 0 then
		return result("empty")
	end
	local take = math.min(h.eggs, space)
	h.eggs -= take
	s.carried += take
	Rewards.Track(s, "collected", take)
	self:Emit("Collected", { slot = slot, amount = take, full = s.carried >= m.carryCap })
	self.dirty = true
	Tutorial.Update(s)
	return result("ok")
end

-- Move the whole basket into the warehouse (shipping stock).
function Economy.Deposit(self: Farm, now: number): { ok: boolean, code: string, message: string? }
	local s = self.state
	if s.carried <= 0 then
		return result("nothing_carried")
	end
	local amount = s.carried
	s.carried = 0
	s.warehouse += amount
	Rewards.Track(s, "deposited", amount)
	self:Emit("Deposited", { amount = amount })
	self.dirty = true
	Tutorial.Update(s)
	return result("ok")
end

-- Lucky Fox caught (server validated the fox and the distance). Pays some seconds of earnings.
function Economy.CatchFox(self: Farm, now: number): { ok: boolean, code: string, message: string? }
	local s = self.state
	local roll = if self.ctx.rng then self.ctx.rng() else 0.5
	local seconds = 30 + math.floor(roll * 90)
	local egg = Eggs.List[s.egg]
	local cash = math.floor(math.max(Modifiers.SteadyCashRate(s, now, self.ctx) * seconds, 50 * egg.value))
	s.cash = math.min(CAP, s.cash + cash)
	Rewards.Track(s, "foxes", 1)
	self:Emit("Fox", { cash = cash })
	self.dirty = true
	return result("ok")
end

------------------------------------------------------------------------------------------------
-- Client actions
------------------------------------------------------------------------------------------------

local handlers: { [string]: (self: Farm, a: any, now: number) -> { ok: boolean, code: string, message: string? } } = {}

local function slotArg(a: any, max: number): number?
	if Validate.Int(a.slot, 1, max) then
		return a.slot
	end
	return nil
end

-- `expect` guards against double taps and stale menus: the request names the level it saw.
local function expectOk(a: any, current: number): boolean
	return a.expect == nil or (Validate.Int(a.expect, 0, 1e6) and a.expect == current)
end

local function purchased(self: Farm, kind: string, data: { [string]: any })
	Rewards.Track(self.state, "upgrades", 1)
	self:Emit("Purchased", data)
	self.dirty = true
	Tutorial.Update(self.state)
end

handlers.spawn = function(self, a, now)
	local s = self.state
	local m = self:Mods(now)
	local cap = Modifiers.TotalCapacity(s, m)
	if s.population >= cap then
		self:Notice("HousingFull", now, 2)
		return result("full")
	end
	local add = math.min(m.spawnPerTap, cap - s.population)
	s.population += add
	Rewards.Track(s, "spawned", add)
	-- tap combo: every accepted tap raises the Cash Multiplier a little; it decays when idle
	self.combo = math.min(m.comboMax, self.combo + Modifiers.COMBO_PER_TAP)
	self.lastTap = now
	self.dirty = true
	Tutorial.Update(s)
	return result("ok")
end

handlers.setAutoSpawn = function(self, a, now)
	if not Validate.Bool(a.value) then
		return result("invalid")
	end
	if a.value and not self.state.tutorial.done then
		return result("tutorial")
	end
	self.state.settings.autoSpawn = a.value
	self.dirty = true
	return result("ok")
end

handlers.buyHouse = function(self, a, now)
	local slot = slotArg(a, Housing.Slots)
	if not slot then
		return result("invalid")
	end
	local price, code = Prices.BuyHouse(self.state, slot)
	if not price then
		return result(code)
	end
	if not spend(self, price) then
		return result("cant_afford")
	end
	local h = self.state.housing[slot]
	h.tier, h.eggs, h.partial = 1, 0, 0
	purchased(self, "house", { kind = "house", slot = slot, tier = 1 })
	return result("ok")
end

handlers.upgradeHouse = function(self, a, now)
	local slot = slotArg(a, Housing.Slots)
	if not slot then
		return result("invalid")
	end
	local h = self.state.housing[slot]
	if not expectOk(a, h.tier) then
		return result("stale")
	end
	local price, code = Prices.UpgradeHouse(self.state, slot)
	if not price then
		return result(code)
	end
	if not spend(self, price) then
		return result("cant_afford")
	end
	h.tier += 1
	purchased(self, "house", { kind = "house", slot = slot, tier = h.tier })
	return result("ok")
end

handlers.buyVehicle = function(self, a, now)
	local slot = slotArg(a, Vehicles.MaxSlots)
	if not slot then
		return result("invalid")
	end
	local price, code = Prices.BuyVehicle(self.state, slot, self:Mods(now))
	if not price then
		return result(code)
	end
	if not spend(self, price) then
		return result("cant_afford")
	end
	local v = self.state.vehicles[slot]
	v.tier, v.load, v.phase, v.t = 1, 0, "dock", 0
	purchased(self, "vehicle", { kind = "vehicle", slot = slot, tier = 1 })
	return result("ok")
end

handlers.upgradeVehicle = function(self, a, now)
	local slot = slotArg(a, Vehicles.MaxSlots)
	if not slot then
		return result("invalid")
	end
	local v = self.state.vehicles[slot]
	if not expectOk(a, v.tier) then
		return result("stale")
	end
	local price, code = Prices.UpgradeVehicle(self.state, slot)
	if not price then
		return result(code)
	end
	if not spend(self, price) then
		return result("cant_afford")
	end
	v.tier += 1 -- a vehicle out on a trip keeps its load; the new size applies from the next load
	purchased(self, "vehicle", { kind = "vehicle", slot = slot, tier = v.tier })
	return result("ok")
end

handlers.hireWorker = function(self, a, now)
	local slot = slotArg(a, Workers.MaxSlots)
	if not slot then
		return result("invalid")
	end
	local price, code = Prices.HireWorker(self.state, slot, self:Mods(now))
	if not price then
		return result(code)
	end
	if not spend(self, price) then
		return result("cant_afford")
	end
	local w = self.state.workers[slot]
	w.tier, w.load, w.t, w.house = 1, 0, 0, 1
	purchased(self, "worker", { kind = "worker", slot = slot, tier = 1 })
	return result("ok")
end

handlers.upgradeWorker = function(self, a, now)
	local slot = slotArg(a, Workers.MaxSlots)
	if not slot then
		return result("invalid")
	end
	local w = self.state.workers[slot]
	if not expectOk(a, w.tier) then
		return result("stale")
	end
	local price, code = Prices.UpgradeWorker(self.state, slot)
	if not price then
		return result(code)
	end
	if not spend(self, price) then
		return result("cant_afford")
	end
	w.tier += 1
	purchased(self, "worker", { kind = "worker", slot = slot, tier = w.tier })
	return result("ok")
end

handlers.buildSilo = function(self, a, now)
	if not expectOk(a, self.state.silos) then
		return result("stale")
	end
	local price, code = Prices.Silo(self.state)
	if not price then
		return result(code)
	end
	if not spend(self, price) then
		return result("cant_afford")
	end
	self.state.silos += 1
	purchased(self, "silo", { kind = "silo", count = self.state.silos })
	return result("ok")
end

local function buyUpgrade(self: Farm, a: any, now: number, wantEpic: boolean)
	if not Validate.Id(a.id) then
		return result("invalid")
	end
	local u = Upgrades.ById[a.id]
	if not u or (table.find(Upgrades.Epic, u) ~= nil) ~= wantEpic then
		return result("invalid")
	end
	local levels = if wantEpic then self.state.epic else self.state.common
	local level = levels[a.id] or 0
	if not expectOk(a, level) then
		return result("stale")
	end
	local price, code, currency = Prices.Upgrade(self.state, a.id, self:Mods(now))
	if not price then
		return result(code)
	end
	if currency == "gold" then
		if not spendGold(self, price) then
			return result("cant_afford_gold")
		end
	elseif not spend(self, price) then
		return result("cant_afford")
	end
	levels[a.id] = level + 1
	purchased(self, "upgrade", { kind = if wantEpic then "epic" else "common", id = a.id, level = level + 1 })
	return result("ok")
end

handlers.buyCommon = function(self, a, now)
	return buyUpgrade(self, a, now, false)
end

handlers.buyEpic = function(self, a, now)
	return buyUpgrade(self, a, now, true)
end

-- Starts the next farm. Fields in State.RESET_FIELDS are cleared; eggs still on the farm are
-- counted as discarded so the conservation ledger stays exact.
local function newFarm(self: Farm, nextEgg: number)
	local s = self.state
	Rewards.Track(s, "discarded", State.EggsOnFarm(s))
	State.ApplyFreshFarm(s)
	s.egg = nextEgg
	self.combo = 1
	self.dirty = true
end

handlers.rebirth = function(self, a, now)
	local s = self.state
	if not expectOk(a, s.egg) then
		return result("stale")
	end
	if s.egg >= Eggs.Count then
		return result("last_egg")
	end
	if self:FarmValue() < Eggs.List[s.egg].requirement then
		return result("not_requirement")
	end
	local from = s.egg
	newFarm(self, from + 1)
	s.rebirths += 1
	local granted = Rewards.Grant(s, { gold = Eggs.List[s.egg].rebirthGold }, now, self.ctx, true)
	self:Emit("Rebirth", { from = from, to = s.egg, gold = granted.gold or 0 })
	return result("ok")
end

handlers.skip = function(self, a, now)
	local s = self.state
	if not expectOk(a, s.egg) then
		return result("stale")
	end
	local cost, code = Prices.Skip(s, self:FarmValue())
	if not cost then
		return result(code)
	end
	if not spendGold(self, cost) then
		return result("cant_afford_gold")
	end
	local from = s.egg
	newFarm(self, from + 1)
	s.rebirths += 1
	local granted = Rewards.Grant(s, { gold = Eggs.List[s.egg].rebirthGold }, now, self.ctx, true)
	self:Emit("Rebirth", { from = from, to = s.egg, gold = granted.gold or 0, skipped = true, cost = cost })
	return result("ok")
end

-- Stars granted by a prestige (DESIGN rule; the reference's prestige rules are unknown).
function Economy.PrestigeStars(state: any): number
	return 10 + 5 * state.prestiges
end

handlers.prestige = function(self, a, now)
	local s = self.state
	if not expectOk(a, s.egg) then
		return result("stale")
	end
	if s.egg < Eggs.Count then
		return result("not_last_egg")
	end
	if self:FarmValue() < Eggs.List[s.egg].requirement then
		return result("not_requirement")
	end
	local stars = Economy.PrestigeStars(s)
	newFarm(self, 1)
	s.prestiges += 1
	s.stars += stars
	self:Emit("Prestige", { stars = stars, total = s.stars })
	return result("ok")
end

handlers.useBoost = function(self, a, now)
	local s = self.state
	if not Validate.Id(a.id) or not Boosts.ById[a.id] then
		return result("invalid")
	end
	local have = s.boosts.inventory[a.id] or 0
	if have <= 0 then
		return result("no_boost")
	end
	local b = Boosts.ById[a.id]
	local existing
	for _, act in s.boosts.active do
		if act.id == a.id then
			existing = act
		end
	end
	if existing then
		if existing.endsAt - now >= Boosts.MaxDuration then
			return result("max_level")
		end
		existing.endsAt = math.min(now + Boosts.MaxDuration, existing.endsAt + b.duration)
	else
		if #s.boosts.active >= self:Mods(now).maxBoosts then
			return result("boost_limit")
		end
		table.insert(s.boosts.active, { id = a.id, endsAt = now + b.duration })
	end
	s.boosts.inventory[a.id] = have - 1
	if s.boosts.inventory[a.id] == 0 then
		s.boosts.inventory[a.id] = nil
	end
	Rewards.Track(s, "boostsUsed", 1)
	self:Emit("BoostUsed", { id = a.id })
	self.dirty = true
	return result("ok")
end

handlers.claimQuest = function(self, a, now)
	local s = self.state
	if not Validate.Id(a.id) then
		return result("invalid")
	end
	Rewards.RollDay(s, now)
	local q = Rewards.FindQuest(s.quests.day, a.id)
	if not q then
		return result("invalid")
	end
	if s.quests.claimed[q.id] then
		return result("already")
	end
	if (s.quests.progress[q.stat] or 0) < q.target then
		return result("not_ready")
	end
	s.quests.claimed[q.id] = true
	local granted = Rewards.Grant(s, q.reward, now, self.ctx, true)
	self:Emit("Reward", { source = "quest", id = q.id, granted = granted })
	self.dirty = true
	return result("ok")
end

handlers.claimDaily = function(self, a, now)
	local s = self.state
	local today = Rewards.Day(now)
	if not Rewards.DailyCanClaim(s, now) then
		return result("already")
	end
	local dayIndex = Rewards.DailyNextDay(s, now)
	s.daily.streak = if s.daily.lastDay == today - 1 then s.daily.streak + 1 else 1
	s.daily.lastDay = today
	local granted = Rewards.Grant(s, RewardData.Daily[dayIndex], now, self.ctx, true)
	self:Emit("Reward", { source = "daily", day = dayIndex, granted = granted })
	self.dirty = true
	return result("ok")
end

local function claimGift(self: Farm, i: number, now: number): string
	local s = self.state
	local g = RewardData.Gifts[i]
	if not g then
		return "invalid"
	end
	local key = tostring(i) -- string keys: DataStores reject sparse numeric tables
	if s.gifts.claimed[key] then
		return "already"
	end
	if s.gifts.playtime < g.minutes * 60 then
		return "not_ready"
	end
	s.gifts.claimed[key] = true
	local granted = Rewards.Grant(s, g.reward, now, self.ctx, true)
	self:Emit("Reward", { source = "gift", index = i, granted = granted })
	self.dirty = true
	return "ok"
end

handlers.claimGift = function(self, a, now)
	if not Validate.Int(a.index, 1, #RewardData.Gifts) then
		return result("invalid")
	end
	Rewards.RollDay(self.state, now)
	return result(claimGift(self, a.index, now))
end

handlers.claimAllGifts = function(self, a, now)
	Rewards.RollDay(self.state, now)
	local any = false
	for i in RewardData.Gifts do
		if claimGift(self, i, now) == "ok" then
			any = true
		end
	end
	return result(if any then "ok" else "not_ready")
end

-- Codes are matched case-insensitively. The code table lives on the server only.
handlers.redeemCode = function(self, a, now)
	local s = self.state
	if not Validate.Text(a.text, 32) then
		return result("code_invalid")
	end
	if not s.tutorial.done then
		return result("tutorial")
	end
	local key = string.upper(a.text)
	local def = self.ctx.codes and self.ctx.codes[key]
	if not def then
		return result("code_invalid")
	end
	if s.codes[key] then
		return result("code_used")
	end
	if def.expires and now >= def.expires then
		return result("code_expired")
	end
	s.codes[key] = true
	local granted = Rewards.Grant(s, def.reward, now, self.ctx, false)
	self:Emit("Reward", { source = "code", code = key, granted = granted })
	self.dirty = true
	return result("code_ok")
end

-- Items bought with Gold Eggs (boost shop). Robux items never come through here.
handlers.buyGoldItem = function(self, a, now)
	if not Validate.Id(a.id) then
		return result("invalid")
	end
	local p = Products.ById[a.id]
	if not p or p.kind ~= "gold" or not p.goldPrice then
		return result("invalid")
	end
	if not spendGold(self, p.goldPrice) then
		return result("cant_afford_gold")
	end
	local granted = Rewards.Grant(self.state, p.grant, now, self.ctx, false)
	self:Emit("Reward", { source = "shop", id = p.id, granted = granted })
	self.dirty = true
	return result("ok")
end

handlers.setSetting = function(self, a, now)
	if not Validate.Id(a.id) then
		return result("invalid")
	end
	local rule = Contract.Settings[a.id]
	if rule == nil then
		return result("invalid")
	end
	if rule == "boolean" then
		if not Validate.Bool(a.value) then
			return result("invalid")
		end
		if a.id == "autoSpawn" then
			return handlers.setAutoSpawn(self, { value = a.value }, now)
		end
	elseif type(rule) == "table" then
		if not Validate.OneOf(a.value, rule) then
			return result("invalid")
		end
	end
	self.state.settings[a.id] = a.value
	self.dirty = true
	return result("ok")
end

handlers.claimOffline = function(self, a, now)
	local s = self.state
	if s.offline.pending <= 0 then
		return result("not_ready")
	end
	local cash = s.offline.pending
	s.cash = math.min(CAP, s.cash + cash)
	s.offline.pending = 0
	s.offline.seconds = 0
	Rewards.Track(s, "cashEarned", cash)
	self:Emit("Reward", { source = "offline", granted = { cash = cash } })
	self.dirty = true
	return result("ok")
end

-- Entry point for client requests. Rejects unknown/server-only actions, malformed tables and
-- replayed sequence numbers before any handler runs. Handlers never yield, so each one is atomic.
function Economy.Apply(self: Farm, action: any, now: number): { ok: boolean, code: string, message: string? }
	if type(action) ~= "table" or type(action.type) ~= "string" then
		return result("invalid")
	end
	if not Contract.ClientActions[action.type] then
		return result("invalid")
	end
	if action.seq ~= nil then
		if not Validate.Int(action.seq, 1, 2 ^ 52) or action.seq <= self.lastSeq then
			return result("stale")
		end
		self.lastSeq = action.seq
	end
	Rewards.RollDay(self.state, now)
	local h = handlers[action.type]
	return h(self, action, now)
end

------------------------------------------------------------------------------------------------
-- Simulation
------------------------------------------------------------------------------------------------

-- Splits the population over the owned houses in proportion to their capacity.
function Economy.Occupants(self: Farm, m: Modifiers.Mods): { number }
	local s = self.state
	local cap = Modifiers.TotalCapacity(s, m)
	local out = {}
	for i, h in s.housing do
		local c = Modifiers.HouseCapacity(h.tier, m)
		out[i] = if cap > 0 then s.population * c / cap else 0
	end
	return out
end

local function stepSlice(self: Farm, dt: number, now: number)
	local s = self.state
	local m = self:Mods(now)

	-- 1. hatching: Coop Hatchery (per owned house) + Auto Spawn, capped by housing capacity
	local cap = Modifiers.TotalCapacity(s, m)
	local owned = 0
	for _, h in s.housing do
		if h.tier > 0 then
			owned += 1
		end
	end
	local rate = m.hatchPerHouse * owned
	if s.settings.autoSpawn and s.tutorial.done then
		rate += m.autoSpawnRate
	end
	if rate > 0 and s.population < cap then
		s.hatchPartial += rate * dt
		local whole = math.floor(s.hatchPartial)
		if whole > 0 then
			local add = math.min(whole, cap - s.population)
			s.population += add
			s.hatchPartial -= whole
			Rewards.Track(s, "spawned", add)
			self.dirty = true
		end
	elseif s.population >= cap then
		s.hatchPartial = 0
	end
	if s.population > cap then
		s.population = cap -- only if capacity ever shrinks (e.g. a pass removed in testing)
	end

	-- 2. laying: whole eggs go into each house's storage until it's full
	local occ = Economy.Occupants(self, m)
	local anyFull = false
	for i, h in s.housing do
		if h.tier > 0 and occ[i] > 0 then
			local storage = Modifiers.HouseStorage(h.tier, m)
			if h.eggs >= storage then
				anyFull = true
				h.partial = 0
			else
				h.partial += occ[i] * m.layRate * dt
				local whole = math.floor(h.partial)
				if whole > 0 then
					h.partial -= whole
					local add = math.min(whole, storage - h.eggs)
					h.eggs += add
					Rewards.Track(s, "laid", add)
					self.dirty = true
					if h.eggs >= storage then
						anyFull = true
					end
				end
			end
		end
	end
	if anyFull then
		self:Notice("StorageFull", now, 20)
	end

	-- 3. workers: pick up halfway through the cycle, drop at the warehouse at the end
	for _, w in s.workers do
		if w.tier > 0 then
			local cycle = Modifiers.WorkerCycle(w.tier)
			local before = w.t
			w.t += dt
			if before < cycle / 2 and w.t >= cycle / 2 and w.load == 0 then
				local best, bestEggs = 0, 0
				for i, h in s.housing do
					if h.tier > 0 and h.eggs > bestEggs then
						best, bestEggs = i, h.eggs
					end
				end
				if best > 0 then
					local take = math.min(Modifiers.WorkerCarry(w.tier, m), bestEggs)
					s.housing[best].eggs -= take
					w.load = take
					w.house = best
					self.dirty = true
				end
			end
			if w.t >= cycle then
				w.t -= cycle
				if w.t >= cycle then
					w.t = 0
				end
				if w.load > 0 then
					s.warehouse += w.load
					Rewards.Track(s, "workerDeposited", w.load)
					w.load = 0
					self.dirty = true
				end
			end
		end
	end

	-- 4. vehicles: load at the dock, sell halfway through the trip, come back
	for i, v in s.vehicles do
		if v.tier > 0 then
			local capV = Modifiers.VehicleCap(v.tier)
			local half = Modifiers.VehicleTrip(v.tier, m) / 2
			if v.phase == "dock" then
				if v.load < capV and s.warehouse > 0 then
					local take = math.min(capV - v.load, s.warehouse)
					s.warehouse -= take
					v.load += take
					self.dirty = true
				end
				if v.load > 0 then
					v.t += dt
					if v.load >= capV or v.t >= Vehicles.LoadWait then
						v.phase, v.t = "out", 0
						self:Emit("VehicleLeft", { slot = i })
						self.dirty = true
					end
				else
					v.t = 0
				end
			elseif v.phase == "out" then
				v.t += dt
				if v.t >= half then
					local combo = self.combo
					local cash = math.min(CAP, v.load * m.eggValue * m.saleMult * combo)
					s.cash = math.min(CAP, s.cash + cash)
					Rewards.Track(s, "sold", v.load)
					Rewards.Track(s, "cashEarned", cash)
					self:Emit("Sold", { slot = i, eggs = v.load, cash = cash })
					v.load = 0
					v.phase, v.t = "back", 0
					self.dirty = true
				end
			elseif v.phase == "back" then
				v.t += dt
				if v.t >= half then
					v.phase, v.t = "dock", 0
					self:Emit("VehicleBack", { slot = i })
					self.dirty = true
				end
			end
		end
	end

	-- 5. tap combo decays after a short pause
	if self.combo > 1 and now - self.lastTap > 1.5 then
		self.combo = math.max(1, self.combo - 0.75 * dt)
		self.dirty = true
	end

	-- 6. playtime for gifts and quests
	s.gifts.playtime += dt
	Rewards.Track(s, "playtime", dt)
end

function Economy.Step(self: Farm, dt: number, now: number)
	if not Validate.Finite(dt) or dt <= 0 then
		return
	end
	local s = self.state
	Rewards.RollDay(s, now)
	-- expire boosts (server real time)
	local active = s.boosts.active
	for i = #active, 1, -1 do
		if active[i].endsAt <= now then
			self:Emit("BoostEnded", { id = active[i].id })
			table.remove(active, i)
			self.dirty = true
		end
	end
	local remaining = dt
	local sliceStart = now - dt
	while remaining > 0 do
		local slice = math.min(remaining, MAX_STEP)
		remaining -= slice
		sliceStart += slice
		stepSlice(self, slice, sliceStart)
	end
	s.lastSeen = now
	if Tutorial.Update(s) then
		self.dirty = true
	end
end

-- Silo earnings for time spent away. Called once when a save loads. Boosts don't count and the
-- farm itself doesn't run while you're away; only silos earn (DESIGN rule; docs/DESIGN.md).
function Economy.ComputeOffline(self: Farm, now: number)
	local s = self.state
	local away = now - (s.lastSeen or now)
	s.lastSeen = now
	local silos = s.silos + (if s.passes.perma_silos then Silos.Max else 0)
	if away < Silos.MinAwaySeconds or silos <= 0 or not Validate.Finite(away) then
		return
	end
	local m = Modifiers.Compute(s, now, self.ctx, true)
	local seconds = math.min(away, silos * m.siloMinutes * 60)
	local cash = math.floor(Modifiers.SteadyCashRate(s, now, self.ctx) * Silos.OfflineRate * m.offlineMult * seconds)
	if cash > 0 then
		s.offline.pending = math.min(CAP, s.offline.pending + cash)
		s.offline.seconds = seconds
		self.dirty = true
	end
end

-- Robux purchase fulfilment (called by the server's commerce layer after a confirmed receipt).
-- Idempotent per purchase id: a replayed receipt grants nothing the second time.
function Economy.GrantProduct(self: Farm, productId: string, purchaseId: string, now: number): (boolean, string)
	local s = self.state
	local p = Products.ById[productId]
	if not p or (p.kind ~= "pass" and p.kind ~= "product") then
		return false, "invalid"
	end
	if type(purchaseId) ~= "string" or #purchaseId == 0 or #purchaseId > 64 then
		return false, "invalid"
	end
	if s.receipts[purchaseId] then
		return true, "already"
	end
	s.receipts[purchaseId] = now
	if p.grant.pass then
		s.passes[p.grant.pass] = true
	end
	local granted = Rewards.Grant(s, p.grant, now, self.ctx, false)
	self:Emit("Reward", { source = "purchase", id = productId, granted = granted })
	self.dirty = true
	return true, "ok"
end

------------------------------------------------------------------------------------------------
-- Snapshot
------------------------------------------------------------------------------------------------

function Economy.Snapshot(self: Farm, now: number): any
	local s = self.state
	local m = self:Mods(now)
	local rates = Modifiers.Rates(s, m)
	local occ = Economy.Occupants(self, m)
	local fv = self:FarmValue()
	local egg = Eggs.List[s.egg]
	local skip = Prices.Skip(s, fv)

	local housing = {}
	for i, h in s.housing do
		housing[i] = {
			tier = h.tier,
			eggs = h.eggs,
			storage = Modifiers.HouseStorage(h.tier, m),
			capacity = Modifiers.HouseCapacity(h.tier, m),
			occupants = math.floor(occ[i] + 0.5),
		}
	end
	local vehicles = {}
	for i, v in s.vehicles do
		vehicles[i] = {
			tier = v.tier,
			load = v.load,
			phase = v.phase,
			t = v.t,
			trip = if v.tier > 0 then Modifiers.VehicleTrip(v.tier, m) else 0,
			cap = Modifiers.VehicleCap(v.tier),
		}
	end
	local workers = {}
	for i, w in s.workers do
		workers[i] = {
			tier = w.tier,
			load = w.load,
			t = w.t,
			cycle = if w.tier > 0 then Modifiers.WorkerCycle(w.tier) else 0,
			house = w.house,
		}
	end
	local quests = {}
	local day = Rewards.Day(now)
	for _, q in Rewards.QuestsForDay(day) do
		table.insert(quests, {
			id = q.id,
			progress = math.min(q.target, if s.quests.day == day then s.quests.progress[q.stat] or 0 else 0),
			target = q.target,
			claimed = s.quests.day == day and s.quests.claimed[q.id] == true,
		})
	end

	local flow = math.min(rates.lay, rates.ship)
	return {
		serverNow = now,
		cash = s.cash,
		gold = s.gold,
		stars = s.stars,
		population = s.population,
		capacity = Modifiers.TotalCapacity(s, m),
		egg = s.egg,
		eggValue = m.eggValue,
		farmValue = fv,
		nextRequirement = egg.requirement,
		canRebirth = s.egg < Eggs.Count and fv >= egg.requirement,
		canPrestige = s.egg == Eggs.Count and fv >= egg.requirement,
		skipCost = skip or -1,
		rebirths = s.rebirths,
		prestiges = s.prestiges,
		combo = self.combo,
		comboMax = m.comboMax,
		spawnPerTap = m.spawnPerTap,
		autoSpawnRate = m.autoSpawnRate,
		rates = {
			lay = rates.lay,
			hatch = m.hatchPerHouse,
			ship = rates.ship,
			workers = rates.workers,
			cash = flow * m.eggValue * m.saleMult * self.combo,
		},
		mods = {
			layRate = m.layRate,
			saleMult = m.saleMult,
			capacityMult = m.capacityMult,
			tripMult = m.tripMult,
			workerMult = m.workerMult,
			commonPriceMult = m.commonPriceMult,
			siloMinutes = m.siloMinutes,
		},
		housing = housing,
		carried = s.carried,
		carryCap = m.carryCap,
		warehouse = s.warehouse,
		vehicles = vehicles,
		vehicleSlots = m.vehicleSlots,
		workers = workers,
		workerSlots = m.workerSlots,
		silos = s.silos,
		permanentSilos = if s.passes.perma_silos then Silos.Max else 0,
		common = table.clone(s.common),
		epic = table.clone(s.epic),
		boosts = {
			inventory = table.clone(s.boosts.inventory),
			active = table.clone(s.boosts.active),
			maxActive = m.maxBoosts,
		},
		quests = { day = day, list = quests },
		daily = {
			streak = s.daily.streak,
			canClaim = Rewards.DailyCanClaim(s, now),
			nextDay = Rewards.DailyNextDay(s, now),
			resetsIn = (day + 1) * 86400 - now,
		},
		gifts = { playtime = if s.gifts.day == day then s.gifts.playtime else 0, claimed = table.clone(s.gifts.claimed) },
		settings = table.clone(s.settings),
		tutorial = { step = s.tutorial.step, done = s.tutorial.done },
		passes = table.clone(s.passes),
		offline = { pending = s.offline.pending, seconds = s.offline.seconds },
		walkSpeed = m.walkSpeed,
	}
end

return Economy
