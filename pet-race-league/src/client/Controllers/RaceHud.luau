-- Race screens: queue banner, countdown, live place/timer/progress, checkpoint
-- flashes, finish feed and the results board.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RaceRules = require(Shared.Logic.RaceRules)
local UI = require(script.Parent.Parent.UI)
local Notify = require(script.Parent.Notify)

local RaceHud = {}

local player = Players.LocalPlayer
local MEDAL_COLORS = { Gold = Color3.fromRGB(255, 205, 50), Silver = Color3.fromRGB(205, 210, 220), Bronze = Color3.fromRGB(215, 140, 80) }

local queueBanner: Frame
local queueText: TextLabel
local lastQueue = 0
local race: Frame
local placeText: TextLabel
local timeText: TextLabel
local trackText: TextLabel
local medalText: TextLabel
local progressFill: Frame
local big: TextLabel
local results: Frame
local leaveBtn: TextButton

local function flash(text: string, color: Color3?, hold: number?)
	big.Text = text
	big.TextColor3 = color or Color3.new(1, 1, 1)
	big.TextTransparency = 0
	big.TextStrokeTransparency = 0
	big.Visible = true
	big.Size = UDim2.fromOffset(260, 110)
	TweenService:Create(big, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(340, 140) }):Play()
	local token = {}
	big:SetAttribute("Token", tostring(token))
	task.delay(hold or 0.8, function()
		if big:GetAttribute("Token") == tostring(token) then
			TweenService:Create(big, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function showResults(data: any)
	results:ClearAllChildren()
	results.Visible = true
	UI.Corner(results, 16)
	UI.Stroke(results, Color3.fromRGB(15, 15, 25), 3)
	UI.Text({ Text = data.Track .. " - Results", Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 8) }, results)
	for i, r in data.Rows do
		local y = 52 + (i - 1) * 30
		local line = string.format("%s  %s", RaceRules.PlaceText(r.Place), r.Name)
		UI.Text({ Text = line, Size = UDim2.new(0.6, -10, 0, 26), Position = UDim2.fromOffset(16, y), TextXAlignment = Enum.TextXAlignment.Left, Font = UI.Body }, results)
		UI.Text({
			Text = if r.Finished and r.Time then RaceRules.FormatTime(r.Time) else "DNF",
			Size = UDim2.new(0.25, 0, 0, 26),
			Position = UDim2.new(0.6, 0, 0, y),
			Font = UI.Body,
			TextColor3 = if r.Medal then MEDAL_COLORS[r.Medal] else UI.Colors.Muted,
		}, results)
	end
	local m = data.Mine
	if m then
		local parts = { "+" .. m.Coins .. " coins" }
		if m.Trophies > 0 then
			table.insert(parts, "+" .. m.Trophies .. " trophies")
		end
		if m.Medal then
			table.insert(parts, m.Medal .. " medal!")
		end
		if m.NewBest then
			table.insert(parts, "New best time!")
		end
		UI.Text({ Text = table.concat(parts, "   "), Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0, 10, 1, -44), TextColor3 = UI.Colors.Gold }, results)
		flash(RaceRules.PlaceText(m.Place), if m.Place == 1 then UI.Colors.Gold else Color3.new(1, 1, 1), 2)
	end
	results.Size = UDim2.fromOffset(420, 110 + #data.Rows * 30)
end

local function onRace(kind: string, data: any)
	if kind == "Queue" then
		lastQueue = os.clock()
		queueBanner.Visible = true
		queueText.Text = string.format("Race starts in %d  -  %d racer%s ready", data.In, data.Count, if data.Count == 1 then "" else "s")
	elseif kind == "Start" then
		queueBanner.Visible = false
		results.Visible = false
		race.Visible = true
		trackText.Text = data.Track
		medalText.Text = string.format("Gold %s   Silver %s   Bronze %s", RaceRules.FormatTime(data.Medals.Gold), RaceRules.FormatTime(data.Medals.Silver), RaceRules.FormatTime(data.Medals.Bronze))
		placeText.Text = ""
		timeText.Text = "0:00.00"
		progressFill.Size = UDim2.fromScale(0, 1)
	elseif kind == "Count" then
		flash(tostring(data), UI.Colors.Gold, 0.7)
	elseif kind == "Go" then
		flash("GO!", UI.Colors.Green, 0.8)
	elseif kind == "Standing" then
		placeText.Text = RaceRules.PlaceText(data.Place) .. " / " .. data.Of
		timeText.Text = RaceRules.FormatTime(math.max(0, data.Time))
		progressFill.Size = UDim2.fromScale(math.clamp(data.Progress, 0, 1), 1)
		if data.EndsIn < 15 then
			timeText.TextColor3 = UI.Colors.Red
		else
			timeText.TextColor3 = Color3.new(1, 1, 1)
		end
	elseif kind == "Checkpoint" then
		Notify.Show("Checkpoint " .. data.Index .. "/" .. data.Total, "Xp")
	elseif kind == "Fell" then
		flash("Oops!", UI.Colors.Red, 0.8)
	elseif kind == "Hurry" then
		Notify.Show(string.format("Someone finished! %d seconds left!", math.floor(data.EndsIn)), "Info")
	elseif kind == "Finished" then
		Notify.Show(string.format("%s finished %s (%s)", data.Name, RaceRules.PlaceText(data.Place), RaceRules.FormatTime(data.Time)), "Level")
	elseif kind == "Results" then
		race.Visible = false
		showResults(data)
	end
end

function RaceHud.Start()
	local screen = UI.Screen()
	queueBanner = UI.Frame({ Size = UDim2.fromOffset(460, 50), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), BackgroundColor3 = UI.Colors.Pink, Visible = false }, screen)
	UI.Corner(queueBanner, 14)
	UI.Stroke(queueBanner, Color3.fromRGB(20, 20, 30), 2)
	UI.Pad(queueBanner, 6)
	queueText = UI.Text({ Size = UDim2.fromScale(1, 1) }, queueBanner)

	race = UI.Frame({ Size = UDim2.fromOffset(420, 110), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.15, Visible = false }, screen)
	UI.Corner(race, 14)
	trackText = UI.Text({ Size = UDim2.new(0.5, -10, 0, 26), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Muted }, race)
	placeText = UI.Text({ Size = UDim2.new(0.5, -10, 0, 44), Position = UDim2.fromOffset(10, 32), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Gold }, race)
	timeText = UI.Text({ Size = UDim2.new(0.5, -10, 0, 44), Position = UDim2.new(0.5, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right }, race)
	medalText = UI.Text({ Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 1, -40), TextColor3 = UI.Colors.Muted, Font = UI.Body }, race)
	local bar = UI.Frame({ Size = UDim2.new(1, -20, 0, 10), Position = UDim2.new(0, 10, 1, -18), BackgroundColor3 = Color3.fromRGB(20, 20, 30) }, race)
	UI.Corner(bar, 5)
	progressFill = UI.Frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.Colors.Green }, bar)
	UI.Corner(progressFill, 5)

	big = UI.Text({ Size = UDim2.fromOffset(340, 140), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Visible = false, TextStrokeTransparency = 0, ZIndex = 20 }, screen)

	results = UI.Frame({ Size = UDim2.fromOffset(420, 300), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Visible = false, ZIndex = 15 }, screen)

	leaveBtn = UI.Button({ Text = "Leave race", Size = UDim2.fromOffset(130, 40), Position = UDim2.new(0, 10, 0, 160), BackgroundColor3 = UI.Colors.Red, Visible = false }, screen, function()
		Net.Event("LeaveRace"):FireServer()
	end)

	Net.Event("Race").OnClientEvent:Connect(onRace)
	player:GetAttributeChangedSignal("InRace"):Connect(function()
		local inRace = player:GetAttribute("InRace") == true
		leaveBtn.Visible = inRace
		if not inRace then
			race.Visible = false
			results.Visible = false
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if queueBanner.Visible and os.clock() - lastQueue > 1.5 then
				queueBanner.Visible = false
			end
		end
	end)
end

return RaceHud
