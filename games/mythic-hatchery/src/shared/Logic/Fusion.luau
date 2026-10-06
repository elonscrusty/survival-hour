--!strict
-- Prepares an atomic change. The service owns the actual removal/debit/egg grant.
local Config = require("../Config")
local Species = require("../Species")
local Elements = require("../Elements")
local Areas = require("../Areas")
local Hatch = require("./Hatch")
local Level = require("./Level")
export type Parent = Level.Creature & { Tier: number, Locked: boolean }
export type Egg = { Uid: string, Egg: string, Tier: number, Fused: Hatch.Fused }
export type Plan = { Consume: { string }, Cost: number, Egg: Egg }
local Fusion = {}
function Fusion.HatchLevel(): number return 1 end
function Fusion.Prepare(a: Parent, b: Parent, eggUid: string, busy: { [string]: boolean }, coins: number, coinMult: number, freeEggSpace: number): (Plan?, string?)
	if a.Uid == b.Uid then return nil, "Choose two different creatures" end
	if a.Locked or b.Locked then return nil, "Unlock both creatures first" end
	if busy[a.Uid] or busy[b.Uid] then return nil, "Remove creatures from habitats, battles, rides, expeditions or trades first" end
	if not Level.IsFinite(coins) or not Level.IsFinite(coinMult) or coinMult <= 0 then return nil, "Invalid currency" end
	if not Level.IsFinite(freeEggSpace) or freeEggSpace < 1 then return nil, "Egg bag full" end
	if eggUid == "" then return nil, "Missing egg id" end
	for _, c in { a, b } do
		if not Species.ById[c.Species] or not Elements.ById[c.Element] or not Areas.List[c.Tier] then return nil, "Invalid creature" end
	end
	local cost = math.floor(Config.Fusion.CoinCost * coinMult)
	if not Level.IsFinite(cost) or cost < 1 or coins < cost then return nil, "Not enough coins" end
	local ai, bi = table.find(Config.Rarities, a.Rarity), table.find(Config.Rarities, b.Rarity)
	if not ai or not bi then return nil, "Invalid rarity" end
	local best = math.max(ai, bi)
	local chance = Config.Fusion.UpgradeChance + (if ai == bi then Config.Fusion.SameRarityBonus else 0)
	chance = math.min(chance, Config.Fusion.MaxUpgradeChance)
	local rarity = { { Id = Config.Rarities[best], Weight = if best == #Config.Rarities then 1 else 1 - chance } }
	if best < #Config.Rarities then table.insert(rarity, { Id = Config.Rarities[best + 1], Weight = chance }) end
	local elements = {}
	for _, e in Elements.List do
		local weight = Config.Fusion.RandomElementChance / #Elements.List
		if e.Id == a.Element then weight += (1 - Config.Fusion.RandomElementChance) / 2 end
		if e.Id == b.Element then weight += (1 - Config.Fusion.RandomElementChance) / 2 end
		table.insert(elements, { Id = e.Id, Weight = weight })
	end
	local hybrid = Species.Hybrid(a.Species, b.Species)
	return {
		Consume = { a.Uid, b.Uid }, Cost = cost,
		Egg = {
			Uid = eggUid, Egg = "FusedEgg", Tier = math.max(a.Tier, b.Tier),
			Fused = { Species = { { Id = a.Species, Weight = 0.5 }, { Id = b.Species, Weight = 0.5 } },
				Rarity = rarity, Element = elements, Hybrid = hybrid, HybridChance = if hybrid then Config.Fusion.HybridChance else 0 },
		},
	}, nil
end
return Fusion
