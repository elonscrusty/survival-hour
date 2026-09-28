local Director = require("../src/shared/Logic/Director")

local function snap(over)
	local s = { MatchAge = 600, Night = false, Remaining = 4, Started = 4, Spread = 0.2, QuietFor = 120, SinceWildlifeFight = 300, RecentEvents = 0, PoisExplored = 0.2 }
	for k, v in over or {} do
		s[k] = v
	end
	return s
end

return {
	steady_by_default = function(t)
		local p = Director.Plan(snap())
		t.eq(p.GapMult, 1)
		t.eq(p.CacheFocus, nil)
		t.no(p.Opportunity)
	end,
	busy_match_breathes = function(t)
		t.eq(Director.Plan(snap({ RecentEvents = 2 })).GapMult, 1.4)
		t.eq(Director.Plan(snap({ QuietFor = 20 })).GapMult, 1.4)
	end,
	quiet_match_speeds_up = function(t)
		local p = Director.Plan(snap({ QuietFor = 300 }))
		t.eq(p.GapMult, 0.5)
		t.ok((p.Weights.SurvivorCache or 1) > 1)
	end,
	spread_out_players_get_a_cache_between_them = function(t)
		t.eq(Director.Plan(snap({ QuietFor = 300, Spread = 0.6 })).CacheFocus, "Between")
	end,
	late_standoff_pulls_to_centre_by_day_only = function(t)
		local day = Director.Plan(snap({ Remaining = 2, QuietFor = 250 }))
		t.eq(day.CacheFocus, "Centre")
		t.ok(day.Opportunity)
		t.no(Director.Plan(snap({ Remaining = 2, QuietFor = 250, Night = true })).Opportunity)
	end,
	no_surge_right_after_a_fight = function(t)
		t.ok(Director.Plan(snap({ SinceWildlifeFight = 30 })).Weights.PredatorSurge < 1)
	end,
	never_boosts_surges = function(t)
		for _, q in { 10, 100, 300 } do
			for _, r in { 1, 2, 4 } do
				t.ok((Director.Plan(snap({ QuietFor = q, Remaining = r })).Weights.PredatorSurge or 1) <= 1)
			end
		end
	end,
	spread_math = function(t)
		t.eq(Director.Spread({ { X = 0, Z = 0 }, { X = 100, Z = 0 } }, 200), 0.5)
		t.eq(Director.Spread({ { X = 0, Z = 0 } }, 200), 0)
	end,
}
