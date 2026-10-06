--!strict
local Fusion = require("../src/shared/Logic/Fusion")
local Hatch = require("../src/shared/Logic/Hatch")
local Eggs = require("../src/shared/Eggs")
local function parent(uid: string, species: string, rarity: string): Fusion.Parent
	return { Uid = uid, Species = species, Element = "Fire", Rarity = rarity, Level = 10, Xp = 0, Neon = false, Tier = 1, Locked = false }
end
return {
	["fusion plan consumes exactly two distinct parents"] = function(t: any)
		local a, b = parent("a", "Dragon", "Rare"), parent("b", "Griffin", "Epic")
		local plan = Fusion.Prepare(a, b, "egg1", {}, 500, 1, 1)
		t.ok(plan ~= nil)
		local p = plan :: Fusion.Plan
		t.eq(p.Consume[1], "a"); t.eq(p.Consume[2], "b"); t.eq(p.Cost, 500); t.eq(p.Egg.Egg, "FusedEgg")
		t.eq(a.Uid, "a"); t.eq(b.Level, 10)
		t.eq(p.Egg.Fused.Hybrid, "Wyvern")
	end,
	["same rarity raises upgrade chance and parents determine tier"] = function(t: any)
		local a, b = parent("a", "Dragon", "Rare"), parent("b", "Dragon", "Rare")
		b.Tier = 4
		local p = Fusion.Prepare(a, b, "egg1", {}, 500, 1, 1) :: Fusion.Plan
		t.eq(p.Egg.Tier, 4); t.eq(p.Egg.Fused.Hybrid, nil)
		local odds = Hatch.Odds(Eggs.ById.FusedEgg, 1, p.Egg.Fused)
		t.ok(math.abs(odds.Rarity.Epic - 45) < 1e-8); t.eq(odds.Species.Dragon, 100)
		t.eq(Fusion.HatchLevel(), 1)
	end,
	["mythic parents never roll an invalid higher rarity"] = function(t: any)
		local p = Fusion.Prepare(parent("a", "Dragon", "Mythic"), parent("b", "Griffin", "Mythic"), "e", {}, 500, 1, 1) :: Fusion.Plan
		local odds = Hatch.Odds(Eggs.ById.FusedEgg, 6, p.Egg.Fused)
		t.eq(odds.Rarity.Mythic, 100)
	end,
	["busy locked duplicate poor and full bag parents cannot fuse"] = function(t: any)
		local a, b = parent("a", "Dragon", "Rare"), parent("b", "Griffin", "Epic")
		t.eq(Fusion.Prepare(a, a, "e", {}, 500, 1, 1), nil)
		t.eq(Fusion.Prepare(a, b, "e", { a = true }, 500, 1, 1), nil)
		a.Locked = true; t.eq(Fusion.Prepare(a, b, "e", {}, 500, 1, 1), nil); a.Locked = false
		t.eq(Fusion.Prepare(a, b, "e", {}, 499, 1, 1), nil)
		t.eq(Fusion.Prepare(a, b, "e", {}, 500, 1, 0), nil)
	end,
	["fused parent element odds include random element share"] = function(t: any)
		local a, b = parent("a", "Dragon", "Rare"), parent("b", "Griffin", "Epic"); b.Element = "Ice"
		local p = Fusion.Prepare(a, b, "e", {}, 500, 1, 1) :: Fusion.Plan
		local odds = Hatch.Odds(Eggs.ById.FusedEgg, 1, p.Egg.Fused)
		t.ok(math.abs(odds.Element.Fire - 47) < 1e-8); t.ok(math.abs(odds.Element.Ice - 47) < 1e-8)
		t.ok(math.abs(odds.Element.Nature - 2) < 1e-8)
	end,
}
