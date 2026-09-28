--!nonstrict
-- Sprint input: hold Shift / L3 (PC, gamepad) or tap the on-screen RUN button (touch
-- toggle). The server owns stamina and speed (StaminaService); this only reports intent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local State = require("../State")
local UI = require("../UI/UI")

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
		local btn = UI.Buttons.round("🏃", "RUN", 56, "Neutral", { Name = "Sprint", Position = UDim2.new(1, -85, 1, -375), AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui })
		btn.Activated:Connect(function()
			State.Emit("Action", { Name = "SprintToggle", Down = true })
		end)
		State.On("SprintWanted", function(v)
			UI.Buttons.setTone(btn, if v then "Green" else "Neutral")
		end)
	end
end

return Movement
