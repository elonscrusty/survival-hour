local C = require("../src/shared/Logic/ChallengeRules")

return {
	same_wall_counts_once = function(t)
		local tr = C.NewTracker()
		t.eq(C.Accept(tr, "EnemyWallsScaled", 1, "wall7"), 1)
		t.eq(C.Accept(tr, "EnemyWallsScaled", 1, "wall7"), 0)
		t.eq(C.Accept(tr, "EnemyWallsScaled", 1, "wall8"), 1)
	end,
	per_match_cap = function(t)
		local tr = C.NewTracker()
		local total = 0
		for i = 1, 50 do
			total += C.Accept(tr, "CratesOpened", 1, "crate" .. i)
		end
		t.eq(total, 8, "Scavenger cap per match")
	end,
	arrow_victim_limit = function(t)
		local tr = C.NewTracker()
		local total = 0
		for _ = 1, 20 do
			total += C.Accept(tr, "LongArrowHits", 1, "victim1")
		end
		t.eq(total, 5, "one teammate/enemy cannot be farmed")
	end,
	teleport_not_travel = function(t)
		local tr = C.NewTracker()
		t.eq(C.Accept(tr, "DistanceTravelled", 400, nil, 1), 0, "400 studs in 1s rejected")
		t.eq(C.Accept(tr, "DistanceTravelled", 16, nil, 1), 16)
	end,
	missing_target_rejected = function(t)
		local tr = C.NewTracker()
		t.eq(C.Accept(tr, "AnimalsKilled", 1, nil), 0)
	end,
	unknown_stat = function(t)
		t.eq(C.Accept(C.NewTracker(), "Nope", 5, "x"), 0)
	end,
	relevance = function(t)
		t.ok(C.StatRelevant({ Hunter = 1 }, "AnimalsKilled"))
		t.no(C.StatRelevant({ Hunter = 3 }, "AnimalsKilled"), "maxed powerup stops tracking")
		t.no(C.StatRelevant({}, "AnimalsKilled"))
	end,
}
