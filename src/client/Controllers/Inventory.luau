--!nonstrict
-- Inventory panel + equip/swap/bandage/drop actions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local InventoryModel = require(Shared.Logic.InventoryModel)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")
local Panels = require("./Panels")

local Inventory = {}

local player = Players.LocalPlayer
local body: ScrollingFrame
local C = Theme.Colors
local SLOT_LABEL = { Weapon1 = "Weapon 1", Weapon2 = "Weapon 2", Tool = "Tool 1", Tool2 = "Tool 2", Utility = "Utility", ArmorHead = "Head (worn)", ArmorChest = "Chest (worn)", ArmorLegs = "Legs (worn)", Backpack = "Backpack (worn)" }
local RES = InventoryModel.ResourceIds

local function section(title: string, order: number)
	UI.text(title, { LayoutOrder = order, TextSize = 18, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = body })
end

local function row(order: number, height: number?): Frame
	return UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, height or 54), BackgroundColor3 = C.PanelLight, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = body }, { UI.corner(UDim.new(0, 8)) })
end

function Inventory.Render()
	if not body then
		return
	end
	UI.clear(body)
	local inv = State.Get("Inventory")
	if not inv then
		UI.text("No inventory outside a match.", { Parent = body })
		return
	end
	local total = 0
	for _, n in inv.Resources do
		total += n
	end
	section("Equipment", 1)
	local order = 2
	for _, slot in { "Weapon1", "Weapon2", "Tool", "Tool2", "Utility", "ArmorHead", "ArmorChest", "ArmorLegs", "Backpack" } do
		local piece = string.match(slot, "^Armor(%a+)$")
		local stack = if piece then (inv.Armor or {})[piece] elseif slot == "Backpack" then inv.Backpack else inv.Slots[slot]
		local r = row(order)
		order += 1
		UI.text(SLOT_LABEL[slot], { Position = UDim2.fromOffset(62, 4), Size = UDim2.new(0.5, 0, 0, 16), TextSize = 12, TextColor3 = C.TextDim, Parent = r })
		if stack and stack ~= false then
			local def = Items[stack.Id]
			local ic = UI.icon(def.Icon.Glyph, def.Icon.Color, 44, def.Icon.Shape)
			ic.Position = UDim2.fromOffset(6, 5)
			ic.Parent = r
			local extra = ""
			if stack.Durability and def.Durability then
				extra = string.format("  ·  %d/%d", stack.Durability, def.Durability)
			end
			if stack.Id == "Canteen" then
				extra = if stack.Filled then "  ·  FULL" else "  ·  empty"
			end
			UI.text(def.Name .. extra, { Position = UDim2.fromOffset(62, 20), Size = UDim2.new(1, -250, 0, 22), TextSize = 16, Font = Theme.FontBold, Parent = r })
			if def.Slots then
				extra = "  ·  " .. def.Slots .. " slots"
			end
			if not piece and slot ~= "Backpack" then
				UI.button(if inv.Equipped == slot then "Equipped" else "Equip", { Size = UDim2.fromOffset(92, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0), TextSize = 14, BackgroundColor3 = if inv.Equipped == slot then C.AccentDark else C.PanelLighter, Parent = r }, function()
					Net.Event("Equip"):FireServer(slot)
				end)
			end
			UI.button("Drop", { Size = UDim2.fromOffset(88, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), TextSize = 14, BackgroundColor3 = Color3.fromRGB(90, 44, 38), Parent = r }, function()
				Net.Event("DropItem"):FireServer({ Slot = slot })
			end)
		else
			UI.text("— empty —", { Position = UDim2.fromOffset(62, 20), TextSize = 15, TextColor3 = C.TextDim, Parent = r })
		end
	end
	local sw = row(order, 48)
	order += 1
	UI.button("⇄ Swap weapon slots (Q)", { Size = UDim2.new(1, -12, 0, 40), Position = UDim2.fromOffset(6, 4), TextSize = 15, Parent = sw }, function()
		Net.Event("SwapWeapons"):FireServer()
	end)

	section("Pouches", order)
	order += 1
	local pr = row(order, 54)
	order += 1
	UI.text(string.format("✚ Bandages %d/3   🏹 Arrows %d   ➶ Bolts %d   • Bullets %d", inv.Bandages, inv.Ammo.Arrow or 0, inv.Ammo.Bolt or 0, inv.Ammo.Bullet or 0), { Position = UDim2.fromOffset(10, 14), Size = UDim2.new(1, -130, 0, 24), TextSize = 16, Parent = pr })
	UI.button("Use bandage", { Size = UDim2.fromOffset(116, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), TextSize = 14, BackgroundColor3 = Color3.fromRGB(110, 40, 44), Parent = pr }, function()
		Net.Event("UseBandage"):FireServer()
	end)

	local used = inv.SlotsUsed or 0
	section(string.format("Pack  %d / %d slots  (%d items)", used, inv.Capacity, total), order)
	order += 1
	local _, setCap = UI.bar({ Size = UDim2.new(1, -8, 0, 14), LayoutOrder = order, Parent = body }, if used >= inv.Capacity then C.Warn else C.Good)
	order += 1
	setCap(used / math.max(1, inv.Capacity))
	for _, id in RES do
		local n = inv.Resources[id] or 0
		local def = Items[id]
		local r = row(order, 50)
		order += 1
		local ic = UI.icon(def.Icon.Glyph, def.Icon.Color, 38, "Square")
		ic.Position = UDim2.fromOffset(6, 6)
		ic.Parent = r
		UI.text(def.Name .. "  ×" .. n, { Position = UDim2.fromOffset(54, 14), Size = UDim2.new(1, -250, 0, 22), TextSize = 16, Font = Theme.FontBold, TextColor3 = if n > 0 then C.Text else C.TextDim, Parent = r })
		if n > 0 then
			UI.button("Drop 1", { Size = UDim2.fromOffset(80, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), TextSize = 13, Parent = r }, function()
				Net.Event("DropItem"):FireServer({ Resource = id, Count = 1 })
			end)
			UI.button("Drop all", { Size = UDim2.fromOffset(80, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), TextSize = 13, BackgroundColor3 = Color3.fromRGB(90, 44, 38), Parent = r }, function()
				Net.Event("DropItem"):FireServer({ Resource = id, Count = n })
			end)
		end
		if (def.Food or def.Heal) and n > 0 then
			UI.button(if def.Heal then "Use" else "Eat", { Size = UDim2.fromOffset(80, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -184, 0.5, 0), TextSize = 13, BackgroundColor3 = Color3.fromRGB(60, 110, 60), Parent = r }, function()
				Net.Event("Eat"):FireServer(id)
			end)
		end
		if id == "Rope" then
			UI.button("Twist rope (3 fibre)", { Size = UDim2.fromOffset(150, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -184, 0.5, 0), TextSize = 13, BackgroundColor3 = C.AccentDark, Parent = r }, function()
				Net.Event("Craft"):FireServer("Rope")
			end)
		end
	end
	UI.text("Carried materials drop on death. Tools, weapons, armour, ammo and bandages are kept.", { LayoutOrder = order, TextSize = 13, TextColor3 = C.TextDim, Parent = body })
end

local slotCycle = { "Fists", "Weapon1", "Weapon2", "Tool", "Tool2", "Utility" }

local function equip(slot: string?)
	Net.Event("Equip"):FireServer(slot)
end

function Inventory.Start()
	body = Panels.Create("Inventory", "INVENTORY", Vector2.new(560, 620), Inventory.Render)
	UI.list(Enum.FillDirection.Vertical, 6).Parent = body
	State.On("Inventory", function()
		if Panels.IsOpen("Inventory") then
			Inventory.Render()
		end
	end)
	State.On("Action", function(a)
		if not a.Down or not player:GetAttribute("InMatch") then
			return
		end
		local n = a.Name
		if n == "Inventory" then
			Panels.Toggle("Inventory")
		elseif n == "Slot1" then
			equip("Weapon1")
		elseif n == "Slot2" then
			equip("Weapon2")
		elseif n == "Slot3" then
			equip("Tool")
		elseif n == "Slot4" then
			equip("Tool2")
		elseif n == "Slot5" then
			equip("Utility")
		elseif n == "Fists" then
			equip(nil)
		elseif n == "Swap" then
			if not State.Get("Building") then
				Net.Event("SwapWeapons"):FireServer()
			end
		elseif n == "Bandage" then
			Net.Event("UseBandage"):FireServer()
		elseif n == "NextSlot" or n == "PrevSlot" then
			local inv = State.Get("Inventory")
			if not inv then
				return
			end
			local cur = if inv.Equipped then table.find(slotCycle, inv.Equipped) or 1 else 1
			for step = 1, #slotCycle do
				local i = ((cur - 1 + (if n == "NextSlot" then step else -step)) % #slotCycle) + 1
				local s = slotCycle[i]
				if s == "Fists" or inv.Slots[s] then
					equip(if s == "Fists" then nil else s)
					break
				end
			end
		end
	end)
end

return Inventory
