local Loot = require("../src/shared/Loot")
local Rng = require("../src/shared/Logic/Rng")

return {
	odds_sum_to_100 = function(t)
		t.eq(Loot.TotalWeight(Loot.CarePackage), 100, "care package odds")
		t.eq(Loot.TotalWeight(Loot.Crate), 100, "crate odds")
	end,
	exactly_three_entries = function(t)
		local rng = Rng.new(42)
		for _ = 1, 200 do
			local roll = Loot.RollCarePackage(function()
				return rng:Next()
			end)
			t.eq(#roll, 3)
		end
	end,
	guns_sometimes_not_always = function(t)
		local rng = Rng.new(7)
		local withGun, total = 0, 2000
		for _ = 1, total do
			local roll = Loot.RollCarePackage(function()
				return rng:Next()
			end)
			for _, e in roll do
				if e.Id == "Pistol" or e.Id == "Rifle" then
					withGun += 1
					break
				end
			end
		end
		-- P(at least one gun) = 1 - 0.88^3 ~= 31.9%
		local frac = withGun / total
		t.ok(frac > 0.26 and frac < 0.38, "gun frequency " .. frac)
	end,
	distribution_matches_weights = function(t)
		local rng = Rng.new(99)
		local counts = {}
		local n = 50000
		for _ = 1, n do
			local e = Loot.Roll(Loot.CarePackage, function()
				return rng:Next()
			end)
			counts[e.Id] = (counts[e.Id] or 0) + 1
		end
		for _, e in Loot.CarePackage do
			local observed = (counts[e.Id] or 0) / n * 100
			t.ok(math.abs(observed - e.Weight) < 1, e.Id .. " observed " .. observed)
		end
	end,
	chest_tiers = function(t)
		for _, tier in { "Common", "Uncommon", "Rare", "Epic" } do
			local tbl = Loot.Chest[tier]
			t.ok(tbl ~= nil, tier .. " table")
			t.eq(Loot.TotalWeight(tbl), 100, tier .. " odds")
			t.ok((Loot.ChestRolls[tier] or 0) >= 1, tier .. " rolls")
			local gun = false
			for _, e in tbl do
				for _, g in e.Grants do
					if g.Item == "Pistol" or g.Item == "Rifle" then
						gun = true
					end
				end
			end
			t.eq(gun, tier == "Rare" or tier == "Epic", tier .. " gun policy")
		end
		t.ok(Loot.ChestRolls.Epic > Loot.ChestRolls.Common, "epic chests give more")
		local rng = Rng.new(3)
		t.eq(#Loot.RollChest("Epic", function()
			return rng:Next()
		end), Loot.ChestRolls.Epic)
	end,
	crates_have_no_guns = function(t)
		for _, e in Loot.Crate do
			for _, g in e.Grants do
				t.ok(g.Item ~= "Pistol" and g.Item ~= "Rifle", "crate gun")
			end
		end
	end,
}
