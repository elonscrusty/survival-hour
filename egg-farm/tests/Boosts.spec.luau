local H = require("./Helpers")
local Boosts = require("../src/shared/Data/Boosts")
local Modifiers = require("../src/shared/Logic/Modifiers")

return {
	use_needs_inventory = function(t)
		local f = H.Farm()
		t.eq(f:Apply({ type = "useBoost", id = "earn3" }, H.T0).code, "no_boost")
		t.eq(f:Apply({ type = "useBoost", id = "fake" }, H.T0).code, "invalid")
	end,

	use_consumes_one_and_activates = function(t)
		local f, s = H.Farm(function(s)
			s.boosts.inventory.earn3 = 2
		end)
		t.ok(f:Apply({ type = "useBoost", id = "earn3" }, H.T0).ok)
		t.eq(s.boosts.inventory.earn3, 1)
		t.eq(#s.boosts.active, 1)
		t.eq(s.boosts.active[1].endsAt, H.T0 + Boosts.ById.earn3.duration)
		t.near(f:Snapshot(H.T0).mods.saleMult, 3, 1e-9)
	end,

	same_boost_stacks_duration_with_cap = function(t)
		local f, s = H.Farm(function(s)
			s.boosts.inventory.earn10 = 50
		end)
		for _ = 1, 50 do
			f:Apply({ type = "useBoost", id = "earn10" }, H.T0)
		end
		t.eq(#s.boosts.active, 1, "one entry")
		t.eq(s.boosts.active[1].endsAt, H.T0 + Boosts.MaxDuration, "capped")
		t.eq(s.boosts.inventory.earn10, 50 - Boosts.MaxDuration / Boosts.ById.earn10.duration, "no boost wasted past the cap")
	end,

	active_limit_and_vip = function(t)
		local f, s = H.Farm(function(s)
			for _, b in Boosts.List do
				s.boosts.inventory[b.id] = 1
			end
		end)
		local okCount = 0
		for _, b in Boosts.List do
			if f:Apply({ type = "useBoost", id = b.id }, H.T0).ok then
				okCount += 1
			end
		end
		t.eq(okCount, Boosts.MaxActive)
		s.passes.vip = true
		for _, b in Boosts.List do
			f:Apply({ type = "useBoost", id = b.id }, H.T0)
		end
		t.eq(#s.boosts.active, Boosts.MaxActiveVip)
	end,

	boosts_expire_on_server_time_and_survive_reconnect = function(t)
		local f, s = H.Farm(function(s)
			s.boosts.inventory.lay2 = 1
		end)
		f:Apply({ type = "useBoost", id = "lay2" }, H.T0)
		-- "reconnect": a new Farm object over the same saved state, 5 minutes later
		local Economy = require("../src/shared/Logic/Economy")
		local f2 = Economy.new(s, {})
		f2:Step(1, H.T0 + 300)
		t.eq(#s.boosts.active, 1, "still active after reconnect")
		f2:Step(1, H.T0 + Boosts.ById.lay2.duration + 1)
		t.eq(#s.boosts.active, 0, "expired")
		t.eq(f2:Snapshot(H.T0 + Boosts.ById.lay2.duration + 1).mods.layRate, Modifiers.BASE_LAY)
	end,

	booster_doubles_other_bonuses = function(t)
		local mults = Modifiers.BoostMults({ { id = "earn3", endsAt = H.T0 + 10 }, { id = "booster", endsAt = H.T0 + 10 } }, H.T0)
		t.eq(mults.earn, 5, "bonus part 2 doubled -> x5")
		mults = Modifiers.BoostMults({ { id = "earn3", endsAt = H.T0 + 10 }, { id = "lay2", endsAt = H.T0 + 10 } }, H.T0)
		t.eq(mults.earn, 3)
		t.eq(mults.lay, 2)
	end,
}
