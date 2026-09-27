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
	Stacks: number?, -- storage: stack slots
	BreachTool: string?, -- tools: "Crowbar" | "Sledgehammer" (storage breaching)
	Door: boolean?, -- structures: has an owner-only door
	Hold: number?, -- traps: seconds the victim is held in place
	Detect: number?, -- alarms: detection radius (studs)
	ArmorSlot: string?, -- "Head" | "Chest" | "Legs"
	Headshots: boolean?, -- ranged: head hits deal Config.Combat.HeadshotMult
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
local ROPE_COLOR = Color3.fromRGB(205, 180, 120)

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
-- Ranged (spec): Crude Bow II, Hunting Bow III, Crossbow III/IV. Headshots x1.75, and
-- no early bow one-shots a full-health player (see CombatRules.spec).
add({
	Id = "Bow", Name = "Crude Bow", Kind = "Weapon", Description = "Hold to draw, release to fire. Uses arrows.",
	Icon = icon("》", WOOD),
	Damage = 22, Cooldown = 0.35, DrawTime = 0.7, Range = 200, Durability = 100, Ranged = "Arrow",
	AmmoType = "Arrow", Spread = 1.4, StructureMult = 0.3, AnimalMult = 1, Headshots = true,
})
add({
	Id = "HuntingBow", Name = "Hunting Bow", Kind = "Weapon", Description = "Stronger draw, flatter shots. Uses arrows.",
	Icon = icon("》", Color3.fromRGB(120, 80, 50)),
	Damage = 34, Cooldown = 0.35, DrawTime = 0.8, Range = 240, Durability = 180, Ranged = "Arrow",
	AmmoType = "Arrow", Spread = 1.0, StructureMult = 0.35, AnimalMult = 1.1, Headshots = true,
})
add({
	Id = "Crossbow", Name = "Crossbow", Kind = "Weapon", Description = "Slow to load (hold), hits hard. Uses bolts.",
	Icon = icon("✚", Color3.fromRGB(110, 110, 116)),
	Damage = 48, Cooldown = 0.4, DrawTime = 1.6, Range = 260, Durability = 220, Ranged = "Arrow",
	AmmoType = "Bolt", Spread = 0.6, StructureMult = 0.5, AnimalMult = 1.1, Headshots = true,
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
-- Breaching tools (spec progression: normal tools -> Crowbar -> Sledgehammer -> Breaching Charge)
add({
	Id = "Crowbar", Name = "Crowbar", Kind = "Tool", Description = "Breaches storage faster. Opens Metal Lockers.",
	Icon = icon("⌐", Color3.fromRGB(150, 60, 50)),
	Damage = 12, Cooldown = 0.75, Range = 6, Durability = 120, BreachTool = "Crowbar", StructureMult = 1.2, AnimalMult = 1,
})
add({
	Id = "Sledgehammer", Name = "Sledgehammer", Kind = "Tool", Description = "Breaches any storage, including Survival Safes. Heavy against walls.",
	Icon = icon("⚒", Color3.fromRGB(110, 110, 116)),
	Damage = 20, Cooldown = 1.2, Range = 6.5, Durability = 200, BreachTool = "Sledgehammer", StructureMult = 3, AnimalMult = 1,
})
add({ Id = "BreachingCharge", Name = "Breaching Charge", Kind = "Resource", Description = "Blows any storage open in 5 s. Very loud; damages what's around it.", Icon = icon("✹", Color3.fromRGB(220, 120, 40), "Square") })

add({
	Id = "RepairHammer", Name = "Repair Hammer", Kind = "Tool", Description = "Repairs your team's structures using resources.",
	Icon = icon("⚒", STONE),
	Damage = 7, Cooldown = 0.8, Range = 7, Durability = 200, StructureMult = 0.3, AnimalMult = 1,
})

-- Backpacks (worn, kept on death): pack slots 10 / 16 / 24 / 32 / 40 by tier.
local PACKS: { { Id: string, Name: string, Slots: number, Color: Color3 } } = {
	{ Id = "FibrePack", Name = "Fibre Pack", Slots = 10, Color = Color3.fromRGB(150, 170, 110) },
	{ Id = "HidePack", Name = "Hide Pack", Slots = 16, Color = LEATHER },
	{ Id = "FramePack", Name = "Scrap-Frame Pack", Slots = 24, Color = Color3.fromRGB(140, 120, 100) },
	{ Id = "IronPack", Name = "Iron-Frame Pack", Slots = 32, Color = Color3.fromRGB(150, 110, 96) },
	{ Id = "ExpeditionPack", Name = "Expedition Pack", Slots = 40, Color = Color3.fromRGB(80, 110, 90) },
}
for tier, pack in PACKS do
	add({ Id = pack.Id, Name = pack.Name, Kind = "Backpack", Description = string.format("Worn. %d pack slots. Kept when you die.", pack.Slots), Icon = icon("🎒", pack.Color), Slots = pack.Slots, Tier = tier })
end

-- Utility / worn / pouches ---------------------------------------------------------
add({ Id = "Canteen", Name = "Canteen", Kind = "Utility", Description = "Fill at a stream. Pour on an enemy fire at night.", Icon = icon("💧", BLUE) })
-- Armour (spec): Head / Chest / Legs, Hide -> Reinforced Hide -> Scrap -> Iron -> Tactical.
-- A full set reduces damage by 15 / 22 / 30 / 38 / 46% (split 25 / 45 / 30% across pieces).
local ARMOR_TIERS: { { Key: string, Name: string, Set: number, Dur: number, Color: Color3 } } = {
	{ Key = "Hide", Name = "Hide", Set = 0.15, Dur = 120, Color = LEATHER },
	{ Key = "ReinforcedHide", Name = "Reinforced Hide", Set = 0.22, Dur = 200, Color = Color3.fromRGB(120, 76, 50) },
	{ Key = "Scrap", Name = "Scrap", Set = 0.30, Dur = 300, Color = Color3.fromRGB(128, 112, 96) },
	{ Key = "Iron", Name = "Iron", Set = 0.38, Dur = 420, Color = Color3.fromRGB(110, 114, 124) },
	{ Key = "Tactical", Name = "Tactical", Set = 0.46, Dur = 560, Color = Color3.fromRGB(70, 84, 70) },
}
local ARMOR_PIECES: { { Slot: string, Name: string, Share: number, Glyph: string } } = {
	{ Slot = "Head", Name = "Helmet", Share = 0.25, Glyph = "⛑" },
	{ Slot = "Chest", Name = "Chestpiece", Share = 0.45, Glyph = "▣" },
	{ Slot = "Legs", Name = "Leggings", Share = 0.30, Glyph = "‖" },
}
for tier, at in ARMOR_TIERS do
	for _, piece in ARMOR_PIECES do
		add({
			Id = at.Key .. piece.Slot, Name = at.Name .. " " .. piece.Name, Kind = "Armor", ArmorSlot = piece.Slot, Tier = tier,
			Description = string.format("Worn (%s). -%d%% damage; a full %s set gives -%d%%.", piece.Slot:lower(), math.floor(at.Set * piece.Share * 100 + 0.5), at.Name, math.floor(at.Set * 100 + 0.5)),
			Icon = icon(piece.Glyph, at.Color), Durability = math.floor(at.Dur * (0.6 + piece.Share)), DamageReduction = at.Set * piece.Share,
		})
	end
end
-- Legacy loot item: a hide chestpiece.
add({ Id = "Armor", Name = "Leather Vest", Kind = "Armor", ArmorSlot = "Chest", Tier = 1, Description = "Worn (chest). -7% damage.", Icon = icon("▣", LEATHER), Durability = 150, DamageReduction = 0.15 * 0.45 })
add({ Id = "Bandage", Name = "Bandage", Kind = "Consumable", Description = "Heals 20 HP over a 3 s use. Interrupted by damage.", Icon = icon("✚", RED), Heal = 20, UseTime = 3 })
-- Stronger healing lives in the pack (stackable, dropped on death like materials).
add({ Id = "FirstAid", Name = "First Aid Kit", Kind = "Resource", Description = "Heals 50 HP over a 5 s use. Interrupted by damage.", Icon = icon("✚", Color3.fromRGB(230, 230, 230), "Square"), Heal = 50, UseTime = 5 })
add({ Id = "Medkit", Name = "Medkit", Kind = "Resource", Description = "Heals 100 HP over an 8 s use. Interrupted by damage.", Icon = icon("✚", Color3.fromRGB(80, 200, 120), "Square"), Heal = 100, UseTime = 8 })
add({ Id = "Arrow", Name = "Arrows", Kind = "Ammo", Description = "Ammunition for bows.", Icon = icon("🏹", WOOD) })
add({ Id = "Bolt", Name = "Bolts", Kind = "Ammo", Description = "Ammunition for crossbows.", Icon = icon("➶", Color3.fromRGB(110, 110, 116)) })
add({ Id = "Bullet", Name = "Bullets", Kind = "Ammo", Description = "Ammunition for guns.", Icon = icon("•", Color3.fromRGB(200, 170, 90)) })

-- Structures -------------------------------------------------------------------
-- Storage (spec): Wooden Crate I ~12 stacks, Reinforced Chest II ~20, Metal Locker III ~30,
-- Survival Safe (high tier) ~45. Enemies breach it to unlock it; the owner can resecure.
add({
	Id = "StorageBox", Name = "Wooden Crate", Kind = "Structure", Description = "12 stack slots. Enemies can breach it with any tool.",
	Icon = icon("▤", WOOD, "Square"), Health = 400, Size = Vector3.new(6, 4, 4), Material = "Wood", Limit = "Storage", Tier = 1, Stacks = 12,
})
add({
	Id = "ReinforcedChest", Name = "Reinforced Chest", Kind = "Structure", Description = "20 stack slots. Iron-banded; slower to breach.",
	Icon = icon("▤", Color3.fromRGB(120, 96, 70), "Square"), Health = 800, Size = Vector3.new(6, 4.4, 4), Material = "Wood", Limit = "Storage", Tier = 2, Stacks = 20,
})
add({
	Id = "MetalLocker", Name = "Metal Locker", Kind = "Structure", Description = "30 stack slots. Needs a Crowbar or better to breach.",
	Icon = icon("▯", Color3.fromRGB(120, 130, 140), "Square"), Health = 1400, Size = Vector3.new(4, 7, 3), Material = "Scrap", Limit = "Storage", Tier = 3, Stacks = 30,
})
add({
	Id = "SurvivalSafe", Name = "Survival Safe", Kind = "Structure", Description = "45 stack slots. Needs a Sledgehammer or a Breaching Charge.",
	Icon = icon("▣", Color3.fromRGB(70, 74, 80), "Square"), Health = 2400, Size = Vector3.new(4.5, 5, 4.5), Material = "Iron", Limit = "Storage", Tier = 4, Stacks = 45,
})
add({
	Id = "WoodWall", Name = "Wooden Wall", Kind = "Structure", Description = "Palisade wall section.",
	Icon = icon("▥", WOOD, "Square"), Health = 250, Size = Vector3.new(10, 9, 1.6), Material = "Wood", Limit = "Wall",
})
add({
	Id = "Gate", Name = "Wooden Door", Kind = "Structure", Description = "Opens for you only.",
	Icon = icon("Π", WOOD, "Square"), Health = 300, Size = Vector3.new(10, 9, 1.6), Material = "Wood", Limit = "Wall", Door = true,
})
add({
	Id = "WoodFloor", Name = "Wooden Floor", Kind = "Structure", Description = "10×10 platform. Level uneven ground or build a raised base.",
	Icon = icon("▭", WOOD, "Square"), Health = 300, Size = Vector3.new(10, 1, 10), Material = "Wood", Limit = "Floor",
})
add({
	Id = "Spikes", Name = "Spike Barricade", Kind = "Structure", Description = "Damages enemies who touch it (15 per second). Counts as a trap.",
	Icon = icon("▲", WOOD, "Square"), Health = 120, Size = Vector3.new(8, 3, 3), Material = "Wood", Limit = "Trap",
	Damage = 15,
})
add({
	Id = "ReinforcedWall", Name = "Reinforced Wall", Kind = "Structure", Description = "Stone-faced wall. Very tough.",
	Icon = icon("▦", STONE, "Square"), Health = 700, Size = Vector3.new(10, 10, 2.4), Material = "Stone", Limit = "Wall",
})
add({
	Id = "ReinforcedDoor", Name = "Reinforced Door", Kind = "Structure", Description = "Iron-strapped door. Opens for you only.",
	Icon = icon("Π", Color3.fromRGB(110, 84, 58), "Square"), Health = 700, Size = Vector3.new(10, 9, 1.6), Material = "Stone", Limit = "Wall", Door = true,
})
add({
	Id = "WindowWall", Name = "Window Wall", Kind = "Structure", Description = "Reinforced wall with a shooting window.",
	Icon = icon("▣", STONE, "Square"), Health = 600, Size = Vector3.new(10, 10, 2.4), Material = "Stone", Limit = "Wall",
})
add({
	Id = "TripwireAlarm", Name = "Tripwire Alarm", Kind = "Structure", Description = "Rattles and warns you (with a direction) when an enemy walks through.",
	Icon = icon("〰", ROPE_COLOR, "Square"), Health = 60, Size = Vector3.new(8, 1.5, 1), Material = "Wood", Limit = "Trap",
})
add({
	Id = "Snare", Name = "Snare", Kind = "Structure", Description = "Holds an enemy in place for 2.5 s. Used up when it catches someone.",
	Icon = icon("◎", ROPE_COLOR, "Square"), Health = 50, Size = Vector3.new(3, 1, 3), Material = "Wood", Limit = "Trap", Hold = 2.5,
})
add({
	Id = "ScrapWall", Name = "Scrap Wall", Kind = "Structure", Description = "Salvaged metal sheets. Much tougher than stone.",
	Icon = icon("▥", Color3.fromRGB(128, 112, 96), "Square"), Health = 1200, Size = Vector3.new(10, 10, 2), Material = "Scrap", Limit = "Wall",
})
add({
	Id = "BearTrap", Name = "Bear Trap", Kind = "Structure", Description = "Steel jaws: 35 damage and a 3.5 s hold. Used up when it bites.",
	Icon = icon("✶", Color3.fromRGB(120, 124, 130), "Square"), Health = 150, Size = Vector3.new(3, 1, 3), Material = "Scrap", Limit = "Trap", Damage = 35, Hold = 3.5,
})
add({
	Id = "MetalWall", Name = "Metal Wall", Kind = "Structure", Description = "Heavy riveted plates. Raiding it takes serious tools.",
	Icon = icon("▦", Color3.fromRGB(92, 96, 104), "Square"), Health = 2200, Size = Vector3.new(10, 11, 2.6), Material = "Iron", Limit = "Wall",
})
add({
	Id = "HeavyGate", Name = "Heavy Gate", Kind = "Structure", Description = "Iron-plated gate. Opens for you only.",
	Icon = icon("Π", Color3.fromRGB(92, 96, 104), "Square"), Health = 1800, Size = Vector3.new(10, 9, 1.6), Material = "Iron", Limit = "Wall", Door = true,
})
add({
	Id = "AdvancedAlarm", Name = "Advanced Alarm", Kind = "Structure", Description = "Motion sensor: tells you who is near your base and from which side (no wallhack).",
	Icon = icon("◉", Color3.fromRGB(120, 220, 120), "Square"), Health = 200, Size = Vector3.new(1.5, 5, 1.5), Material = "Iron", Limit = "Trap", Detect = 16,
})
add({
	Id = "Watchtower", Name = "Watchtower", Kind = "Structure", Description = "Raised platform with a ladder. See further, shoot down.",
	Icon = icon("🏰", WOOD, "Square"), Health = 500, Size = Vector3.new(8, 16, 8), Material = "Wood", Limit = "Watchtower",
})

return Items
