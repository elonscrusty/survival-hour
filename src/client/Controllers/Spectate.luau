--!nonstrict
-- Spectator camera for players who are down or eliminated. Cycles through
-- living clanmates first, then everyone else still alive in the match.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UI = require("../UI/UI")
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local Theme = require("../UI/Theme")

local Spectate = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local index = 1
local bar: Frame
local nameLabel: TextLabel

local function candidates(): { Player }
	local mine, others = {}, {}
	local team = player:GetAttribute("Team")
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("InMatch") and p:GetAttribute("LifeState") == "Alive" and p.Character then
			if p:GetAttribute("Team") == team then
				table.insert(mine, p)
			else
				table.insert(others, p)
			end
		end
	end
	for _, p in others do
		table.insert(mine, p)
	end
	return mine
end

local function spectating(): boolean
	local st = player:GetAttribute("LifeState")
	return player:GetAttribute("InMatch") == true and (st == "Eliminated" or st == "AwaitingRevive")
end

function Spectate.Start()
	local gui = UI.new("ScreenGui", { Name = "Spectate", ResetOnSpawn = false, DisplayOrder = 4, Parent = player:WaitForChild("PlayerGui") })
	bar = UI.panel({ Size = UDim2.fromOffset(420, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Visible = false, Parent = gui })
	UI.Buttons.icon("◀", { Size = UDim2.fromOffset(60, 48), Position = UDim2.fromOffset(6, 6), TextSize = 24, Parent = bar }, function()
		index -= 1
	end)
	UI.Buttons.icon("▶", { Size = UDim2.fromOffset(60, 48), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), TextSize = 24, Parent = bar }, function()
		index += 1
	end)
	local leave = UI.Buttons.action("🏠 Return to lobby", { Size = UDim2.fromOffset(220, 42), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), Tone = "Neutral", Parent = bar }, function()
		Net.Event("LeaveMatch"):FireServer()
	end)
	leave.Name = "Leave"
	nameLabel = UI.text("", { Position = UDim2.fromOffset(70, 0), Size = UDim2.new(1, -140, 1, 0), TextSize = 16, Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = bar })

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		if spectating() then
			local list = candidates()
			bar.Visible = true
			local leaveBtn = bar:FindFirstChild("Leave") :: GuiObject?
			if leaveBtn then
				leaveBtn.Visible = player:GetAttribute("LifeState") == "Eliminated"
			end
			if #list == 0 then
				nameLabel.Text = "No one left to watch"
				return
			end
			index = ((index - 1) % #list) + 1
			local target = list[index]
			local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if hum and camera.CameraSubject ~= hum then
				camera.CameraSubject = hum
			end
			-- only public match info: name, whether their fire is out, survivors left, day/night
			local ms = game:GetService("ReplicatedStorage"):FindFirstChild("MatchState")
			local t = target:GetAttribute("Team")
			local finalLife = ms and t and ms:GetAttribute("Fire" .. tostring(t)) == false
			local left = ms and ms:GetAttribute("Remaining")
			local phase = ms and ms:GetAttribute("Phase")
			local day = ms and ms:GetAttribute("Day")
			local extra = {}
			if finalLife then
				table.insert(extra, "FINAL LIFE")
			end
			if type(left) == "number" then
				table.insert(extra, tostring(left) .. " left")
			end
			if (phase == "Day" or phase == "Night") and type(day) == "number" then
				table.insert(extra, phase .. " " .. tostring(day))
			end
			nameLabel.Text = "Watching " .. target.DisplayName .. (if t == player:GetAttribute("Team") then " (clanmate)" else "") .. (if #extra > 0 then "  ·  " .. table.concat(extra, " · ") else "")
		else
			bar.Visible = false
			local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if myHum and camera.CameraSubject ~= myHum and player:GetAttribute("LifeState") ~= "Respawning" then
				camera.CameraSubject = myHum
			end
		end
	end)
end

return Spectate
