local Recipes = require("../src/shared/Recipes")

local expected = {
	[1] = { "CrudeAxe", "CrudePickaxe", "CrudeSpear", "StorageBox", "WoodWall", "RepairHammer" },
	[2] = { "StoneAxe", "StonePickaxe", "Spear", "Bow", "Arrows", "Canteen", "Gate", "Spikes", "FirstAid" },
}

return {
	tiers_one_and_two = function(t)
		for level, ids in expected do
			for _, id in ids do
				t.eq(Recipes.ById[id] and Recipes.ById[id].Level, level, id .. " tier")
			end
		end
	end,
	every_tier_unlocks_something = function(t)
		t.eq(Recipes.MaxWorkbenchLevel, 5)
		for lvl = 1, 5 do
			local n = 0
			for _, r in Recipes.List do
				if r.Level == lvl then
					n += 1
				end
			end
			t.ok(n > 0, "tier " .. lvl .. " unlocks recipes")
		end
	end,
	spec_crude_tools = function(t)
		local function eq(id, cost)
			for k, v in cost do
				t.eq(Recipes.ById[id].Cost[k], v, id .. " " .. k)
			end
			for k in Recipes.ById[id].Cost do
				t.ok(cost[k] ~= nil, id .. " unexpected cost " .. k)
			end
		end
		eq("CrudeAxe", { Stick = 8, Stone = 3, Plant = 3 })
		eq("CrudePickaxe", { Stick = 10, Stone = 5, Plant = 3 })
		eq("CrudeSpear", { Stick = 12, Stone = 3, Plant = 5 })
	end,
	spec_workbench_costs = function(t)
		local U = Recipes.WorkbenchUpgrades
		t.eq(U[2].Wood, 64); t.eq(U[2].Stone, 36); t.eq(U[2].Plant, 10)
		t.eq(U[3].Wood, 192); t.eq(U[3].Stone, 96); t.eq(U[3].Scrap, 40)
		t.eq(U[4].Wood, 384); t.eq(U[4].Stone, 192); t.eq(U[4].Scrap, 100); t.eq(U[4].Iron, 32)
		t.eq(U[5].Wood, 640); t.eq(U[5].Stone, 300); t.eq(U[5].Scrap, 200); t.eq(U[5].Iron, 96); t.eq(U[5].RareComponent, 3)
	end,
	rope_and_bandage_anywhere = function(t)
		t.eq(Recipes.ById.Rope.Level, 0)
		t.eq(Recipes.ById.Rope.Cost.Plant, 3)
		t.eq(Recipes.ById.Bandage.Level, 0)
		t.eq(Recipes.ById.Canteen.Level, 2)
	end,
	results_are_items = function(t)
		local ok, Items = pcall(require, "../src/shared/Items")
		if not ok then
			return -- Items needs Roblox types (Color3); covered by the skins suite
		end
		for _, r in Recipes.List do
			t.ok(Items[r.Result] ~= nil, r.Id .. " result")
		end
	end,
}
