--!nonstrict
-- In-match shop: public care package calls (paid random item → full odds are
-- shown before purchase, region-restricted players can't buy) and bandages.
-- Also lists stored credits (deferred purchases).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Loot = require(Shared.Loot)
local Products = require(Shared.Products)
local Net = require(Shared.Net)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")
local Panels = require("./Panels")
local Hud = require("./Hud")

local Shop = {}

local player = Players.LocalPlayer
local body: ScrollingFrame
local C = Theme.Colors
local matchState = ReplicatedStorage:WaitForChild("MatchState")

local function oddsTable(parent: Instance, order: number)
	local box = UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = parent }, { UI.corner(UDim.new(0, 8)), UI.padding(8), UI.list(Enum.FillDirection.Vertical, 2) })
	UI.text("Odds — each of the 3 items is rolled independently from this table:", { TextSize = 13, Font = Theme.FontBold, Parent = box })
	local total = Loot.TotalWeight(Loot.CarePackage)
	for i, e in Loot.CarePackage do
		UI.text(string.format("%-34s %5.1f%%", e.Label, e.Weight / total * 100), { LayoutOrder = i, TextSize = 13, Font = Enum.Font.RobotoMono, Parent = box })
	end
	UI.text("Total 100%. Contents drop on the ground for anyone to pick up.", { LayoutOrder = 99, TextSize = 12, TextColor3 = C.TextDim, Parent = box })
end

function Shop.Render()
	UI.clear(body)
	local profile = State.Get("Profile")
	local credits = profile and profile.Credits or { CarePackage = 0, Bandage = 0, Revive = {} }
	local night = matchState:GetAttribute("Phase") == "Night"
	local restricted = player:GetAttribute("PaidRandomRestricted") == true
	local order = 1
	-- Care package
	local card = UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 150), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = body }, { UI.corner(UDim.new(0, 8)), UI.padding(10) })
	order += 1
	local ic = UI.icon("✚", C.Accent, 56, "Square")
	ic.Parent = card
	UI.text("Call a Public Care Package", { Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -200, 0, 24), TextSize = 18, Font = Theme.FontBlack, Parent = card })
	UI.text("Everyone is told where it lands, and any clan can open it (3 random items).\n" .. (if night then "It's night: your package will be queued and drop at DAWN." else "Drops shortly after purchase (drops are spaced out)."), { Position = UDim2.fromOffset(66, 26), Size = UDim2.new(1, -200, 0, 60), TextSize = 13, TextColor3 = if night then C.Warn else C.TextDim, Parent = card })
	if restricted then
		UI.text("Paid care packages aren't available in your region. The free daily package still drops for everyone.", { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 34), TextSize = 13, TextColor3 = C.Warn, Parent = card })
	else
		local label = if (credits.CarePackage or 0) > 0 then "Use credit (" .. credits.CarePackage .. ")" else Hud.PriceText("CarePackage")
		UI.button(label, { Size = UDim2.fromOffset(160, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(40, 110, 60), Parent = card }, function()
			Net.Event("BuyInMatch"):FireServer({ Kind = "CarePackage" })
		end)
		UI.text("Odds are listed below ↓", { Position = UDim2.new(0, 66, 0, 100), TextSize = 13, TextColor3 = C.Info, Parent = card })
	end
	if not restricted then
		oddsTable(body, order)
		order += 1
	end
	-- Bandage
	local bcard = UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 86), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = body }, { UI.corner(UDim.new(0, 8)), UI.padding(10) })
	order += 1
	local bic = UI.icon("✚", C.Bad, 56, "Round")
	bic.Parent = bcard
	UI.text("Bandage", { Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -200, 0, 24), TextSize = 18, Font = Theme.FontBlack, Parent = bcard })
	UI.text("Heals 45 HP over 3 s. Delivered to your pouch (max 3); extras are stored for later.", { Position = UDim2.fromOffset(66, 26), Size = UDim2.new(1, -240, 0, 40), TextSize = 13, TextColor3 = C.TextDim, Parent = bcard })
	UI.button(Hud.PriceText("Bandage"), { Size = UDim2.fromOffset(160, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(40, 110, 60), Parent = bcard }, function()
		Net.Event("BuyInMatch"):FireServer({ Kind = "Bandage" })
	end)
	-- Credits
	local rev = {}
	for tier, n in credits.Revive or {} do
		table.insert(rev, "tier " .. tier .. " ×" .. n)
	end
	UI.text(string.format("Stored credits — Care packages: %d · Bandages: %d · Revives: %s", credits.CarePackage or 0, credits.Bandage or 0, if #rev > 0 then table.concat(rev, ", ") else "none"), { LayoutOrder = order, TextSize = 13, TextColor3 = C.TextDim, Parent = body })
end

function Shop.Start()
	body = Panels.Create("Shop", "SUPPLY SHOP", Vector2.new(620, 620), Shop.Render)
	UI.list(Enum.FillDirection.Vertical, 8).Parent = body
	local gui = UI.new("ScreenGui", { Name = "ShopButton", ResetOnSpawn = false, DisplayOrder = 4, Parent = player:WaitForChild("PlayerGui") })
	local btn = UI.button("✚ Shop", { Size = UDim2.fromOffset(96, 44), Position = UDim2.new(0, 12, 1, -176), BackgroundColor3 = Color3.fromRGB(60, 90, 50), Parent = gui }, function()
		Panels.Toggle("Shop")
	end)
	local function vis()
		-- Nothing gameplay-affecting is sold (non-pay-to-win), so the in-match shop stays hidden.
		btn.Visible = player:GetAttribute("InMatch") == true and (Products.OnSale("CarePackage") or Products.OnSale("Bandage"))
	end
	player:GetAttributeChangedSignal("InMatch"):Connect(vis)
	vis()
	State.On("PricesUpdated", function()
		if Panels.IsOpen("Shop") then
			Shop.Render()
		end
	end)
	State.On("Profile", function()
		if Panels.IsOpen("Shop") then
			Shop.Render()
		end
	end)
end

return Shop
