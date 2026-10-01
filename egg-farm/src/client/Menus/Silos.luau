--!strict
-- Farm > Silos: silos earn while you're away. Shows built / max, permanent silos from the pass,
-- offline minutes covered, and a Build button (buildSilo, expect = silos).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Silos = require(Shared:WaitForChild("Data"):WaitForChild("Silos"))

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
	Common.Note(scroll, "Silos let you earn while you're away. Each silo covers some offline time; claim the cash when you come back.", 0)

	local row = Card.Row({ icon = "silo", title = "Silos", minHeight = 130, order = 1, parent = scroll })
	Util.Text({
		text = "BUILD SILO",
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
			return Common.Quote("silo", snap, nil)
		end,
		send = function(snap)
			return host.Store.Request({ type = "buildSilo", expect = snap.silos })
		end,
	})

	local perma = Card.Row({ icon = "crown", title = "Permanent Silos", minHeight = 100, order = 2, parent = scroll })
	local shopBtn = PurchaseButton.new({
		host = host,
		currency = "free",
		verb = "SHOP",
		size = UDim2.new(1, 0, 0, 60),
		position = UDim2.fromScale(0, 0.5),
		anchor = Vector2.new(0, 0.5),
		parent = perma.Action,
		successSound = "click",
		quote = function(snap)
			return 0, nil, snap.permanentSilos > 0
		end,
		send = function()
			host:Open("Shop", "Passes", { returnTo = true })
			return { ok = true, code = "ok" }
		end,
	})

	local page = { Frame = scroll }

	function page.Refresh(snap: any)
		local total = snap.silos + snap.permanentSilos
		local minutes = total * (snap.mods.siloMinutes or Silos.MinutesPerSilo)
		row.Title.Text = string.format("Silos: %d / %d built", snap.silos, Silos.Max)
		row.Detail.Text = string.format(
			"Covers %s of offline time (%d min per silo)\nEarns %d%% of your steady cash rate while away\nBuilt silos reset when you start a new farm",
			Num.Duration(minutes * 60),
			snap.mods.siloMinutes or Silos.MinutesPerSilo,
			math.floor(Silos.OfflineRate * 100)
		)
		btn:Refresh(snap)
		if snap.permanentSilos > 0 then
			perma.Detail.Text = string.format("You own %d permanent silos. They never reset.", snap.permanentSilos)
		else
			perma.Detail.Text = "The 10 Permanent Silos pass adds silos that survive every rebirth."
		end
		shopBtn:Refresh(snap)
	end

	return page
end

return Page
