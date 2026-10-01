--!strict
-- Upgrades: COMMON (cash, reset on rebirth) and EPIC (Gold Eggs, kept forever) from Data/Upgrades.
-- Each row shows level / max, the effect text and a PurchaseButton (buyCommon / buyEpic with
-- expect = the level shown).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared:WaitForChild("Data"):WaitForChild("Upgrades"))
local Eggs = require(Shared:WaitForChild("Data"):WaitForChild("Eggs"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Card = require(UI.Card)
local PurchaseButton = require(UI.PurchaseButton)
local Common = require(script.Parent.Common)

local M = {
	Name = "Upgrades",
	Title = "Upgrades",
	Icon = "upgrades",
	Color = Theme.Color.Green,
	Tabs = {
		{ id = "COMMON", label = "COMMON", color = Theme.Color.Green },
		{ id = "EPIC", label = "EPIC", color = Theme.Color.Purple },
	},
}

function M.Build(host: any, panel: any)
	local pages: { [string]: ScrollingFrame } = {}
	local rows: { { refresh: (any) -> () } } = {}

	local function page(id: string, list: { Upgrades.Upgrade }, epic: boolean)
		local scroll = Util.Scroll(panel.Body)
		Util.List(scroll, 8)
		Util.Pad(scroll, 4)
		Common.Note(
			scroll,
			if epic
				then "Epic upgrades cost Gold Eggs and are kept forever."
				else "Common upgrades cost Cash and reset when you start a new farm.",
			0
		)
		for i, u in list do
			local row = Card.Row({ icon = u.icon, title = u.name, detail = u.desc, order = i, parent = scroll })
			local btn = PurchaseButton.new({
				host = host,
				currency = if epic then "gold" else "cash",
				size = UDim2.new(1, 0, 0, 60),
				position = UDim2.fromScale(0, 0.5),
				anchor = Vector2.new(0, 0.5),
				parent = row.Action,
				quote = function(snap)
					return Common.Quote("upgrade", snap, u.id)
				end,
				send = function(snap)
					local levels = if epic then snap.epic else snap.common
					return host.Store.Request({
						type = if epic then "buyEpic" else "buyCommon",
						id = u.id,
						expect = levels[u.id] or 0,
					})
				end,
			})
			table.insert(rows, {
				refresh = function(snap)
					local levels = if epic then snap.epic else snap.common
					local lvl = levels[u.id] or 0
					row.Title.Text = string.format("%s  Lv %d/%d", u.name, lvl, u.max)
					if snap.egg < u.unlockEgg then
						row.Detail.Text = u.desc .. "\nUnlocks on the " .. Eggs.List[u.unlockEgg].name .. "."
					else
						row.Detail.Text = u.desc
					end
					btn:Refresh(snap)
				end,
			})
		end
		pages[id] = scroll
	end
	page("COMMON", Upgrades.Common, false)
	page("EPIC", Upgrades.Epic, true)

	local inst = {}
	local function show(tab: string?)
		for id, p in pages do
			p.Visible = id == (tab or "COMMON")
		end
	end
	function inst.OnShow(tab: string?)
		show(tab)
	end
	function inst.OnTab(tab: string?)
		show(tab)
	end
	function inst.Refresh(snap: any)
		for _, r in rows do
			r.refresh(snap)
		end
	end
	return inst
end

return M
