--!strict
-- Granting rewards, and the daily/quest/gift bookkeeping. All "day" values are UTC day numbers
-- computed from the SERVER clock that the caller passes in.

local Data = require("../Data/Rewards")
local Boosts = require("../Data/Boosts")
local Eggs = require("../Data/Eggs")
local Modifiers = require("./Modifiers")

local Rewards = {}

function Rewards.Day(now: number): number
	return math.floor(now / 86400)
end

local function clampAdd(a: number, b: number): number
	return math.min(Modifiers.CAP, a + b)
end

-- Cash value of `minutes` of steady earnings (never less than the floor for the current egg).
function Rewards.CashFor(state: any, minutes: number, now: number, ctx: any?): number
	local egg = Eggs.List[state.egg] or Eggs.List[1]
	local rate = Modifiers.SteadyCashRate(state, now, ctx)
	return math.floor(math.max(rate * 60 * minutes, Data.MinCashReward * egg.value))
end

-- Adds a reward to the state. `goldBonus` = true applies the x2 Gold Eggs pass (earned gold only;
-- purchased and code gold are exact). Returns what was actually granted, for the UI.
function Rewards.Grant(state: any, reward: any, now: number, ctx: any?, goldBonus: boolean?): { [string]: any }
	local granted: { [string]: any } = {}
	if reward.gold and reward.gold > 0 then
		local g = reward.gold * (if goldBonus and state.passes.x2gold then 2 else 1)
		state.gold = clampAdd(state.gold, g)
		granted.gold = g
	end
	if reward.cashMinutes and reward.cashMinutes > 0 then
		local c = Rewards.CashFor(state, reward.cashMinutes, now, ctx)
		state.cash = clampAdd(state.cash, c)
		granted.cash = c
	end
	if reward.boosts then
		granted.boosts = {}
		for id, n in reward.boosts do
			if Boosts.ById[id] then
				local have = state.boosts.inventory[id] or 0
				local add = math.min(n, Boosts.MaxInventory - have)
				if add > 0 then
					state.boosts.inventory[id] = have + add
					granted.boosts[id] = add
				end
			end
		end
	end
	return granted
end

-- Resets per-day quest progress and gift playtime when the UTC day changes.
function Rewards.RollDay(state: any, now: number)
	local day = Rewards.Day(now)
	if state.quests.day ~= day then
		state.quests.day = day
		state.quests.progress = {}
		state.quests.claimed = {}
	end
	if state.gifts.day ~= day then
		state.gifts.day = day
		state.gifts.playtime = 0
		state.gifts.claimed = {}
	end
end

-- The quests shown on `day` (rotates through the pool; same list for everyone that day).
function Rewards.QuestsForDay(day: number): { Data.Quest }
	local pool = Data.QuestPool
	local out = {}
	local start = (day * Data.QuestsPerDay) % #pool
	for i = 0, Data.QuestsPerDay - 1 do
		table.insert(out, pool[(start + i) % #pool + 1])
	end
	return out
end

function Rewards.FindQuest(day: number, id: string): Data.Quest?
	for _, q in Rewards.QuestsForDay(day) do
		if q.id == id then
			return q
		end
	end
	return nil
end

function Rewards.Track(state: any, statName: string, amount: number)
	if amount <= 0 then
		return
	end
	state.stats[statName] = math.min(Modifiers.CAP, (state.stats[statName] or 0) + amount)
	local p = state.quests.progress
	p[statName] = math.min(Modifiers.CAP, (p[statName] or 0) + amount)
end

function Rewards.DailyCanClaim(state: any, now: number): boolean
	return state.daily.lastDay < Rewards.Day(now)
end

-- The streak day the NEXT claim would pay (1..7).
function Rewards.DailyNextDay(state: any, now: number): number
	local today = Rewards.Day(now)
	local streak = if state.daily.lastDay == today - 1 or state.daily.lastDay == today then state.daily.streak else 0
	return math.min(streak + 1, #Data.Daily) -- if already claimed today, this is tomorrow's reward
end

return Rewards
