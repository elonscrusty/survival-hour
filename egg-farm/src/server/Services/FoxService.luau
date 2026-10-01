--!nonstrict
-- The Lucky Fox (reported in the reference as a random clickable fox that pays cash). Every few
-- minutes a fox appears at one of the owner's FoxSpots for a short time. Only the plot owner can
-- catch it, through a ProximityPrompt (the server checks owner + distance again before paying).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FoxService = {}

local MIN_GAP, MAX_GAP = 150, 300 -- seconds between foxes
local LIFETIME = 40
local CATCH_DISTANCE = 14

local ctx
local active: { [Player]: Model } = {}
local rng = Random.new()

local function buildFox(): Model
	local models = ReplicatedStorage.Shared:FindFirstChild("Models")
	local builder = models and models:FindFirstChild("Fox")
	if builder then
		local ok, m = pcall(function()
			local mod = require(builder)
			return if type(mod) == "function" then mod() elseif type(mod) == "table" and mod.Build then mod.Build() else nil
		end)
		if ok and typeof(m) == "Instance" and m:IsA("Model") then
			return m
		end
	end
	-- simple fallback fox made of parts
	local m = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(1.6, 1.4, 3)
	body.Color = Color3.fromRGB(232, 120, 40)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.Parent = m
	local head = body:Clone()
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.3, 1.4)
	head.CFrame = body.CFrame * CFrame.new(0, 0.6, -1.9)
	head.Parent = m
	local tail = body:Clone()
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.8, 0.8, 1.8)
	tail.Color = Color3.fromRGB(250, 240, 230)
	tail.CFrame = body.CFrame * CFrame.new(0, 0.4, 2.1) * CFrame.Angles(math.rad(25), 0, 0)
	tail.Parent = m
	m.PrimaryPart = body
	return m
end

local function despawn(player: Player)
	local fox = active[player]
	active[player] = nil
	if fox then
		fox:Destroy()
	end
end

local function spawnFox(player: Player)
	local farm = ctx.FarmService.Get(player)
	local zones = ctx.PlotService.Zones(player)
	if not farm or not farm.state.tutorial.done or not zones or not zones.foxSpots or #zones.foxSpots == 0 then
		return
	end
	despawn(player)
	local spot = zones.foxSpots[rng:NextInteger(1, #zones.foxSpots)]
	local fox = buildFox()
	fox.Name = "LuckyFox"
	for _, d in fox:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	fox:PivotTo(CFrame.new(spot + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Catch!"
	prompt.ObjectText = "Lucky Fox"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Fox", true)
	prompt.Parent = fox.PrimaryPart or fox:FindFirstChildWhichIsA("BasePart")
	fox:SetAttribute("OwnerUserId", player.UserId)
	prompt.Triggered:Connect(function(who: Player)
		if who ~= player or active[player] ~= fox then
			return -- only the owner, only once
		end
		local character = who.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - fox:GetPivot().Position).Magnitude > CATCH_DISTANCE then
			return
		end
		active[player] = nil
		local f = ctx.FarmService.Get(player)
		if f then
			f:CatchFox(ctx.FarmService.Now())
			ctx.FarmService.Push(player, true)
		end
		fox:Destroy()
	end)
	local plot = ctx.PlotService.PlotOf(player)
	fox.Parent = plot or workspace
	active[player] = fox
	task.delay(LIFETIME, function()
		if active[player] == fox then
			despawn(player)
		end
	end)
end

function FoxService.Init(c)
	ctx = c
end

function FoxService.StartFor(player: Player)
	task.spawn(function()
		while player.Parent == Players and ctx.FarmService.Get(player) do
			task.wait(rng:NextNumber(MIN_GAP, MAX_GAP))
			if player.Parent ~= Players then
				break
			end
			spawnFox(player)
		end
	end)
end

function FoxService.SpawnNow(player: Player)
	spawnFox(player)
end

function FoxService.Cleanup(player: Player)
	despawn(player)
end

return FoxService
