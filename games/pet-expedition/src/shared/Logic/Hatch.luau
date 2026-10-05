--!strict
-- Egg rolls. Luck multiplies the weight of every pet rarer than the egg's
-- lowest rarity (so it also works on the Prism Egg, whose lowest is Rare);
-- the weights are then renormalised (the roll picks against their new
-- total). Luck is clamped to [1, Config.MaxLuckMult].

local Config = require("../Config")
local Pets = require("../Pets")
local Eggs = require("../Eggs")
local PetMath = require("./PetMath")
local Schema = require("./Schema")
local Rng = require("./Rng")

local Hatch = {}


function Hatch.ClampLuck(luck: number): number
	if not Schema.IsFinite(luck) then
		return 1
	end
	return math.clamp(luck, 1, Config.MaxLuckMult)
end

-- Effective weights for an egg at a luck level: { { Pet, Weight } }.
function Hatch.Weights(egg: Eggs.Egg, luck: number): { Eggs.Odds }
	luck = Hatch.ClampLuck(luck)
	local lowest = math.huge
	for _, o in egg.Odds do
		local def = Pets.ById[o.Pet]
		if def then
			lowest = math.min(lowest, PetMath.RarityIndex(def.Rarity))
		end
	end
	local out: { Eggs.Odds } = {}
	for _, o in egg.Odds do
		local def = Pets.ById[o.Pet]
		local w = o.Weight
		if def and PetMath.RarityIndex(def.Rarity) > lowest then
			w *= luck
		end
		table.insert(out, { Pet = o.Pet, Weight = w })
	end
	return out
end

-- Odds in percent (sums to 100) for showing to players.
function Hatch.Odds(egg: Eggs.Egg, luck: number): { [string]: number }
	local weights = Hatch.Weights(egg, luck)
	local total = 0
	for _, o in weights do
		total += o.Weight
	end
	local out: { [string]: number } = {}
	for _, o in weights do
		out[o.Pet] = if total > 0 then o.Weight / total * 100 else 0
	end
	return out
end

-- Picks a pet id. `roll` is a number in [0, 1).
function Hatch.Pick(egg: Eggs.Egg, luck: number, roll: number): string
	local weights = Hatch.Weights(egg, luck)
	local total = 0
	for _, o in weights do
		total += o.Weight
	end
	if not Schema.IsFinite(roll) then
		roll = 0
	end
	local target = math.clamp(roll, 0, 1) * total
	local acc = 0
	for _, o in weights do
		acc += o.Weight
		if target < acc then
			return o.Pet
		end
	end
	return weights[#weights].Pet
end

-- Full roll with an Rng: returns the pet id and whether it is shiny.
function Hatch.Roll(egg: Eggs.Egg, luck: number, rng: Rng.Rng): (string, boolean)
	local id = Hatch.Pick(egg, luck, rng:Next())
	local shiny = rng:Next() < Config.ShinyChance
	return id, shiny
end

return Hatch
