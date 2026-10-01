--!strict
-- Quests: today's list (snapshot.quests.list) with text and reward from Data/Rewards QuestPool,
-- live progress bars, Claim buttons (claimQuest), claimed state and the reset countdown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rewards = require(Shared:WaitForChild("Data"):WaitForChild("Rewards"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Card = require(UI.Card)
local Num = require(UI.Num)
local ProgressBar = require(UI.ProgressBar)
local PurchaseButton = require(UI.PurchaseButton)
local Common = require(script.Parent.Common)

local M = {
	Name = "Quests",
	Title = "Quests",
	Icon = "quest",
	Color = Theme.Color.Teal,
}

local byId: { [string]: Rewards.Quest } = {}
for _, q in Rewards.QuestPool do
	byId[q.id] = q
end

function M.Build(host: any, panel: any)
	local scroll = Util.Scroll(panel.Body)
	Util.List(scroll, 8)
	Util.Pad(scroll, 4)
	local timer = Common.Heading(scroll, "", 0, Theme.Color.TextDark)
	local rows: { any } = {}
	local shownDay = -1
	local resetsAt = 0

	local function rebuild(snap: any)
		for _, r in rows do
			r.row.Frame:Destroy()
		end
		rows = {}
		for i, q in snap.quests.list do
			local def = byId[q.id]
			local id = q.id
			local row = Card.Row({
				icon = Common.RewardIcon(def and def.reward),
				title = if def then def.text else q.id,
				detail = "Reward: " .. Common.RewardText(def and def.reward),
				minHeight = 130,
				order = i,
				parent = scroll,
			})
			local bar = ProgressBar.new({ size = UDim2.new(1, 0, 0, 26), color = Theme.Color.Teal, order = 3, parent = row.Title.Parent })
			local btn = PurchaseButton.new({
				host = host,
				currency = "free",
				verb = "CLAIM",
				size = UDim2.new(1, 0, 0, 60),
				position = UDim2.fromScale(0, 0.5),
				anchor = Vector2.new(0, 0.5),
				parent = row.Action,
				successSound = "claim",
				quote = function(s)
					for _, cur in s.quests.list do
						if cur.id == id then
							if cur.claimed then
								return nil, "claimed"
							elseif cur.progress < cur.target then
								return nil, "not_ready"
							end
							return 0, "ok"
						end
					end
					return nil, "invalid"
				end,
				send = function()
					return host.Store.Request({ type = "claimQuest", id = id })
				end,
			})
			table.insert(rows, { id = id, row = row, bar = bar, btn = btn })
		end
	end

	local inst = {}
	function inst.Refresh(snap: any)
		if shownDay ~= snap.quests.day or #rows ~= #snap.quests.list then
			shownDay = snap.quests.day
			rebuild(snap)
		end
		resetsAt = snap.serverNow + snap.daily.resetsIn
		for _, r in rows do
			for _, q in snap.quests.list do
				if q.id == r.id then
					local frac = q.progress / math.max(1, q.target)
					local caption = if q.id:match("^play_")
						then string.format("%s / %s", Num.Duration(q.progress), Num.Duration(q.target))
						else string.format("%s / %s", Num.Short(q.progress), Num.Short(q.target))
					r.bar:Set(frac, if q.claimed then "Claimed!" else caption)
					r.bar:SetColor(if q.claimed then Theme.Color.GreenDark elseif frac >= 1 then Theme.Color.Gold else Theme.Color.Teal)
				end
			end
			r.btn:Refresh(snap)
		end
	end
	function inst.Tick(now: number)
		timer.Text = "New quests in " .. Common.Countdown(resetsAt - now)
	end
	return inst
end

return M
