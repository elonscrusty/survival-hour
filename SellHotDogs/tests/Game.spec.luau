local B = require("../src/shared/Logic/BigNum")
local G = require("../src/shared/Logic/Game")
local P = require("../src/shared/Logic/Profile")

local function cash(p)
	return B.toNumber(p.cash)
end

local function standing(c)
	local p = P.new(0)
	p.cash = B.new(c or 1)
	assert(G.buyPad(p, "biz:stand"))
	return p
end

return {
	clean_start_buys_stand_for_one_dollar = function(t)
		local p = P.new(0)
		t.near(cash(p), 1, 1e-9)
		t.no(G.click(p, "stand"), "cannot click before owning")
		local ok = G.buyPad(p, "biz:stand")
		t.ok(ok)
		t.near(cash(p), 0, 1e-9)
		t.eq(p.biz.stand.level, 1)
	end,
	one_second_cycle_grants_one_dollar = function(t)
		local p = standing(3)
		t.near(cash(p), 2, 1e-9)
		t.ok(G.click(p, "stand"))
		local g = G.step(p, 0.5)
		t.eq(#g, 0, "nothing at 0.5s")
		t.near(cash(p), 2, 1e-9, "no early grant")
		g = G.step(p, 0.5)
		t.eq(#g, 1)
		t.near(B.toNumber(g[1].amount), 1, 1e-9)
		t.near(cash(p), 3, 1e-9)
		t.no(p.biz.stand.running, "manual cycle stops")
	end,
	repeated_clicks_while_running_ignored = function(t)
		local p = standing(1)
		t.ok(G.click(p, "stand"))
		t.no(G.click(p, "stand"))
		t.no(G.click(p, "stand"))
		G.step(p, 5)
		t.near(cash(p), 1, 1e-9, "only one cycle paid")
	end,
	manual_never_runs_without_click = function(t)
		local p = standing(1)
		G.step(p, 100)
		t.near(cash(p), 0, 1e-9)
	end,
	purchase_deducts_exactly_once = function(t)
		local p = standing(10)
		t.ok(G.buyPad(p, "stand:condiment"))
		t.near(cash(p), 9 - 6.20, 1e-9)
		local ok, why = G.buyPad(p, "stand:condiment")
		t.no(ok)
		t.eq(why, "Already owned")
		t.near(cash(p), 2.80, 1e-9)
	end,
	unaffordable_rejected_without_deduction = function(t)
		local p = standing(6)
		local ok, why = G.buyPad(p, "stand:condiment")
		t.no(ok)
		t.eq(why, "Not enough cash")
		t.near(cash(p), 5, 1e-9)
	end,
	locked_pad_rejected = function(t)
		local p = standing(1e6)
		local ok, why = G.buyPad(p, "stand:billboard")
		t.no(ok)
		t.eq(why, "Locked")
		t.no(G.buyPad(p, "nope"))
	end,
	opening_pads_visible = function(t)
		local p = standing(1)
		local E = require("../src/shared/Logic/Economy")
		t.ok(G.padVisible(p, E.padById["stand:condiment"]))
		t.ok(G.padVisible(p, E.padById["stand:register"]))
		t.no(G.padVisible(p, E.padById["stand:bunrack"]))
		t.ok(G.padVisible(p, E.padById["biz:dash"]))
		t.no(G.padVisible(p, E.padById["biz:depot"]))
	end,
	condiment_then_upgrade_sequence = function(t)
		local p = standing(1000)
		G.buyPad(p, "stand:condiment")
		local before = cash(p)
		t.ok(G.upgradeLevel(p, "stand", 1))
		t.near(before - cash(p), 5.10, 1e-9)
		t.ok(G.upgradeLevel(p, "stand", 1))
		t.ok(G.upgradeLevel(p, "stand", 1))
		t.near(before - cash(p), 5.10 + 7.65 + 11.00, 1e-9)
		t.eq(p.biz.stand.level, 4)
	end,
	bulk_requires_stack_power = function(t)
		local p = standing(1e6)
		local ok, why = G.upgradeLevel(p, "stand", 5)
		t.no(ok)
		t.eq(why, "Bulk size locked")
		t.no(G.upgradeLevel(p, "stand", "max"))
		t.no(G.upgradeLevel(p, "stand", 2), "arbitrary counts rejected")
		t.no(G.upgradeLevel(p, "stand", -1))
		p.powers.stack = 1
		t.ok(G.upgradeLevel(p, "stand", 5))
		t.eq(p.biz.stand.level, 6)
	end,
	bulk_is_all_or_nothing = function(t)
		local p = standing(20)
		p.powers.stack = 1
		local ok = G.upgradeLevel(p, "stand", 5)
		t.no(ok)
		t.eq(p.biz.stand.level, 1)
		t.near(cash(p), 19, 1e-9)
	end,
	max_buys_what_is_affordable = function(t)
		local p = standing(5.10 + 7.65 + 11 + 1)
		p.powers.stack = 3
		local ok, _, n = G.upgradeLevel(p, "stand", "max")
		t.ok(ok)
		t.eq(n, 3)
		t.near(cash(p), 0, 1e-9)
	end,
	register_automates = function(t)
		local p = standing(101)
		t.ok(G.buyPad(p, "stand:register"))
		t.no(G.click(p, "stand"), "automatic now")
		G.step(p, 3.5)
		t.near(cash(p), 3, 1e-9, "three full cycles")
		G.step(p, 0.5)
		t.near(cash(p), 4, 1e-9, "fractional progress carried")
	end,
	fast_production_aggregates = function(t)
		local p = standing(1e6)
		G.buyPad(p, "stand:register")
		p.evolutions = 3 -- 42^3 = 74088 cycles/s
		local g = G.step(p, 0.1)
		t.eq(#g, 1, "one grant event per step, not thousands")
		t.ok(g[1].cycles >= 7408 and g[1].cycles <= 7409, "aggregated cycles " .. g[1].cycles)
	end,
	continuous_mode_at_extreme_speed = function(t)
		local p = standing(1e6)
		G.buyPad(p, "stand:register")
		p.evolutions = 10
		local before = p.cash
		local g = G.step(p, 0.1)
		t.eq(#g, 1)
		t.eq(g[1].cycles, -1)
		t.ok(B.lt(before, p.cash))
	end,
	offline_only_counts_automated = function(t)
		local p = standing(1)
		t.eq(G.offlineEarnings(p, 3600).m, 0, "manual business earns nothing offline")
		p.cash = B.new(100)
		G.buyPad(p, "stand:register")
		t.near(B.toNumber(G.offlineEarnings(p, 3600)), 3600, 1e-6, "100% of $1/s")
	end,
	offline_return_and_claim = function(t)
		local p = standing(101)
		G.buyPad(p, "stand:register")
		p.lastSeen = 1000
		G.applyReturn(p, 1000 + 7200)
		t.near(B.toNumber(p.pendingOffline), 7200, 1e-6)
		t.eq(p.lastSeen, 8200)
		local ok = G.claimOffline(p)
		t.ok(ok)
		t.near(cash(p), 7200, 1e-6)
		t.no(G.claimOffline(p), "claim only once")
	end,
	offline_negative_elapsed_ignored = function(t)
		local p = standing(101)
		G.buyPad(p, "stand:register")
		p.lastSeen = 5000
		G.applyReturn(p, 4000)
		t.eq(p.pendingOffline.m, 0)
	end,
	pickups_scale_with_expert = function(t)
		local p = standing(1)
		local base = B.toNumber(G.pickupValue(p))
		t.near(base, 10, 1e-9, "10s of $1/s")
		p.robux.tiers.expertPicker = 1
		t.near(B.toNumber(G.pickupValue(p)), 20, 1e-9)
	end,
	next_pad_is_cheapest_visible = function(t)
		local p = standing(1)
		t.eq(G.nextPad(p).id, "stand:condiment")
	end,
	powers_spend_investors = function(t)
		local p = standing(1)
		t.no(G.buyPower(p, "manage"))
		p.investors = B.new(150)
		t.ok(G.buyPower(p, "manage"))
		t.near(B.toNumber(p.investors), 50, 1e-9)
		t.no(G.buyPower(p, "manage"), "single tier")
		t.eq(G.powerTier(p, "manage"), 1)
	end,
	robux_and_investor_tiers_combine_capped = function(t)
		local p = standing(1)
		p.powers.runFaster = 2
		p.robux.tiers.runFaster = 3
		t.eq(G.powerTier(p, "runFaster"), 3)
	end,
	multiple_players_isolated = function(t)
		local a, b = standing(101), standing(101)
		G.buyPad(a, "stand:register")
		G.step(a, 2)
		G.step(b, 2)
		t.near(cash(a), 2, 1e-9)
		t.near(cash(b), 100, 1e-9)
	end,
}
