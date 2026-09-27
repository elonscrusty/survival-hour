--!nonstrict
-- Sprint input: hold Shift / L3 (PC, gamepad) or tap the on-screen RUN button (touch
-- toggle). The server owns stamina and speed (StaminaService); this only reports intent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local State = require("../State")
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")

local Movement = {}

local player = Players.LocalPlayer
local sprinting = false

local function set(want: boolean)
	if want ~= sprinting then
		sprinting = want
		Net.Event("Sprint"):FireServer(want)
		State.Set("SprintWanted", want)
	end
end

function Movement.Start()
	State.On("Action", function(a)
		if a.Name == "Sprint" then
			set(a.Down)
		elseif a.Name == "SprintToggle" and a.Down then
			set(not sprinting)
		end
	end)
	-- Stop sprinting after death so the next life starts walking.
	player:GetAttributeChangedSignal("LifeState"):Connect(function()
		if player:GetAttribute("LifeState") ~= "Alive" then
			set(false)
		end
	end)
	-- Touch: a RUN toggle next to the jump button.
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("TouchControls", 5)
	if gui then
		local btn = UI.new("TextButton", {
			Name = "Sprint",
			Size = UDim2.fromOffset(58, 58),
			Position = UDim2.new(1, -90, 1, -350),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.25,
			Text = "RUN",
			Font = Theme.FontBlack,
			TextScaled = true,
			TextColor3 = Theme.Colors.Text,
			Parent = gui,
		}, { UI.corner(UDim.new(0.5, 0)), UI.stroke(Theme.Colors.Accent, 2, 0.3) })
		btn.Activated:Connect(function()
			State.Emit("Action", { Name = "SprintToggle", Down = true })
		end)
		State.On("SprintWanted", function(v)
			btn.BackgroundColor3 = if v then Theme.Colors.AccentDark else Theme.Colors.Panel
		end)
	end
end

return Movement
