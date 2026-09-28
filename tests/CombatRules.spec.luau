local C = require("../src/shared/Logic/CombatRules")

-- Mirrors Items armour: set reduction by tier split Head 25% / Chest 45% / Legs 30%.
local SETS = { 0.15, 0.22, 0.30, 0.38, 0.46 }

return {
	full_sets_stay_under_half = function(t)
		for tier, set in SETS do
			local r = C.ArmorReduction({ set * 0.25, set * 0.45, set * 0.30 }, 0.5)
			t.ok(math.abs(r - set) < 1e-9, "tier " .. tier .. " set value")
			t.ok(r < 0.5, "under 50%")
		end
		t.eq(C.ArmorReduction({ 0.4, 0.4 }, 0.5), 0.5, "capped")
		t.eq(C.ArmorReduction({}, 0.5), 0)
	end,
	block_costs_stamina_and_breaks = function(t)
		local r = C.Block(20, 0.5, 100, 1, 0)
		t.eq(r.Taken, 10)
		t.eq(r.Drain, 10)
		t.no(r.GuardBroken)
		local heavy = C.Block(40, 0.5, 25, 1, 20) -- heavy hit on a tired blocker
		t.ok(heavy.GuardBroken, "heavy breaks the guard")
		t.ok(heavy.Taken > 20, "more gets through")
		t.eq(heavy.Drain, 25, "stamina emptied")
	end,
	heavy_and_tired = function(t)
		t.eq(C.MeleeDamage(20, true, 1.8, false), 36)
		t.eq(C.MeleeDamage(20, false, 1.8, true), 10)
	end,
	early_bows_dont_one_shot = function(t)
		-- Crude Bow 22, Hunting Bow 34, Crossbow 48 at full draw, headshot x1.75
		for _, dmg in { 22, 34, 48 } do
			t.ok(C.Headshot(dmg, true, 1.75) < 100, dmg .. " headshot < 100 HP")
		end
		t.eq(C.Headshot(30, false, 1.75), 30)
	end,
	parry_window = function(t)
		t.ok(C.IsParry(10, 1, 10.2, 0.28, 0.45))
		t.no(C.IsParry(10, 1, 10.4, 0.28, 0.45)) -- too late: a normal block
		t.no(C.IsParry(10, 0.2, 10.1, 0.28, 0.45)) -- guard was only just lowered (mashing)
		t.no(C.IsParry(nil, 1, 10.1, 0.28, 0.45))
		t.no(C.IsParry(10, 1, 9.9, 0.28, 0.45))
	end,
}
