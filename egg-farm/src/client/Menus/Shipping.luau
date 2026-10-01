--!strict
-- Farm > Shipping: vehicle slots. Usable slots = snapshot.vehicleSlots (of Vehicles.MaxSlots);
-- the rest show as locked until the Fleet Permit upgrade. Each row: tier, capacity, trip time,
-- throughput, live status, and a Buy (buyVehicle) / Upgrade (upgradeVehicle, expect = tier) button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Vehicles = require(Shared:WaitForChild("Data"):WaitForChild("Vehicles"))
local Eggs = require(Shared:WaitForChild("Data"):WaitForChild("Eggs"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Card = require(UI.Card)
local Num = require(UI.Num)
local PurchaseButton = require(UI.PurchaseButton)
local Common = require(script.Parent.Common)

local Page = {}

local PHASE = { dock = "Loading at the dock", out = "Driving to market", back = "Coming back" }

function Page.Build(host: any, parent: Instance)
	local scroll = Util.Scroll(parent)
	Util.List(scroll, 8)
	Util.Pad(scroll, 4)
	local summary = Common.Note(scroll, "", 0)
	local rows = {}

	for slot = 1, Vehicles.MaxSlots do
		local row = Card.Row({ icon = "truck", title = "Vehicle " .. slot, minHeight = 116, order = slot, parent = scroll })
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
				local v = snap.vehicles[slot]
				if v.tier == 0 then
					return Common.Quote("buyVehicle", snap, slot)
				end
				return Common.Quote("upgradeVehicle", snap, slot)
			end,
			send = function(snap)
				local v = snap.vehicles[slot]
				if v.tier == 0 then
					return host.Store.Request({ type = "buyVehicle", slot = slot })
				end
				return host.Store.Request({ type = "upgradeVehicle", slot = slot, expect = v.tier })
			end,
			explain = function(code, snap)
				if code == "locked" and slot > snap.vehicleSlots then
					return "Buy the Fleet Permit upgrade to unlock this slot."
				elseif code == "locked" then
					local nextTier = Vehicles.Tiers[snap.vehicles[slot].tier + 1]
					if nextTier then
						return "Unlocks on the " .. Eggs.List[nextTier.unlockEgg].name .. "."
					end
				elseif code == "slot_locked" then
					return "Buy Vehicle " .. (slot - 1) .. " first."
				end
				return nil
			end,
		})
		rows[slot] = { row = row, caption = caption, btn = btn }
	end

	local page = { Frame = scroll }

	function page.Refresh(snap: any)
		for slot, r in rows do
			local v = snap.vehicles[slot]
			local tier = Vehicles.Tiers[v.tier]
			local nextTier = Vehicles.Tiers[v.tier + 1]
			local tripMult = snap.mods.tripMult or 1
			if slot > snap.vehicleSlots then
				r.row.Title.Text = "Vehicle " .. slot .. ": locked"
				r.row.Detail.Text = "Needs a Fleet Permit (Common upgrade) to unlock this parking bay."
				r.caption.Text = "LOCKED"
			elseif v.tier == 0 then
				local t1 = Vehicles.Tiers[1]
				r.row.Title.Text = "Vehicle " .. slot .. ": empty bay"
				r.row.Detail.Text = string.format("Buy a %s: %s eggs per trip.", t1.name, Num.Short(t1.capacity))
				r.caption.Text = "BUY VEHICLE"
			else
				local trip = v.trip
				r.row.Title.Text = string.format("Vehicle %d: %s (Tier %d)", slot, tier.name, v.tier)
				local lines = {
					string.format("%s eggs/trip  •  %.1fs trip  •  %s eggs/s", Num.Short(v.cap), trip, Num.Short(v.cap / math.max(trip, 0.1))),
					string.format("%s (%s aboard)", PHASE[v.phase] or v.phase, Num.Short(v.load)),
				}
				if nextTier then
					table.insert(lines, string.format("Next: %s, %s eggs in %.1fs", nextTier.name, Num.Short(nextTier.capacity), nextTier.trip * tripMult))
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
			"Shipping %s eggs/s  •  Warehouse %s eggs  •  %d of %d bays open",
			Num.Short(snap.rates.ship),
			Num.Short(snap.warehouse),
			snap.vehicleSlots,
			Vehicles.MaxSlots
		)
	end

	function page.Focus(slot: number?)
		local r = slot and rows[slot]
		if r then
			Util.Pop(r.row.Frame, 0.06)
			scroll.CanvasPosition = Vector2.new(0, math.max(0, r.row.Frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 8))
		end
	end

	return page
end

return Page
