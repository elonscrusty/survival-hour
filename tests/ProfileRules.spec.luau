local P = require("../src/shared/Logic/ProfileRules")
local Classes = require("../src/shared/Classes")
local Perks = require("../src/shared/Perks")
local Progression = require("../src/shared/Progression")

local DAY = 86400

return {
	new_player_defaults = function(t)
		local p = P.New()
		t.eq(p.Class, "Survivor", "free class equipped")
		t.ok(p.OwnedClasses.Survivor)
		t.eq(p.Perk, nil, "no power-up")
		t.eq(p.Level, 1)
		t.eq(p.Coins, 0)
		t.eq(p.Diamonds, 0)
	end,
	receipt_idempotent_coins = function(t)
		local p = P.New()
		local prod = { Kind = "Coins", Amount = 1200 }
		t.eq((P.ApplyReceipt(p, "r1", prod, 200)), "Granted")
		t.eq((P.ApplyReceipt(p, "r1", prod, 200)), "AlreadyGranted")
		t.eq(p.Coins, 1200, "granted once")
	end,
	receipt_replay_after_reload = function(t)
		local p = P.New()
		P.ApplyReceipt(p, "r9", { Kind = "Coins", Amount = 500 }, 200)
		local reloaded = P.Reconcile(table.clone(p))
		t.eq((P.ApplyReceipt(reloaded, "r9", { Kind = "Coins", Amount = 500 }, 200)), "AlreadyGranted")
		t.eq(reloaded.Coins, 500)
	end,
	receipt_memory_bounded = function(t)
		local p = P.New()
		for i = 1, 250 do
			P.ApplyReceipt(p, "r" .. i, { Kind = "Coins", Amount = 1 }, 200)
		end
		t.eq(#p.Receipts, 200)
		t.eq(p.Coins, 250)
	end,
	bundle_grants_and_refunds_duplicates = function(t)
		local p = P.New()
		p.Cosmetics.PlateMoss = true
		P.ApplyReceipt(p, "b1", { Kind = "Bundle", Bundle = "Founder" }, 200)
		t.ok(p.Cosmetics.OutfitRanger)
		t.ok(p.Cosmetics.TitleForager)
		t.eq(p.Coins, 4000, "owned Moss Nameplate refunded at its coin price")
	end,
	legacy_receipts_still_resolve = function(t)
		local p = P.New()
		P.ApplyReceipt(p, "d", { Kind = "Diamonds", Amount = 100 }, 200)
		P.ApplyReceipt(p, "u", { Kind = "Unlock", Powerup = "Hunter", Level = 1 }, 200)
		P.ApplyReceipt(p, "r", { Kind = "Revive", Tier = 2 }, 200)
		t.eq(p.Diamonds, 250, "legacy unlock refunded as diamonds")
		t.eq(p.Credits.Revive["2"], 1)
	end,
	v1_powerups_refunded = function(t)
		local p = P.Reconcile({ Version = 1, Diamonds = 10, Owned = { Hunter = 2, Fake = 3 }, Equipped = "Hunter" })
		-- Hunter 150: L1 150 + L2 120
		t.eq(p.Diamonds, 10 + 150 + 120)
		t.eq(p.Class, "Survivor")
		-- no double refund once migrated
		local again = P.Reconcile(table.clone(p))
		t.eq(again.Diamonds, p.Diamonds)
	end,
	reconcile_garbage = function(t)
		local p = P.Reconcile({ Diamonds = -5, Coins = "x", OwnedClasses = { Fake = true, Miner = true }, Class = "Fake", Perk = "Hardy", Wearing = { Title = "TitleApex" } })
		t.eq(p.Diamonds, 0)
		t.eq(p.Coins, 0)
		t.eq(p.OwnedClasses.Fake, nil)
		t.ok(p.OwnedClasses.Miner)
		t.eq(p.Class, "Survivor", "unknown class falls back")
		t.eq(p.Perk, nil, "unowned perk dropped")
		t.eq(p.Wearing.Title, nil, "unowned cosmetic not worn")
		t.eq(P.Reconcile(nil).Version, P.SchemaVersion)
	end,
	buy_and_equip_class = function(t)
		local p = P.New()
		local miner = Classes.ById.Miner
		p.Diamonds = miner.Price - 1
		local ok, why = P.BuyClass(p, "Miner")
		t.no(ok)
		t.eq(why, "Not enough Diamonds")
		t.no(P.EquipClass(p, "Miner"), "can't equip unowned")
		p.Diamonds = miner.Price
		t.ok(P.BuyClass(p, "Miner"))
		t.eq(p.Diamonds, 0)
		t.no(P.BuyClass(p, "Miner"), "no double buy")
		t.ok(P.EquipClass(p, "Miner"))
		t.eq(p.Class, "Miner")
	end,
	buy_and_equip_perk = function(t)
		local p = P.New()
		p.Diamonds = Perks.ById.Runner.Price
		t.ok(P.BuyPerk(p, "Runner"))
		t.ok(P.EquipPerk(p, "Runner"))
		t.eq(p.Perk, "Runner")
		t.ok(P.EquipPerk(p, nil))
		t.eq(p.Perk, nil)
		t.no(P.EquipPerk(p, "Hardy"))
	end,
	cosmetics_buy_and_wear = function(t)
		local p = P.New()
		p.Coins = 1799
		t.no(P.BuyCosmetic(p, "OutfitWoodsman"))
		p.Coins = 1800
		t.ok(P.BuyCosmetic(p, "OutfitWoodsman"))
		t.eq(p.Coins, 0)
		t.no(P.WearCosmetic(p, "Title", "OutfitWoodsman"), "type must match")
		t.ok(P.WearCosmetic(p, "Outfit", "OutfitWoodsman"))
		t.eq(p.Wearing.Outfit, "OutfitWoodsman")
		t.no(P.BuyCosmetic(p, "TitleSprout"), "level rewards aren't sold")
	end,
	xp_levels_and_rewards = function(t)
		local p = P.New()
		local res = P.AddXP(p, Progression.TotalForLevel(10))
		t.eq(p.Level, 10)
		t.eq(res.Levels, 9)
		t.eq(res.Coins, 200, "levels 5 and 10")
		t.eq(res.Diamonds, 1, "level 10")
		t.ok(p.Cosmetics.TitleSprout and p.Cosmetics.TitleTrailhand, "milestone titles")
	end,
	placement_rewards_once = function(t)
		local p = P.New()
		local xp, coins, d = P.AwardPlacement(p, "m1", 1, 40)
		t.eq(xp, 500)
		t.eq(coins, 250)
		t.eq(d, 2, "exactly 2 diamonds for a win")
		xp, coins, d = P.AwardPlacement(p, "m1", 1, 40)
		t.eq(xp + coins + d, 0, "same match never rewarded twice")
		t.eq(p.Wins, 1)
		local q = P.New()
		t.eq(select(2, P.AwardPlacement(q, "m2", 2, 40)), 100)
		t.eq(select(2, P.AwardPlacement(q, "m3", 3, 40)), 50)
		t.eq(select(3, P.AwardPlacement(q, "m4", 2, 40)), 0, "no diamonds for 2nd")
		t.eq(q.Wins, 0)
	end,
	daily_streak = function(t)
		local p = P.New()
		local t0 = 1000 * DAY + 100
		t.eq(P.ClaimDaily(p, t0), 50)
		t.eq(P.ClaimDaily(p, t0 + 60), 0, "once per day")
		t.eq(P.ClaimDaily(p, t0 + DAY), 70, "streak day 2")
		t.eq(P.ClaimDaily(p, t0 + 3 * DAY), 50, "streak broken")
		for i = 4, 12 do
			P.ClaimDaily(p, t0 + i * DAY)
		end
		t.eq(p.Daily.Streak, 10)
		t.eq(P.ClaimDaily(p, t0 + 13 * DAY), 150, "capped")
	end,
	weekly_bonus = function(t)
		local p = P.New()
		local t0 = 3000 * DAY
		t.no(P.CanClaimWeekly(p, t0))
		P.NoteMatch(p, t0, true)
		P.NoteMatch(p, t0, false)
		t.eq(P.ClaimWeekly(p, t0), 0, "needs 3 matches")
		P.NoteMatch(p, t0, true)
		t.eq(P.ClaimWeekly(p, t0), 450, "300 + 2 wins x 75")
		t.eq(P.ClaimWeekly(p, t0), 0, "once a week")
		t.no(P.CanClaimWeekly(p, t0 + 7 * DAY), "new week resets")
	end,
	double_purchase_is_blocked = function(t)
		local p = P.New()
		p.Diamonds = 100
		t.ok(P.BuyClass(p, "Lumberjack"))
		t.no(P.BuyClass(p, "Lumberjack"), "second click")
		t.eq(p.Diamonds, 60, "charged once")
		p.Coins = 1800
		t.ok(P.BuyCosmetic(p, "OutfitWoodsman"))
		t.no(P.BuyCosmetic(p, "OutfitWoodsman"))
		t.eq(p.Coins, 0)
	end,
	bundle_receipt_replay_no_double_refund = function(t)
		local p = P.New()
		P.ApplyReceipt(p, "b", { Kind = "Bundle", Bundle = "Ember" }, 200)
		local coins = p.Coins
		t.eq((P.ApplyReceipt(p, "b", { Kind = "Bundle", Bundle = "Ember" }, 200)), "AlreadyGranted")
		t.eq(p.Coins, coins, "replay grants nothing")
	end,
	save_roundtrip_keeps_everything = function(t)
		local p = P.New()
		p.Diamonds, p.Coins = 77, 4321
		P.AddXP(p, 5000)
		p.OwnedClasses.Miner = true
		p.Class = "Miner"
		p.OwnedPerks.Runner = true
		p.Perk = "Runner"
		p.Cosmetics.PlateBark = true
		p.Wearing.Nameplate = "PlateBark"
		P.AwardPlacement(p, "m1", 1, 40)
		P.ClaimDaily(p, 90000 * 86400)
		local q = P.Reconcile(table.clone(p))
		t.eq(q.Diamonds, p.Diamonds)
		t.eq(q.Coins, p.Coins)
		t.eq(q.XP, p.XP)
		t.eq(q.Level, p.Level)
		t.eq(q.Class, "Miner")
		t.eq(q.Perk, "Runner")
		t.eq(q.Wearing.Nameplate, "PlateBark")
		t.eq(q.Wins, 1)
		t.eq(q.Daily.Streak, 1)
		t.eq((P.AwardPlacement(q, "m1", 1, 40)), 0, "match reward survives reload")
	end,
	corrupted_values_are_sanitised = function(t)
		local q = P.Reconcile({ Version = 2, Coins = 0 / 0, Diamonds = math.huge, XP = -50, Wearing = { Title = 5 }, Cosmetics = { Fake = true } })
		t.eq(q.Coins, 0, "NaN coins")
		t.eq(q.XP, 0)
		t.eq(q.Wearing.Title, nil)
		t.eq(q.Cosmetics.Fake, nil)
		t.eq(q.Diamonds, 0, "infinite diamonds rejected")
	end,
	rewarded_matches_bounded = function(t)
		local p = P.New()
		for i = 1, 60 do
			P.AwardPlacement(p, "m" .. i, 3, 40)
		end
		t.eq(#p.RewardedMatches, 40)
		t.eq(p.Coins, 60 * 50)
	end,
}
