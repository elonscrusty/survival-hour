local Powerups = require("../src/shared/Powerups")

return {
	six_powerups_three_levels = function(t)
		t.eq(#Powerups.List, 6)
		for _, p in Powerups.List do
			t.eq(#p.Levels, 3, p.Id)
			t.ok(p.Challenges[2] and p.Challenges[3], p.Id .. " challenges")
			t.ok(p.Challenges[3].Target > p.Challenges[2].Target, p.Id .. " L3 harder")
		end
	end,
	prices = function(t)
		local exp = { Trailblazer = 100, Craftsman = 125, Hunter = 150, Scavenger = 175, Climber = 200, Sharpshooter = 250 }
		for id, price in exp do
			t.eq(Powerups.ById[id].Price, price, id)
		end
		t.eq(Powerups.UpgradePrice("Trailblazer", 2), 80)
		t.eq(Powerups.UpgradePrice("Trailblazer", 3), 150)
		t.eq(Powerups.List[1].Id, "Trailblazer", "cheapest first")
	end,
	modest_bonuses = function(t)
		for _, p in Powerups.List do
			for _, lvl in p.Levels do
				for k, v in lvl.Passive do
					t.ok(v <= 35, p.Id .. " passive " .. k .. " too large")
				end
			end
		end
	end,
	levels_monotonic = function(t)
		for _, p in Powerups.List do
			for i = 2, 3 do
				for k, v in p.Levels[i].Passive do
					t.ok(v >= p.Levels[i - 1].Passive[k], p.Id .. " " .. k)
				end
				if p.Levels[i].Ability.Cooldown then
					t.ok(p.Levels[i].Ability.Cooldown <= p.Levels[i - 1].Ability.Cooldown, p.Id .. " cooldown")
				end
			end
		end
	end,
	describe = function(t)
		t.eq(Powerups.Describe("+{SpeedPct}% speed", { SpeedPct = 4 }), "+4% speed")
	end,
}
