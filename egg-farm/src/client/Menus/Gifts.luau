--!strict
-- Playtime gifts: each unlocks after N minutes played today (Data/Rewards Gifts). Timers count
-- locally between snapshots; claimed keys are the strings "1".."6". Claim (claimGift index) or
-- Claim All (claimAllGifts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rewards = require(Shared:WaitForChild("Data"):WaitForChild("Rewards"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Card = require(UI.Card)
local PurchaseButton = require(UI.PurchaseButton)
local Common = require(script.Parent.Common)

local M = {
	Name = "Gifts",
	Title = "Gifts",
	Icon = "gift",
	Color = Theme.Color.Red,
}

function M.Build(host: any, panel: any)
	local scroll = Util.Scroll(panel.Body)
	Util.List(scroll, 8)
	Util.Pad(scroll, 4)
	Common.Note(scroll, "Play to unlock free gifts! They reset every day.", 0)

	local function ready(snap: any, i: number): (number?, string?)
		local g = Rewards.Gifts[i]
		if snap.gifts.claimed[tostring(i)] then
			return nil, "claimed"
		end
		if Common.Playtime(snap, host.Store.Now()) < g.minutes * 60 then
			return nil, "not_ready"
		end
		return 0, "ok"
	end

	local all = PurchaseButton.new({
		host = host,
		currency = "free",
		verb = "CLAIM ALL",
		size = UDim2.new(1, -8, 0, 64),
		order = 1,
		parent = scroll,
		successSound = "claim",
		quote = function(snap)
			for i in Rewards.Gifts do
				local p = ready(snap, i)
				if p then
					return 0, "ok"
				end
			end
			return nil, "not_ready"
		end,
		send = function()
			return host.Store.Request({ type = "claimAllGifts" })
		end,
	})

	local rows = {}
	for i, g in Rewards.Gifts do
		local row = Card.Row({
			icon = "gift",
			title = string.format("Gift %d: %d min", i, g.minutes),
			detail = Common.RewardText(g.reward),
			order = 1 + i,
			parent = scroll,
		})
		local btn = PurchaseButton.new({
			host = host,
			currency = "free",
			verb = "CLAIM",
			size = UDim2.new(1, 0, 0, 60),
			position = UDim2.fromScale(0, 0.5),
			anchor = Vector2.new(0, 0.5),
			parent = row.Action,
			successSound = "claim",
			quote = function(snap)
				return ready(snap, i)
			end,
			send = function()
				return host.Store.Request({ type = "claimGift", index = i })
			end,
		})
		rows[i] = { row = row, btn = btn }
	end

	local inst = {}
	local function update(snap: any, now: number)
		local play = Common.Playtime(snap, now)
		for i, r in rows do
			local g = Rewards.Gifts[i]
			local left = g.minutes * 60 - play
			if snap.gifts.claimed[tostring(i)] then
				r.row.Detail.Text = Common.RewardText(g.reward) .. "\nClaimed"
			elseif left > 0 then
				r.row.Detail.Text = Common.RewardText(g.reward) .. "\nReady in " .. Common.Countdown(left)
			else
				r.row.Detail.Text = Common.RewardText(g.reward) .. "\nReady!"
			end
			r.btn:Refresh(snap)
		end
		all:Refresh(snap)
	end
	function inst.Refresh(snap: any)
		update(snap, host.Store.Now())
	end
	function inst.Tick(now: number)
		local snap = host.Store.Get()
		if snap then
			update(snap, now)
		end
	end
	return inst
end

return M
