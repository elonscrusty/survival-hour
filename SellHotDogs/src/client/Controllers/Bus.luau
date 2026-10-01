--!strict
-- Client-side message bus so controllers can open each other's screens without cycles.
local Bus = {}
local ev = Instance.new("BindableEvent")
Bus.Opened = ev.Event -- (what, arg)

-- Selected bulk size for level upgrades (1, 5, 25, 100 or "max"); validated by the server.
Bus.bulk = 1 :: any
local bulkEv = Instance.new("BindableEvent")
Bus.BulkChanged = bulkEv.Event

function Bus.open(what: string, arg: any?)
	ev:Fire(what, arg)
end

function Bus.setBulk(v: any)
	Bus.bulk = v
	bulkEv:Fire(v)
end

-- Convert a {m, e} table from the server into a BigNum (tables cross remotes as plain data).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BigNum = require(Shared.Logic.BigNum)
function Bus.big(v: any): BigNum.Big
	return BigNum.sanitize(v) or BigNum.zero
end

return Bus
