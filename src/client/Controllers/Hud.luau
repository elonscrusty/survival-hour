--!nonstrict
-- Match HUD: phase/timer, clan fire strip, health/lives/pack/pouches, hotbar,
-- ability cooldown, channel progress, death / revive / eliminated screens,
-- announcements, kill feed, fire alerts and the victory/defeat screen.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Products = require(Shared.Products)
local Powerups = require(Shared.Powerups)
local Net = require(Shared.Net)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")

local Hud = {}

local player = Players.LocalPlayer
local matchState = ReplicatedStorage:WaitForChild("MatchState") :: Folder
local gui: ScreenGui
local C = Theme.Colors

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Live Robux price (regional pricing aware). Cached per session only.
local priceCache: { [number]: string } = {}
function Hud.PriceText(key: string): string
	local p = Products.ByKey[key]
	if not p then
		return "?"
	end
	if p.ProductId == 0 then
		return if workspace:GetAttribute("DevEnabled") then "DEV (free sim)" else "Unavailable"
	end
	if priceCache[p.ProductId] then
		return priceCache[p.ProductId]
	end
	priceCache[p.ProductId] = "…"
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(p.ProductId, Enum.InfoType.Product)
		end)
		if not ok then
			-- Older engine builds only have the deprecated synchronous name.
			ok, info = pcall(function()
				return (MarketplaceService :: any):GetProductInfo(p.ProductId, Enum.InfoType.Product)
			end)
		end
		if ok and info and info.PriceInRobux then
			priceCache[p.ProductId] = "R$ " .. tostring(info.PriceInRobux)
		else
			priceCache[p.ProductId] = "R$ ?"
		end
		State.Emit("PricesUpdated", true)
	end)
	return priceCache[p.ProductId]
end

-- Top: phase + clan strip -----------------------------------------------------------------------

local phaseLabel: TextLabel
local phasePill: Frame
local teamBadges: { Frame } = {}

local function buildTop()
	phasePill = UI.panel({ Name = "Phase", Size = UDim2.fromOffset(250, 40), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Parent = gui })
	phaseLabel = UI.text("", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.FontBlack, TextSize = 22, Parent = phasePill })
	local strip = UI.new("Frame", { Name = "Teams", BackgroundTransparency = 1, Size = UDim2.fromOffset(4 * 92, 34), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50), Parent = gui }, { UI.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center) })
	for t, def in Config.Teams do
		local b = UI.panel({ Name = "T" .. t, LayoutOrder = t, Size = UDim2.fromOffset(88, 32), Parent = strip })
		UI.text(def.Symbol, { Name = "Sym", Size = UDim2.fromOffset(24, 32), Position = UDim2.fromOffset(4, 0), TextColor3 = def.Color, Font = Theme.FontBlack, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
		UI.text("", { Name = "Info", Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(28, 0), TextSize = 14, Font = Theme.FontBold, Parent = b })
		teamBadges[t] = b
	end
end

local function refreshTop()
	local phase = matchState:GetAttribute("Phase") or "Idle"
	local ends = matchState:GetAttribute("PhaseEnds") or 0
	local day = matchState:GetAttribute("Day") or 0
	local remaining = math.max(0, ends - now())
	if phase == "Day" then
		phaseLabel.Text = "☀  DAY " .. day .. "   " .. UI.fmtTime(remaining)
		phaseLabel.TextColor3 = C.Day
	elseif phase == "Night" then
		phaseLabel.Text = "🌙  NIGHT " .. day .. "   " .. UI.fmtTime(remaining)
		phaseLabel.TextColor3 = C.Night
	elseif phase == "Intro" then
		phaseLabel.Text = "GET READY   " .. UI.fmtTime(remaining)
		phaseLabel.TextColor3 = C.Accent
	elseif phase == "Loading" then
		phaseLabel.Text = "PREPARING THE FOREST…"
		phaseLabel.TextColor3 = C.TextDim
	elseif phase == "Ended" then
		phaseLabel.Text = "MATCH OVER"
		phaseLabel.TextColor3 = C.Accent
	else
		phaseLabel.Text = ""
	end
	local myTeam = player:GetAttribute("Team")
	for t, b in teamBadges do
		local fire = matchState:GetAttribute("Fire" .. t)
		local standing = matchState:GetAttribute("Standing" .. t)
		local alive = matchState:GetAttribute("Alive" .. t) or 0
		local info = b:FindFirstChild("Info") :: TextLabel
		if not standing then
			info.Text = "✖ OUT"
			info.TextColor3 = C.TextDim
			b.BackgroundTransparency = 0.5
		else
			info.Text = (if fire then "🔥" else "✖🔥") .. " " .. alive .. "♟"
			info.TextColor3 = if fire then C.Text else C.Bad
			b.BackgroundTransparency = 0.12
		end
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if t == myTeam then Config.Teams[t].Color else C.Stroke
			stroke.Thickness = if t == myTeam then 3 else 1.5
		end
	end
end

-- Bottom-left: vitals ------------------------------------------------------------------------------

local healthSet: (number, string?) -> ()
local livesLabel: TextLabel
local packLabel: TextLabel
local pouchLabel: TextLabel
local vitals: Frame

local function buildVitals()
	vitals = UI.panel({ Name = "Vitals", Size = UDim2.fromOffset(270, 112), Position = UDim2.new(0, 12, 1, -124), Parent = gui }, { UI.padding(8) })
	local hb
	hb, healthSet = UI.bar({ Size = UDim2.new(1, 0, 0, 24), Parent = vitals }, Color3.fromRGB(200, 70, 60))
	hb.Name = "Health"
	livesLabel = UI.text("", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 22), Font = Theme.FontBold, TextSize = 16, Parent = vitals })
	packLabel = UI.text("", { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 20), TextSize = 15, Parent = vitals })
	pouchLabel = UI.text("", { Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 20), TextSize = 15, TextColor3 = C.TextDim, Parent = vitals })
end

local function refreshVitals()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		healthSet(hum.Health / math.max(1, hum.MaxHealth), string.format("♥ %d / %d", math.ceil(hum.Health), hum.MaxHealth))
	end
	local free = player:GetAttribute("FreeRespawns") or 0
	local team = player:GetAttribute("Team") or 0
	local fire = matchState:GetAttribute("Fire" .. team)
	local flames = string.rep("🔥", free) .. string.rep("·", math.max(0, Config.Lives.FreeRespawns - free))
	if fire then
		livesLabel.Text = "Respawns: " .. flames .. "  (" .. free .. " left)"
		livesLabel.TextColor3 = C.Text
	else
		livesLabel.Text = "✖ FIRE OUT — no respawns"
		livesLabel.TextColor3 = C.Bad
	end
	local inv = State.Get("Inventory")
	if inv then
		local total = 0
		for _, n in inv.Resources do
			total += n
		end
		packLabel.Text = string.format("Pack %d/%d   ", total, inv.Capacity) .. (if total >= inv.Capacity then "FULL" else "")
		packLabel.TextColor3 = if total >= inv.Capacity then C.Warn else C.Text
		pouchLabel.Text = string.format("✚ Bandages %d (H)   🏹 %d   • %d", inv.Bandages, inv.Ammo.Arrow or 0, inv.Ammo.Bullet or 0)
	end
end

-- Hotbar -------------------------------------------------------------------------------------------

local hotbar: Frame
local SLOTS = { { "Fists", "`" }, { "Weapon1", "1" }, { "Weapon2", "2" }, { "Tool", "3" }, { "Utility", "4" } }

local function buildHotbar()
	hotbar = UI.new("Frame", { Name = "Hotbar", BackgroundTransparency = 1, Size = UDim2.fromOffset(5 * 70, 78), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Parent = gui }, { UI.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom) })
end

local function refreshHotbar()
	local inv = State.Get("Inventory")
	UI.clear(hotbar)
	if not inv then
		return
	end
	for i, s in SLOTS do
		local slot, key = s[1], s[2]
		local stack = if slot == "Fists" then { Id = "Fists" } else inv.Slots[slot]
		local equipped = (inv.Equipped == false and slot == "Fists") or inv.Equipped == slot
		local btn = UI.new("TextButton", {
			Name = slot,
			LayoutOrder = i,
			Size = UDim2.fromOffset(64, 72),
			BackgroundColor3 = if equipped then C.AccentDark else C.Panel,
			BackgroundTransparency = if equipped then 0.05 else 0.2,
			Text = "",
			AutoButtonColor = false,
			Parent = hotbar,
		}, { UI.corner(UDim.new(0, 10)), UI.stroke(if equipped then C.Accent else C.Stroke, if equipped then 2.5 else 1.2, 0.1) })
		if stack then
			local def = Items[stack.Id]
			local ic = UI.icon(def.Icon.Glyph, def.Icon.Color, 40, def.Icon.Shape)
			ic.Position = UDim2.fromOffset(12, 6)
			ic.Parent = btn
			UI.text(def.Name, { Position = UDim2.fromOffset(2, 48), Size = UDim2.new(1, -4, 0, 14), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.FontBold, Parent = btn })
			if stack.Durability and def.Durability then
				local bar = UI.new("Frame", { Position = UDim2.new(0, 6, 1, -6), Size = UDim2.new((stack.Durability / def.Durability) * 0.83, 0, 0, 3), BackgroundColor3 = if stack.Durability / def.Durability < 0.25 then C.Bad else C.Good, BorderSizePixel = 0, Parent = btn })
				bar.Name = "Durability"
			end
			if stack.Id == "Canteen" then
				UI.text(if stack.Filled then "FULL" else "EMPTY", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = if stack.Filled then C.Info else C.TextDim, Font = Theme.FontBlack, Parent = btn })
			end
		else
			UI.text("empty", { Position = UDim2.fromOffset(0, 26), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.TextDim, Parent = btn })
		end
		if not State.Get("IsTouch") then
			UI.text(key, { Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(16, 14), TextSize = 12, TextColor3 = C.Accent, Font = Theme.FontBlack, Parent = btn })
		end
		btn.Activated:Connect(function()
			if slot == "Fists" then
				Net.Event("Equip"):FireServer(nil)
			elseif stack then
				Net.Event("Equip"):FireServer(slot)
			end
		end)
	end
end

-- Ability ---------------------------------------------------------------------------------------------

local abilityFrame: Frame
local abilityCd: Frame
local abilityText: TextLabel

local function buildAbility()
	abilityFrame = UI.panel({ Name = "Ability", Size = UDim2.fromOffset(150, 60), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 186, 1, -14), Parent = gui })
	abilityCd = UI.new("Frame", { Name = "Cooldown", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = abilityFrame }, { UI.corner() })
	abilityText = UI.text("", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.FontBold, TextSize = 14, Parent = abilityFrame })
	abilityText.ZIndex = 3
end

local function refreshAbility()
	local ab = State.Get("Ability")
	if not ab or not ab.Id then
		abilityFrame.Visible = false
		return
	end
	local def = Powerups.ById[ab.Id]
	abilityFrame.Visible = player:GetAttribute("LifeState") == "Alive"
	local remaining = math.max(0, (ab.CooldownEnds or 0) - now())
	local lv = def.Levels[ab.Level]
	local total = lv and lv.Ability.Cooldown or 1
	abilityCd.Size = UDim2.fromScale(1, math.clamp(remaining / total, 0, 1))
	local key = if State.Get("IsTouch") then "" else "[X] "
	if ab.Id == "Sharpshooter" then
		abilityText.Text = def.Glyph .. " " .. def.AbilityName .. (if remaining > 0 then string.format("  %.0fs", remaining) else " READY (auto)")
	else
		abilityText.Text = key .. def.Glyph .. " " .. def.AbilityName .. (if remaining > 0 then string.format("\n%.0fs", remaining) else "\nREADY")
	end
	local stroke = abilityFrame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if remaining > 0 then C.Stroke else Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
	end
	local touchBtn = State.Get("TouchAbilityButton")
	if touchBtn then
		touchBtn.BackgroundTransparency = if remaining > 0 then 0.6 else 0.25
	end
end

-- Channel progress ------------------------------------------------------------------------------------

local channel: { Id: number, Label: string, Duration: number, Start: number, Hold: boolean }? = nil
local channelFrame: Frame
local channelSet: (number, string?) -> ()
local channelHint: TextLabel

local function buildChannel()
	channelFrame = UI.panel({ Name = "Channel", Size = UDim2.fromOffset(360, 64), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -170), Visible = false, Parent = gui }, { UI.padding(8) })
	local bar
	bar, channelSet = UI.bar({ Size = UDim2.new(1, 0, 0, 26), Parent = channelFrame }, C.Accent)
	bar.Name = "Bar"
	channelHint = UI.text("", { Position = UDim2.fromOffset(0, 30), TextSize = 13, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = channelFrame })
end

-- Center overlays -----------------------------------------------------------------------------------------

local announce: TextLabel
local sub: TextLabel

local function buildAnnounce()
	announce = UI.text("", { Name = "Announce", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0.8, 0, 0, 60), TextSize = 42, Font = Theme.FontBlack, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, TextTransparency = 1, Parent = gui })
	sub = UI.text("", { Name = "Sub", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 44), Size = UDim2.new(0.8, 0, 0, 28), TextSize = 20, Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, TextTransparency = 1, Parent = gui })
end

function Hud.Announce(text: string, subtext: string?, color: Color3?, hold: number?)
	announce.Text = text
	announce.TextColor3 = color or C.Text
	sub.Text = subtext or ""
	announce.TextTransparency = 0
	sub.TextTransparency = 0
	announce.TextStrokeTransparency = 0.3
	local token = {}
	Hud._announceToken = token
	task.delay(hold or 3, function()
		if Hud._announceToken ~= token then
			return
		end
		local info = TweenInfo.new(0.6)
		TweenService:Create(announce, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(sub, info, { TextTransparency = 1 }):Play()
	end)
end
Hud._announceToken = nil :: any

-- Kill feed -------------------------------------------------------------------------------------------------

local feed: Frame
local function buildFeed()
	feed = UI.new("Frame", { Name = "Feed", BackgroundTransparency = 1, Size = UDim2.fromOffset(330, 200), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 262), Parent = gui }, { UI.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Right) })
end

local function teamTag(t: number?): string
	local def = t and Config.Teams[t]
	return if def then def.Symbol .. " " else ""
end

local function pushFeed(text: string, color: Color3?)
	local row = UI.panel({ Size = UDim2.fromOffset(330, 26), LayoutOrder = math.floor(os.clock() * 100), Parent = feed })
	UI.text(text, { Size = UDim2.fromScale(1, 1), TextSize = 14, Font = Theme.FontBold, TextColor3 = color or C.Text, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	local pad = UI.padding(4)
	pad.Parent = row
	task.delay(7, function()
		row:Destroy()
	end)
	local rows = {}
	for _, c in feed:GetChildren() do
		if c:IsA("Frame") then
			table.insert(rows, c)
		end
	end
	if #rows > 6 then
		table.sort(rows, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		rows[1]:Destroy()
	end
end

-- Death / revive / eliminated ------------------------------------------------------------------------------

local deathFrame: Frame
local deathTitle: TextLabel
local deathSub: TextLabel
local reviveBtn: TextButton
local teamRevive: Frame
local pendingRevives: { [number]: { Name: string, Ends: number } } = {}

local function buildDeath()
	deathFrame = UI.panel({ Name = "Death", Size = UDim2.fromOffset(420, 150), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Visible = false, Parent = gui }, { UI.padding(12) })
	deathTitle = UI.text("", { Size = UDim2.new(1, 0, 0, 34), TextSize = 28, Font = Theme.FontBlack, TextXAlignment = Enum.TextXAlignment.Center, Parent = deathFrame })
	deathSub = UI.text("", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 40), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.TextDim, Parent = deathFrame })
	reviveBtn = UI.button("", { Size = UDim2.new(1, 0, 0, 46), Position = UDim2.new(0, 0, 1, -46), BackgroundColor3 = Color3.fromRGB(40, 110, 60), Visible = false, Parent = deathFrame }, function()
		Net.Event("RequestRevive"):FireServer(player.UserId)
	end)
	teamRevive = UI.new("Frame", { Name = "TeamRevive", BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 200), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.45, 0), Parent = gui }, { UI.list(Enum.FillDirection.Vertical, 6) })
end

local function refreshDeath()
	local st = player:GetAttribute("LifeState")
	local inMatch = player:GetAttribute("InMatch")
	if not inMatch or st == "Alive" or st == "Lobby" or matchState:GetAttribute("Phase") == "Ended" then
		deathFrame.Visible = false
	else
		deathFrame.Visible = true
		if st == "Respawning" then
			deathTitle.Text = "YOU DIED"
			deathTitle.TextColor3 = C.Bad
			deathSub.Text = "Respawning at your campfire… (" .. (player:GetAttribute("FreeRespawns") or 0) .. " free respawns left)"
			reviveBtn.Visible = false
		elseif st == "AwaitingRevive" then
			local left = math.max(0, (player:GetAttribute("WindowEnds") or 0) - now())
			local tier = player:GetAttribute("ReviveTier") or 1
			deathTitle.Text = "OUT OF RESPAWNS  " .. UI.fmtTime(left)
			deathTitle.TextColor3 = C.Warn
			local lock = player:GetAttribute("ReviveLockBy") or 0
			local profile = State.Get("Profile")
			local credit = false
			if profile and profile.Credits and profile.Credits.Revive then
				for t = tier, Config.Lives.MaxReviveTier do
					if (profile.Credits.Revive[tostring(t)] or 0) > 0 then
						credit = true
					end
				end
			end
			if lock ~= 0 and lock ~= player.UserId then
				deathSub.Text = "A teammate is buying your revive…"
			else
				deathSub.Text = "Your fire still burns. Revive now or teammates can pay for you. Revive #" .. tier .. " this match."
			end
			reviveBtn.Visible = true
			reviveBtn.Text = if credit then "Revive (use credit)" else "Revive  —  " .. Hud.PriceText(Products.ReviveKey(tier))
		else
			deathTitle.Text = "ELIMINATED"
			deathTitle.TextColor3 = C.Bad
			deathSub.Text = "Spectating. Stay until the end: if your clan wins, you still earn the win reward."
			reviveBtn.Visible = false
		end
	end
	-- Teammate revive cards (created once, text refreshed; buttons aren't rebuilt mid-tap)
	for uid, info in pendingRevives do
		local mate = Players:GetPlayerByUserId(uid)
		local card = teamRevive:FindFirstChild("R" .. uid) :: Frame?
		if not mate or mate:GetAttribute("LifeState") ~= "AwaitingRevive" then
			pendingRevives[uid] = nil
			if card then
				card:Destroy()
			end
		else
			if not card then
				local newCard = UI.panel({ Name = "R" .. uid, Size = UDim2.fromOffset(300, 62), Parent = teamRevive }, { UI.padding(6) })
				UI.text("", { Name = "Title", Size = UDim2.new(1, 0, 0, 20), TextSize = 14, Font = Theme.FontBold, Parent = newCard })
				UI.button("", { Name = "Pay", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 22), TextSize = 14, BackgroundColor3 = Color3.fromRGB(40, 110, 60), Parent = newCard }, function()
					Net.Event("RequestRevive"):FireServer(uid)
				end)
				card = newCard
			end
			local c = card :: Frame
			local left = math.max(0, (mate:GetAttribute("WindowEnds") or 0) - now())
			local tier = mate:GetAttribute("ReviveTier") or 1
			local lock = mate:GetAttribute("ReviveLockBy") or 0
			;(c:FindFirstChild("Title") :: TextLabel).Text = info.Name .. " needs a revive  " .. UI.fmtTime(left)
			;(c:FindFirstChild("Pay") :: TextButton).Text = if lock ~= 0 and lock ~= player.UserId then "Someone is paying…" else "Pay revive  " .. Hud.PriceText(Products.ReviveKey(tier))
		end
	end
end

-- End screen ------------------------------------------------------------------------------------------------

local function showEnd(data: any)
	local won = data.Won
	local winner = data.Winner
	local frame = UI.panel({ Name = "EndScreen", Size = UDim2.fromOffset(460, 230), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Parent = gui }, { UI.padding(16) })
	UI.text(if won then "VICTORY" else "DEFEAT", { Size = UDim2.new(1, 0, 0, 56), TextSize = 50, Font = Theme.FontBlack, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = if won then C.Accent else C.Bad, Parent = frame })
	local wdef = Config.Teams[winner]
	UI.text(if wdef then (wdef.Symbol .. " " .. wdef.Name .. " clan kept their fire burning!") else "No clan survived.", { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 26), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	if (data.Diamonds or 0) > 0 then
		UI.text("+" .. data.Diamonds .. " ◆ diamonds", { Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 34), TextSize = 28, Font = Theme.FontBlack, TextColor3 = C.Diamond, TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	end
	UI.text("Returning to the lobby shortly…", { Position = UDim2.new(0, 0, 1, -24), TextSize = 14, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	task.delay(Config.Match.EndScreenLength + 2, function()
		frame:Destroy()
	end)
end

-- Events ---------------------------------------------------------------------------------------------------------

local function onMatchEvent(ev: any)
	local d = ev.Data or {}
	local name = ev.Name
	if name == "Phase" then
		if d.Phase == "Night" then
			Hud.Announce("🌙 NIGHTFALL", "Wildlife roams. Enemy fires can be put out.", C.Night)
		else
			Hud.Announce("☀ DAY " .. tostring(d.Day), "Gather, build, and watch for the care package.", C.Day)
		end
	elseif name == "Intro" then
		Hud.Announce("SURVIVAL HOUR", "Protect your fire. Last clan with a flame wins.", C.Accent, 5)
	elseif name == "Loading" then
		Hud.Announce("PREPARING THE FOREST…", "Building a new forest layout", C.TextDim, 6)
	elseif name == "FireOut" then
		local def = Config.Teams[d.Team]
		local mine = d.Team == player:GetAttribute("Team")
		Hud.Announce((def and def.Symbol or "") .. " " .. (def and def.Name or "?") .. " FIRE EXTINGUISHED", if mine then "No more respawns for your clan!" elseif d.By then "Put out by " .. d.By else nil, if mine then C.Bad else C.Warn, 4)
		pushFeed("✖🔥 " .. teamTag(d.Team) .. (def and def.Name or "") .. " fire is out", C.Warn)
	elseif name == "Death" then
		local killer = if d.Killer then teamTag(d.KillerTeam) .. d.Killer else tostring(d.Cause)
		pushFeed(killer .. "  ⚔  " .. teamTag(d.VictimTeam) .. d.Victim .. (if d.Eliminated then "  [OUT]" else ""), if d.Eliminated then C.Bad else C.Text)
	elseif name == "TeamEliminated" then
		local def = Config.Teams[d.Team]
		pushFeed(teamTag(d.Team) .. (def and def.Name or "") .. " clan eliminated", C.Bad)
	elseif name == "TeammateNeedsRevive" then
		pendingRevives[d.UserId] = { Name = d.Name, Ends = d.Ends }
	elseif name == "FireUnderAttack" then
		Hud.Announce("⚠ YOUR FIRE IS BEING DOUSED!", "Get back to camp — hit the raider to stop the pour", C.Bad, 3)
	elseif name == "StorageRaided" then
		Hud.Announce("⚠ STORAGE RAID", "An enemy is stealing from your storage", C.Warn, 2.5)
	elseif name == "CampRevealed" then
		local def = Config.Teams[d.Team]
		pushFeed("🧭 " .. tostring(d.By) .. " found the " .. (def and def.Name or "?") .. " camp", C.Info)
	elseif name == "CarePackage" then
		Hud.Announce("✚ CARE PACKAGE INCOMING", (if d.Source == "Paid" and d.Buyer then "Called in by " .. d.Buyer .. " — " else "") .. "Marked on your map", C.Accent, 3)
	elseif name == "PackageCalled" then
		pushFeed("✚ " .. tostring(d.Buyer) .. " called a care package" .. (if d.AtDawn then " (arrives at dawn)" else ""), C.Accent)
	elseif name == "CarePackageOpened" then
		pushFeed("✚ " .. teamTag(d.ByTeam) .. tostring(d.By) .. " opened a care package", C.TextDim)
	elseif name == "MatchEnded" then
		showEnd(d)
	elseif name == "Eliminated" then
		Hud.Announce("ELIMINATED", if d.Cause == "FireOut" then "Your fire went out while you were down." else "Spectating your clan.", C.Bad, 4)
	elseif name == "ReturnedToLobby" then
		pendingRevives = {}
	end
end

local closingId = 0
local function onChannel(s: any)
	if s.Kind then
		channel = { Id = s.Id, Label = s.Label, Duration = s.Duration, Start = os.clock(), Hold = s.Hold }
		channelFrame.Visible = true
		channelHint.Text = (if s.Hold then "Keep holding · " else "") .. "Taking damage or moving away cancels"
		channelHint.TextColor3 = C.TextDim
	elseif channel and s.Id == channel.Id then
		channel = nil -- stop the live progress update
		closingId = s.Id
		if s.Cancelled then
			channelHint.Text = "✖ " .. tostring(s.Reason)
			channelHint.TextColor3 = C.Bad
			channelSet(0, "Cancelled")
		else
			channelSet(1, "Done ✓")
		end
		local id = s.Id
		task.delay(if s.Cancelled then 1.2 else 0.4, function()
			if channel == nil and closingId == id then
				channelFrame.Visible = false
			end
		end)
	end
end

function Hud.Start()
	gui = UI.new("ScreenGui", { Name = "Hud", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 2, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	UI.new("UIScale", { Parent = gui, Name = "Scale" })
	buildTop()
	buildVitals()
	buildHotbar()
	buildAbility()
	buildChannel()
	buildAnnounce()
	buildFeed()
	buildDeath()

	State.On("Inventory", refreshHotbar)
	State.On("IsTouch", refreshHotbar)
	State.On("MatchEvent", onMatchEvent)
	State.On("Channel", onChannel)
	State.On("PricesUpdated", refreshDeath)

	local scale = gui:FindFirstChild("Scale") :: UIScale
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(vp.X / 1100, vp.Y / 620), 0.62, 1.2)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- Match servers: shown while waiting for every matched player to arrive.
	local waiting = UI.panel({ Name = "Waiting", Size = UDim2.fromOffset(460, 110), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Visible = false, Parent = gui }, { UI.padding(14) })
	UI.text("SURVIVAL HOUR", { Size = UDim2.new(1, 0, 0, 36), TextSize = 30, Font = Theme.FontBlack, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, Parent = waiting })
	UI.text("Waiting for every clan member to arrive, then building a new forest…", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 40), TextSize = 15, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = waiting })

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local inMatch = player:GetAttribute("InMatch") == true
		waiting.Visible = not inMatch and workspace:GetAttribute("ServerMode") == "Match"
		for _, c in gui:GetChildren() do
			if c:IsA("GuiObject") and c.Name ~= "Announce" and c.Name ~= "Sub" and c.Name ~= "EndScreen" then
				if c.Name == "Death" or c.Name == "Channel" or c.Name == "Ability" or c.Name == "Waiting" then
					continue
				end
				c.Visible = inMatch
			end
		end
		if channel and channelFrame.Visible then
			local frac = (os.clock() - channel.Start) / channel.Duration
			channelSet(frac, channel.Label .. string.format("  %.1fs", math.max(0, channel.Duration - (os.clock() - channel.Start))))
		end
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		if inMatch then
			refreshTop()
			refreshVitals()
			refreshAbility()
			refreshDeath()
		else
			deathFrame.Visible = false
			abilityFrame.Visible = false
			teamRevive.Visible = false
		end
		teamRevive.Visible = inMatch
	end)
end

return Hud
