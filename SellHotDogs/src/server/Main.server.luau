--!strict
-- Sell Hot Dogs server entry. Init order matters: World before GameService (plots exist),
-- GameService before Extras (Extras registers actions on it), Data last (starts loading players).
local Services = script.Parent:WaitForChild("Services")

local World = require(Services.World)
local GameService = require(Services.GameService)
local Extras = require(Services.Extras)
local Data = require(Services.Data)

game:GetService("Players").CharacterAutoLoads = true
World.init()
GameService.init()
Extras.init()
Data.init()
print("[SellHotDogs] server ready")
