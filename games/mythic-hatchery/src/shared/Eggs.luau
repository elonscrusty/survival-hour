--!strict
-- Eggs and their odds. Weights are percentages and each egg sums to 100.
-- Odds are always shown to players before they hatch (Roblox rule for paid
-- random items, and fair anyway). Luck multiplies the weight of Rare and
-- above (Logic/Hatch renormalises).

export type Odds = { Pet: string, Weight: number }
export type Egg = {
	Id: string,
	Name: string,
	Area: string,
	Currency: string, -- "Coins" | "Gems"
	Cost: number,
	Odds: { Odds },
}

local Eggs = {}

Eggs.List = {
	{ Id = "MeadowEgg", Name = "Meadow Egg", Area = "Meadow", Currency = "Coins", Cost = 100, Odds = {
		{ Pet = "Puppy", Weight = 55 }, { Pet = "Kitten", Weight = 30 }, { Pet = "Bunny", Weight = 12 },
		{ Pet = "Fox", Weight = 2.7 }, { Pet = "HoneyBear", Weight = 0.3 },
	} },
	{ Id = "GroveEgg", Name = "Grove Egg", Area = "Grove", Currency = "Coins", Cost = 3600, Odds = {
		{ Pet = "Toadstool", Weight = 55 }, { Pet = "Snail", Weight = 30 }, { Pet = "Frog", Weight = 12 },
		{ Pet = "Owl", Weight = 2.7 }, { Pet = "GlowcapDragon", Weight = 0.3 },
	} },
	{ Id = "FrostEgg", Name = "Frost Egg", Area = "Frost", Currency = "Coins", Cost = 72000, Odds = {
		{ Pet = "Penguin", Weight = 55 }, { Pet = "SnowBunny", Weight = 30 }, { Pet = "ArcticFox", Weight = 12 },
		{ Pet = "Yeti", Weight = 2.7 }, { Pet = "AuroraWolf", Weight = 0.3 },
	} },
	{ Id = "CoralEgg", Name = "Coral Egg", Area = "Coral", Currency = "Coins", Cost = 1.5e6, Odds = {
		{ Pet = "Crab", Weight = 55 }, { Pet = "Turtle", Weight = 30 }, { Pet = "Pufferfish", Weight = 12 },
		{ Pet = "Octopus", Weight = 2.7 }, { Pet = "Narwhal", Weight = 0.3 },
	} },
	{ Id = "VolcanoEgg", Name = "Volcano Egg", Area = "Volcano", Currency = "Coins", Cost = 3e7, Odds = {
		{ Pet = "LavaSlime", Weight = 55 }, { Pet = "Salamander", Weight = 30 }, { Pet = "EmberBat", Weight = 12 },
		{ Pet = "LavaGolem", Weight = 2.7 }, { Pet = "InfernoDragon", Weight = 0.3 },
	} },
	{ Id = "StarEgg", Name = "Star Egg", Area = "Starfall", Currency = "Coins", Cost = 5.4e8, Odds = {
		{ Pet = "CometCat", Weight = 55 }, { Pet = "MoonBunny", Weight = 30 }, { Pet = "NebulaFox", Weight = 12 },
		{ Pet = "GalaxyAxolotl", Weight = 2.65 }, { Pet = "CelestialDragon", Weight = 0.3 }, { Pet = "CosmicUnicorn", Weight = 0.05 },
	} },
	-- Premium egg: bought with gems (earnable in play or bought with Robux).
	-- Hidden for players whose PolicyService says paid random items are restricted.
	{ Id = "PrismEgg", Name = "Prism Egg", Area = "Meadow", Currency = "Gems", Cost = 400, Odds = {
		{ Pet = "CrystalPup", Weight = 62 }, { Pet = "PrismFox", Weight = 30 },
		{ Pet = "RainbowUnicorn", Weight = 7 }, { Pet = "DiamondDragon", Weight = 1 },
	} },
} :: { Egg }

Eggs.ById = {} :: { [string]: Egg }
for _, e in Eggs.List do
	Eggs.ById[e.Id] = e
end

return Eggs
