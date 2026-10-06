--!strict
-- Server calls. Every RemoteFunction is invoked inside pcall; a failed call
-- or an { ok = false, err } result shows the reason as a toast.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Toasts = require("../UI/Toasts")
local State = require("./State")

local Remote = {}

export type Result = { [string]: any }

local busy: { [string]: boolean } = {}

-- Claims and purchases stay blocked after a success until the next State
-- snapshot shows the result (or a short timeout), so a quick double tap on a
-- button that still says "Claim" doesn't send a second request.
local HOLD_AFTER_SUCCESS: { [string]: boolean } = {
	ClaimExpedition = true,
	SkipExpedition = true,
	StartExpedition = true,
	ClaimDaily = true,
	ClaimPlaytime = true,
	ClaimQuest = true,
	ClaimIndex = true,
	DevPurchase = true,
	OpenGate = true,
	Rebirth = true,
	CraftPet = true,
	DeletePets = true,
}
local holds: { [string]: number } = {} -- name -> os.clock() deadline

local function isBusy(name: string): boolean
	if busy[name] then
		return true
	end
	local h = holds[name]
	if h and os.clock() < h then
		return true
	end
	holds[name] = nil
	return false
end

local function release(name: string, succeeded: boolean)
	busy[name] = false
	if succeeded and HOLD_AFTER_SUCCESS[name] then
		holds[name] = os.clock() + 1.5
	end
end

-- The next snapshot carries the result, so lift every hold then.
State.Changed:Connect(function()
	table.clear(holds)
end)

-- Returns the result table when ok, nil otherwise (after showing a toast).
-- `quiet` suppresses the error toast.
function Remote.Call(name: string, ...: any): Result?
	local args = table.pack(...)
	local ok, res = pcall(function()
		return Net.Function(name):InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn("[Remote] " .. name .. " failed: " .. tostring(res))
		Toasts.Show("Couldn't reach the server. Try again!", "bad")
		return nil
	end
	if type(res) ~= "table" then
		Toasts.Show("Something went wrong. Try again!", "bad")
		return nil
	end
	if res.ok ~= true then
		Toasts.Show(tostring(res.err or "That didn't work."), "bad")
		return nil
	end
	return res
end

-- Same as Call but ignores repeated taps while a call with this name is in
-- flight (and, for claims and purchases, until the result shows up).
function Remote.CallOnce(name: string, ...: any): Result?
	if isBusy(name) then
		return nil
	end
	busy[name] = true
	local ok, res = pcall(Remote.Call, name, ...)
	release(name, ok and res ~= nil)
	if not ok then
		warn("[Remote] " .. tostring(res))
		return nil
	end
	return res
end

-- Like Call but shows no toast: returns (result, nil) or (nil, readable error)
-- so the caller can add its own hint. Guarded like CallOnce: returns
-- (nil, nil) when the same call is already in flight.
function Remote.Try(name: string, ...: any): (Result?, string?)
	if isBusy(name) then
		return nil, nil
	end
	busy[name] = true
	local args = table.pack(...)
	local ok, res = pcall(function()
		return Net.Function(name):InvokeServer(table.unpack(args, 1, args.n))
	end)
	release(name, ok and type(res) == "table" and res.ok == true)
	if not ok then
		warn("[Remote] " .. name .. " failed: " .. tostring(res))
		return nil, "Couldn't reach the server. Try again!"
	end
	if type(res) ~= "table" then
		return nil, "Something went wrong. Try again!"
	end
	if res.ok ~= true then
		return nil, tostring(res.err or "That didn't work.")
	end
	return res, nil
end

-- Same as Call, but errors are not shown (for background polling-style calls).
function Remote.Quiet(name: string, ...: any): Result?
	local args = table.pack(...)
	local ok, res = pcall(function()
		return Net.Function(name):InvokeServer(table.unpack(args, 1, args.n))
	end)
	if ok and type(res) == "table" and res.ok == true then
		return res
	end
	return nil
end

function Remote.Fire(name: string, ...: any)
	local args = table.pack(...)
	local ok, err = pcall(function()
		Net.Event(name):FireServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn("[Remote] " .. name .. " fire failed: " .. tostring(err))
	end
end

return Remote
