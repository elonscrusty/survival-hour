-- Test helpers. SYNTHETIC FIXTURES: these build states for tests only; nothing here is game balance.
local Economy = require("../src/shared/Logic/Economy")
local State = require("../src/shared/Logic/State")

local H = {}

H.T0 = 1_800_000_000 -- fixed server time for tests (a UTC day boundary is not near it)

function H.Farm(mutate: ((any) -> ())?, ctx: any?)
	local s = State.New(H.T0)
	if mutate then
		mutate(s)
	end
	return Economy.new(s, ctx or {}), s
end

-- Finishes the tutorial the legitimate way is slow; tests that don't test it just mark it done.
function H.Done(s: any)
	s.tutorial.step = 8
	s.tutorial.done = true
end

-- Total eggs accounted for: on the farm + sold + discarded must equal laid.
function H.Ledger(s: any): (number, number)
	local onFarm = State.EggsOnFarm(s)
	local st = s.stats
	return (st.laid or 0), onFarm + (st.sold or 0) + (st.discarded or 0)
end

-- Deterministic pseudo-random sequence (LCG) for fuzz tests.
function H.Rng(seed: number)
	local x = seed
	return function(): number
		x = (x * 1103515245 + 12345) % 2147483648
		return x / 2147483648
	end
end

return H
