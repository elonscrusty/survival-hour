--!strict
-- Codes: text box + Redeem. Distinct looks for each result: code_ok (green), code_invalid (red),
-- code_used (orange), code_expired (grey), tutorial (blue), rate_limited (orange), busy/loading.
-- Opened from the Shop (Back returns to the Shop).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared:WaitForChild("Contract"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Button = require(UI.Button)
local Icon = require(UI.Icon)

local M = {
	Name = "Codes",
	Title = "Codes",
	Icon = "code",
	Color = Theme.Color.Purple,
	MaxSize = Vector2.new(560, 440),
}

local LOOK: { [string]: { color: Color3, icon: string } } = {
	idle = { color = Theme.Color.GrayDark, icon = "code" },
	loading = { color = Theme.Color.Blue, icon = "clock" },
	code_ok = { color = Theme.Color.Green, icon = "check" },
	code_invalid = { color = Theme.Color.Red, icon = "close" },
	code_used = { color = Theme.Color.Orange, icon = "check" },
	code_expired = { color = Theme.Color.Gray, icon = "clock" },
	tutorial = { color = Theme.Color.Blue, icon = "lock" },
	rate_limited = { color = Theme.Color.Orange, icon = "clock" },
	error = { color = Theme.Color.Red, icon = "close" },
}

function M.Build(host: any, panel: any)
	local body = panel.Body
	Util.List(body, 12)

	Util.Text({
		text = "Got a code? Type it here to get free rewards!",
		size = UDim2.new(1, 0, 0, 0),
		textSize = Theme.Text.M,
		color = Theme.Color.TextDark,
		wrap = true,
		order = 1,
		parent = body,
	})

	local box = Instance.new("TextBox")
	box.Name = "CodeBox"
	box.LayoutOrder = 2
	box.Size = UDim2.new(1, 0, 0, 64)
	box.BackgroundColor3 = Theme.Color.Card
	box.PlaceholderText = "Enter code"
	box.PlaceholderColor3 = Theme.Color.TextMuted
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Font = Theme.Font.Title
	box.TextColor3 = Theme.Color.TextDark
	box.TextScaled = true
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = Theme.Text.L
	c.MinTextSize = Theme.Text.Min
	c.Parent = box
	Util.Corner(box, 14)
	local boxStroke = Util.Stroke(box, 3, Theme.Color.Ink, true)
	Util.Pad(box, 12, 6, 6)
	box.Parent = body

	local status = Instance.new("Frame")
	status.LayoutOrder = 4
	status.Size = UDim2.new(1, 0, 0, 56)
	status.BackgroundColor3 = Theme.Color.GrayDark
	Util.Corner(status, 14)
	Util.Stroke(status, 3, Theme.Color.Ink, true)
	status.Parent = body
	local iconHolder = Instance.new("Frame")
	iconHolder.BackgroundTransparency = 1
	iconHolder.Size = UDim2.fromOffset(40, 40)
	iconHolder.Position = UDim2.fromOffset(10, 8)
	iconHolder.Parent = status
	local statusText = Util.Text({
		text = "",
		size = UDim2.new(1, -64, 1, -8),
		position = UDim2.fromOffset(56, 4),
		textSize = Theme.Text.M,
		font = Theme.Font.Title,
		xAlign = Enum.TextXAlignment.Left,
		outline = true,
		parent = status,
	})

	local function setState(state: string, message: string?)
		local look = LOOK[state] or LOOK.error
		status.BackgroundColor3 = look.color
		boxStroke.Color = if state == "idle" or state == "loading" then Theme.Color.Ink else look.color
		Util.Clear(iconHolder)
		Icon.new(look.icon, 40, iconHolder)
		statusText.Text = message or ""
		Util.Pop(status, 0.06)
	end
	setState("idle", "Codes are not case sensitive.")

	local busy = false
	local redeem: any
	redeem = Button.new({
		text = "Redeem",
		color = Theme.Color.Green,
		size = UDim2.new(1, 0, 0, 64),
		order = 3,
		parent = body,
		onClick = function()
			if busy then
				return
			end
			local text = string.gsub(box.Text, "^%s+", "")
			text = string.gsub(text, "%s+$", "")
			if text == "" then
				setState("code_invalid", "Type a code first.")
				Util.Shake(box)
				return
			end
			busy = true
			redeem:SetText("...")
			redeem:SetColor(Theme.Color.Gray)
			setState("loading", "Checking code...")
			local res = host.Store.Request({ type = "redeemCode", text = text })
			busy = false
			redeem:SetText("Redeem")
			redeem:SetColor(Theme.Color.Green)
			if res.code == "busy" then
				setState("loading", "Still checking...")
				return
			end
			local msg = res.message or Contract.Messages[res.code] or "That didn't work."
			setState(res.code, msg)
			if res.ok or res.code == "code_ok" then
				host:Sound("claim")
				box.Text = ""
			else
				host:Sound("error")
				Util.Shake(status)
			end
		end,
	})

	local inst = {}
	function inst.OnShow()
		if not busy then
			setState("idle", "Codes are not case sensitive.")
		end
	end
	return inst
end

return M
