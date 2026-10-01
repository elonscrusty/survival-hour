-- Largest intended values (every upgrade maxed, last egg, all passes) and beyond.
local H = require("./Helpers")
local Eggs = require("../src/shared/Data/Eggs")
local Housing = require("../src/shared/Data/Housing")
local Upgrades = require("../src/shared/Data/Upgrades")
local Modifiers = require("../src/shared/Logic/Modifiers")
local Format = require("../src/shared/Format")

local function maxed(s)
	H.Done(s)
	s.egg = Eggs.Count
	s.stars = 10000
	for _, u in Upgrades.Common do
		s.common[u.id] = u.max
	end
	for _, u in Upgrades.Epic do
		s.epic[u.id] = u.max
	end
	for _, h in s.housing do
		h.tier = Housing.MaxTier
	end
	for _, v in s.vehicles do
		v.tier = 8
	end
	for _, w in s.workers do
		w.tier = 8
	end
	for _, p in { "x2cash", "x2housing", "x2chickens", "x2workers", "x2shipping", "vip" } do
		s.passes[p] = true
	end
end

return {
	max_capacity_population_stays_exact = function(t)
		local f, s = H.Farm(maxed)
		local snap = f:Snapshot(H.T0)
		t.ok(snap.capacity < 2 ^ 53, "capacity is an exact integer range")
		s.population = snap.capacity
		local now = H.T0
		for _ = 1, 3600 do -- an hour at 1s slices
			now += 1
			f:Step(1, now)
			f:Collect(1, now)
			f:Deposit(now)
		end
		local laid, accounted = H.Ledger(s)
		t.eq(accounted, laid, "ledger exact at max scale")
		t.ok(laid < 2 ^ 53, "egg totals stay below 2^53 for an hour of max play")
		t.ok(s.cash > 0 and s.cash < math.huge)
	end,

	cash_is_clamped_not_infinite = function(t)
		local f, s = H.Farm(function(s)
			maxed(s)
			s.cash = 9.9e299
			s.warehouse = 1e12
		end)
		local now = H.T0
		for _ = 1, 50 do
			now += 1
			f:Step(1, now)
		end
		t.ok(s.cash <= Modifiers.CAP, "clamped at CAP")
		t.ok(s.cash == s.cash and s.cash ~= math.huge)
		t.ok(f:FarmValue() <= Modifiers.CAP)
	end,

	absurd_population_does_not_break_step = function(t)
		local f, s = H.Farm(function(s)
			maxed(s)
		end)
		s.population = 1e13 -- far beyond capacity (e.g. a corrupted save)
		f:Step(1, H.T0 + 1)
		t.ok(s.population <= f:Snapshot(H.T0 + 1).capacity, "clamped back to capacity")
		for _, h in s.housing do
			t.ok(h.eggs == math.floor(h.eggs))
		end
	end,

	prices_and_values_finite_at_the_top = function(t)
		local f = H.Farm(maxed)
		local snap = f:Snapshot(H.T0)
		for k, v in snap.rates do
			t.ok(v == v and v < math.huge, "rate " .. k)
		end
		t.ok(snap.eggValue < 1e30)
		t.ok(Eggs.List[Eggs.Count].requirement < 1e30)
		t.ok(#Format.Short(snap.rates.cash) <= 8, "formatted rate is short: " .. Format.Short(snap.rates.cash))
	end,

	step_cost_does_not_grow_with_population = function(t)
		local f1, s1 = H.Farm(maxed)
		local f2, s2 = H.Farm(maxed)
		s1.population = 10
		s2.population = f2:Snapshot(H.T0).capacity
		local c0 = os.clock()
		for i = 1, 2000 do
			f1:Step(0.25, H.T0 + i * 0.25)
		end
		local small = os.clock() - c0
		c0 = os.clock()
		for i = 1, 2000 do
			f2:Step(0.25, H.T0 + i * 0.25)
		end
		local big = os.clock() - c0
		t.ok(big < small * 3 + 0.05, string.format("step time independent of population (%.3fs vs %.3fs)", small, big))
	end,
}
