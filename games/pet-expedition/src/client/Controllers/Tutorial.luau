--!strict
-- First-time hints with a glowing beam and a bouncing arrow:
--   1. walk to the Meadow egg stand and hatch a pet
--   2. tap a coin pile so your pets break it
--   3. collect coins and open the gate to the next island
-- Progress comes from the player's Stats/Areas, so nothing extra is saved.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared:WaitForChild("Areas"))

local State = require("../Core/State")
local Format = require("../Core/Format")
local Breakables = require("../Core/Breakables")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")

local Tutorial = {}

local player = Players.LocalPlayer
local hint: Frame
local hintText: TextLabel
local anchor: Part
local arrowGui: BillboardGui
local beam: Beam
local att1: Attachment
local att0: Attachment? = nil

local FIRST = Areas.List[1]
local SECOND = Areas.List[2]

local function posOf(inst: Instance): Vector3?
	if inst:IsA("Model") then
		local cf, size = inst:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2, 0)
	elseif inst:IsA("BasePart") then
		return inst.Position + Vector3.new(0, inst.Size.Y / 2, 0)
	end
	return nil
end

local function findTagged(tag: string, attr: string, value: string): Instance?
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:GetAttribute(attr) == value then
			return inst
		end
	end
	return nil
end

local function nearestPile(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best: Vector3? = nil
	local bestD = math.huge
	for _, info in Breakables.All() do
		if info.Kind == "CoinPile" and info.Area == FIRST.Id and info.Model.Parent then
			local d = (info.Center - root.Position).Magnitude
			if d < bestD then
				bestD = d
				best = info.Center + Vector3.new(0, info.Size.Y / 2, 0)
			end
		end
	end
	return best
end

-- Returns (hint text, target position) for the current step, or nil when done.
local function step(): (string?, Vector3?)
	local d = State.Data
	if not d then
		return nil, nil
	end
	if d.Stats.Hatched == 0 then
		local stand = findTagged("EggStand", "EggId", FIRST.Egg)
		return Theme.Icons.Egg .. " Walk to the egg stand and hatch your first pet!", if stand then posOf(stand) else nil
	end
	if d.Stats.Broken == 0 then
		return Theme.Icons.Coins .. " Tap a coin pile to send your pets!", nearestPile()
	end
	if SECOND and not d.Areas[SECOND.Id] then
		local gate = findTagged("Gate", "AreaId", SECOND.Id)
		local text = if d.Coins >= SECOND.GateCost
			then Theme.Icons.Islands .. " You have enough! Open the gate to " .. SECOND.Name
			else Theme.Icons.Coins .. " Collect " .. Format.num(d.Coins) .. "/" .. Format.num(SECOND.GateCost) .. " coins, then open the gate"
		return text, if gate then posOf(gate) else nil
	end
	return nil, nil
end

local function ensureAttachment0(): Attachment?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local a = att0
	if a and a.Parent == root then
		return a
	end
	local na = Instance.new("Attachment")
	na.Name = "TutorialBeam"
	na.Parent = root
	att0 = na
	return na
end

local function update()
	local text, target = step()
	local busy = Windows.CurrentName() ~= nil
	hint.Visible = text ~= nil and not busy
	if text then
		hintText.Text = text
	end
	local a0 = ensureAttachment0()
	local show = text ~= nil and target ~= nil and a0 ~= nil
	beam.Enabled = show
	arrowGui.Enabled = show
	if show then
		anchor.Position = target :: Vector3
		beam.Attachment0 = a0
	end
end

function Tutorial.Init()
	hint = Kit.panel({
		Name = "TutorialHint",
		Size = UDim2.fromOffset(560, 56),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -80),
		BackgroundColor3 = Color3.fromRGB(255, 250, 220),
		StrokeColor = Theme.Tones.Yellow.Rim,
		Corner = 28,
		Visible = false,
		Parent = Windows.Gui("Hud"),
	})
	Kit.autoScale(hint, 1)
	hintText = Kit.fitLabel("", 24, { Size = UDim2.new(1, -24, 1, -8), Position = UDim2.fromOffset(12, 4), Parent = hint })

	local folder = Workspace:FindFirstChild("ClientFx") or Workspace
	local p = Instance.new("Part")
	p.Name = "TutorialTarget"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Parent = folder
	anchor = p
	att1 = Instance.new("Attachment")
	att1.Parent = p
	local b = Instance.new("Beam")
	b.Attachment1 = att1
	b.FaceCamera = true
	b.Width0 = 0.9
	b.Width1 = 0.9
	b.Segments = 12
	b.LightEmission = 1
	b.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 140, 60))
	b.Transparency = NumberSequence.new(0.15, 0.35)
	b.TextureSpeed = 1
	b.Enabled = false
	b.Parent = p
	beam = b
	arrowGui = Kit.new("BillboardGui", {
		Size = UDim2.fromOffset(80, 80),
		StudsOffset = Vector3.new(0, 4, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = p,
		Enabled = false,
		Parent = p,
	})
	local arrow = Kit.fitLabel("⬇", 64, {
		Size = UDim2.fromScale(1, 1),
		Color = Theme.Colors.Coins,
		Outline = Theme.Tones.Yellow.Rim,
		Parent = arrowGui,
	})
	RunService.RenderStepped:Connect(function()
		if arrowGui.Enabled then
			arrow.Position = UDim2.fromOffset(0, math.sin(os.clock() * 5) * 10)
		end
	end)
	task.spawn(function()
		while true do
			update()
			task.wait(0.5)
		end
	end)
end

return Tutorial
