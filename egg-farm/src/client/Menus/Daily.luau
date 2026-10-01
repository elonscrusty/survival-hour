--!strict
-- Daily rewards: 7-day ladder (Data/Rewards Daily), current streak, Claim (claimDaily) and the
-- countdown to the next day. snapshot.daily.nextDay is the ladder day the next claim pays.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rewards = require(Shared:WaitForChild("Data"):WaitForChild("Rewards"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Card = require(UI.Card)
local Icon = require(UI.Icon)
local PurchaseButton = require(UI.PurchaseButton)
local Common = require(script.Parent.Common)

local M = {
	Name = "Daily",
	Title = "Daily Rewards",
	Icon = "daily",
	Color = Theme.Color.Red,
}

function M.Build(host: any, panel: any)
	local scroll = Util.Scroll(panel.Body)
	Util.List(scroll, 10)
	Util.Pad(scroll, 4)
	local streak = Common.Heading(scroll, "", 1)

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -8, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = 2
	grid.Parent = scroll
	Util.Grid(grid, Vector2.new(132, 150), 8)

	local tiles = {}
	for day, reward in Rewards.Daily do
		local card = Card.new({ order = day, parent = grid })
		Util.Text({
			text = "Day " .. day,
			size = UDim2.new(1, -8, 0, 28),
			position = UDim2.fromOffset(4, 4),
			textSize = Theme.Text.M,
			color = Theme.Color.TextDark,
			font = Theme.Font.Title,
			parent = card,
		})
		local ic = Icon.new(Common.RewardIcon(reward), 48)
		ic.AnchorPoint = Vector2.new(0.5, 0)
		ic.Position = UDim2.new(0.5, 0, 0, 34)
		ic.Parent = card
		local lbl = Util.Text({
			text = Common.RewardText(reward),
			size = UDim2.new(1, -8, 0, 60),
			position = UDim2.fromOffset(4, 86),
			textSize = Theme.Text.S,
			color = Theme.Color.TextMuted,
			parent = card,
		})
		lbl.TextWrapped = true
		local check = Icon.new("check", 40)
		check.AnchorPoint = Vector2.new(1, 0)
		check.Position = UDim2.new(1, -4, 0, 4)
		check.Visible = false
		check.Parent = card
		tiles[day] = { card = card, check = check }
	end

	local timer = Common.Note(scroll, "", 3)
	local btn = PurchaseButton.new({
		host = host,
		currency = "free",
		verb = "CLAIM",
		size = UDim2.new(1, -8, 0, 64),
		order = 4,
		parent = scroll,
		successSound = "claim",
		quote = function(snap)
			if not snap.daily.canClaim then
				return nil, "claimed"
			end
			return 0, "ok"
		end,
		send = function()
			return host.Store.Request({ type = "claimDaily" })
		end,
	})

	local nextAt = 0
	local inst = {}
	function inst.Refresh(snap: any)
		local d = snap.daily
		local nextDay = d.nextDay
		streak.Text = string.format("Streak: %d day%s", d.streak, if d.streak == 1 then "" else "s")
		for day, t in tiles do
			local isNext = day == nextDay
			-- days before the next claim are done; after a full week day 7 repeats (claimed today)
			local done = day < nextDay or (not d.canClaim and d.streak >= #Rewards.Daily and day == #Rewards.Daily)
			t.check.Visible = done
			t.card.BackgroundColor3 = if isNext and d.canClaim
				then Theme.Color.Gold
				elseif done then Theme.Color.CardAlt
				else Theme.Color.Card
		end
		nextAt = snap.serverNow + d.resetsIn
		btn:Refresh(snap)
	end
	function inst.Tick(now: number)
		local snap = host.Store.Get()
		if snap and snap.daily.canClaim then
			timer.Text = "Your reward is ready!"
		else
			timer.Text = "Next reward in " .. Common.Countdown(nextAt - now)
		end
	end
	return inst
end

return M
