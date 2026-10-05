-- Daily login streak and daily quests (tested by tests/Daily.spec.luau).
-- Quest progress needs no per-event tracking: when a day starts the profile snapshots
-- the lifetime Stats, and progress is "stat now - stat then". Everyone gets the same
-- three quests each day (picked from the day number), so they can't be rerolled.
-- Rewards are Coins only.
local Daily = {}

export type QuestDef = { Id: string, Stat: string, Need: number, Coins: number, Text: string }
export type State = {
	Day: number,
	Streak: number,
	LoginClaimed: boolean,
	Quests: { string }, -- quest ids for today
	Base: { [string]: number }, -- Stats snapshot at the start of the day
	Claimed: { [string]: boolean },
}

-- Login rewards for streak days 1..7; after day 7 it stays at the last value.
Daily.LoginCoins = { 50, 75, 100, 150, 200, 250, 400 }

Daily.Quests = {
	{ Id = "Race3", Stat = "Races", Need = 3, Coins = 150, Text = "Finish 3 races" },
	{ Id = "Race5", Stat = "Races", Need = 5, Coins = 250, Text = "Finish 5 races" },
	{ Id = "Medal2", Stat = "Medals", Need = 2, Coins = 200, Text = "Win 2 medals" },
	{ Id = "Gold1", Stat = "Golds", Need = 1, Coins = 250, Text = "Win a Gold medal" },
	{ Id = "Hatch2", Stat = "Hatches", Need = 2, Coins = 120, Text = "Hatch 2 eggs" },
	{ Id = "Gates20", Stat = "Gates", Need = 20, Coins = 120, Text = "Ride through 20 speed gates" },
	{ Id = "Hurdles12", Stat = "Hurdles", Need = 12, Coins = 120, Text = "Jump 12 training hurdles" },
	{ Id = "Train150", Stat = "TrainXp", Need = 150, Coins = 150, Text = "Earn 150 training XP" },
} :: { QuestDef }

Daily.ById = {} :: { [string]: QuestDef }
for _, q in Daily.Quests do
	Daily.ById[q.Id] = q
end

Daily.PerDay = 3

function Daily.Today(now: number): number
	return math.floor(now / 86400)
end

-- Today's quest ids: PerDay different quests, chosen from the day number.
function Daily.Pick(day: number): { string }
	local n = #Daily.Quests
	local out = {}
	local i = (day * 7) % n
	local step = 3 -- co-prime with 8, so it walks all quests without repeating
	while #out < Daily.PerDay do
		local id = Daily.Quests[i + 1].Id
		if not table.find(out, id) then
			table.insert(out, id)
		end
		i = (i + step) % n
	end
	return out
end

function Daily.New(): State
	return { Day = -1, Streak = 0, LoginClaimed = false, Quests = {}, Base = {}, Claimed = {} }
end

-- Starts a new day if needed. Returns true if the day changed.
function Daily.Rollover(s: State, today: number, stats: { [string]: number }): boolean
	if s.Day == today then
		return false
	end
	s.Streak = if s.Day == today - 1 then s.Streak + 1 else 1
	s.Day = today
	s.LoginClaimed = false
	s.Quests = Daily.Pick(today)
	s.Base = table.clone(stats)
	s.Claimed = {}
	return true
end

function Daily.LoginReward(streak: number): number
	return Daily.LoginCoins[math.clamp(streak, 1, #Daily.LoginCoins)]
end

function Daily.Progress(s: State, stats: { [string]: number }, id: string): number
	local q = Daily.ById[id]
	if not q then
		return 0
	end
	return math.clamp((stats[q.Stat] or 0) - (s.Base[q.Stat] or 0), 0, q.Need)
end

-- Claims a reward. what = "Login" or a quest id. Returns coins (0 if not claimable).
function Daily.Claim(s: State, stats: { [string]: number }, what: string): number
	if what == "Login" then
		if s.LoginClaimed or s.Day < 0 then
			return 0
		end
		s.LoginClaimed = true
		return Daily.LoginReward(s.Streak)
	end
	local q = Daily.ById[what]
	if not q or not table.find(s.Quests, what) or s.Claimed[what] then
		return 0
	end
	if Daily.Progress(s, stats, what) < q.Need then
		return 0
	end
	s.Claimed[what] = true
	return q.Coins
end

-- Anything waiting to be claimed? (for the red dot on the DAILY button)
function Daily.HasClaimable(s: State, stats: { [string]: number }): boolean
	if s.Day >= 0 and not s.LoginClaimed then
		return true
	end
	for _, id in s.Quests do
		local q = Daily.ById[id]
		if q and not s.Claimed[id] and Daily.Progress(s, stats, id) >= q.Need then
			return true
		end
	end
	return false
end

return Daily
