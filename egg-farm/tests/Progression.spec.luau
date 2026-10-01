-- Rebirth / SKIP / Prestige: exact reset and preservation rules, applied exactly once.
local H = require("./Helpers")
local Eggs = require("../src/shared/Data/Eggs")
local State = require("../src/shared/Logic/State")
local MemoryStore = require("../src/server/Persistence/MemoryStore")

local function richFarm(egg)
	return H.Farm(function(s)
		H.Done(s)
		s.egg = egg
		s.cash = Eggs.List[egg].requirement
		s.gold = 77
		s.stars = 3
		s.population = 90
		s.carried = 12
		s.warehouse = 34
		s.housing[1].tier = 3
		s.housing[2].tier = 2
		s.vehicles[1].tier = 3
		s.workers[1].tier = 2
		s.silos = 4
		s.common = { feed = 5, basket = 2 }
		s.epic = { auto_clicker = 3, golden_touch = 7 }
		s.boosts.inventory = { earn3 = 2 }
		s.boosts.active = { { id = "lay2", endsAt = H.T0 + 600 } }
		s.codes = { WELCOME = true }
		s.passes = { x2cash = true }
		s.receipts = { r1 = H.T0 }
		s.daily = { streak = 4, lastDay = 5 }
		s.settings.music = false
		s.stats.laid = 200
	end)
end

return {
	rebirth_needs_farm_value = function(t)
		local f, s = H.Farm()
		t.eq(f:Apply({ type = "rebirth", expect = 1 }, H.T0).code, "not_requirement")
		t.eq(s.egg, 1)
	end,

	rebirth_resets_exactly_the_reset_fields = function(t)
		local f, s = richFarm(1)
		local before = MemoryStore.DeepCopy(s)
		local r = f:Apply({ type = "rebirth", expect = 1 }, H.T0)
		t.ok(r.ok, r.code)
		local fresh = State.New(H.T0)
		for _, k in State.RESET_FIELDS do
			t.ok(MemoryStore.DeepCopy(fresh[k]) ~= nil or fresh[k] == nil)
			if type(fresh[k]) ~= "table" then
				t.eq(s[k], fresh[k], "reset " .. k)
			end
		end
		t.eq(s.housing[1].tier, 1)
		t.eq(s.housing[2].tier, 0)
		t.eq(s.vehicles[1].tier, 1)
		t.eq(s.workers[1].tier, 0)
		t.eq(next(s.common), nil, "common upgrades cleared")
		-- kept
		t.eq(s.egg, 2)
		t.eq(s.rebirths, 1)
		t.eq(s.gold, 77 + Eggs.List[2].rebirthGold, "gold kept + rebirth reward")
		t.eq(s.stars, 3)
		t.eq(s.epic.auto_clicker, 3)
		t.eq(s.epic.golden_touch, 7)
		t.eq(s.boosts.inventory.earn3, 2)
		t.eq(#s.boosts.active, 1)
		t.ok(s.codes.WELCOME)
		t.ok(s.passes.x2cash)
		t.eq(s.receipts.r1, H.T0)
		t.eq(s.daily.streak, 4)
		t.eq(s.settings.music, false)
		t.ok(s.tutorial.done)
		t.eq(s.stats.laid, before.stats.laid)
	end,

	rebirth_applies_once = function(t)
		local f, s = richFarm(1)
		t.ok(f:Apply({ type = "rebirth", expect = 1 }, H.T0).ok)
		local goldAfter = s.gold
		local r = f:Apply({ type = "rebirth", expect = 1 }, H.T0)
		t.eq(r.code, "stale", "the same request again is stale")
		t.eq(s.egg, 2)
		t.eq(s.gold, goldAfter)
		t.eq(f:Apply({ type = "rebirth", expect = 2 }, H.T0).code, "not_requirement", "new farm starts at 0")
	end,

	skip_costs_gold_and_needs_quarter_progress = function(t)
		local f, s = H.Farm(function(s)
			H.Done(s)
			s.gold = 1000
			s.cash = Eggs.List[1].requirement * 0.2
		end)
		t.eq(f:Apply({ type = "skip", expect = 1 }, H.T0).code, "skip_too_early")
		s.cash = Eggs.List[1].requirement * 0.5
		local snap = f:Snapshot(H.T0)
		t.eq(snap.skipCost, 15, "50% missing x 30 x egg 1")
		t.ok(f:Apply({ type = "skip", expect = 1 }, H.T0).ok)
		t.eq(s.egg, 2)
		t.eq(s.gold, 1000 - 15 + Eggs.List[2].rebirthGold)
		t.eq(s.cash, 0)
	end,

	skip_without_gold_changes_nothing = function(t)
		local f, s = H.Farm(function(s)
			s.cash = Eggs.List[1].requirement * 0.5
		end)
		t.eq(f:Apply({ type = "skip", expect = 1 }, H.T0).code, "cant_afford_gold")
		t.eq(s.egg, 1)
		t.eq(s.cash, Eggs.List[1].requirement * 0.5)
	end,

	last_egg_prestiges_instead = function(t)
		local f, s = richFarm(Eggs.Count)
		t.eq(f:Apply({ type = "rebirth", expect = Eggs.Count }, H.T0).code, "last_egg")
		local r = f:Apply({ type = "prestige", expect = Eggs.Count }, H.T0)
		t.ok(r.ok, r.code)
		t.eq(s.egg, 1)
		t.eq(s.prestiges, 1)
		t.eq(s.stars, 3 + 10)
		t.eq(s.gold, 77, "prestige grants stars, not gold")
		t.eq(s.epic.golden_touch, 7, "epic kept")
		t.eq(s.cash, 0)
		t.eq(f:Apply({ type = "prestige", expect = 1 }, H.T0).code, "not_last_egg")
	end,

	stars_raise_sale_value = function(t)
		local f0 = H.Farm()
		local f1 = H.Farm(function(s)
			s.stars = 10
		end)
		t.near(f1:Snapshot(H.T0).mods.saleMult / f0:Snapshot(H.T0).mods.saleMult, 1.5, 1e-9)
	end,

	each_new_egg_sells_for_more_than_prices_grow = function(t)
		for i = 2, Eggs.Count do
			local a, b = Eggs.List[i - 1], Eggs.List[i]
			t.ok(b.value / a.value > b.costScale / a.costScale, "egg " .. i .. " is a real step up")
			t.ok(b.requirement > a.requirement)
		end
	end,
}
