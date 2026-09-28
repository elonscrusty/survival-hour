--!nonstrict
-- Survival Hour server entry point.
--
-- Mode selection (DECISIONS D1/D2):
--   * Reserved server (PrivateServerId ~= "" and PrivateServerOwnerId == 0) -> "Match"
--   * Anything else -> "Lobby". In Studio the lobby can also host a local match.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))

local Services = script.Parent:WaitForChild("Services")

local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local isStudio = RunService:IsStudio()

local ctx: any = {
	Mode = if isReserved then "Match" else "Lobby",
	IsStudio = isStudio,
	LocalMatches = isStudio and Config.Dev.StudioLocalMatches,
	DevEnabled = isStudio and Config.Dev.DevPanelInStudio,
}

-- The workspace attribute lets clients know the mode without a remote round-trip.
workspace:SetAttribute("ServerMode", ctx.Mode)
workspace:SetAttribute("DevEnabled", ctx.DevEnabled)
workspace:SetAttribute("GameVersion", Config.Version)

Net.Init()

StarterGui.ResetPlayerGuiOnSpawn = false

-- Load order matters only for Init; Start runs after every Init.
local order = {
	"Util",
	"AssetLoaderService",
	"DataService",
	"PurchaseService",
	"WorldService",
	"LobbyService",
	"MatchmakingService",
	"MatchService",
	"CampService",
	"LivesService",
	"InventoryService",
	"ChannelService",
	"StaminaService",
	"CombatService",
	"GatherService",
	"CraftService",
	"BuildService",
	"StorageService",
	"WildlifeService",
	"LootService",
	"EventService",
	"CosmeticService",
	"PowerupService",
	"TelemetryService",
	"DevService",
}

for _, name in order do
	local mod = Services:FindFirstChild(name)
	assert(mod, "Missing service " .. name)
	ctx[name] = require(mod :: ModuleScript)
end

for _, name in order do
	local svc = ctx[name]
	if svc.Init then
		svc.Init(ctx)
	end
end

for _, name in order do
	local svc = ctx[name]
	if svc.Start then
		task.spawn(svc.Start)
	end
end

-- Seasonal event (Config.Seasons): clients read these attributes for the lobby banner,
-- Locker "limited" tags and the seasonal look. Re-checked every minute so an event starts
-- and ends on time in long-running servers.
task.spawn(function()
	while true do
		local season = ctx.Util.Season()
		workspace:SetAttribute("Season", if season then season.Id else nil)
		workspace:SetAttribute("SeasonEnds", if season then season.End else nil)
		task.wait(60)
	end
end)

print(string.format("[SurvivalHour] v%s server started in %s mode%s", Config.Version, ctx.Mode, if isStudio then " (Studio)" else ""))

-- Players who joined before services were ready get the normal join path.
for _, p in Players:GetPlayers() do
	task.spawn(ctx.Util.FirePlayerAdded, p)
end
