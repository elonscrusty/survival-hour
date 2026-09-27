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

Recipes.List = {
	-- Always available, anywhere (does NOT occupy a workbench unlock)
	{ Id = "Rope", Result = "Rope", Count = 1, Level = 0, Kind = "Resource", Cost = { Plant = 3 }, Order = 0 },

	-- Workbench level 1
	{ Id = "StoneAxe", Result = "StoneAxe", Count = 1, Level = 1, Kind = "Equipment", Cost = { Stick = 1, Stone = 1 }, Order = 1 },
	{ Id = "StorageBox", Result = "StorageBox", Count = 1, Level = 1, Kind = "Structure", Cost = { Wood = 10, Stone = 2 }, Order = 2 },
	{ Id = "WoodWall", Result = "WoodWall", Count = 1, Level = 1, Kind = "Structure", Cost = { Wood = 4 }, Order = 3 },
	{ Id = "Spear", Result = "Spear", Count = 1, Level = 1, Kind = "Equipment", Cost = { Stick = 3, Stone = 2 }, Order = 4 },
	{ Id = "RepairHammer", Result = "RepairHammer", Count = 1, Level = 1, Kind = "Equipment", Cost = { Wood = 2, Stone = 2 }, Order = 5 },

	-- Workbench level 2
	{ Id = "Canteen", Result = "Canteen", Count = 1, Level = 2, Kind = "Equipment", Cost = { Leather = 2, Rope = 1 }, Order = 6 },
	{ Id = "Bow", Result = "Bow", Count = 1, Level = 2, Kind = "Equipment", Cost = { Wood = 3, Rope = 2 }, Order = 7 },
	{ Id = "Arrows", Result = "Arrow", Count = 6, Level = 2, Kind = "Ammo", Cost = { Stick = 2, Stone = 1 }, Order = 8 },
	{ Id = "Gate", Result = "Gate", Count = 1, Level = 2, Kind = "Structure", Cost = { Wood = 6, Rope = 1 }, Order = 9 },
	{ Id = "Spikes", Result = "Spikes", Count = 1, Level = 2, Kind = "Structure", Cost = { Wood = 3, Stick = 2 }, Order = 10 },

	-- Workbench level 3
	{ Id = "Armor", Result = "Armor", Count = 1, Level = 3, Kind = "Equipment", Cost = { Leather = 4, Rope = 2, Stone = 3 }, Order = 11 },
	{ Id = "Sword", Result = "Sword", Count = 1, Level = 3, Kind = "Equipment", Cost = { Stone = 6, Wood = 2, Leather = 1 }, Order = 12 },
	{ Id = "ReinforcedWall", Result = "ReinforcedWall", Count = 1, Level = 3, Kind = "Structure", Cost = { Wood = 4, Stone = 6 }, Order = 13 },
	{ Id = "Watchtower", Result = "Watchtower", Count = 1, Level = 3, Kind = "Structure", Cost = { Wood = 12, Stone = 4, Rope = 4 }, Order = 14 },
	{ Id = "Shield", Result = "Shield", Count = 1, Level = 3, Kind = "Equipment", Cost = { Wood = 5, Leather = 2, Rope = 1 }, Order = 15 },
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
Recipes.WorkbenchUpgrades = {
	[2] = { Wood = 20, Stone = 15, Leather = 3, Rope = 4 },
	[3] = { Wood = 40, Stone = 30, Leather = 6, Rope = 8 },
} :: { [number]: { [string]: number } }

Recipes.MaxWorkbenchLevel = 3

-- Repair costs: resource spent per hammer swing by structure material. Each swing
-- restores RepairFraction of max health.
Recipes.Repair = {
	RepairFraction = 0.1,
	Cost = { Wood = { Wood = 1 }, Stone = { Stone = 1 } },
}

return Recipes
