--!strict
-- Pure rules for world events and match conditions (tested by tests/MatchEvents.spec.luau).
-- EventService owns the timing and the world side; this module only decides.

local MatchEvents = {}

export type Condition = {
	Id: string,
	Name: string,
	Line: string, -- one sentence shown at the start of the match
	EventWeights: { [string]: number }?, -- multipliers on Config.Events.Weights
	RainMult: number?, -- multiplier on the per-phase rain chance
	WildlifeInterval: number?, -- multiplier on the wildlife spawn interval (<1 = more animals)
	PredatorAggro: number?, -- multiplier on night predator aggro range
	BonusCaches: number?, -- extra survivor caches during the match
}

-- Small twists, never new rules: every one is within ~20% of normal.
local CONDITIONS: { Condition } = {
	{ Id = "Misty", Name = "Misty Valley", Line = "Fog rolls through the trees more often.", EventWeights = { Fog = 3 } },
	{ Id = "Rainy", Name = "Rainy Season", Line = "Showers and storms are more likely.", RainMult = 2.2, EventWeights = { Thunderstorm = 2 } },
	{ Id = "Restless", Name = "Restless Wilds", Line = "More wildlife is on the move.", WildlifeInterval = 0.85, EventWeights = { Migration = 2 } },
	{ Id = "Hungry", Name = "Hungry Predators", Line = "Predators hunt a little harder at night.", PredatorAggro = 1.12, EventWeights = { PredatorSurge = 1.5 } },
	{ Id = "Scavenged", Name = "Lost Survivors", Line = "More survivors left caches behind.", BonusCaches = 1, EventWeights = { SurvivorCache = 2 } },
}
MatchEvents.Conditions = CONDITIONS

MatchEvents.ById = {} :: { [string]: Condition }
for _, c in MatchEvents.Conditions do
	MatchEvents.ById[c.Id] = c
end

-- Picks this match's condition (or nil). `roll` returns [0, 1).
function MatchEvents.PickCondition(chance: number, roll: () -> number): Condition?
	if roll() >= chance then
		return nil
	end
	local list = MatchEvents.Conditions
	return list[math.clamp(math.floor(roll() * #list) + 1, 1, #list)]
end

-- Weighted event choice. `blocked[kind]` removes a kind (e.g. storms on Day 1, or the last event).
function MatchEvents.PickEvent(weights: { [string]: number }, condition: Condition?, blocked: { [string]: boolean }, roll: () -> number): string?
	local kinds = {}
	for k in weights do
		table.insert(kinds, k)
	end
	table.sort(kinds) -- deterministic order for a given roll
	local total = 0
	local eff = {}
	for _, k in kinds do
		local w = if blocked[k] then 0 else weights[k] * ((condition and condition.EventWeights and condition.EventWeights[k]) or 1)
		eff[k] = w
		total += w
	end
	if total <= 0 then
		return nil
	end
	local r = roll() * total
	for _, k in kinds do
		r -= eff[k]
		if r < 0 then
			return k
		end
	end
	return kinds[#kinds]
end

-- The phase's base sky when no event holds the weather.
function MatchEvents.BaseWeather(day: number, rainChance: number, condition: Condition?, roll: () -> number): string
	if day <= 1 then
		return "Clear"
	end
	local rain = rainChance * ((condition and condition.RainMult) or 1)
	local r = roll()
	if r < rain then
		return "Rain"
	elseif r < rain + 0.2 then
		return "Cloudy"
	end
	return "Clear"
end

-- Eight-way compass word for a flat offset (x east, z south in Roblox space: -Z is north).
function MatchEvents.Compass(dx: number, dz: number): string
	local deg = (math.deg(math.atan2(dx, -dz)) + 360) % 360
	local names = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }
	return names[math.floor((deg + 22.5) / 45) % 8 + 1]
end

return MatchEvents
