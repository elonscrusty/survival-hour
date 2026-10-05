-- First-time tips: four short cards, shown once per player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)

local Tutorial = {}

local STEPS = {
	{ "Welcome to Pet Race League!", "You're riding your first pet, a Pup. Ride it around!" },
	{ "Train your pet", "SPEED RING: ride through the gates in order.\nJUMP HURDLES: jump over the walls.\nSTAMINA TREADMILL: keep running on the belt." },
	{ "Race!", "Stand on the pink RACE PORTAL. Finish fast for coins, trophies and medals.\nTap DASH for a burst of speed." },
	{ "Hatch new pets", "Spend coins at the EGGS. Rare pets get a small bonus, but training matters most!" },
}

local shown = false

local function show()
	shown = true
	local step = 1
	local card = UI.Frame({ Size = UDim2.fromOffset(440, 220), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 50 }, UI.Screen())
	UI.Corner(card, 18)
	UI.Stroke(card, UI.Colors.Gold, 3)
	local title = UI.Text({ Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 10), TextColor3 = UI.Colors.Gold, ZIndex = 51 }, card)
	local body = UI.Text({ Size = UDim2.new(1, -24, 0, 100), Position = UDim2.fromOffset(12, 54), Font = UI.Body, TextScaled = false, TextSize = 18, TextWrapped = true, ZIndex = 51 }, card)
	local nextBtn: TextButton
	local function render()
		title.Text = STEPS[step][1]
		body.Text = STEPS[step][2]
		nextBtn.Text = if step == #STEPS then "Let's go!" else "Next"
	end
	nextBtn = UI.Button({ Text = "Next", Size = UDim2.fromOffset(160, 46), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), BackgroundColor3 = UI.Colors.Green, ZIndex = 51 }, card, function()
		if step < #STEPS then
			step += 1
			render()
		else
			card:Destroy()
			Net.Event("TutorialDone"):FireServer()
		end
	end)
	render()
end

function Tutorial.Start()
	State.OnChange(function(d)
		if not shown and not d.Tutorial then
			show()
		end
	end)
end

return Tutorial
