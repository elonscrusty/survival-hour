--!strict
-- Client boot: starts every controller (each in its own pcall so one failure
-- can't take the whole UI down), then tells the server the UI is ready.

local StarterGui = game:GetService("StarterGui")

local State = require("./Core/State")
local Sounds = require("./Core/Sounds")
local Breakables = require("./Core/Breakables")
local Remote = require("./Core/Remote")

local Hud = require("./Controllers/Hud")
local World = require("./Controllers/World")
local Farming = require("./Controllers/Farming")
local PetRenderer = require("./Controllers/PetRenderer")
local Shop = require("./Controllers/Shop")
local Hatch = require("./Controllers/Hatch")
local Inventory = require("./Controllers/Inventory")
local Craft = require("./Controllers/Craft")
local Expeditions = require("./Controllers/Expeditions")
local Quests = require("./Controllers/Quests")
local IndexMenu = require("./Controllers/IndexMenu")
local Rebirth = require("./Controllers/Rebirth")
local Settings = require("./Controllers/Settings")
local Trade = require("./Controllers/Trade")
local Notifications = require("./Controllers/Notifications")
local Tutorial = require("./Controllers/Tutorial")
local DevPanel = require("./Controllers/DevPanel")

-- the game has no tools, so hide the empty backpack bar
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local function start(name: string, init: () -> ())
	local ok, err = pcall(init :: any)
	if not ok then
		warn("[Client] " .. name .. " failed to start: " .. tostring(err))
	end
end

-- State first so nothing misses the first snapshot.
start("State", State.Init)
start("Sounds", Sounds.Init)
start("Breakables", Breakables.Init)
start("Hud", Hud.Init)
start("World", World.Init)
start("Farming", Farming.Init)
start("PetRenderer", PetRenderer.Init)
start("Shop", Shop.Init)
start("Hatch", Hatch.Init)
start("Inventory", Inventory.Init)
start("Craft", Craft.Init)
start("Expeditions", Expeditions.Init)
start("Quests", Quests.Init)
start("IndexMenu", IndexMenu.Init)
start("Rebirth", Rebirth.Init)
start("Settings", Settings.Init)
start("Trade", Trade.Init)
start("Notifications", Notifications.Init)
start("Tutorial", Tutorial.Init)
start("DevPanel", DevPanel.Init)

Remote.Fire("ClientReady")

-- If the first snapshot is lost (e.g. the server was still loading the
-- profile), ask again a few times.
task.spawn(function()
	for _ = 1, 5 do
		task.wait(5)
		if State.Data then
			return
		end
		Remote.Fire("ClientReady")
	end
end)
