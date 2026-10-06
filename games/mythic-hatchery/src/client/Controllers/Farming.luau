--!strict
-- Farming: tap/click a breakable to send your pets (SetTarget), tap it again
-- or tap the ground to call them back. Selection highlight, HP bars, break
-- pops (Notify Broken) and floating rewards with coins flying to the HUD
-- (Notify Reward).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local Format = require("../Core/Format")
local Sounds = require("../Core/Sounds")
local Breakables = require("../Core/Breakables")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Toasts = require("../UI/Toasts")
local Hud = require("./Hud")

local Farming = {}

local player = Players.LocalPlayer
local fxFolder: Folder
local highlight: Highlight
local localTarget: string? = nil
type Bar = { Gui: BillboardGui, Set: (number, string?) -> () }
local bars: { [string]: Bar } = {}

-- Fired when the local player picks a target (for the tutorial).
Farming.OnTarget = nil :: ((id: string) -> ())?

local function character(): (Model?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	return char, char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function currentTarget(): string?
	local t = player:GetAttribute("Target")
	if type(t) == "string" and t ~= "" then
		return t
	end
	return nil
end

local function refreshHighlight()
	local id = localTarget or currentTarget()
	local info = Breakables.Get(id)
	if info then
		highlight.Adornee = info.Model
		highlight.Enabled = true
	else
		highlight.Adornee = nil
		highlight.Enabled = false
	end
end

-- HP bars -------------------------------------------------------------------

local function ensureBar(info: Breakables.Info): Bar?
	local existing = bars[info.Id]
	if existing then
		return existing
	end
	local adornee = info.Model.PrimaryPart or info.Model:FindFirstChildWhichIsA("BasePart", true)
	if not adornee then
		return nil
	end
	local gui: BillboardGui = Kit.new("BillboardGui", {
		Name = "HpBar",
		Adornee = adornee,
		Size = UDim2.fromOffset(120, 22),
		StudsOffsetWorldSpace = Vector3.new(info.Center.X, info.Center.Y + info.Size.Y / 2 + 1.4, info.Center.Z) - (adornee :: BasePart).Position,
		AlwaysOnTop = false,
		MaxDistance = 90,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	local _, set = Kit.bar({ Size = UDim2.fromScale(1, 1), Parent = gui }, Theme.Colors.Good)
	gui.Parent = info.Model
	local entry: Bar = { Gui = gui, Set = set }
	bars[info.Id] = entry
	return entry
end

local function updateBar(info: Breakables.Info, force: boolean?)
	local hp = info.Model:GetAttribute("Hp")
	local maxHp = info.Model:GetAttribute("MaxHp")
	if type(hp) ~= "number" or type(maxHp) ~= "number" or maxHp <= 0 then
		return
	end
	local isTarget = info.Id == (localTarget or currentTarget())
	if hp >= maxHp and not isTarget and not force then
		local existing = bars[info.Id]
		if existing then
			existing.Gui.Enabled = false
		end
		return
	end
	local entry = ensureBar(info)
	if entry then
		entry.Gui.Enabled = true
		entry.Set(hp / maxHp, Format.num(hp))
	end
end

local function watchBreakable(info: Breakables.Info)
	info.Model:GetAttributeChangedSignal("Hp"):Connect(function()
		updateBar(info)
	end)
	updateBar(info)
end

-- Picking ---------------------------------------------------------------------

local function pick(screenPos: Vector2): Breakables.Info?
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local char = character()
	-- 1. raycast (works when breakable parts are queryable)
	local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { fxFolder }
	if char then
		table.insert(exclude, char)
	end
	local pets = Workspace:FindFirstChild("ClientPets")
	if pets then
		table.insert(exclude, pets)
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if hit then
		local info = Breakables.FromModel(hit.Instance)
		if info then
			return info
		end
	end
	-- 2. screen-space pick: nearest breakable whose projected size covers the
	-- tap (generous so small coin piles are easy to hit with a finger)
	local best: Breakables.Info? = nil
	local bestScore = math.huge
	local halfFov = math.tan(math.rad(cam.FieldOfView / 2))
	local vh = cam.ViewportSize.Y
	for _, info in Breakables.All() do
		if info.Model.Parent == nil then
			continue
		end
		local p, onScreen = cam:WorldToScreenPoint(info.Center)
		if onScreen and p.Z > 0 then
			local radiusPx = (math.max(info.Size.X, info.Size.Y, info.Size.Z) / 2) / (p.Z * halfFov) * (vh / 2)
			local d = (Vector2.new(p.X, p.Y) - screenPos).Magnitude
			local reach = radiusPx + 26
			if d <= reach then
				local score = d / reach + p.Z * 0.002
				if score < bestScore then
					bestScore = score
					best = info
				end
			end
		end
	end
	return best
end

local function setTarget(id: string?)
	localTarget = id
	Remote.Fire("SetTarget", id)
	refreshHighlight()
	if id then
		local info = Breakables.Get(id)
		if info then
			updateBar(info, true)
		end
	end
	-- fall back to the server's value shortly after
	task.delay(1.5, function()
		if localTarget == id then
			localTarget = nil
			refreshHighlight()
		end
	end)
end

local function onTap(screenPos: Vector2)
	local info = pick(screenPos)
	local current = localTarget or currentTarget()
	if info then
		if info.Id == current then
			setTarget(nil)
			Sounds.Play("Click", 0.8)
			return
		end
		local d = State.Data
		if d and info.Area ~= "" and not d.Areas[info.Area] then
			Toasts.Show(Theme.Icons.Lock .. " Open this island's gate first!", "bad")
			return
		end
		local _, root = character()
		if root and (root.Position - info.Center).Magnitude > Config.MaxTargetDistance then
			Toasts.Show("Too far away! Walk closer.", "info")
			return
		end
		if d and #d.Equipped == 0 then
			Toasts.Show("Equip a pet first! Open " .. Theme.Icons.Pets .. " Pets.", "info")
			return
		end
		setTarget(info.Id)
		Sounds.Play("Target")
		local cb = Farming.OnTarget
		if cb then
			cb(info.Id)
		end
	elseif current then
		setTarget(nil)
	end
end

-- Effects -------------------------------------------------------------------

local function nearCamera(pos: Vector3, range: number): boolean
	local cam = Workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude <= range
end

local function breakPop(pos: Vector3, kind: string?)
	if not nearCamera(pos, 160) then
		return
	end
	Sounds.Play("Break", 0.9 + math.random() * 0.3)
	local color = if kind == "GemRock" then Theme.Colors.Gems else Theme.Colors.Coins
	-- expanding ring
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.new(1, 1, 1)
	ring.Transparency = 0.3
	ring.Size = Vector3.new(1, 1, 1)
	ring.CFrame = CFrame.new(pos)
	ring.Parent = fxFolder
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = Vector3.new(9, 9, 9), Transparency = 1 }):Play()
	task.delay(0.4, function()
		ring:Destroy()
	end)
	-- chunks
	for _ = 1, 9 do
		local chunk = Instance.new("Part")
		chunk.Anchored = true
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.Material = Enum.Material.SmoothPlastic
		chunk.Color = if math.random() < 0.5 then color else Theme.Lighten(color, 0.4)
		local s = 0.5 + math.random() * 0.6
		chunk.Size = Vector3.new(s, s, s)
		chunk.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		chunk.Parent = fxFolder
		local dir = Vector3.new(math.random() * 2 - 1, 0.6 + math.random(), math.random() * 2 - 1).Unit
		local goal = pos + dir * (4 + math.random() * 4)
		TweenService:Create(chunk, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {
			CFrame = CFrame.new(goal) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, 0.1),
		}):Play()
		task.delay(0.6, function()
			chunk:Destroy()
		end)
	end
end

local function floatText(pos: Vector3, text: string, color: Color3, offset: number)
	if not nearCamera(pos, 200) then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 3 + offset, 0))
	anchor.Parent = fxFolder
	local gui: BillboardGui = Kit.new("BillboardGui", {
		Size = UDim2.fromOffset(200, 50),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = anchor,
		Parent = anchor,
	})
	local label = Kit.fitLabel(text, 36, {
		Size = UDim2.fromScale(1, 1),
		Color = color,
		Outline = Theme.Darken(color, 0.6),
		Parent = gui,
	})
	Kit.pop(label, 0.4)
	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { CFrame = anchor.CFrame + Vector3.new(0, 4, 0) }):Play()
	task.delay(0.7, function()
		Kit.tween(label, 0.4, { TextTransparency = 1 })
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			Kit.tween(st, 0.4, { Transparency = 1 })
		end
	end)
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

local function onReward(data: { [string]: any })
	local pos = if typeof(data.Position) == "Vector3" then data.Position :: Vector3 else nil
	local coins = if type(data.Coins) == "number" then data.Coins else 0
	local gems = if type(data.Gems) == "number" then data.Gems else 0
	if pos then
		if coins > 0 then
			floatText(pos, "+" .. Format.num(coins) .. " " .. Theme.Icons.Coins, Theme.Colors.Coins, 0)
			Hud.FlyFrom(pos, "Coins", math.clamp(math.floor(math.log10(coins + 1) * 2), 2, 7))
		end
		if gems > 0 then
			floatText(pos, "+" .. Format.num(gems) .. " " .. Theme.Icons.Gems, Theme.Colors.Gems, 1.6)
			Hud.FlyFrom(pos, "Gems", math.clamp(gems, 1, 5))
		end
	else
		if coins > 0 then
			Hud.Bump("Coins")
			Sounds.Play("Coin")
		end
		if gems > 0 then
			Hud.Bump("Gems")
			Sounds.Play("Gem")
		end
	end
end

function Farming.Init()
	local f = Instance.new("Folder")
	f.Name = "ClientFx"
	f.Parent = Workspace
	fxFolder = f
	local h = Instance.new("Highlight")
	h.Name = "TargetHighlight"
	h.FillColor = Color3.fromRGB(255, 230, 90)
	h.FillTransparency = 0.7
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Enabled = false
	h.Parent = f
	highlight = h

	Breakables.Added:Connect(watchBreakable)
	for _, info in Breakables.All() do
		watchBreakable(info)
	end
	Breakables.Removed:Connect(function(id: string)
		bars[id] = nil
		if localTarget == id then
			localTarget = nil
		end
		refreshHighlight()
	end)

	player:GetAttributeChangedSignal("Target"):Connect(function()
		local t = currentTarget()
		if localTarget and t == localTarget then
			localTarget = nil
		end
		refreshHighlight()
		local info = Breakables.Get(t)
		if info then
			updateBar(info, true)
		end
	end)

	-- touch: TouchTapInWorld only fires for taps that miss the UI
	UserInputService.TouchTapInWorld:Connect(function(pos: Vector2, processed: boolean)
		if processed then
			return
		end
		onTap(pos)
	end)
	-- mouse: a short click without dragging
	local downAt: Vector2? = nil
	local downTime = 0
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			downAt = Vector2.new(input.Position.X, input.Position.Y)
			downTime = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local start = downAt
		downAt = nil
		if processed or not start then
			return
		end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if os.clock() - downTime < 0.4 and (pos - start).Magnitude < 12 then
			onTap(pos)
		end
	end)

	State.Notify:Connect(function(kind: string, data: { [string]: any })
		if kind == "Broken" then
			local pos = if typeof(data.Position) == "Vector3" then data.Position :: Vector3 else nil
			if pos then
				breakPop(pos, if type(data.Kind) == "string" then data.Kind else nil)
			end
			if type(data.Id) == "string" and data.Id == localTarget then
				localTarget = nil
				refreshHighlight()
			end
		elseif kind == "Reward" then
			onReward(data)
		end
	end)
end

return Farming
