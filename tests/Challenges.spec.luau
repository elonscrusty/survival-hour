local Challenges = require("../src/shared/Logic/Challenges")

local function profile(stats, wins)
	return { Stats = stats or {}, Wins = wins or 0, Matches = 0, Kills = 0, Eliminations = 0 }
end

return {
	same_day_same_set = function(t)
		local a, b = Challenges.ForDay(20000), Challenges.ForDay(20000)
		t.eq(#a, 3)
		for i = 1, 3 do
			t.eq(a[i].Id, b[i].Id)
		end
	end,
	sets_are_distinct = function(t)
		local seen = {}
		for _, d in Challenges.ForDay(20001) do
			t.no(seen[d.Id])
			seen[d.Id] = true
		end
	end,
	progress_counts_from_the_snapshot = function(t)
		local p = profile({ Resources = 1000, Animals = 5, Pois = 9, Nights = 2, Crafts = 1, Chests = 0, DamageDealt = 50 })
		local s = Challenges.New()
		Challenges.Refresh(s, p, 20000, 3000)
		for _, v in Challenges.View(s, p) do
			t.eq(v.Progress, 0, v.Id)
		end
		p.Stats.Resources += 300
		p.Stats.Animals += 3
		p.Stats.Pois += 3
		p.Stats.Nights += 2
		p.Stats.Crafts += 5
		p.Stats.Chests += 4
		p.Stats.DamageDealt += 200
		p.Matches += 2
		for _, v in Challenges.View(s, p) do
			if not v.Weekly then
				t.eq(v.Progress, v.Need, v.Id)
			end
		end
	end,
	claim_once_and_only_when_done = function(t)
		local p = profile({})
		local s = Challenges.New()
		Challenges.Refresh(s, p, 20000, 3000)
		local first = Challenges.View(s, p)[1]
		t.eq(Challenges.Claim(s, p, first.Id), 0)
		if first.Id == "D_Play" then
			p.Matches += first.Need
		else
			p.Stats[Challenges.ById[first.Id].Stat] = first.Need
		end
		t.eq(Challenges.Claim(s, p, first.Id), first.Coins)
		t.eq(Challenges.Claim(s, p, first.Id), 0)
	end,
	new_day_resets_dailies_only = function(t)
		local p = profile({})
		local s = Challenges.New()
		Challenges.Refresh(s, p, 20000, 3000)
		s.WeekClaimed.X = true
		t.ok(Challenges.Refresh(s, p, 20001, 3000))
		t.ok(s.WeekClaimed.X)
		t.no(Challenges.Refresh(s, p, 20001, 3000))
	end,
	unknown_id_refused = function(t)
		local s = Challenges.New()
		Challenges.Refresh(s, profile({}), 1, 1)
		t.eq(Challenges.Claim(s, profile({}), "nope"), 0)
	end,
	reconcile_drops_junk = function(t)
		local s = Challenges.Reconcile({ Day = 5, DayBase = { A = 1, B = "x" }, DayClaimed = { A = true, B = 1 } })
		t.eq(s.Day, 5)
		t.eq(s.DayBase.A, 1)
		t.eq(s.DayBase.B, nil)
		t.eq(s.DayClaimed.B, nil)
		t.eq(s.Week, -1)
	end,
}
