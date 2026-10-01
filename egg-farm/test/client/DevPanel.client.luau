--!nonstrict
-- TEST PLACE ONLY: a small developer panel (toggle with the "DEV" button or F8) that calls the
-- server's DevCommand remote. Lets a tester reach late-game states and exercise saves/checkout
-- without touching production balance. Not part of build/EggFarm.rbxlx.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
-- The button always appears; the server's DevCommand remote is looked up in the background. If it
-- never arrives, the server's test setup failed: the panel says so (check the Output window).
local remote: RemoteFunction? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "DevPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(84, 36)
toggle.Position = UDim2.new(0.5, -42, 0, 100)
toggle.Text = "DEV"
toggle.Font = Enum.Font.GothamBlack
toggle.TextSize = 18
toggle.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
toggle.TextColor3 = Color3.fromRGB(30, 30, 40)
toggle.Parent = gui
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)

local panel = Instance.new("ScrollingFrame")
panel.Visible = false
panel.Size = UDim2.fromOffset(220, 360)
panel.Position = UDim2.new(0.5, -110, 0, 134)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
panel.BackgroundTransparency = 0.1
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.CanvasSize = UDim2.new()
panel.ScrollBarThickness = 6
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local layout = Instance.new("UIListLayout", panel)
layout.Padding = UDim.new(0, 4)
local pad = Instance.new("UIPadding", panel)
pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 22)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(180, 255, 180)
status.Font = Enum.Font.GothamBold
status.TextSize = 12
status.Text = "TEST PLACE (memory saves)"
status.Parent = panel

local function button(label: string, cmd: string, arg: any?)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Text = label
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.Activated:Connect(function()
		if not remote then
			status.Text = "Server dev tools not ready (see Output)"
			return
		end
		local r = remote:InvokeServer(cmd, arg)
		status.Text = if type(r) == "table" then tostring(r.message) else "?"
	end)
end

button("MAX MONEY (cash + gold)", "maxmoney")
button("Upgrade everything +1 level", "upgradeall")
button("Max upgrade everything", "maxall")
button("+ Cash", "cash")
button("+1000 Gold Eggs", "gold")
button("Finish tutorial", "tutorial")
button("Max current farm", "maxed")
for _, n in { 2, 5, 9, 10 } do
	button("Jump to egg " .. n, "egg", n)
end
button("All boosts x3", "boosts")
button("Quests ready", "quests")
button("Fast-forward 10 min", "forward", 600)
button("Simulate 2h offline", "offline", 7200)
button("Next UTC day", "nextday")
button("Spawn Lucky Fox", "fox")
button("Checkout: success", "checkout", "success")
button("Checkout: cancel", "checkout", "cancel")
button("Checkout: fail", "checkout", "fail")
button("Fail next load", "failload")
button("Fail next save", "failsave")
button("Reset my save", "reset")
button("Kick (test rejoin)", "rejoin")

task.spawn(function()
	remote = ReplicatedStorage:WaitForChild("DevCommand", 120) :: RemoteFunction?
	if remote then
		status.Text = "TEST PLACE (memory saves)"
	else
		status.Text = "Server dev tools missing! Check Output for red errors."
		status.TextColor3 = Color3.fromRGB(255, 120, 120)
		toggle.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	end
end)
status.Text = "Waiting for server..."

local function flip()
	panel.Visible = not panel.Visible
end
toggle.Activated:Connect(flip)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F8 then
		flip()
	end
end)
