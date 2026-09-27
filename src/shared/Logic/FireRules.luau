--!strict
-- Pure campfire rules: fuel, levels, upgrade contributions and when fires can be
-- snuffed. CampService owns one Fire per camp; this module decides the numbers so
-- they can be unit-tested. Tunables live in Config.Fire.

export type Fire = {
	Level: number,
	Fuel: number, -- 0..1 of a full fire at the current level
	Out: boolean,
	Progress: { [string]: number }, -- materials contributed toward the next level
}

export type Tuning = {
	StartFuel: number,
	FullFuelSeconds: { number },
	FuelPerWood: number,
	SnuffTimes: { number },
	ProtectedNights: number,
	MaxLevel: number,
	Upgrades: { [number]: { [string]: number } },
}

local FireRules = {}

function FireRules.New(t: Tuning): Fire
	return { Level = 1, Fuel = t.StartFuel, Out = false, Progress = {} }
end

function FireRules.FullSeconds(fire: Fire, t: Tuning): number
	return t.FullFuelSeconds[math.clamp(fire.Level, 1, #t.FullFuelSeconds)]
end

-- Seconds of burn left at the current level.
function FireRules.SecondsLeft(fire: Fire, t: Tuning): number
	return if fire.Out then 0 else fire.Fuel * FireRules.FullSeconds(fire, t)
end

-- Burns `dt` seconds of fuel. Returns true if the fire just went out.
function FireRules.Burn(fire: Fire, dt: number, t: Tuning): boolean
	if fire.Out or dt <= 0 then
		return false
	end
	fire.Fuel = math.max(0, fire.Fuel - dt / FireRules.FullSeconds(fire, t))
	if fire.Fuel <= 0 then
		fire.Out = true
		return true
	end
	return false
end

-- How many Wood the fire can take before it's full (never more than `have`).
function FireRules.WoodAccepted(fire: Fire, have: number, t: Tuning, mult: number?): number
	if fire.Out or have <= 0 then
		return 0
	end
	local per = t.FuelPerWood * (mult or 1)
	local room = math.ceil((1 - fire.Fuel) / per - 1e-9)
	return math.clamp(room, 0, have)
end

-- Adds `n` Wood of fuel (caller has already checked WoodAccepted). Returns the new fuel.
function FireRules.AddWood(fire: Fire, n: number, t: Tuning, mult: number?): number
	if fire.Out or n <= 0 then
		return fire.Fuel
	end
	fire.Fuel = math.min(1, fire.Fuel + n * t.FuelPerWood * (mult or 1))
	return fire.Fuel
end

function FireRules.SnuffTime(fire: Fire, t: Tuning): number
	return t.SnuffTimes[math.clamp(fire.Level, 1, #t.SnuffTimes)]
end

-- Enemy snuffing is allowed from the start of Night (ProtectedNights + 1) onwards,
-- day and night. `day` is the match day counter (Night N follows Day N).
function FireRules.SnuffAllowed(phase: string, day: number, t: Tuning): boolean
	local first = t.ProtectedNights + 1
	if day > first then
		return phase == "Day" or phase == "Night"
	end
	return day == first and phase == "Night"
end

-- Materials still needed for the next level ({} when maxed / out).
function FireRules.Remaining(fire: Fire, t: Tuning): { [string]: number }
	local cost = t.Upgrades[fire.Level + 1]
	local out = {}
	if not cost or fire.Out then
		return out
	end
	for id, n in cost do
		local left = n - (fire.Progress[id] or 0)
		if left > 0 then
			out[id] = left
		end
	end
	return out
end

function FireRules.CanUpgrade(fire: Fire, t: Tuning): boolean
	return not fire.Out and fire.Level < t.MaxLevel and t.Upgrades[fire.Level + 1] ~= nil
end

-- Contributes materials from `have` toward the next level. Returns the amounts taken
-- (caller removes them from the inventory) and whether the fire levelled up.
-- Levelling keeps the fuel fraction, so a bigger fire burns longer at the same %.
function FireRules.Contribute(fire: Fire, have: { [string]: number }, t: Tuning): ({ [string]: number }, boolean)
	local taken = {}
	if not FireRules.CanUpgrade(fire, t) then
		return taken, false
	end
	for id, left in FireRules.Remaining(fire, t) do
		local n = math.min(left, have[id] or 0)
		if n > 0 then
			taken[id] = n
			fire.Progress[id] = (fire.Progress[id] or 0) + n
		end
	end
	if next(FireRules.Remaining(fire, t)) == nil then
		fire.Level += 1
		fire.Progress = {}
		return taken, true
	end
	return taken, false
end

return FireRules
