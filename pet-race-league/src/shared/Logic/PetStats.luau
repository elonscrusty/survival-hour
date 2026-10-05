-- Pet levels, xp and the riding numbers they give.
local Config = require("../Config")
local Pets = require("../Pets")

local PetStats = {}

export type Pet = {
	Uid: string,
	Species: string,
	Levels: { [string]: number },
	Xp: { [string]: number },
	Paint: string?,
	Trail: string?,
	Nick: string?,
}

function PetStats.XpToNext(level: number): number
	return math.floor(Config.Stats.XpBase * Config.Stats.XpGrowth ^ (level - 1))
end

function PetStats.New(uid: string, species: string): Pet
	local levels, xp = {}, {}
	for _, s in Config.Stats.Names do
		levels[s] = 1
		xp[s] = 0
	end
	return { Uid = uid, Species = species, Levels = levels, Xp = xp }
end

local function isStat(stat: string): boolean
	return table.find(Config.Stats.Names, stat) ~= nil
end

-- Adds xp to one stat. Returns how many levels were gained.
function PetStats.AddXp(pet: Pet, stat: string, amount: number): number
	if not isStat(stat) or amount <= 0 then
		return 0
	end
	local max = Config.Stats.MaxLevel
	local level = pet.Levels[stat] or 1
	if level >= max then
		pet.Xp[stat] = 0
		return 0
	end
	local xp = (pet.Xp[stat] or 0) + amount
	local gained = 0
	while level < max and xp >= PetStats.XpToNext(level) do
		xp -= PetStats.XpToNext(level)
		level += 1
		gained += 1
	end
	if level >= max then
		xp = 0
	end
	pet.Levels[stat] = level
	pet.Xp[stat] = xp
	return gained
end

function PetStats.Bonus(pet: Pet): number
	local s = Pets.ById[pet.Species]
	local r = s and Pets.Rarities[s.Rarity]
	return r and r.Bonus or 0
end

export type Ride = {
	WalkSpeed: number,
	JumpPower: number,
	DashCharges: number,
	DashRecharge: number,
	Size: number,
}

function PetStats.Ride(pet: Pet): Ride
	local R = Config.Ride
	local mult = 1 + PetStats.Bonus(pet)
	local sp = pet.Levels.Speed or 1
	local jp = pet.Levels.Jump or 1
	local st = pet.Levels.Stamina or 1
	local total = sp + jp + st
	return {
		WalkSpeed = (R.BaseSpeed + (sp - 1) * R.SpeedPerLevel) * mult,
		JumpPower = (R.BaseJump + (jp - 1) * R.JumpPerLevel) * mult,
		DashCharges = math.min(R.DashChargesMax, R.DashChargesBase + math.floor(st / R.DashChargesEvery)),
		DashRecharge = math.max(R.DashRechargeMin, R.DashRechargeBase - (st - 1) * R.DashRechargePerLevel),
		Size = R.SizeBase + (total - 3) * R.SizePerLevel / 3,
	}
end

-- The fastest a racer on this pet can legally move (used by the anti-cheat).
function PetStats.MaxSpeed(pet: Pet?): number
	local R = Config.Ride
	local base = if pet then PetStats.Ride(pet).WalkSpeed else R.OnFootSpeed
	return base * R.DashBoost
end

-- A short "power" number shown on pet cards: average level.
function PetStats.Power(pet: Pet): number
	local sum = 0
	for _, s in Config.Stats.Names do
		sum += pet.Levels[s] or 1
	end
	return math.floor(sum / #Config.Stats.Names * 10 + 0.5) / 10
end

return PetStats
