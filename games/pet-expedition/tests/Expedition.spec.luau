-- Expeditions: start validation, deterministic rewards, claim, skip.
local Expedition = require("../src/shared/Logic/Expedition")
local Inventory = require("../src/shared/Logic/Inventory")
local Profile = require("../src/shared/Logic/Profile")
local PetMath = require("../src/shared/Logic/PetMath")
local Economy = require("../src/shared/Logic/Economy")
local Config = require("../src/shared/Config")
local Areas = require("../src/shared/Areas")

local NOW = 1_800_000_000

local function setup(n)
	local p = Profile.Default()
	local uids = {}
	for _ = 1, n or 3 do
		local pet = Inventory.Add(p, { Id = "Fox" })
		table.insert(uids, pet.Uid)
	end
	return p, uids
end

return {
	["start validates area, duration, pets and slots"] = function(t)
		local p, uids = setup(5)
		t.no(Expedition.Start(p, "Atlantis", "Short", { uids[1] }, NOW, 1), "unknown area")
		t.no(Expedition.Start(p, "Grove", "Short", { uids[1] }, NOW, 1), "closed area")
		t.no(Expedition.Start(p, "Meadow", "Forever", { uids[1] }, NOW, 1), "unknown duration")
		t.no(Expedition.Start(p, "Meadow", "Short", {}, NOW, 1), "no pets")
		t.no(Expedition.Start(p, "Meadow", "Short", { uids[1], uids[2], uids[3], uids[4] }, NOW, 1), "too many pets")
		t.no(Expedition.Start(p, "Meadow", "Short", { uids[1], uids[1] }, NOW, 1), "duplicate pet")
		t.no(Expedition.Start(p, "Meadow", "Short", { "ghost" }, NOW, 1), "unknown pet")
		t.no(Expedition.Start(p, "Meadow", "Short", { uids[1] }, NOW, 1, { [uids[1]] = true }), "pet in a trade")
		local slot, exp = Expedition.Start(p, "Meadow", "Short", { uids[1], uids[2] }, NOW, 1)
		t.eq(slot, "1", "slot 1")
		t.eq(exp.EndAt, NOW + Config.ExpeditionDurations[1].Seconds, "end time")
		t.no(Expedition.Start(p, "Meadow", "Short", { uids[3] }, NOW, 1), "only one slot")
		p.Passes.MoreExpeditions = true
		t.no(Expedition.Start(p, "Meadow", "Short", { uids[2] }, NOW, 1), "pet already away")
		t.eq(Expedition.Start(p, "Meadow", "Short", { uids[3] }, NOW, 1), "2", "second slot")
	end,
	["starting unequips the pets and makes them busy"] = function(t)
		local p, uids = setup(2)
		Inventory.Equip(p, uids[1], true)
		Expedition.Start(p, "Meadow", "Short", { uids[1] }, NOW, 5)
		t.no(Inventory.IsEquipped(p, uids[1]), "unequipped")
		t.ok(Inventory.IsBusy(p, uids[1]), "busy")
		t.no(Inventory.Equip(p, uids[1], true), "can't equip")
		t.no(Inventory.Delete(p, { uids[1] }), "can't delete")
	end,
	["rewards are deterministic from the seed"] = function(t)
		local p, uids = setup(3)
		local _, exp = Expedition.Start(p, "Meadow", "Long", uids, NOW, 777)
		local a = Expedition.RollReward(p, exp)
		local b = Expedition.RollReward(p, exp)
		t.eq(a.Coins, b.Coins, "coins")
		t.eq(a.Gems, b.Gems, "gems")
		t.eq(#a.Pets, #b.Pets, "pets")
		for i = 1, #a.Pets do
			t.eq(a.Pets[i].Id, b.Pets[i].Id, "pet " .. i)
		end
		local power = 3 * PetMath.Power(Inventory.Find(p, uids[1]))
		t.eq(a.Coins, math.floor(power * Config.ExpeditionCoinsPerPower * Areas.ById.Meadow.CoinMult * 16), "coin formula")
	end,
	["reward rates roughly follow the config"] = function(t)
		local p, uids = setup(1)
		local finds, gems, eggs = 0, 0, 0
		local n = 4000
		local dur = Config.ExpeditionDurations[2] -- Medium
		for i = 1, n do
			local exp = { Area = "Meadow", Duration = dur.Key, Pets = { uids[1] }, StartAt = 0, EndAt = 0, Seed = i * 7919 }
			local r = Expedition.RollReward(p, exp)
			if r.Gems > 0 then
				gems += 1
				t.ok(r.Gems >= math.floor(Config.ExpeditionGems[1] * math.sqrt(dur.Mult)), "gem min")
				t.ok(r.Gems <= math.floor(Config.ExpeditionGems[2] * math.sqrt(dur.Mult)), "gem max")
			end
			for _, s in r.Pets do
				if s.Id == Areas.ById.Meadow.ExpeditionPet then
					finds += 1
				else
					eggs += 1
				end
			end
		end
		t.ok(math.abs(finds / n - dur.FindChance) < 0.03, "find rate " .. finds)
		t.ok(math.abs(gems / n - dur.GemChance) < 0.04, "gem rate " .. gems)
		t.eq(eggs, n, "medium always brings an egg (0.35 * 5 capped at 1)")
	end,
	["claim waits for the timer and pays once"] = function(t)
		local p, uids = setup(1)
		p.Coins = 0
		local slot = Expedition.Start(p, "Meadow", "Short", uids, NOW, 3)
		t.no(Expedition.Claim(p, slot, NOW + 10, 1), "too early")
		local r = Expedition.Claim(p, slot, NOW + 301, 2)
		t.ok(r, "claimed")
		t.ok(r.Coins > 0, "coins")
		t.eq(p.Coins, r.Coins, "credited")
		t.eq(p.Stats.Expeditions, 1, "stat")
		t.no(Inventory.IsBusy(p, uids[1]), "pet home")
		t.no(Expedition.Claim(p, slot, NOW + 400, 1), "double claim")
		t.eq(p.Stats.Expeditions, 1, "stat once")
	end,
	["claim applies the coin multiplier and ignores bad ones"] = function(t)
		local p, uids = setup(1)
		local slot, exp = Expedition.Start(p, "Meadow", "Short", uids, NOW, 3)
		local base = Expedition.RollReward(p, exp).Coins
		p.Coins = 0
		local r = Expedition.Claim(p, slot, exp.EndAt, 0 / 0)
		t.eq(r.Coins, base, "nan mult treated as 1")
	end,
	["claim refuses when found pets don't fit"] = function(t)
		local p, uids = setup(1)
		-- Find a seed whose reward contains a pet.
		local seed
		for s = 1, 500 do
			local r = Expedition.RollReward(p, { Area = "Meadow", Duration = "Medium", Pets = uids, StartAt = 0, EndAt = 0, Seed = s })
			if #r.Pets > 0 then
				seed = s
				break
			end
		end
		t.ok(seed, "seed found")
		local slot, exp = Expedition.Start(p, "Meadow", "Medium", uids, NOW, seed)
		exp.Seed = seed
		while Inventory.FreeSpace(p) > 0 do
			Inventory.Add(p, { Id = "Puppy" })
		end
		local coins = p.Coins
		local r, err = Expedition.Claim(p, slot, exp.EndAt, 1)
		t.no(r, "refused")
		t.ok(err, "reason")
		t.ok(p.Expeditions[slot], "still waiting")
		t.eq(p.Coins, coins, "no partial payout")
	end,
	["skip costs gems and finishes now"] = function(t)
		local p, uids = setup(1)
		local slot, exp = Expedition.Start(p, "Meadow", "Epic", uids, NOW, 3)
		local cost = Expedition.SkipCost(exp, NOW)
		t.eq(cost, math.ceil(8 * 60 * Config.ExpeditionSkipGemsPerMinute), "cost")
		t.ok(Expedition.SkipCost(exp, exp.EndAt - 1) >= 5, "minimum 5")
		t.eq(Expedition.SkipCost(exp, exp.EndAt), 0, "free when done")
		p.Gems = cost - 1
		t.no(Expedition.Skip(p, slot, NOW), "not enough gems")
		t.eq(p.Gems, cost - 1, "no charge")
		p.Gems = cost
		t.eq(Expedition.Skip(p, slot, NOW), cost, "skipped")
		t.eq(p.Gems, 0, "charged")
		t.no(Expedition.Skip(p, slot, NOW), "already finished")
		t.ok(Expedition.Claim(p, slot, NOW, 1), "claim now")
		t.no(Expedition.Skip(p, "9", NOW), "empty slot")
	end,
	["unknown area or duration rolls nothing"] = function(t)
		local p, uids = setup(1)
		local r = Expedition.RollReward(p, { Area = "X", Duration = "Short", Pets = uids, StartAt = 0, EndAt = 0, Seed = 1 })
		t.eq(r.Coins, 0, "coins")
		t.eq(#r.Pets, 0, "pets")
		t.eq(Economy.ExpeditionSlots(p), 1, "slots")
	end,
}
