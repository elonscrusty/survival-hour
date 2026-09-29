--!nonstrict
-- Storage panel. Owners deposit/withdraw; enemies can take anything from a
-- storage they have breached (StorageService).

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

local Storage = {}

local player = Players.LocalPlayer
local body: ScrollingFrame
local C = Theme.Colors
local RES = InventoryModel.ResourceIds

local function act(action: string, resource: string?, count: number?)
	local s = State.Get("Storage")
	if not s or not s.Key then
		return
	end
	Net.Event("StorageAction"):FireServer({ Key = s.Key, Action = action, Resource = resource, Count = count })
end

function Storage.Render()
	UI.clear(body)
	local s = State.Get("Storage")
	local inv = State.Get("Inventory")
	if not s or not s.Items then
		return
	end
	local meta = s.Meta or {}
	local used = meta.SlotsUsed or InventoryModel.SlotsUsedBy(s.Items)
	local owner = s.Mode == "Owner"
	local loot = s.Mode == "Loot"
	local intro = if owner
		then (if meta.Breached then "⚠ BREACHED — enemies can take from it. Hold R at the storage to resecure it." else "Your storage. Everything here can be used to build and upgrade.")
		elseif loot then "BREACHED ENEMY STORAGE — take what fits in your pack."
		else "Locked. Breach it first (hold G at the storage)."
	UI.text((meta.Name or "Storage") .. "  ·  " .. intro, { LayoutOrder = 1, TextSize = 14, TextColor3 = if owner and not meta.Breached then C.TextDim else C.Warn, Size = UDim2.new(1, -8, 0, 40), Parent = body })
	local _, setBar = UI.bar({ LayoutOrder = 2, Size = UDim2.new(1, -8, 0, 20), Parent = body }, C.Info)
	setBar(used / math.max(1, s.Capacity), string.format("%d / %d stack slots", used, s.Capacity))
	if owner then
		UI.button("Deposit everything I carry", { LayoutOrder = 3, Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = C.AccentDark, Parent = body }, function()
			act("DepositAll")
		end)
	elseif loot then
		UI.button("Take everything that fits", { LayoutOrder = 3, Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = Color3.fromRGB(120, 60, 30), Parent = body }, function()
			act("TakeAll")
		end)
	end
	for i, id in RES do
		local def = Items[id]
		local have = s.Items[id] or 0
		local carry = inv and inv.Resources[id] or 0
		if not owner and have <= 0 then
			continue
		end
		if owner and have <= 0 and carry <= 0 then
			continue
		end
		local r = UI.new("Frame", { LayoutOrder = 10 + i, Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = body }, { UI.corner(UDim.new(0, 8)) })
		local ic = UI.icon(def.Icon.Glyph, def.Icon.Color, 40, "Square", "Item_" .. id)
		ic.Position = UDim2.fromOffset(6, 7)
		ic.Parent = r
		UI.text(string.format("%s   stored %d   ·   you carry %d", def.Name, have, carry), { Position = UDim2.fromOffset(54, 16), Size = UDim2.new(1, -330, 0, 22), TextSize = 15, Font = Theme.FontBold, Parent = r })
		if owner then
			UI.button("Put all", { Size = UDim2.fromOffset(70, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -158, 0.5, 0), TextSize = 13, Parent = r }, function()
				act("Deposit", id, math.max(1, carry))
			end)
			UI.button("Take 10", { Size = UDim2.fromOffset(70, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -82, 0.5, 0), TextSize = 13, BackgroundColor3 = Color3.fromRGB(50, 80, 110), Parent = r }, function()
				act("Withdraw", id, 10)
			end)
			UI.button("Take 1", { Size = UDim2.fromOffset(70, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), TextSize = 13, BackgroundColor3 = Color3.fromRGB(50, 80, 110), Parent = r }, function()
				act("Withdraw", id, 1)
			end)
		elseif loot then
			UI.button("Take all", { Size = UDim2.fromOffset(110, 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), TextSize = 14, BackgroundColor3 = Color3.fromRGB(120, 60, 30), Parent = r }, function()
				act("Withdraw", id, have)
			end)
		end
	end
end

function Storage.Start()
	body = Panels.Create("Storage", "STORAGE", Vector2.new(620, 560), nil, function()
		act("Close")
	end)
	UI.list(Enum.FillDirection.Vertical, 6).Parent = body
	State.On("Storage", function(s)
		if s.Mode == "Closed" then
			if Panels.IsOpen("Storage") then
				Panels.Close()
			end
			return
		end
		if not Panels.IsOpen("Storage") then
			Panels.Open("Storage")
		end
		Storage.Render()
	end)
	State.On("Inventory", function()
		if Panels.IsOpen("Storage") then
			Storage.Render()
		end
	end)
	local _ = player
end

return Storage
