--!nonstrict
-- Lobby: parties (up to 4, invite/accept/leave/kick), ready status (UI toggle
-- or standing in the Ready ring), powerup shop/equip with diamonds, Robux
-- product prompts, and the lobby view pushed to clients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))
local Powerups = require(Shared:WaitForChild("Powerups"))
local ProfileRules = require(Shared:WaitForChild("Logic"):WaitForChild("ProfileRules"))

local LobbyService = {}

export type Party = {
	Id: string,
	Leader: Player,
	Members: { Player },
	Invites: { [number]: number }, -- userId -> expiry (os.clock)
	Queued: boolean,
	QueuedAt: number,
}

local ctx: any
local parties: { [string]: Party } = {}
local partyOf: { [Player]: Party } = {}
local ready: { [Player]: string? } = {} -- "Button" | "Ring"
local counter = 0
local dirty = true

local MAX_PARTY = Config.Match.MaxPerTeam -- solo launch: 1 (parties disabled)

function LobbyService.Init(c)
	ctx = c
	if ctx.Mode ~= "Lobby" then
		return
	end
	ctx.Util.OnPlayerAdded(function(p)
		LobbyService._solo(p)
		dirty = true
	end)
	ctx.Util.OnPlayerRemoving(function(p)
		LobbyService._leaveParty(p, true)
		ready[p] = nil
		dirty = true
	end)
	ctx.Util.Connect("LobbyAction", "Lobby", LobbyService._onAction)
	ctx.ChannelService.OnPrompt("Station", function(p: Player, prompt: ProximityPrompt)
		Net.FireClient("MatchEvent", p, "OpenStation", { Station = prompt:GetAttribute("Station") })
	end)
	ctx.MatchService.On("MatchCleanup", function()
		task.delay(1, function()
			dirty = true
		end)
	end)
end

function LobbyService.Start()
	if ctx.Mode ~= "Lobby" then
		return
	end
	local acc = 0
	while true do
		task.wait(0.5)
		LobbyService._ringCheck()
		acc += 0.5
		if dirty or acc >= 3 then
			acc = 0
			dirty = false
			LobbyService.PushAll()
		end
	end
end

-- Parties ---------------------------------------------------------------------------------------

function LobbyService._solo(p: Player)
	counter += 1
	local party: Party = {
		Id = game.JobId .. "-" .. counter .. "-" .. p.UserId,
		Leader = p,
		Members = { p },
		Invites = {},
		Queued = false,
		QueuedAt = 0,
	}
	parties[party.Id] = party
	partyOf[p] = party
	return party
end

function LobbyService.PartyOf(p: Player): Party?
	return partyOf[p]
end

local function unreadyParty(party: Party)
	for _, m in party.Members do
		ready[m] = nil
	end
	if party.Queued then
		ctx.MatchmakingService.Dequeue(party)
		party.Queued = false
	end
end

function LobbyService._leaveParty(p: Player, leaving: boolean)
	local party = partyOf[p]
	if not party then
		return
	end
	unreadyParty(party)
	local idx = table.find(party.Members, p)
	if idx then
		table.remove(party.Members, idx)
	end
	partyOf[p] = nil
	if #party.Members == 0 then
		parties[party.Id] = nil
	elseif party.Leader == p then
		party.Leader = party.Members[1]
	end
	if not leaving then
		LobbyService._solo(p)
	end
	dirty = true
end

function LobbyService.RemoveFromQueue(party: Party)
	party.Queued = false
	for _, m in party.Members do
		ready[m] = nil
	end
	dirty = true
end

local function canUseLobby(p: Player): boolean
	return not p:GetAttribute("InMatch")
end

function LobbyService._onAction(p: Player, req: any)
	if type(req) ~= "table" or type(req.Action) ~= "string" then
		return
	end
	local a = req.Action
	local party = partyOf[p]
	if not party then
		return
	end
	if a == "Invite" then
		if not ctx.Util.IsInt(req.UserId) or party.Leader ~= p then
			return
		end
		local target = Players:GetPlayerByUserId(req.UserId)
		if not target or target == p or not canUseLobby(target) then
			return
		end
		if #party.Members >= MAX_PARTY then
			ctx.Util.Notify(p, if MAX_PARTY <= 1 then "Matches are solo for now — parties are disabled." else "Your party is full (" .. MAX_PARTY .. ").", "warn")
			return
		end
		party.Invites[target.UserId] = os.clock() + 60
		Net.FireClient("MatchEvent", target, "PartyInvite", { PartyId = party.Id, From = p.DisplayName })
		ctx.Util.Notify(p, "Invite sent to " .. target.DisplayName .. ".", "info")
	elseif a == "Accept" then
		if type(req.PartyId) ~= "string" then
			return
		end
		local target = parties[req.PartyId]
		if not target or target == party then
			return
		end
		local exp = target.Invites[p.UserId]
		if not exp or os.clock() > exp then
			ctx.Util.Notify(p, "That invite expired.", "warn")
			return
		end
		if #target.Members >= MAX_PARTY then
			ctx.Util.Notify(p, "That party is full.", "warn")
			return
		end
		target.Invites[p.UserId] = nil
		LobbyService._leaveParty(p, true)
		unreadyParty(target)
		table.insert(target.Members, p)
		partyOf[p] = target
		for _, m in target.Members do
			ctx.Util.Notify(m, p.DisplayName .. " joined the party.", "success")
		end
	elseif a == "Decline" then
		local target = type(req.PartyId) == "string" and parties[req.PartyId]
		if target then
			target.Invites[p.UserId] = nil
			ctx.Util.Notify(target.Leader, p.DisplayName .. " declined your invite.", "info")
		end
	elseif a == "Leave" then
		if #party.Members > 1 then
			LobbyService._leaveParty(p, false)
		end
	elseif a == "Kick" then
		if party.Leader ~= p or not ctx.Util.IsInt(req.UserId) then
			return
		end
		local target = Players:GetPlayerByUserId(req.UserId)
		if target and target ~= p and partyOf[target] == party then
			LobbyService._leaveParty(target, false)
			ctx.Util.Notify(target, "You were removed from the party.", "info")
		end
	elseif a == "Ready" then
		if not canUseLobby(p) then
			return
		end
		ready[p] = if req.Value == true then "Button" else nil
		LobbyService._checkParty(party)
	elseif a == "Cancel" then
		unreadyParty(party)
	elseif a == "BuyPowerup" or a == "UpgradePowerup" or a == "EquipPowerup" then
		LobbyService._powerupAction(p, a, req.Id)
	elseif a == "BuyRobux" then
		LobbyService._robux(p, req.Key)
	end
	dirty = true
end

function LobbyService._checkParty(party: Party)
	local all = true
	for _, m in party.Members do
		if not ready[m] then
			all = false
		end
	end
	if all and not party.Queued then
		party.Queued = true
		party.QueuedAt = os.clock()
		ctx.MatchmakingService.Enqueue(party)
		for _, m in party.Members do
			ctx.Util.Notify(m, "Searching for a match...", "info")
		end
	elseif not all and party.Queued then
		party.Queued = false
		ctx.MatchmakingService.Dequeue(party)
	end
	dirty = true
end

function LobbyService._ringCheck()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end
	local center = lobby:GetAttribute("ReadyCenter") :: Vector3?
	local radius = lobby:GetAttribute("ReadyRadius") :: number?
	if not center or not radius then
		return
	end
	for _, p in Players:GetPlayers() do
		if canUseLobby(p) and partyOf[p] then
			local root = ctx.Util.Root(p)
			local inside = root ~= nil and Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude <= radius and math.abs(root.Position.Y - center.Y) < 12
			if inside and not ready[p] then
				ready[p] = "Ring"
				LobbyService._checkParty(partyOf[p] :: Party)
			elseif not inside and ready[p] == "Ring" then
				ready[p] = nil
				LobbyService._checkParty(partyOf[p] :: Party)
			end
		end
	end
end

-- Shop --------------------------------------------------------------------------------------

function LobbyService._powerupAction(p: Player, action: string, id: any)
	if not canUseLobby(p) then
		ctx.Util.Notify(p, "Powerups can only be changed in the lobby.", "warn")
		return
	end
	local session = ctx.DataService.Get(p)
	if not session or not ctx.DataService.CanGrant(p) then
		ctx.Util.Notify(p, "Your data isn't loaded — shop unavailable.", "error")
		return
	end
	if id ~= nil and (type(id) ~= "string" or not Powerups.ById[id]) then
		return
	end
	local ok, why
	if action == "BuyPowerup" then
		ok, why = ProfileRules.BuyUnlock(session.Profile, id)
	elseif action == "UpgradePowerup" then
		ok, why = ProfileRules.BuyUpgrade(session.Profile, id)
	else
		ok, why = ProfileRules.Equip(session.Profile, id)
	end
	if ok then
		task.spawn(ctx.DataService.Save, p, false)
		ctx.Util.Notify(p, if action == "EquipPowerup" then (if id then "Equipped " .. id else "Powerup unequipped") else "Done! " .. tostring(id) .. " updated.", "success")
		ctx.Util.PlaySound("UiReady", ctx.Util.Root(p))
	else
		ctx.Util.Notify(p, why or "Can't do that.", "error")
	end
	ctx.DataService.Push(p)
end

function LobbyService._robux(p: Player, key: any)
	if type(key) ~= "string" then
		return
	end
	local product = Products.ByKey[key]
	if not product or not Products.OnSale(key) or not (product.Kind == "Diamonds" or product.Kind == "Unlock" or product.Kind == "Upgrade") then
		return
	end
	local session = ctx.DataService.Get(p)
	if not session or not ctx.DataService.CanGrant(p) then
		ctx.Util.Notify(p, "Your data isn't loaded — purchases are paused to keep them safe.", "error")
		return
	end
	if product.Kind == "Unlock" and session.Profile.Owned[product.Powerup] then
		ctx.Util.Notify(p, "You already own that powerup.", "info")
		return
	end
	if product.Kind == "Upgrade" and (session.Profile.Owned[product.Powerup] or 0) ~= (product.Level :: number) - 1 then
		ctx.Util.Notify(p, "Unlock the previous level first.", "info")
		return
	end
	local ok, why = ctx.PurchaseService.Prompt(p, key, {})
	if not ok then
		ctx.Util.Notify(p, why or "Unavailable", "error")
	end
end

-- View ----------------------------------------------------------------------------------------------

function LobbyService.PushAll()
	local list = {}
	for _, pl in Players:GetPlayers() do
		if canUseLobby(pl) then
			table.insert(list, { UserId = pl.UserId, Name = pl.DisplayName, InParty = partyOf[pl] ~= nil and #(partyOf[pl] :: Party).Members > 1 })
		end
	end
	local queueInfo = ctx.MatchmakingService.Status()
	for _, pl in Players:GetPlayers() do
		local party = partyOf[pl]
		if party and canUseLobby(pl) then
			local members = {}
			for _, m in party.Members do
				table.insert(members, { UserId = m.UserId, Name = m.DisplayName, Ready = ready[m] ~= nil, Leader = party.Leader == m })
			end
			Net.FireClient("LobbySync", pl, {
				PartyId = party.Id,
				Members = members,
				IsLeader = party.Leader == pl,
				Queued = party.Queued,
				QueuedFor = if party.Queued then os.clock() - party.QueuedAt else 0,
				Ready = ready[pl] ~= nil,
				Players = list,
				Queue = queueInfo,
				MinPlayers = if ctx.LocalMatches then Config.Dev.StudioMinPlayers else Config.Match.MinPlayers,
				MaxPlayers = Config.Match.MaxPlayers,
			})
		end
	end
end

function LobbyService.MarkDirty()
	dirty = true
end

return LobbyService
