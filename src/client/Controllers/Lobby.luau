--!nonstrict
-- Lobby interface: ready button + matchmaking status, party management,
-- powerup shrine (unlock / upgrade / equip / challenge progress), diamond shop,
-- and a how-to-play page.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Powerups = require(Shared.Powerups)
local Products = require(Shared.Products)
local Net = require(Shared.Net)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")
local Panels = require("./Panels")
local Hud = require("./Hud")

local Lobby = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local gui: ScreenGui
local readyBtn: TextButton
local statusLabel: TextLabel
local partyStrip: Frame
local diamondsLabel: TextLabel
local partyBody: ScrollingFrame
local powerBody: ScrollingFrame
local shopBody: ScrollingFrame
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
		local eq = profile.Equipped and Powerups.ById[profile.Equipped]
		diamondsLabel.Text = string.format("◆ %d     %s", profile.Diamonds, if eq then (eq.Glyph .. " " .. eq.Name .. " Lv" .. (profile.Owned[profile.Equipped] or 1)) else "No powerup equipped")
	end
	if not lobby then
		return
	end
	readyBtn.Text = if lobby.Queued then "SEARCHING…  (tap to cancel)" elseif lobby.Ready then "READY ✓  (waiting for party)" else "READY UP"
	readyBtn.BackgroundColor3 = if lobby.Queued then Color3.fromRGB(60, 90, 140) elseif lobby.Ready then Color3.fromRGB(50, 120, 70) else C.AccentDark
	local q = lobby.Queue or {}
	if lobby.Queued then
		statusLabel.Text = string.format("In queue %s · %d searching · matches start at %d players (fills to %d)%s", UI.fmtTime(lobby.QueuedFor or 0), q.Searching or 0, lobby.MinPlayers, lobby.MaxPlayers, if q.Mode == "Local" then " · STUDIO LOCAL MODE" else "")
	else
		statusLabel.Text = "Ready up here or stand in the glowing ring. Parties of up to 4 stay together."
	end
	UI.clear(partyStrip)
	for i, m in lobby.Members do
		UI.text((if m.Ready then "✓ " else "○ ") .. m.Name .. (if m.Leader then " ★" else ""), {
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
		UI.text((if m.Leader then "★ " else "") .. m.Name .. (if m.Ready then "   ✓ ready" else "   not ready"), { Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -120, 0, 24), TextSize = 16, Parent = r })
		if lobby.IsLeader and m.UserId ~= player.UserId then
			UI.button("Kick", { Size = UDim2.fromOffset(90, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), BackgroundColor3 = Color3.fromRGB(90, 40, 36), Parent = r }, function()
				send("Kick", { UserId = m.UserId })
			end)
		end
	end
	if #lobby.Members > 1 then
		UI.button("Leave party", { LayoutOrder = 10, Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = Color3.fromRGB(90, 40, 36), Parent = partyBody }, function()
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
			UI.text(pl.Name .. (if pl.InParty then "  (in a party)" else ""), { Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -120, 0, 22), TextSize = 15, Parent = r })
			if lobby.IsLeader and #lobby.Members < 4 then
				UI.button("Invite", { Size = UDim2.fromOffset(96, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Parent = r }, function()
					send("Invite", { UserId = pl.UserId })
				end)
			end
		end
	end
	UI.text("Tip: friends can join your server from the Roblox friends list, then accept your invite here.", { LayoutOrder = 999, TextSize = 12, TextColor3 = C.TextDim, Parent = partyBody })
end

-- Powerups panel ------------------------------------------------------------------------------------

local function renderPowerups()
	UI.clear(powerBody)
	local profile = State.Get("Profile")
	if not profile then
		UI.text("Loading your profile…", { Parent = powerBody })
		return
	end
	UI.text(string.format("◆ %d diamonds  ·  Win a match: +%d ◆  ·  One powerup equipped at a time (lobby only)", profile.Diamonds, Config.Match.WinDiamonds), { LayoutOrder = 0, TextSize = 14, TextColor3 = C.Diamond, Parent = powerBody })
	for i, def in Powerups.List do
		local lvl = profile.Owned[def.Id] or 0
		local color = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
		local card = UI.new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 176), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = powerBody }, { UI.corner(UDim.new(0, 10)), UI.stroke(if profile.Equipped == def.Id then color else C.Stroke, if profile.Equipped == def.Id then 3 else 1, 0.2), UI.padding(10) })
		local ic = UI.icon(def.Glyph, color, 60, "Round")
		ic.Parent = card
		UI.text(def.Name .. (if lvl > 0 then "   Level " .. lvl .. "/3" else "   🔒 " .. def.Price .. " ◆"), { Position = UDim2.fromOffset(72, 0), Size = UDim2.new(1, -72, 0, 24), TextSize = 19, Font = Theme.FontBlack, TextColor3 = color, Parent = card })
		local shown = def.Levels[math.max(1, lvl)]
		UI.text("Passive: " .. Powerups.Describe(def.Passive, shown.Passive), { Position = UDim2.fromOffset(72, 26), Size = UDim2.new(1, -72, 0, 18), TextSize = 13, Parent = card })
		UI.text("Ability: " .. Powerups.Describe(def.Ability, shown.Ability), { Position = UDim2.fromOffset(72, 44), Size = UDim2.new(1, -72, 0, 34), TextSize = 13, TextColor3 = C.TextDim, Parent = card })
		local buttons = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 46), Parent = card }, { UI.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right) })
		if lvl == 0 then
			UI.button("Unlock " .. def.Price .. " ◆", { Size = UDim2.fromOffset(150, 44), BackgroundColor3 = if profile.Diamonds >= def.Price then Color3.fromRGB(40, 90, 120) else C.PanelLighter, Parent = buttons }, function()
				send("BuyPowerup", { Id = def.Id })
			end)
			if Products.OnSale("Unlock_" .. def.Id) then
				UI.button("Unlock " .. Hud.PriceText("Unlock_" .. def.Id), { Size = UDim2.fromOffset(170, 44), BackgroundColor3 = Color3.fromRGB(40, 110, 60), Parent = buttons }, function()
					send("BuyRobux", { Key = "Unlock_" .. def.Id })
				end)
			end
		else
			UI.button(if profile.Equipped == def.Id then "Equipped ✓" else "Equip", { Size = UDim2.fromOffset(120, 44), BackgroundColor3 = if profile.Equipped == def.Id then C.AccentDark else C.PanelLighter, Parent = buttons }, function()
				send("EquipPowerup", { Id = if profile.Equipped == def.Id then nil else def.Id })
			end)
			if lvl < Powerups.MaxLevel then
				local ch = profile.Challenges and profile.Challenges[def.Id]
				local price = Powerups.UpgradePrice(def.Id, lvl + 1)
				local met = ch and ch.Progress and ch.Target and ch.Progress >= ch.Target
				UI.button("Upgrade " .. price .. " ◆", { Size = UDim2.fromOffset(150, 44), BackgroundColor3 = if met and profile.Diamonds >= price then Color3.fromRGB(40, 90, 120) else C.PanelLighter, Parent = buttons }, function()
					send("UpgradePowerup", { Id = def.Id })
				end)
				if Products.OnSale("Upgrade_" .. def.Id .. "_" .. (lvl + 1)) then
					UI.button("Skip " .. Hud.PriceText("Upgrade_" .. def.Id .. "_" .. (lvl + 1)), { Size = UDim2.fromOffset(150, 44), BackgroundColor3 = Color3.fromRGB(40, 110, 60), Parent = buttons }, function()
						send("BuyRobux", { Key = "Upgrade_" .. def.Id .. "_" .. (lvl + 1) })
					end)
				end
				if ch and ch.Target then
					local bar, set = UI.bar({ Position = UDim2.fromOffset(72, 82), Size = UDim2.new(1, -72, 0, 22), Parent = card }, color)
					bar.Name = "Challenge"
					set((ch.Progress or 0) / ch.Target, string.format("Lv%d challenge: %s  (%d/%d)", lvl + 1, ch.Text, math.min(ch.Progress or 0, ch.Target), ch.Target))
				end
			else
				UI.text("MAX LEVEL", { Position = UDim2.fromOffset(72, 84), TextSize = 15, Font = Theme.FontBlack, TextColor3 = C.Good, Parent = card })
			end
		end
	end
end

-- Shop panel ------------------------------------------------------------------------------------------

local function renderShop()
	UI.clear(shopBody)
	local profile = State.Get("Profile")
	UI.text("Diamonds are earned by playing: +" .. Config.Match.WinDiamonds .. " ◆ per win. Robux never buys gameplay power — Coin packs for cosmetics are coming soon.", { LayoutOrder = 0, TextSize = 14, TextColor3 = C.TextDim, Parent = shopBody })
	for i, key in { "Diamonds100", "Diamonds300", "Diamonds800" } do
		if not Products.OnSale(key) then
			continue
		end
		local p = Products.ByKey[key]
		local r = UI.new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 70), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0, Parent = shopBody }, { UI.corner(UDim.new(0, 8)), UI.padding(8) })
		local ic = UI.icon("◆", C.Diamond, 52, "Round")
		ic.Parent = r
		UI.text(p.Title, { Position = UDim2.fromOffset(64, 12), Size = UDim2.new(1, -240, 0, 28), TextSize = 20, Font = Theme.FontBlack, TextColor3 = C.Diamond, Parent = r })
		UI.button(Hud.PriceText(key), { Size = UDim2.fromOffset(160, 48), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(40, 110, 60), Parent = r }, function()
			send("BuyRobux", { Key = key })
		end)
	end
	if profile and profile.Credits then
		local rev = {}
		for tier, n in profile.Credits.Revive or {} do
			table.insert(rev, "tier " .. tier .. " ×" .. n)
		end
		UI.text(string.format("Stored credits (used automatically in matches): revives %s · care packages %d · bandages %d", if #rev > 0 then table.concat(rev, ", ") else "none", profile.Credits.CarePackage or 0, profile.Credits.Bandage or 0), { LayoutOrder = 10, TextSize = 13, TextColor3 = C.TextDim, Parent = shopBody })
	end
	UI.text("Prices are shown by Roblox for your region. Purchases are only granted after Roblox confirms them.", { LayoutOrder = 11, TextSize = 12, TextColor3 = C.TextDim, Parent = shopBody })
end

local HELP = {
	{ "Goal", "Four clans of up to four. Keep your campfire burning and be the last clan with a player alive or able to respawn." },
	{ "Day & night", "Day and night each last 2 minutes and repeat until one clan wins. At night, wolves, bears and bats hunt anyone away from a burning fire, and enemy fires can be put out." },
	{ "Lives", "Each death uses one of 3 free respawns (5 s) while your fire burns. That includes deaths to players, animals, spikes and resetting. After that, you or a teammate can buy a revive within 20 s. Once your fire is out, any death eliminates you." },
	{ "Progression", "Gather sticks, stone and fibre by hand, craft a Stone Axe, chop wood, build walls and storage. Hunt at night for leather. Twist fibre into rope. Upgrade your workbench to level 2 and craft a Canteen." },
	{ "Raiding", "Fill your canteen at any stream. At night, hold Pour at an enemy fire for 10 s. Getting hit stops the pour, and only one raider can pour on a fire at a time." },
	{ "Storage", "Build a storage box and deposit resources your whole clan can build and upgrade with. Enemies can steal from it (3 s)." },
	{ "Loot", "A free care package drops every day (3 random items, shown on the map). Hidden crates in the forest restock at dawn." },
	{ "PC controls", "WASD move · Click attack / hold to draw a bow · Right-click aim or block · 1-4 slots · ` fists · Q swap · X ability · H bandage · I bag · C craft · B build · M map · E/F/G interact" },
	{ "Mobile", "Use the on-screen buttons: ATTACK (hold for bows), AIM/BLOCK, ABILITY, HEAL, SWAP. Tap the prompt cards to interact. BAG, CRAFT, BUILD and MAP are at the top right." },
}

local function renderHelp()
	UI.clear(helpBody)
	for i, h in HELP do
		UI.text(h[1], { LayoutOrder = i * 2, TextSize = 17, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = helpBody })
		UI.text(h[2], { LayoutOrder = i * 2 + 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 14, Parent = helpBody })
	end
end

-- Invites -------------------------------------------------------------------------------------------------

local function showInvite(d: any)
	local card = UI.panel({ Size = UDim2.fromOffset(340, 104), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Parent = gui }, { UI.padding(10) })
	UI.text(tostring(d.From) .. " invited you to their party", { Size = UDim2.new(1, 0, 0, 24), TextSize = 16, Font = Theme.FontBold, Parent = card })
	UI.button("Accept", { Size = UDim2.new(0.48, 0, 0, 46), Position = UDim2.new(0, 0, 1, -46), BackgroundColor3 = Color3.fromRGB(40, 110, 60), Parent = card }, function()
		send("Accept", { PartyId = d.PartyId })
		card:Destroy()
	end)
	UI.button("Decline", { Size = UDim2.new(0.48, 0, 0, 46), Position = UDim2.new(0.52, 0, 1, -46), BackgroundColor3 = Color3.fromRGB(90, 40, 36), Parent = card }, function()
		send("Decline", { PartyId = d.PartyId })
		card:Destroy()
	end)
	task.delay(60, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

function Lobby.Start()
	gui = UI.new("ScreenGui", { Name = "LobbyHud", ResetOnSpawn = false, DisplayOrder = 3, Parent = player:WaitForChild("PlayerGui") })
	local scale = UI.new("UIScale", { Parent = gui })
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(vp.X / 1000, vp.Y / 600), 0.65, 1.2)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	local top = UI.panel({ Size = UDim2.fromOffset(420, 40), Position = UDim2.fromOffset(12, 8), Parent = gui })
	diamondsLabel = UI.text("", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -12, 1, 0), TextSize = 17, Font = Theme.FontBold, TextColor3 = C.Diamond, Parent = top })

	local bottom = UI.panel({ Size = UDim2.fromOffset(640, 150), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Parent = gui }, { UI.padding(10) })
	readyBtn = UI.button("READY UP", { Size = UDim2.new(1, 0, 0, 56), TextSize = 24, Font = Theme.FontBlack, Parent = bottom }, function()
		local lobby = State.Get("Lobby")
		if lobby and (lobby.Ready or lobby.Queued) then
			send("Ready", { Value = false })
		else
			send("Ready", { Value = true })
		end
	end)
	statusLabel = UI.text("", { Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 20), TextSize = 13, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = bottom })
	partyStrip = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 24), Parent = bottom }, { UI.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center) })
	local nav = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(1, 0, 0, 40), Parent = bottom }, { UI.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })
	for _, spec in { { "Party", "♟ Party" }, { "Powerups", "⚡ Powerups" }, { "LobbyShop", "◆ Shop" }, { "Help", "? How to play" } } do
		UI.button(spec[2], { Size = UDim2.fromOffset(148, 40), TextSize = 15, Parent = nav }, function()
			Panels.Toggle(spec[1])
		end)
	end

	partyBody = Panels.Create("Party", "PARTY", Vector2.new(560, 560), renderParty)
	UI.list(Enum.FillDirection.Vertical, 6).Parent = partyBody
	powerBody = Panels.Create("Powerups", "POWERUP SHRINE", Vector2.new(680, 640), renderPowerups)
	UI.list(Enum.FillDirection.Vertical, 8).Parent = powerBody
	shopBody = Panels.Create("LobbyShop", "TRADING POST", Vector2.new(600, 480), renderShop)
	UI.list(Enum.FillDirection.Vertical, 8).Parent = shopBody
	helpBody = Panels.Create("Help", "HOW TO PLAY", Vector2.new(640, 600), renderHelp)
	UI.list(Enum.FillDirection.Vertical, 4).Parent = helpBody

	State.On("Lobby", function()
		renderHud()
		if Panels.IsOpen("Party") then
			renderParty()
		end
	end)
	State.On("Profile", function()
		renderHud()
		if Panels.IsOpen("Powerups") then
			renderPowerups()
		end
		if Panels.IsOpen("LobbyShop") then
			renderShop()
		end
	end)
	State.On("PricesUpdated", function()
		if Panels.IsOpen("Powerups") then
			renderPowerups()
		elseif Panels.IsOpen("LobbyShop") then
			renderShop()
		end
	end)
	State.On("MatchEvent", function(ev)
		if ev.Name == "PartyInvite" then
			showInvite(ev.Data)
		elseif ev.Name == "OpenStation" then
			local st = ev.Data.Station
			Panels.Open(if st == "Shop" then "LobbyShop" elseif st == "Powerups" then "Powerups" else "Party")
		end
	end)
	local function vis()
		gui.Enabled = not player:GetAttribute("InMatch") and workspace:GetAttribute("ServerMode") ~= "Match"
	end
	player:GetAttributeChangedSignal("InMatch"):Connect(vis)
	vis()
end

return Lobby
