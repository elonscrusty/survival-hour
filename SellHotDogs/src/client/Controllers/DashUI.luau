--!strict
-- DogDash the Game: pick one of four racing hot dogs, choose a bet, then mash Cheer.
-- The server runs the race; this screen only shows the positions it sends.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local Bus = require(script.Parent.Bus)
local State = require(script.Parent.State)

local C = Kit.C
local new = Kit.new

local DashUI = {}

local gui: ScreenGui
local runners: { Frame } = {}
local pickButtons: { Kit.Button } = {}
local betButtons: { Kit.Button } = {}
local startBtn: Kit.Button
local cheerBtn: Kit.Button
local status: TextLabel
local pick, bet = 1, 1
local racing = false
local COLORS = { C.ketchup, C.mustard, C.green, C.blue }
local NAMES = { "Ketchup", "Mustard", "Relish", "Blue Bun" }

local function paint()
	for i, b in pickButtons do
		b.setColor(if i == pick then COLORS[i] else C.grey, C.shadow)
	end
	for i, b in betButtons do
		b.setColor(if i == bet then C.gold else C.grey, C.goldDark)
	end
	startBtn.frame.Visible = not racing
	cheerBtn.frame.Visible = racing
	for _, b in pickButtons do
		b.setEnabled(not racing)
	end
	for _, b in betButtons do
		b.setEnabled(not racing)
	end
end

function DashUI.init()
	local g, root = Kit.canvas("DogDash", 25)
	gui = g
	gui.Enabled = false
	new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Parent = root })
	local box = Kit.panel({ size = UDim2.fromOffset(600, 470), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), parent = root })
	Kit.label({ Text = "🏁 DogDash", Size = UDim2.new(1, -90, 0, 44), Position = UDim2.fromOffset(16, 10), Parent = box, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 30 })
	Kit.button({ text = "✕", color = C.red, dark = C.redDark, size = UDim2.fromOffset(48, 48), pos = UDim2.new(1, -12, 0, 10), anchor = Vector2.new(1, 0), parent = box, textSize = 26, onClick = function()
		gui.Enabled = false
	end })
	local track = new("Frame", { Size = UDim2.new(1, -32, 0, 200), Position = UDim2.fromOffset(16, 62), BackgroundColor3 = Color3.fromRGB(120, 200, 100), Parent = box }, { Kit.corner(12) })
	new("Frame", { Size = UDim2.new(0, 6, 1, 0), Position = UDim2.new(1, -40, 0, 0), BackgroundColor3 = C.white, Parent = track })
	for i = 1, 4 do
		local lane = new("Frame", { Size = UDim2.new(1, -8, 0, 44), Position = UDim2.fromOffset(4, 4 + (i - 1) * 49), BackgroundColor3 = Color3.fromRGB(235, 222, 196), Parent = track }, { Kit.corner(10) })
		local r = Kit.label({ Text = "🌭", Size = UDim2.fromOffset(44, 44), Position = UDim2.fromScale(0, 0), Parent = lane, MaxText = 36, BackgroundTransparency = 0, BackgroundColor3 = COLORS[i] })
		Kit.corner(22).Parent = r
		runners[i] = r :: any
	end
	local pickRow = new("Frame", { Size = UDim2.new(1, -32, 0, 46), Position = UDim2.fromOffset(16, 270), BackgroundTransparency = 1, Parent = box }, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
	for i = 1, 4 do
		pickButtons[i] = Kit.button({ text = NAMES[i], size = UDim2.fromOffset(136, 44), parent = pickRow, textSize = 18, onClick = function()
			pick = i
			paint()
		end })
	end
	local betRow = new("Frame", { Size = UDim2.new(1, -32, 0, 46), Position = UDim2.fromOffset(16, 320), BackgroundTransparency = 1, Parent = box }, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
	for i, f in Economy.Catalog.dash.betFractions.value do
		betButtons[i] = Kit.button({ text = string.format("Bet %d%%", math.floor(f * 100 + 0.5)), size = UDim2.fromOffset(150, 44), parent = betRow, textSize = 18, onClick = function()
			bet = i
			paint()
		end })
	end
	status = Kit.label({ Text = "Pick a racer and a bet!", Size = UDim2.new(1, -32, 0, 26), Position = UDim2.fromOffset(16, 370), Parent = box, TextColor3 = C.ink, MaxText = 20 })
	startBtn = Kit.button({ text = "Start race", color = C.green, dark = C.greenDark, size = UDim2.fromOffset(220, 56), pos = UDim2.new(0.5, 0, 1, -12), anchor = Vector2.new(0.5, 1), parent = box, textSize = 24, onClick = function()
		startBtn.setPending(true)
		State.send("dashStart", pick, bet)
		task.delay(1, function()
			startBtn.setPending(false)
		end)
	end })
	cheerBtn = Kit.button({ text = "📣 CHEER!", color = C.ketchup, dark = C.redDark, size = UDim2.fromOffset(260, 56), pos = UDim2.new(0.5, 0, 1, -12), anchor = Vector2.new(0.5, 1), parent = box, textSize = 26, onClick = function()
		State.send("dashCheer")
	end })
	paint()

	Bus.Opened:Connect(function(what)
		if what == "dash" then
			gui.Enabled = true
			paint()
		end
	end)
	State.Notify:Connect(function(kind, data)
		if kind == "race" then
			if not racing then
				racing = true
				gui.Enabled = true
				paint()
			end
			for i, p in data.pos do
				runners[i].Position = UDim2.new(p * 0.9, 0, 0, 0)
			end
			status.Text = string.format("Go %s! Cheers: %d", NAMES[data.pick], data.cheers)
		elseif kind == "raceEnd" then
			racing = false
			local won = data.winner == data.pick
			status.Text = if won then string.format("%s won! You got %s", NAMES[data.winner], Format.cash(Bus.big(data.payout))) else string.format("%s won. Better luck next time!", NAMES[data.winner])
			paint()
		end
	end)
end

return DashUI
