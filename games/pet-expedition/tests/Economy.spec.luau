-- Currency, multipliers, boosts, gates and rebirth.
local Economy = require("../src/shared/Logic/Economy")
local Profile = require("../src/shared/Logic/Profile")
local Schema = require("../src/shared/Logic/Schema")
local Config = require("../src/shared/Config")
local Areas = require("../src/shared/Areas")

local NOW = 1_800_000_000

local function near(a, b)
	return math.abs(a - b) < 1e-9
end

return {
	["new players start with coins and Meadow"] = function(t)
		local p = Profile.Default()
		t.ok(p.Coins >= 100, "enough for the first egg")
		t.ok(p.Areas.Meadow, "meadow open")
		t.no(p.Areas.Grove, "grove closed")
	end,
	["coin multiplier stacks every source"] = function(t)
		local p = Profile.Default()
		t.ok(near(Economy.CoinMult(p, { Now = NOW }), 1), "base")
		p.Rebirths = 2
		p.Passes.VIP = true
		p.Boosts.Coins2x = NOW + 60
		local expect = (1 + 2 * Config.RebirthCoinBonus) * Config.VipCoinMult * Config.CoinBoostMult * Config.PremiumCoinMult
		t.ok(near(Economy.CoinMult(p, { Now = NOW, Premium = true }), expect), "stacked")
		-- Expired boost no longer counts.
		p.Boosts.Coins2x = NOW - 1
		t.ok(near(Economy.CoinMult(p, { Now = NOW, Premium = true }), expect / Config.CoinBoostMult), "expired boost")
	end,
	["group bonus only when a group is configured"] = function(t)
		local p = Profile.Default()
		local m = Economy.CoinMult(p, { Now = NOW, InGroup = true })
		if Config.GroupId == 0 then
			t.ok(near(m, 1), "off when GroupId is 0")
		else
			t.ok(near(m, Config.GroupCoinMult), "on")
		end
	end,
	["luck multiplier is capped"] = function(t)
		local p = Profile.Default()
		t.ok(near(Economy.LuckMult(p, { Now = NOW }), 1), "base")
		p.Passes.Lucky = true
		p.Boosts.Luck2x = NOW + 100
		local m = Economy.LuckMult(p, { Now = NOW, ServerLuckUntil = NOW + 100 })
		t.ok(near(m, math.min(Config.MaxLuckMult, Config.LuckyPassMult * Config.LuckBoostMult * Config.ServerLuckMult)), "stacked")
		t.ok(m <= Config.MaxLuckMult, "capped")
		t.ok(near(Economy.LuckMult(p, { Now = NOW, ServerLuckUntil = NOW - 1 }), Config.LuckyPassMult * Config.LuckBoostMult), "server luck expired")
	end,
	["capacity from passes and index"] = function(t)
		local p = Profile.Default()
		t.eq(Economy.MaxEquip(p), Config.BaseEquip, "base equip")
		t.eq(Economy.MaxStorage(p), Config.BaseStorage, "base storage")
		t.eq(Economy.ExpeditionSlots(p), Config.BaseExpeditionSlots, "base slots")
		p.Passes.MoreEquip = true
		p.Passes.BigBackpack = true
		p.Passes.MoreExpeditions = true
		p.ExtraEquip = 100
		p.ExtraStorage = 50
		t.eq(Economy.MaxEquip(p), Config.MaxEquipCap, "equip capped")
		t.eq(Economy.MaxStorage(p), Config.BaseStorage + 150 + 50, "storage")
		t.eq(Economy.ExpeditionSlots(p), Config.BaseExpeditionSlots + 2, "slots")
	end,
	["AddCoins rejects bad amounts and caps"] = function(t)
		local p = Profile.Default()
		local start = p.Coins
		for _, bad in { -5, 0, 0 / 0, math.huge, -math.huge } do
			t.eq(Economy.AddCoins(p, bad, true), 0, "bad " .. tostring(bad))
		end
		t.eq(p.Coins, start, "unchanged")
		t.eq(Economy.AddCoins(p, 10.9, true), 10, "floored")
		t.eq(p.Stats.CoinsEarned, 10, "earned counted")
		Economy.AddCoins(p, 1e300, false)
		t.eq(p.Coins, Schema.MaxCoins, "capped")
		t.eq(Economy.AddCoins(p, 5, true), 0, "nothing past cap")
	end,
	["Spend refuses bad or unaffordable amounts"] = function(t)
		local p = Profile.Default()
		p.Coins = 100
		p.Gems = 10
		t.no(Economy.Spend(p, "Coins", 101), "too much")
		t.no(Economy.Spend(p, "Coins", -5), "negative")
		t.no(Economy.Spend(p, "Coins", 0 / 0), "nan")
		t.no(Economy.Spend(p, "Bananas", 1), "unknown currency")
		t.ok(Economy.Spend(p, "Coins", 100), "exact")
		t.eq(p.Coins, 0, "spent")
		t.ok(Economy.Spend(p, "Gems", 4), "gems")
		t.eq(p.Gems, 6, "gems spent")
		t.eq(Economy.AddGems(p, -3), 0, "no negative gems")
		Economy.AddGems(p, 1e300)
		t.eq(p.Gems, Schema.MaxGems, "gem cap")
	end,
	["boosts stack by extending and are capped"] = function(t)
		local p = Profile.Default()
		local secs = Config.Boosts.Luck2x.Seconds
		t.eq(Economy.ApplyBoost(p, "Luck2x", NOW), NOW + secs, "first")
		t.eq(Economy.ApplyBoost(p, "Luck2x", NOW + 10), NOW + 2 * secs, "extends")
		for _ = 1, 200 do
			Economy.ApplyBoost(p, "Luck2x", NOW)
		end
		t.eq(p.Boosts.Luck2x, NOW + Config.MaxBoostSeconds, "capped")
		t.eq(Economy.ApplyBoost(p, "Nope", NOW), 0, "unknown key")
		t.eq(p.Boosts.Nope, nil, "not stored")
		-- An expired boost restarts from now.
		p.Boosts.Coins2x = NOW - 500
		t.eq(Economy.ApplyBoost(p, "Coins2x", NOW), NOW + Config.Boosts.Coins2x.Seconds, "restart")
		t.ok(Economy.PruneBoosts(p, NOW + Config.MaxBoostSeconds + 1), "pruned")
		t.eq(next(p.Boosts), nil, "empty")
	end,
	["server luck extends and caps"] = function(t)
		t.eq(Economy.ExtendServerLuck(0, NOW), NOW + Config.ServerLuckSeconds, "fresh")
		t.eq(Economy.ExtendServerLuck(NOW + 100, NOW), NOW + 100 + Config.ServerLuckSeconds, "stack")
		local u = 0
		for _ = 1, 1000 do
			u = Economy.ExtendServerLuck(u, NOW)
		end
		t.eq(u, NOW + Config.MaxBoostSeconds, "cap")
	end,
	["gates open in order and cost coins"] = function(t)
		local p = Profile.Default()
		p.Coins = 1e9
		local ok, err = Economy.OpenGate(p, "Frost")
		t.no(ok, "skip a gate")
		t.ok(err, "reason")
		t.ok(Economy.OpenGate(p, "Grove"), "grove")
		t.eq(p.Coins, 1e9 - Areas.ById.Grove.GateCost, "paid")
		t.no(Economy.OpenGate(p, "Grove"), "twice")
		t.no(Economy.OpenGate(p, "Atlantis"), "unknown")
		p.Coins = 0
		t.no(Economy.OpenGate(p, "Frost"), "broke")
		t.no(p.Areas.Frost, "still closed")
		t.eq(Economy.HighestArea(p), "Grove", "highest")
	end,
	["rebirth resets coins and gates, keeps pets and gems"] = function(t)
		local p = Profile.Default()
		p.Areas.Grove = true
		p.Gems = 7
		table.insert(p.Pets, { Uid = "1", Id = "Puppy", Variant = "Normal", Shiny = false, Level = 1, Xp = 0, Locked = false })
		p.Coins = Economy.RebirthCost(0) - 1
		t.no(Economy.Rebirth(p), "too poor")
		p.Coins = Economy.RebirthCost(0)
		t.ok(Economy.Rebirth(p), "rebirth")
		t.eq(p.Coins, 0, "coins reset")
		t.no(p.Areas.Grove, "gates reset")
		t.ok(p.Areas.Meadow, "meadow kept")
		t.eq(p.Rebirths, 1, "count")
		t.eq(p.Gems, 7 + Config.RebirthGems, "gems")
		t.eq(#p.Pets, 1, "pets kept")
		t.eq(Economy.RebirthCost(1), Config.RebirthBaseCost * Config.RebirthCostGrowth, "cost grows")
		p.Rebirths = Config.MaxRebirths
		p.Coins = Schema.MaxCoins
		t.no(Economy.Rebirth(p), "max rebirths")
	end,
	["break split: gems add up exactly"] = function(t)
		for _, case in { { 1, 1, 1 }, { 5, 3, 2 }, { 1, 1, 1, 1, 1, 1, 1 }, { 100 }, { 0.3, 0.3, 0.4 } } do
			for gems = 0, 7 do
				local out = Economy.SplitBreak(case, 100, gems)
				local sum = 0
				for _, s in out do
					t.ok(s.Gems >= 0 and s.Gems == math.floor(s.Gems), "whole gems")
					sum += s.Gems
				end
				t.eq(sum, gems, "sum for " .. #case .. " players, " .. gems .. " gems")
			end
		end
	end,
	["break split: three equal players share 5 gems as 2/2/1"] = function(t)
		local out = Economy.SplitBreak({ 10, 10, 10 }, 0, 5)
		local counts = {}
		for _, s in out do
			counts[s.Gems] = (counts[s.Gems] or 0) + 1
		end
		t.eq(counts[2], 2, "two get 2")
		t.eq(counts[1], 1, "one gets 1")
	end,
	["break split: coins by share, credit needs 5%"] = function(t)
		local out = Economy.SplitBreak({ 96, 4 }, 1000, 0)
		t.ok(math.abs(out[1].Coins - 960) < 1e-9, "big share")
		t.ok(out[1].Credit, "credited")
		t.no(out[2].Credit, "4% gets no credit")
		t.ok(math.abs(out[2].Coins - 40) < 1e-9, "but still its coins")
		local tiny = Economy.SplitBreak({ 999999, 1 }, 10, 0)
		t.ok(tiny[2].Coins < 1, "no free minimum coin for a tiny hit")
		local small = Economy.SplitBreak({ 95, 5 }, 1, 0)
		t.ok(small[2].Credit, "exactly 5% is credited")
		t.eq(small[2].Coins, 1, "credited players get at least 1 coin")
	end,
	["break split: bad input"] = function(t)
		local out = Economy.SplitBreak({ 0 / 0, -5, 10 }, 0 / 0, -3)
		t.eq(out[1].Gems + out[2].Gems + out[3].Gems, 0, "no gems from bad totals")
		t.no(out[1].Credit, "nan damage")
		t.no(out[2].Credit, "negative damage")
		t.ok(out[3].Credit, "real damage")
		local none = Economy.SplitBreak({ 0, 0 }, 100, 5)
		t.eq(none[1].Gems + none[2].Gems, 0, "nobody hit it")
		t.eq(#Economy.SplitBreak({}, 100, 5), 0, "empty")
	end,
	["rolling cap limits gems per hour"] = function(t)
		local log = {}
		t.eq(Economy.CapRolling(log, 0, 10, 15, 3600), 10, "under cap")
		t.eq(Economy.CapRolling(log, 100, 10, 15, 3600), 5, "partly")
		t.eq(Economy.CapRolling(log, 200, 3, 15, 3600), 0, "full")
		t.eq(Economy.CapRolling(log, 3599, 1, 15, 3600), 0, "still inside the hour")
		t.eq(Economy.CapRolling(log, 3600, 20, 15, 3600), 10, "first grant expired")
		t.eq(Economy.CapRolling(log, 3700, 20, 15, 3600), 5, "second expired too")
		for _, bad in { -1, 0, 0 / 0, math.huge } do
			t.eq(Economy.CapRolling({}, 0, bad, 15, 3600), 0, "bad amount " .. tostring(bad))
		end
		t.eq(Economy.CapRolling({}, 0, 2.9, 15, 3600), 2, "whole gems only")
		t.eq(Economy.CapRolling({}, 0, 5, Config.BreakGemsPerHour, 3600), math.min(5, Config.BreakGemsPerHour), "config cap")
	end,
	["rebirth costs stay under the coin cap up to the max"] = function(t)
		local p = Profile.Default()
		for r = 0, Config.MaxRebirths - 1 do
			local cost = Economy.RebirthCost(r)
			t.ok(cost == cost and cost < math.huge, "finite cost " .. r)
			t.ok(cost <= Schema.MaxCoins, "affordable under the coin cap at rebirth " .. r)
			p.Coins = Schema.MaxCoins
			t.ok(Economy.Rebirth(p), "rebirth " .. (r + 1))
		end
		t.eq(p.Rebirths, Config.MaxRebirths, "reached the max")
		p.Coins = Schema.MaxCoins
		t.no(Economy.Rebirth(p), "no rebirth past the max")
		local s = Profile.BuildState(p, { Now = 0 })
		t.eq(s.RebirthCost, 0, "state shows no further cost")
		local mult = Economy.CoinMult(p, { Now = 0 })
		t.eq(mult, 1 + Config.RebirthCoinBonus * Config.MaxRebirths, "bonus at max")
	end,
}
