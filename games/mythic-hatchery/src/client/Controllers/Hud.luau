--!strict
-- HUD: coins/gems with animated counters, side menu buttons with
-- notification dots, active boost timers, server luck banner, island banner
-- (from AreaBounds parts) and flying coin/gem pickups.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Areas = require(Shared:WaitForChild("Areas"))
local Pets = require(Shared:WaitForChild("Pets"))
local Types = require(Shared:WaitForChild("Types"))

local State = require("../Core/State")
local Format = require("../Core/Format")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Toasts = require("../UI/Toasts")

type PlayerState = Types.PlayerState

local Hud = {}

local player = Players.LocalPlayer

local gui: ScreenGui
local coinsLabel: TextLabel
local gemsLabel: TextLabel
local coinIcon: GuiObject
local gemIcon: GuiObject
local boostsFrame: Frame
local luckBanner: Frame
local autoPill: Frame
local dots: { [string]: Frame } = {}

local shown = { Coins = 0, Gems = 0 }
local target = { Coins = 0, Gems = 0 }
local currentArea: string? = nil

-- Side menu: window name, icon, label, tone, keyboard shortcut.
local MENU = {
	{ Name = "Pets", Icon = Theme.Icons.Pets, Label = "Pets", Tone = "Yellow", Key = Enum.KeyCode.P },
	{ Name = "Shop", Icon = Theme.Icons.Shop, Label = "Shop", Tone = "Pink", Key = Enum.KeyCode.M },
	{ Name = "Expeditions", Icon = Theme.Icons.Expeditions, Label = "Trips", Tone = "Green", Key = Enum.KeyCode.X },
	{ Name = "Quests", Icon = Theme.Icons.Quests, Label = "Quests", Tone = "Purple", Key = Enum.KeyCode.J },
	{ Name = "Index", Icon = Theme.Icons.Index, Label = "Index", Tone = "Cyan", Key = Enum.KeyCode.I },
	{ Name = "Islands", Icon = Theme.Icons.Islands, Label = "Islands", Tone = "Blue", Key = Enum.KeyCode.N },
	{ Name = "Trade", Icon = Theme.Icons.Trade, Label = "Trade", Tone = "Red", Key = Enum.KeyCode.T },
	{ Name = "Settings", Icon = Theme.Icons.Settings, Label = "Settings", Tone = "Grey", Key = Enum.KeyCode.K },
}

local function currencyPill(icon: string, color: Color3, order: number, onPlus: (() -> ())?): (Frame, TextLabel, GuiObject)
	local f: Frame = Kit.panel({
		Name = "Currency" .. order,
		Size = UDim2.fromOffset(190, 50),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Corner = 25,
		LayoutOrder = order,
	})
	local iconLabel = Kit.fitLabel(icon, 34, {
		Name = "Icon",
		Size = UDim2.fromOffset(46, 46),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -8, 0.5, 0),
		Parent = f,
	})
	local value = Kit.fitLabel("0", 30, {
		Name = "Value",
		Size = UDim2.new(1, if onPlus then -92 else -52, 1, -8),
		Position = UDim2.fromOffset(42, 4),
		Outline = Theme.Darken(color, 0.55),
		Color = color,
		Parent = f,
	})
	if onPlus then
		Kit.button("+", "Green", {
			Size = UDim2.fromOffset(40, 40),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -5, 0.5, 0),
			TextSize = 30,
			Parent = f,
		}, onPlus)
	end
	return f, value, iconLabel
end

local function buildTop()
	local top: Frame = Kit.box({
		Name = "Top",
		Size = UDim2.fromOffset(420, 56),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center) })
	Kit.autoScale(top, 1.05)
	local cf, cl, ci = currencyPill(Theme.Icons.Coins, Theme.Colors.Coins, 1, nil)
	cf.Parent = top
	coinsLabel, coinIcon = cl, ci
	local gf, gl, gi = currencyPill(Theme.Icons.Gems, Theme.Colors.Gems, 2, function()
		Windows.Open("Shop", "Gems")
	end)
	gf.Parent = top
	gemsLabel, gemIcon = gl, gi

	luckBanner = Kit.pill("", Theme.Colors.Luck, {
		Name = "ServerLuck",
		Size = UDim2.fromOffset(330, 36),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Visible = false,
		Parent = gui,
	})
	Kit.autoScale(luckBanner, 1.05)
end

local function buildSide()
	local side: Frame = Kit.box({
		Name = "Side",
		Size = UDim2.fromOffset(176, 360),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.45, 0),
		Parent = gui,
	}, { Kit.grid(Vector2.new(82, 82), 8) })
	Kit.autoScale(side, 1)
	for i, item in MENU do
		local b = Kit.button("", item.Tone, {
			Name = item.Name,
			Size = UDim2.fromOffset(82, 82),
			LayoutOrder = i,
		}, function()
			Windows.Toggle(item.Name)
		end)
		Kit.fitLabel(item.Icon, 40, {
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.fromOffset(0, 4),
			ZIndex = 3,
			Parent = b,
		})
		Kit.fitLabel(item.Label, 18, {
			Size = UDim2.new(1, -4, 0, 22),
			Position = UDim2.new(0, 2, 1, -26),
			Outline = true,
			ZIndex = 3,
			Parent = b,
		})
		b.Parent = side
		local dot: Frame = Kit.new("Frame", {
			Name = "Dot",
			Size = UDim2.fromOffset(28, 28),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			BackgroundColor3 = Theme.Colors.Bad,
			Visible = false,
			ZIndex = 6,
			Parent = b,
		}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(Color3.new(1, 1, 1), 2) })
		Kit.fitLabel("!", 18, { Name = "Count", Size = UDim2.fromScale(1, 1), Outline = true, ZIndex = 7, Parent = dot })
		dots[item.Name] = dot
	end
end

local function buildBoosts()
	boostsFrame = Kit.box({
		Name = "Boosts",
		Size = UDim2.fromOffset(170, 200),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 70),
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right) })
	Kit.autoScale(boostsFrame, 1)
end

local function buildAutoPill()
	autoPill = Kit.panel({
		Name = "AutoHatch",
		Size = UDim2.fromOffset(330, 58),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Visible = false,
		Corner = 29,
		Parent = gui,
	})
	Kit.autoScale(autoPill, 1)
	Kit.fitLabel(Theme.Icons.Egg .. " Auto hatching...", 22, {
		Name = "Text",
		Size = UDim2.new(1, -130, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		Align = "Left",
		Parent = autoPill,
	})
end

-- Shows or hides the "Auto hatching" pill at the bottom of the screen.
local stopConn: RBXScriptConnection? = nil
function Hud.SetAutoHatch(text: string?, onStop: (() -> ())?)
	autoPill.Visible = text ~= nil
	if text then
		local l = autoPill:FindFirstChild("Text") :: TextLabel
		l.Text = text
	end
	local old = autoPill:FindFirstChild("Stop")
	if old then
		old:Destroy()
	end
	if stopConn then
		stopConn:Disconnect()
		stopConn = nil
	end
	if text and onStop then
		Kit.button("Stop", "Red", {
			Name = "Stop",
			Size = UDim2.fromOffset(104, 46),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Parent = autoPill,
		}, onStop)
	end
end

-- Absolute screen position of a currency icon's centre.
function Hud.Target(kind: string): Vector2
	local icon = if kind == "Gems" then gemIcon else coinIcon
	return icon.AbsolutePosition + icon.AbsoluteSize / 2
end

function Hud.Bump(kind: string)
	local label = if kind == "Gems" then gemsLabel else coinsLabel
	local pill = label.Parent :: GuiObject
	Kit.pop(pill, 1.15)
end

-- Flies a few coin/gem icons from a world position to the HUD counter.
function Hud.FlyFrom(worldPos: Vector3, kind: string, count: number?)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local screenPt, onScreen = cam:WorldToScreenPoint(worldPos)
	if not onScreen then
		Hud.Bump(kind)
		return
	end
	-- children are positioned relative to the ScreenGui, whose origin is moved
	-- by the safe-area insets (notches, top bar)
	local origin = gui.AbsolutePosition
	local pt = Vector2.new(screenPt.X, screenPt.Y) - origin
	local goal = Hud.Target(kind) - origin
	local n = math.clamp(count or 5, 1, 8)
	for i = 1, n do
		local icon = Kit.fitLabel(if kind == "Gems" then Theme.Icons.Gems else Theme.Icons.Coins, 30, {
			Size = UDim2.fromOffset(34, 34),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(pt.X, pt.Y),
			ZIndex = 20,
			Parent = gui,
		})
		local spread = Vector2.new(math.random(-60, 60), math.random(-60, 20))
		task.delay((i - 1) * 0.05, function()
			Kit.tween(icon, 0.22, { Position = UDim2.fromOffset(pt.X + spread.X, pt.Y + spread.Y) }, Enum.EasingStyle.Quad)
			task.wait(0.22)
			local t = Kit.tween(icon, 0.45, { Position = UDim2.fromOffset(goal.X, goal.Y), Size = UDim2.fromOffset(22, 22) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			t.Completed:Wait()
			icon:Destroy()
			if i == 1 then
				Hud.Bump(kind)
				Sounds.Play(if kind == "Gems" then "Gem" else "Coin")
			end
		end)
	end
end

local function setDot(name: string, count: number)
	local d = dots[name]
	if not d then
		return
	end
	d.Visible = count > 0
	local l = d:FindFirstChild("Count") :: TextLabel?
	if l then
		l.Text = if count > 9 then "9+" else tostring(count)
	end
end

local function refreshDots()
	local d = State.Data
	if not d then
		return
	end
	local now = State.Now()
	-- Expeditions ready to claim
	local ready = 0
	for _, e in d.Expeditions do
		if e.EndAt <= now then
			ready += 1
		end
	end
	setDot("Expeditions", ready)
	-- Quests / daily / playtime
	local q = 0
	if d.Daily.CanClaim then
		q += 1
	end
	for _, quest in d.Quests do
		if not quest.Claimed and quest.Progress >= quest.Goal then
			q += 1
		end
	end
	local minutes = State.SessionMinutes()
	for i, gift in Config.PlaytimeGifts do
		if not d.Playtime.Claimed[tostring(i)] and minutes >= (gift.Minutes or 0) then
			q += 1
		end
	end
	setDot("Quests", q)
	-- Index tiers
	local found = 0
	for _ in d.Index do
		found += 1
	end
	local total = #Pets.List
	local idx = 0
	for tier, r in Config.IndexRewards do
		if not d.IndexClaimed[tostring(tier)] and total > 0 and found / total >= (r.Fraction or 1) then
			idx += 1
		end
	end
	setDot("Index", idx)
end

local boostRows: { [string]: Frame } = {}

local function boostRow(key: string, text: string, color: Color3): Frame
	local existing = boostRows[key]
	if existing then
		return existing
	end
	local row = Kit.pill(text, color, { Name = key, Size = UDim2.fromOffset(170, 36) })
	row.Parent = boostsFrame
	boostRows[key] = row
	return row
end

local function refreshTimers()
	local d = State.Data
	if not d then
		return
	end
	local seen: { [string]: boolean } = {}
	for key, _ in d.Boosts do
		local left = State.BoostLeft(key)
		-- paid luck doesn't apply when the policy restricts paid random items
		if left > 0 and (d.CanBuyGemEggs or not string.find(key, "Luck")) then
			seen[key] = true
			local def = Config.Boosts[key]
			local name = if def then def.Name else key
			local color = if string.find(key, "Luck") then Theme.Colors.Luck else Theme.Colors.Coins
			local row = boostRow(key, "", color)
			Kit.setPill(row, Theme.Icons.Boost .. " " .. name .. "  " .. Format.time(left))
		end
	end
	for key, row in boostRows do
		if not seen[key] then
			row:Destroy()
			boostRows[key] = nil
		end
	end
	local luck = State.ServerLuckLeft()
	luckBanner.Visible = luck > 0 and d.CanBuyGemEggs == true
	if luckBanner.Visible then
		Kit.setPill(luckBanner, Theme.Icons.Luck .. " Server Luck x" .. tostring(Config.ServerLuckMult) .. "  " .. Format.time(luck))
	end
end

local function onState(d: PlayerState)
	target.Coins = d.Coins
	target.Gems = d.Gems
	refreshDots()
	refreshTimers()
end

-- Island banner: which AreaBounds box contains the character.
local function areaAt(pos: Vector3): string?
	for _, part in CollectionService:GetTagged("AreaBounds") do
		if part:IsA("BasePart") then
			local rel = part.CFrame:PointToObjectSpace(pos)
			local half = part.Size / 2
			if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
				local id = part:GetAttribute("AreaId")
				if type(id) == "string" then
					return id
				end
			end
		end
	end
	return nil
end

function Hud.CurrentArea(): string?
	return currentArea
end

local function checkArea()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local id = areaAt(root.Position)
	if id and id ~= currentArea then
		currentArea = id
		local a = Areas.ById[id]
		if a then
			Toasts.Banner(a.Name, a.Blurb, Theme.Colors.Coins, 3)
		end
	end
end

function Hud.Init()
	gui = Windows.Gui("Hud")
	buildTop()
	buildSide()
	buildBoosts()
	buildAutoPill()

	State.Changed:Connect(onState)
	if State.Data then
		onState(State.Data)
		shown.Coins = State.Data.Coins
		shown.Gems = State.Data.Gems
	end
	State.Ready:Connect(function(d: PlayerState)
		-- don't count up from zero on join
		shown.Coins = d.Coins
		shown.Gems = d.Gems
	end)

	-- animated counters (ease towards the real value)
	game:GetService("RunService").RenderStepped:Connect(function(dt: number)
		for _, kind in { "Coins", "Gems" } do
			local cur, goal = shown[kind], target[kind]
			if cur ~= goal then
				local nextV = cur + (goal - cur) * math.min(1, dt * 8)
				if math.abs(goal - nextV) < math.max(1, math.abs(goal) * 0.0005) then
					nextV = goal
				end
				shown[kind] = nextV
			end
		end
		coinsLabel.Text = Format.num(shown.Coins)
		gemsLabel.Text = Format.num(shown.Gems)
	end)

	task.spawn(function()
		while true do
			refreshTimers()
			refreshDots()
			checkArea()
			task.wait(0.5)
		end
	end)

	-- keyboard shortcuts (PC)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		for _, item in MENU do
			if input.KeyCode == item.Key then
				Windows.Toggle(item.Name)
			end
		end
	end)
end

return Hud
