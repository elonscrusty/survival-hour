--!strict
-- Item definitions. Kinds:
--   Resource  – carried in the resource pack (weight 1 each)
--   Weapon    – weapon slots (2)
--   Tool      – tool slot (1)
--   Utility   – utility slot (1)
--   Armor     – worn, no hand slot
--   Ammo      – ammo pouch
--   Consumable– bandage pouch
--   Structure – placed via build mode, never held

export type ItemDef = {
	Id: string,
	Name: string,
	Kind: string,
	Description: string,
	Icon: { Glyph: string, Color: Color3, Shape: string },
	-- weapons / tools
	Damage: number?,
	Cooldown: number?,
	Range: number?,
	Durability: number?,
	StructureMult: number?,
	AnimalMult: number?,
	Ranged: string?, -- "Arrow" | "Hitscan"
	AmmoType: string?,
	Spread: number?, -- degrees
	DrawTime: number?,
	ToolType: string?, -- gathering tool class matched against Resources RequiredTool ("Axe")
	ToolPower: number?, -- chop points removed per hit
	ToolTier: number?, -- 1 Crude, 2 Stone, 3 Iron, 4 Steel (Resources MinTier)
	Heal: number?, -- healing items
	UseTime: number?, -- seconds to apply (interrupted by damage)
	Slots: number?, -- backpacks: pack slots
	Tier: number?, -- general tier (armor, backpacks, storage)
	Food: boolean?, -- resource that can be eaten (heal values in Resources.Food)
	BlockReduction: number?, -- shield
	DamageReduction: number?, -- armor
	-- structures
	Health: number?,
	Size: Vector3?,
	Material: string?, -- "Wood" | "Stone" repair material
	Limit: string?,
}

local function icon(glyph: string, color: Color3, shape: string?)
	return { Glyph = glyph, Color = color, Shape = shape or "Round" }
end

local WOOD = Color3.fromRGB(156, 106, 64)
local STONE = Color3.fromRGB(138, 142, 150)
local GREEN = Color3.fromRGB(96, 160, 80)
local LEATHER = Color3.fromRGB(150, 92, 60)
local STEEL = Color3.fromRGB(190, 198, 210)
local RED = Color3.fromRGB(210, 70, 70)
local BLUE = Color3.fromRGB(80, 150, 220)

local Items: { [string]: ItemDef } = {}

local function add(def: ItemDef)
	Items[def.Id] = def
end

-- Resources ------------------------------------------------------------------
add({ Id = "Stick", Name = "Stick", Kind = "Resource", Description = "Gathered by hand from twig piles.", Icon = icon("／", WOOD, "Square") })
add({ Id = "Stone", Name = "Stone", Kind = "Resource", Description = "Gathered by hand from rock piles.", Icon = icon("◆", STONE, "Square") })
add({ Id = "Wood", Name = "Wood", Kind = "Resource", Description = "Chopped from small trees with an axe.", Icon = icon("▬", WOOD, "Square") })
add({ Id = "Plant", Name = "Plant Fibre", Kind = "Resource", Description = "Picked from ferns. Twist into rope.", Icon = icon("✿", GREEN, "Square") })
add({ Id = "Leather", Name = "Leather", Kind = "Resource", Description = "Dropped by animals killed at night.", Icon = icon("🐾", LEATHER, "Square") })
add({ Id = "Rope", Name = "Rope", Kind = "Resource", Description = "Twisted from plant fibre.", Icon = icon("§", Color3.fromRGB(205, 180, 120), "Square") })
add({ Id = "Berries", Name = "Berries", Kind = "Resource", Food = true, Description = "Picked from berry bushes. Eat to heal a little.", Icon = icon("●", Color3.fromRGB(190, 50, 90), "Square") })
-- Advanced materials (fire / workbench upgrades). Sources arrive with POIs, caves and chests.
add({ Id = "Scrap", Name = "Scrap", Kind = "Resource", Description = "Salvaged metal from ruins, vehicles and chests.", Icon = icon("⚙", Color3.fromRGB(150, 130, 110), "Square") })
add({ Id = "Iron", Name = "Iron", Kind = "Resource", Description = "Mined from iron deposits in caves and mines.", Icon = icon("▣", Color3.fromRGB(170, 120, 100), "Square") })
add({ Id = "Coal", Name = "Coal", Kind = "Resource", Description = "Mined in caves. Smelts iron.", Icon = icon("◼", Color3.fromRGB(50, 50, 55), "Square") })
add({ Id = "RareComponent", Name = "Rare Component", Kind = "Resource", Description = "A rare mechanical part found in the best chests.", Icon = icon("✦", Color3.fromRGB(230, 190, 80), "Square") })
add({ Id = "Mushroom", Name = "Mushroom", Kind = "Resource", Food = true, Description = "Found in the damp deep forest. Eat to heal.", Icon = icon("♣", Color3.fromRGB(214, 170, 120), "Square") })

-- Weapons --------------------------------------------------------------------
add({
	Id = "Fists", Name = "Fists", Kind = "Weapon", Description = "Always available.",
	Icon = icon("✊", Color3.fromRGB(230, 200, 170)),
	Damage = 8, Cooldown = 0.6, Range = 5.5, StructureMult = 0.25, AnimalMult = 1,
})
add({
	Id = "CrudeSpear", Name = "Crude Spear", Kind = "Weapon", Description = "Sharpened stick with a stone tip. Long reach.",
	Icon = icon("↗", Color3.fromRGB(170, 130, 90)),
	Damage = 16, Cooldown = 0.9, Range = 9, Durability = 40, StructureMult = 0.4, AnimalMult = 1.15,
})
add({
	Id = "Spear", Name = "Stone Spear", Kind = "Weapon", Description = "Long reach. Good for keeping wolves at bay.",
	Icon = icon("↗", WOOD),
	Damage = 22, Cooldown = 0.9, Range = 9.5, Durability = 100, StructureMult = 0.6, AnimalMult = 1.15,
})
add({
	Id = "Bow", Name = "Bow", Kind = "Weapon", Description = "Hold to draw, release to fire. Uses arrows.",
	Icon = icon("》", WOOD),
	Damage = 28, Cooldown = 0.35, DrawTime = 0.6, Range = 220, Durability = 150, Ranged = "Arrow",
	AmmoType = "Arrow", Spread = 1.2, StructureMult = 0.4, AnimalMult = 1,
})
add({
	Id = "Sword", Name = "Sword", Kind = "Weapon", Description = "Fast, heavy melee strikes.",
	Icon = icon("†", STEEL),
	Damage = 32, Cooldown = 0.75, Range = 7.5, Durability = 200, StructureMult = 1, AnimalMult = 1,
})
add({
	Id = "Shield", Name = "Shield", Kind = "Weapon", Description = "Hold to block 70% of frontal damage. Light bash.",
	Icon = icon("🛡", WOOD),
	Damage = 6, Cooldown = 0.8, Range = 5, Durability = 400, BlockReduction = 0.7, StructureMult = 0.2, AnimalMult = 1,
})
add({
	Id = "Pistol", Name = "Flintlock Pistol", Kind = "Weapon", Description = "Found in care packages. Uses bullets.",
	Icon = icon("⌐", Color3.fromRGB(120, 110, 100)),
	Damage = 30, Cooldown = 0.5, Range = 130, Durability = 60, Ranged = "Hitscan", AmmoType = "Bullet",
	Spread = 2.2, StructureMult = 0.5, AnimalMult = 1,
})
add({
	Id = "Rifle", Name = "Hunting Rifle", Kind = "Weapon", Description = "Rare care package find. Slow, powerful, long range.",
	Icon = icon("═", Color3.fromRGB(110, 90, 70)),
	Damage = 55, Cooldown = 1.4, Range = 260, Durability = 30, Ranged = "Hitscan", AmmoType = "Bullet",
	Spread = 0.6, StructureMult = 0.5, AnimalMult = 1,
})

-- Tools ----------------------------------------------------------------------
-- Tool tiers (spec): Crude ~40 hits, Stone ~100, Iron ~225, Steel ~450. Small trees and
-- small stones need Crude+, large ones Stone+. Tools hurt players, weapons do it better.
local TIER_NAMES = { "Crude", "Stone", "Iron", "Steel" }
local TIER_COLORS = { Color3.fromRGB(170, 130, 90), STONE, Color3.fromRGB(170, 120, 100), STEEL }
local TIER_DUR = { 40, 100, 225, 450 }
local TIER_POWER = { 10, 15, 22, 30 }
local TIER_DMG = { 10, 13, 16, 19 }
for tier = 1, 4 do
	local tn = TIER_NAMES[tier]
	add({
		Id = tn .. "Axe", Name = tn .. " Axe", Kind = "Tool",
		Description = if tier == 1 then "Chops small trees." elseif tier == 2 then "Chops large trees too. Decent against wooden walls." else "Fast, durable chopping.",
		Icon = icon("🪓", TIER_COLORS[tier]),
		Damage = TIER_DMG[tier], Cooldown = 0.7, Range = 6.5, Durability = TIER_DUR[tier], ToolType = "Axe", ToolTier = tier,
		ToolPower = TIER_POWER[tier], StructureMult = 1.5 + tier * 0.25, AnimalMult = 1,
	})
	add({
		Id = tn .. "Pickaxe", Name = tn .. " Pickaxe", Kind = "Tool",
		Description = if tier == 1 then "Breaks small stones." elseif tier == 2 then "Breaks large stones too." else "Fast, durable mining.",
		Icon = icon("⛏", TIER_COLORS[tier]),
		Damage = TIER_DMG[tier], Cooldown = 0.75, Range = 6.5, Durability = TIER_DUR[tier], ToolType = "Pickaxe", ToolTier = tier,
		ToolPower = TIER_POWER[tier], StructureMult = 1.25 + tier * 0.25, AnimalMult = 1,
	})
end
add({
	Id = "RepairHammer", Name = "Repair Hammer", Kind = "Tool", Description = "Repairs your team's structures using resources.",
	Icon = icon("⚒", STONE),
	Damage = 7, Cooldown = 0.8, Range = 7, Durability = 200, StructureMult = 0.3, AnimalMult = 1,
})

-- Utility / worn / pouches ---------------------------------------------------------
add({ Id = "Canteen", Name = "Canteen", Kind = "Utility", Description = "Fill at a stream. Pour on an enemy fire at night.", Icon = icon("💧", BLUE) })
add({ Id = "Armor", Name = "Leather Armor", Kind = "Armor", Description = "Worn. Reduces incoming damage by 25%.", Icon = icon("▣", LEATHER), Durability = 300, DamageReduction = 0.25 })
add({ Id = "Bandage", Name = "Bandage", Kind = "Consumable", Description = "Heals 20 HP over a 3 s use. Interrupted by damage.", Icon = icon("✚", RED), Heal = 20, UseTime = 3 })
-- Stronger healing lives in the pack (stackable, dropped on death like materials).
add({ Id = "FirstAid", Name = "First Aid Kit", Kind = "Resource", Description = "Heals 50 HP over a 5 s use. Interrupted by damage.", Icon = icon("✚", Color3.fromRGB(230, 230, 230), "Square"), Heal = 50, UseTime = 5 })
add({ Id = "Medkit", Name = "Medkit", Kind = "Resource", Description = "Heals 100 HP over an 8 s use. Interrupted by damage.", Icon = icon("✚", Color3.fromRGB(80, 200, 120), "Square"), Heal = 100, UseTime = 8 })
add({ Id = "Arrow", Name = "Arrows", Kind = "Ammo", Description = "Ammunition for bows.", Icon = icon("🏹", WOOD) })
add({ Id = "Bullet", Name = "Bullets", Kind = "Ammo", Description = "Ammunition for guns.", Icon = icon("•", Color3.fromRGB(200, 170, 90)) })

-- Structures -------------------------------------------------------------------
add({
	Id = "StorageBox", Name = "Storage Box", Kind = "Structure", Description = "Shared team storage (200 units). Enemies can steal from it.",
	Icon = icon("▤", WOOD, "Square"), Health = 400, Size = Vector3.new(6, 4, 4), Material = "Wood", Limit = "Storage",
})
add({
	Id = "WoodWall", Name = "Wooden Wall", Kind = "Structure", Description = "Palisade wall section.",
	Icon = icon("▥", WOOD, "Square"), Health = 250, Size = Vector3.new(10, 9, 1.6), Material = "Wood", Limit = "Wall",
})
add({
	Id = "Gate", Name = "Gate", Kind = "Structure", Description = "Opens for your team only.",
	Icon = icon("Π", WOOD, "Square"), Health = 300, Size = Vector3.new(10, 9, 1.6), Material = "Wood", Limit = "Wall",
})
add({
	Id = "Spikes", Name = "Spikes", Kind = "Structure", Description = "Damages enemies who touch it (15 per second).",
	Icon = icon("▲", WOOD, "Square"), Health = 120, Size = Vector3.new(8, 3, 3), Material = "Wood", Limit = "Spikes",
	Damage = 15,
})
add({
	Id = "ReinforcedWall", Name = "Reinforced Wall", Kind = "Structure", Description = "Stone-faced wall. Very tough.",
	Icon = icon("▦", STONE, "Square"), Health = 700, Size = Vector3.new(10, 10, 2.4), Material = "Stone", Limit = "Wall",
})
add({
	Id = "Watchtower", Name = "Watchtower", Kind = "Structure", Description = "Raised platform with a ladder. See further, shoot down.",
	Icon = icon("🏰", WOOD, "Square"), Health = 500, Size = Vector3.new(8, 16, 8), Material = "Wood", Limit = "Watchtower",
})

return Items
