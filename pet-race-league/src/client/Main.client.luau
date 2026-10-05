-- Client entry: connects remotes and starts each controller.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

Net.Init()

local State = require(script.Parent:WaitForChild("State"))
Net.Event("State").OnClientEvent:Connect(function(data)
	State.Set(data)
end)

local Controllers = script.Parent:WaitForChild("Controllers")
for _, name in { "Sound", "Notify", "PetAnimator", "Hud", "DailyMenu", "PetMenu", "ShopMenu", "HatchView", "RaceHud", "Tutorial" } do
	local ok, err = pcall(function()
		local c = require(Controllers:WaitForChild(name)) :: any
		c.Start()
	end)
	if not ok then
		warn("[Client] " .. name .. " failed: " .. tostring(err))
	end
end
