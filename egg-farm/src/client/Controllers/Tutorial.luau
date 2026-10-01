--!strict
-- Tutorial overlay: the current step's text (Contract.Tutorial[snapshot.tutorial.step]), a
-- bouncing arrow over the HUD element to use, and a beam + marker in the world from the player
-- to the place to walk to (own plot only). Progressive reveal of the HUD itself is done by
-- Controllers/Hud via Logic/Tutorial.Reveals. Hidden for good once tutorial.done.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared:WaitForChild("Contract"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Layout = require(UI.Layout)
local Icon = require(UI.Icon)
local Prompts = require(script.Parent.Prompts)

local Tutorial = {}

-- Where each step points: a HUD target name (Hud.Targets) and/or a world target finder.
type Hint = { ui: string?, world: ((plot: Model) -> BasePart?)? }

local function find(plot: Model, path: { string }): BasePart?
	local cur: Instance? = plot
	for _, name in path do
		cur = cur and cur:FindFirstChild(name)
	end
	return if cur and cur:IsA("BasePart") then cur else nil
end

local function board(menu: string): (plot: Model) -> BasePart?
	return function(plot)
		local boards = plot:FindFirstChild("Boards")
		if not boards then
			return nil
		end
		for _, d in boards:GetDescendants() do
			if d:IsA("ProximityPrompt") and d:GetAttribute("Menu") == menu then
				local p = d.Parent
				if p and p:IsA("BasePart") then
					return p
				elseif p and p:IsA("Attachment") and p.Parent and p.Parent:IsA("BasePart") then
					return p.Parent :: BasePart
				end
			end
		end
		return nil
	end
end

local HINTS: { [string]: Hint } = {
	spawn = { ui = "spawn" },
	collect = {
		world = function(plot)
			return find(plot, { "Houses", "House1", "CollectRing" })
		end,
	},
	deposit = {
		world = function(plot)
			return find(plot, { "Warehouse", "DepositRing" })
		end,
	},
	sell = {
		world = function(plot)
			return find(plot, { "Dock", "Bay1" })
		end,
	},
	vehicle = { ui = "farm", world = board("Shipping") },
	earn = { ui = "cash" },
	housing = { ui = "farm", world = board("Housing") },
}

-- True when the object and every GUI ancestor are visible (hidden HUD parts get no arrow).
local function shown(obj: GuiObject): boolean
	local cur: Instance? = obj
	while cur and cur:IsA("GuiObject") do
		if not cur.Visible then
			return false
		end
		cur = cur.Parent
	end
	if cur and cur:IsA("LayerCollector") then
		return cur.Enabled
	end
	return cur ~= nil
end

function Tutorial.Start(store: any, host: any, hud: any)
	local gui, root = Layout.Layer("EggFarmTutorial", 8)

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 112)
	banner.Size = UDim2.new(1, -40, 0, 0)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.BackgroundColor3 = Theme.Color.Panel
	Util.Corner(banner, 18)
	Util.Stroke(banner, 4, Theme.Color.Ink, true)
	Util.Gradient(banner, Color3.new(1, 1, 1), Color3.fromRGB(240, 226, 196))
	Util.Pad(banner, 10)
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(520, 400)
	lim.Parent = banner
	local ic = Icon.new("chick", 48)
	ic.Parent = banner
	local textBox = Instance.new("Frame")
	textBox.BackgroundTransparency = 1
	textBox.Position = UDim2.fromOffset(58, 0)
	textBox.Size = UDim2.new(1, -58, 0, 0)
	textBox.AutomaticSize = Enum.AutomaticSize.Y
	textBox.Parent = banner
	Util.List(textBox, 2, false, Enum.HorizontalAlignment.Left)
	local stepLabel = Util.Text({
		text = "",
		size = UDim2.new(1, 0, 0, 24),
		textSize = Theme.Text.S,
		color = Theme.Color.Orange,
		font = Theme.Font.Title,
		xAlign = Enum.TextXAlignment.Left,
		order = 1,
		parent = textBox,
	})
	local text = Util.Text({
		text = "",
		size = UDim2.new(1, 0, 0, 0),
		textSize = Theme.Text.M,
		color = Theme.Color.TextDark,
		font = Theme.Font.Title,
		xAlign = Enum.TextXAlignment.Left,
		wrap = true,
		order = 2,
		parent = textBox,
	})
	banner.Parent = root

	-- arrow pointing down at a HUD element
	local arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.AnchorPoint = Vector2.new(0.5, 1)
	arrow.Size = UDim2.fromOffset(44, 54)
	arrow.Visible = false
	local head = Instance.new("Frame")
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.Position = UDim2.new(0.5, 0, 1, -16)
	head.Size = UDim2.fromOffset(30, 30)
	head.Rotation = 45
	head.BackgroundColor3 = Theme.Color.Gold
	Util.Corner(head, 4)
	Util.Stroke(head, 3, Theme.Color.Ink)
	head.Parent = arrow
	local stem = Instance.new("Frame")
	stem.AnchorPoint = Vector2.new(0.5, 0)
	stem.Position = UDim2.new(0.5, 0, 0, 0)
	stem.Size = UDim2.fromOffset(16, 34)
	stem.BackgroundColor3 = Theme.Color.Gold
	Util.Corner(stem, 4)
	Util.Stroke(stem, 3, Theme.Color.Ink)
	stem.ZIndex = 2
	stem.Parent = arrow
	arrow.Parent = root

	-- world beam + marker (local only)
	local me = Players.LocalPlayer
	local beam: Beam? = nil
	local a1: Attachment? = nil
	local marker: BillboardGui? = nil
	local worldTarget: BasePart? = nil

	local function clearWorld()
		if beam then
			beam:Destroy()
		end
		if a1 then
			a1:Destroy()
		end
		if marker then
			marker:Destroy()
		end
		beam, a1, marker, worldTarget = nil, nil, nil, nil
	end

	local function setWorld(part: BasePart?)
		if part == worldTarget then
			return
		end
		clearWorld()
		if not part then
			return
		end
		worldTarget = part
		local att = Instance.new("Attachment")
		att.Name = "EggFarmTutorialTarget"
		att.Position = Vector3.new(0, part.Size.Y / 2 + 0.5, 0)
		att.Parent = part
		a1 = att
		local bb = Instance.new("BillboardGui")
		bb.Name = "EggFarmTutorialMarker"
		bb.AlwaysOnTop = true
		bb.Size = UDim2.fromOffset(64, 80)
		bb.StudsOffset = Vector3.new(0, 5, 0)
		bb.Adornee = part
		bb.LightInfluence = 0
		local mark = Util.Text({
			text = "▼",
			textSize = 64,
			color = Theme.Color.Gold,
			font = Theme.Font.Number,
			outline = true,
			parent = bb,
		})
		mark.Name = "Mark"
		bb.Parent = part
		marker = bb
		local b = Instance.new("Beam")
		b.Name = "EggFarmTutorialBeam"
		b.Color = ColorSequence.new(Theme.Color.Gold)
		b.Transparency = NumberSequence.new(0.2, 0.5)
		b.Width0 = 0.8
		b.Width1 = 0.8
		b.FaceCamera = true
		b.LightEmission = 0.6
		b.Segments = 10
		b.Attachment1 = att
		b.Parent = part
		beam = b
	end

	local function rootAttachment(): Attachment?
		local char = me.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return nil
		end
		local att = hrp:FindFirstChild("EggFarmTutorialFrom")
		if not att then
			local made = Instance.new("Attachment")
			made.Name = "EggFarmTutorialFrom"
			made.Parent = hrp
			att = made
		end
		return att :: Attachment
	end

	local currentKey: string? = nil
	local done = false

	local function update(snap: any)
		done = snap.tutorial.done
		if done then
			gui.Enabled = false
			clearWorld()
			currentKey = nil
			return
		end
		local step = snap.tutorial.step
		local entry = Contract.Tutorial[step]
		if not entry then
			gui.Enabled = false
			return
		end
		gui.Enabled = true
		if currentKey ~= entry.key then
			currentKey = entry.key
			Util.Pop(banner, 0.08)
		end
		stepLabel.Text = string.format("TUTORIAL  %d / %d", step, #Contract.Tutorial)
		text.Text = entry.text
	end

	store.OnChanged(function(snap: any)
		update(snap)
	end)

	-- 10 Hz: follow the HUD target, bounce the arrow, keep the beam attached to the character
	local t = 0
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		acc += dt
		if acc < 0.1 or done or not gui.Enabled then
			return
		end
		acc = 0
		local hint = currentKey and HINTS[currentKey]
		-- HUD arrow (hidden while a menu covers the screen)
		local target: GuiObject? = if hint and hint.ui then hud.Targets[hint.ui] else nil
		if target and shown(target) and not host:IsBlocking() then
			local scale = Layout.Scale()
			local rel = (target.AbsolutePosition - root.AbsolutePosition) / scale
			local size = target.AbsoluteSize / scale
			local bounce = math.abs(math.sin(t * 4)) * 10
			arrow.Position = UDim2.fromOffset(rel.X + size.X / 2, rel.Y - 4 - bounce)
			arrow.Visible = true
		else
			arrow.Visible = false
		end
		banner.Visible = not host:IsBlocking()
		-- world beam
		local plot = Prompts.OwnPlot()
		local part = if plot and hint and hint.world then hint.world(plot) else nil
		setWorld(part)
		if beam then
			local from = rootAttachment()
			beam.Attachment0 = from
		end
	end)
end

return Tutorial
