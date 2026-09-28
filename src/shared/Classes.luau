--!strict
-- Classes (spec): permanent Diamond unlocks, one equipped before a match and locked
-- for it. Specialisations / sidegrades, never raw damage or health tiers.
-- Effect keys are read by PowerupService (see there for what each one does).

export type Def = {
	Id: string,
	Name: string,
	Price: number, -- Diamonds (0 = free)
	Order: number,
	Glyph: string,
	Color: { number },
	Summary: string,
	Lines: { string },
	Tip: string?, -- short play-style hint for the Class Hall (text only)
	Effects: { [string]: number },
}

local Classes = {}

Classes.List = {
	{
		Id = "Survivor", Name = "Survivor", Price = 0, Order = 1, Glyph = "⛺", Color = { 170, 190, 150 },
		Summary = "Balanced all-rounder (free).",
		Lines = { "+5% stamina regeneration", "+5% tool durability" },
		Tip = "Good at a bit of everything. Pick it while you learn the map.",
		Effects = { StaminaRegen = 0.05, ToolWear = -0.05 },
	},
	{
		Id = "Lumberjack", Name = "Lumberjack", Price = 40, Order = 2, Glyph = "🪓", Color = { 180, 120, 70 },
		Summary = "Chops faster and gentler. No extra Wood.",
		Lines = { "~15% faster chopping", "~15% less axe wear", "No extra Wood (yields stay exact)" },
		Tip = "Gather Wood early so your team can build walls and feed the fire sooner.",
		Effects = { AxeSpeed = 0.15, AxeWear = -0.15 },
	},
	{
		Id = "Miner", Name = "Miner", Price = 50, Order = 3, Glyph = "⛏", Color = { 150, 150, 170 },
		Summary = "Mines faster and sees better underground.",
		Lines = { "~15% faster mining", "~15% less pickaxe wear", "Slightly better visibility in caves" },
		Tip = "Head for caves and ore; your team's better tools depend on you.",
		Effects = { PickSpeed = 0.15, PickWear = -0.15, CaveSight = 1 },
	},
	{
		Id = "Hunter", Name = "Hunter", Price = 75, Order = 4, Glyph = "🏹", Color = { 110, 160, 90 },
		Summary = "Wildlife specialist.",
		Lines = { "~10% faster bow draw", "+1 hide from every animal", "Nearby wildlife shows on your map", "Quieter through vegetation" },
		Tip = "Hunt for hides and watch the map for wildlife moving nearby.",
		Effects = { DrawSpeed = 0.10, ExtraHide = 1, TrackWildlife = 1, QuietBrush = 1 },
	},
	{
		Id = "Scavenger", Name = "Scavenger", Price = 100, Order = 5, Glyph = "🔍", Color = { 220, 180, 70 },
		Summary = "Finds and carries more.",
		Lines = { "Faster searching (+30%)", "+2 pack slots", "Senses containers within 40 studs", "Small chance of extra common loot" },
		Tip = "Search every shed and chest; your extra slots carry for the team.",
		Effects = { SearchSpeed = 0.30, BonusSlots = 2, ContainerSense = 40, ExtraLoot = 0.15 },
	},
	{
		Id = "Raider", Name = "Raider", Price = 150, Order = 6, Glyph = "🔨", Color = { 200, 90, 70 },
		Summary = "Storage breaching specialist. NO faster fire snuffing.",
		Lines = { "~25% faster storage breaching", "Quieter breaching (half the alert radius)", "Breaching tools last ~25% longer" },
		Tip = "Break into enemy storage fast and quietly, then get out.",
		Effects = { BreachSpeed = 0.25, QuietBreach = 1, BreachWear = -0.25 },
	},
	{
		Id = "Tracker", Name = "Tracker", Price = 200, Order = 7, Glyph = "👣", Color = { 150, 110, 200 },
		Summary = "Reads trails. NO wallhacks.",
		Lines = { "Sees injured players' recent blood trails (delayed)", "Directional cue when a nearby player is hurt" },
		Tip = "Follow blood trails to find players who are already hurt.",
		Effects = { BloodTrails = 1, HurtCues = 1 },
	},
} :: { Def }

Classes.ById = {} :: { [string]: Def }
for _, d in Classes.List do
	Classes.ById[d.Id] = d
end

Classes.Default = "Survivor"

return Classes
