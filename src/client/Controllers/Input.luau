--!nonstrict
-- Unified input: keyboard/mouse, gamepad and on-screen touch controls all map
-- to named actions, emitted as State "Action" events { Name, Down }.
--
-- PC:      LMB attack/draw (hold for heavy) · RMB aim/block · 1-5 slots · Shift sprint · ` fists · Q swap
--          H bandage · I inventory · C craft · B build · M map · R rotate (build)
-- Gamepad: R2 attack · L2 aim/block · R1 swap · L1 bandage · L3 sprint
--          DPad ←/→ cycle slots · DPad ↑ craft · DPad ↓ build · Y inventory · Select map
-- Touch:   on-screen buttons (bottom-right cluster + top-right menu buttons)

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local State = require("../State")
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")

local Input = {}

local player = Players.LocalPlayer

local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.One] = "Slot1",
	[Enum.KeyCode.Two] = "Slot2",
	[Enum.KeyCode.Three] = "Slot3",
	[Enum.KeyCode.Four] = "Slot4",
	[Enum.KeyCode.Five] = "Slot5",
	[Enum.KeyCode.LeftShift] = "Sprint",
	[Enum.KeyCode.ButtonL3] = "Sprint",
	[Enum.KeyCode.Backquote] = "Fists",
	[Enum.KeyCode.Q] = "Swap",
	[Enum.KeyCode.H] = "Bandage",
	[Enum.KeyCode.I] = "Inventory",
	[Enum.KeyCode.C] = "Craft",
	[Enum.KeyCode.B] = "Build",
	[Enum.KeyCode.M] = "Map",
	[Enum.KeyCode.R] = "Rotate",
	[Enum.KeyCode.ButtonR2] = "Attack",
	[Enum.KeyCode.ButtonL2] = "Aim",
	[Enum.KeyCode.ButtonR1] = "Swap",
	[Enum.KeyCode.ButtonL1] = "Bandage",
	[Enum.KeyCode.DPadRight] = "NextSlot",
	[Enum.KeyCode.DPadLeft] = "PrevSlot",
	[Enum.KeyCode.ButtonSelect] = "Map",
	[Enum.KeyCode.ButtonY] = "Inventory",
	[Enum.KeyCode.DPadUp] = "Craft",
	[Enum.KeyCode.DPadDown] = "Build",
}

Input.IsTouch = false
Input.Down = {} :: { [string]: boolean }

local function emit(name: string, down: boolean)
	Input.Down[name] = down
	State.Emit("Action", { Name = name, Down = down })
end
Input.Emit = emit

function Input.Start()
	Input.IsTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	State.Set("IsTouch", Input.IsTouch)

	UserInputService.InputBegan:Connect(function(io, processed)
		if io.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			emit("Attack", true)
			return
		elseif io.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
			emit("Aim", true)
			return
		end
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local name = KEYS[io.KeyCode]
		if name then
			emit(name, true)
		end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			if Input.Down.Attack then
				emit("Attack", false)
			end
			return
		elseif io.UserInputType == Enum.UserInputType.MouseButton2 then
			if Input.Down.Aim then
				emit("Aim", false)
			end
			return
		end
		local name = KEYS[io.KeyCode]
		if name and Input.Down[name] then
			emit(name, false)
		end
	end)

	UserInputService.LastInputTypeChanged:Connect(function(t)
		local touch = t == Enum.UserInputType.Touch
		if touch ~= Input.IsTouch then
			Input.IsTouch = touch
			State.Set("IsTouch", touch)
		end
	end)

	Input._buildTouch()
end

-- Touch controls ---------------------------------------------------------------------------

function Input._buildTouch()
	if not UserInputService.TouchEnabled then
		return
	end
	local gui = UI.new("ScreenGui", {
		Name = "TouchControls",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	UI.new("UIScale", { Name = "UiScale", Scale = Theme.UiScale, Parent = gui })
	local HUD_ICON = { Attack = "Attack", Aim = "Aim", Bandage = "Heal", Swap = "Swap", Sprint = "Run", Inventory = "Bag", Craft = "Craft", Build = "Build", Map = "Map" }
	local function round(name: string, glyph: string, label: string, size: number, pos: UDim2, action: string, hold: boolean, tone: string)
		local b = UI.Buttons.round(glyph, label, size, tone, { Name = name, Position = pos, AnchorPoint = Vector2.new(0.5, 0.5), Icon = "Hud_" .. HUD_ICON[name], Parent = gui })
		b.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.Touch then
				b:SetAttribute("Down", true)
				UI.Buttons.refresh(b)
				emit(action, true)
				if not hold then
					emit(action, false)
				end
			end
		end)
		b.InputEnded:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.Touch then
				b:SetAttribute("Down", nil)
				UI.Buttons.refresh(b)
				if hold and Input.Down[action] then
					emit(action, false)
				end
			end
		end)
		return b
	end
	-- Bottom-right combat cluster (clear of the default jump button, which sits lower-right).
	local attack = round("Attack", "🗡", "ATTACK", 92, UDim2.new(1, -170, 1, -200), "Attack", true, "Red")
	round("Aim", "🛡", "AIM / BLOCK", 66, UDim2.new(1, -275, 1, -155), "Aim", true, "Blue")
	round("Bandage", "✚", "HEAL", 60, UDim2.new(1, -85, 1, -285), "Bandage", false, "Green")
	round("Swap", "⇄", "SWAP", 56, UDim2.new(1, -170, 1, -320), "Swap", false, "Neutral")
	State.Set("TouchAttackButton", attack)

	-- Menu buttons (top right, below the Roblox top bar)
	local menu = UI.new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(4 * 62, 58),
		Position = UDim2.new(1, -12, 0, GuiService:GetGuiInset().Y + 196), -- below the minimap
		AnchorPoint = Vector2.new(1, 0),
		Parent = gui,
	}, { UI.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right) })
	for i, spec in { { "Inventory", "🎒", "BAG" }, { "Craft", "🔨", "CRAFT" }, { "Build", "🧱", "BUILD" }, { "Map", "🗺", "MAP" } } do
		local b = UI.Buttons.tile(spec[3], nil, spec[2], { Name = spec[1], LayoutOrder = i, Size = UDim2.fromOffset(58, 58), Icon = "Hud_" .. HUD_ICON[spec[1]], Parent = menu })
		b.Activated:Connect(function()
			emit(spec[1], true)
			emit(spec[1], false)
		end)
	end

	-- Only show combat buttons in a match while alive.
	local function refresh()
		local inMatch = player:GetAttribute("InMatch") == true
		local alive = player:GetAttribute("LifeState") == "Alive"
		for _, c in gui:GetChildren() do
			if c:IsA("GuiObject") and c.Name ~= "Menu" then
				c.Visible = inMatch and alive and Input.IsTouch
			end
		end
		menu.Visible = inMatch and Input.IsTouch
	end
	player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
	player:GetAttributeChangedSignal("LifeState"):Connect(refresh)
	State.On("IsTouch", refresh)
	refresh()
end

return Input
