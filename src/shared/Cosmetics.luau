--!strict
-- Cosmetics (spec): bought with Coins (or unlocked by account level). Purely
-- visual: outfits, tool/weapon/backpack skins, Campfire/Workbench/storage skins,
-- nameplates, titles, emotes, elimination effects and victory poses.
-- Colours are {r, g, b} so the module stays pure data.

export type Def = {
	Id: string,
	Name: string,
	Type: string, -- one of Cosmetics.Types
	Rarity: string, -- Common | Uncommon | Rare | Epic | Legendary
	Price: number, -- Coins (0 = not sold: level reward / bundle only)
	Level: number?, -- unlocked for free at this account level
	Color: { number }?,
	Color2: { number }?,
	Text: string?, -- titles
}

local Cosmetics = {}

Cosmetics.Types = { "Outfit", "ToolSkin", "BackpackSkin", "CampfireSkin", "WorkbenchSkin", "StorageSkin", "Nameplate", "Title", "Emote", "EliminationFx", "VictoryPose" }

-- Spec price bands (Coins).
Cosmetics.Bands = {
	Common = { 1500, 3000 },
	Uncommon = { 4000, 7500 },
	Rare = { 10000, 17500 },
	Epic = { 20000, 35000 },
	Legendary = { 40000, 75000 },
}

Cosmetics.RarityColor = {
	Common = { 190, 190, 190 },
	Uncommon = { 110, 200, 110 },
	Rare = { 90, 150, 240 },
	Epic = { 180, 100, 230 },
	Legendary = { 250, 180, 60 },
}

local function c(id: string, name: string, typ: string, rarity: string, price: number, col: { number }?, col2: { number }?, text: string?): Def
	return { Id = id, Name = name, Type = typ, Rarity = rarity, Price = price, Color = col, Color2 = col2, Text = text }
end

Cosmetics.List = {
	-- Outfits (body colours: torso, limbs)
	c("OutfitWoodsman", "Woodsman Plaid", "Outfit", "Common", 1800, { 150, 50, 45 }, { 60, 60, 70 }),
	c("OutfitRanger", "Ranger Greens", "Outfit", "Uncommon", 5000, { 80, 110, 70 }, { 110, 95, 70 }),
	c("OutfitHunter", "Autumn Hunter", "Outfit", "Rare", 12000, { 190, 110, 40 }, { 80, 60, 45 }),
	c("OutfitNight", "Night Stalker", "Outfit", "Epic", 25000, { 30, 34, 44 }, { 20, 22, 28 }),
	c("OutfitEmber", "Ember Warden", "Outfit", "Legendary", 50000, { 200, 70, 30 }, { 50, 30, 20 }),
	-- Tool & weapon skins (held-item glow tint)
	c("ToolCopper", "Copper Wrap", "ToolSkin", "Common", 2000, { 200, 120, 70 }),
	c("ToolMoss", "Moss Grip", "ToolSkin", "Uncommon", 4500, { 110, 170, 90 }),
	c("ToolFrost", "Frostbite", "ToolSkin", "Rare", 14000, { 150, 210, 255 }),
	c("ToolGold", "Gilded", "ToolSkin", "Epic", 30000, { 250, 200, 80 }),
	-- Backpack skins
	c("PackCanvas", "Canvas Pack", "BackpackSkin", "Common", 1500, { 170, 160, 120 }),
	c("PackCamo", "Leaf Camo Pack", "BackpackSkin", "Uncommon", 6000, { 80, 110, 60 }),
	c("PackRoyal", "Royal Pack", "BackpackSkin", "Rare", 16000, { 90, 60, 150 }),
	-- Campfire skins (flame colours)
	c("FireBlue", "Blue Flame", "CampfireSkin", "Rare", 15000, { 90, 160, 255 }, { 190, 230, 255 }),
	c("FireGreen", "Spirit Flame", "CampfireSkin", "Epic", 28000, { 90, 230, 120 }, { 200, 255, 200 }),
	c("FirePurple", "Void Flame", "CampfireSkin", "Legendary", 60000, { 170, 80, 255 }, { 230, 190, 255 }),
	-- Workbench / storage skins (plate & crest colours)
	c("BenchOak", "Oak Plate", "WorkbenchSkin", "Common", 2500, { 170, 120, 70 }),
	c("BenchIron", "Ironbound Plate", "WorkbenchSkin", "Uncommon", 7000, { 120, 125, 135 }),
	c("CrateMoss", "Mossy Crest", "StorageSkin", "Common", 2200, { 90, 130, 70 }),
	c("CrateGold", "Gold Crest", "StorageSkin", "Rare", 11000, { 240, 200, 90 }),
	-- Nameplates
	c("PlateBark", "Bark Nameplate", "Nameplate", "Common", 1600, { 110, 80, 50 }),
	c("PlateMoss", "Moss Nameplate", "Nameplate", "Uncommon", 4000, { 70, 110, 60 }),
	c("PlateSilver", "Silver Nameplate", "Nameplate", "Rare", 10000, { 190, 195, 205 }),
	c("PlateGold", "Gold Nameplate", "Nameplate", "Epic", 22000, { 230, 190, 80 }),
	c("PlateEmber", "Ember Nameplate", "Nameplate", "Legendary", 45000, { 230, 100, 40 }),
	-- Titles (some sold, some level rewards)
	c("TitleForager", "Forager", "Title", "Common", 1500, nil, nil, "Forager"),
	c("TitleRaider", "Night Raider", "Title", "Uncommon", 5500, nil, nil, "Night Raider"),
	c("TitleFirekeeper", "Keeper of Flame", "Title", "Rare", 12500, nil, nil, "Keeper of Flame"),
	c("TitleApex", "Apex Survivor", "Title", "Legendary", 75000, nil, nil, "Apex Survivor"),
	-- Emotes (lobby: short pose + particle burst)
	c("EmoteWave", "Wave", "Emote", "Common", 1500, { 255, 255, 255 }),
	c("EmoteFlex", "Flex", "Emote", "Uncommon", 4500, { 255, 200, 120 }),
	c("EmoteCampfire", "Warm Hands", "Emote", "Rare", 11000, { 255, 150, 60 }),
	-- Elimination effects (burst of colour where you eliminate someone)
	c("ElimEmbers", "Ember Burst", "EliminationFx", "Uncommon", 7500, { 255, 130, 50 }),
	c("ElimLeaves", "Leaf Storm", "EliminationFx", "Rare", 17500, { 120, 200, 80 }),
	c("ElimStars", "Starfall", "EliminationFx", "Epic", 35000, { 200, 190, 255 }),
	-- Victory poses (end screen + winner pose)
	c("PoseTorch", "Torch Held High", "VictoryPose", "Rare", 13000),
	c("PoseAxe", "Axe on Shoulder", "VictoryPose", "Epic", 24000),
	c("PoseThrone", "Log Throne", "VictoryPose", "Legendary", 70000),
} :: { Def }

-- Account-level rewards (status, not power): titles + nameplates, never sold.
local LEVEL_REWARDS: { Def } = {
	{ Id = "TitleSprout", Name = "Sprout", Type = "Title", Rarity = "Common", Price = 0, Level = 5, Text = "Sprout" },
	{ Id = "TitleTrailhand", Name = "Trailhand", Type = "Title", Rarity = "Common", Price = 0, Level = 10, Text = "Trailhand" },
	{ Id = "TitleWoodwise", Name = "Woodwise", Type = "Title", Rarity = "Uncommon", Price = 0, Level = 25, Text = "Woodwise" },
	{ Id = "PlateVeteran", Name = "Veteran Nameplate", Type = "Nameplate", Rarity = "Rare", Price = 0, Level = 50, Color = { 120, 150, 200 } },
	{ Id = "TitleElder", Name = "Forest Elder", Type = "Title", Rarity = "Epic", Price = 0, Level = 75, Text = "Forest Elder" },
	{ Id = "TitleLegend", Name = "Legend of the Wilds", Type = "Title", Rarity = "Legendary", Price = 0, Level = 100, Text = "Legend of the Wilds" },
	{ Id = "PlateLegend", Name = "Legend Nameplate", Type = "Nameplate", Rarity = "Legendary", Price = 0, Level = 100, Color = { 250, 210, 90 } },
}
for _, d in LEVEL_REWARDS do
	table.insert(Cosmetics.List, d)
end

Cosmetics.ById = {} :: { [string]: Def }
for _, d in Cosmetics.List do
	Cosmetics.ById[d.Id] = d
end

-- Robux bundles (cosmetics only).
Cosmetics.Bundles = {
	Founder = { "OutfitRanger", "PlateMoss", "TitleForager" },
	Ember = { "FireGreen", "PlateGold", "ElimEmbers" },
} :: { [string]: { string } }

return Cosmetics
