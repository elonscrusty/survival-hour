--!strict
-- Trading: a player list with Request buttons, the incoming request popup
-- (accept / decline, times out), and the trade window showing both offers
-- with pet pictures, a gems box, Ready toggle, countdown and Cancel.
-- Disabled with a message when CanTrade is false (PolicyService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local PetInfo = require("../Core/PetInfo")
local Format = require("../Core/Format")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local PetCard = require("../UI/PetCard")
local Toasts = require("../UI/Toasts")

type PetInstance = Types.PetInstance
type TradeView = Types.TradeView
type TradeSide = Types.TradeSide

local Trade = {}

local player = Players.LocalPlayer

-- Player list window
local listWin: Windows.Window
local playerList: ScrollingFrame
local disabledNote: TextLabel
local requestedAt: { [number]: number } = {}

-- Trade window
local tradeWin: Windows.Window
local myGrid: ScrollingFrame
local theirGrid: ScrollingFrame
local myReady: Frame
local theirReady: Frame
local theirTitle: TextLabel
local theirGems: TextLabel
local gemsBox: TextBox
local readyBtn: TextButton
local addBtn: TextButton
local countdownLabel: TextLabel
local picker: Frame
local pickerGrid: ScrollingFrame
local closingByCode = false
local lastViewId: string? = nil
local renderedSig = ""

local function myOffer(): ({ string }, number)
	local v = State.Trade
	if not v then
		return {}, 0
	end
	local uids: { string } = {}
	for _, p in v.Me.Pets do
		table.insert(uids, p.Uid)
	end
	return uids, v.Me.Gems
end

local function sendOffer(uids: { string }, gems: number)
	Remote.CallOnce("TradeSetOffer", uids, gems)
end

-- Player list ---------------------------------------------------------------------

local function renderList()
	if not listWin.IsOpen then
		return
	end
	local d = State.Data
	Kit.clear(playerList)
	local can = d ~= nil and d.CanTrade
	disabledNote.Visible = not can
	playerList.Visible = can
	if not can then
		return
	end
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then
			table.insert(others, p)
		end
	end
	table.sort(others, function(a, b)
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)
	if #others == 0 then
		Kit.fitLabel("Nobody else is here yet. Invite a friend!", 22, {
			Size = UDim2.new(1, -10, 0, 60),
			Color = Theme.Colors.TextDim,
			Parent = playerList,
		})
	end
	for i, p in others do
		local row = Kit.panel({ Size = UDim2.new(1, -10, 0, 84), LayoutOrder = i, Parent = playerList })
		local thumb: ImageLabel = Kit.new("ImageLabel", {
			Size = UDim2.fromOffset(68, 68),
			Position = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Theme.Colors.PanelDark,
			Parent = row,
		}, { Kit.corner(UDim.new(0.5, 0)) })
		task.spawn(function()
			local ok, img = pcall(function()
				return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if ok and thumb.Parent then
				thumb.Image = img
			end
		end)
		Kit.fitLabel(p.DisplayName, 24, { Size = UDim2.new(1, -320, 0, 34), Position = UDim2.fromOffset(88, 10), Align = "Left", Parent = row })
		Kit.fitLabel("@" .. p.Name, 16, {
			Size = UDim2.new(1, -320, 0, 24),
			Position = UDim2.fromOffset(88, 46),
			Align = "Left",
			Font = Theme.FontBody,
			Color = Theme.Colors.TextDim,
			Parent = row,
		})
		local uid = p.UserId
		local b = Kit.button(Theme.Icons.Trade .. " Request", "Blue", {
			Size = UDim2.fromOffset(210, 62),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Parent = row,
		}, nil)
		b.Activated:Connect(function()
			local since = os.clock() - (requestedAt[uid] or -999)
			if since < Config.TradeCooldown then
				Toasts.Show("Wait " .. math.ceil(Config.TradeCooldown - since) .. "s before asking again.", "info")
				return
			end
			Sounds.Play("Click")
			local res = Remote.CallOnce("TradeRequest", uid)
			if res then
				requestedAt[uid] = os.clock()
				Toasts.Show("Trade request sent to " .. p.DisplayName .. "!", "good")
				Kit.setButton(b, { Text = "Sent!", Tone = "Grey" })
			end
		end)
	end
end

-- Incoming request popup ---------------------------------------------------------------

local function showRequest(fromUserId: number, fromName: string)
	local d = State.Data
	if d and not d.CanTrade then
		return
	end
	local gui = Windows.Gui("Popups")
	local box = Kit.panel({
		Name = "TradeRequest",
		Size = UDim2.fromOffset(460, 190),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Corner = 20,
		StrokeThickness = 4,
		Parent = gui,
	})
	Kit.autoScale(box, 1)
	Kit.fitLabel(Theme.Icons.Trade .. " " .. fromName .. " wants to trade!", 26, {
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 10),
		Parent = box,
	})
	local bar, set = Kit.bar({ Size = UDim2.new(1, -40, 0, 16), Position = UDim2.fromOffset(20, 58) }, Theme.Colors.Info)
	bar.Parent = box
	local done = false
	local function close()
		done = true
		box:Destroy()
	end
	Kit.button("Decline", "Red", {
		Size = UDim2.fromOffset(190, 64),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -16),
		Parent = box,
	}, function()
		close()
		Remote.Quiet("TradeRespond", fromUserId, false)
	end)
	Kit.button("Accept", "Green", {
		Size = UDim2.fromOffset(190, 64),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -16),
		Parent = box,
	}, function()
		close()
		Remote.CallOnce("TradeRespond", fromUserId, true)
	end)
	Kit.pop(box)
	Sounds.Play("Toast")
	task.spawn(function()
		local start = os.clock()
		while not done do
			local left = Config.TradeRequestTimeout - (os.clock() - start)
			if left <= 0 then
				close()
				break
			end
			set(left / Config.TradeRequestTimeout)
			task.wait(0.1)
		end
	end)
end

-- Trade window ----------------------------------------------------------------------

local function readyBadge(f: Frame, ready: boolean)
	f.BackgroundColor3 = if ready then Theme.Colors.Good else Theme.Colors.Locked
	Kit.setPill(f, if ready then Theme.Icons.Equipped .. " Ready" else "Not ready")
end

local function fillGrid(grid: ScrollingFrame, pets: { PetInstance })
	Kit.clear(grid)
	for i, p in pets do
		local c = PetCard.new(p, Vector2.new(92, 108), nil)
		c.LayoutOrder = i
		c.Parent = grid
	end
	if #pets == 0 then
		Kit.fitLabel("No pets offered", 18, { Size = UDim2.fromOffset(200, 40), Color = Theme.Colors.TextDim, Parent = grid })
	end
end

local function renderPicker()
	if not picker.Visible then
		return
	end
	local d = State.Data
	if not d then
		return
	end
	Kit.clear(pickerGrid)
	local busy = State.BusyUids()
	local offered, gems = myOffer()
	local offeredSet: { [string]: boolean } = {}
	for _, uid in offered do
		offeredSet[uid] = true
	end
	local list: { PetInstance } = {}
	for _, p in d.Pets do
		if not busy[p.Uid] then
			table.insert(list, p)
		end
	end
	PetInfo.Sort(list, nil)
	for i, p in list do
		local uid = p.Uid
		local card = PetCard.new(p, Vector2.new(92, 108), function()
			if p.Locked then
				Toasts.Show("Locked pets can't be traded. Unlock it in Pets first.", "info")
				return
			end
			local cur = myOffer()
			local idx = table.find(cur, uid)
			if idx then
				table.remove(cur, idx)
			elseif #cur >= Config.TradeMaxPets then
				Toasts.Show("Up to " .. Config.TradeMaxPets .. " pets per trade.", "info")
				return
			else
				table.insert(cur, uid)
			end
			sendOffer(cur, gems)
		end)
		card.LayoutOrder = i
		card.Parent = pickerGrid
		PetCard.SetFlags(card, { Selected = offeredSet[uid] == true, Locked = p.Locked, Equipped = State.IsEquipped(uid), Dim = p.Locked })
	end
end

local function renderTrade()
	local v = State.Trade
	if not v then
		return
	end
	local sig = v.Id .. v.Status .. tostring(v.Me.Ready) .. tostring(v.Them.Ready) .. v.Me.Gems .. "|" .. v.Them.Gems
	for _, p in v.Me.Pets do
		sig ..= p.Uid
	end
	sig ..= "|"
	for _, p in v.Them.Pets do
		sig ..= p.Uid
	end
	if sig ~= renderedSig then
		renderedSig = sig
		theirTitle.Text = v.Them.Name .. "'s offer"
		fillGrid(myGrid, v.Me.Pets)
		fillGrid(theirGrid, v.Them.Pets)
		readyBadge(myReady, v.Me.Ready)
		readyBadge(theirReady, v.Them.Ready)
		theirGems.Text = Theme.Icons.Gems .. " " .. Format.commas(v.Them.Gems)
		if not gemsBox:IsFocused() then
			gemsBox.Text = tostring(v.Me.Gems)
		end
		Kit.setButton(readyBtn, {
			Text = if v.Me.Ready then "Not ready" else Theme.Icons.Equipped .. " Ready",
			Tone = if v.Me.Ready then "Yellow" else "Green",
		})
		renderPicker()
	end
end

local function closeTradeWindow()
	if tradeWin.IsOpen then
		closingByCode = true
		Windows.Close()
		closingByCode = false
	end
	picker.Visible = false
end

local function onTrade(v: TradeView?)
	if not v or v.Status == "Done" or v.Status == "Cancelled" then
		if v and v.Status == "Done" then
			Sounds.Play("Reward")
			Toasts.Show(Theme.Icons.Trade .. " Trade complete!", "good")
		elseif lastViewId ~= nil then
			Toasts.Show("Trade closed.", "info")
		end
		lastViewId = nil
		renderedSig = ""
		closeTradeWindow()
		return
	end
	if lastViewId ~= v.Id then
		lastViewId = v.Id
		renderedSig = ""
		picker.Visible = false
	end
	if not tradeWin.IsOpen then
		Windows.Show("TradeSession")
	end
	renderTrade()
end

local function buildTradeWindow()
	tradeWin = Windows.Create("TradeSession", { Title = "Trade", Icon = Theme.Icons.Trade, Color = Theme.Tones.Red.Top })
	local body = tradeWin.Body
	local function side(xScale: number, xOffset: number, title: string): (Frame, TextLabel, Frame, ScrollingFrame)
		local f = Kit.panel({
			Size = UDim2.new(0.5, -6, 1, -78),
			Position = UDim2.new(xScale, xOffset, 0, 0),
			BackgroundColor3 = Theme.Colors.PanelAlt,
			Parent = body,
		})
		local t = Kit.fitLabel(title, 24, { Size = UDim2.new(1, -150, 0, 36), Position = UDim2.fromOffset(12, 6), Align = "Left", Parent = f })
		local badge = Kit.pill("Not ready", Theme.Colors.Locked, {
			Size = UDim2.fromOffset(130, 34),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 8),
			Parent = f,
		})
		local grid = Kit.scroll({
			Size = UDim2.new(1, -16, 1, -108),
			Position = UDim2.fromOffset(8, 48),
			Parent = f,
		}, { Kit.grid(Vector2.new(92, 108), 8), Kit.pad(6, 4, 6, 4) })
		return f, t, badge, grid
	end
	local mine, _, mb, mg = side(0, 0, "Your offer")
	myReady, myGrid = mb, mg
	local _, tt, tb, tg = side(0.5, 6, "Their offer")
	theirTitle, theirReady, theirGrid = tt, tb, tg
	-- gems
	Kit.fitLabel(Theme.Icons.Gems, 30, { Size = UDim2.fromOffset(40, 46), Position = UDim2.new(0, 12, 1, -54), Parent = mine })
	gemsBox = Kit.new("TextBox", {
		Size = UDim2.new(1, -70, 0, 44),
		Position = UDim2.new(0, 56, 1, -54),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font,
		TextSize = 24,
		TextColor3 = Theme.Colors.Text,
		PlaceholderText = "Gems to add",
		Text = "0",
		ClearTextOnFocus = false,
		Parent = mine,
	}, { Kit.corner(10), Kit.stroke(Theme.Colors.Stroke, 2) })
	gemsBox.FocusLost:Connect(function()
		local d = State.Data
		local n = tonumber((gemsBox.Text:gsub("[^%d]", ""))) or 0
		n = math.clamp(math.floor(n), 0, math.min(Config.TradeMaxGems, if d then d.Gems else 0))
		gemsBox.Text = tostring(n)
		local uids, gems = myOffer()
		if n ~= gems then
			sendOffer(uids, n)
		end
	end)
	theirGems = Kit.fitLabel(Theme.Icons.Gems .. " 0", 26, {
		Size = UDim2.new(0.5, -30, 0, 44),
		Position = UDim2.new(0.5, 18, 1, -132),
		Align = "Left",
		Parent = body,
	})
	-- bottom bar
	local bar = Kit.box({
		Size = UDim2.new(1, 0, 0, 70),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Parent = body,
	})
	addBtn = Kit.button(Theme.Icons.Pets .. " Add pets", "Blue", { Size = UDim2.fromOffset(200, 64), Position = UDim2.fromOffset(0, 3), Parent = bar }, function()
		picker.Visible = not picker.Visible
		Kit.setButton(addBtn, { Text = if picker.Visible then "Done" else Theme.Icons.Pets .. " Add pets" })
		renderPicker()
	end)
	readyBtn = Kit.button("Ready", "Green", { Size = UDim2.fromOffset(200, 64), Position = UDim2.fromOffset(212, 3), Parent = bar }, function()
		local v = State.Trade
		if v then
			Remote.CallOnce("TradeReady", not v.Me.Ready)
		end
	end)
	countdownLabel = Kit.fitLabel("", 26, {
		Size = UDim2.new(1, -640, 1, 0),
		Position = UDim2.fromOffset(424, 0),
		Color = Theme.Colors.Good,
		Parent = bar,
	})
	Kit.button("Cancel", "Red", {
		Size = UDim2.fromOffset(190, 64),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 3),
		Parent = bar,
	}, function()
		Remote.Quiet("TradeCancel")
		closeTradeWindow()
	end)
	-- pet picker overlay (covers the left side)
	picker = Kit.panel({
		Size = UDim2.new(0.5, -6, 1, -78),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = body,
	})
	Kit.fitLabel("Tap pets to add or remove", 20, { Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 6), ZIndex = 11, Parent = picker })
	pickerGrid = Kit.scroll({
		Size = UDim2.new(1, -16, 1, -46),
		Position = UDim2.fromOffset(8, 40),
		ZIndex = 11,
		Parent = picker,
	}, { Kit.grid(Vector2.new(92, 108), 8), Kit.pad(6, 4, 6, 4) })
	-- closing the window by hand cancels the trade
	tradeWin.Closed:Connect(function()
		if not closingByCode and State.Trade ~= nil then
			Remote.Quiet("TradeCancel")
		end
		picker.Visible = false
		Kit.setButton(addBtn, { Text = Theme.Icons.Pets .. " Add pets" })
	end)
end

function Trade.Init()
	listWin = Windows.Create("Trade", { Title = "Trade", Icon = Theme.Icons.Trade, Color = Theme.Tones.Red.Top, Size = Vector2.new(760, 520) })
	playerList = Kit.scroll({ Size = UDim2.fromScale(1, 1), Parent = listWin.Body }, {
		Kit.list(Enum.FillDirection.Vertical, 8),
		Kit.pad(4, 8, 4, 4),
	})
	disabledNote = Kit.fitLabel(Theme.Icons.Lock .. " Trading isn't available for your account (just joined? give it a few seconds).", 24, {
		Size = UDim2.new(1, -20, 0, 80),
		Position = UDim2.fromOffset(10, 120),
		Color = Theme.Colors.TextDim,
		Visible = false,
		Parent = listWin.Body,
	})
	listWin.Opened:Connect(renderList)
	Players.PlayerAdded:Connect(renderList)
	Players.PlayerRemoving:Connect(function()
		task.defer(renderList)
	end)
	buildTradeWindow()

	State.TradeChanged:Connect(onTrade)
	local lastCanTrade: boolean? = nil
	State.Changed:Connect(function(d: any)
		if d and d.CanTrade ~= lastCanTrade then
			lastCanTrade = d.CanTrade
			renderList()
		end
		if picker.Visible then
			renderedSig = ""
			renderTrade()
		end
	end)
	State.Notify:Connect(function(kind: string, data: { [string]: any })
		if kind == "TradeRequest" and type(data.FromUserId) == "number" then
			showRequest(data.FromUserId, tostring(data.FromName or "Someone"))
		end
	end)
	task.spawn(function()
		while true do
			local left = State.TradeCountdown()
			if countdownLabel then
				countdownLabel.Text = if left then "Trading in " .. math.ceil(left) .. "..." else ""
			end
			task.wait(0.1)
		end
	end)
end

return Trade
