-- Loads and saves player profiles (DataStore), keeps leaderstats in sync and
-- sends each player a snapshot of their profile whenever it changes.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Profile = require(Shared.Logic.Profile)
local RaceRules = require(Shared.Logic.RaceRules)

local DataService = {}

local store: DataStore? = nil
local profiles: { [Player]: Profile.Data } = {}
local loaded: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local listeners: { (Player, Profile.Data) -> () } = {}

local function key(p: Player): string
	return "u" .. p.UserId
end

local function withRetry<T>(fn: () -> T): (boolean, any)
	local ok, res
	for attempt = 1, 4 do
		ok, res = pcall(fn)
		if ok then
			return true, res
		end
		task.wait(attempt)
	end
	return false, res
end

local function setupLeaderstats(p: Player, d: Profile.Data)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local trophies = Instance.new("IntValue")
	trophies.Name = "Trophies"
	trophies.Value = d.Trophies
	trophies.Parent = ls
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = d.Coins
	coins.Parent = ls
	ls.Parent = p
end

local function syncLeaderstats(p: Player, d: Profile.Data)
	local ls = p:FindFirstChild("leaderstats")
	if ls then
		(ls:FindFirstChild("Coins") :: IntValue).Value = d.Coins;
		(ls:FindFirstChild("Trophies") :: IntValue).Value = d.Trophies
	end
	local _, league = RaceRules.League(d.Trophies)
	p:SetAttribute("League", league.Name)
end

-- Saves are stored as { Data = profile, Lock = { Job, At } }. The lock stops two
-- servers using the same save at once (e.g. a quick server hop): a new server waits
-- for the old one to save and let go, and a server that lost its lock stops saving.
local JOB = if game.JobId ~= "" then game.JobId else "studio"
local LOCK_STALE = 600 -- seconds: a lock this old belongs to a crashed server

local function load(p: Player)
	local data: Profile.Data
	if store then
		local raw = nil
		local got = false
		for attempt = 1, 6 do
			local locked = false
			local ok, err = pcall(function()
				(store :: DataStore):UpdateAsync(key(p), function(old)
					local lock = type(old) == "table" and old.Lock
					if type(lock) == "table" and lock.Job ~= JOB and type(lock.At) == "number" and os.time() - lock.At < LOCK_STALE and attempt < 6 then
						locked = true
						return nil -- leave it alone; try again shortly
					end
					raw = if type(old) == "table" then old.Data else nil
					return { Data = raw, Lock = { Job = JOB, At = os.time() } }
				end)
			end)
			if ok and not locked then
				got = true
				break
			end
			if not ok then
				warn("Load attempt failed for " .. p.Name .. ": " .. tostring(err))
			end
			task.wait(if locked then 5 else attempt)
			if not p.Parent then
				return -- we never took the lock on this attempt
			end
		end
		if not got then
			-- Don't risk overwriting real data with a fresh profile.
			p:Kick("Couldn't load your save. Please rejoin in a minute.")
			return
		end
		data = Profile.Sanitize(raw)
	else
		data = Profile.Default()
	end
	if not p.Parent then
		-- Left while loading: let go of the lock so they can rejoin straight away.
		if store then
			pcall(function()
				(store :: DataStore):UpdateAsync(key(p), function(old)
					if type(old) == "table" and type(old.Lock) == "table" and old.Lock.Job == JOB then
						return { Data = old.Data, Lock = nil }
					end
					return nil
				end)
			end)
		end
		return
	end
	profiles[p] = data
	loaded[p] = true
	setupLeaderstats(p, data)
	DataService.Changed(p)
	for _, fn in listeners do
		task.spawn(fn, p, data)
	end
end

-- Writes the profile. release = true also lets go of the session lock (on leave).
-- Returns true when the save is safely stored.
local function save(p: Player, release: boolean?): boolean
	local d = profiles[p]
	if not d or not store or not loaded[p] then
		return false
	end
	dirty[p] = nil
	local lost = false
	local ok, err = withRetry(function()
		return (store :: DataStore):UpdateAsync(key(p), function(old)
			local lock = type(old) == "table" and old.Lock
			if type(lock) == "table" and lock.Job ~= JOB then
				lost = true -- another server has this save now: don't overwrite it
				return nil
			end
			return { Data = d, Lock = if release then nil else { Job = JOB, At = os.time() } }
		end)
	end)
	if lost then
		warn("Save skipped for " .. p.Name .. ": another server owns this save")
		loaded[p] = nil
		if p.Parent then
			p:Kick("Your save was opened on another server. Please rejoin.")
		end
		return false
	end
	if not ok then
		warn("Save failed for " .. p.Name .. ": " .. tostring(err))
		dirty[p] = true
		return false
	end
	return true
end

function DataService.Init()
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore("PetRaceLeague_v1")
	end)
	if ok then
		store = res
	else
		warn("DataStore unavailable (enable API access in Studio to save). Progress won't save.")
	end
	if RunService:IsStudio() and store then
		-- Probe once so Studio without API access falls back cleanly.
		local probeOk = pcall(function()
			(store :: DataStore):GetAsync("probe")
		end)
		if not probeOk then
			warn("DataStore blocked in Studio. Progress won't save this session.")
			store = nil
		end
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		save(p, true)
		profiles[p] = nil
		loaded[p] = nil
		dirty[p] = nil
	end)
	game:BindToClose(function()
		local threads = {}
		for p in profiles do
			table.insert(threads, task.spawn(save, p, true))
		end
		local deadline = os.clock() + 25
		while os.clock() < deadline do
			local busy = false
			for _, th in threads do
				if coroutine.status(th) ~= "dead" then
					busy = true
				end
			end
			if not busy then
				break
			end
			task.wait(0.2)
		end
	end)
	while true do
		task.wait(Config.AutosaveEvery)
		for p in profiles do
			if dirty[p] then
				task.spawn(save, p)
			end
		end
	end
end

function DataService.Get(p: Player): Profile.Data?
	return profiles[p]
end

-- Called when a profile has loaded.
function DataService.OnLoaded(fn: (Player, Profile.Data) -> ())
	table.insert(listeners, fn)
	for p, d in profiles do
		task.spawn(fn, p, d)
	end
end

-- Call after every change: marks for saving and sends the new snapshot.
function DataService.Changed(p: Player)
	local d = profiles[p]
	if not d then
		return
	end
	dirty[p] = true
	syncLeaderstats(p, d)
	Net.Event("State"):FireClient(p, d)
end

function DataService.AddCoins(p: Player, amount: number)
	local d = profiles[p]
	if d and amount ~= 0 then
		d.Coins = math.max(0, d.Coins + math.floor(amount))
		DataService.Changed(p)
	end
end

-- Saves straight away and waits. Returns true if stored (or if saving is off).
function DataService.SaveNow(p: Player): boolean
	if not store then
		return true
	end
	return save(p)
end

return DataService
