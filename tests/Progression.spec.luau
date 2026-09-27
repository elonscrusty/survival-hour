local Progression = require("../src/shared/Progression")

return {
	xp_curve = function(t)
		t.eq(Progression.XPForLevel(1), 150)
		t.eq(Progression.XPForLevel(2), 170)
		t.eq(Progression.TotalForLevel(1), 0)
		t.eq(Progression.TotalForLevel(2), 150)
		t.eq(Progression.TotalForLevel(3), 320)
		for l = 1, 99 do
			t.eq(Progression.TotalForLevel(l + 1) - Progression.TotalForLevel(l), Progression.XPForLevel(l), "level " .. l)
		end
	end,
	level_from_xp = function(t)
		t.eq((Progression.LevelFromXP(0)), 1)
		t.eq((Progression.LevelFromXP(149)), 1)
		t.eq((Progression.LevelFromXP(150)), 2)
		local l, into, need = Progression.LevelFromXP(160)
		t.eq(l, 2)
		t.eq(into, 10)
		t.eq(need, 170)
		t.eq((Progression.LevelFromXP(10 ^ 9)), Progression.MaxLevel)
	end,
	long_grind = function(t)
		-- a solid match is ~600-1200 XP; level 100 should take hundreds of matches
		local total = Progression.TotalForLevel(100)
		t.ok(total / 1000 > 100, "level 100 is a long grind: " .. total)
	end,
	placement = function(t)
		t.eq(select(3, Progression.Placement(1)), 2, "exactly 2 diamonds")
		t.eq(select(2, Progression.Placement(1)), 250)
		t.eq(select(1, Progression.Placement(2)), 250)
		t.eq(select(2, Progression.Placement(3)), 50)
		t.eq(select(2, Progression.Placement(4)), 0)
	end,
	spec_reward_values = function(t)
		t.eq(Progression.XP.SurviveNight, 50)
		t.eq(Progression.XP.Kill, 50)
		t.eq(Progression.XP.Elimination, 100)
		t.eq(Progression.XP.ExtinguishFire, 150)
		t.eq(Progression.XP.WorkbenchV, 200)
		t.eq(Progression.Coins.SurviveNight, 10)
		t.eq(Progression.Coins.Kill, 15)
		t.eq(Progression.Coins.ExtinguishFire, 40)
	end,
	level_rewards = function(t)
		local r = Progression.LevelRewards(1, 20)
		local coins, diamonds = 0, 0
		for _, x in r do
			coins += x.Coins
			diamonds += x.Diamonds
		end
		t.eq(coins, 400)
		t.eq(diamonds, 2)
		t.eq(#Progression.LevelRewards(5, 5), 0)
	end,
	bonuses = function(t)
		t.eq(Progression.DailyCoins(1), 50)
		t.eq(Progression.DailyCoins(100), 150)
		t.eq(Progression.WeeklyCoins(0), 300)
		t.eq(Progression.WeeklyCoins(20), 750)
	end,
	weeks_start_monday = function(t)
		-- 1970-01-05 was a Monday
		t.eq(Progression.WeekNumber(4 * 86400 - 1) + 1, Progression.WeekNumber(4 * 86400))
	end,
}
