-- Egg conservation: laid == on farm + sold + discarded, after every operation, under random
-- interleavings of production ticks, collection, deposits, worker/vehicle moves and new farms.
local H = require("./Helpers")

local function fuzz(t, seed, steps)
	local rng = H.Rng(seed)
	local f, s = H.Farm(function(s)
		s.cash = 5e5
		H.Done(s)
		s.settings.autoSpawn = true
	end, { rng = rng })
	local now = H.T0
	local actions = {
		function()
			f:Apply({ type = "spawn" }, now)
		end,
		function()
			f:Collect(1 + math.floor(rng() * 4), now)
		end,
		function()
			f:Deposit(now)
		end,
		function()
			local dt = rng() * 3
			now += dt
			f:Step(dt, now)
		end,
		function()
			f:Apply({ type = "hireWorker", slot = 1 + math.floor(rng() * 3) }, now)
		end,
		function()
			f:Apply({ type = "buyHouse", slot = 2 }, now)
			f:Apply({ type = "upgradeHouse", slot = 1 + math.floor(rng() * 2) }, now)
		end,
		function()
			f:Apply({ type = "buyVehicle", slot = 2 }, now)
			f:Apply({ type = "upgradeVehicle", slot = 1 }, now)
		end,
		function()
			f:Apply({ type = "buyCommon", id = "basket" }, now)
		end,
		function()
			if rng() < 0.03 then
				s.cash = math.max(s.cash, 150000) -- fixture: allow an occasional rebirth mid-flow
				f:Apply({ type = "rebirth", expect = s.egg }, now)
				s.cash += 5e5 * s.egg ^ 3
			end
		end,
	}
	for i = 1, steps do
		actions[1 + math.floor(rng() * #actions)]()
		local laid, accounted = H.Ledger(s)
		if laid ~= accounted then
			error(string.format("step %d: laid %d but accounted %d", i, laid, accounted))
		end
		for _, h in s.housing do
			t.ok(h.eggs >= 0 and h.eggs == math.floor(h.eggs), "whole, non-negative house eggs")
		end
		t.ok(s.carried >= 0 and s.warehouse >= 0, "non-negative balances")
	end
	return s
end

return {
	ledger_holds_under_random_play_seed1 = function(t)
		local s = fuzz(t, 1, 3000)
		t.ok((s.stats.laid or 0) > 0, "eggs were laid")
		t.ok((s.stats.sold or 0) > 0, "eggs were sold")
	end,
	ledger_holds_under_random_play_seed2 = function(t)
		fuzz(t, 99, 3000)
	end,
	ledger_holds_under_random_play_seed3 = function(t)
		local s = fuzz(t, 12345, 3000)
		t.ok(s.rebirths >= 0)
	end,

	collect_during_production_tick_is_exact = function(t)
		local f, s = H.Farm(function(s)
			s.population = 100
		end)
		-- interleave tiny ticks and collections: no egg created or lost at the boundary
		local now = H.T0
		for _ = 1, 200 do
			now += 0.05
			f:Step(0.05, now)
			f:Collect(1, now)
			if s.carried >= 100 then
				f:Deposit(now)
			end
		end
		local laid, accounted = H.Ledger(s)
		t.eq(accounted, laid)
	end,

	sale_pays_exactly_eggs_times_value = function(t)
		local f, s = H.Farm(function(s)
			s.warehouse = 1000
		end)
		local now = H.T0
		for _ = 1, 400 do
			now += 0.25
			f:Step(0.25, now)
		end
		t.eq(s.cash, s.stats.sold * 1, "cash = sold eggs x $1 (no multipliers)")
		t.eq(s.stats.cashEarned, s.cash)
	end,

	rebirth_discards_on_farm_eggs_into_ledger = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 150000
			s.stats.laid = 600
			s.housing[1].eggs = 300
			s.carried = 100
			s.warehouse = 150
			s.vehicles[1].load = 40
			s.stats.sold = 10
		end)
		t.ok(f:Apply({ type = "rebirth", expect = 1 }, H.T0).ok)
		t.eq(s.stats.discarded, 590)
		local laid, accounted = H.Ledger(s)
		t.eq(accounted, laid)
	end,
}
