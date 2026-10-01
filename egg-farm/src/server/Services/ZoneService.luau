--!nonstrict
-- Physical interactions, checked on the server from the character's real position:
-- standing in a house's CollectRing collects; standing in the warehouse DepositRing deposits.
-- Only the player's OWN plot's rings are considered, so nobody can collect from another farm.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ZoneService = {}

local CHECK_EVERY = 0.2
local EXTRA_RADIUS = 2 -- forgiveness around the ring's visible edge
local MAX_HEIGHT = 9

local ctx
-- last checked position per player: a jump far beyond walking speed (teleport exploit, or a
-- respawn) skips ring actions for that check, so rings need real presence across two checks
local lastPos: { [Player]: { pos: Vector3, t: number } } = {}
local SPEED_SLACK = 1.6

-- Horizontal distance check against a flat ring part (radius = half its largest X/Z size).
function ZoneService.Inside(part: BasePart, pos: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(pos)
	local radius = math.max(part.Size.X, part.Size.Z) / 2 + EXTRA_RADIUS
	return (rel.X * rel.X + rel.Z * rel.Z) <= radius * radius and math.abs(rel.Y) <= MAX_HEIGHT
end

local function check(player: Player)
	local farm = ctx.FarmService.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not farm or not root or not hum or hum.Health <= 0 then
		return
	end
	local zones = ctx.PlotService.Zones(player)
	if not zones then
		return
	end
	local now = ctx.FarmService.Now()
	local pos = root.Position
	local prev = lastPos[player]
	lastPos[player] = { pos = pos, t = os.clock() }
	if not prev then
		return
	end
	local flat = Vector3.new(pos.X - prev.pos.X, 0, pos.Z - prev.pos.Z).Magnitude
	if flat > hum.WalkSpeed * SPEED_SLACK * (os.clock() - prev.t) + 6 then
		return
	end
	for slot, ring in zones.collect do
		local h = farm.state.housing[slot]
		if h and h.tier > 0 and h.eggs > 0 and ring.Parent and ZoneService.Inside(ring, pos) then
			farm:Collect(slot, now)
		end
	end
	if farm.state.carried > 0 and zones.deposit and ZoneService.Inside(zones.deposit, pos) then
		farm:Deposit(now)
	end
end

function ZoneService.Init(c)
	ctx = c
end

function ZoneService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastPos[player] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < CHECK_EVERY then
			return
		end
		acc = 0
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(check, player)
			if not ok then
				warn("[Zone] " .. tostring(err))
			end
		end
	end)
end

return ZoneService
