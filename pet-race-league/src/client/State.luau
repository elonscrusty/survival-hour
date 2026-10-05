-- Holds the latest profile snapshot from the server and tells listeners when it changes.
local State = {}

State.Data = nil :: any
local listeners: { (any) -> () } = {}

function State.Set(data: any)
	State.Data = data
	for _, fn in listeners do
		task.spawn(fn, data)
	end
end

function State.OnChange(fn: (any) -> ())
	table.insert(listeners, fn)
	if State.Data then
		task.spawn(fn, State.Data)
	end
end

-- The pet the player is riding, or nil.
function State.Equipped(): any
	local d = State.Data
	if not d then
		return nil
	end
	for _, p in d.Pets do
		if p.Uid == d.Equipped then
			return p
		end
	end
	return nil
end

return State
