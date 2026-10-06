--!strict
-- Seedable deterministic pseudo random numbers (Park-Miller "minimal
-- standard" generator, multiplier 48271, modulus 2^31 - 1). Every product
-- stays below 2^53, so results are identical on every machine and in the CLI
-- test runner. Used where a roll must be reproducible (expedition rewards
-- fixed by a seed, daily quests fixed by the day number).

local Rng = {}

local MOD = 2147483647
local MULT = 48271

export type Rng = {
	State: number,
	Next: (self: Rng) -> number,
	Int: (self: Rng, lo: number, hi: number) -> number,
	Range: (self: Rng, lo: number, hi: number) -> number,
	Chance: (self: Rng, p: number) -> boolean,
}

-- Turns any number into a valid internal state (1 .. MOD - 1).
local function normalise(seed: number): number
	if type(seed) ~= "number" or seed ~= seed or seed == math.huge or seed == -math.huge then
		seed = 1
	end
	local s = math.floor(math.abs(seed)) % MOD
	if s == 0 then
		s = 1
	end
	return s
end

local function nextValue(self: Rng): number
	self.State = (self.State * MULT) % MOD
	return (self.State - 1) / (MOD - 1) -- [0, 1)
end

-- Integer in [lo, hi] (inclusive). Swaps the bounds if needed.
local function int(self: Rng, lo: number, hi: number): number
	lo, hi = math.floor(lo), math.floor(hi)
	if hi < lo then
		lo, hi = hi, lo
	end
	local n = lo + math.floor(nextValue(self) * (hi - lo + 1))
	return math.min(n, hi)
end

-- Real number in [lo, hi).
local function range(self: Rng, lo: number, hi: number): number
	return lo + (hi - lo) * nextValue(self)
end

local function chance(self: Rng, p: number): boolean
	if p ~= p or p <= 0 then
		return false
	end
	if p >= 1 then
		return true
	end
	return nextValue(self) < p
end

function Rng.New(seed: number): Rng
	local r: Rng = {
		State = normalise(seed),
		Next = nextValue,
		Int = int,
		Range = range,
		Chance = chance,
	}
	-- Discard the first value: tiny seeds otherwise start with tiny outputs.
	r:Next()
	return r
end

-- Combines several numbers / strings into one seed (stable across machines).
function Rng.Hash(...: any): number
	local h = 5381
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		local s = tostring(v)
		for j = 1, #s do
			h = (h * 33 + string.byte(s, j)) % MOD
		end
		h = (h * 31 + 7) % MOD
	end
	return normalise(h)
end

Rng.Modulus = MOD

return Rng
