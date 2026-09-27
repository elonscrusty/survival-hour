--!strict
-- Pure wildlife pacing rules (tested by tests/WildlifeRules.spec.luau).
-- Spec: night escalation raises predator pressure, aggression, pack size and
-- roaming, NOT health. Prey (deer, rabbits) roam day and night.

export type Pressure = {
	Night: number, -- 0 during the day
	PackBonus: number, -- extra wolves per pack
	AggroMult: number, -- detection / territory range multiplier
	IntervalMult: number, -- spawn interval multiplier (<1 = more often)
	PredatorCap: number, -- max predators alive at once
}

export type Tuning = {
	PredatorBase: number,
	PredatorPerNight: number,
	PredatorMax: number,
}

local WildlifeRules = {}

WildlifeRules.Predators = { Wolf = true, Bear = true, Boar = true } :: { [string]: boolean }

-- Night number for a phase (Night N follows Day N); 0 in daylight.
function WildlifeRules.NightNumber(phase: string, day: number): number
	return if phase == "Night" then math.max(1, day) else 0
end

function WildlifeRules.Pressure(night: number, t: Tuning): Pressure
	local n = math.max(0, night)
	local k = math.max(0, n - 1) -- escalation steps after the first night
	return {
		Night = n,
		PackBonus = if n == 0 then 0 else math.min(3, k // 2),
		AggroMult = if n == 0 then 0.8 else math.min(1.6, 1 + 0.1 * k),
		IntervalMult = if n == 0 then 1.5 else math.max(0.5, 1 - 0.08 * k),
		PredatorCap = if n == 0 then math.max(1, t.PredatorBase // 3) else math.min(t.PredatorMax, t.PredatorBase + t.PredatorPerNight * k),
	}
end

-- Spawn weights by time of day. Wolves only hunt at night; bears are uncommon.
function WildlifeRules.Weights(night: number): { [string]: number }
	if night == 0 then
		return { Deer = 5, Rabbit = 5, Boar = 3, Bear = 0.5 }
	end
	return { Wolf = 6 + math.min(4, night - 1), Bear = 1 + math.min(1.5, (night - 1) * 0.25), Boar = 2, Deer = 2, Rabbit = 1.5 }
end

-- Weighted pick from weights (only species in `allowed`), using r in [0,1).
function WildlifeRules.Pick(weights: { [string]: number }, allowed: { [string]: boolean }, r: number): string?
	local names = {}
	local total = 0
	for name, w in weights do
		if allowed[name] and w > 0 then
			table.insert(names, name)
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	table.sort(names)
	local x = r * total
	for _, name in names do
		x -= weights[name]
		if x <= 0 then
			return name
		end
	end
	return names[#names]
end

return WildlifeRules
