--!strict
-- SYNTHETIC TEST FIXTURES (test place + unit tests only; never shipped in default.project.json).
-- Each fixture mutates a FarmState to reach a late-game situation quickly. They are not balance.
-- Pure Luau with no requires: callers pass the catalogs in.

local Fixtures = {}

-- Everything bought on the current egg (respecting unlock rules), plenty of cash/gold.
function Fixtures.Maxed(s: any, cat: any)
	s.tutorial.step, s.tutorial.done = 8, true
	for _, h in s.housing do
		local t = 1
		for i, tier in cat.Housing.Tiers do
			if tier.unlockEgg <= s.egg then
				t = i
			end
		end
		h.tier = t
	end
	for i, v in s.vehicles do
		if i <= 4 then
			local t = 1
			for k, tier in cat.Vehicles.Tiers do
				if tier.unlockEgg <= s.egg then
					t = k
				end
			end
			v.tier = t
		end
	end
	for i, w in s.workers do
		if i <= 2 then
			local t = 1
			for k, tier in cat.Workers.Tiers do
				if tier.unlockEgg <= s.egg then
					t = k
				end
			end
			w.tier = t
		end
	end
	for _, u in cat.Upgrades.Common do
		if u.unlockEgg <= s.egg then
			s.common[u.id] = u.max
		end
	end
	s.silos = 5
	s.gold = math.max(s.gold, 5000)
end

-- Jump to egg `n` with enough cash to rebirth from it.
function Fixtures.AtEgg(s: any, n: number, cat: any)
	s.tutorial.step, s.tutorial.done = 8, true
	s.egg = math.clamp(n, 1, cat.Eggs.Count)
	s.cash = cat.Eggs.List[s.egg].requirement
end

-- Every boost in the inventory.
function Fixtures.AllBoosts(s: any, cat: any)
	for _, b in cat.Boosts.List do
		s.boosts.inventory[b.id] = (s.boosts.inventory[b.id] or 0) + 3
	end
end

-- Quest progress complete for today.
function Fixtures.QuestsReady(s: any)
	for _, stat in { "spawned", "collected", "deposited", "sold", "upgrades", "playtime", "boostsUsed", "foxes" } do
		s.quests.progress[stat] = 1e9
	end
end

return Fixtures
