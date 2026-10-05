--!nonstrict
-- Player profiles in a DataStore with session locking.
--
-- Stored record under key "p_<UserId>": { Profile = <Logic/Schema.Profile>, Lock = { JobId, Time } | nil }
--
-- Safety rules:
--   * Only the server holding a record's lock writes it (UpdateAsync checks).
--     A lock older than Config.SessionLockSeconds is treated as dead.
--   * If loading fails, the session is "Failed": the player can play but
--     nothing is saved, so a blank profile never overwrites real data, and
--     purchases answer NotProcessedYet until a later session loads properly.
--   * Saves are serialised per player; leaving saves and releases the lock;
--     BindToClose saves everyone.
--   * In Studio without DataStore access the profile lives in memory ("Memory").

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = Shared:WaitForChild("Logic")
local Profile = require(Logic:WaitForChild("Profile"))

local DataService = {}

local ctx: any
local store: DataStore? = nil
local persistence = false
local sessions: { [Player]: any } = {}
local loadedHooks: { (Player, any) -> () } = {}
local closing = false

local LOAD_RETRIES = 5

local function key(userId: number): string
	return "p_" .. userId
end

function DataService.Init(c)
	ctx = c
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable:", result)
	end
	persistence = store ~= nil
	if persistence and ctx.IsStudio then
		-- Studio without "Enable Studio Access to API Services" throws here.
		local okProbe = pcall(function()
			(store :: DataStore):GetAsync("__probe")
		end)
		if not okProbe then
			persistence = false
			warn("[DataService] Studio has no DataStore access: profiles are kept in memory only")
		end
	end
	ctx.Util.OnPlayerAdded(DataService._onJoin)
	ctx.Util.OnPlayerRemoving(DataService._onLeave)
	game:BindToClose(DataService._onClose)
end

function DataService.Start()
	while true do
		task.wait(Config.AutosaveSeconds)
		for p, s in sessions do
			if s.State == "Loaded" and not s.Released then
				task.spawn(DataService.Save, p, false)
			end
		end
	end
end

-- Runs after a player's profile is ready (in registration order).
function DataService.OnLoaded(fn: (Player, any) -> ())
	table.insert(loadedHooks, fn)
end

-- The session once the profile is usable (loaded, memory or failed), else nil.
function DataService.Get(player: Player): any
	local s = sessions[player]
	if s and s.Ready and not s.Released then
		return s
	end
	return nil
end

-- Waits until the profile is usable (or the player left / timeout).
function DataService.WaitFor(player: Player, timeout: number?): any
	local deadline = os.clock() + (timeout or 30)
	while player.Parent ~= nil and os.clock() < deadline do
		local s = DataService.Get(player)
		if s then
			return s
		end
		task.wait(0.25)
	end
	return DataService.Get(player)
end

function DataService.All(): { [Player]: any }
	return sessions
end

-- Loading -----------------------------------------------------------------------

local function tryLoad(userId: number): (string, any)
	-- Returns "ok", rawProfile | "locked", nil | "error", message.
	local now = os.time()
	local lockedBy: string? = nil
	local captured: any = nil
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(userId), function(old)
			-- The transform may run more than once; the last run is what commits.
			lockedBy = nil
			captured = nil
			local rec = if type(old) == "table" then old else {}
			local lock = rec.Lock
			if type(lock) == "table" and lock.JobId ~= game.JobId and type(lock.Time) == "number"
				and now - lock.Time < Config.SessionLockSeconds then
				lockedBy = tostring(lock.JobId)
				return nil -- abort: another live server owns this profile
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
	local s = {
		Player = player,
		Profile = Profile.Default(),
		State = "Loading",
		Persist = persistence,
		Ready = false,
		Released = false,
		Saving = false,
		LockLost = false,
		JoinClock = os.clock(),
		PlaytimeClaimed = {},
		Premium = false,
		InGroup = false,
		-- Off until PolicyService answers (StateService), so nothing restricted
		-- slips through in the first seconds.
		CanBuyGemEggs = false,
		CanTrade = false,
		LastHatch = 0,
	}
	sessions[player] = s

	if not s.Persist then
		s.State = "Memory"
	else
		local result, data
		for attempt = 1, LOAD_RETRIES do
			result, data = tryLoad(player.UserId)
			if result == "ok" or player.Parent == nil then
				break
			end
			if result == "error" then
				warn(string.format("[DataService] load error for %d (attempt %d): %s", player.UserId, attempt, tostring(data)))
			end
			-- The previous server releases the lock when the player leaves it.
			task.wait(math.min(2 + attempt * 2, 10))
		end
		if result == "ok" then
			s.Profile = Profile.Sanitize(data)
			s.State = "Loaded"
		else
			s.State = "Failed"
			s.Persist = false
			warn("[DataService] profile load failed; playing without saving for", player.UserId)
		end
	end

	if player.Parent == nil then
		-- Left while loading: release the lock we may hold.
		if s.State == "Loaded" then
			s.Ready = true
			DataService.Save(player, true)
		end
		sessions[player] = nil
		return
	end
	s.JoinClock = os.clock()
	s.Ready = true
	for _, fn in loadedHooks do
		local ok, err = pcall(fn, player, s)
		if not ok then
			warn("[DataService] loaded hook error:", err)
		end
	end
	if s.State == "Failed" then
		ctx.Util.Toast(player, "Your saved data couldn't be loaded. Progress won't be saved this time - please rejoin later.", "bad")
	end
end

-- Saving ------------------------------------------------------------------------

-- Writes the profile. `release` drops the session lock (leaving / shutdown).
-- Returns true when the data is safely stored (or nothing needs storing).
function DataService.Save(player: Player, release: boolean?): boolean
	local s = sessions[player]
	if not s then
		return false
	end
	if not s.Persist or s.State ~= "Loaded" then
		return not s.Persist and s.State == "Memory"
	end
	if s.LockLost then
		return false
	end
	-- One write at a time per player; a later call waits for the earlier one.
	local waited = 0
	while s.Saving and waited < 30 do
		task.wait(0.1)
		waited += 0.1
	end
	if s.Released or s.LockLost then
		-- A release save finished while we waited: never re-take the lock.
		return s.Released
	end
	s.Saving = true
	local data = s.Profile
	local lost = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player.UserId), function(old)
			lost = false
			local rec = if type(old) == "table" then old else {}
			local lock = rec.Lock
			if type(lock) == "table" and lock.JobId ~= game.JobId and type(lock.Time) == "number"
				and os.time() - lock.Time < Config.SessionLockSeconds then
				lost = true
				return nil
			end
			rec.Profile = data
			rec.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return rec
		end)
	end)
	s.Saving = false
	if not ok then
		warn("[DataService] save failed for", player.UserId, err)
		return false
	end
	if lost then
		s.LockLost = true
		warn("[DataService] session lock taken by another server; stopped saving for", player.UserId)
		return false
	end
	if release then
		s.Released = true
	end
	return true
end

-- Saves right away (purchases, trades). Retries a couple of times.
function DataService.SaveNow(player: Player): boolean
	for attempt = 1, 3 do
		if DataService.Save(player, false) then
			return true
		end
		local s = sessions[player]
		if not s or s.LockLost or not s.Persist then
			return false
		end
		task.wait(attempt)
	end
	return false
end

function DataService._onLeave(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	if s.State == "Loaded" and not s.Released then
		DataService.Save(player, true)
	end
	s.Released = true
	sessions[player] = nil
end

function DataService._onClose()
	if closing then
		return
	end
	closing = true
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
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.2)
	end
end

return DataService
