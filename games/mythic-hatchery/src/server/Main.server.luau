--!strict
-- Server entry point. Creates the remotes, then loads every service in order:
-- each gets the shared `ctx` table (ctx.<ServiceName>) in Init, and Start
-- (if any) runs in its own thread once every service is initialised.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

Net.Init()

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
 "Util", "WorldService", "DataService", "StateService", "BoostService",
 "CreatureService", "HatchService", "HabitatService", "BattleService", "RideService",
 "ExpeditionService", "RewardService", "RebirthService", "PurchaseService", "TradeService", "DevService",
}

local ctx: any = {
	IsStudio = RunService:IsStudio(),
}

ctx.Util = require(Services:WaitForChild("Util"))
ctx.WorldService = require(Services:WaitForChild("WorldService"))
ctx.DataService = require(Services:WaitForChild("DataService"))
ctx.StateService = require(Services:WaitForChild("StateService"))
ctx.BoostService = require(Services:WaitForChild("BoostService"))
ctx.CreatureService = require(Services:WaitForChild("CreatureService"))
ctx.HatchService = require(Services:WaitForChild("HatchService"))
ctx.HabitatService = require(Services:WaitForChild("HabitatService"))
ctx.BattleService = require(Services:WaitForChild("BattleService"))
ctx.RideService = require(Services:WaitForChild("RideService"))
ctx.ExpeditionService = require(Services:WaitForChild("ExpeditionService"))
ctx.RewardService = require(Services:WaitForChild("RewardService"))
ctx.RebirthService = require(Services:WaitForChild("RebirthService"))
ctx.PurchaseService = require(Services:WaitForChild("PurchaseService"))
ctx.TradeService = require(Services:WaitForChild("TradeService"))
ctx.DevService = require(Services:WaitForChild("DevService"))

for _, name in ORDER do
	local service = ctx[name]
	if type(service.Init) == "function" then
		local ok, err = pcall(service.Init, ctx)
		if not ok then
			error(string.format("[Main] %s.Init failed: %s", name, tostring(err)))
		end
	end
end

for _, name in ORDER do
	local service = ctx[name]
	if type(service.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(service.Start)
			if not ok then
				warn(string.format("[Main] %s.Start failed: %s", name, tostring(err)))
			end
		end)
	end
end

print("[MythicHatchery] server ready")
