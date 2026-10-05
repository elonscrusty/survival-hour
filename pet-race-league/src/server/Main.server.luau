-- Server entry: creates remotes, then starts each service in order.
-- Every service gets the shared ctx table and can reach the others as ctx.<Name>.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

Net.Init()

local Services = script.Parent:WaitForChild("Services")
local order = {
	"Util",
	"AssetLoader",
	"DataService",
	"WorldService",
	"PetService",
	"TrainingService",
	"TrackBuilder",
	"RaceService",
	"ShopService",
	"DailyService",
	"LeaderboardService",
}

local ctx = {}
for _, name in order do
	ctx[name] = require(Services:WaitForChild(name)) :: any
end
for _, name in order do
	local s = ctx[name]
	if s.Init then
		s.Init(ctx)
	end
end
for _, name in order do
	local s = ctx[name]
	if s.Start then
		task.spawn(s.Start)
	end
end
