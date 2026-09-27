--!nonstrict
-- Shared storage panel. Owners deposit/withdraw; enemies choose a resource to
-- steal (3 s, taking damage interrupts, takes up to 10 within pack space).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
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
	local total = 0
	for _, n in s.Items do
		total += n
	end
	local owner = s.Mode == "Owner"
	UI.text(if owner then "Your clan's shared storage. Anyone on your team can use it to build and upgrade." else "ENEMY STORAGE — pick a resource to steal. Hold still: taking damage interrupts the theft.", { LayoutOrder = 1, TextSize = 14, TextColor3 = if owner then C.TextDim else C.Warn, Size = UDim2.new(1, -8, 0, 36), Parent = body })
	local _, setBar = UI.bar({ LayoutOrder = 2, Size = UDim2.new(1, -8, 0, 20), Parent = body }, C.Info)
	setBar(total / math.max(1, s.Capacity), string.format("Stored %d / %d", total, s.Capacity))
	if owner then
		UI.button("Deposit everything I carry", { LayoutOrder = 3, Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = C.AccentDark, Parent = body }, function()
			act("DepositAll")
		end)
	end
	for i, id in RES do
		local def = Items[id]
		local have = s.Items[id] or 0
		local carry = inv and inv.Resources[id] or 0
		local r = UI.new("Frame", { LayoutOrder = 10 + i, Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = body }, { UI.corner(UDim.new(0, 8)) })
		local ic = UI.icon(def.Icon.Glyph, def.Icon.Color, 40, "Square")
		ic.Position = UDim2.fromOffset(6, 7)
		ic.Parent = r
		UI.text(string.format("%s   stored %d   ·   you carry %d", def.Name, have, carry), { Position = UDim2.fromOffset(54, 16), Size = UDim2.new(1, -330, 0, 22), TextSize = 15, Font = Theme.FontBold, Parent = r })
		if owner then
			UI.button("Put 5", { Size = UDim2.fromOffset(70, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -234, 0.5, 0), TextSize = 13, Parent = r }, function()
				act("Deposit", id, 5)
			end)
			UI.button("Put all", { Size = UDim2.fromOffset(70, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -158, 0.5, 0), TextSize = 13, Parent = r }, function()
				act("Deposit", id, math.max(1, carry))
			end)
			UI.button("Take 5", { Size = UDim2.fromOffset(70, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -82, 0.5, 0), TextSize = 13, BackgroundColor3 = Color3.fromRGB(50, 80, 110), Parent = r }, function()
				act("Withdraw", id, 5)
			end)
			UI.button("Take 1", { Size = UDim2.fromOffset(70, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), TextSize = 13, BackgroundColor3 = Color3.fromRGB(50, 80, 110), Parent = r }, function()
				act("Withdraw", id, 1)
			end)
		elseif have > 0 then
			UI.button("Steal (" .. Config.Storage.StealDuration .. "s)", { Size = UDim2.fromOffset(130, 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), TextSize = 14, BackgroundColor3 = Color3.fromRGB(120, 60, 30), Parent = r }, function()
				act("Steal", id)
				Panels.Close()
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
