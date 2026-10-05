--!nonstrict
-- Sends each player their PlayerState snapshot (coalesced to ~5 per second),
-- keeps the replicated player attributes (Pets / Vip) and leaderstats in sync,
-- and owns the per-player flags that come from Roblox services: Premium,
-- group membership and PolicyService rules. Also handles SetSetting and
-- ClientReady.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Logic = Shared:WaitForChild("Logic")
local Profile = require(Logic:WaitForChild("Profile"))
local Economy = require(Logic:WaitForChild("Economy"))
local Inventory = require(Logic:WaitForChild("Inventory"))
local Rewards = require(Logic:WaitForChild("Rewards"))

local StateService = {}

local ctx: any
local dirty: { [Player]: boolean } = {}
local PUSH_INTERVAL = 0.2

function StateService.Init(c)
	ctx = c
	ctx.DataService.OnLoaded(StateService._onLoaded)
	ctx.Util.OnPlayerRemoving(function(p)
		dirty[p] = nil
	end)
	Players.PlayerMembershipChanged:Connect(function(p)
		local s = ctx.DataService.Get(p)
		if s then
			s.Premium = p.MembershipType == Enum.MembershipType.Premium
			StateService.Dirty(p)
		end
	end)

	ctx.Util.Event("ClientReady", function(player)
		StateService.Push(player)
		ctx.TradeService.PushView(player)
	end)

	ctx.Util.Function("SetSetting", function(player, s, key, value)
		local ok, err = Profile.SetSetting(s.Profile, key, value)
		if not ok then
			return ctx.Util.Fail(err or "Bad setting")
		end
		if key == "AutoFarm" and value == false then
			ctx.BreakableService.ClearTarget(player)
		end
		StateService.Dirty(player)
		return { ok = true }
	end)
end

function StateService.Start()
	task.spawn(function()
		while true do
			task.wait(PUSH_INTERVAL)
			local list = dirty
			dirty = {}
			for p in list do
				if p.Parent ~= nil then
					local ok, err = pcall(StateService.Push, p)
					if not ok then
						warn("[StateService] push failed:", err)
					end
				end
			end
		end
	end)
	-- Housekeeping once a minute: playtime minutes, expired boosts, new quest day.
	while true do
		task.wait(60)
		local now = os.time()
		for p, s in ctx.DataService.All() do
			if s.Ready and not s.Released then
				Economy.PruneBoosts(s.Profile, now)
				Rewards.EnsureQuests(s.Profile, Rewards.DayNumber(now))
				StateService.Dirty(p)
			end
		end
	end
end

local function fetchPolicy(player: Player, s)
	for attempt = 1, 3 do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(info) == "table" then
			s.CanBuyGemEggs = info.ArePaidRandomItemsRestricted ~= true
			s.CanTrade = info.IsPaidItemTradingAllowed ~= false
			s.PolicyKnown = true
			return
		end
		task.wait(attempt)
	end
	if ctx.IsStudio then
		-- Studio test players (negative UserIds) may not get an answer; allow
		-- everything so every flow can be tested.
		s.CanBuyGemEggs = true
		s.CanTrade = true
		s.PolicyKnown = true
		return
	end
	-- Unknown policy: stay on the safe side for paid random items and trading.
	s.CanBuyGemEggs = false
	s.CanTrade = false
	s.PolicyKnown = true
	warn("[StateService] PolicyService failed for", player.UserId, "- gem eggs and trading disabled")
end

function StateService._onLoaded(player: Player, s)
	s.Premium = player.MembershipType == Enum.MembershipType.Premium
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player
	s.Leaderstats = { Coins = coins, Rebirths = rebirths }
	Rewards.EnsureQuests(s.Profile, Rewards.DayNumber(os.time()))
	StateService.Push(player)
	-- Slow lookups after the first push so the player isn't kept waiting.
	task.spawn(function()
		fetchPolicy(player, s)
		if Config.GroupId ~= 0 then
			local ok, inGroup = pcall(function()
				return player:IsInGroup(Config.GroupId)
			end)
			s.InGroup = ok and inGroup == true
		end
		StateService.Dirty(player)
	end)
end

-- Coin / luck multiplier inputs for a session right now.
function StateService.MultContext(s): Economy.MultContext
	return {
		Now = os.time(),
		Premium = s.Premium,
		InGroup = s.InGroup,
		ServerLuckUntil = ctx.BoostService.ServerLuckUntil(),
		NoPaidLuck = StateService.PaidRandomRestricted(s),
	}
end

-- True while paid random items are (or may be) restricted for this player:
-- PolicyService said so, failed, or hasn't answered yet. Such players can't
-- buy luck products, and paid luck (Lucky pass, Luck boost, server luck)
-- doesn't apply to their hatches.
function StateService.PaidRandomRestricted(s): boolean
	return s.CanBuyGemEggs ~= true
end

function StateService.CoinMult(s): number
	return Economy.CoinMult(s.Profile, StateService.MultContext(s))
end

function StateService.LuckMult(s): number
	return Economy.LuckMult(s.Profile, StateService.MultContext(s))
end

-- Marks a player's state as changed; it is sent within PUSH_INTERVAL. Also
-- bumps the profile's change counter so the next save counts it.
function StateService.Dirty(player: Player)
	dirty[player] = true
	ctx.DataService.Touch(ctx.DataService.Get(player))
end

function StateService.DirtyAll()
	for _, p in Players:GetPlayers() do
		dirty[p] = true
	end
end

local function syncReplicated(player: Player, s)
	local p = s.Profile
	local list = {}
	for _, pet in Inventory.EquippedPets(p) do
		table.insert(list, { Uid = pet.Uid, Id = pet.Id, Variant = pet.Variant, Shiny = pet.Shiny })
	end
	local json = HttpService:JSONEncode(list)
	if player:GetAttribute("Pets") ~= json then
		player:SetAttribute("Pets", json)
	end
	local vip = p.Passes.VIP == true
	if player:GetAttribute("Vip") ~= vip then
		player:SetAttribute("Vip", vip)
	end
	if player:GetAttribute("Target") == nil then
		player:SetAttribute("Target", "")
	end
	local ls = s.Leaderstats
	if ls then
		ls.Coins.Value = math.clamp(math.floor(p.Coins), 0, 2 ^ 53)
		ls.Rebirths.Value = p.Rebirths
	end
end

-- Sends the snapshot now.
function StateService.Push(player: Player)
	local s = ctx.DataService.Get(player)
	if not s or player.Parent == nil then
		return
	end
	dirty[player] = nil
	syncReplicated(player, s)
	local state = Profile.BuildState(s.Profile, {
		Now = os.time(),
		Premium = s.Premium,
		InGroup = s.InGroup,
		ServerLuckUntil = ctx.BoostService.ServerLuckUntil(),
		NoPaidLuck = StateService.PaidRandomRestricted(s),
		CanBuyGemEggs = s.CanBuyGemEggs,
		CanTrade = s.CanTrade,
	})
	Net.Event("State"):FireClient(player, state)
end

return StateService
