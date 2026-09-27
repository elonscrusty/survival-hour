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
	{ Id = "FibrePack", Result = "FibrePack", Count = 1, Level = 1, Kind = "Equipment", Cost = { Plant = 20, Rope = 4, Stick = 8 }, Order = 16 },
	{ Id = "WoodWall", Result = "WoodWall", Count = 1, Level = 1, Kind = "Structure", Cost = { Wood = 12 }, Order = 17 },
	{ Id = "Gate", Result = "Gate", Count = 1, Level = 1, Kind = "Structure", Cost = { Wood = 20, Rope = 2 }, Order = 18 },
	{ Id = "WoodFloor", Result = "WoodFloor", Count = 1, Level = 1, Kind = "Structure", Cost = { Wood = 10 }, Order = 19 },
	{ Id = "Spikes", Result = "Spikes", Count = 1, Level = 1, Kind = "Structure", Cost = { Wood = 12, Stick = 8 }, Order = 19.5 },
	{ Id = "RepairHammer", Result = "RepairHammer", Count = 1, Level = 1, Kind = "Equipment", Cost = { Wood = 6, Stone = 6 }, Order = 15 },

	-- Tier II: stone tools, bows, gates, spikes, canteen
	{ Id = "StoneAxe", Result = "StoneAxe", Count = 1, Level = 2, Kind = "Equipment", Cost = { Wood = 12, Stone = 16, Rope = 3 }, Order = 20 },
	{ Id = "StonePickaxe", Result = "StonePickaxe", Count = 1, Level = 2, Kind = "Equipment", Cost = { Wood = 12, Stone = 20, Rope = 3 }, Order = 21 },
	{ Id = "Spear", Result = "Spear", Count = 1, Level = 2, Kind = "Equipment", Cost = { Wood = 10, Stone = 12, Rope = 2 }, Order = 22 },
	{ Id = "Bow", Result = "Bow", Count = 1, Level = 2, Kind = "Equipment", Cost = { Wood = 16, Rope = 6 }, Order = 23 },
	{ Id = "Arrows", Result = "Arrow", Count = 6, Level = 2, Kind = "Ammo", Cost = { Stick = 6, Stone = 3, Plant = 2 }, Order = 24 },
	{ Id = "Canteen", Result = "Canteen", Count = 1, Level = 2, Kind = "Equipment", Cost = { Leather = 4, Rope = 2 }, Order = 25 },
	{ Id = "ReinforcedWall", Result = "ReinforcedWall", Count = 1, Level = 2, Kind = "Structure", Cost = { Wood = 16, Stone = 24 }, Order = 26 },
	{ Id = "ReinforcedDoor", Result = "ReinforcedDoor", Count = 1, Level = 2, Kind = "Structure", Cost = { Wood = 24, Stone = 12, Rope = 3 }, Order = 26.5 },
	{ Id = "WindowWall", Result = "WindowWall", Count = 1, Level = 2, Kind = "Structure", Cost = { Wood = 16, Stone = 20 }, Order = 27 },
	{ Id = "TripwireAlarm", Result = "TripwireAlarm", Count = 1, Level = 2, Kind = "Structure", Cost = { Stick = 6, Rope = 2, Stone = 2 }, Order = 27.2 },
	{ Id = "Snare", Result = "Snare", Count = 1, Level = 2, Kind = "Structure", Cost = { Rope = 3, Stick = 4 }, Order = 27.4 },
	{ Id = "ReinforcedChest", Result = "ReinforcedChest", Count = 1, Level = 2, Kind = "Structure", Cost = { Wood = 48, Stone = 24, Rope = 4 }, Order = 30 },
	{ Id = "HidePack", Result = "HidePack", Count = 1, Level = 2, Kind = "Equipment", Cost = { Leather = 8, Rope = 6, Plant = 10 }, Order = 29 },
	{ Id = "HideHead", Result = "HideHead", Count = 1, Level = 2, Kind = "Equipment", Cost = { Leather = 4, Rope = 2 }, Order = 29.1 },
	{ Id = "HideChest", Result = "HideChest", Count = 1, Level = 2, Kind = "Equipment", Cost = { Leather = 8, Rope = 3 }, Order = 29.2 },
	{ Id = "HideLegs", Result = "HideLegs", Count = 1, Level = 2, Kind = "Equipment", Cost = { Leather = 6, Rope = 2 }, Order = 29.3 },
	{ Id = "FirstAid", Result = "FirstAid", Count = 1, Level = 2, Kind = "Resource", Cost = { Plant = 8, Rope = 2, Mushroom = 2 }, Order = 28 },

	-- Tier III: scrap-era weapons and defences
	{ Id = "Sword", Result = "Sword", Count = 1, Level = 3, Kind = "Equipment", Cost = { Scrap = 12, Wood = 8, Leather = 2 }, Order = 30 },
	{ Id = "Shield", Result = "Shield", Count = 1, Level = 3, Kind = "Equipment", Cost = { Wood = 20, Scrap = 6, Leather = 3 }, Order = 31 },
	{ Id = "ScrapWall", Result = "ScrapWall", Count = 1, Level = 3, Kind = "Structure", Cost = { Scrap = 16, Wood = 10 }, Order = 33.5 },
	{ Id = "BearTrap", Result = "BearTrap", Count = 1, Level = 3, Kind = "Structure", Cost = { Scrap = 12, Rope = 2 }, Order = 33.7 },
	{ Id = "HuntingBow", Result = "HuntingBow", Count = 1, Level = 3, Kind = "Equipment", Cost = { Wood = 20, Rope = 6, Leather = 3, Scrap = 2 }, Order = 35.1 },
	{ Id = "ReinforcedHideHead", Result = "ReinforcedHideHead", Count = 1, Level = 3, Kind = "Equipment", Cost = { Leather = 6, Rope = 2, Scrap = 2 }, Order = 35.2 },
	{ Id = "ReinforcedHideChest", Result = "ReinforcedHideChest", Count = 1, Level = 3, Kind = "Equipment", Cost = { Leather = 12, Rope = 3, Scrap = 4 }, Order = 35.3 },
	{ Id = "ReinforcedHideLegs", Result = "ReinforcedHideLegs", Count = 1, Level = 3, Kind = "Equipment", Cost = { Leather = 9, Rope = 2, Scrap = 3 }, Order = 35.4 },
	{ Id = "ScrapHead", Result = "ScrapHead", Count = 1, Level = 3, Kind = "Equipment", Cost = { Scrap = 8, Leather = 2 }, Order = 35.5 },
	{ Id = "ScrapChest", Result = "ScrapChest", Count = 1, Level = 3, Kind = "Equipment", Cost = { Scrap = 16, Leather = 4 }, Order = 35.6 },
	{ Id = "ScrapLegs", Result = "ScrapLegs", Count = 1, Level = 3, Kind = "Equipment", Cost = { Scrap = 12, Leather = 3 }, Order = 35.7 },
	{ Id = "MetalLocker", Result = "MetalLocker", Count = 1, Level = 3, Kind = "Structure", Cost = { Scrap = 30, Wood = 24 }, Order = 36 },
	{ Id = "Crowbar", Result = "Crowbar", Count = 1, Level = 3, Kind = "Equipment", Cost = { Scrap = 12, Rope = 2 }, Order = 37 },
	{ Id = "FramePack", Result = "FramePack", Count = 1, Level = 3, Kind = "Equipment", Cost = { Leather = 12, Scrap = 10, Rope = 8 }, Order = 35 },
	{ Id = "Watchtower", Result = "Watchtower", Count = 1, Level = 3, Kind = "Structure", Cost = { Wood = 60, Stone = 20, Rope = 8, Scrap = 4 }, Order = 34 },

	-- Tier IV: iron tools, medkits
	{ Id = "IronAxe", Result = "IronAxe", Count = 1, Level = 4, Kind = "Equipment", Cost = { Wood = 20, Iron = 10, Scrap = 6 }, Order = 40 },
	{ Id = "IronPickaxe", Result = "IronPickaxe", Count = 1, Level = 4, Kind = "Equipment", Cost = { Wood = 20, Iron = 12, Scrap = 6 }, Order = 41 },
	{ Id = "MetalWall", Result = "MetalWall", Count = 1, Level = 4, Kind = "Structure", Cost = { Iron = 12, Scrap = 10 }, Order = 43.5 },
	{ Id = "HeavyGate", Result = "HeavyGate", Count = 1, Level = 4, Kind = "Structure", Cost = { Iron = 16, Scrap = 12, Wood = 10 }, Order = 43.7 },
	{ Id = "Crossbow", Result = "Crossbow", Count = 1, Level = 4, Kind = "Equipment", Cost = { Wood = 16, Iron = 8, Scrap = 8, Rope = 4 }, Order = 43.1 },
	{ Id = "Bolts", Result = "Bolt", Count = 6, Level = 4, Kind = "Ammo", Cost = { Stick = 6, Iron = 1, Plant = 2 }, Order = 43.2 },
	{ Id = "IronHead", Result = "IronHead", Count = 1, Level = 4, Kind = "Equipment", Cost = { Iron = 6, Leather = 2, Scrap = 4 }, Order = 43.3 },
	{ Id = "IronChest", Result = "IronChest", Count = 1, Level = 4, Kind = "Equipment", Cost = { Iron = 12, Leather = 4, Scrap = 8 }, Order = 43.4 },
	{ Id = "IronLegs", Result = "IronLegs", Count = 1, Level = 4, Kind = "Equipment", Cost = { Iron = 9, Leather = 3, Scrap = 6 }, Order = 43.5 },
	{ Id = "SurvivalSafe", Result = "SurvivalSafe", Count = 1, Level = 4, Kind = "Structure", Cost = { Iron = 24, Scrap = 40, Stone = 40 }, Order = 44 },
	{ Id = "Sledgehammer", Result = "Sledgehammer", Count = 1, Level = 4, Kind = "Equipment", Cost = { Iron = 12, Wood = 16, Scrap = 8 }, Order = 45 },
	{ Id = "IronPack", Result = "IronPack", Count = 1, Level = 4, Kind = "Equipment", Cost = { Leather = 16, Iron = 8, Scrap = 14, Rope = 8 }, Order = 43 },
	{ Id = "Medkit", Result = "Medkit", Count = 1, Level = 4, Kind = "Resource", Cost = { Plant = 12, Scrap = 4, Iron = 2, Mushroom = 4 }, Order = 42 },

	-- Tier V: steel (endgame)
	{ Id = "SteelAxe", Result = "SteelAxe", Count = 1, Level = 5, Kind = "Equipment", Cost = { Wood = 30, Iron = 24, Coal = 16, Scrap = 12 }, Order = 50 },
	{ Id = "AdvancedAlarm", Result = "AdvancedAlarm", Count = 1, Level = 5, Kind = "Structure", Cost = { Iron = 6, Scrap = 10, Coal = 4 }, Order = 52.5 },
	{ Id = "TacticalHead", Result = "TacticalHead", Count = 1, Level = 5, Kind = "Equipment", Cost = { Iron = 10, Scrap = 10, Leather = 4, RareComponent = 1 }, Order = 52.6 },
	{ Id = "TacticalChest", Result = "TacticalChest", Count = 1, Level = 5, Kind = "Equipment", Cost = { Iron = 18, Scrap = 16, Leather = 6, RareComponent = 1 }, Order = 52.7 },
	{ Id = "TacticalLegs", Result = "TacticalLegs", Count = 1, Level = 5, Kind = "Equipment", Cost = { Iron = 14, Scrap = 12, Leather = 5, RareComponent = 1 }, Order = 52.8 },
	{ Id = "BreachingCharge", Result = "BreachingCharge", Count = 1, Level = 5, Kind = "Resource", Cost = { Scrap = 16, Coal = 12, Iron = 6 }, Order = 53 },
	{ Id = "ExpeditionPack", Result = "ExpeditionPack", Count = 1, Level = 5, Kind = "Equipment", Cost = { Leather = 24, Iron = 14, Scrap = 20, RareComponent = 1 }, Order = 52 },
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
	Cost = { Wood = { Wood = 1 }, Stone = { Stone = 1 }, Scrap = { Scrap = 1 }, Iron = { Iron = 1 } },
}

return Recipes
