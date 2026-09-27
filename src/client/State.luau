--!nonstrict
-- Client-side store for server snapshots with change signals.

local State = {}

type Listener = (any) -> ()
local listeners: { [string]: { Listener } } = {}
local values: { [string]: any } = {}

function State.Set(key: string, value: any)
	values[key] = value
	for _, fn in listeners[key] or {} do
		task.spawn(fn, value)
	end
end

function State.Get(key: string): any
	return values[key]
end

-- Subscribes; calls immediately if a value exists. Returns an unsubscribe fn.
function State.On(key: string, fn: Listener): () -> ()
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], fn)
	if values[key] ~= nil then
		task.spawn(fn, values[key])
	end
	return function()
		local list = listeners[key]
		local i = list and table.find(list, fn)
		if i then
			table.remove(list, i)
		end
	end
end

-- Fire-and-forget events (no stored value)
function State.Emit(key: string, value: any)
	for _, fn in listeners[key] or {} do
		task.spawn(fn, value)
	end
end

return State
