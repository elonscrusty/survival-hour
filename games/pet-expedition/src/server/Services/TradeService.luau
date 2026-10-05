--!nonstrict
-- Player-to-player trading.
--   Request -> target accepts -> both edit offers -> both ready ->
--   Config.TradeConfirmSeconds countdown -> journaled swap.
-- Any offer change un-readies both sides. Trades need PolicyService's
-- IsPaidItemTradingAllowed for both players, accounts at least
-- Config.TradeMinAccountAgeDays old (skipped in Studio), and a cooldown
-- between requests. Leaving before the swap starts cancels the trade.
--
-- The swap can't duplicate items even if the server dies half-way:
--   1. both profiles get PendingTrade = id and must save successfully
--      (otherwise the trade is cancelled and nothing happened);
--   2. the journal (both sides' changes) is written under its own key
--      (if that can't be confirmed, both keep PendingTrade and the trade is
--      settled from the journal - or dropped - on their next join);
--   3. both sides are applied in memory (Logic/Trade.ApplySide) and saved,
--      retrying; the journal is removed once both saves succeeded.
-- A profile that loads with PendingTrade set replays its side (DataService).
-- While a swap runs, both players' remotes are refused (session.TradeBusy).
-- Pure rules: Logic/Trade.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Logic = Shared:WaitForChild("Logic")
local Trade = require(Logic:WaitForChild("Trade"))

local TradeService = {}

local ctx: any
local trades: { [Player]: Trade.TradeState } = {}
-- pending[target][fromUserId] = os.clock() when the request expires
local pending: { [Player]: { [number]: number } } = {}
local lastRequest: { [Player]: number } = {}
local lastCountdown: { [string]: number } = {}
local executing: { [Trade.TradeState]: boolean } = {}

local TICK = 0.25

local function profileOf(userId: number)
	local p = Players:GetPlayerByUserId(userId)
	local s = p and ctx.DataService.Get(p)
	return s and s.Profile
end

local function sendView(player: Player, t: Trade.TradeState?)
	if player.Parent == nil then
		return
	end
	local view = if t then Trade.View(t, player.UserId, os.clock(), profileOf) else nil
	Net.Event("Trade"):FireClient(player, view)
end

local function playersOf(t: Trade.TradeState): { Player }
	local out = {}
	for p, tt in trades do
		if tt == t then
			table.insert(out, p)
		end
	end
	return out
end

local function pushBoth(t: Trade.TradeState)
	for _, p in playersOf(t) do
		sendView(p, t)
	end
end

local function close(t: Trade.TradeState, message: string?, tone: string?)
	lastCountdown[t.Id] = nil
	for _, p in playersOf(t) do
		trades[p] = nil
		sendView(p, t) -- final status (Done / Cancelled)
		sendView(p, nil)
		if message then
			ctx.Util.Toast(p, message, tone)
		end
	end
end

-- Why a player can't trade right now, or nil.
local function blockedReason(player: Player, s): string?
	if not s then
		return "still loading"
	end
	if not s.CanTrade then
		return "trading isn't available for this account"
	end
	if ctx.DataService.ReadOnly(s) then
		return "data didn't load, so trading is off"
	end
	if s.TradeBusy or s.Profile.PendingTrade ~= nil then
		return "a previous trade is still being saved - try again after rejoining"
	end
	if not RunService:IsStudio() and player.AccountAge < Config.TradeMinAccountAgeDays then
		return string.format("accounts must be %d days old to trade", Config.TradeMinAccountAgeDays)
	end
	return nil
end

function TradeService.Init(c)
	ctx = c
	local U = ctx.Util

	U.OnPlayerRemoving(function(p)
		local t = trades[p]
		if t and executing[t] then
			-- The swap is already running; it finishes (or is settled from the
			-- journal on next join). close() tidies up the mapping.
			t = nil
		end
		if t then
			Trade.Cancel(t)
			close(t, p.DisplayName .. " left, trade cancelled", "bad")
			trades[p] = nil
		end
		pending[p] = nil
		lastRequest[p] = nil
		for _, list in pending do
			list[p.UserId] = nil
		end
	end, true)

	U.Function("TradeRequest", function(player, s, targetUserId)
		if not U.IsInt(targetUserId) then
			return U.Fail("Unknown player")
		end
		if targetUserId == player.UserId then
			return U.Fail("You can't trade with yourself")
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then
			return U.Fail("That player isn't in this server")
		end
		local why = blockedReason(player, s)
		if why then
			return U.Fail("You can't trade: " .. why)
		end
		local ts = ctx.DataService.Get(target)
		local whyTarget = blockedReason(target, ts)
		if whyTarget then
			return U.Fail(target.DisplayName .. " can't trade: " .. whyTarget)
		end
		if trades[player] then
			return U.Fail("Finish your current trade first")
		end
		if trades[target] then
			return U.Fail(target.DisplayName .. " is already trading")
		end
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < Config.TradeCooldown then
			return U.Fail("Wait a few seconds before sending another request")
		end
		lastRequest[player] = now
		pending[target] = pending[target] or {}
		pending[target][player.UserId] = now + Config.TradeRequestTimeout
		U.Notify(target, "TradeRequest", { FromUserId = player.UserId, FromName = player.DisplayName })
		return { ok = true }
	end)

	U.Function("TradeRespond", function(player, s, fromUserId, accept)
		if not U.IsInt(fromUserId) or not U.IsBool(accept) then
			return U.Fail("Bad request")
		end
		local list = pending[player]
		local expires = list and list[fromUserId]
		if list then
			list[fromUserId] = nil
		end
		if not expires or os.clock() > expires then
			return U.Fail("That request expired")
		end
		local from = Players:GetPlayerByUserId(fromUserId)
		if not from then
			return U.Fail("That player left")
		end
		if not accept then
			U.Toast(from, player.DisplayName .. " declined your trade", "info")
			return { ok = true }
		end
		local why = blockedReason(player, s)
		if why then
			return U.Fail("You can't trade: " .. why)
		end
		local fs = ctx.DataService.Get(from)
		local whyFrom = blockedReason(from, fs)
		if whyFrom then
			return U.Fail(from.DisplayName .. " can't trade: " .. whyFrom)
		end
		if trades[player] or trades[from] then
			return U.Fail("One of you is already trading")
		end
		local t = Trade.New(HttpService:GenerateGUID(false), from.UserId, from.DisplayName, player.UserId, player.DisplayName)
		trades[from] = t
		trades[player] = t
		pushBoth(t)
		return { ok = true }
	end)

	U.Function("TradeSetOffer", function(player, s, uids, gems)
		local t = trades[player]
		if not t then
			return U.Fail("You're not trading")
		end
		if type(uids) ~= "table" or #uids > Config.TradeMaxPets then
			return U.Fail(string.format("At most %d pets per trade", Config.TradeMaxPets))
		end
		local ok, err = Trade.SetOffer(t, player.UserId, s.Profile, uids, gems)
		if not ok then
			return U.Fail(err or "Can't offer that")
		end
		lastCountdown[t.Id] = nil
		pushBoth(t)
		return { ok = true }
	end)

	U.Function("TradeReady", function(player, s, ready)
		local t = trades[player]
		if not t then
			return U.Fail("You're not trading")
		end
		if not U.IsBool(ready) then
			return U.Fail("Bad request")
		end
		if ready then
			-- Re-check this side's offer now so problems show before the countdown.
			local i = Trade.SideIndex(t, player.UserId)
			local side = i and t.Sides[i]
			if side then
				local ok, err = Trade.ValidateOffer(s.Profile, side.Pets, side.Gems)
				if not ok then
					return U.Fail(err or "Your offer changed")
				end
			end
		end
		local ok, err = Trade.SetReady(t, player.UserId, ready, os.clock())
		if not ok then
			return U.Fail(err or "Can't do that")
		end
		pushBoth(t)
		return { ok = true }
	end)

	U.Function("TradeCancel", function(player)
		local t = trades[player]
		if not t then
			return { ok = true }
		end
		Trade.Cancel(t)
		close(t, player.DisplayName .. " cancelled the trade", "info")
		return { ok = true }
	end)
end

function TradeService.Start()
	while true do
		task.wait(TICK)
		local seen: { [Trade.TradeState]: boolean } = {}
		for _, t in trades do
			if seen[t] or executing[t] then
				continue
			end
			seen[t] = true
			local ok, err = pcall(TradeService._tickTrade, t)
			if not ok then
				warn("[TradeService] tick error:", err)
				Trade.Cancel(t)
				close(t, "Trade cancelled (server error)", "bad")
			end
		end
		-- Drop expired requests.
		local now = os.clock()
		for _, list in pending do
			for from, expires in list do
				if now > expires then
					list[from] = nil
				end
			end
		end
	end
end

function TradeService._tickTrade(t: Trade.TradeState)
	if t.Status ~= "Confirming" then
		return
	end
	local now = os.clock()
	if not Trade.Due(t, now) then
		local left = math.ceil((t.ConfirmAt or now) - now)
		if lastCountdown[t.Id] ~= left then
			lastCountdown[t.Id] = left
			pushBoth(t)
		end
		return
	end
	-- The swap yields (saves), so it runs on its own thread; the tick skips it.
	executing[t] = true
	task.spawn(function()
		local ok, err = pcall(TradeService._execute, t)
		executing[t] = nil
		if not ok then
			warn("[TradeService] execute error:", err)
			Trade.Cancel(t)
			close(t, "Trade cancelled", "bad")
		end
	end)
end

function TradeService._execute(t: Trade.TradeState)
	local pa = Players:GetPlayerByUserId(t.Sides[1].UserId)
	local pb = Players:GetPlayerByUserId(t.Sides[2].UserId)
	local sa = pa and ctx.DataService.Get(pa)
	local sb = pb and ctx.DataService.Get(pb)
	if not sa or not sb or trades[pa] ~= t or trades[pb] ~= t
		or blockedReason(pa, sa) or blockedReason(pb, sb) then
		Trade.Cancel(t)
		close(t, "Trade cancelled", "bad")
		return
	end
	local plan, err = Trade.Plan(t, sa.Profile, sb.Profile)
	if not plan then
		Trade.Cancel(t)
		close(t, "Trade cancelled: " .. (err or "something changed"), "bad")
		return
	end
	sa.TradeBusy = true
	sb.TradeBusy = true
	local ok, result = pcall(TradeService._swap, t, pa, pb, sa, sb)
	sa.TradeBusy = false
	sb.TradeBusy = false
	if not ok then
		warn("[TradeService] swap error:", result)
	end
	if t.Status ~= "Done" then
		Trade.Cancel(t)
		close(t, if ok and type(result) == "string" then result else "Trade cancelled", "bad")
	end
end

-- Steps 1-3 of the journaled swap. Returns a message when the trade did not
-- happen (the caller cancels), nil when it is Done.
function TradeService._swap(t: Trade.TradeState, pa: Player, pb: Player, sa, sb): string?
	local D = ctx.DataService
	local id = t.Id
	local function clearPending()
		for _, s in { sa, sb } do
			if s.Profile.PendingTrade == id then
				s.Profile.PendingTrade = nil
				D.Touch(s)
				task.spawn(D.SaveSession, s)
			end
		end
	end

	-- 1. Mark both profiles and make sure the marks are stored.
	sa.Profile.PendingTrade = id
	sb.Profile.PendingTrade = id
	D.Touch(sa)
	D.Touch(sb)
	local saved = D.SaveSession(sa) and D.SaveSession(sb)
	if not saved then
		clearPending()
		return "Trade cancelled: couldn't save, nothing was exchanged"
	end

	-- Offers can't have changed (remotes were blocked), but check again.
	local plan, err = Trade.Plan(t, sa.Profile, sb.Profile)
	if not plan then
		clearPending()
		return "Trade cancelled: " .. (err or "something changed")
	end

	-- 2. Journal.
	local journal = Trade.Journal(t, plan)
	if D.WriteJournal(id, journal) ~= "written" then
		-- Unknown outcome: both keep PendingTrade (already saved), so their next
		-- join settles it the same way for both. Trading stays off until then.
		return "Trade couldn't be confirmed. It will be settled when you rejoin."
	end

	-- 3. Apply both sides and save.
	local newFor = {}
	for i in t.Sides do
		local receiver = if i == 1 then sb.Profile else sa.Profile
		local list = {}
		for _, pet in journal.Sides[tostring(t.Sides[3 - i].UserId)].Get do
			if not receiver.Index[pet.Id] then
				list[pet.Id] = true
			end
		end
		newFor[3 - i] = list
	end
	Trade.ApplySide(sa.Profile, journal.Sides[tostring(t.Sides[1].UserId)], id)
	Trade.ApplySide(sb.Profile, journal.Sides[tostring(t.Sides[2].UserId)], id)
	t.Status = "Done"
	t.ConfirmAt = nil
	D.Touch(sa)
	D.Touch(sb)
	for i, p in { pa, pb } do
		if p.Parent ~= nil then
			for petId in newFor[i] do
				ctx.RewardService.Discovered(p, petId)
			end
			ctx.StateService.Dirty(p)
		end
	end
	close(t, "Trade complete!", "good")
	task.spawn(TradeService._saveAfter, id, sa, sb)
	return nil
end

-- Saves both sides until stored; removes the journal once both are.
function TradeService._saveAfter(id: string, sa, sb)
	local D = ctx.DataService
	local doneA, doneB = false, false
	for attempt = 1, 8 do
		doneA = doneA or D.SaveSession(sa)
		doneB = doneB or D.SaveSession(sb)
		if doneA and doneB then
			D.RemoveJournal(id)
			return
		end
		-- A side that left before its final save replays from the journal on
		-- its next join, so the journal must stay.
		if (not doneA and (sa.Closed or sa.LockLost)) or (not doneB and (sb.Closed or sb.LockLost)) then
			return
		end
		task.wait(math.min(2 ^ attempt, 30))
	end
	warn("[TradeService] trade", id, "saved only partly; the journal settles it on next join")
end

-- uids the player currently offers in an open trade (blocked from delete,
-- craft and expeditions).
function TradeService.OfferedSet(player: Player): { [string]: boolean }
	local set = {}
	local t = trades[player]
	if t and Trade.IsActive(t) then
		local i = Trade.SideIndex(t, player.UserId)
		if i then
			for _, uid in t.Sides[i].Pets do
				set[uid] = true
			end
		end
	end
	return set
end

-- Sends the current trade window (or nil) to one player.
function TradeService.PushView(player: Player)
	sendView(player, trades[player])
end

return TradeService
