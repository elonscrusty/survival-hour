--!strict
-- Centred tall, scrollable panel with Manage / Powers / Shop tabs and a red close button.
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local BigNum = require(Shared.Logic.BigNum)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Products = require(Shared.Products)
local Kit = require(script.Parent.Parent.UI.Kit)
local Bus = require(script.Parent.Bus)
local State = require(script.Parent.State)

local C = Kit.C
local new = Kit.new

local Panels = {}

local gui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local tabs: { [string]: Kit.Button } = {}
local current = "Manage"
local rows: { [string]: any } = {}
local priceCache: { [string]: string } = {}

local PRODUCT_NAMES: { [string]: string } = {}
for _, p in Economy.Catalog.products do
	PRODUCT_NAMES[p.id] = p.name
end

local function clear()
	for _, c in list:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	rows = {}
end

local function card(height: number, order: number): Frame
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.bg, LayoutOrder = order, Parent = list }, { Kit.corner(14), Kit.stroke(Color3.fromRGB(220, 200, 170), 2) })
	return f
end

local function robuxPrice(key: string): string
	local d = State.data
	if d and d.mock then
		return "TEST BUY"
	end
	if priceCache[key] then
		return priceCache[key]
	end
	local prod = Products.byKey[key]
	if not prod or not prod.id then
		return "Soon"
	end
	priceCache[key] = "…"
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(prod.id :: number, if prod.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
		end)
		priceCache[key] = if ok and info and info.PriceInRobux then "R$ " .. tostring(info.PriceInRobux) else "Soon"
	end)
	return priceCache[key]
end

local function buy(key: string)
	local d = State.data
	if d and d.mock then
		State.send("mockBuy", key)
	else
		State.send("buyProduct", key)
	end
end

---------------------------------------------------------------- Manage
local function buildManage(d: any)
	if d.powers.manage.tier < 1 then
		local f = card(150, 1)
		Kit.label({ Text = "🔒 Manage is locked", Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 10), Parent = f, TextColor3 = C.ink })
		Kit.label({ Text = "Unlock Manage in Powers to run and upgrade every business from here. Until then, walk up to each business.", Size = UDim2.new(1, -20, 0, 60), Position = UDim2.fromOffset(10, 52), Parent = f, TextColor3 = C.inkSoft, Font = Kit.FONT_BODY, MaxText = 18, TextWrapped = true })
		Kit.button({ text = "Go to Powers", size = UDim2.fromOffset(180, 34), pos = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1), parent = f, color = C.violet, dark = Color3.fromRGB(90, 50, 160), onClick = function()
			Bus.open("panel", "Powers")
		end })
		return
	end
	for i, biz in Economy.businesses do
		local b = d.biz[biz.id]
		if not b.owned then
			continue
		end
		local f = card(108, i)
		Kit.icon(biz.id, 34, f, UDim2.fromOffset(8, 3))
		Kit.label({ Text = biz.name, Size = UDim2.new(0.5, -50, 0, 28), Position = UDim2.fromOffset(48, 6), Parent = f, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24 })
		local out = Kit.label({ Text = "", Size = UDim2.new(0.5, -10, 0, 28), Position = UDim2.new(0.5, 0, 0, 6), Parent = f, TextColor3 = C.greenDark, TextXAlignment = Enum.TextXAlignment.Right, MaxText = 24 })
		local barBtn = new("TextButton", { Size = UDim2.new(0.55, -10, 0, 30), Position = UDim2.fromOffset(10, 40), BackgroundColor3 = Color3.fromRGB(40, 70, 40), Text = "", AutoButtonColor = false, Parent = f }, { Kit.corner(8) })
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green, Parent = barBtn }, { Kit.corner(8) })
		local barText = Kit.label({ Text = "", Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), Parent = barBtn, ZIndex = 2, MaxText = 20 })
		barBtn.Activated:Connect(function()
			State.send("click", biz.id)
		end)
		local up = Kit.button({ text = "", color = C.blue, dark = C.blueDark, size = UDim2.new(0.45, -10, 0, 40), pos = UDim2.new(0.55, 0, 0, 36), parent = f, textSize = 20, onClick = function()
			State.send("upgrade", biz.id, Bus.bulk)
		end })
		local info = Kit.label({ Text = "", Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 80), Parent = f, TextColor3 = C.inkSoft, Font = Kit.FONT_BODY, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16 })
		rows[biz.id] = { out = out, fill = fill, barText = barText, up = up, info = info }
	end
end

local function refreshManage(d: any)
	local cash = Bus.big(d.cash)
	for id, r in rows do
		local b = d.biz[id]
		if not b or not b.owned then
			continue
		end
		r.out.Text = Format.cash(Bus.big(b.output))
		local cost = Bus.big(b.cost1)
		local n = "1"
		if Bus.bulk == "max" then
			cost = Bus.big(b.maxCost)
			n = tostring(b.maxN)
			r.up.setEnabled(b.maxN > 0)
		elseif Bus.bulk ~= 1 and b.bulk[tostring(Bus.bulk)] then
			cost = Bus.big(b.bulk[tostring(Bus.bulk)])
			n = tostring(Bus.bulk)
			r.up.setEnabled(BigNum.gte(cash, cost))
		else
			r.up.setEnabled(BigNum.gte(cash, cost))
		end
		r.up.setText(string.format("x%s  %s", n, Format.short(cost)))
		r.info.Text = string.format("Level %d · %s/s · %s cash · %s speed%s", b.level, Format.short(Bus.big(b.rate)), Format.short(Bus.big(b.cashMult)):sub(2), Format.short(Bus.big(b.speedMult)):sub(2), if b.auto then " · automatic" else "")
	end
end

---------------------------------------------------------------- Powers

local function buildPowers(d: any)
	local order = 0
	for _, pw in Economy.Catalog.powers do
		order += 1
		local st = d.powers[pw.id]
		local f = card(120, order)
		Kit.icon(pw.id, 34, f, UDim2.fromOffset(8, 4))
		Kit.label({ Text = pw.name, Size = UDim2.new(1, -190, 0, 30), Position = UDim2.fromOffset(48, 6), Parent = f, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24 })
		Kit.label({ Text = string.format("Level %d / %d", st.tier, pw.tiers), Size = UDim2.fromOffset(130, 26), Position = UDim2.new(1, -140, 0, 8), Parent = f, TextColor3 = C.violet, TextXAlignment = Enum.TextXAlignment.Right, MaxText = 20 })
		Kit.label({ Text = pw.desc, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 38), Parent = f, TextColor3 = C.inkSoft, Font = Kit.FONT_BODY, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, MaxText = 17 })
		local inv = Kit.button({ text = "", color = C.green, dark = C.greenDark, size = UDim2.new(0.5, -15, 0, 38), pos = UDim2.new(0, 10, 1, -44), parent = f, textSize = 18, onClick = function()
			State.send("buyPower", pw.id)
		end })
		local cost = st.cost and Bus.big(st.cost)
		if cost then
			inv.setText("👽 " .. Format.amount(cost, 0) .. " investors")
			inv.setEnabled(BigNum.gte(Bus.big(d.investors), cost))
		else
			inv.setText(if st.tier >= pw.tiers then "Maxed" else "—")
			inv.setEnabled(false)
		end
		if Products.byKey[pw.id] then
			local owned = d.owned[pw.id]
			local rb = Kit.button({ text = if owned then "Owned" else robuxPrice(pw.id), color = C.gold, dark = C.goldDark, size = UDim2.new(0.5, -15, 0, 38), pos = UDim2.new(0.5, 5, 1, -44), parent = f, textSize = 18, onClick = function()
				buy(pw.id)
			end })
			rb.setEnabled(not owned)
		end
	end
end

---------------------------------------------------------------- Shop
local function buildShop(d: any)
	local order = 0
	for _, prod in Products.list do
		order += 1
		local f = card(92, order)
		Kit.icon(prod.key, 64, f, UDim2.fromOffset(6, 14))
		Kit.label({ Text = PRODUCT_NAMES[prod.key] or prod.key, Size = UDim2.new(1, -230, 0, 30), Position = UDim2.fromOffset(74, 8), Parent = f, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22 })
		Kit.label({ Text = prod.blurb, Size = UDim2.new(1, -230, 0, 40), Position = UDim2.fromOffset(74, 40), Parent = f, TextColor3 = C.inkSoft, Font = Kit.FONT_BODY, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, MaxText = 16 })
		local owned = d.owned[prod.key]
		local b = Kit.button({ text = if owned then "Owned" else robuxPrice(prod.key), color = C.gold, dark = C.goldDark, size = UDim2.fromOffset(140, 52), pos = UDim2.new(1, -150, 0.5, 0), anchor = Vector2.new(0, 0.5), parent = f, textSize = 22, onClick = function()
			buy(prod.key)
		end })
		b.setEnabled(not owned)
	end
	if d.mock then
		order += 1
		local f = card(150, order)
		f.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
		Kit.label({ Text = "Studio test tools (not in the live game)", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 6), Parent = f, TextColor3 = C.blueDark, MaxText = 20 })
		Kit.label({ Text = "TEST buttons run the real receipt code with fake receipts. No Robux is ever charged.", Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 34), Parent = f, TextColor3 = C.inkSoft, Font = Kit.FONT_BODY, TextWrapped = true, MaxText = 15 })
		Kit.button({ text = "Resend last receipt", color = C.blue, dark = C.blueDark, size = UDim2.new(0.5, -15, 0, 44), pos = UDim2.new(0, 10, 1, -52), parent = f, textSize = 18, onClick = function()
			State.send("mockBuy", "forever", true)
		end })
		Kit.button({ text = "Cancelled purchase", color = C.red, dark = C.redDark, size = UDim2.new(0.5, -15, 0, 44), pos = UDim2.new(0.5, 5, 1, -52), parent = f, textSize = 18, onClick = function()
			State.send("mockBuy", "cash1h", false, true)
		end })
	end
end

---------------------------------------------------------------- Decor
local function buildDecor(d: any)
	local cash = Bus.big(d.cash)
	local intro = card(56, 0)
	Kit.label({ Text = "Decorate your plot! Decorations are just for looks and stay forever, even after resets.", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Parent = intro, TextColor3 = C.inkSoft, Font = Kit.FONT_BODY, TextWrapped = true, MaxText = 16 })
	for i, item in Economy.Catalog.decor.items do
		local f = card(84, i)
		Kit.icon(item.model, 68, f, UDim2.fromOffset(6, 8))
		Kit.label({ Text = item.name, Size = UDim2.new(1, -240, 0, 30), Position = UDim2.fromOffset(82, 10), Parent = f, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22 })
		Kit.label({ Text = Format.cash(item.price), Size = UDim2.new(1, -240, 0, 24), Position = UDim2.fromOffset(82, 44), Parent = f, TextColor3 = C.greenDark, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20 })
		local owned = d.decor and d.decor[item.id]
		local b = Kit.button({ text = if owned then "Placed ✓" else "Buy", color = C.green, dark = C.greenDark, size = UDim2.fromOffset(140, 52), pos = UDim2.new(1, -150, 0.5, 0), anchor = Vector2.new(0, 0.5), parent = f, textSize = 22, onClick = function()
			State.send("buyDecor", item.id)
		end })
		b.setEnabled(not owned and BigNum.gte(cash, BigNum.new(item.price)))
	end
end

local lastSig = ""
local function tabSignature(d: any): string
	local cash = Bus.big(d.cash)
	local parts = { current }
	if current == "Decor" then
		for _, item in Economy.Catalog.decor.items do
			table.insert(parts, (d.decor and d.decor[item.id] and "o" or "") .. (BigNum.gte(cash, BigNum.new(item.price)) and "a" or "-"))
		end
	elseif current == "Powers" then
		local inv = Bus.big(d.investors)
		for id, st in d.powers do
			table.insert(parts, id .. st.tier .. (st.cost and BigNum.gte(inv, Bus.big(st.cost)) and "a" or "-") .. tostring(d.owned[id]))
		end
		table.sort(parts)
	else
		for k, v in d.owned do
			table.insert(parts, k .. tostring(v))
		end
		table.sort(parts)
	end
	return table.concat(parts, "|")
end

local function rebuild()
	local d = State.data
	if not d or not gui.Enabled then
		return
	end
	clear()
	if current == "Manage" then
		buildManage(d)
		refreshManage(d)
	elseif current == "Powers" then
		buildPowers(d)
	elseif current == "Decor" then
		buildDecor(d)
	else
		buildShop(d)
	end
	-- cards slide in one after another
	local n = 0
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			n += 1
			Kit.popIn(c, math.min(n, 8) * 0.03)
		end
	end
	for name, b in tabs do
		b.setColor(if name == current then C.blue else C.grey, if name == current then C.blueDark else Color3.fromRGB(120, 115, 110))
	end
end

function Panels.open(tab: string)
	current = tab
	lastSig = ""
	local wasOpen = gui.Enabled
	gui.Enabled = true
	panel.Size = UDim2.new(0, 560, 1, -150)
	if not wasOpen then
		Kit.popIn(panel)
	end
	rebuild()
end

function Panels.close()
	gui.Enabled = false
end

function Panels.init()
	local g, root = Kit.canvas("Panels", 20)
	gui = g
	gui.Enabled = false
	-- dim backdrop closes on tap
	local back = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Text = "", AutoButtonColor = false, Parent = root })
	back.Activated:Connect(Panels.close)
	panel = Kit.panel({ size = UDim2.new(0, 560, 1, -150), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), parent = root })
	local tabRow = new("Frame", { Size = UDim2.new(1, -80, 0, 52), Position = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = panel }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	for i, name in { "Manage", "Powers", "Decor", "Shop" } do
		local b = Kit.button({ text = name, color = C.grey, dark = Color3.fromRGB(120, 115, 110), size = UDim2.fromOffset(108, 50), parent = tabRow, textSize = 20, onClick = function()
			current = name
			rebuild()
		end })
		b.frame.LayoutOrder = i
		tabs[name] = b
	end
	Kit.button({ text = "✕", color = C.red, dark = C.redDark, size = UDim2.fromOffset(52, 52), pos = UDim2.new(1, -12, 0, 12), anchor = Vector2.new(1, 0), parent = panel, textSize = 28, onClick = Panels.close })
	list = new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -84),
		Position = UDim2.fromOffset(12, 74),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.inkSoft,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8) }),
	})
	Bus.Opened:Connect(function(what, arg)
		if what == "panel" then
			Panels.open(arg)
		elseif gui.Enabled and what ~= "panel" then
			Panels.close()
		end
	end)
	local lastBuild = 0
	State.Changed:Connect(function(d)
		if not gui.Enabled then
			return
		end
		if current == "Manage" then
			-- rebuild only when the set of owned businesses changes
			local count = 0
			for _, b in d.biz do
				if b.owned then
					count += 1
				end
			end
			local have = 0
			for _ in rows do
				have += 1
			end
			if count ~= have and d.powers.manage.tier > 0 then
				rebuild()
			end
			refreshManage(d)
		elseif os.clock() - lastBuild > 0.5 then
			-- rebuild only when something visible changed (owned / affordable / tiers)
			lastBuild = os.clock()
			local sig = tabSignature(d)
			if sig ~= lastSig then
				lastSig = sig
				rebuild()
			end
		end
	end)
	Bus.BulkChanged:Connect(function()
		if gui.Enabled and current == "Manage" and State.data then
			refreshManage(State.data)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not gui.Enabled or current ~= "Manage" then
			return
		end
		local d = State.data
		if not d then
			return
		end
		for id, r in rows do
			local b = d.biz[id]
			local p = State.progress(b)
			r.fill.Size = UDim2.fromScale(p, 1)
			local cps = b.cps or 1
			r.barText.Text = if b.auto then (if cps > 20 then "MAX SPEED" else Format.timer((1 - p) / cps)) elseif b.running then Format.timer((1 - p) / cps) else "CLICK"
		end
	end)
end

return Panels
