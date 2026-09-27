--!strict
-- Deterministic Park–Miller RNG. Identical results in Roblox and in the Luau
-- CLI tests, which lets map layouts be regenerated and validated from a seed.

export type Rng = {
	Next: (self: Rng) -> number, -- [0, 1)
	Range: (self: Rng, lo: number, hi: number) -> number,
	Int: (self: Rng, lo: number, hi: number) -> number,
	Pick: <T>(self: Rng, list: { T }) -> T,
	Shuffle: <T>(self: Rng, list: { T }) -> (),
	State: number,
}

local Rng = {}
Rng.__index = Rng

local M = 2147483647
local A = 48271

function Rng.new(seed: number): Rng
	local s = math.floor(math.abs(seed)) % M
	if s == 0 then
		s = 1
	end
	local self = setmetatable({ State = s }, Rng)
	return (self :: any) :: Rng
end

function Rng.Next(self: any): number
	self.State = (self.State * A) % M
	return (self.State - 1) / (M - 1)
end

function Rng.Range(self: any, lo: number, hi: number): number
	return lo + (hi - lo) * self:Next()
end

function Rng.Int(self: any, lo: number, hi: number): number
	return math.min(hi, lo + math.floor(self:Next() * (hi - lo + 1)))
end

function Rng.Pick(self: any, list: { any }): any
	return list[self:Int(1, #list)]
end

function Rng.Shuffle(self: any, list: { any })
	for i = #list, 2, -1 do
		local j = self:Int(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

return Rng
