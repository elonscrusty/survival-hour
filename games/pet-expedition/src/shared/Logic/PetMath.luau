--!strict
-- Pet power and levels.
--   Power = RarityPower[rarity] * area PowerMult * VariantPower * (ShinyPower if shiny)
--           * (1 + PetLevelPower * (level - 1))
--
-- Gem pets (Source "Gem", from the Prism Egg) have no home island of their
-- own: they use the PowerMult of `scaleArea`, which callers set to the
-- player's highest opened island (Economy.HighestArea) at the moment power
-- is used. Without a scaleArea they count as Meadow pets. So gems buy a pet
-- that is strong for where the player already is, never a progression skip.

local Config = require("../Config")
local Pets = require("../Pets")
local Areas = require("../Areas")
local Schema = require("./Schema")

type PetInstance = Schema.PetInstance

local PetMath = {}

function PetMath.RarityIndex(rarity: string): number
	return table.find(Config.Rarities, rarity) or 0
end

PetMath.GemScaleDefault = "Meadow"

-- True for pets whose power follows the owner's progress (Prism Egg pets).
function PetMath.IsScaling(petId: string): boolean
	local def = Pets.ById[petId]
	return def ~= nil and def.Source == "Gem"
end

-- The island whose multipliers a pet uses.
function PetMath.PowerArea(petId: string, scaleArea: string?): Areas.Area?
	local def = Pets.ById[petId]
	if not def then
		return nil
	end
	if def.Source == "Gem" then
		return Areas.ById[scaleArea or PetMath.GemScaleDefault] or Areas.ById[PetMath.GemScaleDefault]
	end
	return Areas.ById[def.Area]
end

-- Power of a level 1, Normal, non-shiny pet of this species (0 if unknown).
function PetMath.BasePower(petId: string, scaleArea: string?): number
	local def = Pets.ById[petId]
	if not def then
		return 0
	end
	local area = PetMath.PowerArea(petId, scaleArea)
	local areaMult = if area then area.PowerMult else 1
	return (Config.RarityPower[def.Rarity] or 1) * areaMult
end

function PetMath.Power(pet: PetInstance, scaleArea: string?): number
	local base = PetMath.BasePower(pet.Id, scaleArea)
	local variant = Config.VariantPower[pet.Variant] or 1
	local shiny = if pet.Shiny then Config.ShinyPower else 1
	local level = Schema.ClampInt(pet.Level, 1, Config.PetMaxLevel)
	return base * variant * shiny * (1 + Config.PetLevelPower * (level - 1))
end

-- The variant a craft produces from `variant`, or nil when it is the last one.
function PetMath.NextVariant(variant: string): string?
	local i = table.find(Config.Variants, variant)
	if not i or i >= #Config.Variants then
		return nil
	end
	return Config.Variants[i + 1]
end

-- XP needed to go from `level` to `level + 1`.
function PetMath.XpToNext(level: number): number
	return math.max(1, Config.PetXpForLevel(level))
end

-- Adds XP to a pet (mutates it). Returns the number of levels gained.
function PetMath.AddXp(pet: PetInstance, xp: number): number
	if not Schema.IsFinite(xp) or xp <= 0 then
		return 0
	end
	if pet.Level >= Config.PetMaxLevel then
		pet.Level = Config.PetMaxLevel
		pet.Xp = 0
		return 0
	end
	local gained = 0
	pet.Xp += math.floor(xp)
	while pet.Level < Config.PetMaxLevel and pet.Xp >= PetMath.XpToNext(pet.Level) do
		pet.Xp -= PetMath.XpToNext(pet.Level)
		pet.Level += 1
		gained += 1
	end
	if pet.Level >= Config.PetMaxLevel then
		pet.Level = Config.PetMaxLevel
		pet.Xp = 0
	end
	return gained
end

-- Coins refunded when a pet is deleted. Gem pets always refund at Meadow
-- level (never scaled), so gems can't be turned into coins for gates.
function PetMath.DeleteRefund(pet: PetInstance): number
	local area = PetMath.PowerArea(pet.Id, nil)
	local coinMult = if area then area.CoinMult else 1
	return math.max(1, math.floor(PetMath.Power(pet, nil) * coinMult * Config.DeleteRefund))
end

-- Sort comparator: strongest first (at `scaleArea`), ties broken by uid.
function PetMath.StrongerAt(scaleArea: string?): (PetInstance, PetInstance) -> boolean
	return function(a: PetInstance, b: PetInstance): boolean
		local pa, pb = PetMath.Power(a, scaleArea), PetMath.Power(b, scaleArea)
		if pa ~= pb then
			return pa > pb
		end
		return a.Uid < b.Uid
	end
end

PetMath.Stronger = PetMath.StrongerAt(nil)

return PetMath
