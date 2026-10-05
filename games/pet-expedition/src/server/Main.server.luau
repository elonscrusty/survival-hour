--!nonstrict
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
	"Util",
	"DataService",
	"StateService",
	"BoostService",
	"WorldService",
	"PetService",
	"HatchService",
	"BreakableService",
	"ExpeditionService",
	"RewardService",
	"RebirthService",
	"PurchaseService",
	"TradeService",
}

local ctx: any = {
	IsStudio = RunService:IsStudio(),
}

for _, name in ORDER do
	ctx[name] = require(Services:WaitForChild(name))
end

for _, name in ORDER do
	local service = ctx[name]
	if type(service.Init) == "function" then
		local ok, err = pcall(service.Init, ctx)
		if not ok then
			warn(string.format("[Main] %s.Init failed: %s", name, tostring(err)))
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

print("[PetExpedition] server ready")
