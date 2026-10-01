local H = require("./Helpers")
local Housing = require("../src/shared/Data/Housing")
local Vehicles = require("../src/shared/Data/Vehicles")
local Modifiers = require("../src/shared/Logic/Modifiers")
local Prices = require("../src/shared/Logic/Prices")

return {
	fresh_farm_starting_state = function(t)
		local f, s = H.Farm()
		t.eq(s.cash, 0)
		t.eq(s.population, 0)
		t.eq(s.housing[1].tier, 1, "one coop owned")
		t.eq(s.vehicles[1].tier, 1, "one pickup owned")
		t.eq(s.workers[1].tier, 0, "no workers")
		local snap = f:Snapshot(H.T0)
		t.eq(snap.capacity, Housing.Tiers[1].capacity)
		t.eq(snap.carryCap, Modifiers.BASE_CARRY)
	end,

	spawn_adds_chickens_and_respects_capacity = function(t)
		local f, s = H.Farm()
		for _ = 1, 150 do
			f:Apply({ type = "spawn" }, H.T0)
		end
		t.eq(s.population, 100, "capped at Little Coop capacity")
		local r = f:Apply({ type = "spawn" }, H.T0)
		t.no(r.ok)
		t.eq(r.code, "full")
	end,

	production_fills_storage_then_stops = function(t)
		local f, s = H.Farm(function(s)
			s.population = 100
		end)
		f:Step(10, H.T0 + 10)
		t.eq(s.housing[1].eggs, 100, "100 hens x 0.1/s x 10s")
		f:Step(10000, H.T0 + 10010)
		t.eq(s.housing[1].eggs, Housing.Tiers[1].capacity * Housing.StoragePerChicken, "stops at storage")
	end,

	collect_takes_up_to_basket_space = function(t)
		local f, s = H.Farm(function(s)
			s.housing[1].eggs = 250
		end)
		local r = f:Collect(1, H.T0)
		t.ok(r.ok)
		t.eq(s.carried, 100)
		t.eq(s.housing[1].eggs, 150)
		r = f:Collect(1, H.T0)
		t.eq(r.code, "basket_full")
		t.eq(s.housing[1].eggs, 150, "nothing moved when full")
	end,

	collect_rejects_empty_and_unowned = function(t)
		local f = H.Farm()
		t.eq(f:Collect(1, H.T0).code, "empty")
		t.eq(f:Collect(2, H.T0).code, "invalid", "slot 2 not bought")
		t.eq(f:Collect(9, H.T0).code, "invalid")
		t.eq(f:Collect(0 / 0, H.T0).code, "invalid")
	end,

	deposit_moves_basket_to_warehouse = function(t)
		local f, s = H.Farm(function(s)
			s.carried = 70
		end)
		t.ok(f:Deposit(H.T0).ok)
		t.eq(s.carried, 0)
		t.eq(s.warehouse, 70)
		t.eq(f:Deposit(H.T0).code, "nothing_carried")
	end,

	vehicle_loads_sells_and_returns = function(t)
		local f, s = H.Farm(function(s)
			s.warehouse = 100
		end)
		f:Step(0.25, H.T0)
		t.eq(s.vehicles[1].load, 40, "pickup loads its capacity")
		t.eq(s.warehouse, 60)
		t.eq(s.vehicles[1].phase, "out", "full load leaves at once")
		f:Step(Vehicles.Tiers[1].trip / 2, H.T0 + 5)
		t.eq(s.cash, 40, "40 eggs x $1")
		t.eq(s.vehicles[1].phase, "back")
		t.eq(s.stats.sold, 40)
	end,

	partial_load_waits_then_leaves = function(t)
		local f, s = H.Farm(function(s)
			s.warehouse = 5
		end)
		f:Step(1, H.T0 + 1)
		t.eq(s.vehicles[1].phase, "dock", "waits for more eggs")
		f:Step(Vehicles.LoadWait, H.T0 + 4)
		t.eq(s.vehicles[1].phase, "out")
	end,

	upgrade_house_charges_once = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 1000
		end)
		local price = Prices.UpgradeHouse(s, 1)
		local r = f:Apply({ type = "upgradeHouse", slot = 1, expect = 1 }, H.T0)
		t.ok(r.ok)
		t.eq(s.housing[1].tier, 2)
		t.eq(s.cash, 1000 - price)
		-- the same request again (double tap) is stale, not a second purchase
		r = f:Apply({ type = "upgradeHouse", slot = 1, expect = 1 }, H.T0)
		t.eq(r.code, "stale")
		t.eq(s.cash, 1000 - price)
		t.eq(s.invested, price, "farm value counts what was spent")
	end,

	cant_afford_changes_nothing = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 10
		end)
		local r = f:Apply({ type = "upgradeHouse", slot = 1, expect = 1 }, H.T0)
		t.eq(r.code, "cant_afford")
		t.eq(s.cash, 10)
		t.eq(s.housing[1].tier, 1)
	end,

	slots_must_be_bought_in_order = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 1e9
		end)
		t.eq(f:Apply({ type = "buyHouse", slot = 3 }, H.T0).code, "slot_locked")
		t.ok(f:Apply({ type = "buyHouse", slot = 2 }, H.T0).ok)
		t.eq(f:Apply({ type = "buyHouse", slot = 2 }, H.T0).code, "slot_taken")
		t.eq(s.housing[2].tier, 1)
	end,

	tiers_lock_until_later_eggs = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 1e12
			s.housing[1].tier = 4
		end)
		t.eq(f:Apply({ type = "upgradeHouse", slot = 1, expect = 4 }, H.T0).code, "locked")
		s.egg = 2
		t.ok(f:Apply({ type = "upgradeHouse", slot = 1, expect = 4 }, H.T0).ok)
	end,

	max_level_is_reported = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 1e300
			s.egg = 10
			s.housing[1].tier = Housing.MaxTier
		end)
		t.eq(f:Apply({ type = "upgradeHouse", slot = 1 }, H.T0).code, "max_level")
	end,

	vehicle_slots_need_fleet_permit = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 1e12
			for i = 2, 4 do
				s.vehicles[i].tier = 1
			end
		end)
		t.eq(f:Apply({ type = "buyVehicle", slot = 5 }, H.T0).code, "locked")
		t.ok(f:Apply({ type = "buyCommon", id = "fleet", expect = 0 }, H.T0).ok)
		t.ok(f:Apply({ type = "buyVehicle", slot = 5 }, H.T0).ok)
	end,

	workers_move_eggs_to_warehouse = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 1e6
			s.housing[1].eggs = 500
		end)
		t.ok(f:Apply({ type = "hireWorker", slot = 1 }, H.T0).ok)
		f:Step(6, H.T0 + 6)
		t.eq(s.workers[1].load, 25, "picked up at half cycle")
		t.eq(s.housing[1].eggs, 475)
		f:Step(6, H.T0 + 12)
		t.eq(s.workers[1].load, 0)
		t.ok(s.warehouse + s.vehicles[1].load == 25, "dropped at the warehouse")
	end,

	common_upgrade_effects_apply = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 1e6
		end)
		t.ok(f:Apply({ type = "buyCommon", id = "basket", expect = 0 }, H.T0).ok)
		t.eq(f:Snapshot(H.T0).carryCap, 200)
		t.ok(f:Apply({ type = "buyCommon", id = "spawner", expect = 0 }, H.T0).ok)
		f:Apply({ type = "spawn" }, H.T0)
		t.eq(s.population, 2, "2 per tap")
	end,

	epic_upgrades_cost_gold = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 1e9
			s.gold = 10
		end)
		t.eq(f:Apply({ type = "buyEpic", id = "auto_clicker", expect = 0 }, H.T0).code, "cant_afford_gold")
		s.gold = 25
		t.ok(f:Apply({ type = "buyEpic", id = "auto_clicker", expect = 0 }, H.T0).ok)
		t.eq(s.gold, 0)
		t.eq(s.cash, 1e9, "cash untouched")
		t.eq(f:Apply({ type = "buyCommon", id = "auto_clicker" }, H.T0).code, "invalid", "epic id on common route")
	end,

	auto_spawn_needs_tutorial_and_spawns = function(t)
		local f, s = H.Farm()
		t.eq(f:Apply({ type = "setAutoSpawn", value = true }, H.T0).code, "tutorial")
		H.Done(s)
		t.ok(f:Apply({ type = "setAutoSpawn", value = true }, H.T0).ok)
		f:Step(10, H.T0 + 10)
		t.eq(s.population, 5, "0.5/s base Auto Spawn")
	end,

	cash_multiplier_combo_rises_and_decays = function(t)
		local f, s = H.Farm()
		for _ = 1, 20 do
			f:Apply({ type = "spawn" }, H.T0)
		end
		t.ok(f.combo > 2.5, "combo built by taps")
		s.warehouse = 40
		f:Step(0.25, H.T0 + 0.25)
		f:Step(5, H.T0 + 1) -- sale while combo is still high (no decay before 1.5s idle)
		t.ok(s.cash > 40 * 2.5, "sale used the multiplier")
		f:Step(10, H.T0 + 30)
		t.eq(f.combo, 1, "decays back to x1")
	end,

	snapshot_is_plain_data = function(t)
		local f = H.Farm()
		local snap = f:Snapshot(H.T0)
		local function check(v, path)
			local ty = type(v)
			t.ok(ty == "number" or ty == "string" or ty == "boolean" or ty == "table", "plain value at " .. path)
			if ty == "number" then
				t.ok(v == v, "NaN at " .. path)
			end
			if ty == "table" then
				for k, x in v do
					t.ok(type(k) == "string" or type(k) == "number", "key type at " .. path)
					check(x, path .. "." .. tostring(k))
				end
			end
		end
		check(snap, "snap")
	end,
}
