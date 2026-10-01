local Flock = require("../src/shared/Logic/Flock")

local function sum(t)
	local s = 0
	for _, v in t do
		s += v
	end
	return s
end

local function lcg(seed)
	local s = seed
	return function()
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
end

return {
	caps_are_documented_numbers = function(t)
		t.eq(Flock.Caps.low.house, 6)
		t.eq(Flock.Caps.low.plot, 24)
		t.eq(Flock.Caps.normal.house, 15)
		t.eq(Flock.Caps.normal.plot, 60)
		t.eq(Flock.Caps.high.house, 30)
		t.eq(Flock.Caps.high.plot, 120)
		t.eq(Flock.Other.house, 1)
		t.eq(Flock.Other.plot, 4)
	end,
	empty_house_shows_nothing_occupied_shows_one = function(t)
		t.eq(Flock.ForHouse(0, 15), 0)
		t.eq(Flock.ForHouse(0.2, 15), 0)
		t.eq(Flock.ForHouse(1, 15), 1)
		t.eq(Flock.ForHouse(2, 15), 1)
	end,
	grows_logarithmically_and_caps = function(t)
		local prev = 0
		for e = 0, 12 do
			local n = Flock.ForHouse(10 ^ e, 15)
			t.ok(n >= prev, "monotonic at 1e" .. e)
			t.ok(n <= 15, "per-house cap")
			prev = n
		end
		t.eq(Flock.ForHouse(1e5, 15), 15, "full at FULL_AT")
		t.eq(Flock.ForHouse(1e300, 15), 15, "astronomic population")
		t.ok(Flock.ForHouse(100, 15) < Flock.ForHouse(10000, 15), "readable growth")
	end,
	bad_numbers_are_safe = function(t)
		t.eq(Flock.ForHouse(0 / 0, 15), 0)
		t.eq(Flock.ForHouse(-5, 15), 0)
		t.eq(Flock.ForHouse(math.huge, 15), 15)
	end,
	plan_respects_plot_cap_and_minimum = function(t)
		for _, setting in { "low", "normal", "high" } do
			local cap = Flock.Caps[setting]
			for _, occ in { { 1e9, 1e9, 1e9, 1e9 }, { 1e9, 1, 0, 3 }, { 50, 500, 5000, 50000 }, { 1, 1, 1, 1 } } do
				local plan = Flock.Plan({ occupants = occ, setting = setting, own = true })
				t.ok(sum(plan) <= cap.plot, setting .. " plot cap")
				for i = 1, 4 do
					t.ok(plan[i] <= cap.house, "house cap")
					if occ[i] >= 1 then
						t.ok(plan[i] >= 1, "occupied house shows at least one")
					else
						t.eq(plan[i], 0, "empty house shows none")
					end
				end
			end
		end
		local full = Flock.Plan({ occupants = { 1e9, 1e9, 1e9, 1e9 }, setting = "high", own = true })
		t.eq(sum(full), 120)
	end,
	plan_with_more_houses_than_budget = function(t)
		local occ = {}
		for i = 1, 30 do
			occ[i] = i * 1000
		end
		local plan = Flock.Plan({ occupants = occ, setting = "low", own = true })
		t.ok(sum(plan) <= 24, "never above the plot cap")
		t.eq(plan[30], 1 + plan[30] - 1)
		t.eq(plan[1], 0, "smallest houses drop out only when the plot cap cannot fit them")
	end,
	other_plots_tiny_and_range_limited = function(t)
		local near = Flock.Plan({ occupants = { 1e6, 10, 0, 1 }, own = false, distance = 50 })
		t.eq(near[1], 1)
		t.eq(near[2], 1)
		t.eq(near[3], 0)
		t.eq(near[4], 1)
		local far = Flock.Plan({ occupants = { 1e6, 10, 0, 1 }, own = false, distance = 500 })
		t.eq(sum(far), 0)
		local unknownSetting = Flock.Plan({ occupants = { 1e9 }, setting = "weird", own = true })
		t.eq(unknownSetting[1], 15, "unknown setting falls back to normal")
	end,
	distribute_by_capacity = function(t)
		local d = Flock.Distribute(1000, { 100, 300, 0, 600 })
		t.near(d[1], 100)
		t.near(d[2], 300)
		t.near(d[3], 0)
		t.near(d[4], 600)
		local z = Flock.Distribute(1000, { 0, 0 })
		t.eq(z[1], 0)
	end,
	lod_intervals_grow_with_distance = function(t)
		t.eq(Flock.UpdateInterval(10), 0)
		t.ok(Flock.UpdateInterval(100) > 0)
		t.ok(Flock.UpdateInterval(300) > Flock.UpdateInterval(100))
	end,
	wander_stays_in_yard = function(t)
		local rand = lcg(7)
		local hx, hz = 4.5, 18
		for _ = 1, 20 do
			local b = Flock.NewBird(hx, hz, rand)
			local moved = false
			local sx, sz = b.x, b.z
			for _ = 1, 600 do
				Flock.Wander(b, 1 / 30, hx, hz, rand)
				t.ok(math.abs(b.x) <= hx + 1e-9 and math.abs(b.z) <= hz + 1e-9, "inside yard")
				t.ok(b.hop >= 0 and b.hop < 0.5, "small hop")
				t.ok(b.peck >= 0 and b.peck <= 1, "peck range")
				if b.x ~= sx or b.z ~= sz then
					moved = true
				end
			end
			t.ok(moved, "birds wander")
		end
		local b = Flock.NewBird(hx, hz, rand)
		Flock.Wander(b, 0 / 0, hx, hz, rand)
		t.ok(b.x == b.x, "NaN dt safe")
	end,
}
