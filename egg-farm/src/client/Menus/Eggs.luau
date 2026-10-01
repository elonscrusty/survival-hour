--!strict
-- Eggs: current egg and the next one (Data/Eggs + Data/Themes), Farm Value vs the requirement,
-- and the new-farm actions:
--   REBIRTH  (enabled when snapshot.canRebirth)            -> { type = "rebirth", expect = egg }
--   SKIP     (Gold Eggs = snapshot.skipCost, -1 = no)      -> { type = "skip", expect = egg }
--   PRESTIGE (last egg only, snapshot.canPrestige)         -> { type = "prestige", expect = egg }
-- Each asks for confirmation listing what resets, what is kept (State.RESET/KEPT_FIELDS) and the
-- rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared:WaitForChild("Data"):WaitForChild("Eggs"))
local Themes = require(Shared:WaitForChild("Data"):WaitForChild("Themes"))
local Prices = require(Shared:WaitForChild("Logic"):WaitForChild("Prices"))
local Modifiers = require(Shared:WaitForChild("Logic"):WaitForChild("Modifiers"))
local GameInfo = require(Shared:WaitForChild("GameInfo"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Card = require(UI.Card)
local Icon = require(UI.Icon)
local Num = require(UI.Num)
local ProgressBar = require(UI.ProgressBar)
local PurchaseButton = require(UI.PurchaseButton)
local Common = require(script.Parent.Common)

local M = {
	Name = "Eggs",
	Title = "Eggs",
	Icon = "egg",
	Color = Theme.Color.Gold,
}

local function themeColor(egg: number): Color3
	local e = Eggs.List[egg]
	local t = e and Themes[e.theme]
	if t then
		return Color3.fromRGB(t.accent[1], t.accent[2], t.accent[3])
	end
	return Theme.Color.Gold
end

-- Stars a prestige would grant (mirrors Economy.PrestigeStars; the server decides).
local function prestigeStars(snap: any): number
	return 10 + 5 * (snap.prestiges or 0)
end

local function eggCard(parent: Instance, order: number, caption: string): (Frame, TextLabel, TextLabel, Frame)
	local card = Card.new({ size = UDim2.new(0.5, -6, 0, 170), order = order, parent = parent })
	Util.Text({
		text = caption,
		size = UDim2.new(1, -12, 0, 26),
		position = UDim2.fromOffset(6, 6),
		textSize = Theme.Text.S,
		color = Theme.Color.TextMuted,
		font = Theme.Font.Title,
		parent = card,
	})
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(64, 64)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 32)
	holder.Parent = card
	local name = Util.Text({
		text = "",
		size = UDim2.new(1, -12, 0, 30),
		position = UDim2.fromOffset(6, 98),
		textSize = Theme.Text.M,
		color = Theme.Color.TextDark,
		font = Theme.Font.Title,
		parent = card,
	})
	local sub = Util.Text({
		text = "",
		size = UDim2.new(1, -12, 0, 30),
		position = UDim2.fromOffset(6, 128),
		textSize = Theme.Text.S,
		color = Theme.Color.TextMuted,
		parent = card,
	})
	return card, name, sub, holder
end

function M.Build(host: any, panel: any)
	local scroll = Util.Scroll(panel.Body)
	Util.List(scroll, 10)
	Util.Pad(scroll, 4)

	local pair = Instance.new("Frame")
	pair.BackgroundTransparency = 1
	pair.Size = UDim2.new(1, -8, 0, 170)
	pair.LayoutOrder = 1
	pair.Parent = scroll
	Util.List(pair, 12, true)
	local _, curName, curSub, curIcon = eggCard(pair, 1, "CURRENT EGG")
	local nextCard, nextName, nextSub, nextIcon = eggCard(pair, 2, "NEXT EGG")

	local fvTitle = Common.Heading(scroll, "Farm Value", 2)
	local bar = ProgressBar.new({ size = UDim2.new(1, -8, 0, 36), order = 3, color = Theme.Color.Gold, parent = scroll })
	local hint = Common.Note(scroll, "", 4)

	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.new(1, -8, 0, 0)
	buttons.AutomaticSize = Enum.AutomaticSize.Y
	buttons.LayoutOrder = 5
	buttons.Parent = scroll
	Util.Grid(buttons, Vector2.new(220, 96), 10)

	local function actionTile(order: number, title: string, color: Color3): Frame
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.LayoutOrder = order
		f.Parent = buttons
		Util.Text({
			text = title,
			size = UDim2.new(1, 0, 0, 26),
			textSize = Theme.Text.M,
			color = color,
			font = Theme.Font.Title,
			outline = false,
			parent = f,
		})
		return f
	end

	local function confirmFor(kind: string, snap: any): any
		local prestige = kind == "prestige"
		local rewards = {}
		local nextEgg = Eggs.List[snap.egg + 1]
		if prestige then
			local stars = prestigeStars(snap)
			table.insert(rewards, string.format("+%d %s (+%d%% cash each, forever)", stars, GameInfo.Currency.Star, math.floor(Modifiers.STAR_BONUS * 100)))
		elseif nextEgg then
			local gold = nextEgg.rebirthGold * (if snap.passes.x2gold then 2 else 1)
			table.insert(rewards, "A new farm: " .. nextEgg.name .. " (" .. (Themes[nextEgg.theme] and Themes[nextEgg.theme].name or nextEgg.theme) .. ")")
			table.insert(rewards, string.format("Eggs sell for %s each before upgrades (now %s)", Num.Cash(nextEgg.value), Num.Cash(Eggs.List[snap.egg].value)))
			if gold > 0 then
				table.insert(rewards, string.format("+%d %s", gold, GameInfo.Currency.Gold))
			end
		end
		local title, color, verb, text
		if kind == "rebirth" then
			title, color, verb = "Rebirth?", Theme.Color.Purple, "Rebirth"
			text = "Start a brand-new farm on the next egg."
		elseif kind == "skip" then
			title, color, verb = "Skip ahead?", Theme.Color.Blue, "Skip"
			text = string.format("Pay %s Gold Eggs to start the next farm now, before reaching the Farm Value goal.", Num.Short(snap.skipCost))
		else
			title, color, verb = "Prestige?", Theme.Color.Purple, "Prestige"
			text = "Go back to the first egg and earn Star Eggs that boost your cash forever."
		end
		return {
			title = title,
			icon = if prestige then "prestige" else "rebirth",
			color = color,
			text = text,
			sections = {
				{ title = "You get", items = rewards, color = Theme.Color.GoldDark },
				{ title = "Resets", items = Common.ResetLines(prestige), color = Theme.Color.RedDark },
				{ title = "You keep", items = Common.KeptLines(prestige), color = Theme.Color.GreenDark },
			},
			confirmText = verb,
			confirmColor = color,
		}
	end

	local rebirthTile = actionTile(1, "REBIRTH", Theme.Color.PurpleDark)
	local rebirth = PurchaseButton.new({
		host = host,
		currency = "free",
		verb = "REBIRTH",
		size = UDim2.new(1, 0, 0, 62),
		position = UDim2.fromOffset(0, 30),
		parent = rebirthTile,
		successSound = "rebirth",
		quote = function(snap)
			if snap.egg >= Eggs.Count then
				return nil, "last_egg"
			elseif not snap.canRebirth then
				return nil, "not_requirement"
			end
			return 0, "ok"
		end,
		send = function(snap)
			return host.Store.Request({ type = "rebirth", expect = snap.egg })
		end,
		confirm = function(snap)
			return confirmFor("rebirth", snap)
		end,
		onResult = function(res)
			if res.ok then
				host:Close()
			end
		end,
	})

	local skipTile = actionTile(2, "SKIP", Theme.Color.BlueDark)
	local skip = PurchaseButton.new({
		host = host,
		currency = "gold",
		verb = "SKIP",
		size = UDim2.new(1, 0, 0, 62),
		position = UDim2.fromOffset(0, 30),
		parent = skipTile,
		successSound = "rebirth",
		quote = function(snap)
			if snap.egg >= Eggs.Count then
				return nil, "last_egg"
			end
			if snap.skipCost < 0 then
				local _, code = Prices.Skip(snap, snap.farmValue)
				return nil, code
			end
			return snap.skipCost, "ok"
		end,
		send = function(snap)
			return host.Store.Request({ type = "skip", expect = snap.egg })
		end,
		confirm = function(snap)
			return confirmFor("skip", snap)
		end,
		onResult = function(res)
			if res.ok then
				host:Close()
			end
		end,
	})

	local prestigeTile = actionTile(3, "PRESTIGE", Theme.Color.PurpleDark)
	local prestige = PurchaseButton.new({
		host = host,
		currency = "free",
		verb = "PRESTIGE",
		size = UDim2.new(1, 0, 0, 62),
		position = UDim2.fromOffset(0, 30),
		parent = prestigeTile,
		successSound = "rebirth",
		quote = function(snap)
			if snap.egg < Eggs.Count then
				return nil, "not_last_egg"
			elseif not snap.canPrestige then
				return nil, "not_requirement"
			end
			return 0, "ok"
		end,
		send = function(snap)
			return host.Store.Request({ type = "prestige", expect = snap.egg })
		end,
		confirm = function(snap)
			return confirmFor("prestige", snap)
		end,
		onResult = function(res)
			if res.ok then
				host:Close()
			end
		end,
	})

	local stats = Common.Note(scroll, "", 6)

	local shownEgg = -1
	local inst = {}
	function inst.Refresh(snap: any)
		local egg = Eggs.List[snap.egg] or Eggs.List[1]
		local nxt = Eggs.List[snap.egg + 1]
		if shownEgg ~= snap.egg then
			shownEgg = snap.egg
			Util.Clear(curIcon)
			Icon.new("egg", 64, curIcon)
			local ci = curIcon:FindFirstChildWhichIsA("Frame")
			if ci then
				local shape = ci:FindFirstChildWhichIsA("Frame")
				if shape then
					shape.BackgroundColor3 = themeColor(snap.egg)
				end
			end
			Util.Clear(nextIcon)
			Icon.new(if nxt then "egg" else "prestige", 64, nextIcon)
			if nxt then
				local ni = nextIcon:FindFirstChildWhichIsA("Frame")
				local shape = ni and ni:FindFirstChildWhichIsA("Frame")
				if shape then
					shape.BackgroundColor3 = themeColor(snap.egg + 1)
				end
			end
		end
		curName.Text = egg.name
		curSub.Text = (Themes[egg.theme] and Themes[egg.theme].name or "") .. "  •  " .. Num.Cash(snap.eggValue) .. "/egg"
		if nxt then
			nextName.Text = nxt.name
			nextSub.Text = (Themes[nxt.theme] and Themes[nxt.theme].name or "")
		else
			nextName.Text = "Prestige"
			nextSub.Text = "Earn Star Eggs and start over"
		end
		nextCard.Visible = true
		local req = snap.nextRequirement
		fvTitle.Text = string.format("Farm Value: %s / %s", Num.Cash(snap.farmValue), Num.Cash(req))
		bar:Set(snap.farmValue / math.max(req, 1), string.format("%d%%", math.floor(math.min(1, snap.farmValue / math.max(req, 1)) * 100)))
		if snap.canRebirth then
			hint.Text = "Goal reached! Rebirth to unlock the " .. (if nxt then nxt.name else "next egg") .. "."
		elseif snap.canPrestige then
			hint.Text = "Goal reached! Prestige to earn Star Eggs."
		elseif snap.skipCost >= 0 and snap.egg < Eggs.Count then
			hint.Text = "Farm Value = your Cash + everything you've spent on this farm. Or SKIP for Gold Eggs."
		else
			hint.Text = "Farm Value = your Cash + everything you've spent on this farm. SKIP opens at 25% of the goal."
		end
		rebirthTile.Visible = snap.egg < Eggs.Count
		skipTile.Visible = snap.egg < Eggs.Count
		prestigeTile.Visible = snap.egg >= Eggs.Count
		rebirth:Refresh(snap)
		skip:Refresh(snap)
		prestige:Refresh(snap)
		stats.Text = string.format(
			"Rebirths: %d  •  Prestiges: %d  •  %s: %d",
			snap.rebirths,
			snap.prestiges,
			GameInfo.Currency.Star,
			snap.stars
		)
	end
	return inst
end

return M
