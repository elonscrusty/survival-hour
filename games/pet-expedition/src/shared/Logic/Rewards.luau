--!strict
-- Daily streak, playtime gifts, daily quests and Index (collection) rewards.
-- Days are UTC day numbers: floor(os.time() / 86400).

local Config = require("../Config")
local Pets = require("../Pets")
local Areas = require("../Areas")
local Economy = require("./Economy")
local Rng = require("./Rng")
local Schema = require("./Schema")

type Profile = Schema.Profile
type Quest = Schema.Quest
type Reward = Schema.Reward

local Rewards = {}

local SECONDS_PER_DAY = 86400

function Rewards.DayNumber(now: number): number
	return math.floor(now / SECONDS_PER_DAY)
end

-- Grants a Config.RewardSpec. Returns what was actually given.
function Rewards.Apply(p: Profile, spec: Config.RewardSpec, now: number): Reward
	local out: Reward = {}
	if spec.Coins then
		out.Coins = Economy.AddCoins(p, spec.Coins, false)
	end
	if spec.Gems then
		out.Gems = Economy.AddGems(p, spec.Gems)
	end
	if spec.Boost and Config.Boosts[spec.Boost] then
		Economy.ApplyBoost(p, spec.Boost, now)
		out.Boost = spec.Boost
	end
	if spec.Equip and spec.Equip > 0 then
		p.ExtraEquip += math.floor(spec.Equip)
		out.Equip = math.floor(spec.Equip)
	end
	if spec.Storage and spec.Storage > 0 then
		p.ExtraStorage += math.floor(spec.Storage)
		out.Storage = math.floor(spec.Storage)
	end
	return out
end

-- Daily ----------------------------------------------------------------------

-- The streak the player currently has (0 once a day was missed).
function Rewards.EffectiveStreak(p: Profile, day: number): number
	if p.Daily.LastDay >= day - 1 then
		return p.Daily.Streak
	end
	return 0
end

function Rewards.DailyStatus(p: Profile, day: number): { Streak: number, LastDay: number, CanClaim: boolean }
	return {
		Streak = Rewards.EffectiveStreak(p, day),
		LastDay = p.Daily.LastDay,
		CanClaim = p.Daily.LastDay < day,
	}
end

-- Reward for a streak day (1-based, loops after the last entry).
function Rewards.DailySpec(streakDay: number): Config.RewardSpec
	local n = #Config.DailyRewards
	return Config.DailyRewards[((math.max(1, streakDay) - 1) % n) + 1]
end

function Rewards.ClaimDaily(p: Profile, now: number): (Reward?, number?, string?)
	local day = Rewards.DayNumber(now)
	if p.Daily.LastDay >= day then
		return nil, nil, "Come back tomorrow"
	end
	local streak = if p.Daily.LastDay == day - 1 then p.Daily.Streak + 1 else 1
	p.Daily.Streak = math.min(streak, 1e6)
	p.Daily.LastDay = day
	return Rewards.Apply(p, Rewards.DailySpec(streak), now), streak, nil
end

-- Playtime gifts (once per UTC day, minutes played today) ------------------------

-- Starts a fresh playtime day when the day changed. Returns true if reset.
function Rewards.EnsurePlaytimeDay(p: Profile, now: number): boolean
	local day = Rewards.DayNumber(now)
	if p.Playtime.Day == day then
		return false
	end
	p.Playtime = { Day = day, Minutes = 0, Claimed = {} }
	return true
end

-- Adds online time (seconds) to today's minutes. Time is credited to the day
-- it is added on (a session over midnight starts the new day from zero).
function Rewards.AddPlaytime(p: Profile, seconds: number, now: number)
	Rewards.EnsurePlaytimeDay(p, now)
	if not Schema.IsFinite(seconds) or seconds <= 0 then
		return
	end
	-- One call can't add more than an hour (guards against clock jumps).
	p.Playtime.Minutes = math.min(24 * 60, p.Playtime.Minutes + math.min(seconds, 3600) / 60)
end

function Rewards.PlaytimeMinutes(p: Profile, now: number): number
	if p.Playtime.Day ~= Rewards.DayNumber(now) then
		return 0
	end
	return p.Playtime.Minutes
end

function Rewards.ClaimPlaytime(p: Profile, index: number, now: number): (Reward?, string?)
	if not Schema.IsInt(index, 1, #Config.PlaytimeGifts) then
		return nil, "Unknown gift"
	end
	Rewards.EnsurePlaytimeDay(p, now)
	local key = tostring(index)
	if p.Playtime.Claimed[key] then
		return nil, "Already claimed today"
	end
	local gift = Config.PlaytimeGifts[index]
	if p.Playtime.Minutes < (gift.Minutes or 0) then
		return nil, "Not ready yet"
	end
	p.Playtime.Claimed[key] = true
	return Rewards.Apply(p, gift, now), nil
end

-- Quests -----------------------------------------------------------------------

-- The same quests for everyone on a day. Coins goals are multiplied by
-- `coinMult` (the CoinMult of the player's highest opened island), so they
-- stay meaningful as the player progresses.
function Rewards.GenerateQuests(day: number, coinMult: number?): { Quest }
	local scale = if coinMult and Schema.IsFinite(coinMult) and coinMult > 0 then coinMult else 1
	local rng = Rng.New(Rng.Hash("quests", day))
	local pool = {}
	for i = 1, #Config.QuestPool do
		table.insert(pool, i)
	end
	-- Fisher-Yates shuffle.
	for i = #pool, 2, -1 do
		local j = rng:Int(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local out: { Quest } = {}
	for i = 1, math.min(Config.QuestsPerDay, #pool) do
		local def = Config.QuestPool[pool[i]]
		local tier = rng:Int(1, #def.Goals)
		local goal = def.Goals[tier]
		if def.Kind == "Coins" then
			goal = math.floor(goal * scale)
		end
		table.insert(out, {
			Kind = def.Kind,
			Goal = goal,
			Progress = 0,
			Gems = def.Gems[tier],
			Claimed = false,
		})
	end
	return out
end

-- CoinMult of the player's highest opened island (scales Coins quests).
function Rewards.QuestCoinMult(p: Profile): number
	local best = Areas.ById[Schema.StartArea]
	for _, a in Areas.List do
		if p.Areas[a.Id] then
			best = a
		end
	end
	return if best then best.CoinMult else 1
end

-- Today's quests for this player (fresh ones if the stored day is old).
function Rewards.QuestsFor(p: Profile, day: number): { Quest }
	if p.Quests.Day == day and #p.Quests.List > 0 then
		return p.Quests.List
	end
	return Rewards.GenerateQuests(day, Rewards.QuestCoinMult(p))
end

-- Replaces yesterday's quests. Goals are fixed when generated. Returns true
-- if they changed.
function Rewards.EnsureQuests(p: Profile, day: number): boolean
	if p.Quests.Day == day and #p.Quests.List > 0 then
		return false
	end
	p.Quests = { Day = day, List = Rewards.GenerateQuests(day, Rewards.QuestCoinMult(p)) }
	return true
end

-- Adds progress to every unclaimed quest of a kind. Returns true if changed.
function Rewards.AddQuestProgress(p: Profile, kind: string, amount: number, now: number): boolean
	if not Schema.IsFinite(amount) or amount <= 0 then
		return false
	end
	Rewards.EnsureQuests(p, Rewards.DayNumber(now))
	local changed = false
	for _, q in p.Quests.List do
		if q.Kind == kind and not q.Claimed and q.Progress < q.Goal then
			q.Progress = math.min(q.Goal, q.Progress + amount)
			changed = true
		end
	end
	return changed
end

function Rewards.ClaimQuest(p: Profile, index: number, now: number): (Reward?, string?)
	Rewards.EnsureQuests(p, Rewards.DayNumber(now))
	if not Schema.IsInt(index, 1, #p.Quests.List) then
		return nil, "Unknown quest"
	end
	local q = p.Quests.List[index]
	if q.Claimed then
		return nil, "Already claimed"
	end
	if q.Progress < q.Goal then
		return nil, "Quest not finished"
	end
	q.Claimed = true
	return Rewards.Apply(p, { Gems = q.Gems }, now), nil
end

-- Index ------------------------------------------------------------------------

function Rewards.IndexCount(p: Profile): number
	local n = 0
	for _, def in Pets.List do
		if p.Index[def.Id] then
			n += 1
		end
	end
	return n
end

function Rewards.IndexFraction(p: Profile): number
	return Rewards.IndexCount(p) / math.max(1, #Pets.List)
end

function Rewards.ClaimIndex(p: Profile, tier: number, now: number): (Reward?, string?)
	if not Schema.IsInt(tier, 1, #Config.IndexRewards) then
		return nil, "Unknown reward"
	end
	local key = tostring(tier)
	if p.IndexClaimed[key] then
		return nil, "Already claimed"
	end
	local spec = Config.IndexRewards[tier]
	-- Compare counts, not fractions, so 100% isn't lost to rounding.
	local needed = math.ceil((spec.Fraction or 1) * #Pets.List - 1e-9)
	if Rewards.IndexCount(p) < needed then
		return nil, "Discover more pets first"
	end
	p.IndexClaimed[key] = true
	return Rewards.Apply(p, spec, now), nil
end

return Rewards
