local L = require("../src/shared/Logic/LivesRules")

return {
	three_free_respawns_then_window = function(t)
		local life = L.New(3)
		for i = 1, 3 do
			t.eq(L.OnDeath(life, true, 0, 20), "Respawn", "death " .. i)
			life.State = "Alive"
		end
		t.eq(life.FreeRespawns, 0)
		t.eq(L.OnDeath(life, true, 100, 20), "ReviveWindow")
		t.eq(life.WindowEndsAt, 120)
	end,
	fire_out_eliminates = function(t)
		local life = L.New(3)
		t.eq(L.OnDeath(life, false, 0, 20), "Eliminate")
		t.eq(life.State, "Eliminated")
		t.eq(life.FreeRespawns, 3, "no respawn spent")
	end,
	fire_out_during_respawn = function(t)
		local life = L.New(3)
		L.OnDeath(life, true, 0, 20)
		t.ok(L.OnFireOut(life), "respawning player eliminated")
		t.eq(life.State, "Eliminated")
	end,
	fire_out_during_window = function(t)
		local life = L.New(0)
		L.OnDeath(life, true, 0, 20)
		t.ok(L.OnFireOut(life))
		t.no(L.ApplyRevive(life, 4, false, 1, 4), "cannot revive after fire out")
	end,
	window_expires = function(t)
		local life = L.New(0)
		L.OnDeath(life, true, 0, 20)
		t.no(L.Tick(life, 19.9))
		t.ok(L.Tick(life, 20))
		t.eq(life.State, "Eliminated")
		t.no(L.ApplyRevive(life, 1, true, 21, 4), "late receipt does not revive")
	end,
	tiers_escalate_regardless_of_payer = function(t)
		local life = L.New(0)
		for expected = 1, 5 do
			L.OnDeath(life, true, 0, 20)
			local tier = L.ReviveTier(life, 4)
			t.eq(tier, math.min(expected, 4), "tier")
			t.ok(L.ApplyRevive(life, tier, true, 1, 4))
			life.State = "Alive"
		end
		t.eq(life.PaidRevives, 5)
	end,
	underpaid_tier_rejected = function(t)
		local life = L.New(0)
		life.PaidRevives = 2
		L.OnDeath(life, true, 0, 20)
		t.no(L.ApplyRevive(life, 1, true, 1, 4), "tier 1 cannot pay for tier 3")
		t.ok(L.ApplyRevive(life, 4, true, 1, 4), "higher tier accepted")
	end,
	purchase_lock = function(t)
		local life = L.New(0)
		L.OnDeath(life, true, 0, 20)
		t.ok(L.CanStartRevive(life, true, 1, 111))
		L.Lock(life, 111, 1, 30)
		local ok, why = L.CanStartRevive(life, true, 2, 222)
		t.no(ok)
		t.eq(why, "Another teammate is already paying")
		t.ok(L.CanStartRevive(life, true, 2, 111), "same payer may retry")
		L.Unlock(life, 111)
		t.ok(L.CanStartRevive(life, true, 3, 222))
	end,
	pending_prompt_does_not_extend_window = function(t)
		local life = L.New(0)
		L.OnDeath(life, true, 0, 20)
		L.Lock(life, 5, 19, 30) -- lock extends past window
		t.ok(L.Tick(life, 20), "window still ends")
	end,
	credits_lowest_usable = function(t)
		t.eq(L.FindCredit({ ["1"] = 1, ["3"] = 2 }, 2, 4), 3)
		t.eq(L.FindCredit({ ["1"] = 1 }, 2, 4), nil)
		t.eq(L.FindCredit({ ["2"] = 0, ["4"] = 1 }, 1, 4), 4)
	end,
	outcome = function(t)
		t.eq((L.Outcome({ true, false, false, false }, { 1, 2, 3, 4 }, false)), "Winner")
		t.eq((L.Outcome({ true, true, false, false }, { 1, 2, 3, 4 }, false)), "Continue")
		t.eq((L.Outcome({ false, false, false, false }, { 1, 2, 3, 4 }, false)), "NoTeams")
		t.eq((L.Outcome({ true }, { 1 }, true)), "Continue", "studio single team")
	end,
	team_standing = function(t)
		local a, b = L.New(0), L.New(0)
		a.State = "Eliminated"
		b.State = "AwaitingRevive"
		t.ok(L.TeamStanding({ a, b }), "window keeps team (bounded)")
		b.State = "Eliminated"
		t.no(L.TeamStanding({ a, b }))
	end,
	unlimited_respawns_while_burning = function(t)
		local life = L.New(math.huge)
		for i = 1, 50 do
			t.eq(L.OnDeath(life, true, 0, 20), "Respawn", "death " .. i)
			life.State = "Alive"
		end
		t.ok(L.Unlimited(life))
		t.eq(L.OnDeath(life, false, 0, 20), "Eliminate", "fire out = final life")
	end,
	respawn_delay_escalates = function(t)
		local life = L.New(math.huge)
		local seen = {}
		for _ = 1, 6 do
			L.OnDeath(life, true, 0, 20)
			table.insert(seen, L.RespawnDelay(life, { 8, 12, 16, 20 }))
			life.State = "Alive"
		end
		t.eq(table.concat(seen, ","), "8,12,16,20,20,20")
	end,
}
