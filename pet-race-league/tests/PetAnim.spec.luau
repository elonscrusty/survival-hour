local PetAnim = require("../src/shared/Logic/PetAnim")

local function state(run, air, land, happy)
	return { Run = run, Air = air, Land = land, Happy = happy, Look = 0.3, Size = 4 }
end

local function finite(p)
	for j, o in p do
		for _, v in { o.rx, o.ry, o.rz, o.x, o.y, o.z } do
			if v ~= v or math.abs(v) > 5 then
				return false, j
			end
		end
	end
	return true
end

return {
	all_joints_present_and_sane = function(t)
		for _, s in { state(0, 0, 0, 0), state(1, 0, 0, 0), state(0.5, 1, 0, 0), state(0, 0, 1, 0), state(0, 0, 0, 1), state(5, -2, 9, 3) } do
			for i = 0, 40 do
				local p = PetAnim.Sample(s, i * 0.13, i * 0.41)
				for _, j in PetAnim.Joints do
					t.ok(p[j] ~= nil, j)
				end
				local ok, j = finite(p)
				t.ok(ok, "bad value on " .. tostring(j))
			end
		end
	end,
	idle_is_calm_running_is_big = function(t)
		local maxIdle, maxRun = 0, 0
		for i = 0, 60 do
			local idle = PetAnim.Sample(state(0, 0, 0, 0), i * 0.1, i * 0.3)
			local run = PetAnim.Sample(state(1, 0, 0, 0), i * 0.1, i * 0.3)
			maxIdle = math.max(maxIdle, math.abs(idle.LegFL.rx))
			maxRun = math.max(maxRun, math.abs(run.LegFL.rx))
		end
		t.ok(maxIdle < 0.01, "legs still when idle")
		t.ok(maxRun > 0.6, "legs swing when running")
	end,
	diagonal_legs_move_together = function(t)
		local p = PetAnim.Sample(state(1, 0, 0, 0), 1, 0.8)
		t.near(p.LegFL.rx, p.LegBR.rx, 1e-9)
		t.near(p.LegFR.rx, p.LegBL.rx, 1e-9)
		t.ok(p.LegFL.rx * p.LegFR.rx < 0, "pairs swing opposite")
	end,
	landing_squashes = function(t)
		t.ok(PetAnim.Sample(state(0, 0, 1, 0), 0, 0).Body.y < 0)
	end,
	happy_hops = function(t)
		local top = 0
		for i = 0, 30 do
			top = math.max(top, PetAnim.Sample(state(0, 0, 0, 1), i * 0.05, 0).Body.y)
		end
		t.ok(top > 0.4)
	end,
	ears_mirror = function(t)
		local p = PetAnim.Sample(state(1, 0, 1, 0), 0.7, 1.1)
		t.ok(p.EarL.rz * p.EarR.rz <= 0, "ears flop outward on both sides")
	end,
	cycle_speed_grows = function(t)
		t.ok(PetAnim.CycleSpeed(1) > PetAnim.CycleSpeed(0))
	end,
	blink_is_short = function(t)
		local closed = 0
		for i = 0, 999 do
			if PetAnim.Blink(i * 0.01, 3) < 0.5 then
				closed += 1
			end
		end
		t.ok(closed > 0 and closed < 60, "blinks briefly: " .. closed)
	end,
}
