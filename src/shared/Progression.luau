--!strict
-- Account progression rules (pure; tested by tests/Progression.spec.luau).
-- Spec: a long grind that unlocks status/cosmetics, not competitive power.
-- XP / Coin values are the spec's "working targets" and stay tunable here.

local Progression = {}

Progression.XP = {
	SurviveNight = 50,
	Kill = 50,
	Elimination = 100, -- a kill that permanently eliminates (instead of Kill)
	ExtinguishFire = 150,
	WorkbenchV = 200,
	Second = 250,
	Win = 500,
	PoiDiscovered = 15,
	Wildlife = 5,
	Predator = 10,
	Chest = 10,
	RareChest = 25,
}

Progression.Coins = {
	SurviveNight = 10,
	Kill = 15,
	Elimination = 30,
	ExtinguishFire = 40,
	Third = 50,
	Second = 100,
	Win = 250,
}

Progression.MaxLevel = 100
Progression.WinDiamonds = 2 -- spec: EXACTLY 2 per win
Progression.MilestoneDiamonds = 1 -- every 10 levels (Diamonds are earned slowly)
Progression.LevelCoins = 100 -- every 5 levels

-- XP needed to go from `level` to `level + 1`.
function Progression.XPForLevel(level: number): number
	return 150 + 20 * (level - 1)
end

-- Total XP needed to reach `level` from level 1.
function Progression.TotalForLevel(level: number): number
	local n = level - 1
	return 150 * n + 20 * n * (n - 1) / 2
end

-- Level for a total XP amount (1..MaxLevel) and progress into the next level.
function Progression.LevelFromXP(xp: number): (number, number, number)
	local level = 1
	while level < Progression.MaxLevel and xp >= Progression.TotalForLevel(level + 1) do
		level += 1
	end
	if level >= Progression.MaxLevel then
		return level, 0, 0
	end
	local into = xp - Progression.TotalForLevel(level)
	return level, into, Progression.XPForLevel(level)
end

export type LevelReward = { Level: number, Coins: number, Diamonds: number }

-- Rewards for crossing from level `from` to `to` (exclusive of `from`).
function Progression.LevelRewards(from: number, to: number): { LevelReward }
	local out = {}
	for l = from + 1, to do
		local r = { Level = l, Coins = if l % 5 == 0 then Progression.LevelCoins else 0, Diamonds = if l % 10 == 0 then Progression.MilestoneDiamonds else 0 }
		if r.Coins > 0 or r.Diamonds > 0 then
			table.insert(out, r)
		end
	end
	return out
end

-- Placement rewards: returns xp, coins, diamonds.
function Progression.Placement(place: number): (number, number, number)
	if place == 1 then
		return Progression.XP.Win, Progression.Coins.Win, Progression.WinDiamonds
	elseif place == 2 then
		return Progression.XP.Second, Progression.Coins.Second, 0
	elseif place == 3 then
		return 0, Progression.Coins.Third, 0
	end
	return 0, 0, 0
end

-- Daily login bonus: 50 on day one, +20 per consecutive day, capped at 150.
function Progression.DailyCoins(streak: number): number
	return math.min(150, 50 + math.max(0, streak - 1) * 20)
end

-- Weekly bonus: needs WeeklyMatches matches this week; 300 + 75 per win, capped at 750.
Progression.WeeklyMatches = 3
function Progression.WeeklyCoins(wins: number): number
	return math.min(750, 300 + 75 * math.max(0, wins))
end

function Progression.DayNumber(t: number): number
	return math.floor(t / 86400)
end

function Progression.WeekNumber(t: number): number
	-- weeks start on Monday (1970-01-01 was a Thursday)
	return math.floor((t / 86400 + 3) / 7)
end

return Progression
