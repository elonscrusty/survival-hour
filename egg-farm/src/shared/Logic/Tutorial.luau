--!strict
-- Server-side tutorial progress. Each step completes from real farm state, so the tutorial can't
-- be faked from the client and a returning player whose farm already meets later steps moves on.

local Contract = require("../Contract")

local Tutorial = {}

local checks: { (s: any) -> boolean } = {
	function(s) -- spawn 20 chickens
		return s.population >= 20 or (s.stats.spawned or 0) >= 20
	end,
	function(s) -- collect from a house
		return (s.stats.collected or 0) > 0
	end,
	function(s) -- deposit at the warehouse
		return (s.stats.deposited or 0) > 0
	end,
	function(s) -- a vehicle sold eggs
		return (s.stats.sold or 0) > 0
	end,
	function(s) -- upgrade a vehicle
		for _, v in s.vehicles do
			if v.tier >= 2 then
				return true
			end
		end
		return s.rebirths > 0
	end,
	function(s) -- reach $500
		return s.cash >= 500 or s.rebirths > 0
	end,
	function(s) -- upgrade housing (or buy a second house)
		return s.housing[1].tier >= 2 or s.housing[2].tier >= 1 or s.rebirths > 0
	end,
}

Tutorial.Steps = #checks

-- Advances as many steps as are satisfied. Returns true if anything changed.
function Tutorial.Update(s: any): boolean
	if s.tutorial.done then
		return false
	end
	local changed = false
	while not s.tutorial.done and checks[s.tutorial.step] and checks[s.tutorial.step](s) do
		s.tutorial.step += 1
		changed = true
		if s.tutorial.step > #checks then
			s.tutorial.done = true
		end
	end
	return changed
end

-- What the HUD reveals at each step (the tutorial uncovers navigation as it goes).
function Tutorial.Reveals(step: number, done: boolean): { [string]: boolean }
	if done then
		return { spawn = true, counters = true, shipping = true, housing = true, nav = true, workers = true, eggs = true }
	end
	return {
		spawn = true,
		counters = step >= 2,
		shipping = step >= 5,
		housing = step >= 7,
		nav = false,
		workers = false,
		eggs = false,
	}
end

Tutorial.Text = Contract.Tutorial

return Tutorial
