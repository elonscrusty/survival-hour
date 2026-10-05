--!strict
-- Read-only pet helpers for the UI: display power, sorting, odds with luck.
-- Formulas come from the shared Logic modules (PetMath, Hatch, Economy) so
-- the UI always shows exactly what the server uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared:WaitForChild("Pets"))
local Eggs = require(Shared:WaitForChild("Eggs"))
local Types = require(Shared:WaitForChild("Types"))
local Logic = Shared:WaitForChild("Logic")
local PetMath = require(Logic:WaitForChild("PetMath"))
local HatchLogic = require(Logic:WaitForChild("Hatch"))
local Economy = require(Logic:WaitForChild("Economy"))

local State = require("./State")

type PetInstance = Types.PetInstance

local PetInfo = {}

function PetInfo.RarityIndex(rarity: string): number
	return math.max(1, PetMath.RarityIndex(rarity))
end

-- Island whose power multiplier gem pets use right now (the player's highest
-- opened island, as on the server).
function PetInfo.ScaleArea(): string?
	local d = State.Data
	if not d then
		return nil
	end
	return Economy.HighestArea(d :: any)
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

-- Base power of a species (rarity x island; gem pets use the scale island).
function PetInfo.BasePower(petId: string): number
	return PetMath.BasePower(petId, PetInfo.ScaleArea())
end

-- Power of a pet instance including variant, shiny and level.
function PetInfo.Power(p: PetInstance): number
	return PetMath.Power(p :: any, PetInfo.ScaleArea())
end

-- Key that groups pets that can be crafted together.
function PetInfo.CraftKey(p: PetInstance): string
	return p.Id .. "|" .. p.Variant .. "|" .. (if p.Shiny then "S" else "N")
end

function PetInfo.NextVariant(variant: string): string?
	return PetMath.NextVariant(variant)
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

-- Odds for an egg in percent: base (no luck) and boosted by the player's luck.
function PetInfo.Odds(eggId: string, luckMult: number): { OddsRow }
	local egg = Eggs.ById[eggId]
	local rows: { OddsRow } = {}
	if not egg then
		return rows
	end
	local base = HatchLogic.Odds(egg, 1)
	local boosted = HatchLogic.Odds(egg, luckMult)
	for _, o in egg.Odds do
		table.insert(rows, { Pet = o.Pet, Base = base[o.Pet] or 0, Boosted = boosted[o.Pet] or 0 })
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
