--!strict
local Hatch = require("../src/shared/Logic/Hatch")
local Rng = require("../src/shared/Logic/Rng")
local Config = require("../src/shared/Config")
local Eggs = require("../src/shared/Eggs")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-8
end

local function fused(): Hatch.Fused
	return {
		Species = { { Id = "Dragon", Weight = 50 }, { Id = "Griffin", Weight = 50 } },
		Rarity = { { Id = "Epic", Weight = 0.65 }, { Id = "Legendary", Weight = 0.35 } },
		Element = { { Id = "Fire", Weight = 50 }, { Id = "Ice", Weight = 50 } },
		Hybrid = "Wyvern", HybridChance = 0.08,
	}
end

return {
	["three odds tables sum to 100 and preserve catalogue odds"] = function(t: any)
		for _, egg in Eggs.List do
			if egg.Kind == "Fused" then continue end
			local odds = Hatch.Odds(egg, 1)
			for _, axis in { odds.Species, odds.Rarity, odds.Element } do
				local sum = 0
				for _, value in axis do sum += value end
				t.ok(near(sum, 100), egg.Id)
			end
			for _, weight in egg.Species do t.ok(near(odds.Species[weight.Id], weight.Weight)) end
			for _, weight in egg.Rarity do t.ok(near(odds.Rarity[weight.Id], weight.Weight)) end
		end
	end,
	["home element is 60 percent and the other four are 10"] = function(t: any)
		local odds = Hatch.Odds(Eggs.ById.MeadowEgg, 1).Element
		t.ok(near(odds.Nature, 60))
		for _, id in { "Fire", "Ice", "Storm", "Shadow" } do t.ok(near(odds[id], 10)) end
	end,
	["explicit elements override the home region"] = function(t: any)
		local odds = Hatch.Odds(Eggs.ById.FrostfireEgg, 6).Element
		t.eq(odds.Fire, 50); t.eq(odds.Ice, 50); t.eq(odds.Nature, nil)
	end,
	["luck boosts every rarity above the lowest without affecting other axes"] = function(t: any)
		for _, egg in { Eggs.ById.MeadowEgg, Eggs.ById.MythicEgg, Eggs.ById.FrostfireEgg } do
			local base, lucky = Hatch.Odds(egg, 1), Hatch.Odds(egg, 2)
			local lowest = egg.Rarity[1].Id
			t.ok(lucky.Rarity[lowest] < base.Rarity[lowest])
			for i = 2, #egg.Rarity do
				local id = egg.Rarity[i].Id
				t.ok(lucky.Rarity[id] > base.Rarity[id])
				t.ok(near(lucky.Rarity[id] / lucky.Rarity[lowest], 2 * base.Rarity[id] / base.Rarity[lowest]))
			end
			for id, value in base.Species do t.eq(lucky.Species[id], value) end
			for id, value in base.Element do t.eq(lucky.Element[id], value) end
		end
	end,
	["luck clamps invalid and excessive values"] = function(t: any)
		for _, value in { 0, -2, 0 / 0, math.huge, -math.huge } do t.eq(Hatch.ClampLuck(value), 1) end
		t.eq(Hatch.ClampLuck(1e9), Config.MaxLuckMult)
	end,
	["weighted pick skips zero weights at both boundaries"] = function(t: any)
		local weights = { { Id = "zero", Weight = 0 }, { Id = "a", Weight = 25 }, { Id = "b", Weight = 75 }, { Id = "lastzero", Weight = 0 } }
		t.eq(Hatch.Pick(weights, 0), "a"); t.eq(Hatch.Pick(weights, 0.25), "b")
		for _, roll in { 1, 5 } do t.eq(Hatch.Pick(weights, roll), "b") end
		for _, roll in { -1, 0 / 0, math.huge } do t.eq(Hatch.Pick(weights, roll), "a") end
	end,
	["each result consumes exactly three independent random values"] = function(t: any)
		local count = 0
		local rolls = { 0, 0.99, 0.5 }
		local rng: any = { Next = function() count += 1; return rolls[count] end }
		local result = Hatch.Roll(Eggs.ById.MeadowEgg, 1, rng)
		t.eq(count, 3); t.eq(result.Species, "Dragon"); t.eq(result.Rarity, "Legendary"); t.eq(result.Element, "Nature")
	end,
	["same seed produces the same result"] = function(t: any)
		local a, b = Rng.New(314), Rng.New(314)
		for _ = 1, 100 do
			local x, y = Hatch.Roll(Eggs.ById.MythicEgg, 3, a), Hatch.Roll(Eggs.ById.MythicEgg, 3, b)
			t.eq(x.Species, y.Species); t.eq(x.Rarity, y.Rarity); t.eq(x.Element, y.Element)
		end
	end,
	["fused eggs use parent odds and fold hybrid chance into the species roll"] = function(t: any)
		local odds = Hatch.Odds(Eggs.ById.FusedEgg, 1, fused())
		t.ok(near(odds.Species.Dragon, 46)); t.ok(near(odds.Species.Griffin, 46)); t.ok(near(odds.Species.Wyvern, 8))
		t.ok(near(odds.Rarity.Epic, 65)); t.ok(near(odds.Rarity.Legendary, 35))
		t.eq(odds.Element.Fire, 50); t.eq(odds.Element.Ice, 50)
		local rng: any = { Next = function() return 0.99 end }
		t.eq(Hatch.Roll(Eggs.ById.FusedEgg, 1, rng, fused()).Species, "Wyvern")
	end,
	["ordinary eggs never hatch hidden hybrids"] = function(t: any)
		local rng = Rng.New(18)
		for _, egg in Eggs.List do
			if egg.Kind == "Fused" then continue end
			local allowed: { [string]: boolean } = {}
			for _, weight in egg.Species do allowed[weight.Id] = true end
			for _ = 1, 300 do t.ok(allowed[Hatch.Roll(egg, 6, rng).Species]) end
		end
	end,
	["fused catalogue placeholder cannot hatch without parent odds"] = function(t: any)
		t.no(pcall(function() Hatch.Roll(Eggs.ById.FusedEgg, 1, Rng.New(1)) end))
	end,
	["invalid weight tables fail instead of awarding a creature"] = function(t: any)
		for _, weights in { {}, { { Id = "a", Weight = 0 } }, { { Id = "a", Weight = -1 } }, { { Id = "a", Weight = 0 / 0 } } } do
			t.no(pcall(Hatch.Pick, weights, 0))
		end
	end,
	["seeded rolls follow species rarity and element distributions"] = function(t: any)
		local rng = Rng.New(99)
		local species, rarity, element = 0, 0, 0
		local n = 40000
		for _ = 1, n do
			local result = Hatch.Roll(Eggs.ById.MeadowEgg, 1, rng)
			if result.Species == "Dragon" then species += 1 end
			if result.Rarity == "Common" then rarity += 1 end
			if result.Element == "Nature" then element += 1 end
		end
		t.ok(math.abs(species / n - 0.25) < 0.015)
		t.ok(math.abs(rarity / n - 0.60) < 0.015)
		t.ok(math.abs(element / n - 0.60) < 0.015)
	end,
}
