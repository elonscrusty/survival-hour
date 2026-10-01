--!nonstrict
-- Runs one Economy per player: loads it through DataService, steps it at 4 Hz on the server clock,
-- handles the Action remote (validated, rate limited, atomic), and sends the owner throttled
-- snapshots and events. Never trusts anything from the client beyond the intent it names.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Economy = require(Shared.Logic.Economy)
local RateLimiter = require(Shared.Logic.RateLimiter)
local Modifiers = require(Shared.Logic.Modifiers)
local Codes = require(script.Parent.Parent.Data.Codes)

local FarmService = {}

local TICK = 0.25
local SNAPSHOT_EVERY = 0.25

local farms: { [Player]: any } = {}
local lastSnap: { [Player]: number } = {}
local ctx
-- burst of 25 requests, refilling 14/s: enough for held Spawn (8/s) plus menu taps
local limiter = RateLimiter.new(25, 14)
local readyCallbacks = {}

local timeOffset = 0 -- test place only (dev "next day"); always 0 in the real game

function FarmService.Now(): number
	return workspace:GetServerTimeNow() + timeOffset
end

function FarmService.SetTimeOffset(seconds: number)
	timeOffset = seconds
end

function FarmService.Get(player: Player)
	return farms[player]
end

function FarmService.All()
	return farms
end

function FarmService.OnReady(fn)
	table.insert(readyCallbacks, fn)
end

local function sendEvents(player: Player, farm)
	local events = farm:DrainEvents()
	if #events == 0 then
		return
	end
	local remote = Net.Get("FarmEvent") :: RemoteEvent
	for _, e in events do
		remote:FireClient(player, e.name, e.data)
		ctx.PlotService.OnFarmEvent(player, e.name, e.data)
	end
end

function FarmService.Push(player: Player, force: boolean?)
	local farm = farms[player]
	if not farm then
		return
	end
	sendEvents(player, farm)
	local now = FarmService.Now()
	if farm.dirty and (force or now - (lastSnap[player] or 0) >= SNAPSHOT_EVERY) then
		farm.dirty = false
		lastSnap[player] = now
		local snap = farm:Snapshot(now)
		;(Net.Get("Snapshot") :: RemoteEvent):FireClient(player, snap)
		ctx.PlotService.Sync(player, farm.state, snap)
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = snap.walkSpeed
		end
	end
end

function FarmService.Toast(player: Player, text: string, kind: string?)
	local remoteFarmEvent = Net.Get("FarmEvent") :: RemoteEvent
	remoteFarmEvent:FireClient(player, "Toast", { text = text, kind = kind or "info" })
end

local function onAction(player: Player, action: any)
	local farm = farms[player]
	if not farm then
		return { ok = false, code = "not_ready", message = "Your farm is still loading." }
	end
	if not limiter:Allow(player, os.clock()) then
		return { ok = false, code = "rate_limited", message = "Slow down a little!" }
	end
	local ok, res = pcall(farm.Apply, farm, action, FarmService.Now())
	if not ok then
		warn("[Farm] action error: " .. tostring(res))
		return { ok = false, code = "error", message = "Something went wrong. Try again." }
	end
	FarmService.Push(player, true)
	return res
end

function FarmService.Init(c)
	ctx = c
	local remoteAction = Net.Get("Action") :: RemoteFunction
	remoteAction.OnServerInvoke = onAction
end

-- Called by Main after the player's plot is ready. Yields while the save loads.
function FarmService.Load(player: Player): boolean
	local now = FarmService.Now()
	local state = ctx.DataService.Load(player, now)
	if not state or player.Parent ~= Players then
		return false
	end
	local premium = player.MembershipType == Enum.MembershipType.Premium
	local rng = Random.new()
	local farm = Economy.new(state, {
		premium = premium,
		codes = ctx.Codes or Codes,
		rng = function()
			return rng:NextNumber()
		end,
	})
	farm:ComputeOffline(now)
	farms[player] = farm
	farm.dirty = true
	for _, fn in readyCallbacks do
		task.spawn(fn, player, farm)
	end
	FarmService.Push(player, true)
	return true
end

function FarmService.Unload(player: Player)
	local farm = farms[player]
	if farm then
		farm:Step(math.max(0, FarmService.Now() - farm.state.lastSeen), FarmService.Now())
		farm.state.lastSeen = FarmService.Now()
	end
	farms[player] = nil
	lastSnap[player] = nil
	limiter:Forget(player)
	ctx.DataService.Release(player)
end

function FarmService.Start()
	local acc = 0
	local last = FarmService.Now()
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		local now = FarmService.Now()
		local step = math.clamp(now - last, 0, 5)
		last = now
		for player, farm in farms do
			local ok, err = pcall(farm.Step, farm, step, now)
			if not ok then
				warn("[Farm] step error: " .. tostring(err))
			end
			FarmService.Push(player)
		end
	end)
end

FarmService.Modifiers = Modifiers
return FarmService
