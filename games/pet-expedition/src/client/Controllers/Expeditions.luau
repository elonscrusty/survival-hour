--!strict
-- Expeditions (the idle loop): slots with live countdowns, Claim with a
-- reward reveal, Skip for gems, locked slots that offer the MoreExpeditions
-- pass, and a 3-step start flow: island -> duration -> up to 3 unequipped pets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Areas = require(Shared:WaitForChild("Areas"))
local Types = require(Shared:WaitForChild("Types"))
local ExpeditionLogic = require(Shared:WaitForChild("Logic"):WaitForChild("Expedition"))

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local PetInfo = require("../Core/PetInfo")
local Format = require("../Core/Format")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Viewport = require("../UI/Viewport")
local PetCard = require("../UI/PetCard")
local Toasts = require("../UI/Toasts")
local Shop = require("./Shop")

type PetInstance = Types.PetInstance
type Expedition = Types.Expedition

local Expeditions = {}

local EXTRA_SLOTS_FROM_PASS = 2

local win: Windows.Window
local header: Frame
local stepLabel: TextLabel
local backBtn: TextButton
local content: ScrollingFrame
local footer: Frame
local listLayout: UIListLayout
local gridLayout: UIGridLayout

local view = "Slots" -- Slots | Area | Duration | Pets
local draft = { Area = "", Duration = "", Pets = {} :: { string } }
local tickers: { () -> () } = {}
local renderedSig = ""

local function durationDef(key: string)
	for _, d in Config.ExpeditionDurations do
		if d.Key == key then
			return d
		end
	end
	return Config.ExpeditionDurations[1]
end

-- Same price the server charges (Logic/Expedition).
local function skipCost(exp: Expedition): number
	return ExpeditionLogic.SkipCost(exp :: any, State.Now())
end

local function estimateCoins(areaId: string, durationKey: string, uids: { string }): number
	local a = Areas.ById[areaId]
	local dd = durationDef(durationKey)
	local power = 0
	for _, uid in uids do
		local p = State.PetByUid(uid)
		if p then
			power += PetInfo.Power(p)
		end
	end
	return power * Config.ExpeditionCoinsPerPower * (if a then a.CoinMult else 1) * dd.Mult
end

local function render() end -- assigned below

local function setView(v: string)
	view = v
	renderedSig = ""
	render()
end

-- Reward reveal popup -------------------------------------------------------------

local function showReward(reward: { [string]: any })
	local gui = Windows.Gui("Popups")
	local shade: TextButton = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Backdrop,
		BackgroundTransparency = 0.4,
		Size = UDim2.new(1, 0, 1, 200),
		Position = UDim2.fromOffset(0, -100),
		Parent = gui,
	})
	local box = Kit.panel({
		Size = UDim2.fromOffset(620, 400),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Corner = 20,
		StrokeThickness = 4,
		Parent = shade,
	})
	Kit.autoScale(box, 1)
	Kit.fitLabel(Theme.Icons.Expeditions .. " Expedition complete!", 34, { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 10), Parent = box })
	local items = Kit.scroll({
		Size = UDim2.new(1, -30, 1, -150),
		Position = UDim2.fromOffset(15, 66),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = box,
	}, { Kit.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local order = 0
	local function tile(icon: string, text: string, color: Color3)
		order += 1
		local t = Kit.panel({ Size = UDim2.fromOffset(130, 150), LayoutOrder = order, BackgroundColor3 = Theme.Lighten(color, 0.7), Parent = items })
		Kit.fitLabel(icon, 54, { Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 12), Parent = t })
		Kit.fitLabel(text, 24, { Size = UDim2.new(1, -10, 0, 40), Position = UDim2.fromOffset(5, 98), Outline = Theme.Darken(color, 0.5), Color = color, Parent = t })
		Kit.pop(t, 0.3)
	end
	if type(reward.Coins) == "number" and reward.Coins > 0 then
		tile(Theme.Icons.Coins, "+" .. Format.num(reward.Coins), Theme.Colors.Coins)
	end
	if type(reward.Gems) == "number" and reward.Gems > 0 then
		tile(Theme.Icons.Gems, "+" .. Format.num(reward.Gems), Theme.Colors.Gems)
	end
	if type(reward.Boost) == "string" then
		local def = Config.Boosts[reward.Boost]
		tile(Theme.Icons.Boost, if def then def.Name else reward.Boost, Theme.Colors.Luck)
	end
	if type(reward.Pets) == "table" then
		for _, p in reward.Pets do
			if type(p) == "table" and type(p.Id) == "string" then
				order += 1
				local card = PetCard.new(p :: PetInstance, Vector2.new(130, 150))
				card.LayoutOrder = order
				card.Parent = items
				Kit.pop(card, 0.3)
				local species = PetInfo.Species(p.Id)
				if species and species.Source == "Expedition" then
					Toasts.Show(Theme.Icons.Star .. " Rare find: <b>" .. PetInfo.FullName(p :: PetInstance) .. "</b>!", "gold", { PetId = p.Id, Variant = p.Variant, Shiny = p.Shiny })
				end
			end
		end
	end
	if order == 0 then
		tile("🍃", "Nothing this time", Theme.Colors.TextDim)
	end
	Sounds.Play("Reward")
	Kit.button("Yay!", "Green", {
		Size = UDim2.fromOffset(220, 64),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Parent = box,
	}, function()
		shade:Destroy()
	end)
	Kit.pop(box)
end

-- Slots view --------------------------------------------------------------------

local function claim(slot: number)
	local res, err = Remote.Try("ClaimExpedition", slot)
	if res then
		showReward(if type(res.reward) == "table" then res.reward else {})
	elseif err then
		local d = State.Data
		local full = d ~= nil and #d.Pets >= d.MaxStorage - Config.MaxPetsPerExpedition
		Toasts.Show(err .. (if full then "\nFree some space: delete or craft pets in " .. Theme.Icons.Pets .. " Pets." else ""), "bad", { Duration = 5 })
	end
end

local function skip(slot: number, e: Expedition)
	local left = e.EndAt - State.Now()
	local cost = skipCost(e)
	Windows.Confirm(
		"Finish now?",
		"Skip the remaining " .. Format.time(left) .. " for " .. Theme.Icons.Gems .. " <b>" .. cost .. "</b> gems.",
		"Skip " .. Theme.Icons.Gems .. cost,
		"Cyan",
		function()
			Remote.CallOnce("SkipExpedition", slot)
		end
	)
end

local function slotRow(slot: number, e: Expedition?, order: number)
	local row = Kit.panel({
		Size = UDim2.new(1, -10, 0, 120),
		LayoutOrder = order,
		BackgroundColor3 = if e then Theme.Colors.Panel else Theme.Colors.PanelAlt,
		Parent = content,
	})
	Kit.fitLabel("#" .. slot, 26, { Size = UDim2.fromOffset(50, 40), Position = UDim2.fromOffset(8, 8), Color = Theme.Colors.TextDim, Parent = row })
	if not e then
		Kit.fitLabel("Free slot. Send pets to explore an island!", 22, {
			Size = UDim2.new(1, -360, 0, 60),
			Position = UDim2.fromOffset(60, 30),
			Align = "Left",
			Color = Theme.Colors.TextDim,
			Parent = row,
		})
		Kit.button(Theme.Icons.Expeditions .. " Start", "Green", {
			Size = UDim2.fromOffset(240, 70),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Parent = row,
		}, function()
			draft.Area = ""
			draft.Duration = ""
			draft.Pets = {}
			setView("Area")
		end)
		return
	end
	local exp = e :: Expedition
	local a = Areas.ById[exp.Area]
	local dd = durationDef(exp.Duration)
	Kit.fitLabel((if a then a.Name else exp.Area) .. "  ·  " .. Format.duration(dd.Seconds), 22, {
		Size = UDim2.new(1, -560, 0, 30),
		Position = UDim2.fromOffset(60, 10),
		Align = "Left",
		Parent = row,
	})
	local pics = Kit.box({ Size = UDim2.fromOffset(210, 70), Position = UDim2.fromOffset(60, 44), Parent = row }, {
		Kit.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left),
	})
	for i, uid in exp.Pets do
		local p = State.PetByUid(uid)
		if p then
			Viewport.Pet(p.Id, p.Variant, p.Shiny, { Size = UDim2.fromOffset(66, 66), LayoutOrder = i, Parent = pics })
		end
	end
	local bar, set = Kit.bar({ Size = UDim2.fromOffset(240, 32), Position = UDim2.fromOffset(280, 58) }, Theme.Colors.Good)
	bar.Parent = row
	local btn = Kit.button("", "Green", {
		Size = UDim2.fromOffset(240, 70),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Parent = row,
	}, function()
		if State.Now() >= exp.EndAt then
			claim(slot)
		else
			skip(slot, exp)
		end
	end)
	local wasDone: boolean? = nil
	local function tick()
		local now = State.Now()
		local total = math.max(1, exp.EndAt - exp.StartAt)
		local left = exp.EndAt - now
		local done = left <= 0
		set(1 - math.max(0, left) / total, if done then "Done!" else Format.time(left))
		if done ~= wasDone then
			wasDone = done
			if done then
				Kit.setButton(btn, { Text = Theme.Icons.Gift .. " Claim!", Tone = "Green" })
				Kit.pop(btn, 1.2)
			end
		end
		if not done then
			Kit.setButton(btn, { Text = "Skip " .. Theme.Icons.Gems .. skipCost(exp), Tone = "Cyan" })
		end
	end
	tick()
	table.insert(tickers, tick)
end

local function lockedRow(order: number)
	local row = Kit.panel({
		Size = UDim2.new(1, -10, 0, 90),
		LayoutOrder = order,
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = content,
	})
	Kit.fitLabel(Theme.Icons.Lock .. " Extra slot", 24, {
		Size = UDim2.new(1, -320, 0, 60),
		Position = UDim2.fromOffset(20, 15),
		Align = "Left",
		Color = Theme.Colors.TextDim,
		Parent = row,
	})
	Kit.button("Unlock +" .. EXTRA_SLOTS_FROM_PASS .. " slots", "Purple", {
		Size = UDim2.fromOffset(260, 64),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Parent = row,
	}, function()
		Shop.Upsell("MoreExpeditions", "Run more expeditions at the same time!")
	end)
end

-- Start flow views -----------------------------------------------------------------

local function areaCards()
	local d = State.Data
	if not d then
		return
	end
	for i, a in Areas.List do
		local open = d.Areas[a.Id] == true
		local card = Kit.panel({
			Size = UDim2.fromOffset(250, 210),
			LayoutOrder = i,
			BackgroundColor3 = if open then Theme.Colors.Panel else Theme.Colors.PanelDark,
			Parent = content,
		})
		Kit.fitLabel(a.Name, 24, { Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 6), Parent = card })
		local found = d.Index[a.ExpeditionPet] == true
		Viewport.Pet(a.ExpeditionPet, "Normal", false, {
			Size = UDim2.fromOffset(100, 100),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 38),
			Silhouette = not found,
			Parent = card,
		})
		Kit.fitLabel((if found then PetInfo.Name(a.ExpeditionPet) else "???") .. " can be found here", 15, {
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.fromOffset(8, 138),
			Font = Theme.FontBody,
			Color = Theme.Colors.TextDim,
			Parent = card,
		})
		local b = Kit.button(if open then "Choose" else Theme.Icons.Lock .. " Locked", if open then "Green" else "Grey", {
			Size = UDim2.new(1, -24, 0, 44),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			TextSize = 20,
			Parent = card,
		}, function()
			if not open then
				Toasts.Show("Open " .. a.Name .. " first!", "info")
				return
			end
			draft.Area = a.Id
			setView("Duration")
		end)
		if not open then
			Kit.setButton(b, { Tone = "Grey" })
		end
	end
end

local function durationCards()
	for i, dd in Config.ExpeditionDurations do
		local card = Kit.panel({
			Size = UDim2.fromOffset(250, 210),
			LayoutOrder = i,
			Parent = content,
		})
		Kit.fitLabel(Theme.Icons.Clock .. " " .. Format.duration(dd.Seconds), 30, { Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 6), Parent = card })
		local eggChance = math.min(1, Config.ExpeditionEggChance * dd.Mult)
		Kit.fitLabel(string.format(
			"%s x%d rewards\n%s Rare pet %s\n%s Gems %s\n%s Free egg %s",
			Theme.Icons.Coins,
			dd.Mult,
			Theme.Icons.Star,
			Format.percent(dd.FindChance * 100),
			Theme.Icons.Gems,
			Format.percent(dd.GemChance * 100),
			Theme.Icons.Egg,
			Format.percent(eggChance * 100)
		), 18, {
			Size = UDim2.new(1, -24, 0, 100),
			Position = UDim2.fromOffset(12, 48),
			Font = Theme.FontBody,
			Align = "Left",
			Parent = card,
		})
		Kit.button("Choose", "Green", {
			Size = UDim2.new(1, -24, 0, 44),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			TextSize = 20,
			Parent = card,
		}, function()
			draft.Duration = dd.Key
			draft.Pets = {}
			setView("Pets")
		end)
	end
end

local sendBtn: TextButton? = nil
local estimateLabel: TextLabel? = nil

local function refreshSend()
	local n = #draft.Pets
	if sendBtn then
		Kit.setButton(sendBtn, { Text = "Send " .. n .. "/" .. Config.MaxPetsPerExpedition, Enabled = n > 0 })
	end
	if estimateLabel then
		estimateLabel.Text = "Expected about " .. Theme.Icons.Coins .. " <b>" .. Format.num(estimateCoins(draft.Area, draft.Duration, draft.Pets)) .. "</b> coins"
	end
end

local function petPicker()
	local d = State.Data
	if not d then
		return
	end
	local busy = State.BusyUids()
	local eq: { [string]: boolean } = {}
	for _, uid in d.Equipped do
		eq[uid] = true
	end
	local trading = State.TradeUids()
	local list: { PetInstance } = {}
	for _, p in d.Pets do
		if not busy[p.Uid] and not trading[p.Uid] then
			table.insert(list, p)
		end
	end
	-- unequipped pets first; equipped ones can go too (the server unequips them)
	local power: { [string]: number } = {}
	for _, p in list do
		power[p.Uid] = PetInfo.Power(p)
	end
	table.sort(list, function(a, b)
		local ea, eb = eq[a.Uid] == true, eq[b.Uid] == true
		if ea ~= eb then
			return eb
		end
		if power[a.Uid] ~= power[b.Uid] then
			return power[a.Uid] > power[b.Uid]
		end
		return a.Uid < b.Uid
	end)
	if #list == 0 then
		Kit.fitLabel("No free pets. Hatch more!", 22, {
			Size = UDim2.new(1, 0, 0, 60),
			Color = Theme.Colors.TextDim,
			Parent = content,
		})
	end
	local cardsByUid: { [string]: TextButton } = {}
	for i, p in list do
		local uid = p.Uid
		local card = PetCard.new(p, Vector2.new(100, 118), function()
			local idx = table.find(draft.Pets, uid)
			if idx then
				table.remove(draft.Pets, idx)
			elseif #draft.Pets >= Config.MaxPetsPerExpedition then
				Toasts.Show("Up to " .. Config.MaxPetsPerExpedition .. " pets per expedition.", "info")
				return
			else
				table.insert(draft.Pets, uid)
			end
			for u, c in cardsByUid do
				PetCard.SetFlags(c, { Selected = table.find(draft.Pets, u) ~= nil, Locked = (State.PetByUid(u) or p).Locked, Equipped = eq[u] == true })
			end
			refreshSend()
		end)
		card.LayoutOrder = i
		card.Parent = content
		cardsByUid[uid] = card
		PetCard.SetFlags(card, { Selected = table.find(draft.Pets, uid) ~= nil, Locked = p.Locked, Equipped = eq[uid] == true })
	end
end

local function renderImpl()
	if not win.IsOpen then
		return
	end
	local d = State.Data
	if not d then
		return
	end
	-- the slots view rebuilds only when the expeditions themselves change
	local sig = view
	if view == "Slots" then
		sig ..= "|" .. d.ExpeditionSlots .. "|" .. tostring(State.HasPass("MoreExpeditions"))
		for k, e in d.Expeditions do
			sig ..= k .. e.Area .. e.EndAt .. table.concat(e.Pets, ",")
		end
	end
	if sig == renderedSig then
		return
	end
	renderedSig = sig
	table.clear(tickers)
	Kit.clear(content)
	Kit.clear(footer)
	sendBtn = nil
	estimateLabel = nil
	local layout = gridLayout
	backBtn.Visible = view ~= "Slots"
	footer.Visible = view == "Pets"
	if view == "Slots" then
		layout.Parent = nil
		listLayout.Parent = content
		content.Size = UDim2.new(1, 0, 1, -60)
		stepLabel.Text = "Your expeditions"
		for slot = 1, d.ExpeditionSlots do
			slotRow(slot, d.Expeditions[tostring(slot)], slot)
		end
		if not State.HasPass("MoreExpeditions") then
			for i = 1, EXTRA_SLOTS_FROM_PASS do
				lockedRow(100 + i)
			end
		end
	else
		listLayout.Parent = nil
		layout.Parent = content
		content.Size = UDim2.new(1, 0, 1, if view == "Pets" then -140 else -60)
		if view == "Area" then
			stepLabel.Text = "1/3  Pick an island"
			layout.CellSize = UDim2.fromOffset(250, 210)
			areaCards()
		elseif view == "Duration" then
			local a = Areas.ById[draft.Area]
			stepLabel.Text = "2/3  How long? (" .. (if a then a.Name else "") .. ")"
			layout.CellSize = UDim2.fromOffset(250, 210)
			durationCards()
		else
			stepLabel.Text = "3/3  Pick up to " .. Config.MaxPetsPerExpedition .. " pets (equipped ones get unequipped)"
			layout.CellSize = UDim2.fromOffset(100, 118)
			petPicker()
			estimateLabel = Kit.fitLabel("", 22, {
				Size = UDim2.new(1, -280, 1, 0),
				Align = "Left",
				Rich = true,
				Parent = footer,
			})
			sendBtn = Kit.button("Send", "Green", {
				Size = UDim2.fromOffset(250, 66),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -4, 0.5, 0),
				Parent = footer,
			}, function()
				if #draft.Pets == 0 then
					return
				end
				local res = Remote.CallOnce("StartExpedition", draft.Area, draft.Duration, table.clone(draft.Pets))
				if res then
					Sounds.Play("Reward")
					Toasts.Show(Theme.Icons.Expeditions .. " Your pets set off! Come back in " .. Format.duration(durationDef(draft.Duration).Seconds) .. ".", "good")
					draft.Pets = {}
					setView("Slots")
				end
			end)
			refreshSend()
		end
	end
end
render = renderImpl

function Expeditions.Init()
	win = Windows.Create("Expeditions", { Title = "Expeditions", Icon = Theme.Icons.Expeditions, Color = Theme.Tones.Green.Rim })
	header = Kit.box({ Size = UDim2.new(1, 0, 0, 52), Parent = win.Body })
	backBtn = Kit.button("◀ Back", "White", { Size = UDim2.fromOffset(130, 50), Parent = header }, function()
		if view == "Pets" then
			setView("Duration")
		elseif view == "Duration" then
			setView("Area")
		else
			setView("Slots")
		end
	end)
	stepLabel = Kit.fitLabel("", 26, {
		Size = UDim2.new(1, -150, 1, 0),
		Position = UDim2.fromOffset(146, 0),
		Align = "Left",
		Parent = header,
	})
	content = Kit.scroll({
		Size = UDim2.new(1, 0, 1, -60),
		Position = UDim2.fromOffset(0, 60),
		Parent = win.Body,
	}, { Kit.pad(4, 8, 6, 4) })
	-- slots use a list, the start flow a grid; only one is parented at a time
	listLayout = Kit.list(Enum.FillDirection.Vertical, 10)
	gridLayout = Kit.grid(Vector2.new(250, 210), 12)
	listLayout.Parent = content
	footer = Kit.box({
		Size = UDim2.new(1, 0, 0, 74),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Visible = false,
		Parent = win.Body,
	})
	win.Opened:Connect(function(which: string?)
		if which == "Start" then
			setView("Area")
		else
			setView("Slots")
		end
	end)
	State.Changed:Connect(function()
		if view == "Slots" then
			render()
		end
	end)
	task.spawn(function()
		while true do
			if win.IsOpen then
				for _, t in tickers do
					t()
				end
			end
			task.wait(0.5)
		end
	end)
end

return Expeditions
