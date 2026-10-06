--!strict
local protectedCall: any = pcall
-- Shared server helpers: player join / leave hooks, the remote wrapper
-- (rate limit + loaded-profile check + pcall + uniform error results),
-- argument validation, notifications and character queries.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Logic = Shared:WaitForChild("Logic")
local RateLimiter = require(Logic:WaitForChild("RateLimiter"))

local Util = {}

local ctx: any
local joinHooks: { (Player) -> () } = {}
local leaveHooks: { (Player) -> () } = {}
local joined: { [Player]: boolean } = {}
local limiter = RateLimiter.New()

-- Calls per second (Rate) and burst size (Burst) for each remote. Anything
-- not listed uses DEFAULT_LIMIT.
local DEFAULT_LIMIT = { Rate = 4, Burst = 8 }
Util.Limits = {
 MountInput = { Rate = 15, Burst = 20 },
 BattleMove = { Rate = 3, Burst = 5 },
 BattleSwap = { Rate = 2, Burst = 3 },
	HatchEgg = { Rate = 3, Burst = 4 },
	EquipPet = { Rate = 10, Burst = 20 },
	LockPet = { Rate = 10, Burst = 20 },
	DeletePets = { Rate = 3, Burst = 6 },
	CraftPet = { Rate = 3, Burst = 6 },
	SetTarget = { Rate = 10, Burst = 20 },
	ClientReady = { Rate = 0.5, Burst = 3 },
	TradeSetOffer = { Rate = 6, Burst = 12 },
	TradeRequest = { Rate = 1, Burst = 3 },
	DevPurchase = { Rate = 1, Burst = 3 },
	DevAction = { Rate = 2, Burst = 5 },
	SetSetting = { Rate = 5, Burst = 10 },
} :: { [string]: { Rate: number, Burst: number } }

function Util.Init(c)
	ctx = c
	Players.PlayerAdded:Connect(Util.FirePlayerAdded)
	Players.PlayerRemoving:Connect(function(p)
		for _, fn in leaveHooks do
			local ok, err = protectedCall(fn, p)
			if not ok then
				warn("[Util] leave hook error:", err)
			end
		end
		joined[p] = nil
		RateLimiter.Forget(limiter, p)
	end)
end

-- Runs join hooks for players who arrived before the hooks were connected.
function Util.Start()
	for _, p in Players:GetPlayers() do
		Util.FirePlayerAdded(p)
	end
end

function Util.OnPlayerAdded(fn: (Player) -> ())
	table.insert(joinHooks, fn)
end

-- `first`: run before the other leave hooks (e.g. cancel a trade before saving).
function Util.OnPlayerRemoving(fn: (Player) -> (), first: boolean?)
	if first then
		table.insert(leaveHooks, 1, fn)
	else
		table.insert(leaveHooks, fn)
	end
end

function Util.FirePlayerAdded(p: Player)
	if joined[p] then
		return
	end
	joined[p] = true
	for _, fn in joinHooks do
		task.spawn(function()
			local ok, err = protectedCall(fn, p)
			if not ok then
				warn("[Util] join hook error:", err)
			end
		end)
	end
end

local function allow(player: Player, name: string): boolean
	return RateLimiter.Allow(limiter, player, name, Util.Limits[name] or DEFAULT_LIMIT, os.clock())
end

function Util.Fail(err: string): { ok: boolean, err: string }
	return { ok = false, err = err }
end

-- Connects a RemoteFunction. The handler gets (player, session, ...args) and
-- returns a result table. Players whose profile isn't loaded yet, rate
-- limited calls and handler errors all get { ok = false, err = ... }.
function Util.Function(name: string, handler: (Player, any, ...any) -> any)
	Net.Function(name).OnServerInvoke = function(player: Player, ...)
		if not allow(player, name) then
			return Util.Fail("Slow down a little")
		end
		local session = ctx.DataService.Get(player)
		if not session then
			return Util.Fail("Still loading your data")
		end
		if session.TradeBusy or session.Profile.PendingTrade then
			-- A trade swap is saving; nothing may change this profile meanwhile.
			return Util.Fail("Finishing your trade, one moment")
		end
		local ok, result = protectedCall(handler, player, session, ...)
		if not ok then
			warn(string.format("[%s] error from %s: %s", name, player.Name, tostring(result)))
			return Util.Fail("Something went wrong")
		end
		if type(result) ~= "table" then
			return { ok = true }
		end
		return result
	end
end

-- Connects a client -> server RemoteEvent with the same protections.
function Util.Event(name: string, handler: (Player, any, ...any) -> ())
	Net.Event(name).OnServerEvent:Connect(function(player: Player, ...)
		if not allow(player, name) then
			return
		end
		local session = ctx.DataService.Get(player)
		if not session then
			return
		end
		if session.TradeBusy or session.Profile.PendingTrade then return end
		local ok, err = protectedCall(handler, player, session, ...)
		if not ok then
			warn(string.format("[%s] error from %s: %s", name, player.Name, tostring(err)))
		end
	end)
end

-- Notifications ---------------------------------------------------------------

function Util.Notify(player: Player, kind: string, data: any)
	if player.Parent == nil then
		return
	end
	Net.Event("Notify"):FireClient(player, kind, data)
end

function Util.Toast(player: Player, text: string, tone: string?)
	Util.Notify(player, "Toast", { Text = text, Tone = tone or "info" })
end

function Util.NotifyAll(kind: string, data: any)
	Net.Event("Notify"):FireAllClients(kind, data)
end

-- Validation ------------------------------------------------------------------

function Util.IsFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Util.IsInt(n: any, lo: number?, hi: number?): boolean
	if not Util.IsFinite(n) or n ~= math.floor(n) then
		return false
	end
	if lo and n < lo then
		return false
	end
	if hi and n > hi then
		return false
	end
	return true
end

function Util.IsStr(s: any, maxLen: number?): boolean
	return type(s) == "string" and #s > 0 and #s <= (maxLen or 64)
end

function Util.IsBool(b: any): boolean
	return type(b) == "boolean"
end

-- Characters ------------------------------------------------------------------

function Util.Root(player: Player): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Util.Position(player: Player): Vector3?
	local root = Util.Root(player)
	return if root then root.Position else nil
end

function Util.DistTo(player: Player, pos: Vector3): number
	local p = Util.Position(player)
	if not p then
		return math.huge
	end
	return (p - pos).Magnitude
end

return Util
