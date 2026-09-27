--!strict
-- Pure inventory model. The server's InventoryService owns one of these per
-- player per match and replicates snapshots to the owner. All mutation
-- functions validate first and then mutate, so a failed call changes nothing.

export type Stack = { Id: string, Durability: number?, Filled: boolean? }

export type Inventory = {
	Resources: { [string]: number },
	Capacity: number,
	Slots: { [string]: Stack? },
	Armor: Stack?,
	Bandages: number,
	BandageMax: number,
	Ammo: { [string]: number },
	AmmoMax: { [string]: number },
	Equipped: string?, -- slot name, nil = fists
}

local InventoryModel = {}

InventoryModel.ResourceIds = { "Stick", "Stone", "Wood", "Plant", "Leather", "Rope", "Berries", "Mushroom", "Scrap", "Iron", "Coal", "RareComponent", "FirstAid", "Medkit" }
InventoryModel.SlotNames = { "Weapon1", "Weapon2", "Tool", "Tool2", "Utility" }

local RESOURCE_SET = {}
for _, id in InventoryModel.ResourceIds do
	RESOURCE_SET[id] = true
end

function InventoryModel.IsResource(id: string): boolean
	return RESOURCE_SET[id] == true
end

function InventoryModel.New(capacity: number, bandageMax: number, ammoMax: { [string]: number }): Inventory
	local res = {}
	for _, id in InventoryModel.ResourceIds do
		res[id] = 0
	end
	local ammo = {}
	for k in ammoMax do
		ammo[k] = 0
	end
	return {
		Resources = res,
		Capacity = capacity,
		Slots = {},
		Armor = nil,
		Bandages = 0,
		BandageMax = bandageMax,
		Ammo = ammo,
		AmmoMax = table.clone(ammoMax),
		Equipped = nil,
	}
end

function InventoryModel.ResourceTotal(inv: Inventory): number
	local t = 0
	for _, n in inv.Resources do
		t += n
	end
	return t
end

function InventoryModel.FreeSpace(inv: Inventory): number
	return math.max(0, inv.Capacity - InventoryModel.ResourceTotal(inv))
end

-- Adds up to `n`; returns how many were actually added.
function InventoryModel.AddResource(inv: Inventory, id: string, n: number): number
	if not RESOURCE_SET[id] or n <= 0 or n ~= math.floor(n) then
		return 0
	end
	local add = math.min(n, InventoryModel.FreeSpace(inv))
	inv.Resources[id] += add
	return add
end

function InventoryModel.HasResources(inv: Inventory, cost: { [string]: number }): boolean
	for id, n in cost do
		if (inv.Resources[id] or 0) < n then
			return false
		end
	end
	return true
end

function InventoryModel.RemoveResources(inv: Inventory, cost: { [string]: number }): boolean
	if not InventoryModel.HasResources(inv, cost) then
		return false
	end
	for id, n in cost do
		inv.Resources[id] -= n
	end
	return true
end

-- Removes up to n of one resource; returns removed amount.
function InventoryModel.TakeResource(inv: Inventory, id: string, n: number): number
	if not RESOURCE_SET[id] or n <= 0 then
		return 0
	end
	local take = math.min(n, inv.Resources[id] or 0)
	inv.Resources[id] -= take
	return take
end

-- Empties the resource pack (death drop). Returns what was removed.
function InventoryModel.TakeAllResources(inv: Inventory): { [string]: number }
	local out = {}
	for id, n in inv.Resources do
		if n > 0 then
			out[id] = n
			inv.Resources[id] = 0
		end
	end
	return out
end

-- Which slots can hold an item of `kind`?
function InventoryModel.SlotsForKind(kind: string): { string }
	if kind == "Weapon" then
		return { "Weapon1", "Weapon2" }
	elseif kind == "Tool" then
		return { "Tool", "Tool2" }
	elseif kind == "Utility" then
		return { "Utility" }
	end
	return {}
end

-- Places equipment. Picks an empty compatible slot; if none, replaces
-- `preferSlot` (if compatible) or the first compatible slot. Returns the slot
-- used and the displaced stack (to be dropped by the caller), or nil if the
-- kind cannot be held.
function InventoryModel.AddEquipment(inv: Inventory, kind: string, stack: Stack, preferSlot: string?): (string?, Stack?)
	if kind == "Armor" then
		local old = inv.Armor
		inv.Armor = stack
		return "Armor", old
	end
	local slots = InventoryModel.SlotsForKind(kind)
	if #slots == 0 then
		return nil, nil
	end
	for _, s in slots do
		if inv.Slots[s] == nil then
			inv.Slots[s] = stack
			return s, nil
		end
	end
	local target = slots[1]
	if preferSlot and table.find(slots, preferSlot) then
		target = preferSlot
	end
	local old = inv.Slots[target]
	inv.Slots[target] = stack
	return target, old
end

function InventoryModel.RemoveSlot(inv: Inventory, slot: string): Stack?
	if slot == "Armor" then
		local old = inv.Armor
		inv.Armor = nil
		return old
	end
	local old = inv.Slots[slot]
	inv.Slots[slot] = nil
	if inv.Equipped == slot then
		inv.Equipped = nil
	end
	return old
end

function InventoryModel.HasItem(inv: Inventory, itemId: string): string?
	for _, s in InventoryModel.SlotNames do
		local st = inv.Slots[s]
		if st and st.Id == itemId then
			return s
		end
	end
	if inv.Armor and inv.Armor.Id == itemId then
		return "Armor"
	end
	return nil
end

function InventoryModel.Swap(inv: Inventory, a: string, b: string): boolean
	local weapon = { Weapon1 = true, Weapon2 = true }
	if not (weapon[a] and weapon[b]) or a == b then
		return false
	end
	inv.Slots[a], inv.Slots[b] = inv.Slots[b], inv.Slots[a]
	if inv.Equipped == a then
		inv.Equipped = b
	elseif inv.Equipped == b then
		inv.Equipped = a
	end
	return true
end

function InventoryModel.Equip(inv: Inventory, slot: string?): boolean
	if slot == nil then
		inv.Equipped = nil
		return true
	end
	if inv.Slots[slot] == nil then
		return false
	end
	inv.Equipped = slot
	return true
end

function InventoryModel.AddAmmo(inv: Inventory, ammo: string, n: number): number
	local max = inv.AmmoMax[ammo]
	if max == nil or n <= 0 then
		return 0
	end
	local add = math.min(n, max - inv.Ammo[ammo])
	inv.Ammo[ammo] += add
	return add
end

function InventoryModel.UseAmmo(inv: Inventory, ammo: string): boolean
	if (inv.Ammo[ammo] or 0) <= 0 then
		return false
	end
	inv.Ammo[ammo] -= 1
	return true
end

function InventoryModel.AddBandages(inv: Inventory, n: number): number
	local add = math.max(0, math.min(n, inv.BandageMax - inv.Bandages))
	inv.Bandages += add
	return add
end

-- Wears down durability on a slot; returns true if the item broke (and was removed).
function InventoryModel.Wear(inv: Inventory, slot: string, amount: number): boolean
	local st = if slot == "Armor" then inv.Armor else inv.Slots[slot]
	if st == nil or st.Durability == nil then
		return false
	end
	st.Durability = math.max(0, st.Durability - amount)
	if st.Durability <= 0 then
		InventoryModel.RemoveSlot(inv, slot)
		return true
	end
	return false
end

-- Serialisable snapshot for replication to the owning client.
function InventoryModel.Snapshot(inv: Inventory)
	local slots = {}
	for _, s in InventoryModel.SlotNames do
		local st = inv.Slots[s]
		slots[s] = if st then table.clone(st) else false
	end
	return {
		Resources = table.clone(inv.Resources),
		Capacity = inv.Capacity,
		Slots = slots,
		Armor = if inv.Armor then table.clone(inv.Armor) else false,
		Bandages = inv.Bandages,
		Ammo = table.clone(inv.Ammo),
		Equipped = inv.Equipped or false,
	}
end

return InventoryModel
