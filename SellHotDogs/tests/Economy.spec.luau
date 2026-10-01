local B = require("../src/shared/Logic/BigNum")
local E = require("../src/shared/Logic/Economy")

local function ms(pads)
	return { pads = pads or {}, forever = {}, investors = B.zero, evolutions = 0, ascensions = 0, speedUp = false }
end

return {
	eight_businesses_in_order = function(t)
		local ids = {}
		for _, b in E.businesses do
			table.insert(ids, b.id)
		end
		t.eq(table.concat(ids, ","), "stand,dash,depot,trading,labs,robotics,republic,hotdogx")
	end,
	stand_observed_opening = function(t)
		local stand = E.bizById.stand
		t.eq(stand.cycleTime, 1, "observed 1s cycle")
		t.near(B.toNumber(E.cycleOutput(ms(), stand, 1)), 1.00, 1e-9, "observed $1.00")
	end,
	observed_pad_prices_and_roles = function(t)
		local p = E.padById
		t.eq(p["stand:condiment"].cost, 6.20)
		t.eq(p["stand:condiment"].kind, "cash")
		t.eq(p["stand:condiment"].mult, 2)
		t.eq(p["stand:bunrack"].cost, 82.50)
		t.eq(p["stand:bunrack"].mult, 3)
		t.eq(p["stand:register"].cost, 100)
		t.eq(p["stand:register"].kind, "auto")
		t.eq(p["stand:billboard"].cost, 785)
		t.eq(p["stand:billboard"].kind, "speed")
		t.eq(p["dash:floor"].cost, 19500)
	end,
	condiment_doubles_to_two_dollars = function(t)
		local out = E.cycleOutput(ms({ ["stand:condiment"] = true }), E.bizById.stand, 1)
		t.near(B.toNumber(out), 2.00, 1e-9, "N 00:36-00:38 shows $2.00")
	end,
	observed_level_costs = function(t)
		local s = E.bizById.stand
		t.near(B.toNumber(E.levelCost(s, 0, 0)), 5.10, 1e-9)
		t.near(B.toNumber(E.levelCost(s, 1, 0)), 7.65, 1e-9)
		t.near(B.toNumber(E.levelCost(s, 2, 0)), 11.00, 1e-9)
		t.near(B.toNumber(E.levelCost(s, 3, 0)), 19.00, 1e-9)
		t.near(B.toNumber(E.levelCost(s, 4, 0)), 28.50, 1e-9, "placeholder x1.5")
	end,
	derived_level_outputs_match_labels = function(t)
		local s = E.bizById.stand
		local x2 = ms({ ["stand:condiment"] = true })
		local x6 = ms({ ["stand:condiment"] = true, ["stand:bunrack"] = true })
		t.near(B.toNumber(E.cycleOutput(x2, s, 3)), 5.84, 1e-9, "N 00:48.6 $5.84")
		t.near(B.toNumber(E.cycleOutput(x6, s, 3)), 17.52, 0.011, "N 00:58 $17.51")
		t.near(B.toNumber(E.cycleOutput(x6, s, 4)), 24.26, 0.011, "N 00:59 $24.26")
	end,
	level_shape_monotonic = function(t)
		local prev = 0
		for l = 1, 200 do
			local v = E.levelShape(l)
			t.ok(v > prev, "level " .. l)
			prev = v
		end
	end,
	billboard_triples_speed = function(t)
		local cps = E.cyclesPerSecond(ms({ ["stand:billboard"] = true }), E.bizById.stand)
		t.near(B.toNumber(cps), 3, 1e-9)
	end,
	ascension_scales_prices_and_cash = function(t)
		local pad = E.padById["stand:condiment"]
		t.near(B.toNumber(E.padCost(pad, 1)), 20.65, 0.006)
		local m = ms()
		m.ascensions = 1
		t.near(B.toNumber(E.cashMult(m, E.bizById.stand)), 7.77, 1e-9)
	end,
	evolution_speed_stacks = function(t)
		local m = ms()
		m.evolutions = 2
		t.near(B.toNumber(E.speedMult(m, E.bizById.stand)), 42 * 42, 1e-6)
	end,
	investors_offered_gate = function(t)
		t.eq(E.investorsOffered(B.new(1e21), false).m, 0)
		t.near(B.toNumber(E.investorsOffered(B.new(77e21 * 100), false)), 10, 1e-9)
		t.near(B.toNumber(E.investorsOffered(B.new(77e21 * 100), true)), 20, 1e-9)
	end,
	recipe_names = function(t)
		t.eq(E.recipeName(0), "Classic")
		t.eq(E.recipeName(1), "Chili")
		t.eq(E.recipeName(6), "Void+1")
	end,
	pad_requires_known = function(t)
		for _, pad in E.pads do
			if pad.requires then
				t.ok(E.padById[pad.requires] ~= nil, pad.id .. " requires " .. pad.requires)
			end
		end
	end,
}
