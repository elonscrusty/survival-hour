--!strict
-- Permanent powerups: prices, per-level values and upgrade challenges.
-- Pure data (no Roblox types) so tests can load it.

export type Level = {
	Passive: { [string]: number },
	Ability: { [string]: number },
}

export type Challenge = {
	Stat: string, -- persistent counter name
	Target: number, -- cumulative total required
	Text: string,
}

export type PowerupDef = {
	Id: string,
	Name: string,
	Price: number, -- diamonds to unlock
	Order: number,
	Glyph: string,
	Color: { number },
	Passive: string,
	Ability: string,
	AbilityName: string,
	Levels: { Level },
	Challenges: { [number]: Challenge }, -- key = level being qualified for (2, 3)
	PerMatchCap: number, -- max challenge progress counted per match
}

local Powerups = {}

Powerups.UpgradePriceMult = { [2] = 0.8, [3] = 1.5 }
Powerups.MaxLevel = 3

local list: { PowerupDef } = {
	{
		Id = "Trailblazer", Name = "Trailblazer", Price = 100, Order = 1, Glyph = "»", Color = { 90, 200, 120 },
		Passive = "+{SpeedPct}% move speed",
		Ability = "Burst: +{BurstPct}% speed for {Duration}s and ignore brush slowdown. Cooldown {Cooldown}s.",
		AbilityName = "Burst",
		Levels = {
			{ Passive = { SpeedPct = 4 }, Ability = { BurstPct = 35, Duration = 2.5, Cooldown = 30 } },
			{ Passive = { SpeedPct = 6 }, Ability = { BurstPct = 35, Duration = 3.0, Cooldown = 26 } },
			{ Passive = { SpeedPct = 8 }, Ability = { BurstPct = 40, Duration = 3.5, Cooldown = 22 } },
		},
		Challenges = {
			[2] = { Stat = "DistanceTravelled", Target = 8000, Text = "Travel 8,000 studs in matches" },
			[3] = { Stat = "DistanceTravelled", Target = 30000, Text = "Travel 30,000 studs in matches" },
		},
		PerMatchCap = 2500,
	},
	{
		Id = "Scavenger", Name = "Scavenger", Price = 175, Order = 4, Glyph = "🔍", Color = { 220, 180, 70 },
		Passive = "+{GatherPct}% gathering speed",
		Ability = "Sniff Out: reveal unmarked crates within {Radius} studs for {Duration}s. Cooldown {Cooldown}s.",
		AbilityName = "Sniff Out",
		Levels = {
			{ Passive = { GatherPct = 10 }, Ability = { Radius = 60, Duration = 8, Cooldown = 45 } },
			{ Passive = { GatherPct = 15 }, Ability = { Radius = 80, Duration = 8, Cooldown = 40 } },
			{ Passive = { GatherPct = 20 }, Ability = { Radius = 100, Duration = 10, Cooldown = 35 } },
		},
		Challenges = {
			[2] = { Stat = "CratesOpened", Target = 15, Text = "Open 15 forest crates" },
			[3] = { Stat = "CratesOpened", Target = 50, Text = "Open 50 forest crates" },
		},
		PerMatchCap = 8,
	},
	{
		Id = "Hunter", Name = "Hunter", Price = 150, Order = 3, Glyph = "🎯", Color = { 200, 110, 70 },
		Passive = "+{AnimalDmgPct}% damage to animals",
		Ability = "Track: at night, highlight animals within {Radius} studs for {Duration}s. Cooldown {Cooldown}s.",
		AbilityName = "Track",
		Levels = {
			{ Passive = { AnimalDmgPct = 10 }, Ability = { Radius = 80, Duration = 8, Cooldown = 40 } },
			{ Passive = { AnimalDmgPct = 15 }, Ability = { Radius = 110, Duration = 8, Cooldown = 35 } },
			{ Passive = { AnimalDmgPct = 20 }, Ability = { Radius = 140, Duration = 10, Cooldown = 30 } },
		},
		Challenges = {
			[2] = { Stat = "AnimalsKilled", Target = 20, Text = "Kill 20 animals at night" },
			[3] = { Stat = "AnimalsKilled", Target = 75, Text = "Kill 75 animals at night" },
		},
		PerMatchCap = 15,
	},
	{
		Id = "Climber", Name = "Climber", Price = 200, Order = 5, Glyph = "⤴", Color = { 130, 170, 230 },
		Passive = "+{ClimbPct}% climbing speed",
		Ability = "Scramble: vault over a wall up to {MaxHeight} studs tall in front of you. Cooldown {Cooldown}s.",
		AbilityName = "Scramble",
		Levels = {
			{ Passive = { ClimbPct = 15 }, Ability = { MaxHeight = 11, Cooldown = 45 } },
			{ Passive = { ClimbPct = 25 }, Ability = { MaxHeight = 11, Cooldown = 38 } },
			{ Passive = { ClimbPct = 35 }, Ability = { MaxHeight = 12, Cooldown = 30 } },
		},
		Challenges = {
			[2] = { Stat = "EnemyWallsScaled", Target = 10, Text = "Scramble over 10 different enemy walls" },
			[3] = { Stat = "EnemyWallsScaled", Target = 40, Text = "Scramble over 40 different enemy walls" },
		},
		PerMatchCap = 6,
	},
	{
		Id = "Craftsman", Name = "Craftsman", Price = 125, Order = 2, Glyph = "⚒", Color = { 190, 140, 90 },
		Passive = "+{RepairPct}% repair speed",
		Ability = "Thrifty Repair: your next {FreeSwings} repair swings within 20s cost no resources. Cooldown {Cooldown}s.",
		AbilityName = "Thrifty Repair",
		Levels = {
			{ Passive = { RepairPct = 15 }, Ability = { FreeSwings = 4, Cooldown = 90 } },
			{ Passive = { RepairPct = 25 }, Ability = { FreeSwings = 5, Cooldown = 75 } },
			{ Passive = { RepairPct = 35 }, Ability = { FreeSwings = 6, Cooldown = 60 } },
		},
		Challenges = {
			[2] = { Stat = "HealthRepaired", Target = 3000, Text = "Repair 3,000 structure HP of enemy damage" },
			[3] = { Stat = "HealthRepaired", Target = 12000, Text = "Repair 12,000 structure HP of enemy damage" },
		},
		PerMatchCap = 1500,
	},
	{
		Id = "Sharpshooter", Name = "Sharpshooter", Price = 250, Order = 6, Glyph = "◎", Color = { 230, 90, 110 },
		Passive = "-{SpreadPct}% bow spread, {DrawPct}% faster draw",
		Ability = "Mark: an arrow hit on an enemy reveals them to your team for {Duration}s. Internal cooldown {Cooldown}s.",
		AbilityName = "Mark",
		Levels = {
			{ Passive = { SpreadPct = 15, DrawPct = 5 }, Ability = { Duration = 3, Cooldown = 20 } },
			{ Passive = { SpreadPct = 25, DrawPct = 8 }, Ability = { Duration = 4, Cooldown = 16 } },
			{ Passive = { SpreadPct = 35, DrawPct = 10 }, Ability = { Duration = 5, Cooldown = 12 } },
		},
		Challenges = {
			[2] = { Stat = "LongArrowHits", Target = 25, Text = "Land 25 arrow hits on enemies from 40+ studs" },
			[3] = { Stat = "LongArrowHits", Target = 100, Text = "Land 100 arrow hits on enemies from 40+ studs" },
		},
		PerMatchCap = 20,
	},
}

Powerups.List = list
Powerups.ById = {} :: { [string]: PowerupDef }
for _, p in list do
	Powerups.ById[p.Id] = p
end
table.sort(Powerups.List, function(a, b)
	return a.Order < b.Order
end)

function Powerups.UpgradePrice(id: string, level: number): number
	local def = Powerups.ById[id]
	assert(def, "unknown powerup")
	if level <= 1 then
		return def.Price
	end
	return math.floor(def.Price * Powerups.UpgradePriceMult[level] + 0.5)
end

-- Fills "{Key}" placeholders from a level's values.
function Powerups.Describe(template: string, values: { [string]: number }): string
	return (string.gsub(template, "{(%w+)}", function(key)
		local v = values[key]
		return if v ~= nil then tostring(v) else "?"
	end))
end

return Powerups
