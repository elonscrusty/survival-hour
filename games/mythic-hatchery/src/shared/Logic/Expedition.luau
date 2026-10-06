--!strict
-- Expeditions: send up to Config.MaxPetsPerExpedition creatures to an opened
-- island for a fixed time. The reward is computed only from the expedition's
-- Seed (fixed at start), its creatures' power, the duration and the area, so it
-- can't be re-rolled by claiming again or by rejoining.

local Config = require("../Config")
local Areas = require("../Areas")
local Eggs = require("../Eggs")
local Economy = require("./Economy")
local Hatch = require("./Hatch")
local Inventory = require("./Inventory")
local PetMath = require("./PetMath")
local Rng = require("./Rng")
local Schema = require("./Schema")

type Profile = Schema.Profile
type Expedition = Schema.Expedition
type Creature = Schema.Creature

export type Duration = { Key: string, Seconds: number, Mult: number, FindChance: number, GemChance: number }
export type RewardRoll = { Coins: number, Gems: number, Creatures: { Inventory.CreatureSpec } }

local Expedition = {}

function Expedition.Duration(key: string): Duration?
	for _, d in Config.ExpeditionDurations do
		if d.Key == key then
			return d
		end
	end
	return nil
end

-- First free slot key ("1", "2", ...) or nil.
function Expedition.FreeSlot(p: Profile): string?
	for i = 1, Economy.ExpeditionSlots(p) do
		local key = tostring(i)
		if p.Expeditions[key] == nil then
			return key
		end
	end
	return nil
end

-- Starts an expedition in the first free slot. Creatures are unequipped. Returns
-- the slot key and the expedition, or nil and a reason.
function Expedition.Start(
	p: Profile,
	areaId: string,
	durationKey: string,
	uids: { string },
	now: number,
	seed: number,
	blocked: { [string]: boolean }?,
	coinMult: number?
): (string?, Expedition?, string?)
	local area = Areas.ById[areaId]
	if not area then
		return nil, nil, "Unknown island"
	end
	if not p.Areas[areaId] then
		return nil, nil, "Open that island first"
	end
	local dur = Expedition.Duration(durationKey)
	if not dur then
		return nil, nil, "Unknown duration"
	end
	if type(uids) ~= "table" or #uids < 1 then
		return nil, nil, "Choose at least one creature"
	end
	if #uids > Config.MaxPetsPerExpedition then
		return nil, nil, string.format("At most %d creatures per expedition", Config.MaxPetsPerExpedition)
	end
	local slot = Expedition.FreeSlot(p)
	if not slot then
		return nil, nil, "All expedition slots are busy"
	end
	local busy = Inventory.BusySet(p)
	local seen: { [string]: boolean } = {}
	for _, uid in uids do
		if seen[uid] then
			return nil, nil, "Same creature chosen twice"
		end
		seen[uid] = true
		if not Inventory.Find(p, uid) then
			return nil, nil, "You don't have that creature"
		end
		if busy[uid] then
			return nil, nil, "That creature is already on an expedition"
		end
		if blocked and blocked[uid] then
			return nil, nil, "That creature is in a trade"
		end
	end
	local list: { string } = table.clone(uids)
	for _, uid in list do
		local idx = table.find(p.Equipped, uid)
		if idx then
			table.remove(p.Equipped, idx)
		end
	end
	local exp: Expedition = {
		Area = areaId,
		Duration = dur.Key,
		Creatures = list,
		StartAt = now,
		EndAt = now + dur.Seconds,
		Seed = Rng.New(seed).State,
	}
	p.Expeditions[slot] = exp
	-- The coin multiplier is fixed at start, so buying a boost or VIP just
	-- before claiming doesn't multiply hours of expedition income.
	local mult = coinMult or 1
	p.ExpeditionMult[slot] = if Schema.IsFinite(mult) and mult > 0 then math.min(mult, Schema.MaxCoinMult) else 1
	return slot, exp, nil
end

-- Sum over the expedition's creatures of min(power / destination PowerMult,
-- Config.ExpeditionMaxRelPower).
function Expedition.RelativePower(p: Profile, exp: Expedition): number
	local area = Areas.ById[exp.Area]
	if not area then
		return 0
	end
	local scale = Economy.HighestArea(p)
	local total = 0
	for _, uid in exp.Creatures do
		local creature = Inventory.Find(p, uid)
		if creature then
			total += math.min(PetMath.Power(creature, scale) / area.PowerMult, Config.ExpeditionMaxRelPower)
		end
	end
	return total
end

-- The deterministic base reward (coins before the player's coin multiplier).
function Expedition.RollReward(p: Profile, exp: Expedition): RewardRoll
	local roll: RewardRoll = { Coins = 0, Gems = 0, Creatures = {} }
	local area = Areas.ById[exp.Area]
	local dur = Expedition.Duration(exp.Duration)
	if not area or not dur then
		return roll
	end
	-- Each creature counts with its power relative to the destination island
	-- (creature power already includes its own island's PowerMult), capped so a
	-- very strong creature sent to a cheap island can't farm it.
	local rel = Expedition.RelativePower(p, exp)
	local rng = Rng.New(exp.Seed)
	roll.Coins = math.floor(rel * Config.ExpeditionCoinsPerPower * area.CoinMult * dur.Mult)
	-- The same number of random draws happens whatever the outcomes, so a
	-- reward never depends on anything but the inputs above.
	local gemHit = rng:Chance(dur.GemChance)
	local gemRoll = rng:Next()
	local eggHit = rng:Chance(math.min(1, Config.ExpeditionEggChance * dur.Mult))
	local findHit = rng:Chance(dur.FindChance)
	local _findRoll = rng:Next()
	local lo, hi = Config.ExpeditionGems[1], Config.ExpeditionGems[2]
	if gemHit then
		local base = lo + math.floor(gemRoll * (hi - lo + 1))
		roll.Gems = math.floor(math.min(base, hi) * math.sqrt(dur.Mult))
	end
	if eggHit then
		local egg = Eggs.ById[area.Egg]
		if egg then
			local result = Hatch.Roll(egg, 1, rng)
			table.insert(roll.Creatures, { Species=result.Species, Rarity=result.Rarity, Element=result.Element, Tier=area.Index })
		end
	end
	if findHit then
		local result = Hatch.Roll(Eggs.ById[area.Egg], 1, rng)
		table.insert(roll.Creatures, {Species=result.Species,Rarity=result.Rarity,Element=result.Element,Tier=area.Index})
	end
	return roll
end

export type Claimed = {
	Coins: number,
	Gems: number,
	Creatures: { Creature },
	Discovered: { string },
}

-- Claims a finished expedition: frees its creatures and grants the reward.
-- Refuses (and changes nothing) if the found creatures would not fit. Coins use the
-- multiplier snapshotted at Start; `fallbackMult` is only for expeditions
-- saved before snapshots existed.
function Expedition.Claim(p: Profile, slot: string, now: number, fallbackMult: number?): (Claimed?, string?)
	local exp = p.Expeditions[slot]
	if not exp then
		return nil, "No expedition in that slot"
	end
	if now < exp.EndAt then
		return nil, "Your creatures aren't back yet"
	end
	local roll = Expedition.RollReward(p, exp)
	if #roll.Creatures > Inventory.FreeSpace(p) then
		return nil, string.format("Make room for %d creature(s) first", #roll.Creatures)
	end
	p.Expeditions[slot] = nil
	local snap = p.ExpeditionMult[slot]
	p.ExpeditionMult[slot] = nil
	local m = snap or fallbackMult or 1
	local mult = if Schema.IsFinite(m) and m > 0 then math.min(m, Schema.MaxCoinMult) else 1
	local out: Claimed = { Coins = 0, Gems = 0, Creatures = {}, Discovered = {} }
	out.Coins = Economy.AddCoins(p, roll.Coins * mult, true)
	out.Gems = Economy.AddGems(p, roll.Gems)
	for _, spec in roll.Creatures do
		local creature, discovered = Inventory.Add(p, spec)
		if creature then
			table.insert(out.Creatures, creature)
			if discovered then
				table.insert(out.Discovered, creature.Species .. "|" .. creature.Element)
			end
		end
	end
	p.Stats.Expeditions = math.min(Schema.MaxStat, p.Stats.Expeditions + 1)
	return out, nil
end

-- Gems needed to finish now (0 when already finished).
function Expedition.SkipCost(exp: Expedition, now: number): number
	local left = exp.EndAt - now
	if left <= 0 then
		return 0
	end
	return math.max(5, math.ceil(left / 60 * Config.ExpeditionSkipGemsPerMinute))
end

function Expedition.Skip(p: Profile, slot: string, now: number): (number?, string?)
	local exp = p.Expeditions[slot]
	if not exp then
		return nil, "No expedition in that slot"
	end
	local cost = Expedition.SkipCost(exp, now)
	if cost <= 0 then
		return nil, "Already finished"
	end
	if not Economy.Spend(p, "Gems", cost) then
		return nil, string.format("You need %d gems", cost)
	end
	exp.EndAt = now
	return cost, nil
end

return Expedition
