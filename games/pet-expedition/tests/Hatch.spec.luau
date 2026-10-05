-- Egg rolls and luck.
local Hatch = require("../src/shared/Logic/Hatch")
local Rng = require("../src/shared/Logic/Rng")
local Config = require("../src/shared/Config")
local Eggs = require("../src/shared/Eggs")

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

return {
	["odds without luck match the catalogue"] = function(t)
		for _, egg in Eggs.List do
			local odds = Hatch.Odds(egg, 1)
			local sum = 0
			for _, o in egg.Odds do
				t.ok(near(odds[o.Pet], o.Weight), egg.Id .. " " .. o.Pet)
				sum += odds[o.Pet]
			end
			t.ok(near(sum, 100), egg.Id .. " sums to 100")
		end
	end,
	["luck boosts Rare and above and renormalises"] = function(t)
		local egg = Eggs.ById.MeadowEgg
		local base = Hatch.Odds(egg, 1)
		local lucky = Hatch.Odds(egg, 2)
		t.ok(lucky.Bunny > base.Bunny, "rare up")
		t.ok(lucky.HoneyBear > base.HoneyBear, "legendary up")
		t.ok(lucky.Puppy < base.Puppy, "common down")
		local sum = 0
		for _, v in lucky do
			sum += v
		end
		t.ok(near(sum, 100), "still 100")
		-- Rare vs Epic keep their ratio (both multiplied).
		t.ok(near(lucky.Bunny / lucky.Fox, base.Bunny / base.Fox), "ratio kept")
	end,
	["luck is clamped"] = function(t)
		local egg = Eggs.ById.StarEgg
		local capped = Hatch.Odds(egg, Config.MaxLuckMult)
		local over = Hatch.Odds(egg, 1e9)
		t.ok(near(capped.CosmicUnicorn, over.CosmicUnicorn), "capped at MaxLuckMult")
		local base = Hatch.Odds(egg, 1)
		for _, bad in { 0, -3, 0 / 0, math.huge } do
			local o = Hatch.Odds(egg, bad)
			if bad == math.huge then
				t.ok(near(o.CosmicUnicorn, base.CosmicUnicorn), "inf treated as 1")
			else
				t.ok(near(o.CosmicUnicorn, base.CosmicUnicorn), "bad luck " .. tostring(bad))
			end
		end
	end,
	["Pick handles roll edges"] = function(t)
		local egg = Eggs.ById.MeadowEgg
		t.eq(Hatch.Pick(egg, 1, 0), "Puppy", "roll 0")
		t.eq(Hatch.Pick(egg, 1, 0.9999999), "HoneyBear", "roll near 1")
		t.eq(Hatch.Pick(egg, 1, 1), "HoneyBear", "roll 1")
		t.eq(Hatch.Pick(egg, 1, 5), "HoneyBear", "roll above 1 clamps")
		t.eq(Hatch.Pick(egg, 1, -1), "Puppy", "negative roll clamps")
		t.eq(Hatch.Pick(egg, 1, 0 / 0), "Puppy", "nan roll")
	end,
	["rolls match the odds statistically"] = function(t)
		local egg = Eggs.ById.MeadowEgg
		local rng = Rng.New(99)
		local counts = {}
		local n = 40000
		local shinies = 0
		for _ = 1, n do
			local id, shiny = Hatch.Roll(egg, 1, rng)
			counts[id] = (counts[id] or 0) + 1
			if shiny then
				shinies += 1
			end
		end
		t.ok(math.abs(counts.Puppy / n - 0.55) < 0.015, "puppy " .. counts.Puppy)
		t.ok(math.abs(counts.Kitten / n - 0.30) < 0.015, "kitten " .. counts.Kitten)
		t.ok(math.abs(shinies / n - Config.ShinyChance) < 0.004, "shiny rate " .. shinies)
	end,
	["rolls only produce pets from the egg"] = function(t)
		local rng = Rng.New(5)
		for _, egg in Eggs.List do
			local allowed = {}
			for _, o in egg.Odds do
				allowed[o.Pet] = true
			end
			for _ = 1, 300 do
				local id = Hatch.Roll(egg, 6, rng)
				t.ok(allowed[id], egg.Id .. " gave " .. id)
			end
		end
	end,
}
