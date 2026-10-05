--!strict
-- Read-only pet helpers for the UI: display power, sorting, odds with luck.
-- The server is the authority (Logic/PetMath and Logic/Hatch); these mirror
-- the documented formulas only so the UI can sort and preview.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pets = require(Shared:WaitForChild("Pets"))
local Areas = require(Shared:WaitForChild("Areas"))
local Eggs = require(Shared:WaitForChild("Eggs"))
local Types = require(Shared:WaitForChild("Types"))

type PetInstance = Types.PetInstance

local PetInfo = {}

local rarityIndex: { [string]: number } = {}
for i, r in Config.Rarities do
	rarityIndex[r] = i
end

function PetInfo.RarityIndex(rarity: string): number
	return rarityIndex[rarity] or 1
end

function PetInfo.Species(petId: string): Pets.Pet?
	return Pets.ById[petId]
end

function PetInfo.Name(petId: string): string
	local s = Pets.ById[petId]
	return if s then s.Name else petId
end

function PetInfo.Rarity(petId: string): string
	local s = Pets.ById[petId]
	return if s then s.Rarity else "Common"
end

-- Base power of a species (rarity x island).
function PetInfo.BasePower(petId: string): number
	local s = Pets.ById[petId]
	if not s then
		return 1
	end
	local area = Areas.ById[s.Area]
	return (Config.RarityPower[s.Rarity] or 1) * (if area then area.PowerMult else 1)
end

-- Power of a pet instance including variant, shiny and level.
function PetInfo.Power(p: PetInstance): number
	local power = PetInfo.BasePower(p.Id)
	power *= Config.VariantPower[p.Variant] or 1
	if p.Shiny then
		power *= Config.ShinyPower
	end
	power *= 1 + Config.PetLevelPower * math.max(0, (p.Level or 1) - 1)
	return power
end

-- Key that groups pets that can be crafted together.
function PetInfo.CraftKey(p: PetInstance): string
	return p.Id .. "|" .. p.Variant .. "|" .. (if p.Shiny then "S" else "N")
end

function PetInfo.NextVariant(variant: string): string?
	local i = table.find(Config.Variants, variant)
	if not i then
		return nil
	end
	return Config.Variants[i + 1]
end

-- Display name like "Golden Fox" or "Shiny Rainbow Puppy".
function PetInfo.FullName(p: PetInstance): string
	local name = PetInfo.Name(p.Id)
	if p.Variant ~= "Normal" then
		name = p.Variant .. " " .. name
	end
	if p.Shiny then
		name = "Shiny " .. name
	end
	return name
end

export type OddsRow = { Pet: string, Base: number, Boosted: number }

-- Odds for an egg in percent. Luck multiplies the weight of Rare and above,
-- then everything is renormalised to 100.
function PetInfo.Odds(eggId: string, luckMult: number): { OddsRow }
	local egg = Eggs.ById[eggId]
	local rows: { OddsRow } = {}
	if not egg then
		return rows
	end
	local rareIdx = PetInfo.RarityIndex("Rare")
	local baseTotal, boostTotal = 0, 0
	local weights: { number } = {}
	for i, o in egg.Odds do
		baseTotal += o.Weight
		local w = o.Weight
		if PetInfo.RarityIndex(PetInfo.Rarity(o.Pet)) >= rareIdx then
			w *= math.max(1, luckMult)
		end
		weights[i] = w
		boostTotal += w
	end
	for i, o in egg.Odds do
		table.insert(rows, {
			Pet = o.Pet,
			Base = if baseTotal > 0 then o.Weight / baseTotal * 100 else 0,
			Boosted = if boostTotal > 0 then weights[i] / boostTotal * 100 else 0,
		})
	end
	return rows
end

-- Sort: equipped first, then power, rarity and name.
function PetInfo.Sort(list: { PetInstance }, equipped: { string }?)
	local eq: { [string]: boolean } = {}
	if equipped then
		for _, uid in equipped do
			eq[uid] = true
		end
	end
	local power: { [string]: number } = {}
	for _, p in list do
		power[p.Uid] = PetInfo.Power(p)
	end
	table.sort(list, function(a, b)
		local ea, eb = eq[a.Uid] == true, eq[b.Uid] == true
		if ea ~= eb then
			return ea
		end
		local pa, pb = power[a.Uid], power[b.Uid]
		if pa ~= pb then
			return pa > pb
		end
		if a.Id ~= b.Id then
			return a.Id < b.Id
		end
		return a.Uid < b.Uid
	end)
end

return PetInfo
