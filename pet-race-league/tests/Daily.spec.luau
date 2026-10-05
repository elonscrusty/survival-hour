local Daily = require("../src/shared/Logic/Daily")
local Profile = require("../src/shared/Logic/Profile")
local Config = require("../src/shared/Config")

return {
	pick_three_distinct_valid = function(t)
		for day = 0, 60 do
			local q = Daily.Pick(day)
			t.eq(#q, Daily.PerDay)
			t.ok(q[1] ~= q[2] and q[2] ~= q[3] and q[1] ~= q[3])
			for _, id in q do
				t.ok(Daily.ById[id] ~= nil)
			end
		end
	end,
	picks_vary_by_day = function(t)
		t.ok(table.concat(Daily.Pick(1)) ~= table.concat(Daily.Pick(2)))
	end,
	streak_grows_and_resets = function(t)
		local s = Daily.New()
		Daily.Rollover(s, 100, {})
		t.eq(s.Streak, 1)
		Daily.Rollover(s, 101, {})
		t.eq(s.Streak, 2)
		t.ok(not Daily.Rollover(s, 101, {}), "same day is no rollover")
		Daily.Rollover(s, 105, {})
		t.eq(s.Streak, 1, "missed days reset")
	end,
	login_claim_once = function(t)
		local s = Daily.New()
		t.eq(Daily.Claim(s, {}, "Login"), 0, "nothing before the first day")
		Daily.Rollover(s, 10, {})
		t.eq(Daily.Claim(s, {}, "Login"), Daily.LoginCoins[1])
		t.eq(Daily.Claim(s, {}, "Login"), 0)
		t.eq(Daily.LoginReward(99), Daily.LoginCoins[#Daily.LoginCoins])
	end,
	quest_progress_from_snapshot = function(t)
		local s = Daily.New()
		local stats = { Races = 10, Hatches = 4, Medals = 1, Golds = 0, Gates = 50, Hurdles = 3, TrainXp = 400 }
		Daily.Rollover(s, 7, stats)
		local id = s.Quests[1]
		local q = Daily.ById[id]
		t.eq(Daily.Progress(s, stats, id), 0)
		t.eq(Daily.Claim(s, stats, id), 0, "not done yet")
		stats[q.Stat] += q.Need
		t.eq(Daily.Progress(s, stats, id), q.Need)
		t.ok(Daily.HasClaimable(s, stats))
		t.eq(Daily.Claim(s, stats, id), q.Coins)
		t.eq(Daily.Claim(s, stats, id), 0, "only once")
	end,
	foreign_quest_rejected = function(t)
		local s = Daily.New()
		Daily.Rollover(s, 7, {})
		for _, q in Daily.Quests do
			if not table.find(s.Quests, q.Id) then
				t.eq(Daily.Claim(s, { [q.Stat] = 1e6 }, q.Id), 0)
			end
		end
	end,
	codes_once_and_case_insensitive = function(t)
		local d = Profile.Default()
		local coins = Profile.Redeem(d, " launch ", Config.Codes)
		t.eq(coins, Config.Codes.LAUNCH.Coins)
		local again, err = Profile.Redeem(d, "LAUNCH", Config.Codes)
		t.eq(again, nil)
		t.ok(err ~= nil)
		t.eq(Profile.Redeem(d, "NOPE", Config.Codes), nil)
	end,
	daily_survives_save = function(t)
		local d = Profile.Default()
		Daily.Rollover(d.Daily, 50, d.Stats)
		d.Codes.ZOOM = true
		local back = Profile.Sanitize(d)
		t.eq(back.Daily.Day, 50)
		t.eq(#back.Daily.Quests, 3)
		t.eq(back.Codes.ZOOM, true)
	end,
}
