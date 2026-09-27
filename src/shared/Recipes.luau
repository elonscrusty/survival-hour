--!strict
-- Crafting recipes and workbench upgrades. Pure data (no Roblox types) so the
-- CLI test-suite can load it directly.
--
-- Kind "Equipment": paid from the crafter's own resource pack, result goes to inventory.
-- Kind "Structure": grants a placement; paid on placement from pack first, then team storage.
-- Kind "Ammo": paid from the pack, result goes to the ammo pouch.

export type Recipe = {
	Id: string,
	Result: string,
	Count: number,
	Level: number, -- workbench level required (0 = no workbench needed)
	Kind: string,
	Cost: { [string]: number },
	Order: number,
}

local Recipes = {}

-- Survival Wars tiers (spec): the Workbench is pre-placed at Tier I and upgrades
-- only unlock recipes. Costs are deliberately grindy; all numbers are tunable.
-- Plant = Fiber. Tier III+ needs Scrap, IV+ Iron, V Rare Components (POIs/caves/chests).
Recipes.List = {
	-- Anywhere (no workbench)
	{ Id = "Rope", Result = "Rope", Count = 1, Level = 0, Kind = "Resource", Cost = { Plant = 3 }, Order = 0 },
	{ Id = "Bandage", Result = "Bandage", Count = 1, Level = 0, Kind = "Consumable", Cost = { Plant = 4 }, Order = 1 },

	-- Tier I: crude tools, first walls and storage
	{ Id = "CrudeAxe", Result = "CrudeAxe", Count = 1, Level = 1, Kind = "Equipment", Cost = { Stick = 8, Stone = 3, Plant = 3 }, Order = 10 },
	{ Id = "CrudePickaxe", Result = "CrudePickaxe", Count = 1, Level = 1, Kind = "Equipment", Cost = { Stick = 10, Stone = 5, Plant = 3 }, Order = 11 },
	{ Id = "CrudeSpear", Result = "CrudeSpear", Count = 1, Level = 1, Kind = "Equipment", Cost = { Stick = 12, Stone = 3, Plant = 5 }, Order = 12 },
	{ Id = "StorageBox", Result = "StorageBox", Count = 1, Level = 1, Kind = "Structure", Cost = { Wood = 20, Stone = 6 }, Order = 13 },
	{ Id = "WoodWall", Result = "WoodWall", Count = 1, Level = 1, Kind = "Structure", Cost = { Wood = 12 }, Order = 14 },
	{ Id = "RepairHammer", Result = "RepairHammer", Count = 1, Level = 1, Kind = "Equipment", Cost = { Wood = 6, Stone = 6 }, Order = 15 },

	-- Tier II: stone tools, bows, gates, spikes, canteen
	{ Id = "StoneAxe", Result = "StoneAxe", Count = 1, Level = 2, Kind = "Equipment", Cost = { Wood = 12, Stone = 16, Rope = 3 }, Order = 20 },
	{ Id = "StonePickaxe", Result = "StonePickaxe", Count = 1, Level = 2, Kind = "Equipment", Cost = { Wood = 12, Stone = 20, Rope = 3 }, Order = 21 },
	{ Id = "Spear", Result = "Spear", Count = 1, Level = 2, Kind = "Equipment", Cost = { Wood = 10, Stone = 12, Rope = 2 }, Order = 22 },
	{ Id = "Bow", Result = "Bow", Count = 1, Level = 2, Kind = "Equipment", Cost = { Wood = 16, Rope = 6 }, Order = 23 },
	{ Id = "Arrows", Result = "Arrow", Count = 6, Level = 2, Kind = "Ammo", Cost = { Stick = 6, Stone = 3, Plant = 2 }, Order = 24 },
	{ Id = "Canteen", Result = "Canteen", Count = 1, Level = 2, Kind = "Equipment", Cost = { Leather = 4, Rope = 2 }, Order = 25 },
	{ Id = "Gate", Result = "Gate", Count = 1, Level = 2, Kind = "Structure", Cost = { Wood = 24, Rope = 3 }, Order = 26 },
	{ Id = "Spikes", Result = "Spikes", Count = 1, Level = 2, Kind = "Structure", Cost = { Wood = 12, Stick = 8 }, Order = 27 },
	{ Id = "FirstAid", Result = "FirstAid", Count = 1, Level = 2, Kind = "Resource", Cost = { Plant = 8, Rope = 2, Mushroom = 2 }, Order = 28 },

	-- Tier III: scrap-era weapons and defences
	{ Id = "Sword", Result = "Sword", Count = 1, Level = 3, Kind = "Equipment", Cost = { Scrap = 12, Wood = 8, Leather = 2 }, Order = 30 },
	{ Id = "Shield", Result = "Shield", Count = 1, Level = 3, Kind = "Equipment", Cost = { Wood = 20, Scrap = 6, Leather = 3 }, Order = 31 },
	{ Id = "Armor", Result = "Armor", Count = 1, Level = 3, Kind = "Equipment", Cost = { Leather = 10, Rope = 4, Scrap = 4 }, Order = 32 },
	{ Id = "ReinforcedWall", Result = "ReinforcedWall", Count = 1, Level = 3, Kind = "Structure", Cost = { Wood = 16, Stone = 24, Scrap = 2 }, Order = 33 },
	{ Id = "Watchtower", Result = "Watchtower", Count = 1, Level = 3, Kind = "Structure", Cost = { Wood = 60, Stone = 20, Rope = 8, Scrap = 4 }, Order = 34 },

	-- Tier IV: iron tools, medkits
	{ Id = "IronAxe", Result = "IronAxe", Count = 1, Level = 4, Kind = "Equipment", Cost = { Wood = 20, Iron = 10, Scrap = 6 }, Order = 40 },
	{ Id = "IronPickaxe", Result = "IronPickaxe", Count = 1, Level = 4, Kind = "Equipment", Cost = { Wood = 20, Iron = 12, Scrap = 6 }, Order = 41 },
	{ Id = "Medkit", Result = "Medkit", Count = 1, Level = 4, Kind = "Resource", Cost = { Plant = 12, Scrap = 4, Iron = 2, Mushroom = 4 }, Order = 42 },

	-- Tier V: steel (endgame)
	{ Id = "SteelAxe", Result = "SteelAxe", Count = 1, Level = 5, Kind = "Equipment", Cost = { Wood = 30, Iron = 24, Coal = 16, Scrap = 12 }, Order = 50 },
	{ Id = "SteelPickaxe", Result = "SteelPickaxe", Count = 1, Level = 5, Kind = "Equipment", Cost = { Wood = 30, Iron = 28, Coal = 16, Scrap = 12 }, Order = 51 },
} :: { Recipe }

Recipes.ById = {} :: { [string]: Recipe }
for _, r in Recipes.List do
	Recipes.ById[r.Id] = r
end

-- Structure id -> recipe (for placement cost lookups)
Recipes.ByResult = {} :: { [string]: Recipe }
for _, r in Recipes.List do
	Recipes.ByResult[r.Result] = r
end

-- Workbench upgrade costs: key = target level.
-- Spec costs (paid from your pack + your storage).
Recipes.WorkbenchUpgrades = {
	[2] = { Wood = 64, Stone = 36, Plant = 10 },
	[3] = { Wood = 192, Stone = 96, Scrap = 40 },
	[4] = { Wood = 384, Stone = 192, Scrap = 100, Iron = 32 },
	[5] = { Wood = 640, Stone = 300, Scrap = 200, Iron = 96, RareComponent = 3 },
} :: { [number]: { [string]: number } }

Recipes.MaxWorkbenchLevel = 5

-- Repair costs: resource spent per hammer swing by structure material. Each swing
-- restores RepairFraction of max health.
Recipes.Repair = {
	RepairFraction = 0.1,
	Cost = { Wood = { Wood = 1 }, Stone = { Stone = 1 } },
}

return Recipes
