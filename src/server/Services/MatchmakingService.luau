--!nonstrict
-- Matchmaking.
--
-- LIVE (published place, lobby servers):
--   * Each ready party is written to a MemoryStore sorted map (sort key = queue
--     time, so older parties come first) and refreshed while waiting.
--   * One lobby server at a time holds a short matchmaker lease. It reads the
--     queue, packs parties into 4 teams with TeamAssignment.Select (parties are
--     never split; impossible compositions stay queued), reserves a server, and
--     writes a manifest (keyed by PrivateServerId) plus a per-party assignment.
--   * Every lobby server polls assignments for its own parties and teleports them.
--   * The match server reads the manifest; teleport data is never trusted.
--
-- STUDIO (Config.Dev.StudioLocalMatches): an in-process queue that starts the
-- match inside the same server, with relaxed minimums for solo testing.

local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TeamAssignment = require(Shared:WaitForChild("Logic"):WaitForChild("TeamAssignment"))

local MatchmakingService = {}

local ctx: any
local localQueue: { any } = {} -- LobbyService parties
local lastRefresh: { [string]: number } = {}
local status = { Searching = 0, Mode = "Local" }
local queueMap: MemoryStoreSortedMap? = nil
local assignMap: MemoryStoreSortedMap? = nil
local manifestMap: MemoryStoreSortedMap? = nil
local lockMap: MemoryStoreSortedMap? = nil
local teleporting: { [string]: boolean } = {}

local function live(): boolean
	return ctx.Mode == "Lobby" and not ctx.LocalMatches
end

function MatchmakingService.Init(c)
	ctx = c
	local ok, err = pcall(function()
		queueMap = MemoryStoreService:GetSortedMap(Config.Matchmaking.QueueMapName)
		assignMap = MemoryStoreService:GetSortedMap(Config.Matchmaking.AssignMapName)
		manifestMap = MemoryStoreService:GetSortedMap(Config.Matchmaking.ManifestMapName)
		lockMap = MemoryStoreService:GetSortedMap(Config.Matchmaking.LockKey)
	end)
	if not ok then
		warn("[Matchmaking] MemoryStore unavailable:", err)
	end
	status.Mode = if ctx.LocalMatches then "Local" else "Live"
	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
		warn("[Matchmaking] teleport failed for", player.Name, result, message)
		ctx.Util.Notify(player, "Couldn't join the match (" .. tostring(message) .. "). Please ready up again.", "error")
		local party = ctx.LobbyService.PartyOf(player)
		if party then
			teleporting[party.Id] = nil
			party.Queued = false
			ctx.LobbyService.RemoveFromQueue(party)
		end
	end)
end

function MatchmakingService.Start()
	if ctx.Mode ~= "Lobby" then
		return
	end
	while true do
		task.wait(Config.Matchmaking.PollInterval)
		local ok, err = pcall(function()
			if live() then
				MatchmakingService._liveTick()
			else
				MatchmakingService._localTick()
			end
		end)
		if not ok then
			warn("[Matchmaking] tick error:", err)
		end
	end
end

function MatchmakingService.Status()
	return status
end

local function partyEntry(party: any)
	local members = {}
	for _, m in party.Members do
		table.insert(members, m.UserId)
	end
	return { Id = party.Id, Members = members, Size = #members, Job = game.JobId }
end

function MatchmakingService.Enqueue(party: any)
	if not table.find(localQueue, party) then
		table.insert(localQueue, party)
	end
	lastRefresh[party.Id] = 0
end

function MatchmakingService.Dequeue(party: any)
	local idx = table.find(localQueue, party)
	if idx then
		table.remove(localQueue, idx)
	end
	lastRefresh[party.Id] = nil
	if live() and queueMap then
		task.spawn(function()
			pcall(function()
				(queueMap :: MemoryStoreSortedMap):RemoveAsync(party.Id)
			end)
		end)
	end
end

-- Local (Studio) ------------------------------------------------------------------------------------

function MatchmakingService._localTick()
	-- prune
	for i = #localQueue, 1, -1 do
		local party = localQueue[i]
		if not party.Queued or #party.Members == 0 then
			table.remove(localQueue, i)
		end
	end
	local total = 0
	for _, party in localQueue do
		total += #party.Members
	end
	status.Searching = total
	if ctx.MatchService.Active or #localQueue == 0 then
		return
	end
	local entries = {}
	for _, party in localQueue do
		table.insert(entries, { Id = party.Id, Size = #party.Members, Party = party })
	end
	local packing = TeamAssignment.Select(entries, Config.Match.TeamCount, Config.Match.MaxPerTeam, Config.Match.MinPlayers)
	local teams: { { any } }
	if packing then
		teams = packing.Teams
	elseif total >= Config.Dev.StudioMinPlayers then
		local oldest = math.huge
		for _, party in localQueue do
			oldest = math.min(oldest, party.QueuedAt)
		end
		if os.clock() - oldest < Config.Dev.StudioFillWait and total < Config.Match.MaxPlayers then
			return
		end
		-- Relaxed Studio assignment: fill the emptiest team that fits, parties intact.
		teams = { {}, {}, {}, {} }
		local sizes = { 0, 0, 0, 0 }
		table.sort(entries, function(a, b)
			return a.Size > b.Size
		end)
		for _, e in entries do
			local best = nil
			for t = 1, 4 do
				if sizes[t] + e.Size <= Config.Match.MaxPerTeam and (best == nil or sizes[t] < sizes[best]) then
					best = t
				end
			end
			if best then
				table.insert(teams[best], e)
				sizes[best] += e.Size
			end
		end
	else
		return
	end
	local assignment: { [Player]: number } = {}
	for t, list in teams do
		for _, e in list do
			local party = e.Party
			for _, m in party.Members do
				if m.Parent then
					assignment[m] = t
				end
			end
			local idx = table.find(localQueue, party)
			if idx then
				table.remove(localQueue, idx)
			end
			ctx.LobbyService.RemoveFromQueue(party)
		end
	end
	if next(assignment) then
		print("[Matchmaking] starting local Studio match")
		task.spawn(ctx.MatchService.Begin, assignment, nil)
	end
end

-- Live -------------------------------------------------------------------------------------------------

function MatchmakingService._liveTick()
	if not queueMap or not assignMap or not manifestMap or not lockMap then
		return
	end
	local qm = queueMap :: MemoryStoreSortedMap
	local am = assignMap :: MemoryStoreSortedMap
	local now = os.time()

	-- 1) Refresh our queued parties (sort key = first-queued time).
	for _, party in localQueue do
		if party.Queued and not teleporting[party.Id] and os.clock() - (lastRefresh[party.Id] or 0) > 30 then
			lastRefresh[party.Id] = os.clock()
			local entry = partyEntry(party)
			entry.QueuedAt = now - math.floor(os.clock() - party.QueuedAt)
			qm:SetAsync(party.Id, entry, Config.Matchmaking.EntryTtl, entry.QueuedAt)
		end
	end

	-- 2) Check assignments for our parties.
	for _, party in table.clone(localQueue) do
		if party.Queued and not teleporting[party.Id] then
			local assignment = am:GetAsync(party.Id)
			if type(assignment) == "table" and type(assignment.AccessCode) == "string" then
				teleporting[party.Id] = true
				MatchmakingService._teleportParty(party, assignment.AccessCode)
			end
		end
	end

	-- 3) Matchmaker lease (10 s) — only one server matches at a time.
	local holder = false
	lockMap:UpdateAsync("lease", function(old)
		if type(old) == "table" and old.Job ~= game.JobId and (old.Until or 0) > now then
			return nil
		end
		holder = true
		return { Job = game.JobId, Until = now + 10 }
	end, 15)

	local range = qm:GetRangeAsync(Enum.SortDirection.Ascending, 100)
	local total = 0
	for _, item in range do
		total += (item.value and item.value.Size) or 0
	end
	status.Searching = total
	if holder then
		MatchmakingService._match(range)
	end
end

function MatchmakingService._match(range: { any })
	local qm = queueMap :: MemoryStoreSortedMap
	local am = assignMap :: MemoryStoreSortedMap
	local mm = manifestMap :: MemoryStoreSortedMap
	local entries = {}
	local oldest = math.huge
	for _, item in range do
		local v = item.value
		if type(v) == "table" and type(v.Members) == "table" and v.Size >= 1 and v.Size <= Config.Match.MaxPerTeam then
			table.insert(entries, { Id = item.key, Size = v.Size, Members = v.Members })
			oldest = math.min(oldest, item.sortKey or os.time())
		end
	end
	local packing = TeamAssignment.Select(entries, Config.Match.TeamCount, Config.Match.MaxPerTeam, Config.Match.MinPlayers)
	if not packing then
		return
	end
	local waited = os.time() - oldest
	if packing.Total < Config.Match.MaxPlayers and waited < Config.Matchmaking.FillWait then
		return -- give the queue a little longer to fill to 16
	end
	local accessCode, privateServerId = TeleportService:ReserveServer(game.PlaceId)
	local matchId = HttpService:GenerateGUID(false)
	local teams = {}
	for t, list in packing.Teams do
		teams[t] = {}
		for _, e in list do
			table.insert(teams[t], { Id = e.Id, Members = e.Members })
		end
	end
	mm:SetAsync(privateServerId, { MatchId = matchId, Teams = teams, Created = os.time() }, 3600)
	for _, list in packing.Teams do
		for _, e in list do
			am:SetAsync(e.Id, { AccessCode = accessCode, MatchId = matchId }, 300)
			qm:RemoveAsync(e.Id)
		end
	end
	print(string.format("[Matchmaking] formed match %s with %d players", matchId, packing.Total))
end

function MatchmakingService._teleportParty(party: any, accessCode: string)
	local members = {}
	for _, m in party.Members do
		if m.Parent then
			table.insert(members, m)
			ctx.Util.Notify(m, "Match found! Travelling to the forest...", "success")
		end
	end
	ctx.LobbyService.RemoveFromQueue(party)
	local idx = table.find(localQueue, party)
	if idx then
		table.remove(localQueue, idx)
	end
	if #members == 0 then
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({ PartyId = party.Id })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, members, options)
	end)
	if not ok then
		warn("[Matchmaking] TeleportAsync failed:", err)
		teleporting[party.Id] = nil
		for _, m in members do
			ctx.Util.Notify(m, "Teleport failed. Please ready up again.", "error")
		end
	end
end

-- Match server: read the manifest written by the matchmaker.
function MatchmakingService.ReadManifest(privateServerId: string): any
	if not manifestMap then
		return nil
	end
	for _ = 1, 10 do
		local ok, v = pcall(function()
			return (manifestMap :: MemoryStoreSortedMap):GetAsync(privateServerId)
		end)
		if ok and type(v) == "table" then
			return v
		end
		task.wait(2)
	end
	return nil
end


return MatchmakingService
