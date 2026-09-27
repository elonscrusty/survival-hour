local PR = require("../src/shared/Logic/PlacementRules")

local function ctx(existing)
	return {
		Fire = { X = 0, Z = 0 },
		ZoneRadius = 55,
		Clearances = { { X = 0, Z = 0, R = 9 }, { X = 0, Z = -14, R = 7 } },
		Existing = existing or {},
		LimitUsed = 0,
		LimitMax = 40,
	}
end

local function wall(x, z, yaw)
	return { X = x, Z = z, HX = 5, HZ = 0.8, Yaw = yaw or 0 }
end

return {
	valid_wall = function(t)
		t.ok(PR.Check(wall(0, 30), ctx()))
	end,
	outside_zone = function(t)
		local ok, why = PR.Check(wall(0, 54), ctx())
		t.no(ok)
		t.eq(why, "Outside your camp's build zone")
	end,
	fire_clearance = function(t)
		t.no(PR.Check(wall(0, 5), ctx()))
	end,
	workbench_clearance = function(t)
		t.no(PR.Check(wall(0, -12), ctx()))
	end,
	overlap = function(t)
		t.no(PR.Check(wall(2, 30), ctx({ wall(0, 30) })), "overlapping walls")
		t.ok(PR.Check(wall(10, 30), ctx({ wall(0, 30) })), "walls end-to-end allowed")
		t.no(PR.Check(wall(0, 30, 90), ctx({ wall(0, 30) })), "crossing walls")
	end,
	rotated_zone_corner = function(t)
		t.no(PR.Check(wall(38, 38, 45), ctx()), "rotated corners checked")
	end,
	limit = function(t)
		local c = ctx()
		c.LimitUsed = 40
		local ok, why = PR.Check(wall(0, 30), c)
		t.no(ok)
		t.eq(why, "Structure limit reached")
	end,
}
