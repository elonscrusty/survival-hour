local B = require("../src/shared/Logic/BigNum")
local G = require("../src/shared/Logic/Game")
local P = require("../src/shared/Logic/Profile")

return {
	duplicate_delivery_grants_once = function(t)
		local p = P.new(0)
		t.ok(G.grantProduct(p, "forever", "rcpt-1"))
		t.eq(p.foreverTokens, 1)
		local ok, msg = G.grantProduct(p, "forever", "rcpt-1")
		t.ok(ok)
		t.eq(msg, "Already granted")
		t.eq(p.foreverTokens, 1)
	end,
	unknown_product_not_recorded = function(t)
		local p = P.new(0)
		t.no(G.grantProduct(p, "free_money", "rcpt-2"))
		t.eq(#p.robux.receipts, 0)
	end,
	passes_are_owned = function(t)
		local p = P.new(0)
		t.no(G.productOwned(p, "speedUp"))
		G.grantProduct(p, "speedUp", "a")
		t.ok(G.productOwned(p, "speedUp"))
		G.grantProduct(p, "manage", "b")
		t.ok(G.productOwned(p, "manage"))
		t.eq(G.powerTier(p, "manage"), 1)
	end,
	tiered_power_caps = function(t)
		local p = P.new(0)
		for i = 1, 5 do
			G.grantProduct(p, "runFaster", "rf" .. i)
		end
		t.eq(p.robux.tiers.runFaster, 3)
	end,
	time_skip_uses_income = function(t)
		local p = P.new(0)
		G.buyPad(p, "biz:stand")
		G.grantProduct(p, "cash24h", "s1")
		t.near(B.toNumber(p.cash), 86400, 1e-6, "24h of $1/s")
	end,
	time_skip_banked_without_income = function(t)
		local p = P.new(0)
		G.grantProduct(p, "cash1h", "s2")
		t.eq(p.robux.skipSeconds, 3600)
		G.buyPad(p, "biz:stand")
		local got = G.flushSkips(p)
		t.near(B.toNumber(got), 3600, 1e-6)
		t.eq(p.robux.skipSeconds, 0)
	end,
	receipts_bounded = function(t)
		local p = P.new(0)
		for i = 1, P.MAX_RECEIPTS + 20 do
			G.grantProduct(p, "rebirthNoReset", "id" .. i)
		end
		t.eq(#p.robux.receipts, P.MAX_RECEIPTS)
		t.eq(p.robux.rebirthCredits, P.MAX_RECEIPTS + 20)
	end,
	robux_survives_every_reset = function(t)
		local p = P.new(0)
		G.grantProduct(p, "speedUp", "x")
		G.grantProduct(p, "stack", "y")
		p.lifetime = B.new(77e21)
		G.rebirth(p)
		p.investors = B.new(1e18)
		G.evolve(p)
		for _, pad in require("../src/shared/Logic/Economy").pads do
			p.pads[pad.id] = true
		end
		G.ascend(p)
		t.ok(p.robux.passes.speedUp)
		t.eq(p.robux.tiers.stack, 1)
	end,
}
