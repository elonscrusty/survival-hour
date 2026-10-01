-- Layout invariants for the farm plots (src/shared/Logic/PlotLayout.luau). World.luau builds
-- straight from these numbers, so they stand in for an in-Studio visual check.
local L = require("../src/shared/Logic/PlotLayout")

local function inside(t, p, what, margin)
	t.ok(L.InsideLocal(p, margin), string.format("%s (%g, %g) inside the plot", what, p.x, p.z))
end

local function rectInside(t, r, what)
	t.ok(r.x0 >= -L.HALF_W and r.x1 <= L.HALF_W and r.z0 >= -L.HALF_D and r.z1 <= L.HALF_D, what .. " inside the plot")
end

local function overlap(a, b)
	return a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1
end

local function circleRect(c, r, rect)
	local px = math.clamp(c.x, rect.x0, rect.x1)
	local pz = math.clamp(c.z, rect.z0, rect.z1)
	return (c.x - px) ^ 2 + (c.z - pz) ^ 2 < r * r
end

local function buildingRect(h)
	-- footprint in plot axes: d along x (facing is +-x), w along z
	local b = h.building
	return { x0 = b.x - h.buildingMax.d / 2, x1 = b.x + h.buildingMax.d / 2, z0 = b.z - h.buildingMax.w / 2, z1 = b.z + h.buildingMax.w / 2 }
end

return {
	eight_plots_without_overlap = function(t)
		t.eq(L.PlotCount, 8)
		for i = 1, 8 do
			for j = i + 1, 8 do
				t.no(overlap(L.Bounds(i), L.Bounds(j)), "plots " .. i .. " and " .. j .. " overlap")
			end
			local b = L.Bounds(i)
			t.ok(math.min(math.abs(b.z0), math.abs(b.z1)) >= L.BOULEVARD_HALF, "plot clear of the boulevard")
		end
	end,
	front_faces_the_boulevard = function(t)
		for i = 1, 8 do
			local front = L.ToWorld(i, { x = 0, y = 0, z = L.HALF_D })
			local back = L.ToWorld(i, { x = 0, y = 0, z = -L.HALF_D })
			t.ok(math.abs(front.z) < math.abs(back.z), "plot " .. i .. " front faces the boulevard")
			local o = L.Origin(i)
			local c = L.ToWorld(i, { x = 0, y = 0, z = 0 })
			t.near(c.x, o.x)
			t.near(c.z, o.z)
		end
	end,
	houses_rings_yards_boards_inside = function(t)
		t.eq(#L.Houses, 4)
		for _, h in L.Houses do
			rectInside(t, h.lot, "lot " .. h.slot)
			inside(t, h.ring, "ring", h.ringRadius)
			inside(t, h.anchor, "anchor")
			inside(t, h.board, "board")
			t.ok(h.ringRadius >= 6 and h.ringRadius <= 8, "ring radius about 7")
			t.no(circleRect(h.ring, h.ringRadius, buildingRect(h)), "ring clear of the building")
			-- the yard (anchor box) must not intersect the building footprint
			local yard = { x0 = h.anchor.x - h.anchorSize.x / 2, x1 = h.anchor.x + h.anchorSize.x / 2, z0 = h.anchor.z - h.anchorSize.z / 2, z1 = h.anchor.z + h.anchorSize.z / 2 }
			t.no(overlap(yard, buildingRect(h)), "yard clear of the building")
			local br = buildingRect(h)
			t.ok(br.x0 >= h.lot.x0 and br.x1 <= h.lot.x1 and br.z0 >= h.lot.z0 and br.z1 <= h.lot.z1, "building fits its lot")
			for _, o in L.Houses do
				if o ~= h then
					t.no(overlap(h.lot, o.lot), "lots overlap")
					local d = math.sqrt((h.ring.x - o.ring.x) ^ 2 + (h.ring.z - o.ring.z) ^ 2)
					t.ok(d > h.ringRadius + o.ringRadius, "rings overlap")
				end
			end
		end
	end,
	warehouse_dock_bays = function(t)
		local w = L.Warehouse
		local wr = { x0 = w.center.x - w.w / 2, x1 = w.center.x + w.w / 2, z0 = w.center.z - w.d / 2, z1 = w.center.z + w.d / 2 }
		rectInside(t, wr, "warehouse")
		inside(t, L.Deposit.pos, "deposit ring", L.Deposit.radius)
		t.no(circleRect(L.Deposit.pos, L.Deposit.radius, wr), "deposit ring clear of the warehouse")
		for _, h in L.Houses do
			t.no(circleRect(L.Deposit.pos, L.Deposit.radius, h.lot), "deposit ring clear of lots")
		end
		t.eq(#L.Bays, 8)
		for i, b in L.Bays do
			inside(t, b, "bay " .. i, 5)
			if i > 1 then
				t.ok(b.x - L.Bays[i - 1].x >= L.BayWidth, "bays wide enough")
			end
			t.ok(b.z > L.ROAD_Z + L.ROAD_WIDTH / 2 + 4, "bay clear of the road")
			t.ok(b.x < L.Road[1].x, "bays are before the first waypoint")
		end
		inside(t, L.WorkerStart, "worker start")
		inside(t, L.Spawn, "spawn", 5)
	end,
	road_leaves_the_plot = function(t)
		t.ok(#L.Road >= 3, "enough waypoints")
		inside(t, L.Road[1], "first waypoint")
		t.no(L.InsideLocal(L.Road[#L.Road]), "last waypoint outside the plot")
		t.ok(L.Road[L.TunnelAt].z < L.RIDGE_LOCAL_Z, "tunnel waypoint inside the hill")
		t.ok(L.RIDGE_LOCAL_Z < -L.HALF_D, "hill behind the plot")
		for i = 2, #L.Road do
			local a, b = L.Road[i - 1], L.Road[i]
			t.ok((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2 > 1, "distinct waypoints")
		end
		for bay = 1, 8 do
			local path = L.VehiclePath(bay)
			local len = L.PolyLength(path)
			local td = L.TunnelDistance(bay)
			t.ok(td > 0 and td < len, "tunnel point lies on the path")
			local p = L.PolyPoint(path, td)
			t.near(p.z, L.RIDGE_LOCAL_Z, 1e-6, "tunnel distance hits the hill face")
			local e = L.PolyPoint(path, len + 50)
			t.near(e.z, L.Road[#L.Road].z, 1e-9, "clamped to the end")
			-- the waypoints leave the plot in world space too
			for i = 1, 8 do
				local w = L.ToWorld(i, L.Road[#L.Road])
				local bb = L.Bounds(i)
				t.no(w.x > bb.x0 and w.x < bb.x1 and w.z > bb.z0 and w.z < bb.z1, "world exit outside")
			end
		end
	end,
	silos_boards_fox_decor_inside = function(t)
		t.eq(#L.Silos, 10)
		for i, s in L.Silos do
			inside(t, s, "silo " .. i, L.SiloRadius)
			for _, h in L.Houses do
				t.no(circleRect(s, L.SiloRadius, h.lot), "silo clear of lots")
			end
		end
		local menus = {}
		for _, b in L.Boards do
			inside(t, b.pos, "board " .. b.name, 1)
			menus[b.menu] = true
		end
		for _, m in { "Housing", "Shipping", "Workers", "Silos", "Upgrades", "Eggs" } do
			t.ok(menus[m], "board for " .. m)
		end
		t.ok(#L.FoxSpots >= 4, "fox spots")
		for _, f in L.FoxSpots do
			inside(t, f, "fox spot", 2)
		end
		for _, d in L.Decor do
			inside(t, d, "decor", 3)
			for _, h in L.Houses do
				t.no(circleRect(d, 3, h.lot), "decor clear of lots")
			end
			for _, r in L.Paths do
				t.no(circleRect(d, 3, r), "decor clear of paths")
			end
			for _, r in L.RoadRects do
				t.no(circleRect(d, 3, r), "decor clear of the road")
			end
		end
		for _, r in L.Paths do
			rectInside(t, r, "path")
		end
	end,
	worker_route_ends_at_ring = function(t)
		for slot = 1, 4 do
			local r = L.WorkerRoute(slot)
			t.near(r[1].x, L.WorkerStart.x)
			t.near(r[#r].x, L.Houses[slot].ring.x)
			t.near(r[#r].z, L.Houses[slot].ring.z)
			for _, p in r do
				inside(t, p, "worker route")
			end
		end
	end,
}
