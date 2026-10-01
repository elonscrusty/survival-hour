--!strict
-- Toasts (short messages, top centre, up to 3 stacked), the big celebration banner (Rebirth /
-- Prestige) and floating popups ("+5", "+$1.2K") that rise and fade.

local Theme = require(script.Parent.Parent.UI.Theme)
local Util = require(script.Parent.Parent.UI.Util)
local Layout = require(script.Parent.Parent.UI.Layout)
local Icon = require(script.Parent.Parent.UI.Icon)

local Toasts = {}

local MAX = 3
local holder: Frame
local bannerHolder: Frame
local popRoot: Frame
local recent: { [string]: number } = {}

local KIND_COLOR: { [string]: Color3 } = {
	info = Theme.Color.Blue,
	good = Theme.Color.Green,
	bad = Theme.Color.Red,
	gold = Theme.Color.GoldDark,
	cash = Theme.Color.GreenDark,
	warn = Theme.Color.Orange,
}

function Toasts.Start()
	local _, root = Layout.Layer("EggFarmToasts", 30)
	holder = Instance.new("Frame")
	holder.Name = "Toasts"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 150)
	holder.Size = UDim2.new(1, -40, 0, 220)
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(520, 220)
	lim.Parent = holder
	Util.List(holder, 6)
	holder.Parent = root

	bannerHolder = Instance.new("Frame")
	bannerHolder.Name = "Banner"
	bannerHolder.BackgroundTransparency = 1
	bannerHolder.Size = UDim2.fromScale(1, 1)
	bannerHolder.Parent = root

	popRoot = Instance.new("Frame")
	popRoot.Name = "Popups"
	popRoot.BackgroundTransparency = 1
	popRoot.Size = UDim2.fromScale(1, 1)
	popRoot.Parent = root
end

-- kind: "info" | "good" | "bad" | "gold" | "cash" | "warn"
function Toasts.Show(text: string, kind: string?)
	if not holder or text == "" then
		return
	end
	-- the same message twice within a second is shown once
	local now = os.clock()
	if (recent[text] or 0) + 1 > now then
		return
	end
	recent[text] = now
	local items = {}
	for _, c in holder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	if #items >= MAX then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	local f = Instance.new("Frame")
	f.Name = "Toast"
	f.BackgroundColor3 = KIND_COLOR[kind or "info"] or Theme.Color.Blue
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = math.floor(now * 1000) % 1e9
	Util.Corner(f, 14)
	Util.Stroke(f, 3, Theme.Color.Ink, true)
	Util.Gradient(f)
	Util.Pad(f, 10, 8, 8)
	local t = Util.Text({
		text = text,
		size = UDim2.new(1, 0, 0, 0),
		textSize = Theme.Text.M,
		font = Theme.Font.Title,
		wrap = true,
		outline = true,
		parent = f,
	})
	t.ZIndex = 2
	local sc = Instance.new("UIScale")
	sc.Scale = 0.7
	sc.Parent = f
	f.Parent = holder
	Util.Tween(sc, Theme.Tween.Pop, { Scale = 1 })
	task.delay(2.6, function()
		if f.Parent then
			Util.Tween(sc, Theme.Tween.Med, { Scale = 0.6 })
			Util.Tween(f, Theme.Tween.Med, { BackgroundTransparency = 1 })
			Util.Tween(t, Theme.Tween.Med, { TextTransparency = 1, TextStrokeTransparency = 1 })
			task.wait(0.26)
			f:Destroy()
		end
	end)
end

-- Big centred celebration (Rebirth / Prestige / big rewards).
function Toasts.Banner(title: string, subtitle: string?, color: Color3?, icon: string?)
	if not bannerHolder then
		return
	end
	Util.Clear(bannerHolder)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.36)
	f.Size = UDim2.new(1, -40, 0, 150)
	f.BackgroundColor3 = color or Theme.Color.Purple
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(620, 150)
	lim.Parent = f
	Util.Corner(f, 26)
	Util.Stroke(f, 5, Theme.Color.Ink, true)
	local g = Util.Gradient(f, Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180))
	local ic = Icon.new(icon or "star", 84)
	ic.AnchorPoint = Vector2.new(0, 0.5)
	ic.Position = UDim2.new(0, 16, 0.5, 0)
	ic.ZIndex = 2
	ic.Parent = f
	Util.Text({
		text = title,
		size = UDim2.new(1, -124, 0, 70),
		position = UDim2.fromOffset(110, 12),
		textSize = Theme.Text.Huge,
		font = Theme.Font.Title,
		outline = true,
		z = 2,
		parent = f,
	})
	if subtitle then
		Util.Text({
			text = subtitle,
			size = UDim2.new(1, -124, 0, 50),
			position = UDim2.fromOffset(110, 84),
			textSize = Theme.Text.L,
			font = Theme.Font.Title,
			outline = true,
			z = 2,
			parent = f,
		})
	end
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = f
	f.Parent = bannerHolder
	Util.Tween(sc, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	task.spawn(function()
		for _ = 1, 30 do
			if not f.Parent then
				return
			end
			g.Rotation = (g.Rotation + 12) % 360
			task.wait(0.1)
		end
		Util.Tween(sc, Theme.Tween.Med, { Scale = 0 })
		task.wait(0.3)
		f:Destroy()
	end)
end

-- Floating text that rises from a point (logical px within the toast layer) and fades out.
function Toasts.Popup(text: string, color: Color3?, at: UDim2?, icon: string?)
	if not popRoot then
		return
	end
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(200, 44)
	local start = at or UDim2.fromScale(0.5, 0.7)
	f.Position = start + UDim2.fromOffset(math.random(-30, 30), 0)
	if icon then
		local ic = Icon.new(icon, 34)
		ic.AnchorPoint = Vector2.new(1, 0.5)
		ic.Position = UDim2.new(0.5, -40, 0.5, 0)
		ic.Parent = f
	end
	local t = Util.Text({
		text = text,
		textSize = Theme.Text.XL,
		font = Theme.Font.Title,
		color = color or Theme.Color.Good,
		outline = true,
		parent = f,
	})
	f.Parent = popRoot
	Util.Tween(f, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = f.Position - UDim2.fromOffset(0, 90),
	})
	task.delay(0.6, function()
		Util.Tween(t, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(1.15, function()
		f:Destroy()
	end)
end

return Toasts
