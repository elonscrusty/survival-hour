local B = require("../src/shared/Logic/BigNum")
local G = require("../src/shared/Logic/Game")
local P = require("../src/shared/Logic/Profile")

return {
	new_player_gets_fresh_profile = function(t)
		local p, why = P.migrate(nil, 50)
		t.ok(p)
		t.eq(why, "new")
		t.eq(p.v, P.VERSION)
		t.eq(p.lastSeen, 50)
	end,
	round_trip = function(t)
		local p = P.new(0)
		p.cash = B.fromParts(3, 564)
		G.buyPad(p, "biz:stand") -- affordable? cash is huge
		p.forever["stand:billboard"] = true
		p.robux.receipts = { "r1", "r2" }
		local q = P.migrate(P.serialize(p), 99)
		t.ok(q)
		t.eq(q.cash.e, 564)
		t.ok(q.pads["biz:stand"])
		t.ok(q.forever["stand:billboard"])
		t.eq(#q.robux.receipts, 2)
		t.eq(q.biz.stand.level, 1)
	end,
	corrupt_data_is_rejected_not_blanked = function(t)
		local p, why = P.migrate("garbage", 0)
		t.eq(p, nil)
		t.ok(why)
		p, why = P.migrate({ v = 2, cash = { m = 0 / 0, e = 1 } }, 0)
		t.eq(p, nil)
		t.eq(why, "cash is invalid")
	end,
	newer_version_refused = function(t)
		local p, why = P.migrate({ v = 99, cash = 5 }, 0)
		t.eq(p, nil)
		t.eq(why, "save is from a newer game version")
	end,
	migrates_v1 = function(t)
		local p = P.migrate({ v = 1, cash = 250.5, pads = { ["biz:stand"] = true }, biz = { stand = { level = 3 } } }, 0)
		t.ok(p)
		t.near(B.toNumber(p.cash), 250.5, 1e-9)
		t.eq(p.biz.stand.level, 3)
		t.eq(p.foreverTokens, 0)
	end,
	unknown_pads_dropped_and_levels_fixed = function(t)
		local p = P.migrate({ v = 2, cash = { m = 1, e = 0 }, pads = { ["x:y"] = true, ["biz:dash"] = true }, biz = { stand = { level = 9 } } }, 0)
		t.eq(p.pads["x:y"], nil)
		t.eq(p.biz.stand.level, 0, "no stand pad, so level cleared")
		t.eq(p.biz.dash.level, 1, "owned business at least level 1")
	end,
	negative_cash_rejected = function(t)
		local p = P.migrate({ v = 2, cash = { m = -5, e = 0 } }, 0)
		t.eq(p, nil)
	end,
	power_tiers_clamped = function(t)
		local p = P.migrate({ v = 2, cash = 1, powers = { runFaster = 99, bogus = 3 }, robux = { tiers = { stack = -4 } } }, 0)
		t.eq(p.powers.runFaster, 3)
		t.eq(p.powers.bogus, nil)
		t.eq(p.robux.tiers.stack, 0)
	end,
}
