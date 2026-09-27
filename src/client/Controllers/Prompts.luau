--!nonstrict
-- Custom ProximityPrompt presentation. Server prompts use Style=Custom; this
-- draws readable, touch-friendly prompt cards and hides prompts that don't
-- apply to the local player (team-only / enemy-only), with context hints
-- ("Night only", "Needs canteen", "Needs axe").

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")

local Prompts = {}

local player = Players.LocalPlayer
local shown: { [ProximityPrompt]: BillboardGui } = {}

local function applies(prompt: ProximityPrompt): boolean
	local filter = prompt:GetAttribute("Filter")
	if not filter then
		return true
	end
	local team = prompt:GetAttribute("Team")
	local mine = player:GetAttribute("Team")
	if filter == "Team" then
		return team == mine
	elseif filter == "Enemy" then
		return team ~= mine
	end
	return true
end

local function hint(prompt: ProximityPrompt): string?
	local state = ReplicatedStorage:FindFirstChild("MatchState")
	if prompt:GetAttribute("Night") and state and state:GetAttribute("Phase") ~= "Night" then
		return "Night only"
	end
	if prompt:GetAttribute("Snuff") and state and not state:GetAttribute("SnuffOpen") then
		return "Protected until Night 3"
	end
	local inv = State.Get("Inventory")
	if prompt:GetAttribute("NeedsCanteen") then
		local util = inv and inv.Slots and inv.Slots.Utility
		if not util or util.Id ~= "Canteen" then
			return "Needs a canteen"
		end
	end
	if prompt:GetAttribute("Action") == "Pour" then
		local util = inv and inv.Slots and inv.Slots.Utility
		if not util or util.Id ~= "Canteen" then
			return "Needs a filled canteen"
		elseif not util.Filled then
			return "Canteen is empty"
		end
	end
	if prompt:GetAttribute("NeedsAxe") then
		local tool = inv and inv.Slots and inv.Slots.Tool
		if not tool or tool.Id ~= "StoneAxe" then
			return "Needs a stone axe"
		end
	end
	return nil
end

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return string.gsub(prompt.GamepadKeyCode.Name, "Button", "")
	end
	return prompt.KeyboardKeyCode.Name
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	if not applies(prompt) then
		prompt.Enabled = false -- local only; server keeps it enabled for others
		return
	end
	local adornee = prompt.Parent
	if not adornee or not adornee:IsA("BasePart") then
		return
	end
	local hold = prompt:GetAttribute("Action") == "Pour"
	local h = hint(prompt)
	local bb = UI.new("BillboardGui", {
		Name = "Prompt",
		Adornee = adornee,
		Size = UDim2.fromOffset(230, 64),
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
		AlwaysOnTop = true,
		Active = true,
		MaxDistance = 40,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local card = UI.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.12,
		AutoButtonColor = false,
		Text = "",
		Parent = bb,
	}, { UI.corner(UDim.new(0, 12)), UI.stroke(if h then Theme.Colors.Bad else Theme.Colors.Accent, 2, 0.1) })
	UI.new("TextLabel", {
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = if h then Theme.Colors.PanelLighter else Theme.Colors.AccentDark,
		Text = keyText(prompt, inputType),
		TextScaled = true,
		Font = Theme.FontBlack,
		TextColor3 = Theme.Colors.Text,
		Parent = card,
	}, { UI.corner(UDim.new(0, 8)), UI.padding(6) })
	UI.text((if hold then "HOLD: " else "") .. prompt.ActionText, { Position = UDim2.fromOffset(66, 6), Size = UDim2.new(1, -72, 0, 28), Font = Theme.FontBold, TextSize = 20, Parent = card })
	UI.text(h or prompt.ObjectText, {
		Position = UDim2.fromOffset(66, 34),
		Size = UDim2.new(1, -72, 0, 22),
		TextSize = 15,
		TextColor3 = if h then Theme.Colors.Bad else Theme.Colors.TextDim,
		Parent = card,
	})
	-- Touch: the whole card is the button (hold for Pour)
	card.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	card.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)
	shown[prompt] = bb
end

local function hide(prompt: ProximityPrompt)
	local bb = shown[prompt]
	if bb then
		bb:Destroy()
		shown[prompt] = nil
	end
end

function Prompts.Start()
	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(hide)
	-- Re-render hints when inventory changes (e.g. canteen filled)
	State.On("Inventory", function()
		for prompt, _ in shown do
			local inputType = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then Enum.ProximityPromptInputType.Touch else Enum.ProximityPromptInputType.Keyboard
			hide(prompt)
			if prompt.Parent then
				show(prompt, inputType)
			end
		end
	end)
end

return Prompts
