local B = require("../src/shared/Logic/BigNum")
local G = require("../src/shared/Logic/Game")
local P = require("../src/shared/Logic/Profile")

return {
	buy_decor_costs_cash_once = function(t)
		local p = P.new(0)
		p.cash = B.new(300)
		t.ok(G.buyDecor(p, "planter"))
		t.near(B.toNumber(p.cash), 50, 1e-9)
		t.no(G.buyDecor(p, "planter"), "no double buy")
		t.no(G.buyDecor(p, "bench"), "can't afford")
		t.no(G.buyDecor(p, "rocket"), "unknown")
		t.near(B.toNumber(p.cash), 50, 1e-9)
	end,
	decor_survives_every_reset = function(t)
		local p = P.new(0)
		p.cash = B.new(1e6)
		G.buyDecor(p, "bench")
		p.lifetime = B.new(77e21)
		G.rebirth(p)
		p.investors = B.new(1e18)
		G.evolve(p)
		for _, pad in require("../src/shared/Logic/Economy").pads do
			p.pads[pad.id] = true
		end
		G.ascend(p)
		t.ok(p.decor.bench)
	end,
	decor_saved_and_loaded = function(t)
		local p = P.new(0)
		p.decor.fountain = true
		local q = P.migrate(P.serialize(p), 0)
		t.ok(q.decor.fountain)
		local r = P.migrate({ v = 2, cash = 1, decor = { fake = true, bench = true } }, 0)
		t.eq(r.decor.fake, nil)
		t.ok(r.decor.bench)
	end,
	milestones_fire_once_in_order = function(t)
		local p = P.new(0)
		t.eq(#G.newMilestones(p), 0)
		p.totalEarned = B.new(1500)
		local m = G.newMilestones(p)
		t.eq(#m, 2)
		t.eq(m[1], 100)
		t.eq(m[2], 1000)
		t.eq(#G.newMilestones(p), 0, "not repeated")
		p.totalEarned = B.fromParts(1, 200)
		t.ok(#G.newMilestones(p) > 5)
	end,
	level_tiers = function(t)
		local p = P.new(0)
		p.cash = B.new(10)
		G.buyPad(p, "biz:stand")
		t.eq(G.levelTier(p, "stand"), 0)
		p.biz.stand.level = 30
		t.eq(G.levelTier(p, "stand"), 2)
	end,
}
