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

Loot.CarePackage = {
	{ Id = "Pistol", Label = "Flintlock Pistol + 12 bullets", Weight = 8, Grants = { { Item = "Pistol", Count = 1 }, { Item = "Bullet", Count = 12 } } },
	{ Id = "Rifle", Label = "Hunting Rifle + 6 bullets", Weight = 4, Grants = { { Item = "Rifle", Count = 1 }, { Item = "Bullet", Count = 6 } } },
	{ Id = "Sword", Label = "Sword", Weight = 8, Grants = { { Item = "Sword", Count = 1 } } },
	{ Id = "Bow", Label = "Bow + 6 arrows", Weight = 10, Grants = { { Item = "Bow", Count = 1 }, { Item = "Arrow", Count = 6 } } },
	{ Id = "Arrows", Label = "12 arrows", Weight = 14, Grants = { { Item = "Arrow", Count = 12 } } },
	{ Id = "Bullets", Label = "12 bullets", Weight = 8, Grants = { { Item = "Bullet", Count = 12 } } },
	{ Id = "Bandages", Label = "2 bandages", Weight = 18, Grants = { { Item = "Bandage", Count = 2 } } },
	{ Id = "Armor", Label = "Leather Armor", Weight = 6, Grants = { { Item = "Armor", Count = 1 } } },
	{ Id = "Shield", Label = "Shield", Weight = 6, Grants = { { Item = "Shield", Count = 1 } } },
	{ Id = "Leather", Label = "3 leather", Weight = 8, Grants = { { Item = "Leather", Count = 3 } } },
	{ Id = "Rope", Label = "3 rope", Weight = 10, Grants = { { Item = "Rope", Count = 3 } } },
} :: { Entry }

-- Forest crates: one roll, smaller rewards, no guns or crafted-tier weapons.
Loot.Crate = {
	{ Id = "Bandage", Label = "1 bandage", Weight = 35, Grants = { { Item = "Bandage", Count = 1 } } },
	{ Id = "Arrows", Label = "6 arrows", Weight = 25, Grants = { { Item = "Arrow", Count = 6 } } },
	{ Id = "Bundle", Label = "3 sticks, 3 stone, 3 wood", Weight = 20, Grants = { { Item = "Stick", Count = 3 }, { Item = "Stone", Count = 3 }, { Item = "Wood", Count = 3 } } },
	{ Id = "Rope", Label = "2 rope", Weight = 12, Grants = { { Item = "Rope", Count = 2 } } },
	{ Id = "Bullets", Label = "6 bullets", Weight = 8, Grants = { { Item = "Bullet", Count = 6 } } },
} :: { Entry }

-- Point-of-interest chests. Riskier, farther spots roll better tables:
-- Common = campsites, Uncommon = cabins, Rare = abandoned houses, Epic = caves.
-- Chests restock at dawn. Only Rare/Epic can hold guns.
Loot.ChestRolls = { Common = 1, Uncommon = 2, Rare = 2, Epic = 3 }

Loot.Chest = {
	Common = {
		{ Id = "Food", Label = "4 berries", Weight = 30, Grants = { { Item = "Berries", Count = 4 } } },
		{ Id = "Bandage", Label = "1 bandage", Weight = 25, Grants = { { Item = "Bandage", Count = 1 } } },
		{ Id = "Bundle", Label = "3 sticks, 3 stone, 2 rope", Weight = 25, Grants = { { Item = "Stick", Count = 3 }, { Item = "Stone", Count = 3 }, { Item = "Rope", Count = 2 } } },
		{ Id = "Arrows", Label = "6 arrows", Weight = 20, Grants = { { Item = "Arrow", Count = 6 } } },
	} :: { Entry },
	Uncommon = {
		{ Id = "Bandages", Label = "2 bandages", Weight = 24, Grants = { { Item = "Bandage", Count = 2 } } },
		{ Id = "Arrows", Label = "10 arrows", Weight = 20, Grants = { { Item = "Arrow", Count = 10 } } },
		{ Id = "Spear", Label = "Spear", Weight = 14, Grants = { { Item = "Spear", Count = 1 } } },
		{ Id = "Leather", Label = "3 leather", Weight = 16, Grants = { { Item = "Leather", Count = 3 } } },
		{ Id = "Rope", Label = "3 rope", Weight = 14, Grants = { { Item = "Rope", Count = 3 } } },
		{ Id = "Food", Label = "4 mushrooms", Weight = 12, Grants = { { Item = "Mushroom", Count = 4 } } },
	} :: { Entry },
	Rare = {
		{ Id = "Bow", Label = "Bow + 8 arrows", Weight = 16, Grants = { { Item = "Bow", Count = 1 }, { Item = "Arrow", Count = 8 } } },
		{ Id = "Sword", Label = "Sword", Weight = 12, Grants = { { Item = "Sword", Count = 1 } } },
		{ Id = "Armor", Label = "Leather Armor", Weight = 12, Grants = { { Item = "Armor", Count = 1 } } },
		{ Id = "Shield", Label = "Shield", Weight = 10, Grants = { { Item = "Shield", Count = 1 } } },
		{ Id = "Pistol", Label = "Flintlock Pistol + 8 bullets", Weight = 6, Grants = { { Item = "Pistol", Count = 1 }, { Item = "Bullet", Count = 8 } } },
		{ Id = "Bandages", Label = "2 bandages", Weight = 24, Grants = { { Item = "Bandage", Count = 2 } } },
		{ Id = "Leather", Label = "4 leather", Weight = 20, Grants = { { Item = "Leather", Count = 4 } } },
	} :: { Entry },
	Epic = {
		{ Id = "Rifle", Label = "Hunting Rifle + 6 bullets", Weight = 8, Grants = { { Item = "Rifle", Count = 1 }, { Item = "Bullet", Count = 6 } } },
		{ Id = "Pistol", Label = "Flintlock Pistol + 12 bullets", Weight = 12, Grants = { { Item = "Pistol", Count = 1 }, { Item = "Bullet", Count = 12 } } },
		{ Id = "Sword", Label = "Sword", Weight = 14, Grants = { { Item = "Sword", Count = 1 } } },
		{ Id = "Armor", Label = "Leather Armor", Weight = 14, Grants = { { Item = "Armor", Count = 1 } } },
		{ Id = "Bow", Label = "Bow + 12 arrows", Weight = 14, Grants = { { Item = "Bow", Count = 1 }, { Item = "Arrow", Count = 12 } } },
		{ Id = "Bandages", Label = "3 bandages", Weight = 20, Grants = { { Item = "Bandage", Count = 3 } } },
		{ Id = "Supplies", Label = "4 leather, 4 rope", Weight = 18, Grants = { { Item = "Leather", Count = 4 }, { Item = "Rope", Count = 4 } } },
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
