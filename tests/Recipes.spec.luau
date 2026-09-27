local Recipes = require("../src/shared/Recipes")

local expected = {
	[1] = { "StoneAxe", "StorageBox", "WoodWall", "Spear", "RepairHammer" },
	[2] = { "Canteen", "Bow", "Arrows", "Gate", "Spikes" },
	[3] = { "Armor", "Sword", "ReinforcedWall", "Watchtower", "Shield" },
}

return {
	five_recipes_per_level = function(t)
		for level, ids in expected do
			local n = 0
			for _, r in Recipes.List do
				if r.Level == level then
					n += 1
					t.ok(table.find(ids, r.Id), "unexpected recipe " .. r.Id .. " at level " .. level)
				end
			end
			t.eq(n, 5, "level " .. level .. " count")
		end
	end,
	rope_not_a_workbench_unlock = function(t)
		t.eq(Recipes.ById.Rope.Level, 0)
		t.eq(Recipes.ById.Rope.Cost.Plant, 3)
	end,
	brief_constraints = function(t)
		local axe = Recipes.ById.StoneAxe.Cost
		t.eq(axe.Stick, 1)
		t.eq(axe.Stone, 1)
		local can = Recipes.ById.Canteen
		t.eq(can.Level, 2)
		t.ok(can.Cost.Leather and can.Cost.Rope, "canteen uses leather and rope")
		local hammer = Recipes.ById.RepairHammer.Cost
		t.ok(hammer.Wood and hammer.Stone, "hammer uses wood and stone")
		for lvl = 2, 3 do
			local up = Recipes.WorkbenchUpgrades[lvl]
			t.ok(up.Wood and up.Stone and up.Leather and up.Rope, "upgrade " .. lvl .. " uses all four")
		end
	end,
	costs_fit_in_a_pack = function(t)
		for _, r in Recipes.List do
			local total = 0
			for _, n in r.Cost do
				total += n
			end
			t.ok(total <= 30 or r.Kind == "Structure", r.Id .. " personal craft must fit in a 30-unit pack")
		end
	end,
}
