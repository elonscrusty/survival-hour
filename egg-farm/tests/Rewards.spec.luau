-- Quests, daily rewards and gifts: server-day timing and one-time claims.
local H = require("./Helpers")
local RewardData = require("../src/shared/Data/Rewards")
local Rewards = require("../src/shared/Logic/Rewards")

local DAY = 86400

return {
	quest_claim_needs_progress_and_pays_once = function(t)
		local f, s = H.Farm()
		local day = Rewards.Day(H.T0)
		local q = Rewards.QuestsForDay(day)[1]
		t.eq(f:Apply({ type = "claimQuest", id = q.id }, H.T0).code, "not_ready")
		Rewards.RollDay(s, H.T0)
		Rewards.Track(s, q.stat, q.target)
		local goldBefore = s.gold
		t.ok(f:Apply({ type = "claimQuest", id = q.id }, H.T0).ok)
		t.eq(f:Apply({ type = "claimQuest", id = q.id }, H.T0).code, "already")
		t.ok(s.gold >= goldBefore)
	end,

	quest_not_offered_today_is_invalid = function(t)
		local f = H.Farm()
		local day = Rewards.Day(H.T0)
		local today = {}
		for _, q in Rewards.QuestsForDay(day) do
			today[q.id] = true
		end
		for _, q in RewardData.QuestPool do
			if not today[q.id] then
				t.eq(f:Apply({ type = "claimQuest", id = q.id }, H.T0).code, "invalid")
				return
			end
		end
	end,

	quests_reset_on_new_utc_day = function(t)
		local f, s = H.Farm()
		Rewards.RollDay(s, H.T0)
		Rewards.Track(s, "spawned", 5000)
		t.eq(s.quests.progress.spawned, 5000)
		f:Step(1, H.T0 + DAY)
		t.eq(s.quests.progress.spawned, nil, "progress cleared on the next day")
		t.eq(s.stats.spawned, 5000, "lifetime stat kept")
	end,

	daily_claims_once_per_day_and_streaks = function(t)
		local f, s = H.Farm()
		t.ok(f:Apply({ type = "claimDaily" }, H.T0).ok)
		t.eq(s.daily.streak, 1)
		t.eq(f:Apply({ type = "claimDaily" }, H.T0 + 60).code, "already")
		t.ok(f:Apply({ type = "claimDaily" }, H.T0 + DAY).ok)
		t.eq(s.daily.streak, 2)
		-- miss a day: streak restarts
		t.ok(f:Apply({ type = "claimDaily" }, H.T0 + 3 * DAY).ok)
		t.eq(s.daily.streak, 1)
	end,

	daily_day7_repeats = function(t)
		local f, s = H.Farm()
		for d = 0, 9 do
			t.ok(f:Apply({ type = "claimDaily" }, H.T0 + d * DAY).ok)
		end
		t.eq(s.daily.streak, 10)
		t.eq(Rewards.DailyNextDay(s, H.T0 + 10 * DAY), 7)
	end,

	daily_ignores_client_clock = function(t)
		local f, s = H.Farm()
		t.ok(f:Apply({ type = "claimDaily", now = H.T0 + 99 * DAY, day = 999 }, H.T0).ok)
		t.eq(f:Apply({ type = "claimDaily", now = H.T0 + 99 * DAY }, H.T0 + 10).code, "already")
		t.eq(s.daily.lastDay, Rewards.Day(H.T0))
	end,

	gifts_unlock_with_server_playtime = function(t)
		local f, s = H.Farm()
		t.eq(f:Apply({ type = "claimGift", index = 1 }, H.T0).code, "not_ready")
		f:Step(3 * 60, H.T0 + 180)
		t.ok(f:Apply({ type = "claimGift", index = 1 }, H.T0 + 180).ok)
		t.eq(f:Apply({ type = "claimGift", index = 1 }, H.T0 + 180).code, "already")
		f:Step(22 * 60, H.T0 + 1500)
		local gold = s.gold
		t.ok(f:Apply({ type = "claimAllGifts" }, H.T0 + 1500).ok)
		t.ok(s.gifts.claimed["2"] and s.gifts.claimed["3"] and s.gifts.claimed["4"], "claim all took every ready gift")
		t.no(s.gifts.claimed["5"], "not ready yet")
		t.ok(s.gold > gold)
		t.eq(f:Apply({ type = "claimAllGifts" }, H.T0 + 1500).code, "not_ready")
	end,

	gold_pass_doubles_earned_gold = function(t)
		local f, s = H.Farm(function(s)
			s.passes.x2gold = true
		end)
		t.ok(f:Apply({ type = "claimDaily" }, H.T0).ok)
		t.eq(s.gold, RewardData.Daily[1].gold * 2)
	end,

	cash_rewards_scale_with_farm = function(t)
		local _, s = H.Farm()
		t.eq(Rewards.CashFor(s, 10, H.T0), 100, "floor on an empty farm")
		s.population = 100
		t.ok(Rewards.CashFor(s, 10, H.T0) >= 100)
	end,
}
