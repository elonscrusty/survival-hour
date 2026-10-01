--!strict
-- Quests, daily rewards and playtime gifts. The reference REPORTS quests with Gold Egg rewards,
-- daily/playtime "gift ready" rewards with Claim All. Lists, targets and rewards here are
-- DESIGN VALUES. All timing uses the server clock (UTC day = floor(serverTime / 86400)).
--
-- A Reward is { gold = n?, cashMinutes = n?, boosts = { [boostId] = count }? }.
-- cashMinutes pays that many minutes of the farm's steady cash rate (at least $100 x egg value),
-- so a reward stays useful on every farm.

export type Reward = { gold: number?, cashMinutes: number?, boosts: { [string]: number }? }
export type Quest = { id: string, text: string, stat: string, target: number, reward: Reward }

local questPool: { Quest } = {
	{ id = "spawn_200", text = "Spawn 200 chickens", stat = "spawned", target = 200, reward = { gold = 5 } },
	{ id = "spawn_1000", text = "Spawn 1,000 chickens", stat = "spawned", target = 1000, reward = { gold = 10 } },
	{ id = "collect_500", text = "Collect 500 eggs from houses", stat = "collected", target = 500, reward = { gold = 5 } },
	{ id = "collect_5000", text = "Collect 5,000 eggs from houses", stat = "collected", target = 5000, reward = { gold = 10, boosts = { lay2 = 1 } } },
	{ id = "deposit_1000", text = "Deposit 1,000 eggs at the warehouse", stat = "deposited", target = 1000, reward = { gold = 8 } },
	{ id = "sell_2000", text = "Sell 2,000 eggs", stat = "sold", target = 2000, reward = { cashMinutes = 5 } },
	{ id = "sell_20000", text = "Sell 20,000 eggs", stat = "sold", target = 20000, reward = { gold = 15 } },
	{ id = "upgrade_5", text = "Buy 5 upgrades", stat = "upgrades", target = 5, reward = { gold = 8 } },
	{ id = "upgrade_15", text = "Buy 15 upgrades", stat = "upgrades", target = 15, reward = { boosts = { earn3 = 1 } } },
	{ id = "play_15", text = "Play for 15 minutes", stat = "playtime", target = 15 * 60, reward = { gold = 10 } },
	{ id = "boost_1", text = "Use a boost", stat = "boostsUsed", target = 1, reward = { gold = 5 } },
	{ id = "fox_1", text = "Catch the Lucky Fox", stat = "foxes", target = 1, reward = { gold = 6 } },
}

-- Each UTC day shows QuestsPerDay quests, picked by rotating through the pool.
local QuestsPerDay = 5

local daily: { Reward } = { -- day 1..7 of a streak; day 7 repeats after that
	{ gold = 5 },
	{ cashMinutes = 10 },
	{ gold = 10 },
	{ boosts = { earn3 = 1 } },
	{ gold = 15 },
	{ boosts = { lay2 = 1, hatch10 = 1 } },
	{ gold = 30, boosts = { earn10 = 1 } },
}

local gifts: { { minutes: number, reward: Reward } } = { -- playtime today
	{ minutes = 3, reward = { gold = 2 } },
	{ minutes = 8, reward = { cashMinutes = 3 } },
	{ minutes = 15, reward = { gold = 4 } },
	{ minutes = 25, reward = { boosts = { lay2 = 1 } } },
	{ minutes = 40, reward = { gold = 8 } },
	{ minutes = 60, reward = { boosts = { earn3 = 1 } } },
}

return {
	QuestPool = questPool,
	QuestsPerDay = QuestsPerDay,
	Daily = daily,
	Gifts = gifts,
	MinCashReward = 100, -- x egg value
}
