--!strict
-- Persisted seeds and luck ensure a hatch cannot be rerolled by waiting/rejoining.
local Config = require("../Config")
local Eggs = require("../Eggs")
local Types = require("../Types")
local Hatch = require("./Hatch")
local Rng = require("./Rng")
local Level = require("./Level")
local Incubation = {}
local function weights(source: { Eggs.Weight }): { Eggs.Weight }
	local copy: { Eggs.Weight } = {}
	for _, w in source do table.insert(copy, { Id = w.Id, Weight = w.Weight }) end
	return copy
end
function Incubation.New(item: Types.EggItem, now: number, seed: number, luck: number, fast: boolean): Types.Incubator
	local egg = Eggs.ById[item.Egg]
	assert(egg ~= nil and Level.IsFinite(now), "Invalid incubation")
	assert(Level.IsFinite(seed) and seed % 1 == 0 and seed >= 1 and seed < Rng.Modulus, "Invalid incubation seed")
	local stored: Types.EggItem = { Uid = item.Uid, Egg = item.Egg, Tier = item.Tier }
	if item.Fused then
		stored.Fused = { Species = weights(item.Fused.Species), Rarity = weights(item.Fused.Rarity),
			Element = weights(item.Fused.Element), Hybrid = item.Fused.Hybrid, HybridChance = item.Fused.HybridChance }
	end
	local capturedLuck = Hatch.ClampLuck(luck)
	Hatch.Weights(egg, capturedLuck, stored.Fused)
	return { Egg = stored, StartAt = now, EndAt = now + egg.IncubateSeconds * (if fast then Config.FastIncubationMult else 1), Seed = seed, Luck = capturedLuck }
end
function Incubation.Roll(slot: Types.Incubator, now: number): (Hatch.Result?, string?)
	if not Level.IsFinite(now) or now < slot.EndAt then return nil, "Egg is still incubating" end
	local egg = Eggs.ById[slot.Egg.Egg]
	if not egg then return nil, "Unknown egg" end
	return Hatch.Roll(egg, slot.Luck, Rng.New(slot.Seed), slot.Egg.Fused), nil
end
function Incubation.SkipCost(slot: Types.Incubator, now: number): number
	if not Level.IsFinite(now) or now < slot.StartAt then return 0 end
	local left = slot.EndAt - now
	if left <= 0 then return 0 end
	return math.max(Config.IncubateSkipMinGems, math.ceil(left / 30) * Config.IncubateSkipGemsPer30s)
end
function Incubation.Skip(slot: Types.Incubator, wallet: number, now: number): (boolean, number)
	if not Level.IsFinite(wallet) or not Level.IsFinite(now) or now < slot.StartAt then return false, 0 end
	local cost = Incubation.SkipCost(slot, now)
	if cost == 0 or wallet < cost then return false, 0 end
	slot.EndAt = now
	return true, cost
end
return Incubation
