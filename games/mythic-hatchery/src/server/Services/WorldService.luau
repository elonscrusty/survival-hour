--!strict
local protectedCall: any = pcall
-- Builds the map (Models/World), tracks which island each player stands on,
-- opens gates and teleports between opened islands. A player found inside an
-- island they haven't opened (e.g. a client that removed the gate barrier) is
-- sent back to their furthest opened island.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Areas = require(Shared:WaitForChild("Areas"))
local Models = Shared:WaitForChild("Models")
local World = require(Models:WaitForChild("World"))
local Logic = Shared:WaitForChild("Logic")
local Economy = require(Logic:WaitForChild("Economy"))

local WorldService = {}

local ctx: any
WorldService.Info = { Spawns = {}, Zones = {}, Bounds = {}, Arena = { Center = Vector3.zero, Radius = 0 } } :: World.WorldInfo
local currentArea: { [Player]: string } = {}

local CHECK_INTERVAL = 1
local TELEPORT_COOLDOWN = 2
local LOCKED_MARGIN = 12 -- studs inside a locked island before a player is sent back

function WorldService.Init(c)
	ctx = c
	local ok, result = protectedCall(World.Build)
	if ok and type(result) == "table" then
		WorldService.Info = result
		-- Owned mounts use server physics; gates are enforced by region ownership.
		for _, gate in CollectionService:GetTagged("Gate") do
			local barrier = gate:FindFirstChild("Barrier", true)
			if barrier and barrier:IsA("BasePart") then barrier.CanCollide = false end
		end
	else
		error("[WorldService] World.Build failed: " .. tostring(result))
	end

	ctx.Util.OnPlayerRemoving(function(p)
		currentArea[p] = nil
	end)

	ctx.Util.Function("OpenGate", function(player, s, areaId)
		if not ctx.Util.IsStr(areaId, 32) or not Areas.ById[areaId] then
			return ctx.Util.Fail("Unknown island")
		end
		local ok2, err = Economy.OpenGate(s.Profile, areaId)
		if not ok2 then
			return ctx.Util.Fail(err or "Can't open that gate")
		end
		ctx.Util.Toast(player, Areas.ById[areaId].Name .. " is open!", "good")
		ctx.StateService.Dirty(player)
		return { ok = true }
	end)

	ctx.Util.Function("Teleport", function(player, s, areaId)
		if not ctx.Util.IsStr(areaId, 32) or not Areas.ById[areaId] then
			return ctx.Util.Fail("Unknown island")
		end
		if not s.Profile.Areas[areaId] then
			return ctx.Util.Fail("Open that island first")
		end
		local now = os.clock()
		if s.LastTeleport and now - s.LastTeleport < TELEPORT_COOLDOWN then
			return ctx.Util.Fail("Slow down a little")
		end
		if not WorldService.TeleportTo(player, areaId) then
			return ctx.Util.Fail("Can't teleport right now")
		end
		s.LastTeleport = now
		return { ok = true }
	end)
end

function WorldService.Start()
	while true do
		task.wait(CHECK_INTERVAL)
		for _, p in Players:GetPlayers() do
			local ok, err = protectedCall(WorldService._check, p)
			if not ok then
				warn("[WorldService] area check failed:", err)
			end
		end
	end
end

-- Island id containing a position, or nil. `margin` shrinks each island's box
-- horizontally (so standing right at a gate never counts as being inside).
function WorldService.AreaAt(pos: Vector3, margin: number?): string?
	local m = margin or 0
	for id, b in WorldService.Info.Bounds do
		local mn, mx = b.Min, b.Max
		if pos.X >= mn.X + m and pos.X <= mx.X - m and pos.Y >= mn.Y - 100 and pos.Y <= math.max(mx.Y, Config.Ride.MaxAltitude + 20)
			and pos.Z >= mn.Z + m and pos.Z <= mx.Z - m then
			return id
		end
	end
	return nil
end

function WorldService.AreaOf(player: Player): string?
	return currentArea[player]
end

function WorldService.TeleportTo(player: Player, areaId: string): boolean
	local spawn = WorldService.Info.Spawns[areaId]
	local char = player.Character
	if not spawn or not char or not ctx.Util.Root(player) then
		return false
	end
	if ctx.RideService then ctx.RideService.Stop(player) end
	char:PivotTo(spawn + Vector3.new(math.random(-4, 4), 3, math.random(-4, 4)))
	currentArea[player] = areaId
	return true
end

-- Positions of every tagged interactable with a given attribute value.
function WorldService.TaggedPosition(tag: string, attr: string?, value: any): Vector3?
	for _, inst in CollectionService:GetTagged(tag) do
		if attr == nil or inst:GetAttribute(attr) == value then
			if inst:IsA("Model") then
				return inst:GetPivot().Position
			elseif inst:IsA("BasePart") then
				return inst.Position
			end
		end
	end
	return nil
end

function WorldService._check(player: Player)
	local s = ctx.DataService.Get(player)
	local pos = ctx.Util.Position(player)
	if not s or not pos then
		return
	end
	local deep = WorldService.AreaAt(pos, LOCKED_MARGIN)
	if deep and not s.Profile.Areas[deep] then
		local home = Economy.HighestArea(s.Profile)
		if WorldService.TeleportTo(player, home) then
			ctx.Util.Toast(player, "Open the gate to " .. Areas.ById[deep].Name .. " first!", "bad")
		end
		return
	end
	local area = WorldService.AreaAt(pos)
	if area and s.Profile.Areas[area] then
		currentArea[player] = area
	end
end

return WorldService
