--!strict
-- Resource node definitions: the single place for gathering balance.
-- Pure data (no Roblox types) so the CLI tests can load it. Used by
-- Logic/ResourceRules (state machine + drops), LayoutGen (placement) and
-- GatherService (world behaviour).
--
-- Fields
--   Kind            "Tree" (tool hits, fells, stump, regrows from a sapling)
--                   | "Harvest" (hand/tool channel, becomes exhausted, refills)
--   Label           prompt / UI name
--   Health          trees: chop points (a hit removes the tool's Power);
--                   harvest nodes: number of gathers before exhaustion
--   RequiredTool    tool class (Items[..].ToolType: "Axe" | "Pickaxe") or "Hand"
--   MinTier         minimum Items[..].ToolTier (1 Crude, 2 Stone, 3 Iron, 4 Steel); nil = any
--   Yield           exact total the node gives, spread over its hits by damage dealt
--                   (spec: small tree = EXACTLY 4 Wood). Replaces PerHit when present.
--   HarvestTime     seconds per hand/prompt gather (trees: seconds per prompt chop)
--   PerHit          items granted on every successful hit/gather
--   Drops           rolled once when the node is felled/exhausted:
--                   { Item, Min, Max, Chance? }
--   FellTime        trees: seconds of the falling animation before the stump
--   RespawnTime     seconds from felled/exhausted until it starts regrowing
--   GrowTime        seconds of regrowth (sapling scale-up / berries reappearing)
--   Range           interaction distance (studs)
--   Rarity          "Common" | "Uncommon" | "Rare" (UI tint + placement weight)
--   Placement       { PerSector, NearCamp, MinCenterDist?, MaxCenterDist?, Radius }
--                   per-wedge counts; the layout is rotated for fairness, so
--                   every clan gets identical resources
--   Sounds          { Hit, Break } keys into shared/Sounds
--   Effects         { Hit, Break } client particle presets (Effects.luau)
--   Model           Flora builder name (+ ModelArgs)

export type Drop = { Item: string, Min: number, Max: number, Chance: number? }
export type Def = {
	Id: string,
	Kind: string,
	Label: string,
	Health: number,
	RequiredTool: string,
	MinTier: number?,
	Yield: { [string]: number }?,
	HarvestTime: number,
	PerHit: { [string]: number },
	Drops: { Drop },
	FellTime: number,
	RespawnTime: number,
	GrowTime: number,
	Range: number,
	Rarity: string,
	Placement: { PerSector: number, NearCamp: number, MinCenterDist: number?, MaxCenterDist: number?, Radius: number, Poi: boolean? },
	Sounds: { Hit: string, Break: string },
	Effects: { Hit: string, Break: string },
	Model: string,
	ModelArgs: { any },
}

local Resources = {}

-- Hand gathering counts as a tool with power 1.
Resources.HandPower = 1

-- The order resources are placed in (big blockers first).
Resources.Order = {
	"TreeLarge", "TreeMedium", "TreeSmall", "DeadTree",
	"LargeRockPile", "RockPile", "LooseStones", "Twigs", "FibrePlant", "BerryBush", "Mushrooms",
}

-- POI-only nodes (placed by LayoutGen at caves, mines, vehicles, industrial sites):
-- Placement.Poi = true and they are not in Resources.Order.
local function poiNode(id: string, label: string, tool: string, tier: number, health: number, yield: { [string]: number }, drops: { any }, model: string, respawn: number, rarity: string): Def
	return {
		Id = id, Kind = "Harvest", Label = label,
		Health = health, RequiredTool = tool, MinTier = tier, HarvestTime = 1.0,
		PerHit = {}, Yield = yield,
		Drops = drops,
		FellTime = 0, RespawnTime = respawn, GrowTime = 2,
		Range = 11, Rarity = rarity,
		Placement = { PerSector = 0, NearCamp = 0, Radius = 3, Poi = true },
		Sounds = { Hit = "Gather", Break = "Gather" },
		Effects = { Hit = "Stone", Break = "Dust" },
		Model = model, ModelArgs = {},
	}
end

local defs: { [string]: Def } = {
	ScrapPile = poiNode("ScrapPile", "Scrap Pile", "Pickaxe", 1, 40, { Scrap = 4 }, {}, "ScrapPile", 180, "Uncommon"),
	CoalDeposit = poiNode("CoalDeposit", "Coal Seam", "Pickaxe", 2, 90, { Coal = 6 }, {}, "CoalDeposit", 200, "Uncommon"),
	IronDeposit = poiNode("IronDeposit", "Iron Deposit", "Pickaxe", 2, 110, { Iron = 5 }, {}, "IronDeposit", 240, "Rare"),
	RichIronDeposit = poiNode("RichIronDeposit", "Rich Iron Vein", "Pickaxe", 3, 160, { Iron = 10 }, { { Item = "RareComponent", Min = 1, Max = 1, Chance = 0.15 } }, "RichIronDeposit", 420, "Rare"),
	TreeSmall = {
		-- Spec: EXACTLY 4 Wood, Crude Axe or better.
		Id = "TreeSmall", Kind = "Tree", Label = "Small Tree",
		Health = 40, RequiredTool = "Axe", MinTier = 1, HarvestTime = 0.7,
		PerHit = { Wood = 1 }, Yield = { Wood = 4 },
		Drops = { { Item = "Stick", Min = 1, Max = 2, Chance = 0.6 } },
		FellTime = 1.4, RespawnTime = 90, GrowTime = 4,
		Range = 11, Rarity = "Common",
		Placement = { PerSector = 22, NearCamp = 5, Radius = 3 },
		Sounds = { Hit = "Chop", Break = "TreeFall" },
		Effects = { Hit = "Bark", Break = "Leaves" },
		Model = "ResourceTree", ModelArgs = { "Small" },
	},
	TreeMedium = {
		-- Between the spec's small (4) and large (16) trees: 8 Wood, Crude Axe or better.
		Id = "TreeMedium", Kind = "Tree", Label = "Tree",
		Health = 80, RequiredTool = "Axe", MinTier = 1, HarvestTime = 0.7,
		PerHit = { Wood = 1 }, Yield = { Wood = 8 },
		Drops = { { Item = "Stick", Min = 1, Max = 3 } },
		FellTime = 1.6, RespawnTime = 150, GrowTime = 5,
		Range = 12, Rarity = "Common",
		Placement = { PerSector = 14, NearCamp = 2, MinCenterDist = 140, Radius = 4 },
		Sounds = { Hit = "Chop", Break = "TreeFall" },
		Effects = { Hit = "Bark", Break = "Leaves" },
		Model = "ResourceTree", ModelArgs = { "Medium" },
	},
	TreeLarge = {
		-- Big yield, slow to fell (loud, exposed): found deeper in the forest.
		-- Spec: EXACTLY 16 Wood, Stone Axe or better.
		Id = "TreeLarge", Kind = "Tree", Label = "Large Tree",
		Health = 160, RequiredTool = "Axe", MinTier = 2, HarvestTime = 0.7,
		PerHit = { Wood = 1 }, Yield = { Wood = 16 },
		Drops = { { Item = "Stick", Min = 2, Max = 4 } },
		FellTime = 2, RespawnTime = 240, GrowTime = 6,
		Range = 13, Rarity = "Uncommon",
		Placement = { PerSector = 6, NearCamp = 0, MaxCenterDist = 330, Radius = 6 },
		Sounds = { Hit = "Chop", Break = "TreeFall" },
		Effects = { Hit = "Bark", Break = "Leaves" },
		Model = "ResourceTree", ModelArgs = { "Large" },
	},
	DeadTree = {
		Id = "DeadTree", Kind = "Tree", Label = "Dead Tree",
		Health = 40, RequiredTool = "Axe", MinTier = 1, HarvestTime = 0.7,
		PerHit = { Stick = 1 }, Yield = { Wood = 3, Stick = 4 },
		Drops = {},
		FellTime = 1.4, RespawnTime = 180, GrowTime = 4,
		Range = 11, Rarity = "Common",
		Placement = { PerSector = 6, NearCamp = 1, Radius = 3 },
		Sounds = { Hit = "Chop", Break = "TreeFall" },
		Effects = { Hit = "Splinter", Break = "Dust" },
		Model = "DeadTree", ModelArgs = {},
	},
	RockPile = {
		-- Spec: small stone = 3 Stone, Crude Pickaxe or better.
		Id = "RockPile", Kind = "Harvest", Label = "Small Stone",
		Health = 30, RequiredTool = "Pickaxe", MinTier = 1, HarvestTime = 0.9,
		PerHit = { Stone = 1 }, Yield = { Stone = 3 },
		Drops = {},
		FellTime = 0, RespawnTime = 90, GrowTime = 1,
		Range = 10, Rarity = "Common",
		Placement = { PerSector = 10, NearCamp = 3, Radius = 3 },
		Sounds = { Hit = "Gather", Break = "Gather" },
		Effects = { Hit = "Stone", Break = "Dust" },
		Model = "RockPile", ModelArgs = {},
	},
	LargeRockPile = {
		-- Spec: large stone = 12 Stone, Stone Pickaxe or better.
		Id = "LargeRockPile", Kind = "Harvest", Label = "Large Stone",
		Health = 120, RequiredTool = "Pickaxe", MinTier = 2, HarvestTime = 0.9,
		PerHit = { Stone = 1 }, Yield = { Stone = 12 },
		Drops = {},
		FellTime = 0, RespawnTime = 180, GrowTime = 2,
		Range = 12, Rarity = "Uncommon",
		Placement = { PerSector = 4, NearCamp = 0, MinCenterDist = 120, Radius = 5 },
		Sounds = { Hit = "Gather", Break = "Gather" },
		Effects = { Hit = "Stone", Break = "Dust" },
		Model = "LargeRockPile", ModelArgs = {},
	},
	LooseStones = {
		Id = "LooseStones", Kind = "Harvest", Label = "Loose Stones",
		Health = 1, RequiredTool = "Hand", HarvestTime = 0.6,
		PerHit = { Stone = 2 },
		Drops = {},
		FellTime = 0, RespawnTime = 60, GrowTime = 1,
		Range = 9, Rarity = "Common",
		Placement = { PerSector = 12, NearCamp = 3, Radius = 2 },
		Sounds = { Hit = "Gather", Break = "Gather" },
		Effects = { Hit = "Stone", Break = "Dust" },
		Model = "LooseStones", ModelArgs = {},
	},
	Twigs = {
		Id = "Twigs", Kind = "Harvest", Label = "Twig Pile",
		Health = 3, RequiredTool = "Hand", HarvestTime = 0.8,
		PerHit = { Stick = 2 },
		Drops = {},
		FellTime = 0, RespawnTime = 60, GrowTime = 1,
		Range = 10, Rarity = "Common",
		Placement = { PerSector = 12, NearCamp = 4, Radius = 2.5 },
		Sounds = { Hit = "Gather", Break = "Gather" },
		Effects = { Hit = "Splinter", Break = "Leaves" },
		Model = "TwigPile", ModelArgs = {},
	},
	FibrePlant = {
		Id = "FibrePlant", Kind = "Harvest", Label = "Fibre Fern",
		Health = 2, RequiredTool = "Hand", HarvestTime = 0.9,
		PerHit = { Plant = 2 },
		Drops = {},
		FellTime = 0, RespawnTime = 60, GrowTime = 2,
		Range = 10, Rarity = "Common",
		Placement = { PerSector = 14, NearCamp = 4, Radius = 2.5 },
		Sounds = { Hit = "Gather", Break = "Gather" },
		Effects = { Hit = "Leaves", Break = "Leaves" },
		Model = "FibrePlant", ModelArgs = {},
	},
	BerryBush = {
		Id = "BerryBush", Kind = "Harvest", Label = "Berry Bush",
		Health = 2, RequiredTool = "Hand", HarvestTime = 0.9,
		PerHit = { Berries = 2 },
		Drops = {},
		FellTime = 0, RespawnTime = 75, GrowTime = 3,
		Range = 10, Rarity = "Common",
		Placement = { PerSector = 10, NearCamp = 2, Radius = 3 },
		Sounds = { Hit = "Gather", Break = "Gather" },
		Effects = { Hit = "Berries", Break = "Leaves" },
		Model = "BerryBush", ModelArgs = {},
	},
	Mushrooms = {
		-- Better food, grows in the damp deep forest.
		Id = "Mushrooms", Kind = "Harvest", Label = "Mushrooms",
		Health = 1, RequiredTool = "Hand", HarvestTime = 0.8,
		PerHit = { Mushroom = 2 },
		Drops = {},
		FellTime = 0, RespawnTime = 100, GrowTime = 3,
		Range = 9, Rarity = "Uncommon",
		Placement = { PerSector = 7, NearCamp = 0, MaxCenterDist = 340, Radius = 2 },
		Sounds = { Hit = "Gather", Break = "Gather" },
		Effects = { Hit = "Spores", Break = "Spores" },
		Model = "MushroomPatch", ModelArgs = {},
	},
}

Resources.Defs = defs

function Resources.Get(id: string): Def?
	return defs[id]
end

-- Food: resource items that can be eaten from the pack.
-- Spec: no fast passive regen; food is a small top-up.
Resources.Food = {
	Berries = { Heal = 5, Cooldown = 1.5 },
	Mushroom = { Heal = 8, Cooldown = 1.5 },
}

-- Respawns wait until nothing stands on the spot.
Resources.RespawnClearance = 5
-- How often the service ticks node timers.
Resources.TickInterval = 1

return Resources
