--!strict
-- Player sessions: load, autosave, save on leave/shutdown.
-- A failed load never creates a profile that could overwrite the stored save: the player gets
-- a temporary profile with saving disabled and is told so.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Profile = require(Shared.Logic.Profile)
local Game = require(Shared.Logic.Game)
local Store = require("./Store")

export type Session = {
	player: Player,
	profile: Profile.Profile,
	canSave: boolean,
	dirty: boolean,
	saving: boolean,
	lastSave: number,
	offlineFound: any?,
	-- runtime (not saved)
	rt: { [string]: any },
}

local Data = {}
Data.sessions = {} :: { [number]: Session } -- keyed by UserId
local loadedSignal = Instance.new("BindableEvent")
Data.Loaded = loadedSignal.Event
local leavingSignal = Instance.new("BindableEvent")
Data.Leaving = leavingSignal.Event

local function now(): number
	return os.time()
end

function Data.get(player: Player): Session?
	return Data.sessions[player.UserId]
end

function Data.save(s: Session, release: boolean): boolean
	if not s.canSave then
		return false
	end
	if s.saving then
		-- one save at a time; wait for the running one
		while s.saving do
			task.wait()
		end
	end
	s.saving = true
	s.profile.lastSeen = now()
	local ok = Store.save(s.player.UserId, Profile.serialize(s.profile), release)
	s.saving = false
	if ok then
		s.dirty = false
		s.lastSave = os.clock()
	end
	return ok
end

local function onJoin(player: Player)
	local ok, raw = Store.load(player.UserId)
	if not player.Parent then
		return
	end
	local session: Session
	if not ok then
		warn("[Data] could not load", player.Name, "- playing without saving")
		session = { player = player, profile = Profile.new(now()), canSave = false, dirty = false, saving = false, lastSave = 0, rt = { loadError = "Your save couldn't be loaded, so progress this visit won't be saved. Rejoin to try again." } }
	else
		local profile, why = Profile.migrate(raw, now())
		if not profile then
			warn("[Data] save for", player.Name, "rejected:", why)
			session = { player = player, profile = Profile.new(now()), canSave = false, dirty = false, saving = false, lastSave = 0, rt = { loadError = "Your save couldn't be read (" .. tostring(why) .. "). Progress this visit won't be saved." } }
		else
			session = { player = player, profile = profile, canSave = true, dirty = false, saving = false, lastSave = os.clock(), rt = {} }
			if why ~= "new" then
				session.offlineFound = Game.applyReturn(profile, now())
				Game.flushSkips(profile)
			end
		end
	end
	Data.sessions[player.UserId] = session
	loadedSignal:Fire(session)
end

local function onLeave(player: Player)
	local s = Data.sessions[player.UserId]
	if not s then
		return
	end
	leavingSignal:Fire(s)
	Data.save(s, true)
	Data.sessions[player.UserId] = nil
end

function Data.init()
	Store.init()
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoin, p)
	end
	task.spawn(function()
		while true do
			task.wait(5)
			for _, s in Data.sessions do
				if s.canSave and os.clock() - s.lastSave >= Config.AutosaveSeconds then
					task.spawn(Data.save, s, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, s in Data.sessions do
			pending += 1
			task.spawn(function()
				Data.save(s, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

return Data
