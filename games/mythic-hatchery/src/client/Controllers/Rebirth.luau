--!strict
-- Rebirth menu: cost, what resets, what you keep, and the permanent bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local Format = require("../Core/Format")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Toasts = require("../UI/Toasts")

local Rebirth = {}

local win: Windows.Window
local info: TextLabel
local setProgress: (number, string?) -> ()
local btn: TextButton

local function render()
	if not win.IsOpen then
		return
	end
	local d = State.Data
	if not d then
		return
	end
	local now = d.Rebirths
	local maxed = now >= Config.MaxRebirths
	local bonusNow = math.floor(now * Config.RebirthCoinBonus * 100 + 0.5)
	local bonusNext = math.floor((now + 1) * Config.RebirthCoinBonus * 100 + 0.5)
	info.Text = string.format(
		"Rebirths: <b>%d</b>  (coin bonus <b>+%d%%</b>)\n\n"
			.. "<font color=\"#2FA84F\"><b>You get:</b></font> +%d%% coins forever (total +%d%%) and %s %d gems\n"
			.. "<font color=\"#F05454\"><b>Resets:</b></font> your coins and opened islands\n"
			.. "<font color=\"#5896FF\"><b>You keep:</b></font> pets, gems, passes and your Index",
		now,
		bonusNow,
		math.floor(Config.RebirthCoinBonus * 100 + 0.5),
		bonusNext,
		Theme.Icons.Gems,
		Config.RebirthGems
	)
	setProgress(d.Coins / math.max(1, d.RebirthCost), Theme.Icons.Coins .. " " .. Format.num(d.Coins) .. " / " .. Format.num(d.RebirthCost))
	if maxed then
		Kit.setButton(btn, { Text = "Max rebirths!", Enabled = false })
	else
		Kit.setButton(btn, {
			Text = Theme.Icons.Rebirth .. " Rebirth  " .. Theme.Icons.Coins .. Format.num(d.RebirthCost),
			Enabled = d.Coins >= d.RebirthCost,
			Tone = "Purple",
		})
	end
end

function Rebirth.Init()
	win = Windows.Create("Rebirth", {
		Title = "Rebirth",
		Icon = Theme.Icons.Rebirth,
		Color = Theme.Tones.Purple.Rim,
		Size = Vector2.new(680, 480),
	})
	info = Kit.fitLabel("", 22, {
		Size = UDim2.new(1, -20, 0, 210),
		Position = UDim2.fromOffset(10, 4),
		Font = Theme.FontBody,
		Align = "Left",
		Rich = true,
		Parent = win.Body,
	})
	local bar, set = Kit.bar({ Size = UDim2.new(1, -40, 0, 38), Position = UDim2.fromOffset(20, 226) }, Theme.Colors.Coins)
	bar.Parent = win.Body
	setProgress = set
	btn = Kit.button("Rebirth", "Purple", {
		Size = UDim2.fromOffset(380, 76),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		TextSize = 28,
		Parent = win.Body,
	}, function()
		local d = State.Data
		if not d then
			return
		end
		Windows.Confirm(
			"Rebirth now?",
			"Your coins and opened islands reset. You keep all pets and gems and earn more coins forever.",
			"Rebirth!",
			"Purple",
			function()
				local res = Remote.CallOnce("Rebirth")
				if res then
					Sounds.Play("Rare")
					Toasts.Banner("Rebirth!", "Coins are now boosted forever", Theme.Rarity.Epic, 3)
					Windows.Close()
				end
			end
		)
	end)
	win.Opened:Connect(render)
	State.Changed:Connect(render)
end

return Rebirth
