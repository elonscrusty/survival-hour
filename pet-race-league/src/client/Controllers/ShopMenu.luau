-- Shop: trails and paint for your ridden pet (coins), plus the Robux tab.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Cosmetics)
local Products = require(Shared.Products)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.Hud)

local ShopMenu = {}

local panel: Frame
local list: ScrollingFrame
local tab = "Trail"
local tabButtons: { [string]: TextButton } = {}

local function productFor(cosmeticId: string)
	for _, p in Products.Dev do
		if p.Cosmetic == cosmeticId then
			return p
		end
	end
	return nil
end

local function row(order: number, height: number?): Frame
	local f = UI.Frame({ Size = UDim2.new(1, -10, 0, height or 64), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = order }, list)
	UI.Corner(f, 10)
	return f
end

local function render()
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == tab then UI.Colors.Blue else UI.Colors.PanelLight
	end
	local d = State.Data
	if not d then
		return
	end
	local pet = State.Equipped()
	if tab == "Robux" then
		local any = false
		for i, p in Products.Dev do
			if p.Id then
				any = true
				local f = row(i)
				UI.Text({ Text = p.Name, Size = UDim2.new(0.6, 0, 0.6, 0), Position = UDim2.new(0, 12, 0.2, 0), TextXAlignment = Enum.TextXAlignment.Left }, f)
				UI.Button({ Text = "R$ " .. p.Robux, Size = UDim2.new(0.3, 0, 0.7, 0), Position = UDim2.new(0.68, 0, 0.15, 0), BackgroundColor3 = UI.Colors.Green }, f, function()
					MarketplaceService:PromptProductPurchase(Players.LocalPlayer, p.Id :: number)
				end)
			end
		end
		for i, pass in Products.Passes do
			if pass.Id then
				any = true
				local f = row(100 + i)
				UI.Text({ Text = pass.Name, Size = UDim2.new(0.6, 0, 0.6, 0), Position = UDim2.new(0, 12, 0.2, 0), TextXAlignment = Enum.TextXAlignment.Left }, f)
				if pass.Key == "BigBarn" and d.BigBarn then
					UI.Text({ Text = "Owned", Size = UDim2.new(0.3, 0, 0.6, 0), Position = UDim2.new(0.68, 0, 0.2, 0), TextColor3 = UI.Colors.Green }, f)
				else
					UI.Button({ Text = "R$ " .. pass.Robux, Size = UDim2.new(0.3, 0, 0.7, 0), Position = UDim2.new(0.68, 0, 0.15, 0), BackgroundColor3 = UI.Colors.Green }, f, function()
						MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id :: number)
					end)
				end
			end
		end
		if not any then
			UI.Text({ Text = "Robux shop opens soon!", Size = UDim2.new(1, 0, 0, 40), TextColor3 = UI.Colors.Muted }, list)
		end
		return
	end
	local current = pet and (if tab == "Trail" then pet.Trail else pet.Paint)
	local f0 = row(0, 50)
	UI.Text({ Text = "None", Size = UDim2.new(0.5, 0, 0.6, 0), Position = UDim2.new(0, 12, 0.2, 0), TextXAlignment = Enum.TextXAlignment.Left }, f0)
	if current then
		UI.Button({ Text = "Use", Size = UDim2.new(0.3, 0, 0.7, 0), Position = UDim2.new(0.68, 0, 0.15, 0) }, f0, function()
			Net.Event("SetCosmetic"):FireServer(tab, nil)
		end)
	end
	for i, c in Cosmetics.List do
		if c.Kind == tab then
			local f = row(i)
			local sw = UI.Frame({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 10, 0.5, -22), BackgroundColor3 = UI.Rgb(c.Colors[1]) }, f)
			UI.Corner(sw, 22)
			if #c.Colors > 1 then
				local g = Instance.new("UIGradient")
				local keys = {}
				for k, col in c.Colors do
					table.insert(keys, ColorSequenceKeypoint.new((k - 1) / (#c.Colors - 1), UI.Rgb(col)))
				end
				g.Color = ColorSequence.new(keys)
				g.Parent = sw
				sw.BackgroundColor3 = Color3.new(1, 1, 1)
			end
			UI.Text({ Text = c.Name, Size = UDim2.new(0.5, -60, 0.6, 0), Position = UDim2.new(0, 64, 0.2, 0), TextXAlignment = Enum.TextXAlignment.Left }, f)
			local btnSize, btnPos = UDim2.new(0.3, 0, 0.7, 0), UDim2.new(0.68, 0, 0.15, 0)
			if d.Owned[c.Id] then
				if current == c.Id then
					UI.Text({ Text = "Using", Size = btnSize, Position = btnPos, TextColor3 = UI.Colors.Green }, f)
				else
					UI.Button({ Text = "Use", Size = btnSize, Position = btnPos }, f, function()
						Net.Event("SetCosmetic"):FireServer(tab, c.Id)
					end)
				end
			elseif c.Price then
				UI.Button({ Text = "$ " .. c.Price, Size = btnSize, Position = btnPos, BackgroundColor3 = if d.Coins >= c.Price then UI.Colors.Gold else UI.Colors.PanelLight }, f, function()
					Net.Event("BuyCosmetic"):FireServer(c.Id)
				end)
			else
				local prod = productFor(c.Id)
				if prod and prod.Id then
					UI.Button({ Text = "R$ " .. prod.Robux, Size = btnSize, Position = btnPos, BackgroundColor3 = UI.Colors.Green }, f, function()
						MarketplaceService:PromptProductPurchase(Players.LocalPlayer, prod.Id :: number)
					end)
				else
					UI.Text({ Text = "Soon", Size = btnSize, Position = btnPos, TextColor3 = UI.Colors.Muted }, f)
				end
			end
		end
	end
end

function ShopMenu.Open()
	panel.Visible = true
	render()
end

function ShopMenu.Start()
	local body
	panel, body = UI.Modal("Shop", UDim2.fromScale(0.8, 0.8))
	local tabs = UI.Frame({ Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, body)
	for i, name in { "Trail", "Paint", "Robux" } do
		tabButtons[name] = UI.Button({ Text = if name == "Trail" then "Trails" else name, Size = UDim2.new(1 / 3, -6, 1, 0), Position = UDim2.new((i - 1) / 3, 3, 0, 0) }, tabs, function()
			tab = name
			render()
		end)
	end
	list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -52)
	list.Position = UDim2.fromOffset(0, 52)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	Hud.SetOpener("Shop", ShopMenu.Open)
	State.OnChange(function()
		if panel.Visible then
			render()
		end
	end)
end

return ShopMenu
