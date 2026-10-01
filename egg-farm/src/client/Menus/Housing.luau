--!strict
-- Farm > Housing: the 4 house slots. Each row shows the tier name, chickens (occupants /
-- capacity), eggs stored / storage, a preview of the next tier, and one PurchaseButton that
-- buys the slot (buyHouse) or upgrades it (upgradeHouse, expect = tier). Locked / MAX states come
-- from Logic/Prices through PurchaseState.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Housing = require(Shared:WaitForChild("Data"):WaitForChild("Housing"))
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

	for slot = 1, Housing.Slots do
		local row = Card.Row({ icon = "house", title = "House " .. slot, minHeight = 116, order = slot, parent = scroll })
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
				local h = snap.housing[slot]
				if h.tier == 0 then
					return Common.Quote("buyHouse", snap, slot)
				end
				return Common.Quote("upgradeHouse", snap, slot)
			end,
			send = function(snap)
				local h = snap.housing[slot]
				if h.tier == 0 then
					return host.Store.Request({ type = "buyHouse", slot = slot })
				end
				return host.Store.Request({ type = "upgradeHouse", slot = slot, expect = h.tier })
			end,
			explain = function(code, snap)
				if code == "slot_locked" then
					return "Buy House " .. (slot - 1) .. " first."
				elseif code == "locked" then
					local nextTier = Housing.Tiers[snap.housing[slot].tier + 1]
					if nextTier then
						return "Unlocks on the " .. Eggs.List[nextTier.unlockEgg].name .. "."
					end
				end
				return nil
			end,
		})
		rows[slot] = { row = row, caption = caption, btn = btn }
	end

	local page = { Frame = scroll }

	function page.Refresh(snap: any)
		local total, cap = 0, 0
		for slot, r in rows do
			local h = snap.housing[slot]
			total += h.occupants
			cap += h.capacity
			local tier = Housing.Tiers[h.tier]
			local nextTier = Housing.Tiers[h.tier + 1]
			if h.tier == 0 then
				r.row.Title.Text = "House " .. slot .. ": empty lot"
				r.row.Detail.Text = "Buy this lot to get a " .. Housing.Tiers[1].name .. " for "
					.. Num.Short(math.floor(Housing.Tiers[1].capacity * (snap.mods.capacityMult or 1)))
					.. " more chickens."
				r.caption.Text = "BUY HOUSE"
			else
				r.row.Title.Text = string.format("House %d: %s (Tier %d)", slot, tier.name, h.tier)
				local lines = {
					string.format("Chickens %s / %s", Num.Short(h.occupants), Num.Short(h.capacity)),
					string.format("Eggs stored %s / %s", Num.Short(h.eggs), Num.Short(h.storage)),
				}
				if nextTier then
					local nextCap = math.floor(nextTier.capacity * (snap.mods.capacityMult or 1))
					table.insert(lines, "Next: " .. nextTier.name .. " holds " .. Num.Short(nextCap) .. " chickens")
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
		summary.Text = string.format("Chickens %s / %s  •  More houses = more chickens and more egg storage.", Num.Short(snap.population), Num.Short(snap.capacity))
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
