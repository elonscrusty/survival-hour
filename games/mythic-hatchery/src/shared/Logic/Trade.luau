--!strict
-- Trading as a pure state machine.
--
--   Open --(both ready)--> Confirming --(countdown ends)--> swap -> Done
--     ^                        |
--     +---- any offer change --+         (Cancel at any time -> Cancelled)
--
-- Offers are re-validated at swap time, so a creature that was deleted, locked,
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
type Creature = Schema.Creature

export type Side = { UserId: number, Name: string, Creatures: { string }, Gems: number, Ready: boolean }
export type TradeState = {
	Id: string,
	Sides: { Side },
	Status: string, -- "Open" | "Confirming" | "Done" | "Cancelled"
	ConfirmAt: number?,
}

export type SidePlan = {
	Creatures: { Creature },
	Equipped: { string },
	NextUid: number,
	Gems: number,
	Received: { Creature },
}
export type Plan = { A: SidePlan, B: SidePlan }

local Trade = {}

function Trade.New(id: string, aUserId: number, aName: string, bUserId: number, bName: string): TradeState
	return {
		Id = id,
		Sides = {
			{ UserId = aUserId, Name = aName, Creatures = {}, Gems = 0, Ready = false },
			{ UserId = bUserId, Name = bName, Creatures = {}, Gems = 0, Ready = false },
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

-- Checks that a profile can give these creatures and gems right now.
function Trade.ValidateOffer(p: Profile, uids: any, gems: any): (boolean, string?)
	if type(uids) ~= "table" then
		return false, "Bad creature list"
	end
	local n = #uids
	local count = 0
	for _ in uids do
		count += 1
	end
	if count ~= n then
		return false, "Bad creature list"
	end
	if n > Config.TradeMaxCreatures then
		return false, string.format("At most %d creatures per trade", Config.TradeMaxCreatures)
	end
	if Config.TradeMaxGems <= 0 and gems ~= 0 then
		return false, "Gems can't be traded"
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
			return false, "Bad creature id"
		end
		if seen[uid] then
			return false, "Same creature chosen twice"
		end
		seen[uid] = true
		local creature = Inventory.Find(p, uid)
		if not creature then
			return false, "You don't have that creature"
		end
		if creature.Locked then
			return false, "Locked creatures can't be traded"
		end
		if busy[uid] then
			return false, "Creatures on expeditions can't be traded"
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
	side.Creatures = list
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
		if #a.Creatures == 0 and a.Gems == 0 and #b.Creatures == 0 and b.Gems == 0 then
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

local function planSide(p: Profile, give: { string }, giveGems: number, get: { Creature }, getGems: number): SidePlan
	local drop: { [string]: boolean } = {}
	for _, uid in give do
		drop[uid] = true
	end
	local creatures: { Creature } = {}
	local used: { [string]: boolean } = {}
	for _, creature in p.Creatures do
		if not drop[creature.Uid] then
			table.insert(creatures, creature)
			used[creature.Uid] = true
		end
	end
	local equipped: { string } = {}
	for _, uid in p.Equipped do
		if not drop[uid] then
			table.insert(equipped, uid)
		end
	end
	-- Incoming creatures get fresh uids from the receiver's counter and arrive unlocked.
	local nextUid = p.NextUid
	local received: { Creature } = {}
	for _, src in get do
		local uid
		repeat
			nextUid += 1
			uid = tostring(nextUid)
		until not used[uid]
		used[uid] = true
		local creature = Profile.CopyPet(src)
		creature.Uid = uid
		creature.Locked = false
		creature.Cosmetics = {}
		table.insert(creatures, creature)
		table.insert(received, creature)
	end
	local gems = math.min(Schema.MaxGems, p.Gems - giveGems + getGems)
	return { Creatures = creatures, Equipped = equipped, NextUid = nextUid, Gems = gems, Received = received }
end

local function offeredCreatures(p: Profile, uids: { string }): { Creature }
	local out: { Creature } = {}
	for _, uid in uids do
		local creature = Inventory.Find(p, uid)
		if creature then
			table.insert(out, creature)
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
	local okA, errA = Trade.ValidateOffer(pa, a.Creatures, a.Gems)
	if not okA then
		return nil, a.Name .. ": " .. (errA or "offer changed")
	end
	local okB, errB = Trade.ValidateOffer(pb, b.Creatures, b.Gems)
	if not okB then
		return nil, b.Name .. ": " .. (errB or "offer changed")
	end
	local newCountA = #pa.Creatures - #a.Creatures + #b.Creatures
	if #b.Creatures > #a.Creatures and newCountA > Economy.MaxStorage(pa) then
		return nil, a.Name .. " doesn't have room for those creatures"
	end
	local newCountB = #pb.Creatures - #b.Creatures + #a.Creatures
	if #a.Creatures > #b.Creatures and newCountB > Economy.MaxStorage(pb) then
		return nil, b.Name .. " doesn't have room for those creatures"
	end
	local creaturesA = offeredCreatures(pa, a.Creatures)
	local creaturesB = offeredCreatures(pb, b.Creatures)
	return {
		A = planSide(pa, a.Creatures, a.Gems, creaturesB, b.Gems),
		B = planSide(pb, b.Creatures, b.Gems, creaturesA, a.Gems),
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

export type JournalSide = { Give: { string }, GiveGems: number, Get: { Creature }, GetGems: number }
export type Journal = { Id: string, Sides: { [string]: JournalSide } }

-- Builds the journal for a planned trade (keys are tostring(UserId)).
function Trade.Journal(t: TradeState, plan: Plan): Journal
	local a, b = t.Sides[1], t.Sides[2]
	local function copyList(list: { Creature }): { Creature }
		local out: { Creature } = {}
		for _, creature in list do
			table.insert(out, Profile.CopyPet(creature))
		end
		return out
	end
	return {
		Id = t.Id,
		Sides = {
			[tostring(a.UserId)] = { Give = table.clone(a.Creatures), GiveGems = a.Gems, Get = copyList(plan.A.Received), GetGems = b.Gems },
			[tostring(b.UserId)] = { Give = table.clone(b.Creatures), GiveGems = b.Gems, Get = copyList(plan.B.Received), GetGems = a.Gems },
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
	-- Reuse the profile sanitiser for the creatures (validates ids, variants, levels).
	local tmp = Profile.Sanitize({ Creatures = raw.Get, StarterGranted = true })
 for _, creature in tmp.Creatures do creature.Cosmetics = {} end
	return {
		Give = give,
		GiveGems = Schema.ClampInt(raw.GiveGems, 0, Config.TradeMaxGems),
		Get = tmp.Creatures,
		GetGems = Schema.ClampInt(raw.GetGems, 0, Config.TradeMaxGems),
	}
end

-- Applies one side of a trade to a profile. Returns false (and changes
-- nothing) if this trade was already applied. Received creatures keep their uid
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
	for _, creature in p.Creatures do
		used[creature.Uid] = true
	end
	for _, src in side.Get do
		local creature = Profile.CopyPet(src)
		creature.Locked = false
		creature.Cosmetics = {}
		if used[creature.Uid] or #creature.Uid == 0 or #creature.Uid > Schema.MaxUidLength then
			creature.Uid = Inventory.NewUid(p)
		else
			local n = tonumber(creature.Uid)
			if n and Schema.IsFinite(n) and n > p.NextUid then
				p.NextUid = math.min(math.floor(n), 1e15)
			end
		end
		used[creature.Uid] = true
		table.insert(p.Creatures, creature)
		p.Index[creature.Species .. "|" .. creature.Element] = true
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
	local creatures: { Creature } = {}
	if p then
		for _, uid in s.Creatures do
			local creature = Inventory.Find(p, uid)
			if creature then
				table.insert(creatures, Profile.CopyPet(creature))
			end
		end
	end
	return { UserId = s.UserId, Name = s.Name, Creatures = creatures, Gems = s.Gems, Ready = s.Ready, Vip = false }
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
		MaxCreatures = Config.TradeMaxCreatures,
		Me = sideView(me, profileOf(me.UserId)),
		Them = sideView(them, profileOf(them.UserId)),
		Countdown = if t.Status == "Confirming" and at then math.max(0, math.ceil(at - now)) else nil,
		Status = t.Status,
	}
end

return Trade
