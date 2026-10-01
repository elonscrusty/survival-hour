-- Balance simulator: a greedy bot plays the real Economy module from a fresh save to prestige.
--   luau tools/sim.luau            (from egg-farm/)
-- The bot taps Spawn 5x/s while houses have room, walks a collection loop every `WALK` seconds
-- (collect every house, deposit), keeps Auto Spawn on, buys the cheapest available purchase each second, spends Gold
-- Eggs on Golden Touch / Hen Whisperer, and rebirths as soon as allowed. No boosts, no passes,
-- no quests/daily/codes, no Robux: a deliberately plain player. Prints minutes per farm.

local Economy = require("../src/shared/Logic/Economy")
local State = require("../src/shared/Logic/State")
local Prices = require("../src/shared/Logic/Prices")
local Upgrades = require("../src/shared/Data/Upgrades")
local Eggs = require("../src/shared/Data/Eggs")
local Format = require("../src/shared/Format")

local WALK = tonumber((...)) or 25
local TAPS = 5
local LIMIT_HOURS = 30

local now = 1_800_000_000
local s = State.New(now)
local f = Economy.new(s, {})

local function candidates()
	local m = f:Mods(now)
	local list = {}
	local function add(price, action)
		if price then
			table.insert(list, { price = price, action = action })
		end
	end
	for i = 1, 4 do
		add(Prices.BuyHouse(s, i), { type = "buyHouse", slot = i })
		add(Prices.UpgradeHouse(s, i), { type = "upgradeHouse", slot = i })
	end
	for i = 1, 8 do
		add(Prices.BuyVehicle(s, i, m), { type = "buyVehicle", slot = i })
		add(Prices.UpgradeVehicle(s, i), { type = "upgradeVehicle", slot = i })
		add(Prices.HireWorker(s, i, m), { type = "hireWorker", slot = i })
		add(Prices.UpgradeWorker(s, i), { type = "upgradeWorker", slot = i })
	end
	for _, u in Upgrades.Common do
		local p, _, cur = Prices.Upgrade(s, u.id, m)
		if cur == "cash" and u.id ~= "shoes" then
			add(p, { type = "buyCommon", id = u.id })
		end
	end
	add(Prices.Silo(s), { type = "buildSilo" })
	table.sort(list, function(a, b)
		return a.price < b.price
	end)
	return list
end

s.tutorial.step, s.tutorial.done = 8, true -- the bot plays like a player who finished the tutorial
f:Apply({ type = "setAutoSpawn", value = true }, now)
local farmStart = now
local t0 = now
local nextWalk = now + WALK
print(string.format("walk loop every %ds, %d taps/s", WALK, TAPS))
while now - t0 < LIMIT_HOURS * 3600 do
	-- taps
	local snap = f:Snapshot(now)
	if snap.population < snap.capacity then
		for _ = 1, TAPS do
			f:Apply({ type = "spawn" }, now)
		end
	end
	now += 1
	f:Step(1, now)
	if now >= nextWalk then
		nextWalk = now + WALK
		for i = 1, 4 do
			f:Collect(i, now)
			f:Deposit(now)
		end
	end
	-- spend: keep a little cash aside near the goal so farm value isn't the bottleneck
	for _ = 1, 3 do
		local c = candidates()[1]
		if c and s.cash >= c.price then
			f:Apply(c.action, now)
		else
			break
		end
	end
	for _, id in { "golden_touch", "hen_whisperer", "auto_clicker" } do
		f:Apply({ type = "buyEpic", id = id }, now)
	end
	if f:Snapshot(now).canRebirth then
		local from = s.egg
		f:Apply({ type = "rebirth", expect = s.egg }, now)
		print(string.format("egg %2d -> %2d after %6.1f min (total %5.1f h)  gold %d", from, s.egg, (now - farmStart) / 60, (now - t0) / 3600, s.gold))
		farmStart = now
	elseif f:Snapshot(now).canPrestige then
		print(string.format("PRESTIGE ready after %.1f min on the last egg (total %.1f h)", (now - farmStart) / 60, (now - t0) / 3600))
		break
	end
end
local snap = f:Snapshot(now)
print(string.format("end: egg %d, cash %s, pop %s/%s, farm value %s / %s", s.egg, Format.Short(s.cash), Format.Short(snap.population), Format.Short(snap.capacity), Format.Short(snap.farmValue), Format.Short(snap.nextRequirement)))
