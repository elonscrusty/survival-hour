local L = require("../src/shared/Logic/ClassLevels")
local Classes = require("../src/shared/Classes")

return {
	every_class_has_a_task = function(t)
		for _, def in Classes.List do
			local task = L.Tasks[def.Id]
			t.ok(task ~= nil, "task for " .. def.Id)
			t.eq(#task.Need, L.Max - 1)
			t.ok(task.Need[1] < task.Need[2], "goals rise")
		end
	end,
	levels_follow_progress = function(t)
		t.eq(L.LevelFor("Hunter", 0), 1)
		t.eq(L.LevelFor("Hunter", 24), 1)
		t.eq(L.LevelFor("Hunter", 25), 2)
		t.eq(L.LevelFor("Hunter", 500), 3)
		t.eq(L.LevelFor("Unknown", 500), 1)
	end,
	commit_counts_only_the_class_task = function(t)
		local stats = {}
		t.eq(L.Commit(stats, "Hunter", { Animals = 20, Kills = 9 }), nil)
		t.eq(L.Progress(stats, "Hunter"), 20)
		t.eq(L.Progress(stats, "Tracker"), 0, "other classes untouched")
		t.eq(L.Commit(stats, "Hunter", { Animals = 6 }), 2, "level up reported")
		t.eq(L.Commit(stats, "Hunter", {}), nil)
	end,
	effects_grow_a_little_and_only_percentages = function(t)
		local fx = { AxeSpeed = 0.15, AxeWear = -0.15, BonusSlots = 2, ContainerSense = 40, TrackWildlife = 1 }
		local l1 = L.Effects(fx, 1)
		local l3 = L.Effects(fx, 3)
		t.eq(l1.AxeSpeed, 0.15)
		t.ok(math.abs(l3.AxeSpeed - 0.225) < 1e-9)
		t.ok(math.abs(l3.AxeWear + 0.225) < 1e-9)
		t.eq(l3.BonusSlots, 2)
		t.eq(l3.ContainerSense, 40)
		t.eq(l3.TrackWildlife, 1)
		t.eq(L.Effects(fx, 99).AxeSpeed, l3.AxeSpeed, "clamped to max")
	end,
	view_and_boost_preview = function(t)
		local v = L.View({ [L.Key("Miner")] = 250 }, "Miner")
		t.eq(v.Level, 2)
		t.eq(v.Need, 700)
		t.eq(L.View({ [L.Key("Miner")] = 900 }, "Miner").Need, nil, "max level")
		local b = L.Boosts({ PickSpeed = 0.15, CaveSight = 1 }, 1)
		t.eq(#b, 1)
		t.eq(b[1].From, 15)
		t.eq(b[1].To, 19)
		t.eq(#L.Boosts({ PickSpeed = 0.15 }, 3), 0)
	end,
}
