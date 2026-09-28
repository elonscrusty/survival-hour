--!nonstrict
-- Survival Hour client entry point. Presentation only: every gameplay action
-- is a request that the server validates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

if not game:IsLoaded() then
	game.Loaded:Wait()
end
ReplicatedStorage:WaitForChild("Shared")
ReplicatedStorage:WaitForChild("Remotes")
ReplicatedStorage:WaitForChild("MatchState")

local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent:WaitForChild("State"))

-- Hide default inventory UI; keep chat, player list and the reset button.
for _, t in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(t, false)
	end)
end

-- Route server pushes into the store.
Net.Event("InventorySync").OnClientEvent:Connect(function(snap)
	State.Set("Inventory", snap)
end)
Net.Event("ProfileSync").OnClientEvent:Connect(function(view)
	State.Set("Profile", view)
end)
Net.Event("LobbySync").OnClientEvent:Connect(function(view)
	State.Set("Lobby", view)
end)
Net.Event("CraftSync").OnClientEvent:Connect(function(view)
	State.Set("Craft", view)
	if view.Open then
		State.Emit("OpenPanel", "Craft")
	end
end)
Net.Event("AbilitySync").OnClientEvent:Connect(function(view)
	State.Set("Ability", view)
end)
Net.Event("MapData").OnClientEvent:Connect(function(data)
	State.Set("Map", data)
end)
Net.Event("StorageSync").OnClientEvent:Connect(function(key, items, mode, capacity, meta)
	State.Set("Storage", { Key = key, Items = items, Mode = mode, Capacity = capacity, Meta = meta or {} })
end)
Net.Event("ChannelState").OnClientEvent:Connect(function(s)
	State.Emit("Channel", s)
end)
Net.Event("Notify").OnClientEvent:Connect(function(text, kind)
	State.Emit("Notify", { Text = text, Kind = kind })
end)
Net.Event("MatchEvent").OnClientEvent:Connect(function(name, payload)
	State.Emit("MatchEvent", { Name = name, Data = payload })
end)
Net.Event("HitFeedback").OnClientEvent:Connect(function(kind, amount, pos)
	State.Emit("Hit", { Kind = kind, Amount = amount, Pos = pos })
end)
Net.Event("Fx").OnClientEvent:Connect(function(name, payload)
	State.Emit("Fx", { Name = name, Data = payload })
end)
Net.Event("Reveal").OnClientEvent:Connect(function(kind, list, duration)
	State.Emit("Reveal", { Kind = kind, List = list, Duration = duration })
end)

-- Start controllers (each module exposes Start()).
local order = {
	"Sound",
	"Camera",
	"Input",
	"Movement",
	"Prompts",
	"Hud",
	"Notifications",
	"Panels",
	"Inventory",
	"Craft",
	"Build",
	"Storage",
	"Shop",
	"Lobby",
	"Map",
	"Combat",
	"Animation",
	"Creatures",
	"Effects",
	"Guide",
	"Spectate",
	"Dev",
}
local Controllers = script.Parent:WaitForChild("Controllers")
for _, name in order do
	local mod = Controllers:WaitForChild(name, 10)
	if mod then
		local ok, ctrl = pcall(require, mod)
		if ok and type(ctrl) == "table" and ctrl.Start then
			task.spawn(function()
				local ok2, err = pcall(ctrl.Start)
				if not ok2 then
					warn("[Client] " .. name .. " failed to start:", err)
				end
			end)
		elseif not ok then
			warn("[Client] " .. name .. " failed to load:", ctrl)
		end
	end
end

Net.Event("ClientReady"):FireServer()
local _ = Players
