--!nonstrict
-- Player-to-player trading.
--   Request -> target accepts -> both edit offers -> both ready ->
--   Config.TradeConfirmSeconds countdown -> atomic swap -> both profiles saved.
-- Any offer change un-readies both sides. Trades need PolicyService's
-- IsPaidItemTradingAllowed for both players, accounts at least
-- Config.TradeMinAccountAgeDays old (skipped in Studio), and a cooldown
-- between requests. Leaving cancels the trade. Pure rules: Logic/Trade.

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

local function pushBoth(t: Trade.TradeState)
	for _, side in t.Sides do
		local p = Players:GetPlayerByUserId(side.UserId)
		if p and trades[p] == t then
			sendView(p, t)
		end
	end
end

local function close(t: Trade.TradeState, message: string?, tone: string?)
	lastCountdown[t.Id] = nil
	for _, side in t.Sides do
		local p = Players:GetPlayerByUserId(side.UserId)
		if p and trades[p] == t then
			trades[p] = nil
			sendView(p, t) -- final status (Done / Cancelled)
			sendView(p, nil)
			if message then
				ctx.Util.Toast(p, message, tone)
			end
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
	if s.State == "Failed" or s.LockLost then
		return "data didn't load, so trading is off"
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
			if seen[t] then
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
	TradeService._execute(t)
end

function TradeService._execute(t: Trade.TradeState)
	local pa = Players:GetPlayerByUserId(t.Sides[1].UserId)
	local pb = Players:GetPlayerByUserId(t.Sides[2].UserId)
	local sa = pa and ctx.DataService.Get(pa)
	local sb = pb and ctx.DataService.Get(pb)
	if not sa or not sb or trades[pa] ~= t or trades[pb] ~= t then
		Trade.Cancel(t)
		close(t, "Trade cancelled", "bad")
		return
	end
	if blockedReason(pa, sa) or blockedReason(pb, sb) then
		Trade.Cancel(t)
		close(t, "Trade cancelled", "bad")
		return
	end
	-- Species each side doesn't have yet (for Discovered notifications).
	local newFor = {}
	for i, side in t.Sides do
		local receiver = if i == 1 then sb.Profile else sa.Profile
		local giver = if i == 1 then sa.Profile else sb.Profile
		local list = {}
		for _, uid in side.Pets do
			for _, pet in giver.Pets do
				if pet.Uid == uid and not receiver.Index[pet.Id] then
					list[pet.Id] = true
				end
			end
		end
		newFor[3 - i] = list
	end
	local plan, err = Trade.Execute(t, sa.Profile, sb.Profile)
	if not plan then
		Trade.Cancel(t)
		close(t, "Trade cancelled: " .. (err or "something changed"), "bad")
		return
	end
	for i, p in { pa, pb } do
		for id in newFor[i] do
			ctx.RewardService.Discovered(p, id)
		end
		ctx.StateService.Dirty(p)
	end
	close(t, "Trade complete!", "good")
	-- Save both right away so a crash can't undo half of the trade.
	task.spawn(ctx.DataService.SaveNow, pa)
	task.spawn(ctx.DataService.SaveNow, pb)
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
