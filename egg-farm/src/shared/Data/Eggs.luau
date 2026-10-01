--!strict
-- Egg progression. Each egg is one "farm": REBIRTH moves to the next egg and starts a new farm.
-- STRUCTURE follows the reference (a starting egg plus 9 unlockable eggs, each with its own farm
-- theme, unlocked by Farm Value). NAMES, THEMES AND ALL NUMBERS ARE ORIGINAL DESIGN VALUES:
-- the reference's egg values, thresholds and formulas are unknown (docs/REFERENCE_COVERAGE.md).

export type Egg = {
	id: string,
	name: string,
	theme: string, -- key into Data/Themes
	value: number, -- cash per egg sold, before multipliers
	costScale: number, -- every cash price on this farm is multiplied by this
	requirement: number, -- Farm Value needed to REBIRTH into the next egg (or PRESTIGE on the last)
	rebirthGold: number, -- Gold Eggs granted when you rebirth INTO this egg
}

local VALUE_STEP = 40 -- each egg sells for 40x the previous one
local COST_STEP = 30 -- prices grow 30x per egg (values grow 40x), so each new farm earns faster
-- Farm Value needed to leave each farm. Tuned with tools/sim.luau (a plain greedy player with no
-- boosts or passes) so each farm takes a little longer than the last: ~20 min for the first,
-- growing ~5 min per egg. DESIGN VALUES.
local REQUIREMENTS = { 1e5, 3e7, 2.5e11, 1e14, 7e15, 1.2e18, 7e19, 6e21, 3e23, 1.5e25 }

local defs = {
	{ "farm", "Farm Egg", "meadow" },
	{ "clover", "Clover Egg", "clover" },
	{ "honey", "Honey Egg", "honey" },
	{ "seashell", "Seashell Egg", "beach" },
	{ "frost", "Frost Egg", "snow" },
	{ "cactus", "Cactus Egg", "desert" },
	{ "magma", "Magma Egg", "volcano" },
	{ "crystal", "Crystal Egg", "crystal" },
	{ "nebula", "Nebula Egg", "space" },
	{ "sunburst", "Sunburst Egg", "golden" },
}

local list: { Egg } = {}
for i, d in defs do
	list[i] = {
		id = d[1],
		name = d[2],
		theme = d[3],
		value = VALUE_STEP ^ (i - 1),
		costScale = COST_STEP ^ (i - 1),
		requirement = REQUIREMENTS[i],
		rebirthGold = if i == 1 then 0 else 15 * i,
	}
end

return {
	List = list,
	Count = #list,
	VALUE_STEP = VALUE_STEP,
	COST_STEP = COST_STEP,
}
