--!nonstrict
-- Egg Farm server bootstrap. Picks production or test adapters, starts services in order, and
-- runs the player lifecycle: claim plot -> load save -> spawn character -> play -> release.
-- The test place is detected by ServerScriptService.TestHarness (only test.project.json has it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameInfo = require(Shared.GameInfo)
local Net = require(Shared.Net) -- creates the remotes
local _ = Net

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local FarmService = require(Services.FarmService)
local PlotService = require(Services.PlotService)
local ZoneService = require(Services.ZoneService)
local CommerceService = require(Services.CommerceService)
local FoxService = require(Services.FoxService)
local World = require(script.Parent:WaitForChild("World"):WaitForChild("World"))

Players.CharacterAutoLoads = false

local harness = ServerScriptService:FindFirstChild("TestHarness")
local ctx: any = {
	World = World,
	DataService = DataService,
	FarmService = FarmService,
	PlotService = PlotService,
	ZoneService = ZoneService,
	CommerceService = CommerceService,
	FoxService = FoxService,
	IsTest = harness ~= nil,
}

if harness then
	-- TEST PLACE: memory saves + simulated checkout + dev tools. Never used by the real game.
	local setup = require(harness:WaitForChild("TestSetup"))
	setup.Configure(ctx)
	print("[EggFarm] TEST PLACE: in-memory saves, simulated checkout. Nothing here touches real data.")
else
	local Adapter = require(script.Parent.Persistence.ProfileStoreAdapter)
	ctx.PersistenceAdapter = Adapter.new(GameInfo.SaveStoreName, DataService.Template())
end

DataService.Init(ctx)
PlotService.Init(ctx)
FarmService.Init(ctx)
ZoneService.Init(ctx)
CommerceService.Init(ctx)
FoxService.Init(ctx)
if ctx.AfterInit then
	ctx.AfterInit(ctx)
end
FarmService.Start()
ZoneService.Start()

local function spawnCharacter(player: Player)
	if player.Parent ~= Players then
		return
	end
	player:LoadCharacter()
end

local function onCharacter(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	local farm = FarmService.Get(player)
	if farm then
		hum.WalkSpeed = farm:Snapshot(FarmService.Now()).walkSpeed
	end
	hum.Died:Connect(function()
		task.delay(3, spawnCharacter, player)
	end)
end

local function onJoin(player: Player)
	player.CharacterAdded:Connect(function(c)
		onCharacter(player, c)
	end)
	local index = PlotService.Claim(player)
	if not index then
		player:Kick("This server is full. Please join another server!")
		return
	end
	local ok = FarmService.Load(player)
	if not ok then
		PlotService.Release(player)
		return
	end
	spawnCharacter(player)
	FoxService.StartFor(player)
end

local function onLeave(player: Player)
	FoxService.Cleanup(player)
	FarmService.Unload(player)
	PlotService.Release(player)
end

Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(onLeave)
for _, p in Players:GetPlayers() do
	task.spawn(onJoin, p)
end

game:BindToClose(function()
	-- ProfileStore also flushes on close; releasing here makes the memory adapter consistent too
	for _, p in Players:GetPlayers() do
		pcall(onLeave, p)
	end
end)
