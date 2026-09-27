local W = require("../src/shared/Logic/WildlifeRules")

local T = { PredatorBase = 6, PredatorPerNight = 2, PredatorMax = 14 }

return {
	night_numbers = function(t)
		t.eq(W.NightNumber("Day", 3), 0)
		t.eq(W.NightNumber("Night", 3), 3)
		t.eq(W.NightNumber("Intro", 0), 0)
	end,
	escalates_pressure_not_health = function(t)
		local p1, p3, p9 = W.Pressure(1, T), W.Pressure(3, T), W.Pressure(9, T)
		t.ok(p3.PackBonus >= p1.PackBonus and p9.PackBonus > p1.PackBonus, "packs grow")
		t.ok(p3.AggroMult > p1.AggroMult, "more aggressive")
		t.ok(p3.IntervalMult < p1.IntervalMult, "spawn more often")
		t.ok(p3.PredatorCap > p1.PredatorCap, "more predators")
		t.eq(p9.PredatorCap, 14, "capped")
		t.ok(p9.AggroMult <= 1.6 and p9.PackBonus <= 3, "bounded")
		for k in p9 do
			t.ok(not string.find(k, "Health"), "no HP inflation")
		end
	end,
	day_is_calm = function(t)
		local d = W.Pressure(0, T)
		t.ok(d.AggroMult < 1 and d.IntervalMult > 1, "calmer by day")
		t.eq(W.Weights(0).Wolf, nil, "no wolves by day")
		t.ok(W.Weights(0).Deer > 0 and W.Weights(0).Rabbit > 0, "prey by day")
		t.ok(W.Weights(2).Wolf > W.Weights(2).Bear, "bears uncommon")
	end,
	pick_respects_caps = function(t)
		local w = { Wolf = 5, Deer = 5 }
		t.eq(W.Pick(w, { Deer = true }, 0.99), "Deer")
		t.eq(W.Pick(w, {}, 0.5), nil)
		t.eq(W.Pick(w, { Deer = true, Wolf = true }, 0.0), "Deer", "sorted, deterministic")
	end,
}
