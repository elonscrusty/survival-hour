--!strict
-- The six islands, in unlock order. The world builder lays them out along +X;
-- each one has a gate (except the first), an egg stand, a breakable field and
-- one expedition destination. CoinMult scales breakable and expedition coins;
-- PowerMult is the island tier power of creatures that hatch here.

export type Breakable = { Kind: string, Weight: number, Hp: number, Coins: number, Gems: number? }
export type Area = {
	Id: string,
	Index: number,
	Name: string,
	GateCost: number, -- coins to open (0 = always open)
	CoinMult: number,
	PowerMult: number,
	Egg: string, -- Eggs id sold on this island
	Element: string, -- element its eggs favour ("" = none)
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
	{ Id = "Meadow", Index = 1, Name = "Sunny Meadow", Element = "Nature", GateCost = 0, CoinMult = 1, PowerMult = 1,
		Egg = "MeadowEgg", MaxBreakables = 40, Breakables = field,
		Blurb = "Flowers, hay bales and the friendliest pets around." },
	{ Id = "Shadow", Index = 2, Name = "Shadow Grove", Element = "Shadow", GateCost = 5000, CoinMult = 8, PowerMult = 6,
		Egg = "ShadowEgg", MaxBreakables = 40, Breakables = field,
		Blurb = "A twilight forest of glowing mushrooms." },
	{ Id = "Frost", Index = 3, Name = "Frost Peaks", Element = "Ice", GateCost = 120000, CoinMult = 64, PowerMult = 36,
		Egg = "FrostEgg", MaxBreakables = 40, Breakables = field,
		Blurb = "Icy cliffs and frozen waterfalls." },
	{ Id = "Storm", Index = 4, Name = "Storm Coast", Element = "Storm", GateCost = 2.7e6, CoinMult = 512, PowerMult = 216,
		Egg = "StormEgg", MaxBreakables = 40, Breakables = field,
		Blurb = "Windswept beaches under thunderclouds." },
	{ Id = "Volcano", Index = 5, Name = "Ember Volcano", Element = "Fire", GateCost = 5.4e7, CoinMult = 4096, PowerMult = 1296,
		Egg = "VolcanoEgg", MaxBreakables = 40, Breakables = field,
		Blurb = "Lava rivers, hot rocks and fire-proof friends." },
	{ Id = "Sky", Index = 6, Name = "Sky Isles", Element = "", GateCost = 1.1e9, CoinMult = 32768, PowerMult = 7776,
		Egg = "SkyEgg", MaxBreakables = 40, Breakables = field,
		Blurb = "Floating islands above the clouds." },
} :: { Area }

Areas.ById = {} :: { [string]: Area }
for _, a in Areas.List do
	Areas.ById[a.Id] = a
end

return Areas
