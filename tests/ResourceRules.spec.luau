local Resources = require("../src/shared/Resources")
local RR = require("../src/shared/Logic/ResourceRules")
local Rng = require("../src/shared/Logic/Rng")

local AXE = 10 -- CrudeAxe ToolPower

return {
	every_def_is_complete = function(t)
		local seen = {}
		for _, id in Resources.Order do
			local d = Resources.Defs[id]
			t.ok(d ~= nil, "Order lists unknown resource " .. id)
			seen[id] = true
			t.eq(d.Id, id, "Id field")
			t.ok(d.Kind == "Tree" or d.Kind == "Harvest", id .. " kind")
			t.ok(d.Health > 0 and d.RespawnTime > 0 and d.GrowTime > 0 and d.Range > 0, id .. " numbers")
			t.ok(d.Placement.PerSector > 0 and d.Placement.NearCamp <= d.Placement.PerSector, id .. " placement")
			t.ok(next(d.PerHit) ~= nil, id .. " yields something per hit")
			for _, drop in d.Drops do
				t.ok(drop.Min <= drop.Max, id .. " drop range")
			end
			for item in d.Yield or {} do
				t.ok(d.PerHit[item] ~= nil or d.Kind == "Tree" or d.RequiredTool ~= "Hand", id .. " yield " .. item)
			end
			if d.Kind == "Tree" then
				t.eq(d.RequiredTool, "Axe", id .. " trees need an axe")
				t.ok(d.FellTime > 0, id .. " fell time")
			end
		end
		for id in Resources.Defs do
			t.ok(seen[id], id .. " missing from Resources.Order")
		end
	end,

	bigger_trees_take_longer_and_give_more = function(t)
		local s, m, l = Resources.Defs.TreeSmall, Resources.Defs.TreeMedium, Resources.Defs.TreeLarge
		t.ok(RR.HitsToFinish(s, AXE) < RR.HitsToFinish(m, AXE), "medium > small hits")
		t.ok(RR.HitsToFinish(m, AXE) < RR.HitsToFinish(l, AXE), "large > medium hits")
		local function minWood(d)
			local w = 0
			for _, drop in d.Drops do
				if drop.Item == "Wood" and drop.Chance == nil then
					w += drop.Min
				end
			end
			return w + RR.HitsToFinish(d, AXE) * (d.PerHit.Wood or 0)
		end
		t.ok(minWood(s) < minWood(m) and minWood(m) < minWood(l), "wood scales with size")
	end,

	tree_lifecycle = function(t)
		local d = Resources.Defs.TreeSmall
		local s = RR.New(d)
		local rng = Rng.new(5)
		t.eq(s.State, "Healthy")
		local r = RR.Hit(d, s, "Axe", AXE, 0, rng)
		t.ok(r.Ok and not r.Finished, "first hit")
		t.eq(s.State, "Damaged")
		t.eq(r.Items.Wood, 1, "per-hit wood (40 hp, 4 wood, 10 per hit)")
		local hits = 1
		while not r.Finished do
			r = RR.Hit(d, s, "Axe", AXE, 0, rng)
			hits += 1
		end
		t.eq(hits, RR.HitsToFinish(d, AXE), "hit count")
		t.eq(s.State, "Felled")
		t.eq(r.Items.Wood, 1, "last hit gives the last wood")
		-- no more hits while felled
		t.eq(RR.Hit(d, s, "Axe", AXE, 0.5, rng).Reason, "Unavailable")
		t.eq(RR.Advance(d, s, d.FellTime - 0.01), nil)
		t.eq(RR.Advance(d, s, d.FellTime), "Stump")
		t.eq(RR.Advance(d, s, d.RespawnTime - 1), nil, "stump waits for respawn")
		t.eq(RR.Advance(d, s, d.RespawnTime), "Respawning")
		t.no(RR.Available(s), "not choppable while growing")
		t.eq(RR.Advance(d, s, d.RespawnTime + d.GrowTime), "Healthy")
		t.eq(s.Health, s.Max, "full health after regrowth")
	end,

	tree_needs_axe = function(t)
		local d = Resources.Defs.TreeMedium
		local s = RR.New(d)
		local r = RR.Hit(d, s, nil, 1, 0, Rng.new(1))
		t.no(r.Ok)
		t.eq(r.Reason, "NeedTool")
		t.eq(s.Health, s.Max, "no damage without an axe")
	end,

	harvest_exhausts_and_refills = function(t)
		local d = Resources.Defs.BerryBush
		local s = RR.New(d)
		local rng = Rng.new(9)
		local total = 0
		for _ = 1, d.Health do
			local r = RR.Hit(d, s, nil, Resources.HandPower, 10, rng)
			t.ok(r.Ok, "gather")
			total += r.Items.Berries or 0
		end
		t.eq(total, d.Health * d.PerHit.Berries, "berries per bush")
		t.eq(s.State, "Exhausted")
		t.eq(RR.Advance(d, s, 10 + d.RespawnTime), "Respawning")
		t.eq(RR.Advance(d, s, 10 + d.RespawnTime + d.GrowTime), "Healthy")
	end,

	blocked_respawn_retries = function(t)
		local d = Resources.Defs.LooseStones
		local s = RR.New(d)
		RR.Hit(d, s, nil, 1, 0, Rng.new(2))
		t.eq(s.State, "Exhausted")
		t.eq(RR.Advance(d, s, d.RespawnTime, function() return false end), nil, "someone standing there")
		t.eq(s.State, "Exhausted")
		t.eq(s.RespawnAt, d.RespawnTime + RR.RetryDelay, "retry scheduled")
		t.eq(RR.Advance(d, s, s.RespawnAt, function() return true end), "Respawning")
	end,

	drops_deterministic_and_bounded = function(t)
		local d = Resources.Defs.TreeLarge
		for seed = 1, 50 do
			local a = RR.RollDrops(d, Rng.new(seed))
			local b = RR.RollDrops(d, Rng.new(seed))
			t.eq(a.Stick, b.Stick, "same seed, same drops")
			t.ok(a.Stick >= d.Drops[1].Min and a.Stick <= d.Drops[1].Max, "sticks in range")
		end
	end,

	exact_yields_any_tool = function(t)
		local cases = { { "TreeSmall", "Axe", "Wood", 4 }, { "TreeLarge", "Axe", "Wood", 16 }, { "RockPile", "Pickaxe", "Stone", 3 }, { "LargeRockPile", "Pickaxe", "Stone", 12 } }
		for _, c in cases do
			local d = Resources.Defs[c[1]]
			for _, power in { 10, 15, 22, 30, 7 } do
				local s = RR.New(d)
				local total, guard = 0, 0
				repeat
					local r = RR.Hit(d, s, c[2], power, 0, Rng.new(3), 4)
					total += r.Items[c[3]] or 0
					guard += 1
				until r.Finished or guard > 100
				t.eq(total, c[4], c[1] .. " power " .. power)
			end
		end
	end,

	tool_tiers = function(t)
		local large, small = Resources.Defs.TreeLarge, Resources.Defs.TreeSmall
		t.no(RR.ToolOk(large, "Axe", 1), "crude axe can't fell a large tree")
		t.ok(RR.ToolOk(large, "Axe", 2), "stone axe can")
		t.ok(RR.ToolOk(small, "Axe", 1))
		t.no(RR.ToolOk(Resources.Defs.RockPile, "Axe", 4), "axes don't mine")
		t.no(RR.ToolOk(Resources.Defs.LargeRockPile, "Pickaxe", 1))
		t.ok(RR.ToolOk(Resources.Defs.LooseStones, nil, nil), "loose stones by hand")
		local s = RR.New(large)
		t.eq(RR.Hit(large, s, "Axe", 10, 0, Rng.new(1), 1).Reason, "NeedTier")
	end,

	food_items_are_resources = function(t)
		local IM = require("../src/shared/Logic/InventoryModel")
		for id in Resources.Food do
			t.ok(IM.IsResource(id), id .. " must be a pack resource")
		end
		for _, d in Resources.Defs do
			for id in d.PerHit do
				t.ok(IM.IsResource(id), d.Id .. " yields unknown resource " .. id)
			end
			for _, drop in d.Drops do
				t.ok(IM.IsResource(drop.Item), d.Id .. " drops unknown resource " .. drop.Item)
			end
		end
	end,
}
