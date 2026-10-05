--!strict
-- Trading as a pure state machine.
--
--   Open --(both ready)--> Confirming --(countdown ends)--> swap -> Done
--     ^                        |
--     +---- any offer change --+         (Cancel at any time -> Cancelled)
--
-- Offers are re-validated at swap time, so a pet that was deleted, locked,
-- sent on an expedition or gems that were spent in the meantime make the swap
-- fail instead of duplicating anything. The swap first computes both new
-- inventories without touching either profile, then commits them together.

local Config = require("../Config")
local Types = require("../Types")
local Economy = require("./Economy")
local Inventory = require("./Inventory")
local Profile = require("./Profile")
local Schema = require("./Schema")

type Profile = Schema.Profile
type PetInstance = Schema.PetInstance

export type Side = { UserId: number, Name: string, Pets: { string }, Gems: number, Ready: boolean }
export type TradeState = {
	Id: string,
	Sides: { Side },
	Status: string, -- "Open" | "Confirming" | "Done" | "Cancelled"
	ConfirmAt: number?,
}

export type SidePlan = {
	Pets: { PetInstance },
	Equipped: { string },
	NextUid: number,
	Gems: number,
	Received: { PetInstance },
}
export type Plan = { A: SidePlan, B: SidePlan }

local Trade = {}

function Trade.New(id: string, aUserId: number, aName: string, bUserId: number, bName: string): TradeState
	return {
		Id = id,
		Sides = {
			{ UserId = aUserId, Name = aName, Pets = {}, Gems = 0, Ready = false },
			{ UserId = bUserId, Name = bName, Pets = {}, Gems = 0, Ready = false },
		},
		Status = "Open",
		ConfirmAt = nil,
	}
end

function Trade.SideIndex(t: TradeState, userId: number): number?
	if t.Sides[1].UserId == userId then
		return 1
	elseif t.Sides[2].UserId == userId then
		return 2
	end
	return nil
end

function Trade.IsActive(t: TradeState): boolean
	return t.Status == "Open" or t.Status == "Confirming"
end

-- Checks that a profile can give these pets and gems right now.
function Trade.ValidateOffer(p: Profile, uids: any, gems: any): (boolean, string?)
	if type(uids) ~= "table" then
		return false, "Bad pet list"
	end
	local n = #uids
	local count = 0
	for _ in uids do
		count += 1
	end
	if count ~= n then
		return false, "Bad pet list"
	end
	if n > Config.TradeMaxPets then
		return false, string.format("At most %d pets per trade", Config.TradeMaxPets)
	end
	if not Schema.IsInt(gems, 0, Config.TradeMaxGems) then
		return false, "Bad gem amount"
	end
	if gems > p.Gems then
		return false, "Not enough gems"
	end
	local busy = Inventory.BusySet(p)
	local seen: { [string]: boolean } = {}
	for i = 1, n do
		local uid = uids[i]
		if type(uid) ~= "string" or #uid == 0 or #uid > Schema.MaxUidLength then
			return false, "Bad pet id"
		end
		if seen[uid] then
			return false, "Same pet chosen twice"
		end
		seen[uid] = true
		local pet = Inventory.Find(p, uid)
		if not pet then
			return false, "You don't have that pet"
		end
		if pet.Locked then
			return false, "Locked pets can't be traded"
		end
		if busy[uid] then
			return false, "Pets on expeditions can't be traded"
		end
	end
	return true, nil
end

local function resetReady(t: TradeState)
	t.Sides[1].Ready = false
	t.Sides[2].Ready = false
	t.Status = "Open"
	t.ConfirmAt = nil
end

-- Replaces one side's offer. Any change un-readies both sides.
function Trade.SetOffer(t: TradeState, userId: number, p: Profile, uids: any, gems: any): (boolean, string?)
	if not Trade.IsActive(t) then
		return false, "Trade is closed"
	end
	local i = Trade.SideIndex(t, userId)
	if not i then
		return false, "Not in this trade"
	end
	local ok, err = Trade.ValidateOffer(p, uids, gems)
	if not ok then
		return false, err
	end
	local side = t.Sides[i]
	local list: { string } = {}
	for _, uid in uids do
		table.insert(list, uid)
	end
	side.Pets = list
	side.Gems = gems
	resetReady(t)
	return true, nil
end

function Trade.SetReady(t: TradeState, userId: number, ready: boolean, now: number): (boolean, string?)
	if not Trade.IsActive(t) then
		return false, "Trade is closed"
	end
	local i = Trade.SideIndex(t, userId)
	if not i then
		return false, "Not in this trade"
	end
	if ready then
		local a, b = t.Sides[1], t.Sides[2]
		if #a.Pets == 0 and a.Gems == 0 and #b.Pets == 0 and b.Gems == 0 then
			return false, "Add something to the trade first"
		end
	end
	t.Sides[i].Ready = ready == true
	if t.Sides[1].Ready and t.Sides[2].Ready then
		if t.Status ~= "Confirming" then
			t.Status = "Confirming"
			t.ConfirmAt = now + Config.TradeConfirmSeconds
		end
	else
		t.Status = "Open"
		t.ConfirmAt = nil
	end
	return true, nil
end

-- True when the countdown has finished and the swap should run.
function Trade.Due(t: TradeState, now: number): boolean
	local at = t.ConfirmAt
	return t.Status == "Confirming" and at ~= nil and now >= at
end

function Trade.Cancel(t: TradeState)
	if Trade.IsActive(t) then
		t.Status = "Cancelled"
		t.ConfirmAt = nil
	end
end

local function planSide(p: Profile, give: { string }, giveGems: number, get: { PetInstance }, getGems: number): SidePlan
	local drop: { [string]: boolean } = {}
	for _, uid in give do
		drop[uid] = true
	end
	local pets: { PetInstance } = {}
	local used: { [string]: boolean } = {}
	for _, pet in p.Pets do
		if not drop[pet.Uid] then
			table.insert(pets, pet)
			used[pet.Uid] = true
		end
	end
	local equipped: { string } = {}
	for _, uid in p.Equipped do
		if not drop[uid] then
			table.insert(equipped, uid)
		end
	end
	-- Incoming pets get fresh uids from the receiver's counter and arrive unlocked.
	local nextUid = p.NextUid
	local received: { PetInstance } = {}
	for _, src in get do
		local uid
		repeat
			nextUid += 1
			uid = tostring(nextUid)
		until not used[uid]
		used[uid] = true
		local pet = Profile.CopyPet(src)
		pet.Uid = uid
		pet.Locked = false
		table.insert(pets, pet)
		table.insert(received, pet)
	end
	local gems = math.min(Schema.MaxGems, p.Gems - giveGems + getGems)
	return { Pets = pets, Equipped = equipped, NextUid = nextUid, Gems = gems, Received = received }
end

local function offeredPets(p: Profile, uids: { string }): { PetInstance }
	local out: { PetInstance } = {}
	for _, uid in uids do
		local pet = Inventory.Find(p, uid)
		if pet then
			table.insert(out, pet)
		end
	end
	return out
end

-- Validates both offers against the current profiles and computes both new
-- inventories. Touches nothing. `pa` belongs to Sides[1], `pb` to Sides[2].
function Trade.Plan(t: TradeState, pa: Profile, pb: Profile): (Plan?, string?)
	if t.Status ~= "Confirming" then
		return nil, "Trade isn't confirmed"
	end
	local a, b = t.Sides[1], t.Sides[2]
	if not a.Ready or not b.Ready then
		return nil, "Both players must be ready"
	end
	local okA, errA = Trade.ValidateOffer(pa, a.Pets, a.Gems)
	if not okA then
		return nil, a.Name .. ": " .. (errA or "offer changed")
	end
	local okB, errB = Trade.ValidateOffer(pb, b.Pets, b.Gems)
	if not okB then
		return nil, b.Name .. ": " .. (errB or "offer changed")
	end
	local newCountA = #pa.Pets - #a.Pets + #b.Pets
	if #b.Pets > #a.Pets and newCountA > Economy.MaxStorage(pa) then
		return nil, a.Name .. " doesn't have room for those pets"
	end
	local newCountB = #pb.Pets - #b.Pets + #a.Pets
	if #a.Pets > #b.Pets and newCountB > Economy.MaxStorage(pb) then
		return nil, b.Name .. " doesn't have room for those pets"
	end
	local petsA = offeredPets(pa, a.Pets)
	local petsB = offeredPets(pb, b.Pets)
	return {
		A = planSide(pa, a.Pets, a.Gems, petsB, b.Gems),
		B = planSide(pb, b.Pets, b.Gems, petsA, a.Gems),
	}, nil
end

-- Journal ------------------------------------------------------------------------
-- A trade touches two profiles that are saved separately, so a crash between
-- the two saves could duplicate items. TradeService prevents that with a
-- journal record written before either profile changes:
--   1. both profiles get PendingTrade = id and are saved;
--   2. the journal (both sides' changes) is written under its own key;
--   3. each side is applied with ApplySide and saved.
-- A profile that loads with PendingTrade set replays its side from the journal
-- (or just clears the flag if no journal was written). ApplySide is idempotent
-- through AppliedTrades, so replaying twice changes nothing.

export type JournalSide = { Give: { string }, GiveGems: number, Get: { PetInstance }, GetGems: number }
export type Journal = { Id: string, Sides: { [string]: JournalSide } }

-- Builds the journal for a planned trade (keys are tostring(UserId)).
function Trade.Journal(t: TradeState, plan: Plan): Journal
	local a, b = t.Sides[1], t.Sides[2]
	local function copyList(list: { PetInstance }): { PetInstance }
		local out: { PetInstance } = {}
		for _, pet in list do
			table.insert(out, Profile.CopyPet(pet))
		end
		return out
	end
	return {
		Id = t.Id,
		Sides = {
			[tostring(a.UserId)] = { Give = table.clone(a.Pets), GiveGems = a.Gems, Get = copyList(plan.A.Received), GetGems = b.Gems },
			[tostring(b.UserId)] = { Give = table.clone(b.Pets), GiveGems = b.Gems, Get = copyList(plan.B.Received), GetGems = a.Gems },
		},
	}
end

-- Validates one side of a journal loaded from storage. Returns nil if unusable.
function Trade.SanitizeSide(raw: any): JournalSide?
	if type(raw) ~= "table" or type(raw.Give) ~= "table" or type(raw.Get) ~= "table" then
		return nil
	end
	local give: { string } = {}
	for _, uid in raw.Give do
		if type(uid) == "string" and #uid > 0 and #uid <= Schema.MaxUidLength then
			table.insert(give, uid)
		end
	end
	-- Reuse the profile sanitiser for the pets (validates ids, variants, levels).
	local tmp = Profile.Sanitize({ Pets = raw.Get })
	return {
		Give = give,
		GiveGems = Schema.ClampInt(raw.GiveGems, 0, Config.TradeMaxGems),
		Get = tmp.Pets,
		GetGems = Schema.ClampInt(raw.GetGems, 0, Config.TradeMaxGems),
	}
end

-- Applies one side of a trade to a profile. Returns false (and changes
-- nothing) if this trade was already applied. Received pets keep their uid
-- unless it is taken, arrive unlocked, and may exceed storage (the trade was
-- agreed when they fit).
function Trade.ApplySide(p: Profile, side: JournalSide, tradeId: string): boolean
	if table.find(p.AppliedTrades, tradeId) then
		if p.PendingTrade == tradeId then
			p.PendingTrade = nil
		end
		return false
	end
	Inventory.RemoveUnchecked(p, side.Give)
	local used: { [string]: boolean } = {}
	for _, pet in p.Pets do
		used[pet.Uid] = true
	end
	for _, src in side.Get do
		local pet = Profile.CopyPet(src)
		pet.Locked = false
		if used[pet.Uid] or #pet.Uid == 0 or #pet.Uid > Schema.MaxUidLength then
			pet.Uid = Inventory.NewUid(p)
		else
			local n = tonumber(pet.Uid)
			if n and Schema.IsFinite(n) and n > p.NextUid then
				p.NextUid = math.min(math.floor(n), 1e15)
			end
		end
		used[pet.Uid] = true
		table.insert(p.Pets, pet)
		p.Index[pet.Id] = true
	end
	p.Gems = math.clamp(p.Gems - side.GiveGems + side.GetGems, 0, Schema.MaxGems)
	table.insert(p.AppliedTrades, tradeId)
	while #p.AppliedTrades > Schema.MaxAppliedTrades do
		table.remove(p.AppliedTrades, 1)
	end
	if p.PendingTrade == tradeId then
		p.PendingTrade = nil
	end
	return true
end

-- Plans and applies the swap in memory (tests and the final step of the
-- journaled flow). Both profiles change, or neither does.
function Trade.Execute(t: TradeState, pa: Profile, pb: Profile): (Plan?, string?)
	local plan, err = Trade.Plan(t, pa, pb)
	if not plan then
		return nil, err
	end
	local j = Trade.Journal(t, plan)
	Trade.ApplySide(pa, j.Sides[tostring(t.Sides[1].UserId)], t.Id)
	Trade.ApplySide(pb, j.Sides[tostring(t.Sides[2].UserId)], t.Id)
	t.Status = "Done"
	t.ConfirmAt = nil
	return plan, nil
end

local function sideView(s: Side, p: Profile?): Types.TradeSide
	local pets: { PetInstance } = {}
	if p then
		for _, uid in s.Pets do
			local pet = Inventory.Find(p, uid)
			if pet then
				table.insert(pets, Profile.CopyPet(pet))
			end
		end
	end
	return { UserId = s.UserId, Name = s.Name, Pets = pets, Gems = s.Gems, Ready = s.Ready }
end

-- The window as seen by `userId`. `profileOf` looks up a side's profile.
function Trade.View(t: TradeState, userId: number, now: number, profileOf: (number) -> Profile?): Types.TradeView?
	local i = Trade.SideIndex(t, userId)
	if not i then
		return nil
	end
	local me, them = t.Sides[i], t.Sides[3 - i]
	local at = t.ConfirmAt
	return {
		Id = t.Id,
		Me = sideView(me, profileOf(me.UserId)),
		Them = sideView(them, profileOf(them.UserId)),
		Countdown = if t.Status == "Confirming" and at then math.max(0, math.ceil(at - now)) else nil,
		Status = t.Status,
	}
end

return Trade
