local LG = require("../src/shared/Logic/LayoutGen")

local function countBy(list, sector, typ)
	local n = 0
	for _, it in list do
		if it.Sector == sector and (typ == nil or it.Type == typ) then
			n += 1
		end
	end
	return n
end

return {
	many_seeds_validate = function(t)
		local fails = 0
		for seed = 1, 12 do
			local layout, blockers = LG.GenerateRaw(seed * 1013)
			local ok = LG.Validate(layout, blockers)
			if not ok then
				fails += 1
			end
		end
		-- Generate() retries, but raw seeds should almost always pass.
		t.ok(fails <= 2, "too many raw seeds failed: " .. fails)
		for seed = 1, 5 do
			t.ok(LG.Generate(seed * 31337), "Generate must return a valid layout")
		end
	end,
	four_camps_fixed = function(t)
		local l = LG.Generate(1)
		t.eq(#l.Camps, 4)
		local expect = { { 0, -400 }, { 400, 0 }, { 0, 400 }, { -400, 0 } }
		for i, c in l.Camps do
			t.ok(math.abs(c.X - expect[i][1]) < 1e-6 and math.abs(c.Z - expect[i][2]) < 1e-6, "camp " .. i)
		end
	end,
	fair_resources = function(t)
		local l = LG.Generate(77)
		for _, typ in { "SmallTree", "Twigs", "Rock", "Plant" } do
			local n1 = countBy(l.Nodes, 1, typ)
			t.ok(n1 > 0, typ .. " present")
			for s = 2, 4 do
				t.eq(countBy(l.Nodes, s, typ), n1, typ .. " sector " .. s)
			end
		end
		local c1 = countBy(l.CrateSpots, 1)
		for s = 2, 4 do
			t.eq(countBy(l.CrateSpots, s), c1, "crate spots sector " .. s)
		end
	end,
	nodes_in_own_sector = function(t)
		local l = LG.Generate(5)
		for _, n in l.Nodes do
			if n.Sector ~= 0 then
				t.eq(LG.SectorOf(n.X, n.Z), n.Sector, "node sector")
			end
		end
	end,
	varies_between_matches = function(t)
		local a, b = LG.Generate(1), LG.Generate(2)
		local same = true
		for i = 1, 5 do
			if math.abs(a.Nodes[i].X - b.Nodes[i].X) > 0.01 then
				same = false
			end
		end
		t.no(same, "layouts differ by seed")
	end,
	deterministic = function(t)
		local a, b = LG.Generate(123), LG.Generate(123)
		t.eq(#a.Trees, #b.Trees)
		t.eq(a.Trees[10].X, b.Trees[10].X)
	end,
	camp_has_water_and_nearby_resources = function(t)
		local l = LG.Generate(9)
		for _, c in l.Camps do
			local water = math.huge
			for _, w in l.WaterPoints do
				water = math.min(water, math.sqrt((w.X - c.X) ^ 2 + (w.Z - c.Z) ^ 2))
			end
			t.ok(water < 90, "camp " .. c.Team .. " creek distance " .. water)
			local near = 0
			for _, n in l.Nodes do
				local d = math.sqrt((n.X - c.X) ^ 2 + (n.Z - c.Z) ^ 2)
				if d < 140 then
					near += 1
				end
			end
			t.ok(near >= 12, "early resources near camp " .. c.Team .. ": " .. near)
		end
	end,
	sector_drop_points = function(t)
		local l = LG.Generate(11)
		t.ok(#l.DropPoints >= 5, "centre + one glade per sector")
	end,
	height_symmetric = function(t)
		local l = LG.Generate(3)
		local h1 = LG.Height(l, 37, -210)
		local x, z = LG.Rotate(37, -210, 1)
		t.ok(math.abs(LG.Height(l, x, z) - h1) < 1e-6, "height rotates with sectors")
		t.ok(math.abs(LG.Height(l, 0, -400) - l.Params.BaseHeight) < 1e-6, "camp flattened")
	end,
}
