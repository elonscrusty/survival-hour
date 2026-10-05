-- Toasts: short messages from the server. "Xp" pops small above the buttons,
-- "Rare" is a big gold banner, everything else stacks at the top.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI)

local Notify = {}

local stack: Frame
local xpArea: Frame

local KIND_COLORS = {
	Info = UI.Colors.PanelLight,
	Error = UI.Colors.Red,
	Coins = Color3.fromRGB(220, 160, 30),
	Level = UI.Colors.Green,
	Rare = UI.Colors.Pink,
}

function Notify.Show(text: string, kind: string?)
	kind = kind or "Info"
	if kind == "Xp" then
		local t = UI.Text({
			Text = text,
			Size = UDim2.fromOffset(160, 30),
			Position = UDim2.new(0.5, math.random(-60, 60), 1, -10),
			AnchorPoint = Vector2.new(0.5, 1),
			TextColor3 = UI.Colors.Gold,
			TextStrokeTransparency = 0.2,
		}, xpArea)
		TweenService:Create(t, TweenInfo.new(1.1), { Position = t.Position - UDim2.fromOffset(0, 80), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(1.2, function()
			t:Destroy()
		end)
		return
	end
	local big = kind == "Rare"
	local f = UI.Frame({
		Size = UDim2.new(1, 0, 0, if big then 54 else 40),
		BackgroundColor3 = KIND_COLORS[kind :: string] or KIND_COLORS.Info,
		BackgroundTransparency = 0.05,
	}, stack)
	UI.Corner(f, 10)
	UI.Stroke(f, Color3.fromRGB(20, 20, 30), 2)
	UI.Pad(f, 6)
	UI.Text({ Text = text, Size = UDim2.fromScale(1, 1) }, f)
	task.delay(if big then 5 else 3, function()
		TweenService:Create(f, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.wait(0.3)
		f:Destroy()
	end)
end

function Notify.Start()
	stack = UI.Frame({
		Name = "Toasts",
		Size = UDim2.new(0.5, 0, 0, 300),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 30,
	}, UI.Screen())
	local c = Instance.new("UISizeConstraint")
	c.MinSize = Vector2.new(260, 0)
	c.MaxSize = Vector2.new(520, 300)
	c.Parent = stack
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = stack
	xpArea = UI.Frame({
		Name = "XpArea",
		Size = UDim2.fromOffset(300, 200),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
	}, UI.Screen())
	Net.Event("Notify").OnClientEvent:Connect(Notify.Show)
end

return Notify
