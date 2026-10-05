--!nonstrict
-- Player profiles in a DataStore with session locking.
--
-- Stored record under key "p_<UserId>": { Profile = <Logic/Schema.Profile>, Lock = { JobId, Time } | nil }
-- Trade journals under key "t_<TradeId>" (see Logic/Trade and TradeService).
--
-- Safety rules:
--   * Only the server holding a record's lock writes it (UpdateAsync checks).
--     A lock older than Config.SessionLockSeconds is treated as dead.
--   * If loading fails, or a live server has no DataStore at all, the session
--     is "Failed": the player can play but nothing is saved, purchases answer
--     NotProcessedYet and trading is off. "Memory" sessions exist only in Studio.
--   * Every change that must persist bumps the session's ChangeSeq (Touch).
--     A save records the ChangeSeq it captured; Save / SaveNow report success
--     only when a completed write captured the caller's ChangeSeq or later.
--   * Writes are serialised per player. Once a player is leaving, only the
--     final release save writes, so the lock can never be re-taken after it.
--   * A profile that loads with PendingTrade set replays its side of that
--     trade from the journal before anything else happens.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = Shared:WaitForChild("Logic")
local Profile = require(Logic:WaitForChild("Profile"))
local Trade = require(Logic:WaitForChild("Trade"))

local DataService = {}

local ctx: any
local store: DataStore? = nil
local persistence = false
local sessions: { [Player]: any } = {}
local loadedHooks: { (Player, any) -> () } = {}
local memoryJournals: { [string]: any } = {} -- Studio memory mode only
local closing = false

local LOAD_RETRIES = 5
local RELEASE_RETRIES = 4
local JOURNAL_RETRIES = 5

local function key(userId: number): string
	return "p_" .. userId
end

local function journalKey(tradeId: string): string
	return "t_" .. tradeId
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
	if not persistence and not ctx.IsStudio then
		warn("[DataService] no DataStore on a live server: every session will be read-only (Failed)")
	end
	ctx.Util.OnPlayerAdded(DataService._onJoin)
	ctx.Util.OnPlayerRemoving(DataService._onLeave)
	game:BindToClose(DataService._onClose)
end

function DataService.Start()
	while true do
		task.wait(Config.AutosaveSeconds)
		for _, s in sessions do
			if s.State == "Loaded" and not s.Released and not s.Leaving then
				task.spawn(DataService._save, s, false)
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
	if s and s.Ready and not s.Released and not s.Leaving then
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

-- Marks the profile as changed (call for anything that must persist).
function DataService.Touch(s)
	if s then
		s.ChangeSeq += 1
	end
end

-- True when this session can't keep changes (trading / purchases refuse).
function DataService.ReadOnly(s): boolean
	return s == nil or s.State == "Failed" or s.LockLost == true
end

-- Trade journals ------------------------------------------------------------------

-- Writes a journal once. Returns "written" when the stored record is this
-- journal, "unknown" when every attempt failed (it may or may not exist).
function DataService.WriteJournal(tradeId: string, journal: any): string
	if not persistence then
		if ctx.IsStudio then
			memoryJournals[tradeId] = journal
			return "written"
		end
		return "unknown"
	end
	for attempt = 1, JOURNAL_RETRIES do
		local stored = nil
		local ok, err = pcall(function()
			stored = (store :: DataStore):UpdateAsync(journalKey(tradeId), function(old)
				if type(old) == "table" then
					return nil -- keep whatever is already there
				end
				return journal
			end)
		end)
		if ok then
			if type(stored) == "table" and stored.Id == tradeId then
				return "written"
			end
			-- UpdateAsync returns nil when the transform kept the old value: read it.
			local okGet, existing = pcall(function()
				return (store :: DataStore):GetAsync(journalKey(tradeId))
			end)
			if okGet and type(existing) == "table" and existing.Id == tradeId then
				return "written"
			end
		else
			warn("[DataService] journal write failed (attempt " .. attempt .. "):", err)
		end
		task.wait(attempt)
	end
	return "unknown"
end

-- Returns ok, journal-or-nil. ok = false means the read itself failed.
function DataService.ReadJournal(tradeId: string): (boolean, any)
	if not persistence then
		return ctx.IsStudio, memoryJournals[tradeId]
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(journalKey(tradeId))
		end)
		if ok then
			return true, result
		end
		task.wait(attempt)
	end
	return false, nil
end

function DataService.RemoveJournal(tradeId: string)
	if not persistence then
		memoryJournals[tradeId] = nil
		return
	end
	pcall(function()
		(store :: DataStore):RemoveAsync(journalKey(tradeId))
	end)
end

-- Replays (or clears) a pending trade on a freshly loaded profile.
-- Returns false if the journal couldn't be read (session must not save).
local function resolvePendingTrade(userId: number, s): boolean
	local id = s.Profile.PendingTrade
	if not id then
		return true
	end
	local ok, journal = DataService.ReadJournal(id)
	if not ok then
		return false
	end
	if type(journal) == "table" and type(journal.Sides) == "table" then
		local side = Trade.SanitizeSide(journal.Sides[tostring(userId)])
		if side then
			Trade.ApplySide(s.Profile, side, id)
		end
	end
	-- No journal: the trade never got past its first step, nothing changed.
	s.Profile.PendingTrade = nil
	DataService.Touch(s)
	return true
end

-- Loading -------------------------------------------------------------------------

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
		UserId = player.UserId,
		Profile = Profile.Default(),
		State = "Loading",
		Persist = persistence,
		Ready = false,
		Released = false,
		Leaving = false,
		Closed = false,
		Saving = false,
		LockLost = false,
		ChangeSeq = 0,
		SavedSeq = -1,
		JoinClock = os.clock(),
		LastPlayClock = nil,
		BreakGemLog = {}, -- recent breakable gem grants (Config.BreakGemsPerHour)
		Premium = false,
		InGroup = false,
		-- Off until PolicyService answers (StateService), so nothing restricted
		-- slips through in the first seconds.
		CanBuyGemEggs = false,
		CanTrade = false,
		LastHatch = 0,
		TradeBusy = false,
	}
	sessions[player] = s

	if not s.Persist then
		if ctx.IsStudio then
			s.State = "Memory"
		else
			s.State = "Failed"
		end
	else
		local result, data
		for attempt = 1, LOAD_RETRIES do
			result, data = tryLoad(player.UserId)
			if result == "ok" or s.Leaving or player.Parent == nil then
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
			if not resolvePendingTrade(player.UserId, s) then
				-- Can't tell whether a trade went through: play without saving
				-- and keep the lock short-lived (it expires on its own).
				s.State = "Failed"
				s.Persist = false
				warn("[DataService] couldn't read a pending trade journal for", player.UserId)
			end
		else
			s.State = "Failed"
			s.Persist = false
			warn("[DataService] profile load failed; playing without saving for", player.UserId)
		end
	end

	if s.Leaving or player.Parent == nil then
		-- Left while loading: release the lock we may hold, using this session
		-- object (the session map entry is already gone).
		if s.State == "Loaded" then
			DataService._release(s)
		end
		s.Closed = true
		if sessions[player] == s then
			sessions[player] = nil
		end
		return
	end
	s.JoinClock = os.clock()
	s.Ready = true
	if s.ChangeSeq > 0 then
		task.spawn(DataService._save, s, false)
	end
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

-- Saving --------------------------------------------------------------------------

-- One write. Returns true when a completed write captured ChangeSeq >= the
-- value it had when this call started. `release` drops the lock.
function DataService._save(s, release: boolean?): boolean
	if not s then
		return false
	end
	if s.State == "Memory" then
		return true
	end
	if not s.Persist or s.State ~= "Loaded" then
		return false
	end
	local target = s.ChangeSeq
	-- One write at a time; a later call waits for the earlier one.
	while s.Saving do
		task.wait(0.1)
	end
	if s.SavedSeq >= target and not release then
		return true -- someone else's write already covered our change
	end
	if s.LockLost or s.Released then
		return s.SavedSeq >= target
	end
	if s.Leaving and not release then
		-- Only the release save may write now; report what it achieves.
		while not s.Closed and not s.Released and not s.LockLost do
			task.wait(0.1)
		end
		return s.SavedSeq >= target
	end
	s.Saving = true
	local captured = s.ChangeSeq
	local data = s.Profile
	local lost = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(s.UserId), function(old)
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
		warn("[DataService] save failed for", s.UserId, err)
		return false
	end
	if lost then
		s.LockLost = true
		warn("[DataService] session lock taken by another server; stopped saving for", s.UserId)
		return false
	end
	s.SavedSeq = math.max(s.SavedSeq, captured)
	if release then
		s.Released = true
	end
	return s.SavedSeq >= target
end

-- Final save that releases the lock, retried a few times.
function DataService._release(s)
	for attempt = 1, RELEASE_RETRIES do
		if DataService._save(s, true) or s.LockLost then
			return
		end
		task.wait(attempt)
	end
	warn("[DataService] could not release profile for", s.UserId, "- the lock will expire on its own")
end

function DataService.Save(player: Player, release: boolean?): boolean
	return DataService._save(sessions[player], release)
end

-- Saves right away (purchases, trades), retrying. True only if the player's
-- changes up to now are stored.
function DataService.SaveNow(player: Player): boolean
	return DataService.SaveSession(sessions[player])
end

function DataService.SaveSession(s): boolean
	if not s then
		return false
	end
	for attempt = 1, 3 do
		if DataService._save(s, false) then
			return true
		end
		if s.LockLost or not s.Persist or s.Released or s.Closed then
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
	s.Leaving = true
	sessions[player] = nil
	if s.State == "Loading" then
		return -- the join thread releases once loading finishes
	end
	if s.State == "Loaded" and not s.Released then
		DataService._release(s)
	end
	s.Closed = true
end

function DataService._onClose()
	if closing then
		return
	end
	closing = true
	local pending = 0
	for _, s in sessions do
		if s.State == "Loaded" and not s.Released then
			pending += 1
			s.Leaving = true
			task.spawn(function()
				DataService._release(s)
				s.Closed = true
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
