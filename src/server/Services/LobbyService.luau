--!nonstrict
-- Lobby: parties (up to 4, invite/accept/leave/kick), ready status (UI toggle
-- or standing in the Ready ring), classes / power-ups (Diamonds), cosmetics
-- (Coins), daily / weekly bonuses, emotes, Robux Coin packs, and the lobby
-- view pushed to clients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))
local ProfileRules = require(Shared:WaitForChild("Logic"):WaitForChild("ProfileRules"))
local Challenges = require(Shared:WaitForChild("Logic"):WaitForChild("Challenges"))
local Progression = require(Shared:WaitForChild("Progression"))

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
		-- PLAY AGAIN from the last match: straight back into the queue
		local join = p:GetJoinData()
		local td = join and join.TeleportData
		if type(td) == "table" and td.AutoReady == true then
			task.delay(4, function()
				LobbyService.AutoReady(p)
			end)
		end
		-- Stream the lobby around its fire (not the character) while in the lobby: the
		-- title screen shows the refuge before any character exists.
		local focus
		function focus()
			local lobby = workspace:FindFirstChild("Lobby")
			local fire = lobby and lobby:FindFirstChild("LobbyFire")
			local part = fire and (fire:IsA("Model") and fire.PrimaryPart or fire:FindFirstChildWhichIsA("BasePart", true))
			p.ReplicationFocus = if p:GetAttribute("InMatch") then nil else part
			if not part and not p:GetAttribute("InMatch") and p.Parent then
				task.delay(1, focus) -- lobby still being built
			end
		end
		focus()
		p:GetAttributeChangedSignal("InMatch"):Connect(focus)
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
	local afkAcc = 0
	while true do
		task.wait(0.5)
		LobbyService._ringCheck()
		afkAcc += 0.5
		if afkAcc >= 5 then
			afkAcc = 0
			pcall(LobbyService._afkTick)
		end
		acc += 0.5
		if dirty or acc >= 3 then
			acc = 0
			dirty = false
			LobbyService.PushAll()
			LobbyService._board()
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
	elseif a == "BuyClass" or a == "EquipClass" or a == "BuyPerk" or a == "EquipPerk" or a == "BuyCosmetic" or a == "WearCosmetic" or a == "ClaimDaily" or a == "ClaimWeekly" or a == "ClaimChallenge" then
		LobbyService._profileAction(p, a, req)
	elseif a == "Emote" then
		if canUseLobby(p) and type(req.Id) == "string" then
			ctx.CosmeticService.Emote(p, req.Id)
		end
	elseif a == "BuyRobux" then
		LobbyService._robux(p, req.Key)
	end
	dirty = true
end

-- Readies a player who asked to play again (waits for their profile and character).
function LobbyService.AutoReady(p: Player)
	for _ = 1, 30 do
		if not p.Parent then
			return
		end
		if canUseLobby(p) and ctx.DataService.Get(p) and ctx.Util.Root(p) then
			local party = partyOf[p]
			if party and not ready[p] then
				ready[p] = "Button"
				ctx.Util.LastActive[p] = os.clock()
				LobbyService._checkParty(party)
				ctx.Util.Notify(p, "Back in the queue for another match. Press CANCEL to stay in the Refuge.", "success")
			end
			return
		end
		task.wait(1)
	end
end

-- AFK in the lobby: a readied-up player who stops moving is un-readied (never kicked).
function LobbyService._afkTick()
	local now = os.clock()
	for p, how in ready do
		local last = ctx.Util.LastActive[p]
		local party = partyOf[p]
		-- (standing in the ready ring is a deliberate choice; only button-readies time out)
		if how == "Button" and last and now - last >= Config.Afk.LobbyUnreadyAfter and party then
			ready[p] = nil
			LobbyService._checkParty(party)
			ctx.Util.Notify(p, "You were un-readied for being away. Ready up again when you're back.", "warn")
		end
	end
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

local ACTION_FN = {
	BuyClass = ProfileRules.BuyClass,
	EquipClass = ProfileRules.EquipClass,
	BuyPerk = ProfileRules.BuyPerk,
	EquipPerk = ProfileRules.EquipPerk,
	BuyCosmetic = ProfileRules.BuyCosmetic,
}

local ACTION_DONE = {
	BuyClass = "Class unlocked!",
	EquipClass = "Class equipped for your next match.",
	BuyPerk = "Power-up unlocked!",
	EquipPerk = "Power-up set for your next match.",
	BuyCosmetic = "Cosmetic unlocked!",
	WearCosmetic = "Cosmetic updated.",
}

function LobbyService._profileAction(p: Player, action: string, req: any)
	if not canUseLobby(p) then
		ctx.Util.Notify(p, "Classes, power-ups and cosmetics can only be changed in the lobby.", "warn")
		return
	end
	local session = ctx.DataService.Get(p)
	if not session or not ctx.DataService.CanGrant(p) then
		ctx.Util.Notify(p, "Your data isn't loaded — shop unavailable.", "error")
		return
	end
	local profile = session.Profile
	local id = req.Id
	if id ~= nil and type(id) ~= "string" then
		return
	end
	local ok, why = false, nil
	local note: string? = nil
	if action == "ClaimDaily" then
		local coins = ProfileRules.ClaimDaily(profile, os.time())
		ok, why = coins > 0, "Already claimed today."
		note = "Daily bonus: +" .. coins .. " Coins"
	elseif action == "ClaimWeekly" then
		local coins = ProfileRules.ClaimWeekly(profile, os.time())
		ok, why = coins > 0, "Play more matches this week first."
		note = "Weekly bonus: +" .. coins .. " Coins"
	elseif action == "ClaimChallenge" then
		if type(id) ~= "string" then
			return
		end
		Challenges.Refresh(profile.Challenges, profile, Progression.DayNumber(os.time()), Progression.WeekNumber(os.time()))
		local coins = Challenges.Claim(profile.Challenges, profile, id)
		if coins > 0 then
			ProfileRules.AddCoins(profile, coins)
		end
		ok, why = coins > 0, "Finish the challenge first."
		note = "Challenge complete: +" .. coins .. " Coins"
	elseif action == "WearCosmetic" then
		if type(req.Type) ~= "string" then
			return
		end
		ok, why = ProfileRules.WearCosmetic(profile, req.Type, id)
	elseif action == "EquipPerk" then
		ok, why = ProfileRules.EquipPerk(profile, id)
	elseif id then
		ok, why = ACTION_FN[action](profile, id)
	end
	if ok then
		task.spawn(ctx.DataService.Save, p, false)
		ctx.Util.Notify(p, note or ACTION_DONE[action] or "Done!", "success")
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
	if not product or not Products.OnSale(key) or not (product.Kind == "Coins" or product.Kind == "Bundle") then
		return
	end
	local session = ctx.DataService.Get(p)
	if not session or not ctx.DataService.CanGrant(p) then
		ctx.Util.Notify(p, "Your data isn't loaded — purchases are paused to keep them safe.", "error")
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
				Boards = ctx.DataService.Boards(),
			})
		end
	end
end

-- Hall of Fame board in the lobby (top 5 wins + top 5 levels).
local lastBoard = ""
function LobbyService._board()
	local boards = ctx.DataService.Boards()
	local lines = { "HALL OF FAME" }
	for _, spec in { { "Wins", "Most wins" }, { "XP", "Most XP" } } do
		table.insert(lines, "— " .. spec[2] .. " —")
		local list = boards[spec[1]] or {}
		if #list == 0 then
			table.insert(lines, "(live servers only)")
		end
		for i = 1, math.min(5, #list) do
			table.insert(lines, string.format("%d. %s  %d", i, list[i].Name, list[i].Value))
		end
	end
	local text = table.concat(lines, "\n")
	if text ~= lastBoard then
		lastBoard = text
		ctx.WorldService.SetLobbyBoard(lines)
	end
end

function LobbyService.MarkDirty()
	dirty = true
end

return LobbyService
