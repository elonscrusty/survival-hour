--!strict
-- Hatch menu (opened from an EggStand prompt): egg picture, price, the full
-- odds list (base and luck-boosted), Hatch 1 / Hatch 3 / Auto hatch.
-- The Prism Egg is locked when the server says paid random items are
-- restricted for this player (CanBuyGemEggs = false).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared:WaitForChild("Eggs"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local PetInfo = require("../Core/PetInfo")
local Format = require("../Core/Format")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Viewport = require("../UI/Viewport")
local Toasts = require("../UI/Toasts")
local HatchAnim = require("./HatchAnim")
local Hud = require("./Hud")
local Shop = require("./Shop")

type PetInstance = Types.PetInstance

local Hatch = {}

local player = Players.LocalPlayer
local AUTO_RANGE = 30 -- studs from the stand before auto hatch stops

local win: Windows.Window
local eggHolder: Frame
local eggName: TextLabel
local costPill: Frame
local luckLabel: TextLabel
local oddsList: ScrollingFrame
local lockNote: TextLabel
local btn1: TextButton
local btn3: TextButton
local btnAuto: TextButton

local currentEgg: string? = nil
local standPos: Vector3? = nil
local hatching = false
local auto = false
local autoGen = 0 -- bumped on every start/stop so an old auto loop never touches a new run

-- Fired after each successful hatch (tutorial).
Hatch.OnHatched = nil :: (() -> ())?

local function eggLocked(eggId: string): boolean
	local egg = Eggs.ById[eggId]
	local d = State.Data
	return egg ~= nil and egg.Currency == "Gems" and d ~= nil and d.CanBuyGemEggs == false
end

local function currencyIcon(currency: string): string
	return if currency == "Gems" then Theme.Icons.Gems else Theme.Icons.Coins
end

local function charPos(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function stopAuto()
	auto = false
	autoGen += 1
	Hud.SetAutoHatch(nil)
	if btnAuto then
		Kit.setButton(btnAuto, { Text = "Auto: OFF", Tone = "White" })
	end
end

local oddsSig = ""

local function renderOdds(force: boolean?)
	local eggId = currentEgg
	local d = State.Data
	if not eggId or not d then
		return
	end
	local luck = d.LuckMult or 1
	local rows = PetInfo.Odds(eggId, luck)
	-- skip rebuilding the list when nothing it shows has changed
	local sig = eggId .. "|" .. tostring(luck) .. "|" .. tostring(PetInfo.ScaleArea())
	for _, row in rows do
		sig ..= if d.Index[row.Pet] then "1" else "0"
	end
	if sig == oddsSig and not force then
		return
	end
	oddsSig = sig
	Kit.clear(oddsList)
	for i, row in rows do
		local rarity = PetInfo.Rarity(row.Pet)
		local rc = Theme.RarityColor(rarity)
		local discovered = d.Index[row.Pet] == true
		local r = Kit.panel({
			Size = UDim2.new(1, -10, 0, 70),
			LayoutOrder = i,
			BackgroundColor3 = Theme.Lighten(rc, 0.75),
			StrokeColor = Theme.Darken(rc, 0.2),
			Parent = oddsList,
		})
		Viewport.Pet(row.Pet, "Normal", false, {
			Size = UDim2.fromOffset(62, 62),
			Position = UDim2.fromOffset(6, 4),
			Parent = r,
		})
		Kit.fitLabel(PetInfo.Name(row.Pet) .. (if discovered then "" else "  <font color=\"#F05454\">NEW</font>"), 22, {
			Size = UDim2.new(1, -250, 0, 30),
			Position = UDim2.fromOffset(76, 6),
			Align = "Left",
			Rich = true,
			Parent = r,
		})
		Kit.fitLabel(rarity .. "  " .. Theme.Icons.Boost .. Format.num(PetInfo.BasePower(row.Pet)), 16, {
			Size = UDim2.new(1, -250, 0, 24),
			Position = UDim2.fromOffset(76, 38),
			Align = "Left",
			Color = rc,
			Outline = Theme.Darken(rc, 0.55),
			Parent = r,
		})
		local boosted = math.abs(row.Boosted - row.Base) > 1e-6
		local pct = if boosted
			then "<font color=\"#6E7692\"><s>" .. Format.percent(row.Base) .. "</s></font>  <font color=\"#2FA84F\">" .. Format.percent(row.Boosted) .. "</font>"
			else Format.percent(row.Base)
		Kit.fitLabel(pct, 24, {
			Size = UDim2.fromOffset(170, 50),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Align = "Right",
			Rich = true,
			Parent = r,
		})
	end
	if luck > 1 then
		luckLabel.Text = Theme.Icons.Luck .. " Luck x" .. string.format("%.2g", luck) .. " (Rare+ boosted)"
		luckLabel.TextColor3 = Theme.Colors.Good
	else
		luckLabel.Text = "Odds shown before every hatch"
		luckLabel.TextColor3 = Theme.Colors.TextDim
	end
end

local function renderButtons()
	local eggId = currentEgg
	local d = State.Data
	if not eggId or not d then
		return
	end
	local egg = Eggs.ById[eggId]
	if not egg then
		return
	end
	local icon = currencyIcon(egg.Currency)
	local locked = eggLocked(eggId)
	local balance = if egg.Currency == "Gems" then d.Gems else d.Coins
	lockNote.Visible = locked
	Kit.setButton(btn1, { Text = "Hatch 1  " .. icon .. Format.num(egg.Cost), Enabled = not locked, Tone = if balance >= egg.Cost then "Green" else "Yellow" })
	if State.HasPass("TripleHatch") then
		Kit.setButton(btn3, { Text = "Hatch 3  " .. icon .. Format.num(egg.Cost * 3), Enabled = not locked, Tone = if balance >= egg.Cost * 3 then "Green" else "Yellow" })
	else
		Kit.setButton(btn3, { Text = Theme.Icons.Lock .. " Hatch 3", Enabled = not locked, Tone = "Purple" })
	end
	Kit.setButton(btnAuto, { Text = if auto then "Auto: ON" else "Auto: OFF", Tone = if auto then "Blue" else "White", Enabled = not locked })
	Kit.setPill(costPill, icon .. " " .. Format.num(egg.Cost))
end

local function render()
	local eggId = currentEgg
	if not eggId then
		return
	end
	local egg = Eggs.ById[eggId]
	if not egg then
		return
	end
	win.Title.Text = Theme.Icons.Egg .. "  " .. egg.Name
	eggName.Text = egg.Name
	Kit.clear(eggHolder)
	Viewport.Egg(eggId, { Size = UDim2.fromScale(1, 1), Spin = true, Parent = eggHolder })
	renderOdds(true)
	renderButtons()
end

-- One hatch request + animation. Returns true on success.
local function doHatch(count: number, isAuto: boolean): boolean
	local eggId = currentEgg
	local d = State.Data
	if hatching or not eggId or not d then
		return false
	end
	if eggLocked(eggId) then
		Toasts.Show("This egg isn't available for your account.", "bad")
		return false
	end
	hatching = true
	local before = table.clone(d.Index)
	local wasOpen = win.IsOpen
	local res = Remote.Call("HatchEgg", eggId, count)
	local ok = false
	if res and type(res.pets) == "table" and #res.pets > 0 then
		ok = true
		if wasOpen then
			Windows.Close()
		end
		HatchAnim.Play(eggId, res.pets :: { PetInstance }, before, isAuto)
		local cb = Hatch.OnHatched
		if cb then
			cb()
		end
		if wasOpen and not auto then
			Windows.Show("Hatch")
		end
	end
	hatching = false
	return ok
end

local function startAuto()
	if auto or not currentEgg then
		return
	end
	autoGen += 1
	local gen = autoGen
	auto = true
	renderButtons()
	Windows.Close()
	local eggId = currentEgg
	Hud.SetAutoHatch(Theme.Icons.Egg .. " Auto hatching " .. (if eggId and Eggs.ById[eggId] then Eggs.ById[eggId].Name else ""), stopAuto)
	task.spawn(function()
		local function alive(): boolean
			return auto and autoGen == gen and currentEgg == eggId
		end
		while alive() do
			-- a manual hatch may still be animating; wait instead of giving up
			while hatching and alive() do
				task.wait(0.1)
			end
			if not alive() then
				break
			end
			local pos = charPos()
			if standPos and pos and (pos - standPos).Magnitude > AUTO_RANGE then
				Toasts.Show("Auto hatch stopped: you walked away.", "info")
				break
			end
			local count = if State.HasPass("TripleHatch") then 3 else 1
			if not doHatch(count, true) then
				break
			end
			task.wait(math.max(0.1, Config.HatchCooldown - 0.6))
		end
		if autoGen == gen then
			stopAuto()
		end
	end)
end

function Hatch.Open(eggId: string, stand: Instance?)
	if not Eggs.ById[eggId] then
		return
	end
	if currentEgg ~= eggId and auto then
		stopAuto()
	end
	currentEgg = eggId
	standPos = nil
	if stand then
		if stand:IsA("Model") then
			standPos = stand:GetPivot().Position
		elseif stand:IsA("BasePart") then
			standPos = stand.Position
		end
	end
	Windows.Show("Hatch")
	render()
end

function Hatch.IsBusy(): boolean
	return hatching or auto
end

function Hatch.Init()
	win = Windows.Create("Hatch", { Title = "Hatch", Icon = Theme.Icons.Egg, Color = Theme.Tones.Yellow.Rim })
	local body = win.Body
	-- left: egg
	local left = Kit.box({ Size = UDim2.new(0, 270, 1, -80), Parent = body })
	eggHolder = Kit.panel({
		Size = UDim2.fromOffset(250, 230),
		Position = UDim2.fromOffset(10, 0),
		BackgroundColor3 = Theme.Colors.PanelAlt,
		Parent = left,
	}, { Kit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 220, 255)) })
	eggName = Kit.fitLabel("", 28, { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 238), Parent = left })
	costPill = Kit.pill("", Theme.Colors.Coins, {
		Size = UDim2.fromOffset(170, 38),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 280),
		Parent = left,
	})
	luckLabel = Kit.fitLabel("", 18, {
		Size = UDim2.new(1, -10, 0, 50),
		Position = UDim2.fromOffset(5, 324),
		Font = Theme.FontBody,
		Parent = left,
	})
	-- right: odds
	local right = Kit.panel({
		Size = UDim2.new(1, -284, 1, -80),
		Position = UDim2.fromOffset(280, 0),
		BackgroundColor3 = Theme.Colors.PanelAlt,
		StrokeThickness = 2,
		Parent = body,
	})
	Kit.fitLabel("Odds", 24, { Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(12, 4), Align = "Left", Parent = right })
	oddsList = Kit.scroll({
		Size = UDim2.new(1, -12, 1, -44),
		Position = UDim2.fromOffset(8, 40),
		Parent = right,
	}, { Kit.list(Enum.FillDirection.Vertical, 6), Kit.pad(2, 4, 4, 2) })
	-- bottom: buttons
	local bar = Kit.box({
		Size = UDim2.new(1, 0, 0, 70),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Parent = body,
	}, { Kit.list(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	btn1 = Kit.button("Hatch 1", "Green", { Size = UDim2.fromOffset(260, 66), LayoutOrder = 1, Parent = bar }, function()
		task.spawn(doHatch, 1, false)
	end)
	btn3 = Kit.button("Hatch 3", "Green", { Size = UDim2.fromOffset(260, 66), LayoutOrder = 2, Parent = bar }, function()
		if not State.HasPass("TripleHatch") then
			Shop.Upsell("TripleHatch", "Open 3 eggs at once!")
			return
		end
		task.spawn(doHatch, 3, false)
	end)
	btnAuto = Kit.button("Auto: OFF", "White", { Size = UDim2.fromOffset(220, 66), LayoutOrder = 3, Parent = bar }, function()
		if auto then
			stopAuto()
		else
			startAuto()
		end
	end)
	lockNote = Kit.fitLabel(Theme.Icons.Lock .. " Prism Eggs aren't available for your account (just joined? give it a few seconds).", 18, {
		Size = UDim2.new(1, -20, 0, 50),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -72),
		Color = Theme.Colors.Bad,
		Font = Theme.FontBody,
		Visible = false,
		ZIndex = 5,
		Parent = body,
	})

	Windows.Register("Hatch", function(eggId: string?, stand: Instance?)
		if eggId then
			Hatch.Open(eggId, stand)
		elseif currentEgg then
			Hatch.Open(currentEgg, nil)
		end
	end)
	State.Changed:Connect(function()
		if win.IsOpen then
			renderOdds()
			renderButtons()
		end
	end)
end

return Hatch
