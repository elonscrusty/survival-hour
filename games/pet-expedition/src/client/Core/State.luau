--!strict
-- Client state store. Receives the server's `State` snapshots and the `Trade`
-- window, keeps a clock offset to the server, and fires change signals the
-- controllers subscribe to. Everything here is read-only from the UI's point
-- of view: changes always go through the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))

local Signal = require("./Signal")

export type PlayerState = Types.PlayerState
export type PetInstance = Types.PetInstance
export type TradeView = Types.TradeView

local State = {}

State.Data = nil :: PlayerState?
State.Previous = nil :: PlayerState?
State.Trade = nil :: TradeView?
State.TradeReceivedAt = 0
State.ReceivedAt = 0 -- os.clock() when the last snapshot arrived

-- (new, old) every snapshot
State.Changed = Signal.new()
-- (view?) every trade update
State.TradeChanged = Signal.new()
-- (kind, data) every Notify
State.Notify = Signal.new()
-- fires once, the first time a snapshot arrives
State.Ready = Signal.new()

local offset = 0
local gotFirst = false

local function localNow(): number
	return DateTime.now().UnixTimestampMillis / 1000
end

-- Server time estimate (seconds, os.time scale, fractional).
function State.Now(): number
	return localNow() + offset
end

function State.Get(): PlayerState?
	return State.Data
end

-- Wait until the first snapshot is in.
function State.Wait(): PlayerState
	while not State.Data do
		task.wait()
	end
	return State.Data :: PlayerState
end

function State.HasPass(key: string): boolean
	local d = State.Data
	return d ~= nil and d.Passes[key] == true
end

function State.Setting(key: string, default: any): any
	local d = State.Data
	if not d or d.Settings == nil then
		return default
	end
	local v = d.Settings[key]
	if v == nil then
		return default
	end
	return v
end

-- Optimistic local update of a setting (the server echoes the real value).
function State.SetLocalSetting(key: string, value: any)
	local d = State.Data
	if d then
		d.Settings[key] = value
		State.Changed:Fire(d, d)
	end
end

function State.BoostLeft(key: string): number
	local d = State.Data
	if not d then
		return 0
	end
	local untilT = d.Boosts[key]
	if not untilT then
		return 0
	end
	return math.max(0, untilT - State.Now())
end

function State.ServerLuckLeft(): number
	local d = State.Data
	if not d then
		return 0
	end
	return math.max(0, (d.ServerLuckUntil or 0) - State.Now())
end

function State.PetByUid(uid: string): PetInstance?
	local d = State.Data
	if not d then
		return nil
	end
	for _, p in d.Pets do
		if p.Uid == uid then
			return p
		end
	end
	return nil
end

function State.IsEquipped(uid: string): boolean
	local d = State.Data
	return d ~= nil and table.find(d.Equipped, uid) ~= nil
end

-- Set of uids currently away on an expedition.
function State.BusyUids(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local d = State.Data
	if d then
		for _, e in d.Expeditions do
			for _, uid in e.Pets do
				set[uid] = true
			end
		end
	end
	return set
end

-- Set of uids offered in the open trade (can't be deleted, crafted or sent away).
function State.TradeUids(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local t = State.Trade
	if t then
		for _, p in t.Me.Pets do
			set[p.Uid] = true
		end
	end
	return set
end

-- Minutes played this session, extrapolated between snapshots.
function State.SessionMinutes(): number
	local d = State.Data
	if not d then
		return 0
	end
	return d.Playtime.SessionMinutes + (os.clock() - State.ReceivedAt) / 60
end

function State.TradeCountdown(): number?
	local t = State.Trade
	if not t or t.Countdown == nil then
		return nil
	end
	return math.max(0, t.Countdown - (os.clock() - State.TradeReceivedAt))
end

function State.Init()
	Net.Event("State").OnClientEvent:Connect(function(data: PlayerState)
		if type(data) ~= "table" then
			return
		end
		if type(data.ServerTime) == "number" then
			local diff = data.ServerTime - localNow()
			-- ServerTime is whole seconds, so only resync on real drift
			if not gotFirst or math.abs(diff - offset) > 1.5 then
				offset = diff
			end
		end
		local old = State.Data
		State.Previous = old
		State.Data = data
		State.ReceivedAt = os.clock()
		State.Changed:Fire(data, old)
		if not gotFirst then
			gotFirst = true
			State.Ready:Fire(data)
		end
	end)
	Net.Event("Trade").OnClientEvent:Connect(function(view: TradeView?)
		State.Trade = if type(view) == "table" then view else nil
		State.TradeReceivedAt = os.clock()
		State.TradeChanged:Fire(State.Trade)
	end)
	Net.Event("Notify").OnClientEvent:Connect(function(kind: string, data: any)
		if type(kind) ~= "string" then
			return
		end
		State.Notify:Fire(kind, if type(data) == "table" then data else {})
	end)
end

return State
