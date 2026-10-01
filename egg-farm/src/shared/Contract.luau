--!strict
-- Action names, which of them a client may send, and result codes with player-facing text.
-- "collect", "deposit" and "catchFox" are physical interactions: the server triggers them itself
-- after checking where the player's character actually is, so they are not client actions.

local Contract = {}

Contract.ClientActions = {
	spawn = true,
	setAutoSpawn = true,
	buyHouse = true,
	upgradeHouse = true,
	buyVehicle = true,
	upgradeVehicle = true,
	hireWorker = true,
	upgradeWorker = true,
	buildSilo = true,
	buyCommon = true,
	buyEpic = true,
	rebirth = true,
	skip = true,
	prestige = true,
	useBoost = true,
	claimQuest = true,
	claimDaily = true,
	claimGift = true,
	claimAllGifts = true,
	redeemCode = true,
	buyGoldItem = true,
	setSetting = true,
	claimOffline = true,
}

Contract.Messages = {
	ok = "Done!",
	invalid = "That request wasn't valid.",
	stale = "That changed a moment ago. Try again.",
	cant_afford = "Not enough money yet!",
	cant_afford_gold = "Not enough Gold Eggs!",
	locked = "Unlocks on a later egg.",
	max_level = "Already at max level!",
	full = "Housing is full! Upgrade your houses.",
	basket_full = "Your basket is full! Deposit at the warehouse.",
	empty = "Nothing to collect yet.",
	nothing_carried = "You aren't carrying any eggs.",
	not_ready = "Not ready yet.",
	already = "Already claimed!",
	slot_taken = "That slot is already in use.",
	slot_locked = "Buy the slot before it first.",
	tutorial = "Finish the tutorial first!",
	code_invalid = "That code doesn't exist.",
	code_used = "You already redeemed that code!",
	code_expired = "That code has expired.",
	code_ok = "Code redeemed!",
	boost_limit = "Too many boosts active at once!",
	no_boost = "You don't have that boost.",
	rate_limited = "Slow down a little!",
	not_configured = "This item isn't for sale yet.",
	no_silos = "Build a silo to earn while you're away.",
	not_requirement = "Your Farm Value isn't high enough yet.",
	skip_too_early = "Reach at least 25% of the Farm Value goal to skip.",
	last_egg = "This is the last egg. Prestige instead!",
	not_last_egg = "Prestige unlocks on the last egg.",
}

Contract.Settings = {
	music = "boolean",
	sfx = "boolean",
	autoSpawn = "boolean",
	effects = "boolean",
	confirmSpend = "boolean",
	flock = { "low", "normal", "high" },
	notation = { "short", "scientific" },
}

-- Tutorial steps (server decides when each is done; see Logic/Tutorial.luau).
Contract.Tutorial = {
	{ key = "spawn", text = "Tap SPAWN to hatch 20 chickens!" },
	{ key = "collect", text = "Walk into the glowing ring at your coop to collect eggs." },
	{ key = "deposit", text = "Carry the eggs to the warehouse ring to deposit them." },
	{ key = "sell", text = "Your vehicle will sell these eggs to give you cash. Watch it go!" },
	{ key = "vehicle", text = "Upgrade your vehicle to sell eggs faster. Open SHIPPING at the dock." },
	{ key = "earn", text = "Keep the eggs flowing until you have $500." },
	{ key = "housing", text = "Increase your housing! Open HOUSING at a coop and upgrade it." },
}

return Contract
