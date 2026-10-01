--!strict
-- World-space business controls over each owned business in the player's plot:
-- output label, green production bar (CLICK / countdown), blue upgrade button with a gold
-- badge. Also colours pad prices by affordability and floats "+$" pops (throttled).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local BigNum = require(Shared.Logic.BigNum)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local Bus = require(script.Parent.Bus)
local Effects = require(script.Parent.Effects)
local State = require(script.Parent.State)

local C = Kit.C
local new = Kit.new
local player = Players.LocalPlayer

local WorldUI = {}

type Card = {
	gui: BillboardGui,
	output: TextLabel,
	fill: Frame,
	barText: TextLabel,
	barButton: TextButton,
	upgrade: Kit.Button,
	badge: TextLabel,
	pending: boolean,
}
local cards: { [string]: Card } = {}
local lastPop: { [string]: number } = {}

local function makeCard(bizId: string, anchor: BasePart): Card
	local biz = Economy.bizById[bizId]
	local gui = new("BillboardGui", {
		Name = "Biz_" .. bizId,
		Adornee = anchor,
		Size = UDim2.fromOffset(250, 150),
		AlwaysOnTop = false,
		MaxDistance = 140,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Active = true,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local frame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	Kit.label({ Text = biz.name, Size = UDim2.new(1, 0, 0, 24), Parent = frame, MaxText = 22 })
	local output = Kit.label({ Text = "$0.00", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 22), Parent = frame, TextColor3 = C.white, MaxText = 34 })
	-- green production bar: tap to sell when manual
	local barButton = new("TextButton", { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 62), BackgroundColor3 = Color3.fromRGB(40, 70, 40), Text = "", AutoButtonColor = false, Parent = frame }, { Kit.corner(10), Kit.stroke(C.shadow, 3) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green, Parent = barButton }, { Kit.corner(10) })
	local barText = Kit.label({ Text = "CLICK", Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), Parent = barButton, MaxText = 24, ZIndex = 2 })
	local card: Card
	local upgrade = Kit.button({
		text = "Upgrade",
		color = C.blue,
		dark = C.blueDark,
		size = UDim2.new(1, -60, 0, 42),
		pos = UDim2.fromOffset(10, 102),
		parent = frame,
		textSize = 22,
		onClick = function()
			card.pending = true
			card.upgrade.setPending(true)
			State.send("upgrade", bizId, Bus.bulk)
			task.delay(0.6, function()
				card.pending = false
			end)
		end,
	})
	local badge = Kit.label({ Text = "x1", Size = UDim2.fromOffset(44, 42), Position = UDim2.new(1, -54, 0, 100), BackgroundTransparency = 0, BackgroundColor3 = C.gold, Parent = frame, MaxText = 20 })
	Kit.corner(10).Parent = badge
	card = { gui = gui, output = output, fill = fill, barText = barText, barButton = barButton, upgrade = upgrade, badge = badge, pending = false }
	barButton.Activated:Connect(function()
		local d = State.data
		local b = d and d.biz[bizId]
		if b and b.owned and not b.auto and not b.running then
			Effects.play("click", 0.4, 0.05)
			barText.Text = "…"
			State.send("click", bizId)
		end
	end)
	return card
end

local function plotFolder(): Instance?
	local i = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Plots")
	return if plots and i then plots:FindFirstChild("Plot" .. tostring(i)) else nil
end

local function ensureCards()
	local plot = plotFolder()
	local anchors = plot and plot:FindFirstChild("Anchors")
	if not anchors then
		return
	end
	for _, biz in Economy.businesses do
		local a = anchors:FindFirstChild(biz.id) :: BasePart?
		if a and not cards[biz.id] then
			cards[biz.id] = makeCard(biz.id, a)
		elseif a and cards[biz.id].gui.Adornee ~= a then
			cards[biz.id].gui.Adornee = a
		end
	end
end

local function refresh(d: any)
	ensureCards()
	local cash = Bus.big(d.cash)
	for id, card in cards do
		local b = d.biz[id]
		card.gui.Enabled = b ~= nil and b.owned
		if not (b and b.owned) then
			continue
		end
		card.output.Text = Format.cash(Bus.big(b.output))
		local cost: BigNum.Big
		local label: string
		if Bus.bulk == "max" then
			cost = Bus.big(b.maxCost)
			label = if b.maxN > 0 then string.format("Upgrade x%d  %s", b.maxN, Format.short(cost)) else "Upgrade " .. Format.short(Bus.big(b.cost1))
			card.upgrade.setEnabled(b.maxN > 0)
		elseif Bus.bulk ~= 1 and b.bulk[tostring(Bus.bulk)] then
			cost = Bus.big(b.bulk[tostring(Bus.bulk)])
			label = string.format("Upgrade x%s  %s", tostring(Bus.bulk), Format.short(cost))
			card.upgrade.setEnabled(BigNum.gte(cash, cost))
		else
			cost = Bus.big(b.cost1)
			label = "Upgrade " .. Format.short(cost)
			card.upgrade.setEnabled(BigNum.gte(cash, cost))
		end
		card.upgrade.setText(label)
		card.upgrade.setPending(false)
		-- gold badge: number of level upgrades bought so far (hypothesis H-BADGE)
		card.badge.Text = "x" .. tostring(b.level - 1)
		card.badge.Visible = b.level > 1
	end
	-- pads: price colour by affordability, NEW sparkle on available pads
	local plot = plotFolder()
	if plot then
		for padId, ps in d.pads do
			if ps.s == 1 then
				local part = plot:FindFirstChild(padId)
				local lbl = part and part:FindFirstChild("PadLabel")
				local price = lbl and lbl:FindFirstChild("Price") :: TextLabel?
				if price then
					local c = Bus.big(ps.c)
					price.Text = Format.cash(c)
					price.TextColor3 = if BigNum.gte(cash, c) then Color3.fromRGB(140, 255, 140) else Color3.fromRGB(255, 130, 120)
				end
			end
		end
	end
	-- cash pops for this snapshot's earnings (one per business per 0.25 s at most)
	if d.earned and plot then
		for bizId, e in d.earned do
			local now = os.clock()
			if now - (lastPop[bizId] or 0) < 0.25 then
				continue
			end
			lastPop[bizId] = now
			local card = cards[bizId]
			if card then
				local pop = Kit.label({ Text = "+" .. Format.short(Bus.big(e.amount)), Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 0), Parent = card.gui:FindFirstChildOfClass("Frame"), TextColor3 = C.gold, MaxText = 28, ZIndex = 5 })
				Kit.textStroke(2).Parent = pop
				Kit.tween(pop, 0.8, { Position = UDim2.fromOffset(0, -40), TextTransparency = 1 })
				task.delay(0.85, function()
					pop:Destroy()
				end)
			end
			Effects.play("cash", 0.25, 0.3)
		end
	end
end

function WorldUI.init()
	State.Changed:Connect(refresh)
	Bus.BulkChanged:Connect(function()
		if State.data then
			refresh(State.data)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local d = State.data
		if not d then
			return
		end
		for id, card in cards do
			local b = d.biz[id]
			if not (b and b.owned) then
				continue
			end
			local p = State.progress(b)
			card.fill.Size = UDim2.fromScale(p, 1)
			local cps = b.cps or 1
			if b.auto then
				card.barText.Text = if cps > 20 then "MAX SPEED" else Format.timer((1 - p) / cps)
			elseif b.running then
				card.barText.Text = Format.timer(math.max(0, (1 - p) / cps))
			elseif card.barText.Text ~= "…" or os.clock() - State.receivedAt > 0.5 then
				card.barText.Text = "CLICK"
			end
		end
	end)
end

return WorldUI
