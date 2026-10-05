--!strict
-- Pet inventory rules: adding (capacity, unique uids), removing, equipping,
-- locking, deleting with refunds and crafting 5 -> next variant.
--
-- "Busy" pets are on an expedition: they can't be equipped, deleted,
-- crafted or traded until the expedition is claimed. Callers can pass an
-- extra `blocked` set (e.g. pets offered in an open trade) that is treated
-- the same way for delete / craft.

local Config = require("../Config")
local Pets = require("../Pets")
local Economy = require("./Economy")
local PetMath = require("./PetMath")
local Schema = require("./Schema")

type Profile = Schema.Profile
type PetInstance = Schema.PetInstance

export type PetSpec = { Id: string, Variant: string?, Shiny: boolean?, Level: number?, Xp: number? }

local Inventory = {}

function Inventory.Find(p: Profile, uid: string): (PetInstance?, number?)
	for i, pet in p.Pets do
		if pet.Uid == uid then
			return pet, i
		end
	end
	return nil, nil
end

-- Set of uids currently on expeditions.
function Inventory.BusySet(p: Profile): { [string]: boolean }
	local busy: { [string]: boolean } = {}
	for _, e in p.Expeditions do
		for _, uid in e.Pets do
			busy[uid] = true
		end
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
	return math.max(0, Economy.MaxStorage(p) - #p.Pets)
end

-- Returns a uid that no pet in this profile uses, and advances the counter.
function Inventory.NewUid(p: Profile): string
	local existing: { [string]: boolean } = {}
	for _, pet in p.Pets do
		existing[pet.Uid] = true
	end
	local uid
	repeat
		p.NextUid += 1
		uid = tostring(p.NextUid)
	until not existing[uid]
	return uid
end

-- Validates a pet spec and builds a fresh instance (not yet added).
function Inventory.Make(p: Profile, spec: PetSpec): (PetInstance?, string?)
	if type(spec) ~= "table" or type(spec.Id) ~= "string" or not Pets.ById[spec.Id] then
		return nil, "Unknown pet"
	end
	local variant = spec.Variant or "Normal"
	if not table.find(Config.Variants, variant) then
		return nil, "Unknown variant"
	end
	local level = Schema.ClampInt(spec.Level or 1, 1, Config.PetMaxLevel)
	local xp = if level >= Config.PetMaxLevel then 0 else Schema.ClampInt(spec.Xp or 0, 0, PetMath.XpToNext(level) - 1)
	return {
		Uid = Inventory.NewUid(p),
		Id = spec.Id,
		Variant = variant,
		Shiny = spec.Shiny == true,
		Level = level,
		Xp = xp,
		Locked = false,
	}, nil
end

-- Adds one pet if there is room. Returns the pet and whether its species is
-- new to the player's Index.
function Inventory.Add(p: Profile, spec: PetSpec): (PetInstance?, boolean, string?)
	if Inventory.FreeSpace(p) < 1 then
		return nil, false, "Pet storage is full"
	end
	local pet, err = Inventory.Make(p, spec)
	if not pet then
		return nil, false, err
	end
	table.insert(p.Pets, pet)
	local discovered = not p.Index[pet.Id]
	p.Index[pet.Id] = true
	return pet, discovered, nil
end

-- Removes pets by uid (no checks) and unequips them.
function Inventory.RemoveUnchecked(p: Profile, uids: { string })
	local drop: { [string]: boolean } = {}
	for _, u in uids do
		drop[u] = true
	end
	local kept: { PetInstance } = {}
	for _, pet in p.Pets do
		if not drop[pet.Uid] then
			table.insert(kept, pet)
		end
	end
	p.Pets = kept
	local eq: { string } = {}
	for _, u in p.Equipped do
		if not drop[u] then
			table.insert(eq, u)
		end
	end
	p.Equipped = eq
end

function Inventory.Equip(p: Profile, uid: string, equip: boolean): (boolean, string?)
	local pet = Inventory.Find(p, uid)
	if not pet then
		return false, "You don't have that pet"
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
		return false, "That pet is on an expedition"
	end
	if #p.Equipped >= Economy.MaxEquip(p) then
		return false, "No free pet slots"
	end
	table.insert(p.Equipped, uid)
	return true, nil
end

function Inventory.UnequipAll(p: Profile)
	p.Equipped = {}
end

-- Equips the strongest pets that aren't busy.
function Inventory.EquipBest(p: Profile)
	local busy = Inventory.BusySet(p)
	local list: { PetInstance } = {}
	for _, pet in p.Pets do
		if not busy[pet.Uid] then
			table.insert(list, pet)
		end
	end
	table.sort(list, PetMath.Stronger)
	local eq: { string } = {}
	for i = 1, math.min(#list, Economy.MaxEquip(p)) do
		table.insert(eq, list[i].Uid)
	end
	p.Equipped = eq
end

function Inventory.EquippedPets(p: Profile): { PetInstance }
	local out: { PetInstance } = {}
	for _, uid in p.Equipped do
		local pet = Inventory.Find(p, uid)
		if pet then
			table.insert(out, pet)
		end
	end
	return out
end

function Inventory.EquippedPower(p: Profile): number
	local total = 0
	for _, pet in Inventory.EquippedPets(p) do
		total += PetMath.Power(pet)
	end
	return total
end

function Inventory.Lock(p: Profile, uid: string, locked: boolean): (boolean, string?)
	local pet = Inventory.Find(p, uid)
	if not pet then
		return false, "You don't have that pet"
	end
	pet.Locked = locked == true
	return true, nil
end

-- Deletes pets for a coin refund. All-or-nothing: any locked / busy / blocked
-- / unknown uid rejects the whole request. Returns the refund.
function Inventory.Delete(p: Profile, uids: { string }, blocked: { [string]: boolean }?): (number?, string?)
	local busy = Inventory.BusySet(p)
	local seen: { [string]: boolean } = {}
	local refund = 0
	for _, uid in uids do
		if seen[uid] then
			return nil, "Same pet chosen twice"
		end
		seen[uid] = true
		local pet = Inventory.Find(p, uid)
		if not pet then
			return nil, "You don't have that pet"
		end
		if pet.Locked then
			return nil, "Unlock a pet before deleting it"
		end
		if busy[uid] then
			return nil, "That pet is on an expedition"
		end
		if blocked and blocked[uid] then
			return nil, "That pet is in a trade"
		end
		refund += PetMath.DeleteRefund(pet)
	end
	Inventory.RemoveUnchecked(p, uids)
	local added = Economy.AddCoins(p, refund, false)
	return added, nil
end

-- Pets that could be crafted together with `pet` (same species, variant and
-- shininess, unlocked, not busy or blocked), the chosen pet first, then
-- unequipped pets before equipped ones, lowest level first.
function Inventory.CraftGroup(p: Profile, pet: PetInstance, blocked: { [string]: boolean }?): { PetInstance }
	local busy = Inventory.BusySet(p)
	local group: { PetInstance } = {}
	for _, other in p.Pets do
		if other.Uid ~= pet.Uid and other.Id == pet.Id and other.Variant == pet.Variant
			and other.Shiny == pet.Shiny and not other.Locked and not busy[other.Uid]
			and not (blocked and blocked[other.Uid]) then
			table.insert(group, other)
		end
	end
	table.sort(group, function(a, b)
		local ea, eb = Inventory.IsEquipped(p, a.Uid), Inventory.IsEquipped(p, b.Uid)
		if ea ~= eb then
			return not ea
		end
		if a.Level ~= b.Level then
			return a.Level < b.Level
		end
		return a.Uid < b.Uid
	end)
	table.insert(group, 1, pet)
	return group
end

-- Combines Config.CraftCost copies of a pet into one of the next variant.
-- The new pet is equipped if any consumed pet was equipped.
function Inventory.Craft(p: Profile, uid: string, blocked: { [string]: boolean }?): (PetInstance?, string?)
	local pet = Inventory.Find(p, uid)
	if not pet then
		return nil, "You don't have that pet"
	end
	local nextVariant = PetMath.NextVariant(pet.Variant)
	if not nextVariant then
		return nil, "This pet can't be upgraded further"
	end
	if pet.Locked then
		return nil, "Unlock the pet first"
	end
	if Inventory.IsBusy(p, uid) then
		return nil, "That pet is on an expedition"
	end
	if blocked and blocked[uid] then
		return nil, "That pet is in a trade"
	end
	local group = Inventory.CraftGroup(p, pet, blocked)
	if #group < Config.CraftCost then
		return nil, string.format("You need %d of this pet (unlocked, at home)", Config.CraftCost)
	end
	local used: { string } = {}
	local wasEquipped = false
	for i = 1, Config.CraftCost do
		table.insert(used, group[i].Uid)
		wasEquipped = wasEquipped or Inventory.IsEquipped(p, group[i].Uid)
	end
	local id, shiny = pet.Id, pet.Shiny
	Inventory.RemoveUnchecked(p, used)
	-- Room is guaranteed: we just freed Config.CraftCost slots.
	local made = Inventory.Make(p, { Id = id, Variant = nextVariant, Shiny = shiny })
	if not made then
		return nil, "Craft failed"
	end
	table.insert(p.Pets, made)
	if wasEquipped and #p.Equipped < Economy.MaxEquip(p) then
		table.insert(p.Equipped, made.Uid)
	end
	p.Stats.Crafted = math.min(Schema.MaxStat, p.Stats.Crafted + 1)
	return made, nil
end

return Inventory
