--!strict
-- Pet inventory rules: adding (capacity, unique uids), removing, equipping,
-- locking, deleting with refunds and crafting 5 -> next variant.
--
-- "Busy" creatures are on an expedition: they can't be equipped, deleted,
-- crafted or traded until the expedition is claimed. Callers can pass an
-- extra `blocked` set (e.g. creatures offered in an open trade) that is treated
-- the same way for delete / craft.

local Config = require("../Config")
local Creatures = require("../Species")
local Elements = require("../Elements")
local Gameplay = require("../Gameplay")
local Economy = require("./Economy")
local PetMath = require("./PetMath")
local Schema = require("./Schema")

type Profile = Schema.Profile
type Creature = Schema.Creature

export type CreatureSpec = { Species: string, Rarity: string, Element: string, Tier: number?, Level: number?, Xp: number?, Potions: { [string]: boolean }?, Edition: string?, HatchedAt: number? }

local Inventory = {}

function Inventory.Find(p: Profile, uid: string): (Creature?, number?)
	for i, creature in p.Creatures do
		if creature.Uid == uid then
			return creature, i
		end
	end
	return nil, nil
end

-- Set of uids currently on expeditions.
function Inventory.BusySet(p: Profile): { [string]: boolean }
	local busy: { [string]: boolean } = {}
	for _, e in p.Expeditions do
		for _, uid in e.Creatures do
			busy[uid] = true
		end
	end
	for _, slot in p.Habitats do
		if slot.Creature then busy[slot.Creature] = true end
	end
	return busy
end

function Inventory.IsBusy(p: Profile, uid: string): boolean
	return Inventory.BusySet(p)[uid] == true
end

function Inventory.IsEquipped(p: Profile, uid: string): boolean
	return table.find(p.Equipped, uid) ~= nil
end

function Inventory.FreeSpace(p: Profile): number
	return math.max(0, Economy.MaxStorage(p) - #p.Creatures)
end

-- Returns a uid that no creature in this profile uses, and advances the counter.
function Inventory.NewUid(p: Profile): string
	local existing: { [string]: boolean } = {}
	for _, creature in p.Creatures do
		existing[creature.Uid] = true
	end
	local uid
	repeat
		p.NextUid += 1
		uid = tostring(p.NextUid)
	until not existing[uid]
	return uid
end

-- Validates a creature spec and builds a fresh instance (not yet added).
function Inventory.Make(p: Profile, spec: CreatureSpec): (Creature?, string?)
 if type(spec) ~= "table" or not Creatures.ById[spec.Species] or not Elements.ById[spec.Element] or not table.find(Config.Rarities, spec.Rarity) then return nil, "Unknown creature" end
 local level = Schema.ClampInt(spec.Level or 1, 1, Gameplay.MaxLevel)
 local potions: { [string]: boolean } = {}
 if spec.Potions then for _, key in { "Ride", "Fly", "Neon" } do if spec.Potions[key] == true then potions[key] = true end end end
 return { Uid = Inventory.NewUid(p), Species = spec.Species, Rarity = spec.Rarity, Element = spec.Element,
 Tier = Schema.ClampInt(spec.Tier or 1, 1, 6), Level = level, Xp = if level >= Gameplay.MaxLevel then 0 else Schema.ClampInt(spec.Xp or 0, 0, PetMath.XpToNext(level)-1),
 Potions = potions, Neon = potions.Neon == true, Cosmetics = {}, Edition = spec.Edition, Locked = false, HatchedAt = Schema.ClampInt(spec.HatchedAt or 0, 0, 1e15) }, nil
end

-- Adds one creature if there is room. Returns the creature and whether its species is
-- new to the player's Index.
function Inventory.Add(p: Profile, spec: CreatureSpec): (Creature?, boolean, string?)
	if Inventory.FreeSpace(p) < 1 then
		return nil, false, "Pet storage is full"
	end
	local creature, err = Inventory.Make(p, spec)
	if not creature then
		return nil, false, err
	end
	table.insert(p.Creatures, creature)
	local discovered = not p.Index[creature.Species .. "|" .. creature.Element]
	p.Index[creature.Species .. "|" .. creature.Element] = true
	return creature, discovered, nil
end

-- Removes creatures by uid (no checks) and unequips them.
function Inventory.RemoveUnchecked(p: Profile, uids: { string })
	local drop: { [string]: boolean } = {}
	for _, u in uids do
		drop[u] = true
	end
	local kept: { Creature } = {}
	for _, creature in p.Creatures do
		if not drop[creature.Uid] then
			table.insert(kept, creature)
		end
	end
	p.Creatures = kept
	local eq: { string } = {}
	for _, u in p.Equipped do
		if not drop[u] then
			table.insert(eq, u)
		end
	end
	p.Equipped = eq
 for _,slot in p.Habitats do if slot.Creature and drop[slot.Creature] then slot.Creature=nil; slot.Power=0 end end
 local team: {string}={}
 for _,uid in p.BattleTeam do if not drop[uid] then table.insert(team,uid) end end
 p.BattleTeam=team
end

function Inventory.Equip(p: Profile, uid: string, equip: boolean): (boolean, string?)
	local creature = Inventory.Find(p, uid)
	if not creature then
		return false, "You don't have that creature"
	end
	local idx = table.find(p.Equipped, uid)
	if not equip then
		if idx then
			table.remove(p.Equipped, idx)
		end
		return true, nil
	end
	if idx then
		return true, nil
	end
	if Inventory.IsBusy(p, uid) then
		return false, "That creature is on an expedition"
	end
	if #p.Equipped >= Economy.MaxEquip(p) then
		return false, "No free creature slots"
	end
	table.insert(p.Equipped, uid)
	return true, nil
end

function Inventory.UnequipAll(p: Profile)
	p.Equipped = {}
end

-- Equips the strongest creatures that aren't busy.
function Inventory.EquipBest(p: Profile)
	local busy = Inventory.BusySet(p)
	local list: { Creature } = {}
	for _, creature in p.Creatures do
		if not busy[creature.Uid] then
			table.insert(list, creature)
		end
	end
	table.sort(list, PetMath.StrongerAt(Economy.HighestArea(p)))
	local eq: { string } = {}
	for i = 1, math.min(#list, Economy.MaxEquip(p)) do
		table.insert(eq, list[i].Uid)
	end
	p.Equipped = eq
end

function Inventory.EquippedCreatures(p: Profile): { Creature }
	local out: { Creature } = {}
	for _, uid in p.Equipped do
		local creature = Inventory.Find(p, uid)
		if creature then
			table.insert(out, creature)
		end
	end
	return out
end

function Inventory.EquippedPower(p: Profile): number
	local total = 0
	local scale = Economy.HighestArea(p)
	for _, creature in Inventory.EquippedCreatures(p) do
		total += PetMath.Power(creature, scale)
	end
	return total
end

function Inventory.Lock(p: Profile, uid: string, locked: boolean): (boolean, string?)
	local creature = Inventory.Find(p, uid)
	if not creature then
		return false, "You don't have that creature"
	end
	creature.Locked = locked == true
	return true, nil
end

-- Deletes creatures for a coin refund. All-or-nothing: any locked / busy / blocked
-- / unknown uid rejects the whole request. Returns the refund.
function Inventory.Delete(p: Profile, uids: { string }, blocked: { [string]: boolean }?): (number?, string?)
	local busy = Inventory.BusySet(p)
	local seen: { [string]: boolean } = {}
	local refund = 0
	for _, uid in uids do
		if seen[uid] then
			return nil, "Same creature chosen twice"
		end
		seen[uid] = true
		local creature = Inventory.Find(p, uid)
		if not creature then
			return nil, "You don't have that creature"
		end
		if creature.Locked then
			return nil, "Unlock a creature before deleting it"
		end
		if busy[uid] then
			return nil, "That creature is on an expedition"
		end
		if blocked and blocked[uid] then
			return nil, "That creature is in a trade"
		end
		refund += PetMath.DeleteRefund(creature)
	end
	Inventory.RemoveUnchecked(p, uids)
	local added = Economy.AddCoins(p, refund, false)
	return added, nil
end

return Inventory
