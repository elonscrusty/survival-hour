--!strict
-- Settings: music, sfx, effects, autoSpawn, confirmSpend toggles; flock low/normal/high;
-- notation short/scientific. Each change is a setSetting request; the switches always show the
-- server-confirmed value from the latest snapshot (a rejected change snaps back).

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Card = require(UI.Card)
local Button = require(UI.Button)
local Icon = require(UI.Icon)

local M = {
	Name = "Settings",
	Title = "Settings",
	Icon = "settings",
	Color = Theme.Color.GrayDark,
}

type Choice = { id: string, title: string, detail: string, icon: string, options: { { value: any, label: string } } }

local CHOICES: { Choice } = {
	{ id = "music", title = "Music", detail = "Background music", icon = "music", options = { { value = true, label = "ON" }, { value = false, label = "OFF" } } },
	{ id = "sfx", title = "Sound Effects", detail = "Clicks, coins and cheers", icon = "music", options = { { value = true, label = "ON" }, { value = false, label = "OFF" } } },
	{ id = "effects", title = "Effects", detail = "Popups and particles", icon = "shine", options = { { value = true, label = "ON" }, { value = false, label = "OFF" } } },
	{ id = "autoSpawn", title = "Auto Spawn", detail = "Spawn chickens automatically (after the tutorial)", icon = "auto", options = { { value = true, label = "ON" }, { value = false, label = "OFF" } } },
	{ id = "confirmSpend", title = "Confirm Gold Eggs", detail = "Ask before spending Gold Eggs", icon = "gold", options = { { value = true, label = "ON" }, { value = false, label = "OFF" } } },
	{ id = "flock", title = "Visible Chickens", detail = "Lower is faster on older phones", icon = "chick", options = { { value = "low", label = "LOW" }, { value = "normal", label = "MID" }, { value = "high", label = "HIGH" } } },
	{ id = "notation", title = "Big Numbers", detail = "1.2M or 1.2e6", icon = "cash", options = { { value = "short", label = "1.2M" }, { value = "scientific", label = "1e6" } } },
}

function M.Build(host: any, panel: any)
	local scroll = Util.Scroll(panel.Body)
	Util.List(scroll, 8)
	Util.Pad(scroll, 4)
	local updaters: { (any) -> () } = {}
	local pending: { [string]: boolean } = {}

	for i, c in CHOICES do
		-- title on top, options underneath: fits narrow portrait phones
		local card = Card.new({ size = UDim2.new(1, -8, 0, 0), order = i, parent = scroll })
		card.AutomaticSize = Enum.AutomaticSize.Y
		Util.Pad(card, 10)
		Util.List(card, 6, false, Enum.HorizontalAlignment.Left)
		local head = Instance.new("Frame")
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, 0, 0, 0)
		head.AutomaticSize = Enum.AutomaticSize.Y
		head.LayoutOrder = 1
		head.Parent = card
		local ic = Icon.new(c.icon, 44)
		ic.Parent = head
		local texts = Instance.new("Frame")
		texts.BackgroundTransparency = 1
		texts.Position = UDim2.fromOffset(54, 0)
		texts.Size = UDim2.new(1, -54, 0, 0)
		texts.AutomaticSize = Enum.AutomaticSize.Y
		texts.Parent = head
		Util.List(texts, 0, false, Enum.HorizontalAlignment.Left)
		Util.Text({
			text = c.title,
			size = UDim2.new(1, 0, 0, 0),
			textSize = Theme.Text.M,
			color = Theme.Color.TextDark,
			font = Theme.Font.Title,
			xAlign = Enum.TextXAlignment.Left,
			wrap = true,
			order = 1,
			parent = texts,
		})
		local detail = Util.Text({
			text = c.detail,
			size = UDim2.new(1, 0, 0, 0),
			textSize = Theme.Text.S,
			color = Theme.Color.TextMuted,
			xAlign = Enum.TextXAlignment.Left,
			wrap = true,
			order = 2,
			parent = texts,
		})
		local opts = Instance.new("Frame")
		opts.BackgroundTransparency = 1
		opts.Size = UDim2.new(1, 0, 0, 60)
		opts.LayoutOrder = 2
		opts.Parent = card
		Util.List(opts, 6, true, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		local row = { Action = opts, Detail = detail }
		local btns = {}
		for j, opt in c.options do
			local b = Button.new({
				text = opt.label,
				color = Theme.Color.Gray,
				size = UDim2.fromOffset(96, 60),
				textSize = Theme.Text.M,
				order = j,
				parent = row.Action,
				onClick = function()
					local snap = host.Store.Get()
					if not snap or pending[c.id] or snap.settings[c.id] == opt.value then
						return
					end
					pending[c.id] = true
					local action = if c.id == "autoSpawn"
						then { type = "setAutoSpawn", value = opt.value }
						else { type = "setSetting", id = c.id, value = opt.value }
					host:Request(action)
					pending[c.id] = nil
					local now = host.Store.Get()
					if now then
						for _, u in updaters do
							u(now)
						end
					end
				end,
			})
			btns[j] = b
		end
		table.insert(updaters, function(snap)
			local cur = snap.settings[c.id]
			for j, opt in c.options do
				local on = cur == opt.value
				btns[j]:SetColor(if on then (if opt.value == false then Theme.Color.Red else Theme.Color.Green) else Theme.Color.Gray)
				btns[j].Label.TextTransparency = if on then 0 else 0.35
			end
			if c.id == "autoSpawn" then
				row.Detail.Text = if snap.tutorial.done then c.detail else "Unlocks when you finish the tutorial."
			end
		end)
	end

	local inst = {}
	function inst.Refresh(snap: any)
		for _, u in updaters do
			u(snap)
		end
	end
	return inst
end

return M
