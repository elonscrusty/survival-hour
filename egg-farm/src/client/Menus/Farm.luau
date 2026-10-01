--!strict
-- Farm panel: Housing / Shipping / Workers / Silos tabs (one page module each). Opened from the
-- HUD "Farm" button or a world board (ProximityPrompt attribute Menu + optional Slot).
-- Tabs not yet revealed by the tutorial are hidden (Host._applyReveals).

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)

local Housing = require(script.Parent.Housing)
local Shipping = require(script.Parent.Shipping)
local Workers = require(script.Parent.Workers)
local Silos = require(script.Parent.Silos)

local M = {
	Name = "Farm",
	Title = "Farm",
	Icon = "farm",
	Color = Theme.Color.Orange,
	Tabs = {
		{ id = "Housing", label = "Housing", color = Theme.Color.Red },
		{ id = "Shipping", label = "Shipping", color = Theme.Color.Blue },
		{ id = "Workers", label = "Workers", color = Theme.Color.Teal },
		{ id = "Silos", label = "Silos", color = Theme.Color.Purple },
	},
}

function M.Build(host: any, panel: any)
	local pages: { [string]: any } = {
		Housing = Housing.Build(host, panel.Body),
		Shipping = Shipping.Build(host, panel.Body),
		Workers = Workers.Build(host, panel.Body),
		Silos = Silos.Build(host, panel.Body),
	}
	local current = "Housing"
	local inst = {}

	local function show(tab: string?)
		current = if tab and pages[tab] then tab else "Housing"
		for id, p in pages do
			p.Frame.Visible = id == current
		end
		panel:SetTitle(current)
		local snap = host.Store.Get()
		if snap then
			pages[current].Refresh(snap)
		end
	end

	function inst.OnShow(tab: string?, opts: any?)
		show(tab)
		if opts and opts.slot and pages[current].Focus then
			local slot = opts.slot
			task.defer(function()
				pages[current].Focus(slot)
			end)
		end
	end

	function inst.OnTab(tab: string?)
		show(tab)
	end

	function inst.Refresh(snap: any)
		pages[current].Refresh(snap)
	end

	return inst
end

return M
