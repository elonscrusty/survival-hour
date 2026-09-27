local P = require("../src/shared/Logic/ProfileRules")

return {
	receipt_idempotent = function(t)
		local p = P.New()
		local prod = { Kind = "Diamonds", Amount = 100 }
		t.eq((P.ApplyReceipt(p, "r1", prod, 200)), "Granted")
		t.eq((P.ApplyReceipt(p, "r1", prod, 200)), "AlreadyGranted")
		t.eq(p.Diamonds, 100, "granted once")
	end,
	receipt_replay_after_reload = function(t)
		local p = P.New()
		P.ApplyReceipt(p, "r9", { Kind = "Revive", Tier = 2 }, 200)
		-- simulate save + load round trip
		local reloaded = P.Reconcile(table.clone(p))
		t.eq((P.ApplyReceipt(reloaded, "r9", { Kind = "Revive", Tier = 2 }, 200)), "AlreadyGranted")
		t.eq(reloaded.Credits.Revive["2"], 1)
	end,
	receipt_memory_bounded = function(t)
		local p = P.New()
		for i = 1, 250 do
			P.ApplyReceipt(p, "r" .. i, { Kind = "Bandage", Amount = 1 }, 200)
		end
		t.eq(#p.Receipts, 200)
		t.eq(p.Credits.Bandage, 250)
	end,
	unlock_when_owned_refunds = function(t)
		local p = P.New()
		P.ApplyReceipt(p, "a", { Kind = "Unlock", Powerup = "Hunter", Level = 1 }, 200)
		t.eq(p.Owned.Hunter, 1)
		P.ApplyReceipt(p, "b", { Kind = "Unlock", Powerup = "Hunter", Level = 1 }, 200)
		t.eq(p.Diamonds, 150, "duplicate unlock converted to diamonds, not lost")
	end,
	upgrade_skip_challenge = function(t)
		local p = P.New()
		p.Owned.Climber = 1
		P.ApplyReceipt(p, "u2", { Kind = "Upgrade", Powerup = "Climber", Level = 2 }, 200)
		t.eq(p.Owned.Climber, 2)
		-- out of order: level 2 bought again
		P.ApplyReceipt(p, "u2b", { Kind = "Upgrade", Powerup = "Climber", Level = 2 }, 200)
		t.eq(p.Owned.Climber, 2)
		t.eq(p.Diamonds, 160, "refund = L2 price")
	end,
	diamond_unlock_and_upgrade = function(t)
		local p = P.New()
		p.Diamonds = 100
		t.ok(P.BuyUnlock(p, "Trailblazer"))
		t.eq(p.Diamonds, 0)
		local ok, why = P.BuyUpgrade(p, "Trailblazer")
		t.no(ok)
		t.eq(why, "Challenge not complete")
		p.Stats.DistanceTravelled = 8000
		p.Diamonds = 79
		ok, why = P.BuyUpgrade(p, "Trailblazer")
		t.eq(why, "Not enough diamonds")
		p.Diamonds = 80
		t.ok(P.BuyUpgrade(p, "Trailblazer"))
		t.eq(p.Owned.Trailblazer, 2)
	end,
	win_reward_once = function(t)
		local p = P.New()
		t.ok(P.AwardWin(p, "m1", 10, 40))
		t.no(P.AwardWin(p, "m1", 10, 40))
		t.eq(p.Diamonds, 10)
		t.eq(p.Wins, 1)
	end,
	reconcile_garbage = function(t)
		local p = P.Reconcile({ Diamonds = -5, Owned = { Fake = 3, Hunter = 9 }, Equipped = "Fake" })
		t.eq(p.Diamonds, 0)
		t.eq(p.Owned.Fake, nil)
		t.eq(p.Owned.Hunter, 3, "clamped")
		t.eq(p.Equipped, nil)
		local q = P.Reconcile(nil)
		t.eq(q.Version, 1)
	end,
	equip_requires_ownership = function(t)
		local p = P.New()
		t.no(P.Equip(p, "Hunter"))
		p.Owned.Hunter = 1
		t.ok(P.Equip(p, "Hunter"))
	end,
	consume_credit = function(t)
		local p = P.New()
		P.ApplyReceipt(p, "x", { Kind = "Revive", Tier = 3 }, 200)
		t.no(P.ConsumeReviveCredit(p, 2))
		t.ok(P.ConsumeReviveCredit(p, 3))
		t.no(P.ConsumeReviveCredit(p, 3))
	end,
}
