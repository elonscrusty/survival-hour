--!strict
-- Shop: game passes, gem packs and boosts. Configured items (Id ~= 0) open the
-- Roblox purchase prompt with live prices; unconfigured ones (Id 0) are
-- simulated with DevPurchase in Studio and show "Coming soon" in live games.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared:WaitForChild("Products"))
local Config = require(Shared:WaitForChild("Config"))

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local Format = require("../Core/Format")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Toasts = require("../UI/Toasts")

local Shop = {}

local player = Players.LocalPlayer
local win: Windows.Window
local content: ScrollingFrame
local tab = "Passes"
local selectTab: (string) -> ()
local prices: { [string]: number } = {} -- "pass:<id>" / "product:<id>" -> live Robux price
local fetching: { [string]: boolean } = {}

local PASS_ICONS: { [string]: string } = {
	VIP = "👑",
	Lucky = Theme.Icons.Luck,
	TripleHatch = "🥚🥚🥚",
	FastHatch = "⏩",
	MoreEquip = Theme.Icons.Pets,
	MoreExpeditions = Theme.Icons.Expeditions,
	AutoFarm = "🤖",
	BigBackpack = "🎒",
}

local function render() end -- forward declared below

local function fetchPrice(kind: string, id: number)
	local key = kind .. ":" .. tostring(id)
	if id == 0 or prices[key] or fetching[key] then
		return
	end
	fetching[key] = true
	task.spawn(function()
		local infoType = if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		local ok, info = pcall(function()
			local mps = MarketplaceService :: any
			-- prefer the newer async name when the engine has it
			local okNew, res = pcall(function()
				return mps:GetProductInfoAsync(id, infoType)
			end)
			if okNew and type(res) == "table" then
				return res
			end
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		fetching[key] = false
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			prices[key] = info.PriceInRobux
			render()
		end
	end)
end

local function priceText(kind: string, id: number, fallback: number): string
	if id == 0 then
		return if RunService:IsStudio() then "Test buy" else "Coming soon"
	end
	local p = prices[kind .. ":" .. tostring(id)]
	fetchPrice(kind, id)
	return "R$ " .. tostring(p or fallback)
end

local function devPurchase(key: string)
	local res = Remote.CallOnce("DevPurchase", key)
	if res then
		Toasts.Show("Studio test purchase: " .. key, "good")
	end
end

function Shop.BuyPass(key: string)
	local pass = Products.PassByKey[key]
	if not pass then
		return
	end
	if State.HasPass(key) then
		Toasts.Show("You already own " .. pass.Name .. "!", "info")
		return
	end
	if pass.Id ~= 0 then
		local ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
		if not ok then
			warn("[Shop] " .. tostring(err))
			Toasts.Show("The shop is busy. Try again!", "bad")
		end
	elseif RunService:IsStudio() then
		devPurchase(key)
	else
		Toasts.Show(pass.Name .. " is coming soon!", "info")
	end
end

function Shop.BuyProduct(key: string)
	local product = Products.ByKey[key]
	if not product then
		return
	end
	if product.Id ~= 0 then
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end)
		if not ok then
			warn("[Shop] " .. tostring(err))
			Toasts.Show("The shop is busy. Try again!", "bad")
		end
	elseif RunService:IsStudio() then
		devPurchase(key)
	else
		Toasts.Show(product.Name .. " is coming soon!", "info")
	end
end

-- Popup offering a pass (used when a locked feature is tapped).
function Shop.Upsell(key: string, reason: string?)
	local pass = Products.PassByKey[key]
	if not pass then
		return
	end
	Windows.Confirm(
		(PASS_ICONS[key] or Theme.Icons.Star) .. " " .. pass.Name,
		(if reason then reason .. "\n\n" else "") .. pass.Blurb,
		priceText("pass", pass.Id, pass.Price),
		"Green",
		function()
			Shop.BuyPass(key)
		end,
		"Not now"
	)
end

local function card(order: number, icon: string, title: string, blurb: string, color: Color3): Frame
	local c = Kit.panel({
		Name = title,
		LayoutOrder = order,
		BackgroundColor3 = Theme.Lighten(color, 0.78),
		StrokeColor = Theme.Darken(color, 0.3),
		Parent = content,
	}, { Kit.shade(0.12) })
	Kit.fitLabel(icon, 40, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 8), Parent = c })
	Kit.fitLabel(title, 24, {
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 58),
		Outline = Theme.Darken(color, 0.45),
		Parent = c,
	})
	Kit.fitLabel(blurb, 16, {
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.fromOffset(10, 90),
		Font = Theme.FontBody,
		Color = Theme.Colors.TextDim,
		Parent = c,
	})
	return c
end

local function buyButton(parent: Instance, text: string, tone: string, enabled: boolean, onClick: () -> ())
	local b = Kit.button(text, tone, {
		Size = UDim2.new(1, -24, 0, 54),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Parent = parent,
	}, onClick)
	if not enabled then
		Kit.setButton(b, { Enabled = false })
	end
	return b
end

local function renderImpl()
	if not win or not win.IsOpen then
		return
	end
	Kit.clear(content)
	if tab == "Passes" then
		for i, pass in Products.Passes do
			local owned = State.HasPass(pass.Key)
			local c = card(i, PASS_ICONS[pass.Key] or Theme.Icons.Star, pass.Name, pass.Blurb, Theme.Rarity.Legendary)
			if owned then
				buyButton(c, Theme.Icons.Equipped .. " Owned", "Green", false, function() end)
			else
				buyButton(c, priceText("pass", pass.Id, pass.Price), "Green", true, function()
					Shop.BuyPass(pass.Key)
				end)
			end
		end
	elseif tab == "Gems" then
		local i = 0
		for _, product in Products.Products do
			if product.Kind == "Gems" then
				i += 1
				local c = card(i, string.rep(Theme.Icons.Gems, math.min(3, 1 + i // 2)), Format.commas(product.Amount or 0) .. " Gems", "Spend on Prism Eggs and skipping expeditions.", Theme.Colors.Gems)
				buyButton(c, priceText("product", product.Id, product.Price), "Green", true, function()
					Shop.BuyProduct(product.Key)
				end)
			end
		end
	else
		local i = 0
		for _, product in Products.Products do
			if product.Kind ~= "Gems" then
				i += 1
				local blurb: string
				local left = 0
				if product.Kind == "ServerLuck" then
					blurb = "x" .. tostring(Config.ServerLuckMult) .. " luck for EVERYONE in this server for " .. Format.duration(Config.ServerLuckSeconds) .. "!"
					left = State.ServerLuckLeft()
				else
					local def = Config.Boosts[product.Boost or ""]
					blurb = (if def then def.Name else "Boost") .. " for " .. Format.duration(if def then def.Seconds else 0) .. ". Stacks by adding time."
					left = State.BoostLeft(product.Boost or "")
				end
				if left > 0 then
					blurb ..= "\nActive: " .. Format.time(left)
				end
				local icon = if product.Kind == "ServerLuck" then Theme.Icons.Luck .. "🌍" elseif product.Boost == "Luck2x" then Theme.Icons.Luck else Theme.Icons.Coins .. Theme.Icons.Boost
				local c = card(i, icon, product.Name, blurb, if product.Kind == "ServerLuck" or product.Boost == "Luck2x" then Theme.Colors.Luck else Theme.Colors.Coins)
				buyButton(c, priceText("product", product.Id, product.Price), "Green", true, function()
					Shop.BuyProduct(product.Key)
				end)
			end
		end
	end
end
render = renderImpl

function Shop.Init()
	win = Windows.Create("Shop", { Title = "Shop", Icon = Theme.Icons.Shop, Color = Theme.Tones.Pink.Top })
	local _, sel = Kit.tabs(win.Body, { "Passes", "Gems", "Boosts" }, {
		Passes = Theme.Icons.Star .. " Passes",
		Gems = Theme.Icons.Gems .. " Gems",
		Boosts = Theme.Icons.Boost .. " Boosts",
	}, function(name: string)
		tab = name
		render()
	end)
	selectTab = sel
	content = Kit.scroll({
		Size = UDim2.new(1, 0, 1, -64),
		Position = UDim2.fromOffset(0, 64),
		Parent = win.Body,
	}, { Kit.grid(Vector2.new(260, 210), 12), Kit.pad(6, 8, 6, 6) })
	Windows.Register("Shop", function(which: string?)
		Windows.Show("Shop")
		selectTab(which or tab)
	end)
	State.Changed:Connect(function()
		render()
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who: Player, _id: number, bought: boolean)
		if who == player and bought then
			Toasts.Show("Thank you! Your pass is being added...", "good")
		end
	end)
end

return Shop
