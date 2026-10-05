--!strict
-- Studio-only DEV panel: quick test shortcuts (coins, gems, finish
-- expeditions, open gates, reset data) through the DevAction remote. Not
-- created at all outside Studio, and the server refuses it there too.

local RunService = game:GetService("RunService")

local Remote = require("../Core/Remote")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Toasts = require("../UI/Toasts")

local DevPanel = {}

type Action = { Key: string, Label: string, Tone: string, Confirm: string? }

local ACTIONS: { Action } = {
	{ Key = "Coins1M", Label = Theme.Icons.Coins .. " +1M coins", Tone = "Yellow" },
	{ Key = "CoinsX1000", Label = Theme.Icons.Coins .. " Coins x1000", Tone = "Yellow" },
	{ Key = "Gems1000", Label = Theme.Icons.Gems .. " +1000 gems", Tone = "Cyan" },
	{ Key = "FinishExpeditions", Label = Theme.Icons.Expeditions .. " Finish expeditions", Tone = "Green" },
	{ Key = "OpenGates", Label = Theme.Icons.Islands .. " Open all gates", Tone = "Blue" },
	{ Key = "ResetData", Label = "🗑 Reset my data", Tone = "Red", Confirm = "Wipe your Studio test profile and start fresh? (Studio saves use a separate DataStore, live data is never touched.)" },
}

local function run(a: Action)
	local res = Remote.CallOnce("DevAction", a.Key)
	if res then
		Sounds.Play("Reward")
		Toasts.Show("DEV: " .. tostring(res.message or a.Key), "purple")
	end
end

function DevPanel.Init()
	if not RunService:IsStudio() then
		return
	end
	local win = Windows.Create("Dev", { Title = "DEV (Studio only)", Icon = "🛠", Color = Theme.Rarity.Mythic, Size = Vector2.new(640, 420) })
	local grid = Kit.box({ Size = UDim2.fromScale(1, 1), Parent = win.Body }, { Kit.grid(Vector2.new(296, 92), 12) })
	for i, a in ACTIONS do
		Kit.button(a.Label, a.Tone, { LayoutOrder = i, TextSize = 22, Parent = grid }, function()
			local text = a.Confirm
			if text then
				Windows.Confirm("Are you sure?", text, "Reset", "Red", function()
					run(a)
				end)
			else
				run(a)
			end
		end)
	end
	local btn = Kit.button("DEV", "Pink", {
		Name = "DevButton",
		Size = UDim2.fromOffset(80, 44),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -150),
		TextSize = 20,
		Parent = Windows.Gui("Hud"),
	}, function()
		Windows.Toggle("Dev")
	end)
	Kit.autoScale(btn, 1)
end

return DevPanel
