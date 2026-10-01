--!strict
-- Shop: Featured / Passes / Gold Eggs / Cash tabs of product cards (Data/Products), a Codes
-- button (opens Codes; Back returns here). Robux items ask the server's Commerce RemoteFunction
-- and show loading until the result (or, for a real Roblox prompt, the Checkout event).
-- Gold Egg items use buyGoldItem, with a confirm dialog when settings.confirmSpend is on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared:WaitForChild("Data"):WaitForChild("Products"))
local Net = require(Shared:WaitForChild("Net"))
local Contract = require(Shared:WaitForChild("Contract"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Card = require(UI.Card)
local Icon = require(UI.Icon)
local Button = require(UI.Button)
local Num = require(UI.Num)
local PurchaseButton = require(UI.PurchaseButton)

local M = {
	Name = "Shop",
	Title = "Shop",
	Icon = "shop",
	Color = Theme.Color.Pink,
	Tabs = {
		{ id = "Featured", label = Products.TabLabels.Featured, color = Theme.Color.Pink },
		{ id = "Passes", label = Products.TabLabels.Passes, color = Theme.Color.Purple },
		{ id = "Gold", label = Products.TabLabels.Gold, color = Theme.Color.GoldDark },
		{ id = "Cash", label = Products.TabLabels.Cash, color = Theme.Color.GreenDark },
	},
}

local CHECKOUT_TIMEOUT = 120

-- Asks the server to start a Robux checkout. Production replies "prompted" and later sends a
-- Checkout FarmEvent; the test checkout replies with the final result straight away.
function M.BuyRobux(host: any, productId: string): any
	local remote = Net.Get("Commerce") :: RemoteFunction
	local final: any = nil
	local off = host.Store.OnEvent("Checkout", function(data: any)
		if type(data) == "table" and data.productId == productId then
			final = data
		end
	end)
	local ok, res = pcall(function()
		return remote:InvokeServer({ productId = productId })
	end)
	if not ok or type(res) ~= "table" then
		off()
		return { ok = false, code = "failed", message = "The store couldn't open. Try again later." }
	end
	if res.code == "prompted" then
		local started = os.clock()
		while final == nil and os.clock() - started < CHECKOUT_TIMEOUT do
			task.wait(0.1)
		end
		off()
		if final == nil then
			return { ok = false, code = "cancelled", message = "Purchase window closed." }
		elseif final.status == "ok" then
			return { ok = true, code = "ok" }
		elseif final.status == "cancelled" then
			return { ok = false, code = "cancelled", message = "Purchase cancelled." }
		end
		return { ok = false, code = "failed", message = "The purchase didn't go through." }
	end
	off()
	if res.code == "cancelled" and not res.message then
		res.message = "Purchase cancelled."
	end
	if not res.ok and not res.message then
		res.message = Contract.Messages[res.code] or "The purchase didn't go through."
	end
	return res
end

local function inTab(p: Products.Product, tab: string): boolean
	if tab == "Featured" then
		return p.featured == true or p.tab == "Featured"
	end
	return p.tab == tab
end

function M.Build(host: any, panel: any)
	local body = panel.Body
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, 64)
	bar.Parent = body
	local balance = Util.Text({
		text = "",
		size = UDim2.new(1, -190, 1, 0),
		textSize = Theme.Text.M,
		color = Theme.Color.TextDark,
		font = Theme.Font.Title,
		xAlign = Enum.TextXAlignment.Left,
		parent = bar,
	})
	Button.new({
		text = "Codes",
		icon = "code",
		color = Theme.Color.Purple,
		size = UDim2.fromOffset(170, 60),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 2),
		parent = bar,
		onClick = function()
			host:Open("Codes", nil, { returnTo = true })
		end,
	})

	local pages: { [string]: ScrollingFrame } = {}
	local buttons: { any } = {}

	for _, tab in Products.Tabs do
		local scroll = Util.Scroll(body, UDim2.new(1, 0, 1, -70), UDim2.fromOffset(0, 70))
		Util.Grid(scroll, Vector2.new(214, 268), 10)
		Util.Pad(scroll, 6)
		pages[tab] = scroll
		local order = 0
		for _, p in Products.List do
			if not inTab(p, tab) then
				continue
			end
			order += 1
			local card = Card.new({ order = order, parent = scroll })
			local ic = Icon.new(p.icon, 64)
			ic.AnchorPoint = Vector2.new(0.5, 0)
			ic.Position = UDim2.new(0.5, 0, 0, 8)
			ic.Parent = card
			if p.kind == "pass" then
				local tag = Util.Text({
					text = "PASS",
					size = UDim2.fromOffset(64, 26),
					position = UDim2.fromOffset(8, 8),
					textSize = Theme.Text.S,
					font = Theme.Font.Title,
					outline = true,
					parent = card,
				})
				tag.BackgroundTransparency = 0
				tag.BackgroundColor3 = Theme.Color.Purple
				Util.Corner(tag, 8)
			end
			Util.Text({
				text = p.name,
				size = UDim2.new(1, -16, 0, 30),
				position = UDim2.fromOffset(8, 76),
				textSize = Theme.Text.M,
				color = Theme.Color.TextDark,
				font = Theme.Font.Title,
				parent = card,
			})
			Util.Text({
				text = p.desc,
				size = UDim2.new(1, -16, 0, 74),
				position = UDim2.fromOffset(8, 106),
				textSize = Theme.Text.S,
				color = Theme.Color.TextMuted,
				yAlign = Enum.TextYAlignment.Top,
				parent = card,
			}).TextWrapped = true
			local isGold = p.kind == "gold"
			local btn = PurchaseButton.new({
				host = host,
				currency = if isGold then "gold" else "robux",
				size = UDim2.new(1, -16, 0, 60),
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -10),
				parent = card,
				quote = function(snap)
					local owned = p.kind == "pass" and p.grant.pass ~= nil and snap.passes[p.grant.pass] == true
					if isGold then
						return p.goldPrice, nil, false
					end
					return p.robux, nil, owned
				end,
				send = function(snap)
					if isGold then
						return host.Store.Request({ type = "buyGoldItem", id = p.id })
					end
					return M.BuyRobux(host, p.id)
				end,
				confirm = if isGold
					then function(snap)
						if not snap.settings.confirmSpend then
							return nil
						end
						return {
							title = "Spend Gold Eggs?",
							icon = "gold",
							color = Theme.Color.GoldDark,
							text = string.format("Buy %s for %s Gold Eggs?\n%s", p.name, Num.Short(p.goldPrice or 0), p.desc),
							confirmText = "Buy",
						}
					end
					else nil,
				onResult = function(res)
					if res.ok and not isGold then
						host:Toast("Thank you! " .. p.name .. " is yours.", "good")
					elseif res.ok then
						host:Toast(p.name .. " added to your boosts!", "gold")
					end
				end,
			})
			table.insert(buttons, btn)
		end
	end

	local inst = {}
	local function show(tab: string?)
		for id, s in pages do
			s.Visible = id == (tab or "Featured")
		end
	end
	function inst.OnShow(tab: string?)
		show(tab)
	end
	function inst.OnTab(tab: string?)
		show(tab)
	end
	function inst.Refresh(snap: any)
		balance.Text = string.format("%s Gold Eggs  •  %s", Num.Short(snap.gold), Num.Cash(snap.cash))
		for _, b in buttons do
			b:Refresh(snap)
		end
	end
	return inst
end

return M
