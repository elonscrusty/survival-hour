-- DAILY menu: login streak reward, today's quests, promo codes and the sound switch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Daily = require(Shared.Logic.Daily)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.Hud)
local Notify = require(script.Parent.Notify)

local DailyMenu = {}

local panel: Frame
local body: Frame

local function render()
	body:ClearAllChildren()
	local d = State.Data
	if not d then
		return
	end
	local s = d.Daily
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	-- Login streak
	local login = UI.Frame({ Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = 1 }, body)
	UI.Corner(login, 10)
	UI.Text({
		Text = string.format("Day %d streak: %d coins", math.max(1, s.Streak), Daily.LoginReward(math.max(1, s.Streak))),
		Size = UDim2.new(0.62, 0, 0.6, 0),
		Position = UDim2.new(0, 12, 0.2, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, login)
	if s.LoginClaimed then
		UI.Text({ Text = "Claimed", Size = UDim2.new(0.3, 0, 0.6, 0), Position = UDim2.new(0.68, 0, 0.2, 0), TextColor3 = UI.Colors.Muted }, login)
	else
		UI.Button({ Text = "Claim", Size = UDim2.new(0.3, 0, 0.7, 0), Position = UDim2.new(0.68, 0, 0.15, 0), BackgroundColor3 = UI.Colors.Green }, login, function()
			Net.Event("ClaimDaily"):FireServer("Login")
		end)
	end

	-- Quests
	for i, id in s.Quests do
		local q = Daily.ById[id]
		if q then
			local prog = Daily.Progress(s, d.Stats, id)
			local row = UI.Frame({ Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = 1 + i }, body)
			UI.Corner(row, 10)
			UI.Text({ Text = q.Text, Size = UDim2.new(0.62, 0, 0, 26), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left }, row)
			local bar = UI.Frame({ Size = UDim2.new(0.5, 0, 0, 12), Position = UDim2.fromOffset(12, 40), BackgroundColor3 = Color3.fromRGB(20, 20, 30) }, row)
			UI.Corner(bar, 6)
			local fill = UI.Frame({ Size = UDim2.fromScale(prog / q.Need, 1), BackgroundColor3 = UI.Colors.Gold }, bar)
			UI.Corner(fill, 6)
			UI.Text({ Text = prog .. "/" .. q.Need, Size = UDim2.new(0.1, 0, 0, 16), Position = UDim2.new(0.52, 10, 0, 38), TextColor3 = UI.Colors.Muted, Font = UI.Body }, row)
			local btnSize, btnPos = UDim2.new(0.3, 0, 0.7, 0), UDim2.new(0.68, 0, 0.15, 0)
			if s.Claimed[id] then
				UI.Text({ Text = "Done!", Size = btnSize, Position = btnPos, TextColor3 = UI.Colors.Green }, row)
			elseif prog >= q.Need then
				UI.Button({ Text = "+" .. q.Coins, Size = btnSize, Position = btnPos, BackgroundColor3 = UI.Colors.Gold }, row, function()
					Net.Event("ClaimDaily"):FireServer(id)
				end)
			else
				UI.Text({ Text = "$ " .. q.Coins, Size = btnSize, Position = btnPos, TextColor3 = UI.Colors.Gold }, row)
			end
		end
	end

	-- Codes
	local codes = UI.Frame({ Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = 10 }, body)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.64, 0, 1, 0)
	box.PlaceholderText = "Enter a code..."
	box.Text = ""
	box.Font = UI.Body
	box.TextScaled = true
	box.TextColor3 = Color3.new(1, 1, 1)
	box.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	box.ClearTextOnFocus = false
	UI.Corner(box, 10)
	UI.Pad(box, 8)
	box.Parent = codes
	UI.Button({ Text = "Redeem", Size = UDim2.new(0.33, 0, 1, 0), Position = UDim2.new(0.67, 0, 0, 0), BackgroundColor3 = UI.Colors.Purple }, codes, function()
		local ok, msg = Net.Function("Redeem"):InvokeServer(box.Text)
		Notify.Show(msg or "", if ok then "Coins" else "Error")
		if ok then
			box.Text = ""
		end
	end)

	-- Sound switch
	UI.Button({
		Text = if d.Muted then "Sound: OFF" else "Sound: ON",
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 11,
		BackgroundColor3 = if d.Muted then UI.Colors.PanelLight else UI.Colors.Blue,
	}, body, function()
		Net.Event("SetMuted"):FireServer(not d.Muted)
	end)
end

function DailyMenu.Open()
	panel.Visible = true
	render()
end

function DailyMenu.Start()
	panel, body = UI.Modal("Daily", UDim2.fromScale(0.7, 0.85))
	Hud.SetOpener("Daily", DailyMenu.Open)
	State.OnChange(function(d)
		Hud.SetDot("Daily", Daily.HasClaimable(d.Daily, d.Stats))
		if panel.Visible then
			render()
		end
	end)
end

return DailyMenu
