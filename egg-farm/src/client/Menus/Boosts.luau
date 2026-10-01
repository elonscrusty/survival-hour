--!strict
-- Boosts: BOOSTS tab (active boosts with live countdowns from endsAt vs Store.Now(), the max
-- active count, and the inventory with counts + Use buttons -> useBoost) and SHOP tab (Gold Egg
-- boost items from Data/Products kind "gold" -> buyGoldItem, confirm when settings.confirmSpend).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared:WaitForChild("Data"):WaitForChild("Boosts"))
local Products = require(Shared:WaitForChild("Data"):WaitForChild("Products"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Card = require(UI.Card)
local Icon = require(UI.Icon)
local Num = require(UI.Num)
local PurchaseButton = require(UI.PurchaseButton)
local Common = require(script.Parent.Common)

local M = {
	Name = "Boosts",
	Title = "Boosts",
	Icon = "booster",
	Color = Theme.Color.Purple,
	Tabs = {
		{ id = "BOOSTS", label = "BOOSTS", color = Theme.Color.Purple },
		{ id = "SHOP", label = "SHOP", color = Theme.Color.Orange },
	},
}

local function activeOf(snap: any, id: string, now: number): any
	for _, a in snap.boosts.active do
		if a.id == id and a.endsAt > now then
			return a
		end
	end
	return nil
end

local function activeCount(snap: any, now: number): number
	local n = 0
	for _, a in snap.boosts.active do
		if a.endsAt > now then
			n += 1
		end
	end
	return n
end

function M.Build(host: any, panel: any)
	-- BOOSTS page
	local mine = Util.Scroll(panel.Body)
	Util.List(mine, 8)
	Util.Pad(mine, 4)
	local activeTitle = Common.Heading(mine, "Active", 1, Theme.Color.PurpleDark)
	local activeBox = Instance.new("Frame")
	activeBox.BackgroundTransparency = 1
	activeBox.Size = UDim2.new(1, -8, 0, 0)
	activeBox.AutomaticSize = Enum.AutomaticSize.Y
	activeBox.LayoutOrder = 2
	activeBox.Parent = mine
	Util.Grid(activeBox, Vector2.new(200, 76), 8)
	local noneActive = Common.Note(mine, "No boosts running. Use one below!", 3)
	Common.Heading(mine, "Your boosts", 4, Theme.Color.PurpleDark)

	local invRows = {}
	for i, b in Boosts.List do
		local row = Card.Row({ icon = b.icon, title = b.name, detail = b.desc, order = 4 + i, parent = mine })
		local id = b.id
		local btn = PurchaseButton.new({
			host = host,
			currency = "free",
			verb = "USE",
			size = UDim2.new(1, 0, 0, 60),
			position = UDim2.fromScale(0, 0.5),
			anchor = Vector2.new(0, 0.5),
			parent = row.Action,
			successSound = "claim",
			quote = function(snap)
				local now = host.Store.Now()
				if (snap.boosts.inventory[id] or 0) <= 0 then
					return nil, "no_boost"
				end
				if not activeOf(snap, id, now) and activeCount(snap, now) >= snap.boosts.maxActive then
					return nil, "boost_limit"
				end
				return 0, "ok"
			end,
			send = function()
				return host.Store.Request({ type = "useBoost", id = id })
			end,
			explain = function(code)
				if code == "no_boost" then
					return "You don't have this boost. Get more in the SHOP tab!"
				end
				return nil
			end,
		})
		invRows[id] = { row = row, btn = btn, def = b }
	end

	-- SHOP page
	local shop = Util.Scroll(panel.Body)
	Util.List(shop, 8)
	Util.Pad(shop, 4)
	local goldLine = Common.Heading(shop, "", 0, Theme.Color.GoldDark)
	local shopButtons = {}
	local order = 0
	for _, p in Products.List do
		if p.kind ~= "gold" then
			continue
		end
		order += 1
		local row = Card.Row({ icon = p.icon, title = p.name, detail = p.desc, order = order, parent = shop })
		local btn = PurchaseButton.new({
			host = host,
			currency = "gold",
			size = UDim2.new(1, 0, 0, 60),
			position = UDim2.fromScale(0, 0.5),
			anchor = Vector2.new(0, 0.5),
			parent = row.Action,
			quote = function()
				return p.goldPrice, nil, false
			end,
			send = function()
				return host.Store.Request({ type = "buyGoldItem", id = p.id })
			end,
			confirm = function(snap)
				if not snap.settings.confirmSpend then
					return nil
				end
				return {
					title = "Spend Gold Eggs?",
					icon = "gold",
					color = Theme.Color.GoldDark,
					text = string.format("Buy %s for %s Gold Eggs?", p.name, Num.Short(p.goldPrice or 0)),
					confirmText = "Buy",
				}
			end,
			onResult = function(res)
				if res.ok then
					host:Toast(p.name .. " added to your boosts!", "gold")
				end
			end,
		})
		table.insert(shopButtons, btn)
	end

	local activeTiles: { [string]: { frame: Frame, label: TextLabel } } = {}
	local activeKey = ""

	local function rebuildActive(snap: any, now: number)
		local ids = {}
		for _, a in snap.boosts.active do
			if a.endsAt > now then
				table.insert(ids, a.id)
			end
		end
		table.sort(ids)
		local key = table.concat(ids, ",")
		if key == activeKey then
			return
		end
		activeKey = key
		for _, t in activeTiles do
			t.frame:Destroy()
		end
		activeTiles = {}
		for i, id in ids do
			local def = Boosts.ById[id]
			local f = Card.new({ order = i, color = Theme.Color.CardAlt, parent = activeBox })
			local ic = Icon.new(def and def.icon or "booster", 48)
			ic.Position = UDim2.fromOffset(8, 14)
			ic.Parent = f
			Util.Text({
				text = def and def.name or id,
				size = UDim2.new(1, -66, 0, 30),
				position = UDim2.fromOffset(62, 6),
				textSize = Theme.Text.S,
				color = Theme.Color.TextDark,
				font = Theme.Font.Title,
				xAlign = Enum.TextXAlignment.Left,
				parent = f,
			})
			local lbl = Util.Text({
				text = "",
				size = UDim2.new(1, -66, 0, 30),
				position = UDim2.fromOffset(62, 38),
				textSize = Theme.Text.M,
				color = Theme.Color.GreenDark,
				font = Theme.Font.Number,
				xAlign = Enum.TextXAlignment.Left,
				parent = f,
			})
			activeTiles[id] = { frame = f, label = lbl }
		end
	end

	local function tick(snap: any, now: number)
		rebuildActive(snap, now)
		local n = 0
		for id, t in activeTiles do
			local a = activeOf(snap, id, now)
			if a then
				n += 1
				t.label.Text = Common.Countdown(a.endsAt - now)
			else
				t.label.Text = "Ended"
			end
		end
		activeTitle.Text = string.format("Active  %d / %d", n, snap.boosts.maxActive)
		noneActive.Visible = n == 0
	end

	local inst = {}
	local function show(tab: string?)
		mine.Visible = tab ~= "SHOP"
		shop.Visible = tab == "SHOP"
	end
	function inst.OnShow(tab: string?)
		show(tab)
	end
	function inst.OnTab(tab: string?)
		show(tab)
	end
	function inst.Refresh(snap: any)
		local now = host.Store.Now()
		tick(snap, now)
		for id, r in invRows do
			local count = snap.boosts.inventory[id] or 0
			r.row.Title.Text = string.format("%s  x%d", r.def.name, count)
			r.btn:Refresh(snap)
		end
		goldLine.Text = "You have " .. Num.Short(snap.gold) .. " Gold Eggs"
		for _, b in shopButtons do
			b:Refresh(snap)
		end
	end
	function inst.Tick(now: number)
		local snap = host.Store.Get()
		if snap then
			tick(snap, now)
		end
	end
	return inst
end

return M
