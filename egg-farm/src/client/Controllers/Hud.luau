--!strict
-- The always-on HUD.
--   Top centre : Chickens (population / capacity), Cash, Gold Eggs counters (roll + green flash).
--                Below them: basket (carried / carryCap, orange near full, red when full) and a
--                production readout.
--   Left       : Shop, Eggs, Quests.      Right: Settings, Daily, Boosts, Gifts (ready badge).
--   Bottom     : Cash Multiplier (combo / comboMax) above a big red SPAWN button; Auto Spawn
--                toggle beside it; quick "Upgrades" and "Farm" buttons bottom-left.
-- SPAWN: tap = one request; hold repeats ~8/s; keyboard F / gamepad R2 (Controllers/Input).
-- Spawn is disabled while a menu or modal is open (Host blocking). Elements appear as the
-- tutorial reveals them (Logic/Tutorial.Reveals).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tutorial = require(Shared:WaitForChild("Logic"):WaitForChild("Tutorial"))
local Contract = require(Shared:WaitForChild("Contract"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Layout = require(UI.Layout)
local Icon = require(UI.Icon)
local Button = require(UI.Button)
local ProgressBar = require(UI.ProgressBar)
local Num = require(UI.Num)
local Toasts = require(script.Parent.Toasts)
local Sound = require(script.Parent.Sound)
local Common = require(script.Parent.Parent.Menus.Common)

local Hud = {}

Hud.Targets = {} :: { [string]: GuiObject } -- named elements the tutorial can point at
Hud.Root = nil :: Frame?

local REPEAT_RATE = 8 -- spawns per second while held

local store: any
local host: any
local blocked = false
local holding = false
local holdToken = 0
local housingFull = false
local spawnBtn: Button.Handle
local spawnSub: TextLabel
local autoBtn: Button.Handle
local reveal: { [string]: boolean } = Tutorial.Reveals(1, false)

------------------------------------------------------------------------------------------------
-- Counters
------------------------------------------------------------------------------------------------

type Counter = { set: (number, number?) -> (), frame: Frame }

local function counter(parent: Instance, order: number, icon: string, color: Color3, fmt: (number, number?) -> string): Counter
	local f = Instance.new("Frame")
	f.Name = "Counter_" .. icon
	f.LayoutOrder = order
	f.Size = UDim2.fromOffset(146, 52)
	f.BackgroundColor3 = Color3.fromRGB(40, 32, 28)
	f.BackgroundTransparency = 0.15
	Util.Corner(f, nil, 0.5)
	Util.Stroke(f, 3, Theme.Color.Ink, true)
	local ic = Icon.new(icon, 46)
	ic.AnchorPoint = Vector2.new(0, 0.5)
	ic.Position = UDim2.new(0, -6, 0.5, 0)
	ic.ZIndex = 2
	ic.Parent = f
	local label = Util.Text({
		text = "0",
		size = UDim2.new(1, -50, 1, -6),
		position = UDim2.fromOffset(42, 3),
		textSize = Theme.Text.L,
		font = Theme.Font.Number,
		color = color,
		outline = true,
		z = 2,
		parent = f,
	})
	f.Parent = parent

	local nv = Instance.new("NumberValue")
	local extra: number? = nil
	local shown = 0
	nv.Changed:Connect(function(v)
		label.Text = fmt(v, extra)
	end)
	local function set(v: number, ex: number?)
		local changedExtra = ex ~= extra
		extra = ex
		if v == shown then
			if changedExtra then
				label.Text = fmt(v, extra)
			end
			return
		end
		local gained = v > shown
		local first = shown == 0 and nv.Value == 0
		shown = v
		if first or v ~= v then
			nv.Value = v
			label.Text = fmt(v, extra)
			return
		end
		Util.Tween(nv, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = v })
		if gained then
			label.TextColor3 = Theme.Color.Good
			Util.Tween(label, TweenInfo.new(0.6), { TextColor3 = color })
			Util.Pop(f, 0.08)
		end
	end
	return { set = set, frame = f }
end

------------------------------------------------------------------------------------------------
-- Nav buttons
------------------------------------------------------------------------------------------------

type Nav = { button: Button.Handle, badge: TextLabel }

local function navButton(parent: Instance, order: number, label: string, icon: string, color: Color3, onClick: () -> ()): Nav
	local size = Theme.Size.Nav
	local b = Button.new({
		name = label,
		icon = icon,
		iconSize = 38,
		color = color,
		size = UDim2.fromOffset(size, size),
		order = order,
		parent = parent,
		onClick = onClick,
	})
	if b.Icon then
		b.Icon.Position = UDim2.new(0.5, -19, 0, 3)
		b.Icon.AnchorPoint = Vector2.zero
	end
	local cap = Util.Text({
		text = label,
		size = UDim2.new(1, 4, 0, 22),
		position = UDim2.new(0, -2, 1, -26),
		textSize = Theme.Text.S,
		font = Theme.Font.Title,
		outline = true,
		z = 3,
		parent = b.Instance,
	})
	cap.Name = "Caption"
	local badge = Util.Text({
		text = "!",
		size = UDim2.fromOffset(28, 28),
		position = UDim2.new(1, 4, 0, -4),
		anchor = Vector2.new(1, 0),
		textSize = Theme.Text.S,
		font = Theme.Font.Number,
		outline = true,
		z = 4,
		parent = b.Instance,
	})
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Theme.Color.Red
	Util.Corner(badge, nil, 0.5)
	Util.Stroke(badge, 2, Theme.Color.Ink, true)
	badge.Visible = false
	return { button = b, badge = badge }
end

local function setBadge(n: Nav, text: string?)
	local was = n.badge.Visible
	n.badge.Visible = text ~= nil
	n.badge.Text = text or ""
	if text and not was then
		Util.Pop(n.badge, 0.4)
	end
end

------------------------------------------------------------------------------------------------
-- Spawn
------------------------------------------------------------------------------------------------

local function canSpawn(): boolean
	return not blocked and store.Get() ~= nil
end

local function spawnOnce()
	if not canSpawn() then
		return
	end
	local snap = store.Get()
	if housingFull then
		Util.Shake(spawnBtn.Instance)
		Toasts.Show(Contract.Messages.full, "warn")
		return
	end
	if store.IsBusy(store.Key({ type = "spawn" })) then
		return -- one in flight; the next tap/repeat goes after it lands
	end
	task.spawn(function()
		local res = store.Request({ type = "spawn" })
		if res.ok then
			Sound.Play("spawn")
			local cur = store.Get() or snap
			if cur.settings.effects ~= false then
				Toasts.Popup("+" .. Num.Short(cur.spawnPerTap), Theme.Color.Gold, UDim2.new(0.5, 0, 1, -170), "chick")
			end
		elseif res.code == "full" then
			housingFull = true
			Hud._paintSpawn()
			Toasts.Show(res.message or Contract.Messages.full, "warn")
		elseif res.code ~= "busy" and res.code ~= "rate_limited" and res.code ~= "stale" then
			Toasts.Show(res.message or "Couldn't spawn.", "bad")
		end
	end)
end

function Hud.SpawnPress()
	if holding then
		return
	end
	holding = true
	holdToken += 1
	local token = holdToken
	spawnOnce()
	task.spawn(function()
		task.wait(0.35) -- a tap is a single spawn; holding starts repeating
		while holding and token == holdToken do
			spawnOnce()
			task.wait(1 / REPEAT_RATE)
		end
	end)
end

function Hud.SpawnRelease()
	holding = false
end

function Hud._paintSpawn()
	if not spawnBtn then
		return
	end
	if blocked then
		spawnBtn:SetColor(Theme.Color.Gray)
		spawnBtn:SetText("SPAWN")
		spawnSub.Text = ""
	elseif housingFull then
		spawnBtn:SetColor(Theme.Color.GrayDark)
		spawnBtn:SetText("HOUSING FULL")
		spawnSub.Text = "Upgrade your houses"
	else
		spawnBtn:SetColor(Theme.Color.Red)
		spawnBtn:SetText("SPAWN")
		spawnSub.Text = ""
	end
	spawnBtn:SetEnabled(not blocked and not housingFull)
end

------------------------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------------------------

function Hud.Start(s: any, h: any)
	store = s
	host = h
	local _, root = Layout.Layer("EggFarmHud", 5)
	Hud.Root = root

	-- top counters
	local top = Instance.new("Frame")
	top.Name = "Counters"
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 6)
	top.Size = UDim2.fromOffset(470, 56)
	top.Parent = root
	Util.List(top, 10, true, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local chickens = counter(top, 1, "chick", Color3.fromRGB(255, 240, 160), function(v, cap)
		return Num.Short(math.floor(v + 0.5)) .. "/" .. Num.Short(cap or 0)
	end)
	local cash = counter(top, 2, "cash", Theme.Color.Cash, function(v)
		return Num.Cash(math.floor(v))
	end)
	local gold = counter(top, 3, "gold", Theme.Color.Gold, function(v)
		return Num.Short(math.floor(v + 0.5))
	end)
	Hud.Targets.counters = top
	Hud.Targets.cash = cash.frame

	-- basket + production row
	local info = Instance.new("Frame")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.AnchorPoint = Vector2.new(0.5, 0)
	info.Position = UDim2.new(0.5, 0, 0, 64)
	info.Size = UDim2.fromOffset(470, 40)
	info.Parent = root
	Util.List(info, 8, true, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local basket = Instance.new("Frame")
	basket.Name = "Basket"
	basket.Size = UDim2.fromOffset(150, 38)
	basket.BackgroundColor3 = Color3.fromRGB(40, 32, 28)
	basket.BackgroundTransparency = 0.2
	basket.LayoutOrder = 1
	Util.Corner(basket, nil, 0.5)
	local basketStroke = Util.Stroke(basket, 3, Theme.Color.Ink, true)
	local bic = Icon.new("basket", 34)
	bic.Position = UDim2.fromOffset(4, 2)
	bic.Parent = basket
	local basketText = Util.Text({
		text = "0/0",
		size = UDim2.new(1, -44, 1, -4),
		position = UDim2.fromOffset(40, 2),
		textSize = Theme.Text.M,
		font = Theme.Font.Number,
		outline = true,
		parent = basket,
	})
	basket.Parent = info
	local prod = Instance.new("Frame")
	prod.Name = "Production"
	prod.Size = UDim2.fromOffset(300, 38)
	prod.BackgroundColor3 = Color3.fromRGB(40, 32, 28)
	prod.BackgroundTransparency = 0.35
	prod.LayoutOrder = 2
	Util.Corner(prod, nil, 0.5)
	local prodText = Util.Text({
		text = "",
		size = UDim2.new(1, -16, 1, -4),
		position = UDim2.fromOffset(8, 2),
		textSize = Theme.Text.S,
		font = Theme.Font.Title,
		outline = true,
		parent = prod,
	})
	prod.Parent = info
	Hud.Targets.basket = basket

	-- side navigation
	local function column(name: string, x: number, anchorX: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.AnchorPoint = Vector2.new(anchorX, 0.5)
		f.Position = UDim2.new(x, if anchorX == 0 then 8 else -8, 0.44, 0)
		f.Size = UDim2.fromOffset(Theme.Size.Nav + 8, 4 * (Theme.Size.Nav + 10))
		Util.List(f, 10, false, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		f.Parent = root
		return f
	end
	local left = column("LeftNav", 0, 0)
	local right = column("RightNav", 1, 1)
	local shopNav = navButton(left, 1, "Shop", "shop", Theme.Color.Pink, function()
		host:Toggle("Shop")
	end)
	local eggsNav = navButton(left, 2, "Eggs", "egg", Theme.Color.Gold, function()
		host:Toggle("Eggs")
	end)
	local questNav = navButton(left, 3, "Quests", "quest", Theme.Color.Teal, function()
		host:Toggle("Quests")
	end)
	local settingsNav = navButton(right, 1, "Settings", "settings", Theme.Color.GrayDark, function()
		host:Toggle("Settings")
	end)
	local dailyNav = navButton(right, 2, "Daily", "daily", Theme.Color.Red, function()
		host:Toggle("Daily")
	end)
	local boostNav = navButton(right, 3, "Boosts", "booster", Theme.Color.Purple, function()
		host:Toggle("Boosts")
	end)
	local giftNav = navButton(right, 4, "Gifts", "gift", Theme.Color.Orange, function()
		host:Toggle("Gifts")
	end)
	Hud.Targets.shop = shopNav.button.Instance
	Hud.Targets.eggs = eggsNav.button.Instance
	Hud.Targets.gifts = giftNav.button.Instance

	-- quick access (bottom-left)
	local quick = Instance.new("Frame")
	quick.Name = "Quick"
	quick.BackgroundTransparency = 1
	quick.AnchorPoint = Vector2.new(0, 1)
	quick.Position = UDim2.new(0, 8, 1, -10)
	quick.Size = UDim2.fromOffset(Theme.Size.Nav + 8, 2 * Theme.Size.Nav + 10)
	Util.List(quick, 10, false, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
	quick.Parent = root
	local upgradesNav = navButton(quick, 1, "Upgrades", "upgrades", Theme.Color.Green, function()
		host:Toggle("Upgrades")
	end)
	local farmNav = navButton(quick, 2, "Farm", "farm", Theme.Color.Orange, function()
		local snap = store.Get()
		local rev = if snap then Tutorial.Reveals(snap.tutorial.step, snap.tutorial.done) else reveal
		host:Toggle("Farm", if not rev.housing and rev.shipping then "Shipping" else nil)
	end)
	Hud.Targets.upgrades = upgradesNav.button.Instance
	Hud.Targets.farm = farmNav.button.Instance

	-- bottom centre: multiplier + spawn + auto
	local bottom = Instance.new("Frame")
	bottom.Name = "SpawnArea"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -10)
	bottom.Size = UDim2.fromOffset(220, 136)
	bottom.Parent = root

	local comboRow = Instance.new("Frame")
	comboRow.BackgroundTransparency = 1
	comboRow.Size = UDim2.new(1, 0, 0, 40)
	comboRow.Parent = bottom
	local comboIcon = Icon.new("combo", 36)
	comboIcon.Position = UDim2.fromOffset(0, 2)
	comboIcon.ZIndex = 3
	comboIcon.Parent = comboRow
	local combo = ProgressBar.new({
		size = UDim2.new(1, -30, 0, 32),
		position = UDim2.fromOffset(26, 4),
		color = Theme.Color.Orange,
		textSize = Theme.Text.M,
		parent = comboRow,
	})
	Hud.Targets.combo = comboRow

	spawnBtn = Button.new({
		name = "Spawn",
		text = "SPAWN",
		color = Theme.Color.Red,
		size = UDim2.new(1, 0, 0, 86),
		position = UDim2.fromOffset(0, 48),
		textSize = Theme.Text.Huge,
		radius = 22,
		parent = bottom,
	})
	spawnSub = Util.Text({
		text = "",
		size = UDim2.new(1, -16, 0, 22),
		position = UDim2.new(0, 8, 1, -28),
		textSize = Theme.Text.S,
		font = Theme.Font.Title,
		outline = true,
		z = 4,
		parent = spawnBtn.Instance,
	})
	spawnBtn.Label.Size = UDim2.new(1, -16, 1, -24)
	spawnBtn.Instance.MouseButton1Down:Connect(function()
		Hud.SpawnPress()
	end)
	spawnBtn.Instance.MouseButton1Up:Connect(Hud.SpawnRelease)
	spawnBtn.Instance.MouseLeave:Connect(Hud.SpawnRelease)
	spawnBtn.Instance.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			Hud.SpawnRelease()
		end
	end)
	spawnBtn.Instance.Activated:Connect(function()
		if housingFull and not blocked then
			local snap = store.Get()
			if snap then
				local rev = Tutorial.Reveals(snap.tutorial.step, snap.tutorial.done)
				if rev.housing then
					host:Open("Farm", "Housing")
				end
			end
		end
	end)
	Hud.Targets.spawn = spawnBtn.Instance

	autoBtn = Button.new({
		name = "Auto",
		text = "AUTO",
		icon = "auto",
		iconSize = 28,
		color = Theme.Color.Gray,
		size = UDim2.fromOffset(112, 60),
		anchor = Vector2.new(0, 1),
		position = UDim2.new(1, 10, 1, 0),
		textSize = Theme.Text.M,
		parent = bottom,
		onClick = function()
			local snap = store.Get()
			if not snap then
				return
			end
			if not snap.tutorial.done then
				Util.Shake(autoBtn.Instance)
				Sound.Play("error")
				Toasts.Show("Auto Spawn unlocks when you finish the tutorial!", "info")
				return
			end
			local want = not snap.settings.autoSpawn
			local res = store.Request({ type = "setAutoSpawn", value = want })
			if not res.ok and res.code ~= "busy" then
				Util.Shake(autoBtn.Instance)
				Sound.Play("error")
				Toasts.Show(res.message or "Couldn't change Auto Spawn.", "bad")
			end
		end,
	})
	Hud.Targets.auto = autoBtn.Instance

	-- blocking: menus open -> no spawning, no world clicks
	host:OnBlockingChanged(function(on: boolean)
		blocked = on
		if on then
			holding = false
		end
		Hud._paintSpawn()
	end)

	-- portrait phones: keep the auto toggle above the spawn button if there's no room beside it
	local function relayout(_, logical: Vector2)
		-- short landscape phones: there's no vertical room for the quick column under the left
		-- column, so it moves beside it (the left nav is vertically centred)
		if logical.Y < 520 and logical.X > logical.Y then
			quick.Position = UDim2.new(0, Theme.Size.Nav + 26, 1, -10)
		else
			quick.Position = UDim2.new(0, 8, 1, -10)
		end
		if logical.X < 500 then
			autoBtn.Instance.AnchorPoint = Vector2.new(1, 1)
			autoBtn.Instance.Position = UDim2.new(1, 0, 0, -6)
			autoBtn.Instance.Size = UDim2.fromOffset(100, 60)
		else
			autoBtn.Instance.AnchorPoint = Vector2.new(0, 1)
			autoBtn.Instance.Position = UDim2.new(1, 10, 1, 0)
			autoBtn.Instance.Size = UDim2.fromOffset(112, 60)
		end
	end
	Layout.OnChanged(relayout)
	relayout(Layout.Scale(), Layout.Logical())

	-- apply reveals
	local function applyReveal(r: { [string]: boolean })
		reveal = r
		top.Visible = r.counters
		info.Visible = r.counters
		left.Visible = r.nav
		right.Visible = r.nav
		eggsNav.button:SetVisible(r.eggs)
		upgradesNav.button:SetVisible(r.nav)
		farmNav.button:SetVisible(r.shipping or r.housing)
		quick.Visible = r.shipping or r.housing or r.nav
		comboRow.Visible = r.counters
		autoBtn:SetVisible(r.nav)
		spawnBtn:SetVisible(r.spawn)
	end
	applyReveal(reveal)

	local giftCount = 0
	store.OnChanged(function(snap: any)
		applyReveal(Tutorial.Reveals(snap.tutorial.step, snap.tutorial.done))
		chickens.set(snap.population, snap.capacity)
		cash.set(snap.cash)
		gold.set(snap.gold)

		local cap = math.max(1, snap.carryCap)
		basketText.Text = Num.Short(snap.carried) .. "/" .. Num.Short(snap.carryCap)
		local frac = snap.carried / cap
		if frac >= 1 then
			basket.BackgroundColor3 = Theme.Color.RedDark
			basketStroke.Color = Theme.Color.Bad
		elseif frac >= 0.75 then
			basket.BackgroundColor3 = Theme.Color.Orange
			basketStroke.Color = Theme.Color.Ink
		else
			basket.BackgroundColor3 = Color3.fromRGB(40, 32, 28)
			basketStroke.Color = Theme.Color.Ink
		end
		prodText.Text = string.format("Laying %s  •  Shipping %s  •  %s", Num.Rate(snap.rates.lay), Num.Rate(snap.rates.ship), "$" .. Num.Rate(snap.rates.cash))

		local m = math.max(snap.comboMax, 1)
		combo:Set((snap.combo - 1) / math.max(m - 1, 0.001), "Cash " .. string.format("x%.1f", snap.combo))

		local full = snap.population >= snap.capacity
		if full ~= housingFull then
			housingFull = full
			Hud._paintSpawn()
		end

		local auto = snap.settings.autoSpawn
		autoBtn:SetColor(if auto then Theme.Color.Green else Theme.Color.Gray)
		autoBtn:SetText(if auto then "AUTO ON" else "AUTO")
		autoBtn.Label.TextTransparency = if snap.tutorial.done then 0 else 0.4

		-- badges
		local claimable = 0
		for _, q in snap.quests.list do
			if not q.claimed and q.progress >= q.target then
				claimable += 1
			end
		end
		setBadge(questNav, if claimable > 0 then tostring(claimable) else nil)
		setBadge(dailyNav, if snap.daily.canClaim then "!" else nil)
		local boosts = 0
		for _, n in snap.boosts.inventory do
			boosts += n
		end
		setBadge(boostNav, if boosts > 0 then (if boosts > 99 then "99+" else tostring(boosts)) else nil)
		setBadge(eggsNav, if snap.canRebirth or snap.canPrestige then "!" else nil)
		setBadge(settingsNav, nil)
		setBadge(shopNav, nil)
	end)

	-- 4 Hz: gift readiness (playtime advances between snapshots)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local snap = store.Get()
		if not snap then
			return
		end
		local n = Common.GiftsReady(snap, store.Now())
		if n ~= giftCount then
			giftCount = n
			setBadge(giftNav, if n > 0 then tostring(n) else nil)
		end
	end)

	Hud._paintSpawn()
end

return Hud
