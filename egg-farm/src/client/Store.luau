--!strict
-- Client-side view of the player's farm. Holds the latest server snapshot, lets UI and visuals
-- subscribe to changes and server events, and sends action requests.
--   Store.Get()                    latest FarmSnapshot (nil until the first one arrives)
--   Store.OnChanged(fn)            fn(snapshot) after every new snapshot; returns a disconnect fn
--   Store.OnEvent(name, fn)        fn(data) for FarmEvent `name` ("*" = every event: fn(name, data))
--   Store.Request(action)          yields; returns ActionResult. Adds `seq`; while a request of the
--                                  same key (type+slot+id) is in flight, a duplicate returns
--                                  { ok = false, code = "busy" } without contacting the server.
--   Store.IsBusy(key)              true while a request with that key is in flight
--   Store.Key(action)              the dedupe key for an action
--   Store.Now()                    estimated server time (snapshot clock + local elapsed)
-- Nothing in here is trusted by the server: it only names intents.

local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"))

local Store = {}

local snapshot: any = nil
local receivedAt = 0
local changed: { (any) -> () } = {}
local eventFns: { [string]: { (...any) -> () } } = {}
local busy: { [string]: boolean } = {}
local seq = 0

local function remove(list: { any }, fn: any)
	local i = table.find(list, fn)
	if i then
		table.remove(list, i)
	end
end

function Store.Get(): any
	return snapshot
end

function Store.Now(): number
	if not snapshot then
		return os.time()
	end
	return snapshot.serverNow + (os.clock() - receivedAt)
end

function Store.OnChanged(fn: (any) -> ()): () -> ()
	table.insert(changed, fn)
	if snapshot then
		task.spawn(fn, snapshot)
	end
	return function()
		remove(changed, fn)
	end
end

function Store.OnEvent(name: string, fn: (...any) -> ()): () -> ()
	eventFns[name] = eventFns[name] or {}
	table.insert(eventFns[name], fn)
	return function()
		remove(eventFns[name], fn)
	end
end

function Store.Key(action: any): string
	return string.format("%s|%s|%s", tostring(action.type), tostring(action.slot or ""), tostring(action.id or action.index or ""))
end

function Store.IsBusy(key: string): boolean
	return busy[key] == true
end

function Store.Request(action: any): any
	local key = Store.Key(action)
	if busy[key] then
		return { ok = false, code = "busy" }
	end
	busy[key] = true
	seq += 1
	action.seq = seq
	local remote = Net.Get("Action") :: RemoteFunction
	local ok, res = pcall(function()
		return remote:InvokeServer(action)
	end)
	busy[key] = nil
	if not ok or type(res) ~= "table" then
		return { ok = false, code = "error", message = "Couldn't reach the server. Try again." }
	end
	return res
end

function Store.Start()
	local snapRemote = Net.Get("Snapshot") :: RemoteEvent
	local eventRemote = Net.Get("FarmEvent") :: RemoteEvent
	snapRemote.OnClientEvent:Connect(function(snap)
		snapshot = snap
		receivedAt = os.clock()
		for _, fn in table.clone(changed) do
			task.spawn(fn, snap)
		end
	end)
	eventRemote.OnClientEvent:Connect(function(name: string, data: any)
		for _, fn: any in table.clone(eventFns[name] or {}) do
			task.spawn(fn, data)
		end
		for _, fn: any in table.clone(eventFns["*"] or {}) do
			task.spawn(fn, name, data)
		end
	end)
end

return Store
