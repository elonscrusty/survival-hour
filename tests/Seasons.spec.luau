local Seasons = require("../src/shared/Logic/Seasons")
local Cosmetics = require("../src/shared/Cosmetics")
local P = require("../src/shared/Logic/ProfileRules")

-- Mirrors Config.Seasons (Config itself needs Roblox types).
local HALLOWEEN = { Id = "Halloween2026", Name = "Halloween", Start = 1792800000, End = 1793664000 }
local WINTER = { Id = "Winter2026", Name = "Winter", Start = 1797000000, End = 1798000000 }
local LIST = { HALLOWEEN, WINTER }

return {
	active_only_between_dates = function(t)
		t.eq(Seasons.Active(LIST, HALLOWEEN.Start - 1), nil, "before start")
		t.eq(Seasons.Active(LIST, HALLOWEEN.Start), HALLOWEEN, "start is inclusive")
		t.eq(Seasons.Active(LIST, HALLOWEEN.End - 1), HALLOWEEN, "last second")
		t.eq(Seasons.Active(LIST, HALLOWEEN.End), nil, "end is exclusive")
		t.eq(Seasons.Active(LIST, WINTER.Start + 10), WINTER, "second season")
		t.eq(Seasons.Active({}, HALLOWEEN.Start), nil, "no seasons")
	end,
	force_overrides_dates = function(t)
		t.eq(Seasons.Active(LIST, 0, "Halloween2026"), HALLOWEEN)
		t.eq(Seasons.Active(LIST, HALLOWEEN.Start, "Winter2026"), WINTER, "force wins over dates")
		t.eq(Seasons.Active(LIST, 0, "Nope"), nil, "unknown id is ignored")
		t.eq(Seasons.Active(LIST, HALLOWEEN.Start, "Nope"), HALLOWEEN, "falls back to dates")
	end,
	halloween_2026_dates = function(t)
		-- 2026-10-24 00:00 UTC to 2026-11-03 00:00 UTC: exactly 10 days
		t.eq(HALLOWEEN.End - HALLOWEEN.Start, 10 * 86400)
		t.eq(Seasons.LeftText(Seasons.SecondsLeft(HALLOWEEN, HALLOWEEN.Start + 3600)), "9 days left")
	end,
	left_text = function(t)
		t.eq(Seasons.LeftText(2 * 86400), "2 days left")
		t.eq(Seasons.LeftText(86400), "1 day left")
		t.eq(Seasons.LeftText(3 * 3600 + 5), "3 hours left")
		t.eq(Seasons.LeftText(3600), "1 hour left")
		t.eq(Seasons.LeftText(59), "ends soon")
		t.eq(Seasons.SecondsLeft(HALLOWEEN, HALLOWEEN.End + 50), 0, "never negative")
	end,
	limited_cosmetics_sold_only_in_season = function(t)
		local p = P.New()
		p.Coins = 100000
		local limited
		for _, d in Cosmetics.List do
			if d.Season == "Halloween2026" and d.Price > 0 then
				limited = d
				break
			end
		end
		t.ok(limited ~= nil, "Halloween has sold items")
		t.no(P.BuyCosmetic(p, limited.Id), "not on sale outside the season")
		t.no(P.BuyCosmetic(p, limited.Id, "Winter2026"), "not on sale in another season")
		t.eq(p.Coins, 100000, "nothing charged")
		t.ok(P.BuyCosmetic(p, limited.Id, "Halloween2026"))
		t.eq(p.Coins, 100000 - limited.Price)
		-- owned forever: survives a save round trip after the season
		local back = P.Reconcile(p)
		t.ok(back.Cosmetics[limited.Id], "kept after the season")
		t.ok(P.WearCosmetic(back, limited.Type, limited.Id), "still wearable")
		-- ordinary items don't care about seasons
		p.Coins = 1800
		t.ok(P.BuyCosmetic(p, "OutfitWoodsman"))
	end,
	earned_seasonal_title_never_sold = function(t)
		local earned
		for _, d in Cosmetics.List do
			if d.Season and d.Mastery then
				earned = d
			end
		end
		t.ok(earned ~= nil, "a seasonal title is earned")
		t.eq(earned.Price, 0, "never sold")
		t.eq(earned.Mastery.Stat, Seasons.StatKey(earned.Season))
		local p = P.New()
		p.Coins = 100000
		t.no(P.BuyCosmetic(p, earned.Id, earned.Season), "can't buy it even in season")
		p.Stats[earned.Mastery.Stat] = earned.Mastery.Need - 1
		t.eq(#P.GrantMasteryCosmetics(p), 0)
		p.Stats[earned.Mastery.Stat] = earned.Mastery.Need
		t.ok(table.find(P.GrantMasteryCosmetics(p), earned.Id) ~= nil, "granted at the goal")
		local back = P.Reconcile(p)
		t.ok(back.Cosmetics[earned.Id], "kept after reconcile")
	end,
}
