--!strict
-- Latest server snapshot of this player's game. The client only renders it; every number
-- shown as owned/earned comes from here (server-accepted values).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local State = {}
State.data = nil :: any
State.receivedAt = 0
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event
local notify = Instance.new("BindableEvent")
State.Notify = notify.Event -- (kind, data)

local Action = Net.get("Action")

function State.send(name: string, ...: any)
	Action:FireServer(name, ...)
end

-- Live progress (0..1) of a business, interpolated from the last snapshot.
function State.progress(b: any): number
	if not b or not b.owned then
		return 0
	end
	if not b.running and not b.auto then
		return 0
	end
	local cps = b.cps or 1
	if cps > 20 then
		return 1
	end
	local p = b.progress + (os.clock() - State.receivedAt) * cps
	if b.auto then
		return p % 1
	end
	return math.min(p, 1)
end

function State.init()
	Net.get("State").OnClientEvent:Connect(function(snap)
		State.data = snap
		State.receivedAt = os.clock()
		changed:Fire(snap)
	end)
	Net.get("Notify").OnClientEvent:Connect(function(kind, data)
		notify:Fire(kind, data)
	end)
	State.send("sync")
end

return State
