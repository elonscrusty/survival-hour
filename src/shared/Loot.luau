--!strict
-- Loot tables. Pure data. Weights are percentages and MUST sum to 100 for each
-- table (tests enforce this) because the care-package odds are shown to players
-- before a Robux purchase (Roblox paid-random-item policy).

export type Entry = {
	Id: string,
	Label: string,
	Weight: number,
	Grants: { { Item: string, Count: number } },
}

local Loot = {}

Loot.CarePackageRolls = 3

-- Free daily care package (public, contestable). Robux care packages are off sale
-- (non-pay-to-win); the odds stay published because they are still a random drop.
Loot.CarePackage = {
	{ Id = "Pistol", Label = "Flintlock Pistol + 12 bullets", Weight = 6, Grants = { { Item = "Pistol", Count = 1 }, { Item = "Bullet", Count = 12 } } },
	{ Id = "Rifle", Label = "Hunting Rifle + 6 bullets", Weight = 3, Grants = { { Item = "Rifle", Count = 1 }, { Item = "Bullet", Count = 6 } } },
	{ Id = "HuntingBow", Label = "Hunting Bow + 10 arrows", Weight = 8, Grants = { { Item = "HuntingBow", Count = 1 }, { Item = "Arrow", Count = 10 } } },
	{ Id = "Scrap", Label = "12 scrap", Weight = 14, Grants = { { Item = "Scrap", Count = 12 } } },
	{ Id = "Iron", Label = "6 iron", Weight = 8, Grants = { { Item = "Iron", Count = 6 } } },
	{ Id = "Arrows", Label = "12 arrows", Weight = 12, Grants = { { Item = "Arrow", Count = 12 } } },
	{ Id = "FirstAid", Label = "2 First Aid kits", Weight = 14, Grants = { { Item = "FirstAid", Count = 2 } } },
	{ Id = "Armor", Label = "Scrap Chestpiece", Weight = 6, Grants = { { Item = "ScrapChest", Count = 1 } } },
	{ Id = "Pack", Label = "Hide Pack (16 slots)", Weight = 7, Grants = { { Item = "HidePack", Count = 1 } } },
	{ Id = "Leather", Label = "6 leather", Weight = 12, Grants = { { Item = "Leather", Count = 6 } } },
	{ Id = "Rope", Label = "4 rope", Weight = 10, Grants = { { Item = "Rope", Count = 4 } } },
} :: { Entry }

-- Forest crates: one roll, small rewards, no guns.
Loot.Crate = {
	{ Id = "Bandage", Label = "2 bandages", Weight = 30, Grants = { { Item = "Bandage", Count = 2 } } },
	{ Id = "Arrows", Label = "6 arrows", Weight = 20, Grants = { { Item = "Arrow", Count = 6 } } },
	{ Id = "Bundle", Label = "6 sticks, 4 stone, 4 fibre", Weight = 22, Grants = { { Item = "Stick", Count = 6 }, { Item = "Stone", Count = 4 }, { Item = "Plant", Count = 4 } } },
	{ Id = "Rope", Label = "2 rope", Weight = 12, Grants = { { Item = "Rope", Count = 2 } } },
	{ Id = "Scrap", Label = "3 scrap", Weight = 10, Grants = { { Item = "Scrap", Count = 3 } } },
	{ Id = "Bullets", Label = "6 bullets", Weight = 6, Grants = { { Item = "Bullet", Count = 6 } } },
} :: { Entry }

-- Point-of-interest chests (spec): Common = basic supplies; Uncommon = better
-- supplies/materials/tools; Rare = better equipment/resources; Very Rare =
-- unusual/high-value items. POI chests are ONE-TIME per match (they don't restock).
-- Guns only appear in Rare / Very Rare.
Loot.ChestRolls = { Common = 2, Uncommon = 2, Rare = 3, VeryRare = 3 }
Loot.ChestTiers = { "Common", "Uncommon", "Rare", "VeryRare" }

Loot.Chest = {
	Common = {
		{ Id = "Food", Label = "5 berries", Weight = 20, Grants = { { Item = "Berries", Count = 5 } } },
		{ Id = "Bandages", Label = "2 bandages", Weight = 22, Grants = { { Item = "Bandage", Count = 2 } } },
		{ Id = "Bundle", Label = "8 sticks, 6 stone, 6 fibre", Weight = 24, Grants = { { Item = "Stick", Count = 8 }, { Item = "Stone", Count = 6 }, { Item = "Plant", Count = 6 } } },
		{ Id = "Arrows", Label = "8 arrows", Weight = 14, Grants = { { Item = "Arrow", Count = 8 } } },
		{ Id = "Rope", Label = "3 rope", Weight = 12, Grants = { { Item = "Rope", Count = 3 } } },
		{ Id = "CrudeTool", Label = "Crude Pickaxe", Weight = 8, Grants = { { Item = "CrudePickaxe", Count = 1 } } },
	} :: { Entry },
	Uncommon = {
		{ Id = "Scrap", Label = "8 scrap", Weight = 20, Grants = { { Item = "Scrap", Count = 8 } } },
		{ Id = "Leather", Label = "5 leather", Weight = 14, Grants = { { Item = "Leather", Count = 5 } } },
		{ Id = "FirstAid", Label = "First Aid kit", Weight = 16, Grants = { { Item = "FirstAid", Count = 1 } } },
		{ Id = "StoneTool", Label = "Stone Axe", Weight = 8, Grants = { { Item = "StoneAxe", Count = 1 } } },
		{ Id = "StonePick", Label = "Stone Pickaxe", Weight = 8, Grants = { { Item = "StonePickaxe", Count = 1 } } },
		{ Id = "Bow", Label = "Crude Bow + 8 arrows", Weight = 10, Grants = { { Item = "Bow", Count = 1 }, { Item = "Arrow", Count = 8 } } },
		{ Id = "HideArmor", Label = "Hide Chestpiece", Weight = 10, Grants = { { Item = "HideChest", Count = 1 } } },
		{ Id = "Rope", Label = "5 rope", Weight = 8, Grants = { { Item = "Rope", Count = 5 } } },
		{ Id = "Coal", Label = "5 coal", Weight = 6, Grants = { { Item = "Coal", Count = 5 } } },
	} :: { Entry },
	Rare = {
		{ Id = "Iron", Label = "8 iron", Weight = 16, Grants = { { Item = "Iron", Count = 8 } } },
		{ Id = "Scrap", Label = "16 scrap", Weight = 16, Grants = { { Item = "Scrap", Count = 16 } } },
		{ Id = "HuntingBow", Label = "Hunting Bow + 10 arrows", Weight = 10, Grants = { { Item = "HuntingBow", Count = 1 }, { Item = "Arrow", Count = 10 } } },
		{ Id = "Sword", Label = "Sword", Weight = 8, Grants = { { Item = "Sword", Count = 1 } } },
		{ Id = "ScrapArmor", Label = "Scrap Helmet + Leggings", Weight = 10, Grants = { { Item = "ScrapHead", Count = 1 }, { Item = "ScrapLegs", Count = 1 } } },
		{ Id = "Medkit", Label = "Medkit", Weight = 10, Grants = { { Item = "Medkit", Count = 1 } } },
		{ Id = "Pack", Label = "Scrap-Frame Pack (24 slots)", Weight = 8, Grants = { { Item = "FramePack", Count = 1 } } },
		{ Id = "Crowbar", Label = "Crowbar", Weight = 8, Grants = { { Item = "Crowbar", Count = 1 } } },
		{ Id = "Pistol", Label = "Flintlock Pistol + 8 bullets", Weight = 6, Grants = { { Item = "Pistol", Count = 1 }, { Item = "Bullet", Count = 8 } } },
		{ Id = "Rare", Label = "Rare Component", Weight = 8, Grants = { { Item = "RareComponent", Count = 1 } } },
	} :: { Entry },
	VeryRare = {
		{ Id = "Rare", Label = "2 Rare Components", Weight = 18, Grants = { { Item = "RareComponent", Count = 2 } } },
		{ Id = "Crossbow", Label = "Crossbow + 10 bolts", Weight = 12, Grants = { { Item = "Crossbow", Count = 1 }, { Item = "Bolt", Count = 10 } } },
		{ Id = "Rifle", Label = "Hunting Rifle + 6 bullets", Weight = 8, Grants = { { Item = "Rifle", Count = 1 }, { Item = "Bullet", Count = 6 } } },
		{ Id = "IronArmor", Label = "Iron Chestpiece", Weight = 12, Grants = { { Item = "IronChest", Count = 1 } } },
		{ Id = "SteelTool", Label = "Steel Axe", Weight = 8, Grants = { { Item = "SteelAxe", Count = 1 } } },
		{ Id = "Charge", Label = "Breaching Charge", Weight = 10, Grants = { { Item = "BreachingCharge", Count = 1 } } },
		{ Id = "Iron", Label = "16 iron", Weight = 16, Grants = { { Item = "Iron", Count = 16 } } },
		{ Id = "Medkits", Label = "2 Medkits", Weight = 16, Grants = { { Item = "Medkit", Count = 2 } } },
	} :: { Entry },
}

function Loot.RollChest(tier: string, random01: () -> number): { Entry }
	local tbl = Loot.Chest[tier]
	local out = {}
	for i = 1, Loot.ChestRolls[tier] or 1 do
		out[i] = Loot.Roll(tbl, random01)
	end
	return out
end

function Loot.TotalWeight(tbl: { Entry }): number
	local t = 0
	for _, e in tbl do
		t += e.Weight
	end
	return t
end

-- `random01` returns a float in [0, 1). Injected so tests can use a seeded RNG.
function Loot.Roll(tbl: { Entry }, random01: () -> number): Entry
	local total = Loot.TotalWeight(tbl)
	local pick = random01() * total
	local acc = 0
	for _, e in tbl do
		acc += e.Weight
		if pick < acc then
			return e
		end
	end
	return tbl[#tbl]
end

function Loot.RollCarePackage(random01: () -> number): { Entry }
	local out = {}
	for i = 1, Loot.CarePackageRolls do
		out[i] = Loot.Roll(Loot.CarePackage, random01)
	end
	return out
end

return Loot
