--!strict
-- Anti-farming rules for powerup challenge progress. One tracker exists per
-- player per match; the server feeds it events and adds only the accepted
-- amount to the persistent profile stat.
--
--   * per-match cap per stat (from Powerups.PerMatchCap)
--   * per-target caps: the same wall, crate or animal counts once; the same
--     arrow victim counts at most 5 times per match
--   * DistanceTravelled only accepts plausible per-second movement

local Powerups = require("../Powerups")

export type Tracker = {
	Counted: { [string]: number }, -- stat -> counted this match
	Targets: { [string]: number }, -- stat..target -> count
}

local ChallengeRules = {}

ChallengeRules.PerTargetLimit = {
	EnemyWallsScaled = 1,
	CratesOpened = 1,
	AnimalsKilled = 1,
	LongArrowHits = 5,
}

ChallengeRules.MaxDistancePerSecond = 40 -- faster than any legit movement incl. bursts

-- stat -> per-match cap (first powerup that uses the stat defines it)
local CAPS: { [string]: number } = {}
for _, def in Powerups.List do
	for _, ch in def.Challenges do
		CAPS[ch.Stat] = def.PerMatchCap
	end
end
ChallengeRules.Caps = CAPS

function ChallengeRules.NewTracker(): Tracker
	return { Counted = {}, Targets = {} }
end

-- Returns the amount that may be added to the persistent stat.
function ChallengeRules.Accept(tr: Tracker, stat: string, amount: number, targetKey: string?, dt: number?): number
	if amount <= 0 or amount ~= amount then
		return 0
	end
	local cap = CAPS[stat]
	if cap == nil then
		return 0
	end
	if stat == "DistanceTravelled" then
		local maxAmt = ChallengeRules.MaxDistancePerSecond * math.max(dt or 1, 0)
		if amount > maxAmt then
			return 0 -- teleports / respawns are not travel
		end
	end
	local limit = ChallengeRules.PerTargetLimit[stat]
	if limit then
		if targetKey == nil then
			return 0
		end
		local key = stat .. "|" .. targetKey
		local n = tr.Targets[key] or 0
		if n >= limit then
			return 0
		end
		tr.Targets[key] = n + 1
	end
	local counted = tr.Counted[stat] or 0
	local accept = math.min(amount, cap - counted)
	if accept <= 0 then
		return 0
	end
	tr.Counted[stat] = counted + accept
	return accept
end

-- Which owned powerups track this stat (progress counts for every owned powerup).
function ChallengeRules.StatRelevant(owned: { [string]: number }, stat: string): boolean
	for id, level in owned do
		local def = Powerups.ById[id]
		if def and level < Powerups.MaxLevel then
			for _, ch in def.Challenges do
				if ch.Stat == stat then
					return true
				end
			end
		end
	end
	return false
end

return ChallengeRules
