-- Profile defaults, sanitising of loaded data and the client snapshot.
local Profile = require("../src/shared/Logic/Profile")
local Inventory = require("../src/shared/Logic/Inventory")
local Schema = require("../src/shared/Logic/Schema")
local Config = require("../src/shared/Config")

local NOW = 1_800_000_000

local function pet(uid, id, extra)
	local r = { Uid = uid, Id = id or "Puppy", Variant = "Normal", Shiny = false, Level = 1, Xp = 0, Locked = false }
	for k, v in extra or {} do
		r[k] = v
	end
	return r
end

return {
	["garbage loads as a fresh profile"] = function(t)
		for _, raw in { nil, 5, "x", true } do
			local p = Profile.Sanitize(raw)
			t.eq(p.Coins, Schema.StartCoins, "coins")
			t.ok(p.Areas.Meadow, "meadow")
			t.eq(#p.Pets, 0, "pets")
		end
		local p = Profile.Sanitize({})
		t.eq(p.Coins, Schema.StartCoins, "empty table is a new player")
	end,
	["round trip keeps good data"] = function(t)
		local p = Profile.Default()
		p.Coins = 1234
		p.Gems = 55
		p.Areas.Grove = true
		local a = Inventory.Add(p, { Id = "Fox", Variant = "Golden", Shiny = true })
		Inventory.Add(p, { Id = "Puppy" })
		Inventory.Equip(p, a.Uid, true)
		p.Passes.VIP = true
		p.Boosts.Coins2x = NOW + 50
		p.Receipts.abc = NOW
		p.Settings.Music = false
		local q = Profile.Sanitize(p)
		t.eq(q.Coins, 1234, "coins")
		t.eq(q.Gems, 55, "gems")
		t.ok(q.Areas.Grove, "areas")
		t.eq(#q.Pets, 2, "pets")
		t.eq(q.Pets[1].Variant, "Golden", "variant")
		t.ok(q.Pets[1].Shiny, "shiny")
		t.eq(q.Equipped[1], a.Uid, "equipped")
		t.ok(q.Passes.VIP, "pass")
		t.eq(q.Boosts.Coins2x, NOW + 50, "boost")
		t.ok(Profile.HasReceipt(q, "abc"), "receipt")
		t.eq(q.Settings.Music, false, "setting")
		t.eq(q.NextUid, p.NextUid, "uid counter")
	end,
	["bad numbers are clamped"] = function(t)
		local p = Profile.Sanitize({ Coins = -50, Gems = 0 / 0, Rebirths = 1e9, ExtraEquip = -1, ExtraStorage = math.huge })
		t.eq(p.Coins, 0, "negative coins")
		t.eq(p.Gems, 0, "nan gems")
		t.eq(p.Rebirths, Config.MaxRebirths, "rebirth cap")
		t.eq(p.ExtraEquip, 0, "extra equip")
		t.eq(p.ExtraStorage, 0, "inf storage")
		local q = Profile.Sanitize({ Coins = 1e300, Gems = 1e300 })
		t.eq(q.Coins, Schema.MaxCoins, "coin cap")
		t.eq(q.Gems, Schema.MaxGems, "gem cap")
		local r = Profile.Sanitize({ Coins = "lots" })
		t.eq(r.Coins, 0, "string coins")
	end,
	["bad pets are dropped, duplicate uids renamed"] = function(t)
		local p = Profile.Sanitize({
			NextUid = 2,
			Pets = {
				pet("1"),
				pet("1", "Kitten"),
				pet("7"),
				pet("x", "NotAPet"),
				"junk",
				pet(nil, "Fox"),
				pet("9", "Fox", { Variant = "Plaid", Level = 999, Xp = -4, Shiny = "yes", Locked = 1 }),
			},
		})
		t.eq(#p.Pets, 5, "kept valid pets")
		local seen = {}
		for _, q in p.Pets do
			t.no(seen[q.Uid], "unique uid " .. q.Uid)
			seen[q.Uid] = true
		end
		t.ok(p.NextUid >= 9, "counter above existing uids")
		local fox = Inventory.Find(p, "9")
		t.eq(fox.Variant, "Normal", "bad variant")
		t.eq(fox.Level, Config.PetMaxLevel, "level clamp")
		t.eq(fox.Xp, 0, "xp clamp")
		t.eq(fox.Shiny, false, "shiny must be boolean")
		t.eq(fox.Locked, false, "locked must be boolean")
		t.ok(p.Index.Kitten and p.Index.Fox, "index includes owned pets")
		-- New pets never collide with loaded ones.
		local n = Inventory.Add(p, { Id = "Puppy" })
		t.no(seen[n.Uid], "fresh uid")
	end,
	["equipped and expeditions are cleaned"] = function(t)
		local p = Profile.Sanitize({
			Pets = { pet("1"), pet("2"), pet("3"), pet("4"), pet("5") },
			Equipped = { "1", "1", "ghost", "2", "3", "4", "5" },
			Expeditions = {
				["1"] = { Area = "Meadow", Duration = "Short", Pets = { "2", "ghost" }, StartAt = 1, EndAt = 2, Seed = 5 },
				["2"] = { Area = "Meadow", Duration = "Short", Pets = { "2" }, StartAt = 1, EndAt = 2, Seed = 5 },
				["3"] = { Area = "Mars", Duration = "Short", Pets = { "3" }, StartAt = 1, EndAt = 2, Seed = 5 },
				["99"] = { Area = "Meadow", Duration = "Short", Pets = { "4" }, StartAt = 1, EndAt = 2, Seed = 5 },
				["x"] = "junk",
			},
		})
		t.ok(p.Expeditions["1"], "valid expedition kept")
		t.eq(#p.Expeditions["1"].Pets, 1, "ghost pet removed")
		t.eq(p.Expeditions["2"], nil, "pet can't be on two expeditions")
		t.eq(p.Expeditions["3"], nil, "unknown area")
		t.eq(p.Expeditions["99"], nil, "slot out of range")
		t.no(table.find(p.Equipped, "2"), "busy pet unequipped")
		t.eq(#p.Equipped, Config.BaseEquip, "equip limit")
		t.eq(p.Equipped[1], "1", "no duplicates")
	end,
	["unknown passes, boosts, settings and areas are dropped"] = function(t)
		local p = Profile.Sanitize({
			Passes = { VIP = true, GodMode = true, Lucky = "yes" },
			Boosts = { Coins2x = NOW, Infinite = NOW, Luck2x = 0 / 0 },
			Settings = { Music = false, Admin = true, Sfx = "loud" },
			Areas = { Grove = true, Moon = true },
			IndexClaimed = { ["1"] = true, ["9"] = true },
		})
		t.ok(p.Passes.VIP, "vip")
		t.eq(p.Passes.GodMode, nil, "fake pass")
		t.eq(p.Passes.Lucky, nil, "non-boolean pass")
		t.eq(p.Boosts.Infinite, nil, "fake boost")
		t.eq(p.Boosts.Luck2x, nil, "nan boost")
		t.eq(p.Settings.Music, false, "music")
		t.eq(p.Settings.Admin, nil, "fake setting")
		t.eq(p.Settings.Sfx, true, "bad setting reset to default")
		t.eq(p.Areas.Moon, nil, "fake area")
		t.ok(p.Areas.Meadow, "meadow always open")
		t.ok(p.IndexClaimed["1"], "claimed tier")
		t.eq(p.IndexClaimed["9"], nil, "fake tier")
	end,
	["receipts are trimmed to the newest"] = function(t)
		local p = Profile.Default()
		for i = 1, Schema.MaxReceipts + 20 do
			Profile.RecordReceipt(p, "r" .. i, i)
		end
		local n = 0
		for _ in p.Receipts do
			n += 1
		end
		t.eq(n, Schema.MaxReceipts, "trimmed")
		t.ok(Profile.HasReceipt(p, "r" .. (Schema.MaxReceipts + 20)), "newest kept")
		t.no(Profile.HasReceipt(p, "r1"), "oldest dropped")
	end,
	["settings are whitelisted booleans"] = function(t)
		local p = Profile.Default()
		t.ok(Profile.SetSetting(p, "AutoFarm", true), "ok")
		t.eq(p.Settings.AutoFarm, true, "set")
		t.no(Profile.SetSetting(p, "AutoFarm", "true"), "string value")
		t.no(Profile.SetSetting(p, "Coins", true), "not a setting")
		t.no(Profile.SetSetting(p, 5, true), "bad key")
	end,
	["quests are validated"] = function(t)
		local p = Profile.Sanitize({ Quests = { Day = 5, List = { { Kind = "Break", Goal = 0 / 0, Progress = 1, Gems = 1 } } } })
		t.eq(p.Quests.Day, -1, "bad quests regenerate")
		local q = Profile.Sanitize({ Quests = { Day = 5, List = { { Kind = "Break", Goal = 10, Progress = 50, Gems = 1e9, Claimed = true } } } })
		t.eq(q.Quests.List[1].Progress, 10, "progress clamp")
		t.eq(q.Quests.List[1].Gems, 1000, "gem clamp")
	end,
	["state snapshot has every field and hides seeds"] = function(t)
		local p = Profile.Default()
		local a = Inventory.Add(p, { Id = "Fox" })
		p.Expeditions["1"] = { Area = "Meadow", Duration = "Short", Pets = { a.Uid }, StartAt = NOW, EndAt = NOW + 300, Seed = 12345 }
		p.Boosts.Coins2x = NOW - 1
		p.Boosts.Luck2x = NOW + 100
		local s = Profile.BuildState(p, { Now = NOW, ServerLuckUntil = NOW + 10, SessionMinutes = 3.7, PlaytimeClaimed = { ["1"] = true }, CanTrade = false })
		t.eq(s.Coins, p.Coins, "coins")
		t.eq(#s.Pets, 1, "pets")
		t.ok(s.Pets[1] ~= p.Pets[1], "pets copied")
		t.eq(s.Expeditions["1"].Seed, 0, "seed hidden")
		t.eq(s.Boosts.Coins2x, nil, "expired boost hidden")
		t.eq(s.Boosts.Luck2x, NOW + 100, "active boost")
		t.eq(s.ServerLuckUntil, NOW + 10, "server luck")
		t.eq(s.Playtime.SessionMinutes, 3, "minutes floored")
		t.ok(s.Playtime.Claimed["1"], "claimed")
		t.eq(s.CanTrade, false, "trade off")
		t.eq(s.CanBuyGemEggs, true, "default allowed")
		t.eq(#s.Quests, Config.QuestsPerDay, "quests shown")
		t.ok(s.RebirthCost > 0, "rebirth cost")
		t.eq(s.ServerTime, NOW, "time")
		t.eq(s.MaxEquip, Config.BaseEquip, "max equip")
		t.ok(s.Daily.CanClaim, "daily ready")
		t.eq(s.Settings.AutoFarm, false, "settings")
	end,
	["trade journal fields and expedition snapshots are sanitised"] = function(t)
		local p = Profile.Sanitize({
			Pets = { pet("1") },
			Expeditions = { ["1"] = { Area = "Meadow", Duration = "Short", Pets = { "1" }, StartAt = 1, EndAt = 2, Seed = 5 } },
			ExpeditionMult = { ["1"] = 2.5, ["2"] = 3, ["x"] = 1 },
			PendingTrade = "abc",
			AppliedTrades = { "a", 5, "b" },
		})
		t.eq(p.ExpeditionMult["1"], 2.5, "kept for a live expedition")
		t.eq(p.ExpeditionMult["2"], nil, "dropped for an empty slot")
		t.eq(p.PendingTrade, "abc", "pending trade kept")
		t.eq(#p.AppliedTrades, 2, "only string ids")
		local q = Profile.Sanitize({ ExpeditionMult = { ["1"] = 0 / 0 }, PendingTrade = 5 })
		t.eq(q.PendingTrade, nil, "bad pending id")
		t.eq(next(q.ExpeditionMult), nil, "no expeditions, no snapshots")
	end,
}
