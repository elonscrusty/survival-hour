--!strict
-- Independent species, rarity and element rolls. No Roblox dependencies.
local Config = require("../Config")
local Areas = require("../Areas")
local Elements = require("../Elements")
local Eggs = require("../Eggs")
local Rng = require("./Rng")

type Weight = Eggs.Weight
export type Fused = { Rarity: { Weight }, Species: { Weight }, Element: { Weight }, Hybrid: string?, HybridChance: number }
export type Tables = { Species: { Weight }, Rarity: { Weight }, Element: { Weight } }
export type Odds = { Species: { [string]: number }, Rarity: { [string]: number }, Element: { [string]: number } }
export type Result = { Species: string, Rarity: string, Element: string }
local Hatch = {}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function Hatch.ClampLuck(luck: number): number
	return if finite(luck) then math.clamp(luck, 1, Config.MaxLuckMult) else 1
end

local function total(weights: { Weight }): number
	local sum = 0
	for _, w in weights do
		assert(finite(w.Weight) and w.Weight >= 0, "Invalid hatch weight")
		sum += w.Weight
	end
	assert(finite(sum) and sum > 0, "Empty hatch odds")
	return sum
end

local function copy(weights: { Weight }): { Weight }
	total(weights)
	local out: { Weight } = {}
	for _, w in weights do table.insert(out, { Id = w.Id, Weight = w.Weight }) end
	return out
end

local function percent(weights: { Weight }): { [string]: number }
	local sum = total(weights)
	local out: { [string]: number } = {}
	for _, w in weights do out[w.Id] = (out[w.Id] or 0) + w.Weight / sum * 100 end
	return out
end

function Hatch.Weights(egg: Eggs.Egg, luck: number, fused: Fused?): Tables
	assert(egg.Kind ~= "Fused" or fused ~= nil, "Fused egg is missing parent odds")
	assert(fused == nil or egg.Kind == "Fused", "Parent odds require a fused egg")
	local species = copy(if fused then fused.Species else egg.Species)
	local rarity = copy(if fused then fused.Rarity else egg.Rarity)
	local lowest = math.huge
	for _, w in rarity do
		local index = table.find(Config.Rarities, w.Id)
		assert(index ~= nil, "Unknown rarity")
		if w.Weight > 0 then lowest = math.min(lowest, index :: number) end
	end
	local mult = Hatch.ClampLuck(luck)
	for _, w in rarity do
		if (table.find(Config.Rarities, w.Id) :: number) > lowest then w.Weight *= mult end
	end
	local element: { Weight } = {}
	local explicit = if fused then fused.Element else egg.Element
	if explicit then
		element = copy(explicit)
	else
		local area = Areas.ById[egg.Area]
		assert(area ~= nil, "Unknown egg region")
		local home = area.Element
		for _, e in Elements.List do
			local weight = if home == "" then 100 / #Elements.List
				elseif e.Id == home then Config.HomeElementWeight
				else (100 - Config.HomeElementWeight) / (#Elements.List - 1)
			table.insert(element, { Id = e.Id, Weight = weight })
		end
	end
	if fused and fused.Hybrid then
		local chance = fused.HybridChance
		assert(finite(chance) and chance >= 0 and chance <= 1, "Invalid hybrid chance")
		local sum = total(species)
		for _, w in species do w.Weight = w.Weight / sum * (1 - chance) end
		table.insert(species, { Id = fused.Hybrid, Weight = chance })
	end
	return { Species = species, Rarity = rarity, Element = element }
end

function Hatch.Odds(egg: Eggs.Egg, luck: number, fused: Fused?): Odds
	local weights = Hatch.Weights(egg, luck, fused)
	return { Species = percent(weights.Species), Rarity = percent(weights.Rarity), Element = percent(weights.Element) }
end

-- Boundary values are tolerated; zero-weight entries can never be selected.
function Hatch.Pick(weights: { Weight }, roll: number): string
	local sum = total(weights)
	if not finite(roll) then roll = 0 end
	local target = math.clamp(roll, 0, 1) * sum
	local acc = 0
	local last = ""
	for _, w in weights do
		if w.Weight > 0 then
			last = w.Id
			acc += w.Weight
			if target < acc then return w.Id end
		end
	end
	return last
end

function Hatch.Roll(egg: Eggs.Egg, luck: number, rng: Rng.Rng, fused: Fused?): Result
	local weights = Hatch.Weights(egg, luck, fused)
	local species = Hatch.Pick(weights.Species, rng:Next())
	local rarity = Hatch.Pick(weights.Rarity, rng:Next())
	local element = Hatch.Pick(weights.Element, rng:Next())
	return { Species = species, Rarity = rarity, Element = element }
end

return Hatch
