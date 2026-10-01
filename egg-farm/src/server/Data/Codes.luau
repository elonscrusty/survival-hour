--!strict
-- Redeem codes. SERVER ONLY (lives in ServerScriptService, never replicated), so codes can't be
-- read by exploiters before you announce them. Keys must be UPPERCASE; players can type any case.
-- reward uses the Reward shape from Data/Rewards: { gold?, cashMinutes?, boosts? }.
-- expires = optional unix time (server clock) after which the code says "expired".
-- These are this game's own launch codes (DESIGN); the reference's codes are not reused.

return {
	EGGFARM = { reward = { gold = 25 } },
	WELCOME = { reward = { boosts = { earn3 = 1 } } },
	HATCHED = { reward = { boosts = { lay2 = 1 }, gold = 10 } },
}
