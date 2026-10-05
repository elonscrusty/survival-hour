-- Egg rolls with a pity counter: every Config.Hatch.PityEvery-th hatch of the same
-- egg is guaranteed Rare or better.
local Config = require("../Config")
local Pets = require("../Pets")

local Hatch = {}

-- r is a number in [0, 1). Returns the species id.
function Hatch.Roll(egg: any, r: number, pity: boolean?): string
	local pool = {}
	local total = 0
	for _, o in egg.Odds do
		if not pity or Pets.Rank(o.Pet) >= Config.Hatch.RarePlus then
			table.insert(pool, o)
			total += o.W
		end
	end
	if #pool == 0 then
		-- this egg has nothing Rare or better: roll normally
		return Hatch.Roll(egg, r, false)
	end
	local pick = r * total
	for _, o in pool do
		pick -= o.W
		if pick < 0 then
			return o.Pet
		end
	end
	return pool[#pool].Pet
end

-- count = hatches of this egg so far, including this one.
function Hatch.IsPity(count: number): boolean
	return count > 0 and count % Config.Hatch.PityEvery == 0
end

-- Chance (0..1) of each pet, for the egg odds display.
function Hatch.Chances(egg: any): { { Pet: string, Chance: number } }
	local total = 0
	for _, o in egg.Odds do
		total += o.W
	end
	local out = {}
	for _, o in egg.Odds do
		table.insert(out, { Pet = o.Pet, Chance = o.W / total })
	end
	return out
end

return Hatch
