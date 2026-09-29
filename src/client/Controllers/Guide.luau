--!nonstrict
-- Survival Guide: a compact objective tracker for new players (onboarding).
-- One short line at a time, derived from what the player actually has and has
-- done, so it never blocks play and never shows a wall of text. It hides once
-- the basics are done, for experienced accounts (level 8+), or when dismissed.
-- Contextual one-off tips (first night, Night 3, first death, final life) use
-- the HUD announcer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")

local Guide = {}

local player = Players.LocalPlayer
local C = Theme.Colors

local frame: Frame
local stepLabel: TextLabel
local textLabel: TextLabel
local dismissed = false
local fed = false
local built = false
local lastFuel: number? = nil
local shownTips: { [string]: boolean } = {}

local function hasItem(inv: any, pattern: string): boolean
	for _, st in inv.Slots or {} do
		if st and type(st.Id) == "string" and string.find(st.Id, pattern) then
			return true
		end
	end
	return false
end

local function res(inv: any, id: string): number
	return (inv.Resources and inv.Resources[id]) or 0
end

-- Steps in order: { text, done() }.
local STEPS = {
	{ "Pick up sticks, stones and fibre by hand (walk up and press E)", function(inv)
		return res(inv, "Stick") + res(inv, "Stone") >= 4 or hasItem(inv, "Axe")
	end },
	{ "Craft a Crude Axe — open CRAFT (C)", function(inv)
		return hasItem(inv, "Axe")
	end },
	{ "Chop trees for Wood (small tree = 4 Wood)", function(inv)
		return res(inv, "Wood") >= 4 or fed
	end },
	{ "Feed your fire: hold E at your Campfire (1 Wood = +2% fuel)", function()
		return fed
	end },
	{ "Upgrade your Workbench to Tier II — CRAFT (C)", function()
		local craft = State.Get("Craft")
		return craft ~= nil and (craft.Level or 1) >= 2
	end },
	{ "Build walls or storage near your fire — BUILD (B)", function()
		return built
	end },
}

local function tip(key: string, title: string, sub: string, color: Color3?)
	if shownTips[key] then
		return
	end
	shownTips[key] = true
	local Hud = require("./Hud")
	Hud.Announce(title, sub, color or C.Accent, 4)
end

local function refresh()
	local inMatch = player:GetAttribute("InMatch") == true
	local profile = State.Get("Profile")
	local veteran = profile ~= nil and ((profile.Level or 1) >= 8 or (profile.Settings and profile.Settings.ShowGuide == false))
	local inv = State.Get("Inventory")
	local step, total = nil, #STEPS
	if inv then
		for i, s in STEPS do
			if not s[2](inv) then
				step = i
				break
			end
		end
	end
	local show = inMatch and not dismissed and not veteran and step ~= nil and player:GetAttribute("LifeState") == "Alive"
	if show and step then
		local text = STEPS[step][1]
		if textLabel.Text ~= text then
			textLabel.Text = text
			stepLabel.Text = string.format("SURVIVAL GUIDE · %d/%d", step, total)
			-- small nudge when the objective changes
			local pop = frame:FindFirstChildOfClass("UIScale") :: UIScale
			pop.Scale = 1.06
			TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
		end
	end
	frame.Visible = show
end

function Guide.Start()
	local gui = UI.new("ScreenGui", { Name = "Guide", ResetOnSpawn = false, DisplayOrder = 2, Parent = player:WaitForChild("PlayerGui") })
	UI.new("UIScale", { Name = "UiScale", Scale = Theme.UiScale, Parent = gui })
	frame = UI.panel({ Size = UDim2.fromOffset(330, 58), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -190), Visible = false, Parent = gui }, { UI.padding(8), UI.new("UIScale", {}) })
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = C.Accent
	end
	stepLabel = UI.text("SURVIVAL GUIDE", { Size = UDim2.new(1, -30, 0, 14), TextSize = 11, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = frame })
	textLabel = UI.text("", { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, -4, 0, 26), TextSize = 13, Font = Theme.FontBold, TextWrapped = true, Parent = frame })
	UI.Buttons.icon("✖", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), TextSize = 12, Parent = frame }, function()
		dismissed = true
		frame.Visible = false
	end)

	-- progress signals
	player:GetAttributeChangedSignal("FireFuel"):Connect(function()
		local f = player:GetAttribute("FireFuel") :: number?
		if f and lastFuel and f > lastFuel + 0.005 then
			fed = true
		end
		lastFuel = f
	end)
	State.On("Notify", function(n)
		if type(n.Text) == "string" and (string.find(n.Text, "^Built") or string.find(n.Text, "placed")) then
			built = true
		end
	end)
	State.On("Fx", function(ev)
		if ev.Name == "Built" then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and ev.Data and ev.Data.Pos and (root.Position - ev.Data.Pos).Magnitude < 30 then
				built = true
			end
		end
	end)
	State.On("Inventory", refresh)
	State.On("Craft", refresh)

	-- contextual tips (once per session)
	local ms = ReplicatedStorage:WaitForChild("MatchState")
	State.On("MatchEvent", function(ev)
		local d = ev.Data or {}
		if ev.Name == "Phase" and d.Phase == "Night" and d.Day == 1 then
			tip("night1", "🌙 FIRST NIGHT", "Predators hunt at night. Stay near your fire's light and keep it fed.", C.Night)
		elseif ev.Name == "Phase" and d.ProtectionEnded then
			tip("night3", "⚠ FIRES ARE EXPOSED", "Enemies can now snuff your fire with water. Guard it — and raid theirs.", C.Bad)
		elseif ev.Name == "Died" and not d.Final then
			tip("death", "YOU'LL RESPAWN AT YOUR FIRE", "Only materials drop. Tools, armour and your backpack are kept.", C.Warn)
		elseif ev.Name == "FireOut" and d.Team == player:GetAttribute("Team") then
			tip("final", "FINAL LIFE", "Your fire is out. One more death and you're eliminated — play carefully.", C.Bad)
		elseif ev.Name == "ReturnedToLobby" or ev.Name == "Loading" then
			fed, built, lastFuel = false, false, nil
		end
	end)
	player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
	player:GetAttributeChangedSignal("LifeState"):Connect(refresh)
	ms:GetAttributeChangedSignal("Phase"):Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
end

return Guide
