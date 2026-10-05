local Hatch = require("../src/shared/Logic/Hatch")
local Eggs = require("../src/shared/Eggs")
local Pets = require("../src/shared/Pets")

return {
	roll_covers_every_pet = function(t)
		for _, egg in Eggs.List do
			local seen = {}
			for i = 0, 9999 do
				seen[Hatch.Roll(egg, i / 10000)] = true
			end
			for _, o in egg.Odds do
				t.ok(seen[o.Pet], egg.Id .. " never rolls " .. o.Pet)
			end
		end
	end,
	roll_edges_are_valid = function(t)
		for _, egg in Eggs.List do
			t.eq(Hatch.Roll(egg, 0), egg.Odds[1].Pet)
			t.ok(Pets.ById[Hatch.Roll(egg, 0.9999999)] ~= nil)
		end
	end,
	pity_is_rare_or_better = function(t)
		for _, egg in Eggs.List do
			for i = 0, 99 do
				t.ok(Pets.Rank(Hatch.Roll(egg, i / 100, true)) >= 3, egg.Id)
			end
		end
	end,
	pity_every_tenth = function(t)
		t.ok(not Hatch.IsPity(9))
		t.ok(Hatch.IsPity(10))
		t.ok(Hatch.IsPity(20))
		t.ok(not Hatch.IsPity(0))
	end,
	chances_sum_to_one = function(t)
		for _, egg in Eggs.List do
			local sum = 0
			for _, c in Hatch.Chances(egg) do
				sum += c.Chance
			end
			t.near(sum, 1, 1e-9)
		end
	end,
	egg_pets_exist = function(t)
		for _, egg in Eggs.List do
			for _, o in egg.Odds do
				t.ok(Pets.ById[o.Pet] ~= nil, o.Pet)
			end
		end
	end,
}
