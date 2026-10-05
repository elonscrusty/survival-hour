--!strict
-- The saved profile shape and a few hard limits shared by every Logic module.
-- The client never sees this table directly: Logic/Profile.BuildState turns it
-- into a Types.PlayerState.

local Types = require("../Types")

export type PetInstance = Types.PetInstance
export type Expedition = Types.Expedition
export type Quest = Types.Quest
export type Reward = Types.Reward

export type Stats = { Hatched: number, Broken: number, Expeditions: number, CoinsEarned: number, Crafted: number }

export type Profile = {
	Version: number,
	Coins: number,
	Gems: number,
	Rebirths: number,
	Areas: { [string]: boolean },
	Pets: { PetInstance },
	NextUid: number,
	Equipped: { string },
	Expeditions: { [string]: Expedition },
	Passes: { [string]: boolean },
	Boosts: { [string]: number },
	Index: { [string]: boolean },
	IndexClaimed: { [string]: boolean },
	Daily: { Streak: number, LastDay: number },
	Quests: { Day: number, List: { Quest } },
	Stats: Stats,
	Settings: { [string]: any },
	ExtraEquip: number, -- from Index rewards
	ExtraStorage: number, -- from Index rewards
	Receipts: { [string]: number }, -- PurchaseId -> os.time granted
	ExpeditionMult: { [string]: number }, -- slot -> coin multiplier snapshotted at start
	PendingTrade: string?, -- trade id whose journal may still need applying (see Logic/Trade)
	AppliedTrades: { string }, -- newest trade ids already applied (journal replay guard)
}

local Schema = {}

Schema.StartCoins = 150 -- enough for the first Meadow Egg
Schema.StartArea = "Meadow"
Schema.MaxCoins = 1e15
Schema.MaxGems = 1e12
Schema.MaxStat = 1e15
Schema.MaxReceipts = 100 -- newest purchase ids kept for dedupe
Schema.MaxUidLength = 24
Schema.MaxAppliedTrades = 30
Schema.MaxCoinMult = 1e6 -- sanity cap for snapshotted multipliers

-- Settings the client may change (SetSetting) and their defaults. All booleans.
Schema.SettingDefaults = {
	Music = true,
	Sfx = true,
	HideOthersPets = false,
	AutoFarm = false,
} :: { [string]: boolean }

-- True for a finite number (not NaN, not +-inf).
function Schema.IsFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- True for a finite whole number inside [lo, hi].
function Schema.IsInt(n: any, lo: number?, hi: number?): boolean
	if not Schema.IsFinite(n) or n ~= math.floor(n) then
		return false
	end
	if lo and n < lo then
		return false
	end
	if hi and n > hi then
		return false
	end
	return true
end

-- Clamps any value into a finite whole number inside [lo, hi] (bad input -> lo).
function Schema.ClampInt(n: any, lo: number, hi: number): number
	if not Schema.IsFinite(n) then
		return lo
	end
	return math.clamp(math.floor(n), lo, hi)
end

-- Validates a client-sent list of uids: an array of 1..maxCount distinct,
-- short strings. Returns the list (copied) or nil and a reason.
function Schema.UidList(v: any, maxCount: number): ({ string }?, string?)
	if type(v) ~= "table" then
		return nil, "Bad pet list"
	end
	local n = #v
	if n < 1 then
		return nil, "No pets chosen"
	end
	if n > maxCount then
		return nil, "Too many pets"
	end
	local count = 0
	for _ in v do
		count += 1
	end
	if count ~= n then
		return nil, "Bad pet list"
	end
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for i = 1, n do
		local u = v[i]
		if type(u) ~= "string" or #u == 0 or #u > Schema.MaxUidLength then
			return nil, "Bad pet id"
		end
		if seen[u] then
			return nil, "Same pet chosen twice"
		end
		seen[u] = true
		table.insert(out, u)
	end
	return out, nil
end

return Schema
