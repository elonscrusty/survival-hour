-- Pet power, variants and levels.
local PetMath = require("../src/shared/Logic/PetMath")
local Config = require("../src/shared/Config")
local Areas = require("../src/shared/Areas")
local Pets = require("../src/shared/Pets")

local function pet(id, variant, shiny, level)
	return { Uid = "1", Id = id, Variant = variant or "Normal", Shiny = shiny or false, Level = level or 1, Xp = 0, Locked = false }
end

local function near(a, b)
	return math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b))
end

return {
	["base power is rarity times area PowerMult"] = function(t)
		t.eq(PetMath.BasePower("Puppy"), Config.RarityPower.Common * Areas.ById.Meadow.PowerMult, "puppy")
		t.eq(PetMath.BasePower("Owl"), Config.RarityPower.Epic * Areas.ById.Grove.PowerMult, "owl")
		t.eq(PetMath.BasePower("NoSuchPet"), 0, "unknown pet")
	end,
	["variant, shiny and level multiply"] = function(t)
		local base = PetMath.BasePower("Fox")
		t.ok(near(PetMath.Power(pet("Fox")), base), "normal")
		t.ok(near(PetMath.Power(pet("Fox", "Golden")), base * Config.VariantPower.Golden), "golden")
		t.ok(near(PetMath.Power(pet("Fox", "Rainbow", true)), base * Config.VariantPower.Rainbow * Config.ShinyPower), "rainbow shiny")
		t.ok(near(PetMath.Power(pet("Fox", "Normal", false, 11)), base * (1 + Config.PetLevelPower * 10)), "level 11")
	end,
	["bad levels are clamped in power"] = function(t)
		local base = PetMath.BasePower("Puppy")
		t.ok(near(PetMath.Power(pet("Puppy", "Normal", false, -5)), base), "negative level")
		t.ok(near(PetMath.Power(pet("Puppy", "Normal", false, 0 / 0)), base), "nan level")
		local maxed = base * (1 + Config.PetLevelPower * (Config.PetMaxLevel - 1))
		t.ok(near(PetMath.Power(pet("Puppy", "Normal", false, 9999)), maxed), "huge level")
	end,
	["every pet has positive power"] = function(t)
		for _, def in Pets.List do
			t.ok(PetMath.BasePower(def.Id) > 0, def.Id)
		end
	end,
	["next variant chain"] = function(t)
		t.eq(PetMath.NextVariant("Normal"), "Golden", "normal")
		t.eq(PetMath.NextVariant("Golden"), "Rainbow", "golden")
		t.eq(PetMath.NextVariant("Rainbow"), nil, "rainbow is last")
		t.eq(PetMath.NextVariant("Bogus"), nil, "unknown")
	end,
	["xp levels up and carries over"] = function(t)
		local p = pet("Puppy")
		local need = PetMath.XpToNext(1)
		t.eq(PetMath.AddXp(p, need - 1), 0, "not yet")
		t.eq(p.Level, 1, "still 1")
		t.eq(PetMath.AddXp(p, 1), 1, "one level")
		t.eq(p.Level, 2, "level 2")
		t.eq(p.Xp, 0, "xp reset")
		local gained = PetMath.AddXp(p, PetMath.XpToNext(2) + PetMath.XpToNext(3) + 3)
		t.eq(gained, 2, "two levels at once")
		t.eq(p.Xp, 3, "carry")
	end,
	["xp stops at max level and ignores bad input"] = function(t)
		local p = pet("Puppy")
		PetMath.AddXp(p, 1e12)
		t.eq(p.Level, Config.PetMaxLevel, "capped")
		t.eq(p.Xp, 0, "no xp at max")
		t.eq(PetMath.AddXp(p, 100), 0, "no more levels")
		local q = pet("Puppy")
		for _, bad in { -10, 0, 0 / 0, math.huge, -math.huge } do
			t.eq(PetMath.AddXp(q, bad), 0, "bad xp " .. tostring(bad))
		end
		t.eq(q.Level, 1, "unchanged")
		t.eq(q.Xp, 0, "unchanged xp")
	end,
	["delete refund is at least 1"] = function(t)
		t.ok(PetMath.DeleteRefund(pet("Puppy")) >= 1, "puppy")
		local fox = pet("Fox")
		t.eq(PetMath.DeleteRefund(fox), math.max(1, math.floor(PetMath.Power(fox) * Config.DeleteRefund)), "fox")
		local cat = pet("CometCat")
		local expect = math.floor(PetMath.Power(cat) * Areas.ById.Starfall.CoinMult * Config.DeleteRefund)
		t.eq(PetMath.DeleteRefund(cat), expect, "area coin mult")
	end,
	["Stronger sorts by power then uid"] = function(t)
		local a = pet("Fox")
		a.Uid = "2"
		local b = pet("Puppy")
		b.Uid = "1"
		t.ok(PetMath.Stronger(a, b), "fox first")
		t.no(PetMath.Stronger(b, a), "puppy second")
		local c = pet("Fox")
		c.Uid = "3"
		t.ok(PetMath.Stronger(a, c), "uid tiebreak")
	end,
	["gem pets scale with the given island, Meadow by default"] = function(t)
		t.ok(PetMath.IsScaling("CrystalPup"), "prism pet scales")
		t.no(PetMath.IsScaling("Puppy"), "egg pet doesn't")
		local rare = Config.RarityPower.Rare
		t.eq(PetMath.BasePower("CrystalPup"), rare * Areas.ById.Meadow.PowerMult, "meadow default")
		t.eq(PetMath.BasePower("CrystalPup", "Frost"), rare * Areas.ById.Frost.PowerMult, "frost")
		t.eq(PetMath.BasePower("CrystalPup", "Nowhere"), rare * Areas.ById.Meadow.PowerMult, "unknown area -> meadow")
		t.eq(PetMath.BasePower("Puppy", "Starfall"), PetMath.BasePower("Puppy"), "egg pets fixed")
		t.ok(near(PetMath.Power(pet("CrystalPup"), "Grove"), rare * Areas.ById.Grove.PowerMult), "power uses scale")
	end,
	["gem pets refund at Meadow level"] = function(t)
		local p = pet("DiamondDragon", "Rainbow", true, 25)
		local expect = math.max(1, math.floor(PetMath.Power(p, "Meadow") * Areas.ById.Meadow.CoinMult * Config.DeleteRefund))
		t.eq(PetMath.DeleteRefund(p), expect, "meadow refund")
		t.ok(PetMath.DeleteRefund(p) < Areas.ById.Grove.GateCost, "can't buy the second gate with one gem pet")
	end,
	["StrongerAt ranks gem pets by the scale island"] = function(t)
		local gem = pet("CrystalPup")
		gem.Uid = "1"
		local owl = pet("Owl")
		owl.Uid = "2"
		t.ok(PetMath.StrongerAt("Meadow")(owl, gem), "owl beats a meadow-scaled pup")
		t.ok(PetMath.StrongerAt("Starfall")(gem, owl), "starfall-scaled pup beats owl")
	end,
}
