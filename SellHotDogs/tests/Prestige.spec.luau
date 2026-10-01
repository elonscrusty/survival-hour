local B = require("../src/shared/Logic/BigNum")
local E = require("../src/shared/Logic/Economy")
local G = require("../src/shared/Logic/Game")
local P = require("../src/shared/Logic/Profile")

local function rich()
	local p = P.new(0)
	p.cash = B.new(1e6)
	G.buyPad(p, "biz:stand")
	G.buyPad(p, "stand:condiment")
	G.buyPad(p, "stand:register")
	p.lifetime = B.new(77e21 * 400) -- placeholder rule: sqrt(400) = 20 investors
	p.name = "Carter's Dogs"
	return p
end

return {
	rebirth_needs_investors = function(t)
		local p = P.new(0)
		t.no(G.rebirth(p))
	end,
	rebirth_resets_run_keeps_permanents = function(t)
		local p = rich()
		p.powers.manage = 1
		p.robux.passes.speedUp = true
		p.forever["stand:bunrack"] = true
		local ok, _, award = G.rebirth(p)
		t.ok(ok)
		t.near(B.toNumber(award), 20, 1e-9)
		t.near(B.toNumber(p.investors), 20, 1e-9)
		t.near(B.toNumber(p.cash), 1, 1e-9, "cash back to start")
		t.eq(p.pads["biz:stand"], nil, "businesses reset")
		t.eq(p.biz.stand.level, 0)
		t.eq(p.powers.manage, 1, "powers kept")
		t.ok(p.robux.passes.speedUp, "robux kept")
		t.ok(p.forever["stand:bunrack"], "forever kept")
		t.eq(p.name, "Carter's Dogs")
		t.eq(p.lifetime.m, 0)
	end,
	x2_investors_pass = function(t)
		local p = rich()
		p.robux.passes.x2investors = true
		local _, _, award = G.rebirth(p)
		t.near(B.toNumber(award), 40, 1e-9)
	end,
	investor_bonus_applies = function(t)
		local p = rich()
		G.rebirth(p)
		G.buyPad(p, "biz:stand")
		p.cash = B.new(100)
		-- 20 investors x 1% = x1.2
		t.near(B.toNumber(E.cycleOutput(G.multState(p), E.bizById.stand, 1)), 1.2, 1e-9)
	end,
	rebirth_no_reset_uses_credit_once = function(t)
		local p = rich()
		t.no(G.rebirthNoReset(p), "needs a credit")
		p.robux.rebirthCredits = 1
		t.ok(G.rebirthNoReset(p))
		t.near(B.toNumber(p.investors), 20, 1e-9)
		t.ok(p.pads["stand:register"], "nothing reset")
		t.eq(p.robux.rebirthCredits, 0)
		t.no(G.rebirthNoReset(p))
	end,
	evolution_threshold_and_reset = function(t)
		local p = rich()
		p.investors = B.new(1e15)
		t.no(G.evolve(p))
		p.investors = B.new(501.2e15)
		p.powers.manage = 1
		p.robux.tiers.stack = 1
		local ok, msg = G.evolve(p)
		t.ok(ok)
		t.eq(msg, "Evolved to Chili")
		t.eq(p.evolutions, 1)
		t.eq(p.investors.m, 0, "investors reset")
		t.eq(p.powers.manage, nil, "investor powers reset")
		t.eq(p.robux.tiers.stack, 1, "robux tiers safe")
		t.near(G.evolutionProgress(p), 0, 1e-12)
	end,
	ascension_requires_everything = function(t)
		local p = rich()
		t.no(G.ascend(p))
		for _, pad in E.pads do
			p.pads[pad.id] = true
		end
		p.evolutions = 3
		p.investors = B.new(1e20)
		local ok = G.ascend(p)
		t.ok(ok)
		t.eq(p.ascensions, 1)
		t.eq(p.evolutions, 0)
		t.eq(p.investors.m, 0)
		t.eq(p.foreverTokens, 1)
		t.eq(p.pads["biz:stand"], nil)
	end,
	forever_select_cancel_confirm = function(t)
		local p = rich()
		t.no(G.useForever(p, "stand:billboard"), "no token")
		p.foreverTokens = 1
		t.no(G.useForever(p, "biz:stand"), "business unlock not eligible")
		t.no(G.useForever(p, "made:up"))
		t.eq(p.foreverTokens, 1, "rejections consume nothing")
		t.ok(G.useForever(p, "stand:billboard"))
		t.eq(p.foreverTokens, 0)
		t.no(G.useForever(p, "stand:billboard"), "duplicate attempt")
		G.rebirth(p)
		t.ok(G.owns(p, "stand:billboard"), "survives rebirth")
		p.investors = B.new(501.2e15)
		G.evolve(p)
		t.ok(G.owns(p, "stand:billboard"), "survives evolution")
	end,
	forever_pad_waits_for_business = function(t)
		local p = P.new(0)
		p.forever["stand:condiment"] = true
		t.eq(B.toNumber(G.bizRate(p, "stand")), 0)
		G.buyPad(p, "biz:stand")
		t.near(B.toNumber(G.bizRate(p, "stand")), 2, 1e-9)
	end,
	ascension_cash_and_prices = function(t)
		local p = P.new(0)
		p.ascensions = 1
		p.cash = B.new(10)
		G.buyPad(p, "biz:stand")
		t.near(B.toNumber(p.cash), 10 - 3.33, 1e-9)
		t.near(B.toNumber(G.bizRate(p, "stand")), 7.77, 1e-9)
	end,
}
