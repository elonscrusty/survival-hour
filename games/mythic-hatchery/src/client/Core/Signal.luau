--!strict
-- Minimal signal: Connect returns a disconnect function. Handlers run in
-- order, and an error in one handler doesn't stop the others.

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> () -> (),
	Fire: (self: Signal, ...any) -> (),
	_handlers: { (...any) -> () },
}

local Signal = {}

local function connect(self: Signal, fn: (...any) -> ()): () -> ()
	table.insert(self._handlers, fn)
	return function()
		local i = table.find(self._handlers, fn)
		if i then
			table.remove(self._handlers, i)
		end
	end
end

local function fire(self: Signal, ...: any)
	for _, fn in table.clone(self._handlers) do
		local ok, err = pcall(fn :: any, ...)
		if not ok then
			warn("[Signal] handler error: " .. tostring(err))
		end
	end
end

function Signal.new(): Signal
	return {
		_handlers = {},
		Connect = connect,
		Fire = fire,
	}
end

return Signal
