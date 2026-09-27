--!nonstrict
-- Persistent player profiles with session locking.
--
-- Stored record: { Profile = <ProfileRules.Profile>, Lock = { JobId, Time } | nil }
--
-- Safety rules:
--   * A profile is only ever written by the server holding its lock.
--   * If loading fails (DataStore errors, or a lock we cannot take), the
--     profile is marked NotLoaded: the player can still play, but nothing is
--     saved, so good data is never overwritten by a blank profile. Receipts
--     return NotProcessedYet until a later session loads properly.
--   * Saves use UpdateAsync and verify the lock before writing.
--   * In Studio, DataStores are skipped unless Config.Dev.SaveInStudio (memory profile).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Powerups = require(Shared:WaitForChild("Powerups"))
local ProfileRules = require(Shared:WaitForChild("Logic"):WaitForChild("ProfileRules"))

export type Session = {
	Player: Player,
	Profile: ProfileRules.Profile,
	State: string, -- "Loading" | "Loaded" | "Failed" | "Memory"
	Persist: boolean,
	LockLost: boolean,
	Saving: boolean,
	Released: boolean,
	LoadedEvent: BindableEvent,
}

local DataService = {}

local ctx: any
local store: DataStore? = nil
local sessions: { [Player]: Session } = {}

local function key(userId: number): string
	return "u_" .. userId
end

local function usePersistence(): boolean
	if ctx.IsStudio and not Config.Dev.SaveInStudio then
		return false
	end
	return store ~= nil
end

function DataService.Init(c)
	ctx = c
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable:", result)
	end
	ctx.Util.OnPlayerAdded(DataService._onJoin)
	ctx.Util.OnPlayerRemoving(DataService._onLeave)
	game:BindToClose(DataService._onClose)
end

function DataService.Start()
	while true do
		task.wait(Config.Data.AutosaveInterval)
		for p, s in sessions do
			if s.State == "Loaded" and not s.Released then
				task.spawn(DataService.Save, p, false)
			end
		end
	end
end

-- Loading ------------------------------------------------------------------------------

local function tryLoad(userId: number): (string, any)
	-- returns "ok", profileData | "locked", nil | "error", message
	local now = os.time()
	local lockedBy: string? = nil
	local captured: any = nil
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(userId), function(old)
			-- The transform may run more than once; the last run is what commits.
			lockedBy = nil
			local rec = if type(old) == "table" then old else {}
			local lock = rec.Lock
			if type(lock) == "table" and lock.JobId ~= game.JobId and type(lock.Time) == "number"
				and now - lock.Time < Config.Data.SessionLockTimeout then
				lockedBy = lock.JobId
				return nil -- abort write
			end
			rec.Lock = { JobId = game.JobId, Time = now }
			captured = rec.Profile
			return rec
		end)
	end)
	if not ok then
		return "error", err
	end
	if lockedBy then
		return "locked", nil
	end
	return "ok", captured
end

function DataService._onJoin(player: Player)
	local s: Session = {
		Player = player,
		Profile = ProfileRules.New(),
		State = "Loading",
		Persist = usePersistence(),
		LockLost = false,
		Saving = false,
		Released = false,
		LoadedEvent = Instance.new("BindableEvent"),
	}
	sessions[player] = s
	player:SetAttribute("DataState", "Loading")

	if not s.Persist then
		s.State = "Memory"
		if ctx.IsStudio then
			-- A little starting currency in Studio so the shop can be tested.
			s.Profile.Diamonds = 300
		end
	else
		local attempt = 0
		local result, data
		repeat
			attempt += 1
			result, data = tryLoad(player.UserId)
			if result == "ok" then
				break
			end
			if result == "error" then
				warn(string.format("[DataService] load error for %d (attempt %d): %s", player.UserId, attempt, tostring(data)))
			end
			-- Locks are released by the previous server on leave; teleports take a few seconds.
			task.wait(math.min(2 + attempt * 2, 10))
		until attempt >= Config.Data.LoadRetries or player.Parent == nil
		if result == "ok" then
			s.Profile = ProfileRules.Reconcile(data)
			s.State = "Loaded"
		else
			s.State = "Failed"
			warn("[DataService] profile load failed; running without saving for", player.UserId)
		end
	end

	if player.Parent == nil then
		-- Left while loading: release the lock we might hold.
		if s.State == "Loaded" then
			DataService.Save(player, true)
		end
		sessions[player] = nil
		return
	end
	player:SetAttribute("DataState", s.State)
	s.LoadedEvent:Fire()
	DataService.Push(player)
	if s.State == "Failed" then
		ctx.Util.Notify(player, "Your saved data couldn't be loaded. Progress this session won't be saved. Try rejoining later.", "error")
	end
end

-- Returns the session once loading finished (or nil if the player left).
function DataService.WaitFor(player: Player, timeout: number?): Session?
	local s = sessions[player]
	local deadline = os.clock() + (timeout or 60)
	while s == nil and player.Parent and os.clock() < deadline do
		task.wait(0.2)
		s = sessions[player]
	end
	if not s then
		return nil
	end
	if s.State == "Loading" then
		local done = false
		local conn = s.LoadedEvent.Event:Once(function()
			done = true
		end)
		while not done and player.Parent and os.clock() < deadline do
			task.wait(0.1)
		end
		conn:Disconnect()
	end
	return if s.State ~= "Loading" then s else nil
end

function DataService.Get(player: Player): Session?
	return sessions[player]
end

-- True when changes to this profile will be durable (or deliberately in-memory in Studio).
function DataService.CanGrant(player: Player): boolean
	local s = sessions[player]
	return s ~= nil and (s.State == "Loaded" or s.State == "Memory") and not s.LockLost and not s.Released
end

-- Saving ---------------------------------------------------------------------------------

-- Returns true if the profile is durably stored (or in memory mode).
function DataService.Save(player: Player, release: boolean): boolean
	local s = sessions[player]
	if not s then
		return false
	end
	if s.State == "Memory" then
		return true
	end
	if s.State ~= "Loaded" or s.LockLost then
		return false
	end
	while s.Saving do
		task.wait(0.1)
	end
	s.Saving = true
	local snapshot = HttpService:JSONDecode(HttpService:JSONEncode(s.Profile))
	local success = false
	for attempt = 1, 3 do
		local lost = false
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(player.UserId), function(old)
				local rec = if type(old) == "table" then old else {}
				local lock = rec.Lock
				if type(lock) == "table" and lock.JobId ~= game.JobId then
					lost = true
					return nil
				end
				rec.Profile = snapshot
				rec.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return rec
			end)
		end)
		if ok and lost then
			s.LockLost = true
			warn("[DataService] session lock lost for", player.UserId, "- not overwriting")
			break
		elseif ok then
			success = true
			break
		else
			warn(string.format("[DataService] save failed for %d (attempt %d): %s", player.UserId, attempt, tostring(err)))
			task.wait(attempt)
		end
	end
	s.Saving = false
	if release and success then
		s.Released = true
	end
	return success
end

function DataService._onLeave(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	if s.State == "Loaded" then
		DataService.Save(player, true)
	end
	sessions[player] = nil
end

function DataService._onClose()
	local pending = 0
	for p, s in sessions do
		if s.State == "Loaded" and not s.Released then
			pending += 1
			task.spawn(function()
				DataService.Save(p, true)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.2)
	end
end

-- Client view ---------------------------------------------------------------------------

function DataService.Push(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	local p = s.Profile
	local challenge = {}
	for _, def in Powerups.List do
		local lvl = p.Owned[def.Id] or 0
		local next = lvl + 1
		local ch = def.Challenges[next]
		challenge[def.Id] = {
			Level = lvl,
			Progress = if ch then (p.Stats[ch.Stat] or 0) else nil,
			Target = if ch then ch.Target else nil,
			Text = if ch then ch.Text else nil,
		}
	end
	Net.FireClient("ProfileSync", player, {
		Diamonds = p.Diamonds,
		Owned = p.Owned,
		Equipped = p.Equipped or false,
		Credits = p.Credits,
		Wins = p.Wins,
		Matches = p.Matches,
		Challenges = challenge,
		State = s.State,
	})
	player:SetAttribute("Powerup", p.Equipped or "")
	player:SetAttribute("PowerupLevel", if p.Equipped then p.Owned[p.Equipped] else 0)
end

return DataService
