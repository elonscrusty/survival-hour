--!nonstrict
-- Toast notifications (right side), colour + glyph per kind, auto-stacking.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")

local Notifications = {}

local player = Players.LocalPlayer
local list: Frame
local order = 0
local recent: { [string]: number } = {}

function Notifications.Push(text: string, kind: string?)
	local k = kind or "info"
	-- Collapse spam of identical messages (e.g. "+2 Stick")
	local t = os.clock()
	if recent[text] and t - recent[text] < 0.6 then
		return
	end
	recent[text] = t
	order += 1
	local color = Theme.KindColor[k] or Theme.Colors.Info
	local card = UI.panel({ Size = UDim2.fromOffset(320, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = list }, { UI.padding(8) })
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	UI.new("TextLabel", {
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = color,
		Text = Theme.KindGlyph[k] or "i",
		Font = Theme.FontBlack,
		TextSize = 14,
		TextColor3 = Color3.new(0, 0, 0),
		Parent = card,
	}, { UI.corner(UDim.new(0.5, 0)) })
	UI.text(text, { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -30, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, Parent = card })
	-- pop in (quick scale from 0.85), fade everything out at the end
	local pop = UI.new("UIScale", { Scale = 0.85, Parent = card })
	TweenService:Create(pop, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local life = if k == "gain" then 1.8 elseif k == "danger" or k == "error" then 5 else 3.5
	task.delay(life, function()
		if not card.Parent then
			return
		end
		local info = TweenInfo.new(0.3)
		TweenService:Create(card, info, { BackgroundTransparency = 1 }):Play()
		for _, d in card:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.3)
		card:Destroy()
	end)
	local cards = {}
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			table.insert(cards, c)
		end
	end
	if #cards > 5 then
		table.sort(cards, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		cards[1]:Destroy()
	end
end

function Notifications.Start()
	local gui = UI.new("ScreenGui", { Name = "Notifications", ResetOnSpawn = false, DisplayOrder = 20, Parent = player:WaitForChild("PlayerGui") })
	UI.new("UIScale", { Name = "UiScale", Scale = Theme.UiScale, Parent = gui })
	list = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(320, 400),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -150),
		Parent = gui,
	}, { UI.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom) })
	UI.new("UIScale", { Parent = list, Scale = 1 })
	State.On("Notify", function(n)
		Notifications.Push(n.Text, n.Kind)
	end)
end

return Notifications
