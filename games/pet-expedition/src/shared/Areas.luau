--!strict
-- The six islands, in unlock order. The world builder lays them out along +X;
-- each one has a gate (except the first), an egg stand, a breakable field and
-- one expedition destination. CoinMult scales breakable and expedition coins;
-- PowerMult scales the power of pets that hatch here.

export type Breakable = { Kind: string, Weight: number, Hp: number, Coins: number, Gems: number? }
export type Area = {
	Id: string,
	Index: number,
	Name: string,
	GateCost: number, -- coins to open (0 = always open)
	CoinMult: number,
	PowerMult: number,
	Egg: string, -- Eggs id sold on this island
	ExpeditionPet: string, -- Pets id that can only be found on expeditions here
	MaxBreakables: number,
	Breakables: { Breakable },
	Blurb: string,
}

local Areas = {}

-- Breakable kinds are shared across areas; Hp and Coins are multiplied by the
-- area's CoinMult at spawn time. Gems are flat.
local field: { Breakable } = {
	{ Kind = "CoinPile", Weight = 62, Hp = 100, Coins = 12 },
	{ Kind = "Crate", Weight = 26, Hp = 300, Coins = 40 },
	{ Kind = "Chest", Weight = 10.5, Hp = 1000, Coins = 150 },
	{ Kind = "GemRock", Weight = 1.5, Hp = 750, Coins = 20, Gems = 1 },
	{ Kind = "BigChest", Weight = 1, Hp = 6000, Coins = 1200, Gems = 2 },
}

Areas.List = {
	{ Id = "Meadow", Index = 1, Name = "Sunny Meadow", GateCost = 0, CoinMult = 1, PowerMult = 1,
		Egg = "MeadowEgg", ExpeditionPet = "SunflowerSprite", MaxBreakables = 40, Breakables = field,
		Blurb = "Flowers, hay bales and the friendliest pets around." },
	{ Id = "Grove", Index = 2, Name = "Mushroom Grove", GateCost = 5000, CoinMult = 8, PowerMult = 6,
		Egg = "GroveEgg", ExpeditionPet = "FairyMoth", MaxBreakables = 40, Breakables = field,
		Blurb = "Glowing caps and sleepy forest critters." },
	{ Id = "Frost", Index = 3, Name = "Frostbite Peaks", GateCost = 120000, CoinMult = 64, PowerMult = 36,
		Egg = "FrostEgg", ExpeditionPet = "PolarKing", MaxBreakables = 40, Breakables = field,
		Blurb = "Snowy cliffs where the toughest fluff lives." },
	{ Id = "Coral", Index = 4, Name = "Coral Cove", GateCost = 2.7e6, CoinMult = 512, PowerMult = 216,
		Egg = "CoralEgg", ExpeditionPet = "PearlSeahorse", MaxBreakables = 40, Breakables = field,
		Blurb = "Warm sand, tide pools and sunken treasure." },
	{ Id = "Volcano", Index = 5, Name = "Ember Volcano", GateCost = 5.4e7, CoinMult = 4096, PowerMult = 1296,
		Egg = "VolcanoEgg", ExpeditionPet = "Phoenix", MaxBreakables = 40, Breakables = field,
		Blurb = "Lava rivers, hot rocks and fire-proof friends." },
	{ Id = "Starfall", Index = 6, Name = "Starfall Isles", GateCost = 1.1e9, CoinMult = 32768, PowerMult = 7776,
		Egg = "StarEgg", ExpeditionPet = "VoidKraken", MaxBreakables = 40, Breakables = field,
		Blurb = "Floating islands at the edge of space." },
} :: { Area }

Areas.ById = {} :: { [string]: Area }
for _, a in Areas.List do
	Areas.ById[a.Id] = a
end

return Areas
