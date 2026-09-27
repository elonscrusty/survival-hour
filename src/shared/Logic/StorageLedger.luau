--!strict
-- Pure shared-storage ledger. Each transaction validates everything first and
-- then moves resources between an inventory and a store in one synchronous
-- step (Luau event handlers never interleave mid-function), so concurrent
-- requests can neither duplicate nor lose items.

local InventoryModel = require("./InventoryModel")

export type Store = { Items: { [string]: number }, Capacity: number }

local StorageLedger = {}

function StorageLedger.New(capacity: number): Store
	local items = {}
	for _, id in InventoryModel.ResourceIds do
		items[id] = 0
	end
	return { Items = items, Capacity = capacity }
end

function StorageLedger.Total(store: Store): number
	local t = 0
	for _, n in store.Items do
		t += n
	end
	return t
end

function StorageLedger.Free(store: Store): number
	return math.max(0, store.Capacity - StorageLedger.Total(store))
end

-- Deposit up to `n` of `id` from inv into store. Returns moved amount.
function StorageLedger.Deposit(store: Store, inv: InventoryModel.Inventory, id: string, n: number): number
	if not InventoryModel.IsResource(id) or n <= 0 or n ~= math.floor(n) then
		return 0
	end
	local move = math.min(n, inv.Resources[id] or 0, StorageLedger.Free(store))
	if move <= 0 then
		return 0
	end
	inv.Resources[id] -= move
	store.Items[id] += move
	return move
end

-- Withdraw (or steal) up to `n` of `id` into inv, respecting pack space.
function StorageLedger.Withdraw(store: Store, inv: InventoryModel.Inventory, id: string, n: number): number
	if not InventoryModel.IsResource(id) or n <= 0 or n ~= math.floor(n) then
		return 0
	end
	local move = math.min(n, store.Items[id] or 0, InventoryModel.FreeSpace(inv))
	if move <= 0 then
		return 0
	end
	store.Items[id] -= move
	inv.Resources[id] += move
	return move
end

-- Pays `cost` from inventory first, then from the given stores (in order).
-- All-or-nothing. Returns true on success.
function StorageLedger.PayCombined(cost: { [string]: number }, inv: InventoryModel.Inventory, stores: { Store }): boolean
	for id, need in cost do
		local have = inv.Resources[id] or 0
		for _, s in stores do
			have += s.Items[id] or 0
		end
		if have < need then
			return false
		end
	end
	for id, need in cost do
		local fromInv = math.min(need, inv.Resources[id] or 0)
		inv.Resources[id] -= fromInv
		local left = need - fromInv
		for _, s in stores do
			if left <= 0 then
				break
			end
			local take = math.min(left, s.Items[id] or 0)
			s.Items[id] -= take
			left -= take
		end
	end
	return true
end

-- Combined availability (for UI / checks).
function StorageLedger.CanPayCombined(cost: { [string]: number }, inv: InventoryModel.Inventory, stores: { Store }): boolean
	for id, need in cost do
		local have = inv.Resources[id] or 0
		for _, s in stores do
			have += s.Items[id] or 0
		end
		if have < need then
			return false
		end
	end
	return true
end

return StorageLedger
