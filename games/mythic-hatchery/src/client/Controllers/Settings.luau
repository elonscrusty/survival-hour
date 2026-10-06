--!strict
-- Settings: Music, Sound effects, Hide other players' pets, Auto Farm (only
-- with the AutoFarm pass). Saved on the server via SetSetting.

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Shop = require("./Shop")

local Settings = {}

type Row = { Key: string, Label: string, Blurb: string, Default: boolean, Pass: string? }

local ROWS: { Row } = {
	{ Key = "Music", Label = "🎵 Music", Blurb = "Background music", Default = true },
	{ Key = "Sfx", Label = "🔊 Sound effects", Blurb = "Clicks, coins and hatching sounds", Default = true },
	{ Key = "HideOthersPets", Label = "🙈 Hide other pets", Blurb = "Only show your own pets (smoother on phones)", Default = false },
	{ Key = "AutoFarm", Label = "🤖 Auto Farm", Blurb = "Pets attack the nearest coins on their own", Default = false, Pass = "AutoFarm" },
}

local win: Windows.Window
local toggles: { [string]: TextButton } = {}

local function render()
	for _, row in ROWS do
		local b = toggles[row.Key]
		if b then
			if row.Pass and not State.HasPass(row.Pass) then
				Kit.setButton(b, { Text = Theme.Icons.Lock .. " Get pass", Tone = "Purple" })
			else
				local on = State.Setting(row.Key, row.Default) == true
				Kit.setButton(b, { Text = if on then "ON" else "OFF", Tone = if on then "Green" else "White" })
			end
		end
	end
end

local function toggle(row: Row)
	if row.Pass and not State.HasPass(row.Pass) then
		Shop.Upsell(row.Pass)
		return
	end
	local old = State.Setting(row.Key, row.Default) == true
	local new = not old
	State.SetLocalSetting(row.Key, new)
	render()
	local res = Remote.CallOnce("SetSetting", row.Key, new)
	if not res then
		State.SetLocalSetting(row.Key, old)
		render()
	end
end

function Settings.Init()
	win = Windows.Create("Settings", {
		Title = "Settings",
		Icon = Theme.Icons.Settings,
		Color = Theme.Tones.Grey.Rim,
		Size = Vector2.new(680, 500),
	})
	local list = Kit.scroll({ Size = UDim2.fromScale(1, 1), Parent = win.Body }, {
		Kit.list(Enum.FillDirection.Vertical, 10),
		Kit.pad(4, 8, 4, 4),
	})
	for i, row in ROWS do
		local f = Kit.panel({ Size = UDim2.new(1, -10, 0, 90), LayoutOrder = i, Parent = list })
		Kit.fitLabel(row.Label, 26, { Size = UDim2.new(1, -200, 0, 36), Position = UDim2.fromOffset(16, 8), Align = "Left", Parent = f })
		Kit.fitLabel(row.Blurb, 16, {
			Size = UDim2.new(1, -200, 0, 34),
			Position = UDim2.fromOffset(16, 46),
			Align = "Left",
			Font = Theme.FontBody,
			Color = Theme.Colors.TextDim,
			Parent = f,
		})
		toggles[row.Key] = Kit.button("", "White", {
			Size = UDim2.fromOffset(160, 64),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Parent = f,
		}, function()
			toggle(row)
		end)
	end
	win.Opened:Connect(render)
	State.Changed:Connect(function()
		if win.IsOpen then
			render()
		end
	end)
end

return Settings
