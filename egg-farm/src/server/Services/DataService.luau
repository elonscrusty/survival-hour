--!nonstrict
-- Loads, migrates, saves and releases each player's FarmState through a persistence adapter.
-- Rules:
--   * A failed, cancelled or conflicting load kicks the player with a friendly message. It never
--     hands out a default profile, so a DataStore outage can't overwrite real progress.
--   * Saved data is migrated on a COPY; only a successful migration replaces the live table.
--   * Data from a newer game version is refused (no downgrade).
--   * Release happens on leave and on shutdown (ProfileStore also flushes on BindToClose).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Migrations = require(Shared.Logic.Migrations)
local State = require(Shared.Logic.State)

local DataService = {}

local adapter
local handles: { [Player]: any } = {}

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

function DataService.Init(ctx)
	adapter = ctx.PersistenceAdapter
	DataService.Kind = adapter.Kind
end

function DataService.Template(): any
	local s = State.New(0)
	s.createdAt = 0 -- marks "never saved"
	s.lastSeen = 0
	return s
end

-- Yields. Returns the live FarmState table, or nil after kicking the player.
function DataService.Load(player: Player, now: number): any?
	local key = "Player_" .. player.UserId
	local result = adapter:Load(key, function()
		return player.Parent ~= Players
	end)
	if player.Parent ~= Players then
		if result.ok then
			adapter:Release(result.handle)
		end
		return nil
	end
	if not result.ok then
		warn(string.format("[Data] load failed for %d: %s", player.UserId, tostring(result.reason)))
		local msg = if result.reason == "locked"
			then "Your farm is still open on another server. Please wait a moment and rejoin."
			else "We couldn't load your farm safely, so nothing was changed. Please rejoin in a moment."
		player:Kick(msg)
		return nil
	end
	local handle = result.handle
	local data = deepCopy(handle.data)
	if result.isNew or data.createdAt == 0 then
		data = State.New(now)
	end
	local ok, migrated = Migrations.Migrate(data, now)
	if not ok then
		warn(string.format("[Data] migration refused for %d: %s", player.UserId, tostring(migrated)))
		adapter:Release(handle) -- saves the untouched original
		player:Kick(if migrated == "newer"
			then "This server is running an older version of the game. Please rejoin."
			else "Your save needs attention; nothing was changed. Please rejoin.")
		return nil
	end
	adapter:SetData(handle, migrated)
	handles[player] = handle
	adapter:OnSessionEnd(handle, function()
		-- another server took the session (ProfileStore): stop this one from playing on stale data
		if handles[player] == handle and player.Parent == Players then
			handles[player] = nil
			player:Kick("Your farm was opened on another server.")
		end
	end)
	return migrated
end

function DataService.IsActive(player: Player): boolean
	local h = handles[player]
	return h ~= nil and adapter:IsActive(h)
end

function DataService.Save(player: Player): boolean
	local h = handles[player]
	if not h then
		return false
	end
	return (adapter:Save(h))
end

-- Yields until a save that satisfies check(savedData) is confirmed (receipt handling).
function DataService.WaitForSave(player: Player, check: (any) -> boolean, timeout: number): boolean
	local h = handles[player]
	if not h then
		return false
	end
	return adapter:WaitForSave(h, check, timeout)
end

function DataService.Release(player: Player)
	local h = handles[player]
	handles[player] = nil
	if h then
		local ok, err = adapter:Release(h)
		if not ok then
			warn(string.format("[Data] release for %d reported: %s", player.UserId, tostring(err)))
		end
	end
end

function DataService.Adapter()
	return adapter
end

return DataService
