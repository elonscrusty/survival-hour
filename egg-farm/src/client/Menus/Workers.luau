--!strict
-- Farm > Workers: worker slots (snapshot.workerSlots usable of Workers.MaxSlots). Each row shows
-- the worker tier, carry and cycle time, and a Hire (hireWorker) / Upgrade (upgradeWorker,
-- expect = tier) button. Locked slots explain the Bunkhouse upgrade / +2 Worker Slots pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Workers = require(Shared:WaitForChild("Data"):WaitForChild("Workers"))
local Eggs = require(Shared:WaitForChild("Data"):WaitForChild("Eggs"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Card = require(UI.Card)
local Num = require(UI.Num)
local PurchaseButton = require(UI.PurchaseButton)
local Common = require(script.Parent.Common)

local Page = {}

function Page.Build(host: any, parent: Instance)
	local scroll = Util.Scroll(parent)
	Util.List(scroll, 8)
	Util.Pad(scroll, 4)
	local summary = Common.Note(scroll, "", 0)
	local rows = {}

	for slot = 1, Workers.MaxSlots do
		local row = Card.Row({ icon = "worker", title = "Worker " .. slot, minHeight = 116, order = slot, parent = scroll })
		local caption = Util.Text({
			text = "",
			size = UDim2.new(1, 0, 0, 24),
			textSize = Theme.Text.S,
			color = Theme.Color.TextDark,
			font = Theme.Font.Title,
			parent = row.Action,
		})
		local btn = PurchaseButton.new({
			host = host,
			size = UDim2.new(1, 0, 0, 60),
			position = UDim2.fromOffset(0, 28),
			parent = row.Action,
			quote = function(snap)
				local w = snap.workers[slot]
				if w.tier == 0 then
					return Common.Quote("hireWorker", snap, slot)
				end
				return Common.Quote("upgradeWorker", snap, slot)
			end,
			send = function(snap)
				local w = snap.workers[slot]
				if w.tier == 0 then
					return host.Store.Request({ type = "hireWorker", slot = slot })
				end
				return host.Store.Request({ type = "upgradeWorker", slot = slot, expect = w.tier })
			end,
			explain = function(code, snap)
				if code == "locked" and slot > snap.workerSlots then
					return "Buy the Bunkhouse upgrade (or the +2 Worker Slots pass) to unlock this slot."
				elseif code == "locked" then
					local nextTier = Workers.Tiers[snap.workers[slot].tier + 1]
					if nextTier then
						return "Unlocks on the " .. Eggs.List[nextTier.unlockEgg].name .. "."
					end
				elseif code == "slot_locked" then
					return "Hire Worker " .. (slot - 1) .. " first."
				end
				return nil
			end,
		})
		rows[slot] = { row = row, caption = caption, btn = btn }
	end

	local page = { Frame = scroll }

	function page.Refresh(snap: any)
		local mult = snap.mods.workerMult or 1
		for slot, r in rows do
			local w = snap.workers[slot]
			local tier = Workers.Tiers[w.tier]
			local nextTier = Workers.Tiers[w.tier + 1]
			if slot > snap.workerSlots then
				r.row.Title.Text = "Worker " .. slot .. ": locked"
				r.row.Detail.Text = "Unlock more worker slots with the Bunkhouse upgrade or the +2 Worker Slots pass."
				r.caption.Text = "LOCKED"
			elseif w.tier == 0 then
				local t1 = Workers.Tiers[1]
				r.row.Title.Text = "Worker " .. slot .. ": not hired"
				r.row.Detail.Text = string.format(
					"Hire a %s to carry %s eggs from your houses to the warehouse every %ds.",
					t1.name,
					Num.Short(math.floor(t1.carry * mult)),
					t1.cycle
				)
				r.caption.Text = "HIRE"
			else
				r.row.Title.Text = string.format("Worker %d: %s (Tier %d)", slot, tier.name, w.tier)
				local carry = math.floor(tier.carry * mult)
				local lines = {
					string.format("Carries %s eggs every %ds  •  %s eggs/s", Num.Short(carry), tier.cycle, Num.Short(carry / tier.cycle)),
					string.format("Holding %s eggs, working House %d", Num.Short(w.load), w.house),
				}
				if nextTier then
					table.insert(lines, string.format("Next: %s carries %s", nextTier.name, Num.Short(math.floor(nextTier.carry * mult))))
					if snap.egg < nextTier.unlockEgg then
						table.insert(lines, "Unlocks on the " .. Eggs.List[nextTier.unlockEgg].name)
					end
				else
					table.insert(lines, "Top tier reached!")
				end
				r.row.Detail.Text = table.concat(lines, "\n")
				r.caption.Text = if nextTier then "UPGRADE" else "MAX"
			end
			r.btn:Refresh(snap)
		end
		summary.Text = string.format(
			"Workers move %s eggs/s for you  •  %d of %d slots open",
			Num.Short(snap.rates.workers),
			snap.workerSlots,
			Workers.MaxSlots
		)
	end

	function page.Focus(slot: number?)
		local r = slot and rows[slot]
		if r then
			Util.Pop(r.row.Frame, 0.06)
		end
	end

	return page
end

return Page
