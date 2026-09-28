--!strict
-- Daily and weekly gameplay challenges (tested by tests/Challenges.spec.luau).
--
-- Progress needs no per-event tracking: when a day (or week) starts, the profile snapshots
-- the lifetime stats the challenges read, and progress is simply "stat now - stat then".
-- Three dailies and two weeklies are picked deterministically from the day/week number, so
-- every player gets the same set and it can't be rerolled. Rewards are Coins only.

local Challenges = {}

export type Def = { Id: string, Stat: string, Need: number, Coins: number, Text: string }
export type State = {
	Day: number,
	DayBase: { [string]: number },
	DayClaimed: { [string]: boolean },
	Week: number,
	WeekBase: { [string]: number },
	WeekClaimed: { [string]: boolean },
}

-- Stats are lifetime totals kept in Profile.Stats (plus Wins/Matches/Kills/Eliminations).
local DAILY: { Def } = {
	{ Id = "D_Gather", Stat = "Resources", Need = 250, Coins = 60, Text = "Gather 250 resources" },
	{ Id = "D_Hunt", Stat = "Animals", Need = 3, Coins = 60, Text = "Hunt 3 animals" },
	{ Id = "D_Explore", Stat = "Pois", Need = 3, Coins = 60, Text = "Discover 3 places" },
	{ Id = "D_Nights", Stat = "Nights", Need = 2, Coins = 60, Text = "Survive 2 nights" },
	{ Id = "D_Craft", Stat = "Crafts", Need = 5, Coins = 60, Text = "Craft 5 items" },
	{ Id = "D_Loot", Stat = "Chests", Need = 4, Coins = 60, Text = "Search 4 chests" },
	{ Id = "D_Fight", Stat = "DamageDealt", Need = 200, Coins = 60, Text = "Deal 200 damage to survivors" },
	{ Id = "D_Play", Stat = "Matches", Need = 2, Coins = 60, Text = "Play 2 matches" },
}
local WEEKLY: { Def } = {
	{ Id = "W_Win", Stat = "Wins", Need = 2, Coins = 300, Text = "Win 2 matches" },
	{ Id = "W_Nights", Stat = "Nights", Need = 12, Coins = 250, Text = "Survive 12 nights" },
	{ Id = "W_Elim", Stat = "Eliminations", Need = 3, Coins = 250, Text = "Knock out 3 survivors for good" },
	{ Id = "W_Predators", Stat = "Predators", Need = 6, Coins = 250, Text = "Hunt 6 wolves, boars or bears" },
	{ Id = "W_Bench", Stat = "BenchUpgrades", Need = 8, Coins = 250, Text = "Upgrade a Workbench 8 times" },
	{ Id = "W_Raid", Stat = "Breaches", Need = 3, Coins = 250, Text = "Breach 3 enemy storages" },
	{ Id = "W_Explore", Stat = "Pois", Need = 15, Coins = 250, Text = "Discover 15 places" },
}
Challenges.Daily = DAILY
Challenges.Weekly = WEEKLY
Challenges.DailyCount = 3
Challenges.WeeklyCount = 2

Challenges.ById = {} :: { [string]: Def }
for _, d in DAILY do
	Challenges.ById[d.Id] = d
end
for _, d in WEEKLY do
	Challenges.ById[d.Id] = d
end

-- Deterministic pick of `n` distinct entries from `pool` for period number `k`.
local function pick(pool: { Def }, n: number, k: number): { Def }
	local idx = {}
	for i = 1, #pool do
		idx[i] = i
	end
	-- Park-Miller shuffle seeded by the period number (products stay far below 2^53, so the
	-- arithmetic is exact in doubles and every entry can be picked)
	local seed = k % 2147483646 + 1
	for _ = 1, 3 do
		seed = (seed * 16807) % 2147483647
	end
	for i = #idx, 2, -1 do
		seed = (seed * 16807) % 2147483647
		local j = seed % i + 1
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(n, #idx) do
		table.insert(out, pool[idx[i]])
	end
	return out
end

function Challenges.ForDay(day: number): { Def }
	return pick(DAILY, Challenges.DailyCount, day)
end

function Challenges.ForWeek(week: number): { Def }
	return pick(WEEKLY, Challenges.WeeklyCount, week + 7919)
end

function Challenges.New(): State
	return { Day = -1, DayBase = {}, DayClaimed = {}, Week = -1, WeekBase = {}, WeekClaimed = {} }
end

-- Reads a lifetime stat off a profile-like table.
function Challenges.Stat(profile: any, stat: string): number
	local top = profile[stat]
	if stat == "Wins" or stat == "Matches" or stat == "Kills" or stat == "Eliminations" then
		return if type(top) == "number" then top else 0
	end
	local v = profile.Stats and profile.Stats[stat]
	return if type(v) == "number" then v else 0
end

local function snapshot(profile: any, defs: { Def }): { [string]: number }
	local base = {}
	for _, d in defs do
		base[d.Stat] = Challenges.Stat(profile, d.Stat)
	end
	return base
end

-- Starts a new day/week set when the period changes. Returns true if anything reset.
function Challenges.Refresh(state: State, profile: any, day: number, week: number): boolean
	local changed = false
	if state.Day ~= day then
		state.Day = day
		state.DayBase = snapshot(profile, Challenges.ForDay(day))
		state.DayClaimed = {}
		changed = true
	end
	if state.Week ~= week then
		state.Week = week
		state.WeekBase = snapshot(profile, Challenges.ForWeek(week))
		state.WeekClaimed = {}
		changed = true
	end
	return changed
end

export type View = { Id: string, Text: string, Progress: number, Need: number, Coins: number, Claimed: boolean, Weekly: boolean }

function Challenges.View(state: State, profile: any): { View }
	local out: { View } = {}
	local function add(defs: { Def }, base: { [string]: number }, claimed: { [string]: boolean }, weekly: boolean)
		for _, d in defs do
			local p = math.max(0, Challenges.Stat(profile, d.Stat) - (base[d.Stat] or 0))
			table.insert(out, { Id = d.Id, Text = d.Text, Progress = math.min(p, d.Need), Need = d.Need, Coins = d.Coins, Claimed = claimed[d.Id] == true, Weekly = weekly })
		end
	end
	add(Challenges.ForDay(state.Day), state.DayBase, state.DayClaimed, false)
	add(Challenges.ForWeek(state.Week), state.WeekBase, state.WeekClaimed, true)
	return out
end

-- Claims a finished challenge from the current set. Returns the Coins to grant (0 = refused).
function Challenges.Claim(state: State, profile: any, id: string): number
	for _, v in Challenges.View(state, profile) do
		if v.Id == id and not v.Claimed and v.Progress >= v.Need then
			if v.Weekly then
				state.WeekClaimed[id] = true
			else
				state.DayClaimed[id] = true
			end
			return v.Coins
		end
	end
	return 0
end

-- Sanitises a stored state (older saves have none).
function Challenges.Reconcile(data: any): State
	local s = Challenges.New()
	if type(data) ~= "table" then
		return s
	end
	local function nums(t: any): { [string]: number }
		local o = {}
		if type(t) == "table" then
			for k, v in t do
				if type(k) == "string" and type(v) == "number" and v == v then
					o[k] = v
				end
			end
		end
		return o
	end
	local function flags(t: any): { [string]: boolean }
		local o = {}
		if type(t) == "table" then
			for k, v in t do
				if type(k) == "string" and v == true then
					o[k] = true
				end
			end
		end
		return o
	end
	s.Day = if type(data.Day) == "number" then data.Day else -1
	s.Week = if type(data.Week) == "number" then data.Week else -1
	s.DayBase, s.WeekBase = nums(data.DayBase), nums(data.WeekBase)
	s.DayClaimed, s.WeekClaimed = flags(data.DayClaimed), flags(data.WeekClaimed)
	return s
end

return Challenges
