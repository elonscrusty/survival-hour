-- Always-on HUD: coins, trophies, league, and the main buttons (Pets, Shop,
-- Ride/Walk, Dash). Keyboard: Shift or Q = dash, R = ride/walk.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RaceRules = require(Shared.Logic.RaceRules)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)

local Hud = {}

local player = Players.LocalPlayer
Hud.Buttons = {} :: { [string]: TextButton }
local openers: { [string]: () -> () } = {}

-- Other controllers register their menus here so the buttons can open them.
function Hud.SetOpener(name: string, fn: () -> ())
	openers[name] = fn
end

local function stat(parent: Instance, order: number, icon: string, color: Color3): TextLabel
	local f = UI.Frame({ Size = UDim2.fromOffset(170, 40), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.15, LayoutOrder = order }, parent)
	UI.Corner(f, 20)
	UI.Stroke(f, Color3.fromRGB(15, 15, 25), 2)
	UI.Text({ Text = icon, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(4, 3), TextColor3 = color }, f)
	return UI.Text({ Text = "0", Size = UDim2.new(1, -46, 1, -8), Position = UDim2.fromOffset(40, 4), TextXAlignment = Enum.TextXAlignment.Left }, f)
end

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

local function dash()
	Net.Event("Dash"):FireServer()
end

local function toggleRide()
	Net.Event("Ride"):FireServer(not player:GetAttribute("Riding"))
end

function Hud.Start()
	local screen = UI.Screen()

	-- Top-left stats
	local stats = UI.Frame({ Size = UDim2.fromOffset(180, 140), Position = UDim2.fromOffset(10, 10), BackgroundTransparency = 1 }, screen)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = stats
	local coins = stat(stats, 1, "$", UI.Colors.Gold)
	local trophies = stat(stats, 2, "T", Color3.fromRGB(255, 170, 60))
	local league = stat(stats, 3, "L", UI.Colors.Blue)

	State.OnChange(function(d)
		coins.Text = fmt(d.Coins)
		trophies.Text = fmt(d.Trophies)
		local idx, lg = RaceRules.League(d.Trophies)
		local nextL = require(Shared.Config).Leagues[idx + 1]
		league.Text = lg.Name .. if nextL then string.format(" (%d)", nextL.Min - d.Trophies) else ""
		league.TextColor3 = UI.Rgb(lg.Color)
	end)

	-- Bottom-right buttons (thumb reach on phones)
	local pad = UI.Frame({ Size = UDim2.fromOffset(250, 250), Position = UDim2.new(1, -10, 1, -10), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1 }, screen)
	local isTouch = UserInputService.TouchEnabled
	if isTouch then
		-- leave room for Roblox's jump button
		pad.Position = UDim2.new(1, -150, 1, -10)
	end

	local dashBtn = UI.Button({ Text = "DASH", Size = UDim2.fromOffset(110, 110), Position = UDim2.new(1, 0, 1, 0), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = UI.Colors.Pink }, pad, dash)
	UI.Corner(dashBtn, 55)
	local charges = UI.Text({ Text = "", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -28), TextColor3 = UI.Colors.Gold }, dashBtn)
	local rideBtn = UI.Button({ Text = "WALK", Size = UDim2.fromOffset(110, 56), Position = UDim2.new(1, -120, 1, 0), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = UI.Colors.Green }, pad, toggleRide)
	local petsBtn = UI.Button({ Text = "PETS", Size = UDim2.fromOffset(110, 56), Position = UDim2.new(1, -120, 1, -64), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = UI.Colors.Blue }, pad, function()
		if openers.Pets then
			openers.Pets()
		end
	end)
	local shopBtn = UI.Button({ Text = "SHOP", Size = UDim2.fromOffset(110, 56), Position = UDim2.new(1, 0, 1, -120), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = UI.Colors.Gold }, pad, function()
		if openers.Shop then
			openers.Shop()
		end
	end)
	Hud.Buttons = { Dash = dashBtn, Ride = rideBtn, Pets = petsBtn, Shop = shopBtn }

	local function refreshAttrs()
		local riding = player:GetAttribute("Riding")
		rideBtn.Text = if riding then "WALK" else "RIDE"
		rideBtn.BackgroundColor3 = if riding then UI.Colors.PanelLight else UI.Colors.Green
		local c = player:GetAttribute("DashCharges") or 0
		local m = player:GetAttribute("DashMax") or 0
		charges.Text = string.rep("o", c) .. string.rep(".", math.max(0, m - c))
		dashBtn.BackgroundTransparency = if riding and c > 0 then 0 else 0.5
		local inRace = player:GetAttribute("InRace") == true
		rideBtn.Visible = not inRace
		petsBtn.Visible = not inRace
		shopBtn.Visible = not inRace
	end
	for _, a in { "Riding", "DashCharges", "DashMax", "InRace" } do
		player:GetAttributeChangedSignal(a):Connect(refreshAttrs)
	end
	refreshAttrs()

	ContextActionService:BindAction("PetDash", function(_, st)
		if st == Enum.UserInputState.Begin then
			dash()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("PetRide", function(_, st)
		if st == Enum.UserInputState.Begin and not player:GetAttribute("InRace") then
			toggleRide()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
end

return Hud
