--!strict
-- Quests panel: daily login streak (with countdown to the next claim), the 3
-- daily quests with progress bars, and playtime gifts for this session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local Format = require("../Core/Format")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Toasts = require("../UI/Toasts")
local RewardText = require("../UI/RewardText")

local Quests = {}

local win: Windows.Window
local content: ScrollingFrame
local tab = "Daily"
local selectTab: (string) -> ()
local tickers: { () -> () } = {}
local renderedSig = ""
local questBars: { [number]: (number, string?) -> () } = {}

local QUEST_TEXT: { [string]: string } = {
	Break = "Break %s things",
	Hatch = "Hatch %s eggs",
	Expedition = "Finish %s expeditions",
	Coins = "Earn %s coins",
	Craft = "Craft %s pets",
}

local QUEST_ICON: { [string]: string } = {
	Break = "💥",
	Hatch = Theme.Icons.Egg,
	Expedition = Theme.Icons.Expeditions,
	Coins = Theme.Icons.Coins,
	Craft = Theme.Icons.Craft,
}

local function secondsToNextDay(): number
	local now = State.Now()
	return 86400 - (now % 86400)
end

local function claimed(res: { [string]: any }?)
	if res then
		Sounds.Play("Reward")
		local text = RewardText(if type(res.reward) == "table" then res.reward else nil)
		Toasts.Show(Theme.Icons.Gift .. " Claimed! " .. text, "good")
	end
end

local function renderDaily()
	local d = State.Data
	if not d then
		return
	end
	local daily = d.Daily
	local n = #Config.DailyRewards
	-- the streak continues only when the last claim was yesterday (UTC days)
	local today = math.floor(State.Now() / 86400)
	local nextDay = if not daily.CanClaim then daily.Streak elseif daily.LastDay >= today - 1 then daily.Streak + 1 else 1
	local highlight = ((math.max(1, nextDay) - 1) % n) + 1
	local top = Kit.box({ Size = UDim2.new(1, -10, 0, 50), LayoutOrder = 1, Parent = content })
	Kit.fitLabel("🔥 Streak: " .. daily.Streak .. " day" .. (if daily.Streak == 1 then "" else "s"), 28, {
		Size = UDim2.fromScale(1, 1),
		Align = "Left",
		Parent = top,
	})
	local row = Kit.box({ Size = UDim2.new(1, -10, 0, 170), LayoutOrder = 2, Parent = content }, {
		Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center),
	})
	for i, r in Config.DailyRewards do
		local isNext = i == highlight
		local done = i < highlight or (i == highlight and not daily.CanClaim)
		local tile = Kit.panel({
			Size = UDim2.fromOffset(106, 160),
			LayoutOrder = i,
			BackgroundColor3 = if isNext and daily.CanClaim then Theme.Lighten(Theme.Colors.Good, 0.6) elseif done then Theme.Colors.PanelDark else Theme.Colors.Panel,
			StrokeColor = if isNext then Theme.Colors.Good else Theme.Colors.Stroke,
			Parent = row,
		})
		Kit.fitLabel("Day " .. i, 20, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 6), Parent = tile })
		Kit.fitLabel(if done then Theme.Icons.Equipped else Theme.Icons.Gift, 38, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 34), Parent = tile })
		Kit.fitLabel(RewardText(r :: any), 15, {
			Size = UDim2.new(1, -8, 0, 64),
			Position = UDim2.fromOffset(4, 88),
			Font = Theme.FontBody,
			Parent = tile,
		})
	end
	local bottom = Kit.box({ Size = UDim2.new(1, -10, 0, 80), LayoutOrder = 3, Parent = content })
	if daily.CanClaim then
		Kit.button(Theme.Icons.Gift .. " Claim Day " .. highlight, "Green", {
			Size = UDim2.fromOffset(300, 70),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = bottom,
		}, function()
			claimed(Remote.CallOnce("ClaimDaily"))
		end)
	else
		local l = Kit.fitLabel("", 24, { Size = UDim2.fromScale(1, 1), Color = Theme.Colors.TextDim, Parent = bottom })
		local function tick()
			l.Text = Theme.Icons.Clock .. " Next reward in " .. Format.time(secondsToNextDay())
		end
		tick()
		table.insert(tickers, tick)
	end
end

local function renderQuests()
	local d = State.Data
	if not d then
		return
	end
	local l = Kit.fitLabel("", 20, { Size = UDim2.new(1, -10, 0, 30), LayoutOrder = 0, Color = Theme.Colors.TextDim, Parent = content })
	local function tick()
		l.Text = Theme.Icons.Clock .. " New quests in " .. Format.time(secondsToNextDay())
	end
	tick()
	table.insert(tickers, tick)
	if #d.Quests == 0 then
		Kit.fitLabel("No quests right now.", 22, { Size = UDim2.new(1, -10, 0, 40), LayoutOrder = 1, Parent = content })
	end
	for i, q in d.Quests do
		local done = q.Progress >= q.Goal
		local row = Kit.panel({
			Size = UDim2.new(1, -10, 0, 100),
			LayoutOrder = i,
			BackgroundColor3 = if q.Claimed then Theme.Colors.PanelDark elseif done then Theme.Lighten(Theme.Colors.Good, 0.65) else Theme.Colors.Panel,
			Parent = content,
		})
		Kit.fitLabel(QUEST_ICON[q.Kind] or Theme.Icons.Quests, 40, { Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(10, 15), Parent = row })
		local fmt = QUEST_TEXT[q.Kind] or (q.Kind .. " %s")
		Kit.fitLabel(string.format(fmt, Format.num(q.Goal)), 24, {
			Size = UDim2.new(1, -360, 0, 34),
			Position = UDim2.fromOffset(86, 10),
			Align = "Left",
			Parent = row,
		})
		local bar, set = Kit.bar({ Size = UDim2.new(1, -360, 0, 28), Position = UDim2.fromOffset(86, 56) }, if done then Theme.Colors.Good else Theme.Colors.Info)
		bar.Parent = row
		set(q.Progress / math.max(1, q.Goal), Format.num(math.min(q.Progress, q.Goal)) .. " / " .. Format.num(q.Goal))
		questBars[i] = set
		local b = Kit.button(
			if q.Claimed then Theme.Icons.Equipped .. " Done" else "Claim " .. Theme.Icons.Gems .. q.Gems,
			if q.Claimed then "Grey" elseif done then "Green" else "White",
			{
				Size = UDim2.fromOffset(230, 66),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Parent = row,
			},
			function()
				claimed(Remote.CallOnce("ClaimQuest", i))
			end
		)
		if q.Claimed or not done then
			Kit.setButton(b, { Enabled = false })
		end
	end
end

local function renderGifts()
	local d = State.Data
	if not d then
		return
	end
	local grid = Kit.box({ Size = UDim2.new(1, -10, 0, 440), LayoutOrder = 1, Parent = content }, { Kit.grid(Vector2.new(250, 200), 12) })
	for i, gift in Config.PlaytimeGifts do
		local isClaimed = d.Playtime.Claimed[tostring(i)] == true
		local tile = Kit.panel({
			LayoutOrder = i,
			BackgroundColor3 = if isClaimed then Theme.Colors.PanelDark else Theme.Colors.Panel,
			Parent = grid,
		})
		Kit.fitLabel(if isClaimed then Theme.Icons.Equipped else Theme.Icons.Gift, 44, { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 8), Parent = tile })
		Kit.fitLabel(RewardText(gift :: any), 22, { Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 66), Parent = tile })
		local b = Kit.button("", "Green", {
			Size = UDim2.new(1, -24, 0, 58),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Parent = tile,
		}, function()
			claimed(Remote.CallOnce("ClaimPlaytime", i))
		end)
		local ready: boolean? = nil
		local function tick()
			if isClaimed then
				Kit.setButton(b, { Text = "Claimed", Enabled = false })
				return
			end
			local left = (gift.Minutes or 0) * 60 - State.SessionMinutes() * 60
			if left <= 0 then
				if ready ~= true then
					ready = true
					Kit.setButton(b, { Text = Theme.Icons.Gift .. " Claim!", Enabled = true, Tone = "Green" })
				end
			else
				ready = false
				Kit.setButton(b, { Text = Theme.Icons.Clock .. " " .. Format.time(left), Enabled = false })
			end
		end
		tick()
		table.insert(tickers, tick)
	end
end

local function render(force: boolean?)
	if not win.IsOpen then
		return
	end
	local d = State.Data
	if not d then
		return
	end
	local sig = tab .. tostring(d.Daily.CanClaim) .. d.Daily.Streak
	-- progress alone doesn't rebuild the list: bars are updated in place
	for _, q in d.Quests do
		sig ..= q.Kind .. q.Goal .. tostring(q.Progress >= q.Goal) .. tostring(q.Claimed)
	end
	for k in d.Playtime.Claimed do
		sig ..= k
	end
	if sig == renderedSig and not force then
		for i, set in questBars do
			local q = d.Quests[i]
			if q then
				set(q.Progress / math.max(1, q.Goal), Format.num(math.min(q.Progress, q.Goal)) .. " / " .. Format.num(q.Goal))
			end
		end
		return
	end
	renderedSig = sig
	table.clear(tickers)
	table.clear(questBars)
	Kit.clear(content)
	if tab == "Daily" then
		renderDaily()
	elseif tab == "Quests" then
		renderQuests()
	else
		renderGifts()
	end
end

function Quests.Init()
	win = Windows.Create("Quests", { Title = "Quests & Rewards", Icon = Theme.Icons.Quests, Color = Theme.Tones.Purple.Top })
	local _, sel = Kit.tabs(win.Body, { "Daily", "Quests", "Gifts" }, {
		Daily = "🔥 Daily",
		Quests = Theme.Icons.Quests .. " Quests",
		Gifts = Theme.Icons.Gift .. " Gifts",
	}, function(name: string)
		tab = name
		render(true)
	end)
	selectTab = sel
	content = Kit.scroll({
		Size = UDim2.new(1, 0, 1, -64),
		Position = UDim2.fromOffset(0, 64),
		Parent = win.Body,
	}, { Kit.list(Enum.FillDirection.Vertical, 10), Kit.pad(4, 8, 6, 4) })
	Windows.Register("Quests", function(which: string?)
		Windows.Show("Quests")
		if which then
			selectTab(which)
		else
			-- open on the tab with something to claim
			local d = State.Data
			local pick = tab
			if d then
				local questReady = false
				for _, q in d.Quests do
					if not q.Claimed and q.Progress >= q.Goal then
						questReady = true
					end
				end
				if d.Daily.CanClaim then
					pick = "Daily"
				elseif questReady then
					pick = "Quests"
				end
			end
			selectTab(pick)
		end
	end)
	State.Changed:Connect(function()
		render()
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

return Quests
