--!nonstrict
-- Lobby interface: ready button + matchmaking status, party management,
-- Classes and Power-ups (Diamonds), the cosmetic Locker (Coins), Profile &
-- Rewards (level, daily / weekly bonus, leaderboards), the Coin shop, and a
-- how-to-play page.

local Players = game:GetService("Players")
local AvatarEditorService = game:GetService("AvatarEditorService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Classes)
local Perks = require(Shared.Perks)
local Cosmetics = require(Shared.Cosmetics)
local Progression = require(Shared.Progression)
local Products = require(Shared.Products)
local Config = require(Shared.Config)
local Changelog = require(Shared.Changelog)
local Net = require(Shared.Net)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")
local Panels = require("./Panels")
local ClassHall = require("./ClassHall")
local Hud = require("./Hud")
local Buttons = require("../UI/Buttons")
local Icons = require("../UI/Icons")
local Season = require("./Season")
local Seasons = require(Shared.Logic.Seasons)

local Lobby = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local gui: ScreenGui
local setReady: (string, string?, string?) -> () = function() end
local statusLabel: TextLabel
local partyStrip: Frame
local diamondsLabel: TextLabel
local levelLabel: TextLabel
local streakLabel: TextLabel? = nil
local coinPill: TextLabel
local diamondPill: TextLabel
local xpSet: (number, string?) -> () = function() end
local shownCoins, shownDiamonds = -1, -1
local seasonBanner: Frame? = nil
local seasonLabel: TextLabel? = nil

-- Counts a currency label up/down to its new value (short, never blocks input).
local function countTo(label: TextLabel, from: number, to: number)
	if from < 0 or from == to then
		label.Text = tostring(to)
		return
	end
	local v = Instance.new("NumberValue")
	v.Value = from
	v.Changed:Connect(function(x)
		label.Text = tostring(math.floor(x + 0.5))
	end)
	local tw = TweenService:Create(v, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = to })
	tw.Completed:Once(function()
		label.Text = tostring(to)
		v:Destroy()
	end)
	tw:Play()
	-- a small flash so gains are noticed
	local up = to > from
	label.TextColor3 = if up then Color3.fromRGB(160, 255, 140) else Color3.fromRGB(255, 140, 120)
	task.delay(0.7, function()
		label.TextColor3 = if label == coinPill then Color3.fromRGB(242, 193, 78) else C.Diamond
	end)
end
local partyBody: ScrollingFrame
local perkBody: ScrollingFrame
local lockerBody: ScrollingFrame
local profileBody: ScrollingFrame
local shopBody: ScrollingFrame
local lockerType = "Outfit"
local titleUp = false -- lobby HUD stays hidden behind the title screen
local refreshVis: () -> () = function() end
local helpBody: ScrollingFrame

local function send(action: string, extra: { [string]: any }?)
	local req = extra and table.clone(extra) or {}
	req.Action = action
	Net.Event("LobbyAction"):FireServer(req)
end

-- HUD ---------------------------------------------------------------------------------------

local function renderHud()
	local lobby = State.Get("Lobby")
	local profile = State.Get("Profile")
	if profile then
		local cls = Classes.ById[profile.Class]
		local perk = profile.Perk and Perks.ById[profile.Perk]
		diamondsLabel.Text = string.format("%s %s · %s", if cls then cls.Glyph else "", if cls then cls.Name else "?", if perk then perk.Glyph .. " " .. perk.Name else "no power-up")
		levelLabel.Text = "Lv " .. tostring(profile.Level or 1)
		-- win streak: a small flame on the profile card at 2+ (prestige only)
		local streak = (profile.Records and profile.Records.WinStreak) or 0
		if streakLabel then
			streakLabel.Text = if streak >= 2 then "🔥 " .. streak .. " win streak" else ""
		end
		if (profile.LevelNeed or 0) > 0 then
			xpSet(profile.LevelInto / profile.LevelNeed, string.format("%d / %d XP", profile.LevelInto, profile.LevelNeed))
		else
			xpSet(1, "MAX LEVEL")
		end
		countTo(coinPill, shownCoins, profile.Coins or 0)
		countTo(diamondPill, shownDiamonds, profile.Diamonds or 0)
		shownCoins, shownDiamonds = profile.Coins or 0, profile.Diamonds or 0
	end
	if not lobby then
		return
	end
	if lobby.Queued then
		setReady("READY UP", "Searching… tap to cancel", "Normal")
	elseif lobby.Ready then
		setReady("READY UP ✓", "Waiting for your party", "Normal")
	else
		setReady("READY UP", nil, "Normal")
	end
	local q = lobby.Queue or {}
	if lobby.Queued then
		statusLabel.Text = string.format("In queue %s · %d searching · matches start at %d players (fills to %d)%s", UI.fmtTime(lobby.QueuedFor or 0), q.Searching or 0, lobby.MinPlayers, lobby.MaxPlayers, if q.Mode == "Local" then " · STUDIO LOCAL MODE" else "")
	else
		statusLabel.Text = "Ready up here or stand in the glowing ring. Parties of up to 4 stay together."
	end
	UI.clear(partyStrip)
	for i, m in lobby.Members do
		UI.text((if m.Ready then "✓ " else "○ ") .. m.Name .. (if m.Leader then " ★" else ""), {
			AutoLocalize = false,
			LayoutOrder = i,
			Size = UDim2.fromOffset(150, 24),
			TextSize = 14,
			Font = Theme.FontBold,
			TextColor3 = if m.Ready then C.Good else C.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = partyStrip,
		})
	end
end

-- Seasonal event banner (Config.Seasons): "🎃 Halloween event: 9 days left". Tapping it opens
-- the Locker, where the limited items are.
local function renderSeason()
	local season = Season.Current()
	if not seasonBanner or not seasonLabel then
		return
	end
	seasonBanner.Visible = season ~= nil
	if season then
		local left = Seasons.LeftText(Seasons.SecondsLeft(season, workspace:GetServerTimeNow()))
		seasonLabel.Text = string.format("%s %s event: %s · limited items in the Locker", season.Glyph or "★", season.Name, left)
		seasonLabel.TextColor3 = season.Accent or C.Warn
	end
end

-- Party panel ------------------------------------------------------------------------------------

local function renderParty()
	UI.clear(partyBody)
	local lobby = State.Get("Lobby")
	if not lobby then
		return
	end
	UI.text("Your party (" .. #lobby.Members .. "/4)", { LayoutOrder = 1, TextSize = 18, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = partyBody })
	for i, m in lobby.Members do
		local r = UI.new("Frame", { LayoutOrder = 1 + i, Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = partyBody }, { UI.corner(UDim.new(0, 8)) })
		UI.text((if m.Leader then "★ " else "") .. m.Name .. (if m.Ready then "   ✓ ready" else "   not ready"), { AutoLocalize = false, Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -120, 0, 24), TextSize = 16, Parent = r })
		if lobby.IsLeader and m.UserId ~= player.UserId then
			Buttons.action("👤 Kick", { Size = UDim2.fromOffset(100, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Tone = "Red", Parent = r }, function()
				send("Kick", { UserId = m.UserId })
			end)
		end
	end
	if #lobby.Members > 1 then
		Buttons.action("⮌ Leave party", { LayoutOrder = 10, Size = UDim2.new(1, -8, 0, 44), Tone = "Neutral", Parent = partyBody }, function()
			send("Leave")
		end)
	end
	UI.text("Invite players in this lobby", { LayoutOrder = 20, TextSize = 18, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = partyBody })
	if not lobby.IsLeader then
		UI.text("Only the party leader can invite.", { LayoutOrder = 21, TextSize = 13, TextColor3 = C.TextDim, Parent = partyBody })
	end
	local order = 22
	for _, pl in lobby.Players do
		local inMine = false
		for _, m in lobby.Members do
			if m.UserId == pl.UserId then
				inMine = true
			end
		end
		if not inMine then
			local r = UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = partyBody }, { UI.corner(UDim.new(0, 8)) })
			order += 1
			UI.text(pl.Name .. (if pl.InParty then "  (in a party)" else ""), { AutoLocalize = false, Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -120, 0, 22), TextSize = 15, Parent = r })
			if lobby.IsLeader and #lobby.Members < 4 then
				Buttons.action("+ Invite", { Size = UDim2.fromOffset(110, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Tone = "Neutral", Parent = r }, function()
					send("Invite", { UserId = pl.UserId })
				end)
			end
		end
	end
	UI.text("Tip: friends can join your server from the Roblox friends list, then accept your invite here.", { LayoutOrder = 999, TextSize = 12, TextColor3 = C.TextDim, Parent = partyBody })
end

-- Shared bits ------------------------------------------------------------------------------------

local function rgb(c: { number }?): Color3
	return if c then Color3.fromRGB(c[1], c[2], c[3]) else C.Text
end


-- Locker tab icons (Shared/IconIds), by cosmetic type.
local LOCKER_TAB_ICON = {
	Outfit = "LockerTab_Outfits", BackpackSkin = "LockerTab_BackpackSkins", CampfireSkin = "LockerTab_CampfireSkins",
	WorkbenchSkin = "LockerTab_WorkbenchSkins", StorageSkin = "LockerTab_StorageSkins", Nameplate = "LockerTab_Nameplates",
	Title = "LockerTab_Titles", Emote = "LockerTab_Emotes", EliminationFx = "LockerTab_EliminationEffects",
}

local function card(parent: Instance, order: number, height: number, color: Color3, selected: boolean): Frame
	return UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = parent }, { UI.corner(UDim.new(0, 10)), UI.stroke(if selected then color else C.Stroke, if selected then 3 else 1, 0.2), UI.padding(10) })
end

local function buttonRow(parent: Instance): Frame
	return UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0.5, 0, 0, 44), Parent = parent }, { UI.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right) })
end


-- Power-ups panel ------------------------------------------------------------------------------------

local function renderPerks()
	UI.clear(perkBody)
	local profile = State.Get("Profile")
	if not profile then
		UI.text("Loading your profile…", { Parent = perkBody })
		return
	end
	UI.text(string.format("◆ %d Diamonds · equip ONE power-up before a match (no swapping mid-match)", profile.Diamonds), { LayoutOrder = 0, TextSize = 13, TextColor3 = C.Diamond, Parent = perkBody })
	for i, def in Perks.List do
		local owned = profile.OwnedPerks[def.Id] == true
		local color = rgb(def.Color)
		local sel = profile.Perk == def.Id
		local cd = card(perkBody, i, 84, color, sel)
		local ic = UI.icon(def.Glyph, color, 48, "Round", "Perk_" .. def.Id)
		ic.Parent = cd
		UI.text(def.Name .. (if owned then "" else "   🔒 " .. def.Price .. " ◆"), { Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -60, 0, 22), TextSize = 17, Font = Theme.FontBlack, TextColor3 = color, Parent = cd })
		UI.text(def.Text, { Position = UDim2.fromOffset(60, 24), Size = UDim2.new(0.62, -60, 0, 36), TextWrapped = true, TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top, Parent = cd })
		local row = buttonRow(cd)
		if owned then
			Buttons.action(if sel then "Equipped" else "Equip", { Size = UDim2.fromOffset(130, 40), Tone = "Green", State = if sel then "Selected" else nil, Parent = row }, function()
				send("EquipPerk", { Id = if sel then nil else def.Id })
			end)
		else
			Buttons.action("Unlock", { Size = UDim2.fromOffset(150, 40), Tone = "Green", Price = { Kind = "Diamonds", Amount = def.Price }, State = if profile.Diamonds >= def.Price then nil else "Disabled", Parent = row }, function()
				send("BuyPerk", { Id = def.Id })
			end)
		end
	end
end

-- Locker (cosmetics) --------------------------------------------------------------------------------------

local TYPE_LABEL = {
	Outfit = "Outfits", ToolSkin = "Tool skins", BackpackSkin = "Backpacks", CampfireSkin = "Campfire", WorkbenchSkin = "Workbench",
	StorageSkin = "Storage", Nameplate = "Nameplates", Title = "Titles", Emote = "Emotes", EliminationFx = "Elim. effects", VictoryPose = "Victory poses",
}

local TYPE_GLYPH = {
	Outfit = "👕", ToolSkin = "🔨", BackpackSkin = "🎒", CampfireSkin = "🔥", WorkbenchSkin = "⚒", StorageSkin = "📦",
	Nameplate = "🏷", Title = "👑", Emote = "🙌", EliminationFx = "💀", VictoryPose = "🏆",
}

local function renderLocker()
	UI.clear(lockerBody)
	local profile = State.Get("Profile")
	if not profile then
		UI.text("Loading your profile…", { Parent = lockerBody })
		return
	end
	UI.text(string.format("🪙 %d Coins · cosmetics are purely visual — they never change stats", profile.Coins or 0), { LayoutOrder = 0, TextSize = 14, TextColor3 = C.Accent, Parent = lockerBody })
	local tabs = UI.new("Frame", { LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 190), Parent = lockerBody }, { UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(104, 56), CellPadding = UDim2.fromOffset(6, 6) }) })
	for _, typ in Cosmetics.Types do
		Buttons.tab(TYPE_LABEL[typ] or typ, TYPE_GLYPH[typ], typ == lockerType, { Size = UDim2.fromOffset(104, 56), Icon = LOCKER_TAB_ICON[typ], Parent = tabs }, function()
			lockerType = typ
			renderLocker()
		end)
	end
	local order = 10
	local wearing = profile.Wearing[lockerType]
	if wearing then
		Buttons.action("Remove " .. (TYPE_LABEL[lockerType] or lockerType):lower(), { LayoutOrder = 2, Size = UDim2.new(1, -8, 0, 36), Tone = "Neutral", Parent = lockerBody }, function()
			send("WearCosmetic", { Type = lockerType, Id = nil })
		end)
	end
	local season = Season.Current()
	for _, def in Cosmetics.List do
		local owned = profile.Cosmetics[def.Id] == true
		-- limited-time items: shown while their season runs, or once owned
		local limited = def.Season ~= nil
		local inSeason = limited and season ~= nil and season.Id == def.Season
		if def.Type == lockerType and (not limited or inSeason or owned) then
			order += 1
			local rarity = rgb(Cosmetics.RarityColor[def.Rarity])
			local sel = wearing == def.Id
			local cd = card(lockerBody, order, if limited then 78 else 64, rarity, sel)
			local sw = UI.new("Frame", { Size = UDim2.fromOffset(42, 42), BackgroundColor3 = if def.Color then rgb(def.Color) else C.PanelLighter, Parent = cd }, { UI.corner(UDim.new(0, 8)) })
			if not Icons.Apply(sw, "Cosmetic_" .. def.Id) and def.Type == "Title" then
				Icons.Apply(sw, "Title_Scroll") -- titles share one scroll icon
			end
			if def.Text then
				UI.text("✎", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = sw })
			end
			UI.text(def.Name .. (if def.Text then '  "' .. def.Text .. '"' else ""), { Position = UDim2.fromOffset(52, 0), Size = UDim2.new(0.6, -52, 0, 22), TextSize = 15, Font = Theme.FontBold, Parent = cd })
			local how = if def.Level then " · level " .. def.Level .. " reward" elseif def.Mastery then " · " .. def.Mastery.Label elseif def.Price > 0 then " · " .. def.Price .. " Coins" else " · bundle"
			if inSeason and def.Mastery and not owned then
				local have = (profile.SeasonStats or {})[def.Mastery.Stat] or 0
				how ..= string.format(" (%d/%d)", math.min(have, def.Mastery.Need), def.Mastery.Need)
			end
			UI.text(def.Rarity .. how, { Position = UDim2.fromOffset(52, 22), Size = UDim2.new(0.6, -52, 0, 18), TextSize = 12, TextColor3 = rarity, Parent = cd })
			if limited then
				local tag = if inSeason and not owned then string.format("%s LIMITED · %s", season.Glyph or "★", Seasons.LeftText(Seasons.SecondsLeft(season, workspace:GetServerTimeNow()))) else "LIMITED EDITION"
				UI.text(tag, { Position = UDim2.fromOffset(52, 40), Size = UDim2.new(0.6, -52, 0, 14), TextSize = 11, Font = Theme.FontBold, TextColor3 = if season and season.Accent then season.Accent else C.Warn, Parent = cd })
			end
			local row = buttonRow(cd)
			if owned then
				if def.Type == "Emote" then
					Buttons.action("▶ Play", { Size = UDim2.fromOffset(90, 40), Tone = "Neutral", Parent = row }, function()
						send("Emote", { Id = def.Id })
					end)
				end
				Buttons.action(if sel then "Wearing" else "Wear", { Size = UDim2.fromOffset(120, 40), Tone = "Green", State = if sel then "Selected" else nil, Parent = row }, function()
					send("WearCosmetic", { Type = def.Type, Id = if sel then nil else def.Id })
				end)
			elseif def.Price > 0 then
				Buttons.action("Buy", { Size = UDim2.fromOffset(150, 40), Tone = "Gold", Price = { Kind = "Coins", Amount = def.Price }, State = if (profile.Coins or 0) >= def.Price then nil else "Disabled", Parent = row }, function()
					send("BuyCosmetic", { Id = def.Id })
				end)
			else
				UI.text(if def.Level then "🔒 Lv " .. def.Level elseif def.Mastery then "🔒 earn" else "🔒 bundle", { Size = UDim2.fromOffset(110, 40), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.TextDim, Parent = row })
			end
		end
	end
end

-- Profile & rewards ------------------------------------------------------------------------------------------

local function renderProfile()
	UI.clear(profileBody)
	local profile = State.Get("Profile")
	if not profile then
		UI.text("Loading your profile…", { Parent = profileBody })
		return
	end
	UI.text("Level " .. tostring(profile.Level or 1), { LayoutOrder = 1, TextSize = 24, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = profileBody })
	local barHolder = UI.new("Frame", { LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 26), Parent = profileBody })
	local _, set = UI.bar({ Size = UDim2.fromScale(1, 1), Parent = barHolder }, C.Accent)
	if (profile.LevelNeed or 0) > 0 then
		set(profile.LevelInto / profile.LevelNeed, string.format("%d / %d XP to level %d", profile.LevelInto, profile.LevelNeed, (profile.Level or 1) + 1))
	else
		set(1, "MAX LEVEL")
	end
	UI.text(string.format("Matches %d · Wins %d · Kills %d · Eliminations %d · ◆ %d · 🪙 %d", profile.Matches or 0, profile.Wins or 0, profile.Kills or 0, profile.Eliminations or 0, profile.Diamonds or 0, profile.Coins or 0), { LayoutOrder = 3, TextSize = 14, TextColor3 = C.TextDim, Parent = profileBody })
	UI.text("Every 5 levels: +" .. Progression.LevelCoins .. " Coins · every 10 levels: +" .. Progression.MilestoneDiamonds .. " ◆ · titles & nameplates at 5 / 10 / 25 / 50 / 75 / 100", { LayoutOrder = 4, Size = UDim2.new(1, -8, 0, 32), TextWrapped = true, TextSize = 12, TextColor3 = C.TextDim, Parent = profileBody })
	-- Daily
	local daily = profile.Daily or {}
	local dcard = card(profileBody, 10, 64, C.Accent, daily.CanClaim == true)
	UI.text("Daily bonus", { Size = UDim2.new(0.6, 0, 0, 22), TextSize = 16, Font = Theme.FontBold, Parent = dcard })
	UI.text(string.format("Streak %d · +%d Coins (grows each day in a row, max 150)", daily.Streak or 0, daily.Amount or 50), { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(0.6, 0, 0, 20), TextSize = 12, TextColor3 = C.TextDim, Parent = dcard })
	Buttons.action(if daily.CanClaim then "🎁 Claim +" .. (daily.Amount or 50) else "Claimed", { Size = UDim2.fromOffset(150, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Tone = "Green", State = if daily.CanClaim then nil else "Selected", Parent = dcard }, function()
		send("ClaimDaily")
	end)
	-- Weekly
	local wk = profile.Weekly or {}
	local wcard = card(profileBody, 11, 64, C.Accent, wk.CanClaim == true)
	UI.text("Weekly bonus", { Size = UDim2.new(0.6, 0, 0, 22), TextSize = 16, Font = Theme.FontBold, Parent = wcard })
	UI.text(string.format("Matches %d/%d · wins %d → +%d Coins", wk.Matches or 0, wk.Need or 3, wk.Wins or 0, wk.Amount or 300), { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(0.6, 0, 0, 20), TextSize = 12, TextColor3 = C.TextDim, Parent = wcard })
	Buttons.action(if wk.Claimed then "Claimed" elseif wk.CanClaim then "🏆 Claim" else "Keep playing", { Size = UDim2.fromOffset(150, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Tone = if wk.CanClaim then "Gold" else "Green", State = if wk.Claimed then "Selected" elseif wk.CanClaim then nil else "Disabled", Parent = wcard }, function()
		send("ClaimWeekly")
	end)
	-- Challenges (daily set of 3, weekly set of 2; same for everyone, coins only)
	local challenges = profile.Challenges or {}
	if #challenges > 0 then
		UI.text("Challenges", { LayoutOrder = 12, TextSize = 18, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = profileBody })
		for i, ch in challenges do
			local done = ch.Progress >= ch.Need
			local row = card(profileBody, 12 + i, 56, if ch.Weekly then C.Dev else C.Accent, done and not ch.Claimed)
			UI.text((if ch.Weekly then "WEEKLY · " else "DAILY · ") .. ch.Text, { Size = UDim2.new(1, -170, 0, 20), TextSize = 14, Font = Theme.FontBold, Parent = row })
			local barHolder2 = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -170, 0, 16), Parent = row })
			local _, setBar = UI.bar({ Size = UDim2.fromScale(1, 1), Parent = barHolder2 }, if ch.Weekly then C.Dev else C.Accent)
			setBar(ch.Progress / math.max(1, ch.Need), string.format("%d / %d", ch.Progress, ch.Need))
			Buttons.action(if ch.Claimed then "Claimed" elseif done then "Claim +" .. ch.Coins else "+" .. ch.Coins .. " 🪙", { Size = UDim2.fromOffset(150, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Tone = if done then "Gold" else "Neutral", State = if ch.Claimed then "Selected" elseif done then nil else "Disabled", Parent = row }, function()
				send("ClaimChallenge", { Id = ch.Id })
			end)
		end
	end
	-- Records (lifetime; kept off the match HUD)
	local rec = profile.Records
	if rec then
		UI.text("Records", { LayoutOrder = 18, TextSize = 18, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = profileBody })
		local winRate = if (profile.Matches or 0) > 0 then math.floor((profile.Wins or 0) / profile.Matches * 100 + 0.5) else 0
		local lines = {
			string.format("Win rate %d%% · best win streak %d (current %d)", winRate, rec.BestStreak or 0, rec.WinStreak or 0),
			string.format("Nights survived %d · places discovered %d · items crafted %d", rec.Nights or 0, rec.Pois or 0, rec.Crafts or 0),
			string.format("Wildlife hunted %d (bears %d) · resources gathered %d", rec.Animals or 0, rec.Bears or 0, rec.Resources or 0),
			string.format("Campfires put out %d · storages breached %d", rec.FiresOut or 0, rec.Breaches or 0),
		}
		UI.text(table.concat(lines, "\n"), { LayoutOrder = 19, Size = UDim2.new(1, -8, 0, 76), TextSize = 13, TextColor3 = C.TextDim, TextYAlignment = Enum.TextYAlignment.Top, Parent = profileBody })
	end
	-- Leaderboards
	local lobby = State.Get("Lobby")
	local boards = lobby and lobby.Boards or {}
	UI.text("Leaderboards", { LayoutOrder = 20, TextSize = 18, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = profileBody })
	local cols = UI.new("Frame", { LayoutOrder = 21, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 230), Parent = profileBody }, { UI.list(Enum.FillDirection.Horizontal, 8) })
	for _, spec in { { "Wins", "Most wins" }, { "XP", "Highest level" } } do
		local col = UI.new("Frame", { Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = cols }, { UI.corner(UDim.new(0, 8)), UI.padding(8), UI.list(Enum.FillDirection.Vertical, 2) })
		UI.text(spec[2], { Size = UDim2.new(1, 0, 0, 20), TextSize = 14, Font = Theme.FontBold, Parent = col })
		local list = boards[spec[1]] or {}
		if #list == 0 then
			UI.text("No entries yet (live servers only).", { Size = UDim2.new(1, 0, 0, 18), TextSize = 12, TextColor3 = C.TextDim, Parent = col })
		end
		for rank, e in list do
			local v = if spec[1] == "XP" then "Lv " .. (Progression.LevelFromXP(e.Value)) else tostring(e.Value)
			UI.text(string.format("%d. %s — %s", rank, e.Name, v), { AutoLocalize = false, Size = UDim2.new(1, 0, 0, 18), TextSize = 12, TextColor3 = if e.UserId == player.UserId then C.Accent else C.Text, Parent = col })
		end
	end
end

-- Shop panel ------------------------------------------------------------------------------------------

local function renderShop()
	UI.clear(shopBody)
	UI.text("Robux only buys Coins and cosmetics — never gameplay power. Diamonds (classes & power-ups) are earned by playing.", { LayoutOrder = 0, Size = UDim2.new(1, -8, 0, 34), TextWrapped = true, TextSize = 13, TextColor3 = C.TextDim, Parent = shopBody })
	local season = Season.Current()
	if season then
		UI.text(string.format("%s %s event: limited cosmetics are in the LOCKER for Coins until the event ends.", season.Glyph or "★", season.Name), { LayoutOrder = 0, Size = UDim2.new(1, -8, 0, 20), TextSize = 13, Font = Theme.FontBold, TextColor3 = season.Accent or C.Warn, Parent = shopBody })
	end
	local order = 0
	for _, p in Products.List do
		if Products.OnSale(p.Key) then
			order += 1
			local isBundle = p.Kind == "Bundle"
			local r = UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 70), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = shopBody }, { UI.corner(UDim.new(0, 8)), UI.padding(8) })
			local ic = UI.icon(if isBundle then "🎁" else "🪙", if isBundle then C.Dev else C.Accent, 52, "Round", "Product_" .. p.Key)
			ic.Parent = r
			UI.text(p.Title, { Position = UDim2.fromOffset(64, 4), Size = UDim2.new(1, -240, 0, 26), TextSize = 19, Font = Theme.FontBlack, TextColor3 = if isBundle then C.Dev else C.Accent, Parent = r })
			if isBundle then
				local names = {}
				local items: { string } = Cosmetics.Bundles[p.Bundle or ""] or {}
				for _, id in items do
					local d = Cosmetics.ById[id]
					table.insert(names, if d then d.Name else id)
				end
				UI.text(table.concat(names, " · "), { Position = UDim2.fromOffset(64, 32), Size = UDim2.new(1, -240, 0, 18), TextSize = 12, TextColor3 = C.TextDim, Parent = r })
			end
			Buttons.action("Buy " .. Hud.PriceText(p.Key), { Size = UDim2.fromOffset(170, 48), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Tone = "Green", Parent = r }, function()
				send("BuyRobux", { Key = p.Key })
			end)
		end
	end
	UI.text("Prices are shown by Roblox for your region. Purchases are only granted after Roblox confirms them. Bundle items you already own are refunded as Coins.", { LayoutOrder = 100, Size = UDim2.new(1, -8, 0, 34), TextWrapped = true, TextSize = 12, TextColor3 = C.TextDim, Parent = shopBody })
end

-- Settings panel -----------------------------------------------------------------------------------------

local settingsBody: ScrollingFrame

local function renderSettings()
	UI.clear(settingsBody)
	local profile = State.Get("Profile")
	local st = (profile and profile.Settings) or {}
	local function toggle(order: number, key: string, title: string, sub: string)
		local on = st[key] == true
		local row = UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 60), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = settingsBody }, { UI.corner(UDim.new(0, 8)), UI.padding(8) })
		UI.text(title, { Size = UDim2.new(0.7, 0, 0, 22), TextSize = 16, Font = Theme.FontBold, Parent = row })
		UI.text(sub, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(0.7, 0, 0, 18), TextSize = 12, TextColor3 = C.TextDim, Parent = row })
		Buttons.action(if on then "On" else "Off", { Size = UDim2.fromOffset(90, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Tone = if on then "Green" else "Neutral", State = if on then "Selected" else nil, Parent = row }, function()
			Net.Event("SetSetting"):FireServer(key, not on)
		end)
	end
	toggle(1, "ReduceMotion", "Reduce motion", "No camera punch, damage roll or sprint zoom")
	toggle(2, "ShowGuide", "Survival Guide", "Show the objective tracker in matches")
	toggle(3, "UiSounds", "Interface sounds", "Clicks and menu sounds")
	local vol = if type(st.Ambience) == "number" then st.Ambience else 0.8
	local row = UI.new("Frame", { LayoutOrder = 4, Size = UDim2.new(1, -8, 0, 60), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = settingsBody }, { UI.corner(UDim.new(0, 8)), UI.padding(8) })
	UI.text(string.format("Ambience volume · %d%%", math.floor(vol * 100 + 0.5)), { Size = UDim2.new(0.6, 0, 0, 22), TextSize = 16, Font = Theme.FontBold, Parent = row })
	local steps = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(250, 40), Parent = row }, { UI.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Right) })
	for _, v in { 0, 0.25, 0.5, 0.75, 1 } do
		Buttons.tab(tostring(math.floor(v * 100)), nil, math.abs(v - vol) < 0.01, { Size = UDim2.fromOffset(46, 36), Parent = steps }, function()
			Net.Event("SetSetting"):FireServer("Ambience", v)
		end)
	end
end

local HELP = {
	{ "Goal", "Solo survival. Every player has their own camp with a Campfire and a Tier I Workbench. PvP is on from the start. Be the last survivor." },
	{ "Day & night", "Day and night each last exactly 2 minutes. At each sunrise, everyone alive gets 15 s of protection (and can't deal damage). At night predators roam." },
	{ "Your fire", "While your fire burns you respawn (8 s, 12 s, 16 s, then 20 s). Feed it Wood (1 Wood = +2% fuel). At 0% it goes out for good and you're on your FINAL LIFE. Upgrade it (L2-L5) to burn longer and take longer to snuff." },
	{ "Snuffing", "Fires are protected during Nights 1-2. From Night 3, enemy fires can be snuffed day or night with a filled canteen: hold 8-20 s by fire level. Taking damage, moving or letting go cancels it." },
	{ "Progression", "Start with nothing. Gather sticks, loose stones, fibre and berries by hand, then craft a Crude Axe, Pickaxe and Spear. Small trees give 4 Wood, large trees 16 (Stone Axe). Upgrade your Workbench (Tiers I-V) with your pack + storage." },
	{ "Health & stamina", "Health 100, stamina 100 (sprint with Shift). There's no fast regen: bandages (+20), First Aid kits (+50) and Medkits (+100) take time and are interrupted by damage." },
	{ "Deaths", "Only materials drop, in one loot bag. You keep tools, weapons, armour, backpack and Workbench progress." },
	{ "Classes & power-ups", "Pick one class and one power-up in the lobby (Diamonds). They're locked for the whole match. They are sidegrades: faster chopping, more pack slots, better senses — never more damage or health." },
	{ "XP, Coins & Diamonds", "Earn XP and Coins by surviving nights, kills, snuffing fires, exploring, hunting, opening chests and placing top 3. Coins buy cosmetics. Diamonds come from wins (exactly 2) and every 10 levels." },
	{ "PC controls", "WASD move · Shift sprint · Click attack · Right-click aim/block · 1-5 slots · ` fists · Q swap · H bandage · I bag · C craft · B build · M map · E/F interact" },
	{ "Mobile", "Use the on-screen buttons: ATTACK, AIM/BLOCK, HEAL, SWAP and RUN. Tap the prompt cards to interact. BAG, CRAFT, BUILD and MAP are at the top right." },
}

local function renderHelp()
	UI.clear(helpBody)
	for i, h in HELP do
		UI.text(h[1], { LayoutOrder = i * 2, TextSize = 17, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = helpBody })
		UI.text(h[2], { LayoutOrder = i * 2 + 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 14, Parent = helpBody })
	end
end

-- What's new + favourite prompt ---------------------------------------------------------------------------

local newsBody: ScrollingFrame

local function renderNews()
	UI.clear(newsBody)
	local entry = Changelog[1]
	if not entry then
		return
	end
	UI.text("Version " .. entry.Version, { LayoutOrder = 0, TextSize = 17, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = newsBody })
	for i, line in entry.Lines do
		UI.text("• " .. line, { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, Parent = newsBody })
	end
end

-- Once per session, after the title screen: returning players see "What's new" when
-- Config.Version changed; players who have won once or played 3 matches are asked
-- once to favourite the game. Both are remembered in the profile settings.
local function lobbyPrompts()
	local profile = State.Get("Profile")
	while titleUp or not profile or profile.State == "Loading" do
		task.wait(1)
		profile = State.Get("Profile")
	end
	if not (profile.State == "Loaded" or profile.State == "Memory") or player:GetAttribute("InMatch") or workspace:GetAttribute("ServerMode") == "Match" then
		return
	end
	local st = profile.Settings or {}
	if Config.Dev.PreviewWhatsNew and RunService:IsStudio() then
		Panels.Open("News")
		return
	end
	if st.SeenVersion ~= Config.Version then
		Net.Event("SetSetting"):FireServer("SeenVersion", Config.Version)
		if (profile.Matches or 0) > 0 and Changelog[1] and Changelog[1].Version == Config.Version then
			Panels.Open("News")
			return -- one prompt per visit
		end
	end
	if st.FavAsked ~= true and ((profile.Wins or 0) >= 1 or (profile.Matches or 0) >= 3) then
		task.wait(4)
		if player:GetAttribute("InMatch") then
			return
		end
		Net.Event("SetSetting"):FireServer("FavAsked", true)
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end
end

-- Invites -------------------------------------------------------------------------------------------------

local function showInvite(d: any)
	local card = UI.panel({ Size = UDim2.fromOffset(340, 104), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Parent = gui }, { UI.padding(10) })
	UI.text(tostring(d.From) .. " invited you to their party", { Size = UDim2.new(1, 0, 0, 24), TextSize = 16, Font = Theme.FontBold, Parent = card })
	Buttons.action("✓ Accept", { Size = UDim2.new(0.48, 0, 0, 46), Position = UDim2.new(0, 0, 1, -46), Tone = "Green", Parent = card }, function()
		send("Accept", { PartyId = d.PartyId })
		card:Destroy()
	end)
	Buttons.action("✖ Decline", { Size = UDim2.new(0.48, 0, 0, 46), Position = UDim2.new(0.52, 0, 1, -46), Tone = "Red", Parent = card }, function()
		send("Decline", { PartyId = d.PartyId })
		card:Destroy()
	end)
	task.delay(60, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

-- Title screen: a slow camera orbit over the refuge fire at golden hour,
-- shown once per session in the lobby.
local function titleScreen()
	if workspace:GetAttribute("ServerMode") == "Match" or player:GetAttribute("InMatch") then
		return
	end
	-- coming straight back from a match: skip the title and go to the lobby
	local okTd, td = pcall(function()
		return game:GetService("TeleportService"):GetLocalPlayerTeleportData()
	end)
	if okTd and type(td) == "table" and td.ReturnFromMatch then
		return
	end
	local lobbyFolder = workspace:WaitForChild("Lobby", 20)
	local fire = lobbyFolder and lobbyFolder:WaitForChild("LobbyFire", 10) :: Model?
	if not fire then
		return
	end
	local center = fire:GetPivot().Position
	-- make sure the ground round the fire has streamed in before we look at it
	pcall(function()
		player:RequestStreamAroundAsync(center, 10)
	end)
	local cam = workspace.CurrentCamera
	titleUp = true
	refreshVis()
	local overlay = UI.new("ScreenGui", { Name = "TitleScreen", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Parent = player:WaitForChild("PlayerGui") })
	local shade = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = overlay }, {
		UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 0.1) }) }),
	})
	local title = UI.text("SURVIVAL HOUR", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.new(0.9, 0, 0, 90), TextSize = 78, Font = Theme.FontBlack, TextColor3 = C.Accent, TextStrokeTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, Parent = shade })
	local tag = UI.text("Keep your fire burning. Outlast every other survivor.", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.36, 64), Size = UDim2.new(0.9, 0, 0, 30), TextSize = 22, Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, Parent = shade })
	local done = false
	local _btn, setBtn = Buttons.primary("ENTER THE REFUGE", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromOffset(440, 80), Parent = shade }, function()
		done = true
	end)
	TweenService:Create(title, TweenInfo.new(1.6), { TextTransparency = 0 }):Play()
	TweenService:Create(tag, TweenInfo.new(2.4), { TextTransparency = 0 }):Play()
	local t0 = os.clock()
	cam.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("SurvivalHourTitle", Enum.RenderPriority.Camera.Value + 2, function()
		local a = (os.clock() - t0) * 0.08
		local eye = center + Vector3.new(math.cos(a) * 46, 18 + math.sin(a * 0.7) * 3, math.sin(a) * 46)
		cam.CFrame = CFrame.lookAt(eye, center + Vector3.new(0, 4, 0))
	end)
	-- Leave on the button, when a match starts, or after 45 s.
	local deadline = os.clock() + 45
	while not done and os.clock() < deadline and not player:GetAttribute("InMatch") do
		task.wait(0.1)
	end
	-- Don't hand the camera back until the character exists (the server may
	-- still be starting up), otherwise the view looks frozen.
	setBtn("ENTER THE REFUGE", "Loading the forest…", "Disabled")
	local waitUntil = os.clock() + 60
	local hum: Humanoid? = nil
	while os.clock() < waitUntil do
		local char = player.Character
		hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and char:FindFirstChild("HumanoidRootPart") then
			break
		end
		task.wait(0.2)
	end
	RunService:UnbindFromRenderStep("SurvivalHourTitle")
	cam.CameraType = Enum.CameraType.Custom
	if hum then
		cam.CameraSubject = hum
	end
	TweenService:Create(shade, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	for _, d in shade:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			TweenService:Create(d, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end
	titleUp = false
	refreshVis()
	task.delay(0.7, function()
		overlay:Destroy()
	end)
end

function Lobby.Start()
	titleUp = workspace:GetAttribute("ServerMode") ~= "Match" and not player:GetAttribute("InMatch")
	task.spawn(function()
		local ok, err = pcall(titleScreen)
		if not ok then
			warn("[Lobby] title screen:", err)
		end
		titleUp = false -- whatever happened, give the lobby UI back and the camera
		refreshVis()
		RunService:UnbindFromRenderStep("SurvivalHourTitle")
		if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		end
	end)
	gui = UI.new("ScreenGui", { Name = "LobbyHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3, Parent = player:WaitForChild("PlayerGui") })
	local scale = UI.new("UIScale", { Parent = gui })
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(vp.X / 1000, vp.Y / 600), 0.65, 1.2) * Theme.UiScale
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- Top: profile card (level badge, name, title, XP bar) + animated currency pills.
	-- Top centre: name plate in the middle, Coins and Diamonds to its right.
	-- Top centre, no plates: name, level + class and a thin XP line, then Coins and Diamonds
	-- as icon + number. Text is outlined so it reads over the world.
	local function outlined(props: { [string]: any }): { [string]: any }
		props.TextColor3 = props.TextColor3 or C.ForestText
		props.TextStrokeColor3 = C.ForestStroke
		props.TextStrokeTransparency = 0.25
		props.TextWrapped = false
		return props
	end
	local card = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(420, 66), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -120, 0, 6), Parent = gui })
	UI.text(player.DisplayName, outlined({ AutoLocalize = false, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.6, 0, 0, 30), TextSize = 28, Font = Theme.FontBlack, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card }))
	levelLabel = UI.text("1", outlined({ Name = "Level", Position = UDim2.new(0.6, 6, 0, 4), Size = UDim2.new(0.2, 0, 0, 24), TextSize = 22, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = card }))
	streakLabel = UI.text("", outlined({ Position = UDim2.new(0.6, 0, 0, 4), Size = UDim2.new(0.4, -34, 0, 24), TextSize = 15, Font = Theme.FontBold, TextColor3 = C.Warn, TextXAlignment = Enum.TextXAlignment.Right, Parent = card }))
	diamondsLabel = UI.text("", outlined({ Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, -34, 0, 18), TextSize = 16, Font = Theme.FontBold, TextColor3 = C.Accent, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card }))
	local xpHolder = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 53), Size = UDim2.new(1, -34, 0, 11), Parent = card })
	local gear = UI.new("TextButton", { Text = "⚙", Font = Theme.FontBlack, TextSize = 26, TextColor3 = C.ForestText, TextStrokeColor3 = C.ForestStroke, TextStrokeTransparency = 0.25, BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.fromOffset(32, 32), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2), Parent = card })
	gear.Activated:Connect(function()
		Panels.Toggle("Settings")
	end)
	local _xpBar
	_xpBar, xpSet = UI.bar({ Size = UDim2.fromScale(1, 1), Parent = xpHolder }, C.Accent)
	local function pill(x: number, glyph: string, color: Color3, icon: string): TextLabel
		local f = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 34), Position = UDim2.new(0.5, x, 0, 8), Parent = gui })
		Icons.Apply(UI.text(glyph, outlined({ Size = UDim2.fromOffset(32, 32), TextSize = 24, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, Parent = f })), icon)
		return UI.text("0", outlined({ Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -38, 1, 0), TextSize = 22, Font = Theme.FontBlack, TextColor3 = color, Parent = f }))
	end
	coinPill = pill(104, "●", Color3.fromRGB(242, 193, 78), "Currency_Coins")
	diamondPill = pill(258, "◆", C.Diamond, "Currency_Diamonds")
	local banner = UI.panel({ Size = UDim2.fromOffset(360, 30), Position = UDim2.new(0.5, 104, 0, 46), Visible = false, Parent = gui })
	seasonBanner = banner
	seasonLabel = UI.text("", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextSize = 13, Font = Theme.FontBold, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = banner })
	local bannerHit = UI.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = banner })
	bannerHit.Activated:Connect(function()
		Panels.Open("Locker")
	end)
	workspace:GetAttributeChangedSignal("Season"):Connect(function()
		renderSeason()
		if Panels.IsOpen("Locker") then
			renderLocker()
		end
	end)
	task.spawn(function()
		while banner.Parent do
			renderSeason()
			task.wait(30)
		end
	end)

	-- Bottom centre: the big READY UP plate, status and party strip.
	local bottom = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(460, 140), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Parent = gui })
	partyStrip = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = bottom }, { UI.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center) })
	statusLabel = UI.text("", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 20), TextSize = 13, TextColor3 = C.Text, TextStrokeTransparency = 0.5, TextXAlignment = Enum.TextXAlignment.Center, Parent = bottom })
	local readyPlate, setReadyFn = Buttons.primary("READY UP", { Size = UDim2.new(1, 0, 0, 84), Position = UDim2.fromOffset(0, 50), Parent = bottom }, function()
		local lobby = State.Get("Lobby")
		if lobby and (lobby.Ready or lobby.Queued) then
			send("Ready", { Value = false })
		else
			send("Ready", { Value = true })
		end
	end)
	setReady = setReadyFn
	-- New players: the READY UP plate breathes (green glow) until their first match.
	task.spawn(function()
		local on = false
		while readyPlate.Parent do
			task.wait(0.8)
			local prof = State.Get("Profile")
			local lobby = State.Get("Lobby")
			local newbie = prof ~= nil and (prof.Matches or 0) == 0 and not (lobby and (lobby.Queued or lobby.Ready))
			on = newbie and not on
			if readyPlate:GetAttribute("Hover") ~= on and not readyPlate:GetAttribute("Down") then
				readyPlate:SetAttribute("Hover", if on then true else nil)
				Buttons.refresh(readyPlate)
			end
		end
	end)

	-- Left: the menu, icon + title rows with no plates (hover brightens and nudges).
	local nav = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 8 * 50), Position = UDim2.fromOffset(12, 96), Parent = gui }, {
		UI.list(Enum.FillDirection.Vertical, 4),
	})
	local TILES = {
		{ "Party", "PARTY", "👥", "Party" },
		{ "Classes", "CLASS", "🏠", "Class" },
		{ "Perks", "POWER-UP", "⚡", "PowerUp" },
		{ "Locker", "LOCKER", "🎒", "Locker" },
		{ "Profile", "PROFILE", "👤", "Profile" },
		{ "LobbyShop", "SHOP", "🛒", "Shop" },
		{ "Help", "HOW TO PLAY", "❓", "HowToPlay" },
		{ "LobbyShop", "BUY COINS", "🪙", "BuyCoins" },
	}
	for i, spec in TILES do
		local row = UI.new("TextButton", { Text = "", BackgroundTransparency = 1, AutoButtonColor = false, LayoutOrder = i, Size = UDim2.fromOffset(220, 46), Parent = nav })
		local ic = UI.text(spec[3], outlined({ Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(0, 2), TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Parent = row }))
		Icons.Apply(ic, "Lobby_" .. spec[4])
		local label = UI.text(spec[2], outlined({ Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -50, 1, 0), TextSize = 21, Font = Theme.FontBlack, TextColor3 = if spec[2] == "BUY COINS" then Color3.fromRGB(255, 214, 110) else nil, Parent = row }))
		local base = label.TextColor3
		row.MouseEnter:Connect(function()
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Position = UDim2.fromOffset(54, 0)
		end)
		row.MouseLeave:Connect(function()
			label.TextColor3 = base
			label.Position = UDim2.fromOffset(50, 0)
		end)
		row.Activated:Connect(function()
			Panels.Toggle(spec[1])
		end)
	end

	partyBody = Panels.Create("Party", "PARTY", Vector2.new(560, 560), renderParty)
	UI.list(Enum.FillDirection.Vertical, 6).Parent = partyBody
	-- Classes: the full-screen Class Hall (Controllers/ClassHall)
	task.spawn(ClassHall.Build, send)
	perkBody = Panels.Create("Perks", "POWER-UPS", Vector2.new(640, 640), renderPerks)
	UI.list(Enum.FillDirection.Vertical, 6).Parent = perkBody
	lockerBody = Panels.Create("Locker", "LOCKER", Vector2.new(640, 640), renderLocker)
	UI.list(Enum.FillDirection.Vertical, 6).Parent = lockerBody
	profileBody = Panels.Create("Profile", "PROFILE & REWARDS", Vector2.new(620, 640), renderProfile)
	UI.list(Enum.FillDirection.Vertical, 6).Parent = profileBody
	shopBody = Panels.Create("LobbyShop", "TRADING POST", Vector2.new(600, 520), renderShop)
	settingsBody = Panels.Create("Settings", "SETTINGS", Vector2.new(560, 380), renderSettings)
	UI.list(Enum.FillDirection.Vertical, 8).Parent = settingsBody
	UI.list(Enum.FillDirection.Vertical, 8).Parent = shopBody
	helpBody = Panels.Create("Help", "HOW TO PLAY", Vector2.new(640, 600), renderHelp)
	UI.list(Enum.FillDirection.Vertical, 4).Parent = helpBody
	newsBody = Panels.Create("News", "WHAT'S NEW", Vector2.new(520, 360), renderNews)
	UI.list(Enum.FillDirection.Vertical, 6).Parent = newsBody
	task.spawn(lobbyPrompts)

	State.On("Lobby", function()
		renderHud()
		if Panels.IsOpen("Party") then
			renderParty()
		end
	end)
	local RENDER = { Classes = ClassHall.Render, Perks = renderPerks, Locker = renderLocker, Profile = renderProfile, LobbyShop = renderShop, Settings = renderSettings }
	State.On("Profile", function()
		renderHud()
		for name, fn in RENDER do
			if Panels.IsOpen(name) then
				fn()
			end
		end
	end)
	State.On("PricesUpdated", function()
		if Panels.IsOpen("LobbyShop") then
			renderShop()
		end
	end)
	State.On("MatchEvent", function(ev)
		if ev.Name == "PartyInvite" then
			showInvite(ev.Data)
		elseif ev.Name == "OpenStation" then
			local st = ev.Data.Station
			Panels.Open(if st == "Shop" then "LobbyShop" elseif st == "Powerups" or st == "Classes" then "Classes" elseif st == "Locker" then "Locker" elseif st == "Profile" then "Profile" else "Party")
		end
	end)
	local function vis()
		gui.Enabled = not titleUp and not player:GetAttribute("InMatch") and workspace:GetAttribute("ServerMode") ~= "Match"
	end
	refreshVis = vis
	player:GetAttributeChangedSignal("InMatch"):Connect(vis)
	vis()
end

return Lobby
