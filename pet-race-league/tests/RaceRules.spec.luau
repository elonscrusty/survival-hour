local RaceRules = require("../src/shared/Logic/RaceRules")
local Config = require("../src/shared/Config")

return {
	order_finishers_then_progress = function(t)
		local o = RaceRules.Order({
			{ Id = 1, Finished = false, Progress = 300 },
			{ Id = 2, Finished = true, Time = 40, Progress = 500 },
			{ Id = 3, Finished = true, Time = 35, Progress = 500 },
			{ Id = 4, Finished = false, Progress = 400 },
		})
		t.eq(o[1].Id, 3)
		t.eq(o[2].Id, 2)
		t.eq(o[3].Id, 4)
		t.eq(o[4].Id, 1)
	end,
	medals = function(t)
		local m = RaceRules.MedalTimes(680)
		t.ok(m.Gold < m.Silver and m.Silver < m.Bronze)
		t.eq(RaceRules.Medal(680, m.Gold), "Gold")
		t.eq(RaceRules.Medal(680, m.Silver), "Silver")
		t.eq(RaceRules.Medal(680, m.Bronze + 0.01), nil)
		t.eq(RaceRules.Medal(680, nil), nil)
	end,
	rewards_never_negative = function(t)
		for count = 1, 8 do
			for place = 1, count do
				for _, finished in { true, false } do
					local c, tr = RaceRules.Rewards(place, count, finished, if finished then "Gold" else nil)
					t.ok(c > 0 and tr >= 0)
				end
			end
		end
	end,
	solo_trophies_capped = function(t)
		local _, tr = RaceRules.Rewards(1, 1, true, "Gold")
		t.ok(tr <= Config.Race.SoloTrophyCap)
		local _, none = RaceRules.Rewards(1, 1, true, nil)
		t.eq(none, 0)
	end,
	winning_bigger_race_pays_more = function(t)
		local _, two = RaceRules.Rewards(1, 2, true, nil)
		local _, eight = RaceRules.Rewards(1, 8, true, nil)
		t.ok(eight > two)
		local c1 = RaceRules.Rewards(1, 4, true, nil)
		local c4 = RaceRules.Rewards(4, 4, true, nil)
		t.ok(c1 > c4)
	end,
	dnf_gets_little = function(t)
		local c, tr = RaceRules.Rewards(5, 5, false, nil)
		t.eq(c, Config.Race.DnfCoins)
		t.eq(tr, 0)
	end,
	plausible = function(t)
		t.ok(RaceRules.Plausible(60, 2, 30))
		t.ok(not RaceRules.Plausible(500, 3, 20), "teleporting 500 studs in 3s")
		t.ok(RaceRules.BurstOk(40, 1, 20))
		t.ok(not RaceRules.BurstOk(200, 1, 20))
	end,
	gold_reachable_legitimately = function(t)
		-- the gold average speed must be allowed for a well-trained (not maxed) pet
		local R = Config.Ride
		local walk = R.BaseSpeed + 30 * R.SpeedPerLevel
		t.ok(walk * Config.Race.SustainMult > Config.Race.MedalSpeeds.Gold)
	end,
	teleport_cheat_cannot_win_gold = function(t)
		-- An untrained Pup (walk 20) can't be credited with the finish line faster
		-- than the gold time on any track.
		local Tracks = require("../src/shared/Tracks")
		local TrackLayout = require("../src/shared/Logic/TrackLayout")
		for _, tr in Tracks.List do
			local l = TrackLayout.Build(tr.Segments)
			local gold = RaceRules.MedalTimes(l.Length).Gold
			t.ok(not RaceRules.Plausible(l.Length, gold, Config.Ride.BaseSpeed), tr.Id)
		end
	end,
	leagues = function(t)
		local i, l = RaceRules.League(0)
		t.eq(i, 1)
		t.eq(l.Name, "Bronze")
		local _, l2 = RaceRules.League(100)
		t.eq(l2.Name, "Silver")
		local _, top = RaceRules.League(99999)
		t.eq(top.Name, "Champion")
	end,
	place_text = function(t)
		t.eq(RaceRules.PlaceText(1), "1st")
		t.eq(RaceRules.PlaceText(2), "2nd")
		t.eq(RaceRules.PlaceText(3), "3rd")
		t.eq(RaceRules.PlaceText(4), "4th")
		t.eq(RaceRules.PlaceText(11), "11th")
		t.eq(RaceRules.PlaceText(22), "22nd")
	end,
	format_time = function(t)
		t.eq(RaceRules.FormatTime(65.5), "1:05.50")
		t.eq(RaceRules.FormatTime(9.25), "0:09.25")
	end,
}
