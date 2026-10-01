--!strict
-- Lower-left phone: buyer offers with Accept / Raise / Decline, better and final offers,
-- and "no deal" endings. Sits above the mobile thumbstick on touch devices.
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Format = require(Shared.Logic.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local Bus = require(script.Parent.Bus)
local State = require(script.Parent.State)

local C = Kit.C
local new = Kit.new

local PhoneUI = {}

local phone: Frame
local chat: Frame
local actions: Frame
local offerId: number? = nil
local raiseBtn: Kit.Button
local buttonsAll: { Kit.Button } = {}

local function bubble(text: string, mine: boolean)
	local b = new("Frame", { Size = UDim2.new(0.86, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = if mine then C.blue else Color3.fromRGB(235, 235, 240), LayoutOrder = #chat:GetChildren(), Parent = chat }, { Kit.corner(12), Kit.pad(8) })
	b.Position = UDim2.fromScale(if mine then 0.14 else 0, 0)
	new("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Kit.FONT_BODY, TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if mine then C.white else C.ink, Text = text, Parent = b })
	-- keep the latest few messages
	local kids = {}
	for _, k in chat:GetChildren() do
		if k:IsA("Frame") then
			table.insert(kids, k)
		end
	end
	if #kids > 4 then
		kids[1]:Destroy()
	end
end

local function setButtons(on: boolean)
	actions.Visible = on
	for _, b in buttonsAll do
		b.setPending(false)
	end
end

local function hideSoon()
	task.delay(2.8, function()
		if offerId == nil then
			Kit.tween(phone, 0.35, { Position = UDim2.new(0, -320, 1, phone.Position.Y.Offset) })
		end
	end)
end

local function showPhone()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local y = if touch then -200 else -96
	phone.Position = UDim2.new(0, -320, 1, y)
	Kit.tween(phone, 0.35, { Position = UDim2.new(0, 12, 1, y) }, Enum.EasingStyle.Back)
end

local function respond(action: string)
	if not offerId then
		return
	end
	for _, b in buttonsAll do
		b.setPending(true)
	end
	bubble(if action == "accept" then "Deal!" elseif action == "raise" then "Can you do better?" else "No thanks.", true)
	State.send("phone", offerId, action)
end

function PhoneUI.init()
	local _, root = Kit.canvas("Phone", 15)
	phone = new("Frame", { Size = UDim2.fromOffset(250, 330), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, -320, 1, -96), BackgroundColor3 = Color3.fromRGB(40, 40, 50), Parent = root }, { Kit.corner(26), Kit.stroke(C.shadow, 3) })
	local screen = new("Frame", { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.bg, Parent = phone }, { Kit.corner(20) })
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.mustard, Parent = screen }, { Kit.corner(20) })
	local who = Kit.label({ Text = "📱 Messages", Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Parent = header, TextColor3 = C.ink, MaxText = 20 })
	chat = new("Frame", { Size = UDim2.new(1, -12, 1, -150), Position = UDim2.fromOffset(6, 46), BackgroundTransparency = 1, Parent = screen }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }),
	})
	actions = new("Frame", { Size = UDim2.new(1, -12, 0, 98), Position = UDim2.new(0, 6, 1, -102), BackgroundTransparency = 1, Parent = screen })
	local accept = Kit.button({ text = "Accept", color = C.green, dark = C.greenDark, size = UDim2.new(1, 0, 0, 46), parent = actions, textSize = 22, onClick = function()
		respond("accept")
	end })
	raiseBtn = Kit.button({ text = "Raise", color = C.gold, dark = C.goldDark, size = UDim2.new(0.5, -4, 0, 46), pos = UDim2.fromOffset(0, 52), parent = actions, textSize = 20, onClick = function()
		respond("raise")
	end })
	local decline = Kit.button({ text = "Decline", color = C.red, dark = C.redDark, size = UDim2.new(0.5, -4, 0, 46), pos = UDim2.new(0.5, 4, 0, 52), parent = actions, textSize = 20, onClick = function()
		respond("decline")
	end })
	buttonsAll = { accept, raiseBtn, decline }

	State.Notify:Connect(function(kind, data)
		if kind ~= "phone" then
			return
		end
		local o = data.offer
		local amount = Format.cash(Bus.big(o.amount))
		if data.outcome == "new" then
			for _, k in chat:GetChildren() do
				if k:IsA("Frame") then
					k:Destroy()
				end
			end
			offerId = o.id
			who.Text = "📱 " .. o.buyer
			bubble(string.format("Hey! I'll pay %s for a truckload of your hot dogs. Deal?", amount), false)
			raiseBtn.setText("Raise")
			setButtons(true)
			showPhone()
		elseif data.outcome == "better" then
			bubble(string.format("Okay, okay… %s. How's that?", amount), false)
			setButtons(true)
		elseif data.outcome == "final" then
			bubble(string.format("Final offer: %s. Take it or leave it!", amount), false)
			raiseBtn.setText("Push it")
			setButtons(true)
		elseif data.outcome == "accepted" then
			bubble("Pleasure doing business! 🌭", false)
			offerId = nil
			setButtons(false)
			hideSoon()
		elseif data.outcome == "walked" then
			bubble("No deal. Goodbye!", false)
			offerId = nil
			setButtons(false)
			hideSoon()
		elseif data.outcome == "declined" then
			bubble("Maybe next time!", false)
			offerId = nil
			setButtons(false)
			hideSoon()
		elseif data.outcome == "expired" or data.outcome == "closed" then
			bubble("Guess you're busy. Bye!", false)
			offerId = nil
			setButtons(false)
			hideSoon()
		end
	end)
end

return PhoneUI
