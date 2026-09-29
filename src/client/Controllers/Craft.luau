--!nonstrict
-- Crafting panel: Workbench Tiers I–V, rope and bandages, and the
-- workbench upgrade. Costs show what you carry (+ team storage for
-- structures and upgrades, which may draw from storage).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local Net = require(Shared.Net)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")
local Panels = require("./Panels")

local Craft = {}

local player = Players.LocalPlayer
local body: ScrollingFrame
local C = Theme.Colors
local matchState = ReplicatedStorage:WaitForChild("MatchState")

local function benchLevel(): number
	local team = player:GetAttribute("Team") or 0
	return (matchState:GetAttribute("Bench" .. team) :: number?) or 1
end

local function costChips(parent: Instance, cost: { [string]: number }, useStorage: boolean, x: number, y: number): boolean
	local inv = State.Get("Inventory")
	local craft = State.Get("Craft")
	local storage = craft and craft.Storage or {}
	local okAll = true
	local frame = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.new(1, -x - 130, 0, 24), Parent = parent }, { UI.list(Enum.FillDirection.Horizontal, 4) })
	local ids = {}
	for id in cost do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local need = cost[id]
		local have = (inv and inv.Resources[id] or 0) + (if useStorage then storage[id] or 0 else 0)
		local ok = have >= need
		okAll = okAll and ok
		local def = Items[id]
		UI.new("TextLabel", {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = if ok then Color3.fromRGB(40, 70, 44) else Color3.fromRGB(80, 36, 32),
			Text = string.format(" %s %s %d/%d ", def.Icon.Glyph, def.Name, have, need),
			TextSize = 12,
			Font = Theme.FontBold,
			TextColor3 = C.Text,
			Parent = frame,
		}, { UI.corner(UDim.new(0, 6)) })
	end
	return okAll
end

local ROMAN = { "I", "II", "III", "IV", "V" }
local function tier(n: number): string
	return ROMAN[n] or tostring(n)
end

function Craft.Render()
	if not body then
		return
	end
	UI.clear(body)
	local level = benchLevel()
	local craft = State.Get("Craft")
	local near = craft and craft.NearBench
	local order = 1
	local head = UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 96), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = body }, { UI.corner(UDim.new(0, 8)) })
	order += 1
	UI.text("Workbench Tier " .. tier(level) .. " / " .. tier(Recipes.MaxWorkbenchLevel), { Position = UDim2.fromOffset(10, 6), TextSize = 20, Font = Theme.FontBlack, Parent = head })
	if level < Recipes.MaxWorkbenchLevel then
		local cost = Recipes.WorkbenchUpgrades[level + 1]
		UI.text("Upgrade to Tier " .. tier(level + 1) .. " (uses your pack + your storage):", { Position = UDim2.fromOffset(10, 32), TextSize = 13, TextColor3 = C.TextDim, Parent = head })
		local ok = costChips(head, cost, true, 10, 58)
		UI.button("Upgrade", { Size = UDim2.fromOffset(116, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), BackgroundColor3 = if ok then C.AccentDark else C.PanelLighter, Parent = head }, function()
			Net.Event("UpgradeWorkbench"):FireServer()
		end)
	else
		UI.text("Maximum level — every recipe unlocked.", { Position = UDim2.fromOffset(10, 36), TextSize = 14, TextColor3 = C.Good, Parent = head })
	end
	if not near then
		UI.text("Stand at your workbench to craft gear and upgrade. Rope can be twisted anywhere.", { LayoutOrder = order, TextSize = 13, TextColor3 = C.Warn, Parent = body })
		order += 1
	end
	local sorted = table.clone(Recipes.List)
	table.sort(sorted, function(a, b)
		return a.Order < b.Order
	end)
	local lastLevel = -1
	for _, r in sorted do
		if r.Level ~= lastLevel then
			lastLevel = r.Level
			UI.text(if r.Level == 0 then "Anywhere" else ("Tier " .. tier(r.Level) .. (if r.Level > level then "  🔒" else "")), { LayoutOrder = order, TextSize = 17, Font = Theme.FontBlack, TextColor3 = if r.Level > level then C.TextDim else C.Accent, Parent = body })
			order += 1
		end
		local def = Items[r.Result]
		local locked = r.Level > level
		local card = UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 74), BackgroundColor3 = C.PanelLight, BackgroundTransparency = if locked then 0.55 else 0.15, BorderSizePixel = 0, Parent = body }, { UI.corner(UDim.new(0, 8)) })
		order += 1
		local ic = UI.icon(def.Icon.Glyph, def.Icon.Color, 46, def.Icon.Shape, "Item_" .. r.Result)
		ic.Position = UDim2.fromOffset(8, 8)
		ic.Parent = card
		UI.text(def.Name .. (if r.Count > 1 then " ×" .. r.Count else "") .. (if r.Kind == "Structure" then "  (structure)" else ""), { Position = UDim2.fromOffset(62, 4), Size = UDim2.new(1, -200, 0, 20), TextSize = 16, Font = Theme.FontBold, Parent = card })
		UI.text(def.Description, { Position = UDim2.fromOffset(62, 24), Size = UDim2.new(1, -200, 0, 18), TextSize = 12, TextColor3 = C.TextDim, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = card })
		local ok = costChips(card, r.Cost, r.Kind == "Structure", 62, 46)
		local label = if locked then "Tier " .. tier(r.Level) elseif r.Kind == "Structure" then "Place" else "Craft"
		UI.button(label, { Size = UDim2.fromOffset(110, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), BackgroundColor3 = if locked or not ok then C.PanelLighter else C.AccentDark, Parent = card }, function()
			if locked then
				return
			end
			if r.Kind == "Structure" then
				Panels.Close()
				State.Emit("BeginBuild", r.Result)
			else
				Net.Event("Craft"):FireServer(r.Id)
			end
		end)
	end
end

function Craft.Start()
	body = Panels.Create("Craft", "WORKBENCH", Vector2.new(620, 640), Craft.Render)
	UI.list(Enum.FillDirection.Vertical, 6).Parent = body
	local function rerender()
		if Panels.IsOpen("Craft") then
			Craft.Render()
		end
	end
	State.On("Inventory", rerender)
	State.On("Craft", rerender)
	matchState.AttributeChanged:Connect(function(attr)
		if string.sub(attr, 1, 5) == "Bench" then
			rerender()
		end
	end)
	State.On("Action", function(a)
		if a.Down and a.Name == "Craft" and player:GetAttribute("InMatch") then
			Panels.Toggle("Craft")
		end
	end)
end

return Craft
