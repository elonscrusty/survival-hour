-- Daily streak, playtime gifts, quests and Index rewards.
local Rewards = require("../src/shared/Logic/Rewards")
local Profile = require("../src/shared/Logic/Profile")
local Economy = require("../src/shared/Logic/Economy")
local Config = require("../src/shared/Config")
local Pets = require("../src/shared/Pets")

local DAY = 86400
local NOW = 20000 * DAY + 3600 -- 01:00 UTC on day 20000

return {
	["day number is UTC based"] = function(t)
		t.eq(Rewards.DayNumber(NOW), 20000, "day")
		t.eq(Rewards.DayNumber(20001 * DAY - 1), 20000, "last second")
		t.eq(Rewards.DayNumber(20001 * DAY), 20001, "midnight")
	end,
	["daily claims once per day and builds a streak"] = function(t)
		local p = Profile.Default()
		p.Coins = 0
		local r, streak = Rewards.ClaimDaily(p, NOW)
		t.ok(r, "first claim")
		t.eq(streak, 1, "streak 1")
		t.eq(r.Coins, Config.DailyRewards[1].Coins, "day 1 coins")
		t.eq(p.Coins, Config.DailyRewards[1].Coins, "credited")
		t.no(Rewards.ClaimDaily(p, NOW + 3600), "same day")
		t.no(Rewards.DailyStatus(p, 20000).CanClaim, "status says no")
		local _, s2 = Rewards.ClaimDaily(p, NOW + DAY)
		t.eq(s2, 2, "next day streak 2")
		t.eq(Rewards.DailyStatus(p, 20002).CanClaim, true, "can claim next day")
	end,
	["missing a day resets the streak"] = function(t)
		local p = Profile.Default()
		Rewards.ClaimDaily(p, NOW)
		Rewards.ClaimDaily(p, NOW + DAY)
		t.eq(Rewards.EffectiveStreak(p, 20002), 2, "still alive next day")
		t.eq(Rewards.EffectiveStreak(p, 20003), 0, "missed a day")
		local _, s = Rewards.ClaimDaily(p, NOW + 3 * DAY)
		t.eq(s, 1, "reset")
	end,
	["streak rewards loop and give the boost"] = function(t)
		local n = #Config.DailyRewards
		t.eq(Rewards.DailySpec(n + 1), Config.DailyRewards[1], "loops")
		t.eq(Rewards.DailySpec(0), Config.DailyRewards[1], "0 treated as 1")
		local p = Profile.Default()
		for d = 0, n - 1 do
			Rewards.ClaimDaily(p, NOW + d * DAY)
		end
		t.eq(p.Daily.Streak, n, "full week")
		t.ok(Economy.BoostActive(p, "Luck2x", NOW + (n - 1) * DAY), "boost from day 7")
	end,
	["clock going backwards can't double claim"] = function(t)
		local p = Profile.Default()
		Rewards.ClaimDaily(p, NOW + 5 * DAY)
		t.no(Rewards.ClaimDaily(p, NOW), "earlier day refused")
	end,
	["playtime gifts need minutes played today and claim once per day"] = function(t)
		local p = Profile.Default()
		p.Gems = 0
		Rewards.AddPlaytime(p, 7 * 60, NOW)
		t.no(Rewards.ClaimPlaytime(p, 2, NOW), "8 minutes needed")
		Rewards.AddPlaytime(p, 60, NOW + 60)
		t.eq(Rewards.PlaytimeMinutes(p, NOW), 8, "8 minutes")
		local r = Rewards.ClaimPlaytime(p, 2, NOW)
		t.ok(r, "ok")
		t.eq(p.Gems, Config.PlaytimeGifts[2].Gems, "gems")
		t.no(Rewards.ClaimPlaytime(p, 2, NOW), "double claim")
		t.no(Rewards.ClaimPlaytime(p, 0, NOW), "index 0")
		t.no(Rewards.ClaimPlaytime(p, #Config.PlaytimeGifts + 1, NOW), "too high")
		t.no(Rewards.ClaimPlaytime(p, 1.5, NOW), "fraction")
	end,
	["playtime survives rejoining and resets the next UTC day"] = function(t)
		local p = Profile.Default()
		Rewards.AddPlaytime(p, 5 * 60, NOW)
		Rewards.ClaimPlaytime(p, 1, NOW)
		-- Rejoin (profile saved and loaded): minutes and claims are kept.
		local q = Profile.Sanitize(p)
		t.eq(Rewards.PlaytimeMinutes(q, NOW + 10), 5, "minutes kept")
		t.no(Rewards.ClaimPlaytime(q, 1, NOW + 10), "claim kept: no re-claim by rejoining")
		Rewards.AddPlaytime(q, 4 * 60, NOW + 20)
		t.ok(Rewards.ClaimPlaytime(q, 2, NOW + 20), "minutes add up across sessions")
		-- Next day: fresh minutes and claims.
		t.eq(Rewards.PlaytimeMinutes(q, NOW + DAY), 0, "new day starts at 0")
		Rewards.AddPlaytime(q, 3 * 60, NOW + DAY)
		t.ok(Rewards.ClaimPlaytime(q, 1, NOW + DAY), "claimable again tomorrow")
	end,
	["playtime ignores bad or huge time steps"] = function(t)
		local p = Profile.Default()
		for _, bad in { -60, 0 / 0, math.huge, -math.huge } do
			Rewards.AddPlaytime(p, bad, NOW)
		end
		t.eq(Rewards.PlaytimeMinutes(p, NOW), 0, "nothing added")
		Rewards.AddPlaytime(p, 10 * 3600, NOW)
		t.eq(Rewards.PlaytimeMinutes(p, NOW), 60, "one call adds at most an hour")
		for _ = 1, 40 do
			Rewards.AddPlaytime(p, 3600, NOW)
		end
		t.eq(Rewards.PlaytimeMinutes(p, NOW), 24 * 60, "capped at a day")
		local q = Profile.Sanitize({ Playtime = { Day = 5, Minutes = 1e9, Claimed = { ["1"] = true, ["99"] = true } } })
		t.eq(q.Playtime.Minutes, 24 * 60, "sanitised minutes")
		t.eq(q.Playtime.Claimed["99"], nil, "unknown gift dropped")
	end,
	["coins quest goals scale with the highest opened island"] = function(t)
		local p = Profile.Default()
		local function coinsGoal(q)
			for _, quest in q.Quests.List do
				if quest.Kind == "Coins" then
					return quest.Goal
				end
			end
			return nil
		end
		-- Find a day with a Coins quest.
		local day
		for d = 20000, 20200 do
			for _, q in Rewards.GenerateQuests(d) do
				if q.Kind == "Coins" then
					day = d
				end
			end
			if day then
				break
			end
		end
		t.ok(day, "some day has a coins quest")
		local base = nil
		for _, q in Rewards.GenerateQuests(day) do
			if q.Kind == "Coins" then
				base = q.Goal
			end
		end
		Rewards.EnsureQuests(p, day)
		t.eq(coinsGoal(p), base, "meadow: listed goal")
		local p2 = Profile.Default()
		p2.Areas.Grove = true
		p2.Areas.Frost = true
		Rewards.EnsureQuests(p2, day)
		t.eq(coinsGoal(p2), base * 64, "frost: x64")
		-- Fixed once generated, even if the player opens more islands.
		p2.Areas.Coral = true
		Rewards.EnsureQuests(p2, day)
		t.eq(coinsGoal(p2), base * 64, "goal fixed for the day")
	end,

	["quests are the same for everyone on a day"] = function(t)
		local a = Rewards.GenerateQuests(20000)
		local b = Rewards.GenerateQuests(20000)
		t.eq(#a, Config.QuestsPerDay, "count")
		local kinds = {}
		for i, q in a do
			t.eq(q.Kind, b[i].Kind, "kind")
			t.eq(q.Goal, b[i].Goal, "goal")
			t.no(kinds[q.Kind], "distinct kinds")
			kinds[q.Kind] = true
			t.eq(q.Progress, 0, "fresh")
		end
		local differs = false
		for d = 20001, 20010 do
			local c = Rewards.GenerateQuests(d)
			for i, q in c do
				if q.Kind ~= a[i].Kind or q.Goal ~= a[i].Goal then
					differs = true
				end
			end
		end
		t.ok(differs, "other days differ")
	end,
	["quest progress, claim and daily reset"] = function(t)
		local p = Profile.Default()
		Rewards.EnsureQuests(p, 20000)
		local q = p.Quests.List[1]
		t.no(Rewards.ClaimQuest(p, 1, NOW), "not done")
		t.no(Rewards.AddQuestProgress(p, q.Kind, -5, NOW), "negative ignored")
		t.no(Rewards.AddQuestProgress(p, q.Kind, 0 / 0, NOW), "nan ignored")
		Rewards.AddQuestProgress(p, q.Kind, q.Goal * 10, NOW)
		t.eq(q.Progress, q.Goal, "capped at goal")
		local gems = p.Gems
		t.ok(Rewards.ClaimQuest(p, 1, NOW), "claimed")
		t.eq(p.Gems, gems + q.Gems, "gems")
		t.no(Rewards.ClaimQuest(p, 1, NOW), "double claim")
		t.no(Rewards.AddQuestProgress(p, q.Kind, 1, NOW), "no progress after claim")
		t.no(Rewards.ClaimQuest(p, 0, NOW), "bad index")
		t.no(Rewards.ClaimQuest(p, 99, NOW), "bad index high")
		-- Next day: new quests replace the old ones.
		Rewards.AddQuestProgress(p, "Hatch", 1, NOW + DAY)
		t.eq(p.Quests.Day, 20001, "rolled over")
		for _, nq in p.Quests.List do
			t.no(nq.Claimed, "fresh quests")
		end
	end,
	["index tiers need enough species and claim once"] = function(t)
		local p = Profile.Default()
		t.no(Rewards.ClaimIndex(p, 1, NOW), "nothing found")
		local need = math.ceil(Config.IndexRewards[1].Fraction * #Pets.List)
		for i = 1, need - 1 do
			p.Index[Pets.List[i].Id] = true
		end
		t.no(Rewards.ClaimIndex(p, 1, NOW), "one short")
		p.Index[Pets.List[need].Id] = true
		p.Index.NotARealPet = true
		local r = Rewards.ClaimIndex(p, 1, NOW)
		t.ok(r, "claimed")
		t.eq(p.ExtraEquip, Config.IndexRewards[1].Equip, "equip bonus")
		t.no(Rewards.ClaimIndex(p, 1, NOW), "double claim")
		t.no(Rewards.ClaimIndex(p, 5, NOW), "bad tier")
		for _, def in Pets.List do
			p.Index[def.Id] = true
		end
		t.eq(Rewards.IndexFraction(p), 1, "complete (fake ids ignored)")
		t.ok(Rewards.ClaimIndex(p, 4, NOW), "100% tier")
		t.ok(Rewards.ClaimIndex(p, 3, NOW), "storage tier")
		t.eq(p.ExtraStorage, Config.IndexRewards[3].Storage, "storage bonus")
	end,
}
