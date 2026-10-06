--!strict
-- Eggs and their odds. Every egg rolls three things independently:
--   species  (Species weights, base species only)
--   rarity   (Rarity weights, luck applies to every rarity above the lowest listed)
--   element  (Element weights; region eggs favour their region's element)
-- Weights are percentages and each table sums to 100. Odds are always shown to
-- players before buying (Roblox rule for paid random items).
--
-- Kind:
--   Basic    bought with coins at an region's egg stand
--   Premium  bought with gems (gems can be bought with Robux) at the hub
--   Limited  bought with gems only between StartAt and EndAt (UTC unix time);
--            creatures from it carry the egg's Edition tag forever
--   Fused    never sold; made by fusion (odds come from the parents, Logic/Fusion)

export type Weight = { Id: string, Weight: number }
export type Egg = {
	Id: string,
	Name: string,
	Kind: string,
	Area: string, -- region whose stand sells it (Premium/Limited: "Meadow" hub)
	Currency: string, -- "Coins" | "Gems" | "None"
	Cost: number,
	IncubateSeconds: number,
	Species: { Weight },
	Rarity: { Weight },
	Element: { Weight }?, -- nil = Logic/Hatch builds it from the region (HomeElementWeight)
	Edition: string?,
	StartAt: number?,
	EndAt: number?,
}

local Eggs = {}

local basicSpecies: { Weight } = {
	{ Id = "Dragon", Weight = 25 }, { Id = "Griffin", Weight = 25 }, { Id = "Unicorn", Weight = 20 },
	{ Id = "Phoenix", Weight = 15 }, { Id = "Hydra", Weight = 15 },
}
local basicRarity: { Weight } = {
	{ Id = "Common", Weight = 60 }, { Id = "Rare", Weight = 28 }, { Id = "Epic", Weight = 9 },
	{ Id = "Legendary", Weight = 2.7 }, { Id = "Mythic", Weight = 0.3 },
}
local evenElements: { Weight } = {
	{ Id = "Fire", Weight = 20 }, { Id = "Ice", Weight = 20 }, { Id = "Storm", Weight = 20 },
	{ Id = "Nature", Weight = 20 }, { Id = "Shadow", Weight = 20 },
}

Eggs.List = {
	{ Id = "MeadowEgg", Name = "Meadow Egg", Kind = "Basic", Area = "Meadow", Currency = "Coins", Cost = 100, IncubateSeconds = 60, Species = basicSpecies, Rarity = basicRarity },
	{ Id = "ShadowEgg", Name = "Shadow Egg", Kind = "Basic", Area = "Shadow", Currency = "Coins", Cost = 3600, IncubateSeconds = 120, Species = basicSpecies, Rarity = basicRarity },
	{ Id = "FrostEgg", Name = "Frost Egg", Kind = "Basic", Area = "Frost", Currency = "Coins", Cost = 72000, IncubateSeconds = 240, Species = basicSpecies, Rarity = basicRarity },
	{ Id = "StormEgg", Name = "Storm Egg", Kind = "Basic", Area = "Storm", Currency = "Coins", Cost = 1.5e6, IncubateSeconds = 480, Species = basicSpecies, Rarity = basicRarity },
	{ Id = "VolcanoEgg", Name = "Volcano Egg", Kind = "Basic", Area = "Volcano", Currency = "Coins", Cost = 3e7, IncubateSeconds = 900, Species = basicSpecies, Rarity = basicRarity },
	{ Id = "SkyEgg", Name = "Sky Egg", Kind = "Basic", Area = "Sky", Currency = "Coins", Cost = 5.4e8, IncubateSeconds = 1500, Species = basicSpecies, Element = evenElements, Rarity = {
		{ Id = "Common", Weight = 55 }, { Id = "Rare", Weight = 30 }, { Id = "Epic", Weight = 11 },
		{ Id = "Legendary", Weight = 3.5 }, { Id = "Mythic", Weight = 0.5 },
	} },

	{ Id = "MythicEgg", Name = "Mythic Egg", Kind = "Premium", Area = "Meadow", Currency = "Gems", Cost = 400, IncubateSeconds = 300, Species = basicSpecies, Element = evenElements, Rarity = {
		{ Id = "Rare", Weight = 55 }, { Id = "Epic", Weight = 32 }, { Id = "Legendary", Weight = 11 }, { Id = "Mythic", Weight = 2 },
	} },

	-- Limited egg template: set StartAt/EndAt (UTC) and an Edition for each season.
	{ Id = "FrostfireEgg", Name = "Frostfire Egg", Kind = "Limited", Area = "Meadow", Currency = "Gems", Cost = 750, IncubateSeconds = 600,
		Edition = "Frostfire 2026", StartAt = 1796083200 --[[ 2026-12-01 ]], EndAt = 1798761600 --[[ 2027-01-01 ]],
		Species = { { Id = "Dragon", Weight = 40 }, { Id = "Phoenix", Weight = 30 }, { Id = "Unicorn", Weight = 30 } },
		Element = { { Id = "Fire", Weight = 50 }, { Id = "Ice", Weight = 50 } },
		Rarity = { { Id = "Epic", Weight = 62 }, { Id = "Legendary", Weight = 30 }, { Id = "Mythic", Weight = 8 } } },

	{ Id = "FusedEgg", Name = "Fused Egg", Kind = "Fused", Area = "Meadow", Currency = "None", Cost = 0, IncubateSeconds = 900,
		Species = basicSpecies, Element = evenElements, Rarity = basicRarity },
} :: { Egg }

Eggs.ById = {} :: { [string]: Egg }
for _, e in Eggs.List do
	Eggs.ById[e.Id] = e
end

-- Is a Limited egg on sale at unix time `now`? Other kinds are always "on sale" (Fused never sold).
function Eggs.OnSale(egg: Egg, now: number): boolean
	if egg.Kind == "Fused" then
		return false
	end
	if egg.Kind == "Limited" then
		return egg.StartAt ~= nil and egg.EndAt ~= nil and now >= (egg.StartAt :: number) and now < (egg.EndAt :: number)
	end
	return true
end

return Eggs
