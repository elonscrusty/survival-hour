--!nonstrict
-- Client visual effects: arrows, gun tracers, impacts, blocks, structure
-- breaks, care-package bursts, water pouring, fire-out steam, damage vignette,
-- hit markers, Trailblazer trails, reveal highlights, Sharpshooter marks,
-- and warmth sparkles at your fire.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ItemModels = require(Shared.Models.ItemModels)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")

local Effects = {}

local player = Players.LocalPlayer
local fxFolder: Folder
local vignette: Frame
local hitMarker: TextLabel
local arrows: { [number]: { Model: Model, Pos: Vector3, Vel: Vector3, Gravity: number, T: number } } = {}
local pourEmitters: { [Model]: ParticleEmitter } = {}
local marks: { [Player]: Highlight } = {}

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = fxFolder
	return p
end

local function burst(pos: Vector3, color: Color3, count: number, speed: number, size: number?)
	local a = part({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = pos })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new(size or 0.4, 0)
	pe.Speed = NumberRange.new(speed * 0.5, speed)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.3, 0.8)
	pe.Acceleration = Vector3.new(0, -20, 0)
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(count)
	Debris:AddItem(a, 2)
end

local function onFx(ev: any)
	local d = ev.Data
	local name = ev.Name
	if name == "Arrow" then
		local m = ItemModels.Held("Arrow")
		if not m then
			return
		end
		for _, x in m:GetDescendants() do
			if x:IsA("BasePart") then
				x.Anchored = true
				x.CanCollide = false
				x.CanQuery = false
			end
		end
		m.Parent = fxFolder
		arrows[d.Id] = { Model = m, Pos = d.Origin, Vel = d.Velocity, Gravity = d.Gravity, T = 0 }
	elseif name == "ArrowStop" then
		local a = arrows[d.Id]
		if a then
			arrows[d.Id] = nil
			a.Model:PivotTo(CFrame.lookAt(d.Pos, d.Pos + a.Vel))
			Debris:AddItem(a.Model, 4)
			burst(d.Pos, Color3.fromRGB(180, 150, 110), 6, 10, 0.25)
		end
	elseif name == "Shot" then
		local len = (d.End - d.Origin).Magnitude
		local beam = part({ Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt((d.Origin + d.End) / 2, d.End), Color = Color3.fromRGB(255, 230, 160), Material = Enum.Material.Neon, Transparency = 0.2 })
		TweenService:Create(beam, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		Debris:AddItem(beam, 0.2)
		burst(d.Origin, Color3.fromRGB(255, 200, 120), 8, 12, 0.3)
		burst(d.End, Color3.fromRGB(160, 150, 140), 6, 8, 0.25)
	elseif name == "Impact" then
		burst(d.Pos, if d.Kind == "Structure" then Color3.fromRGB(170, 130, 90) else Color3.fromRGB(200, 60, 60), 8, 12, 0.3)
	elseif name == "Block" then
		burst(d.Pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 240, 180), 12, 16, 0.25)
	elseif name == "StructureBreak" then
		for i = 1, 8 do
			local chunk = part({ Size = Vector3.new(1.2, 0.5, 0.8), Position = d.Pos + Vector3.new(math.random(-3, 3), math.random(1, 6), math.random(-3, 3)), Color = Color3.fromRGB(130, 92, 58), Material = Enum.Material.Wood, Anchored = false })
			chunk.AssemblyLinearVelocity = Vector3.new(math.random(-15, 15), math.random(10, 25), math.random(-15, 15))
			Debris:AddItem(chunk, 3 + i * 0.05)
		end
		burst(d.Pos + Vector3.new(0, 3, 0), Color3.fromRGB(140, 130, 120), 30, 14, 0.8)
	elseif name == "PackageOpen" then
		burst(d.Pos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 170, 70), 40, 20, 0.5)
	elseif name == "Ability" then
		local color = Color3.fromRGB(180, 220, 255)
		burst(d.Pos, color, 25, 14, 0.5)
	end
end

local function onHit(h: any)
	if h.Kind == "Hurt" then
		vignette.BackgroundTransparency = 0.55
		TweenService:Create(vignette, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	else
		hitMarker.Text = if h.Kind == "Repair" then "+" .. tostring(h.Amount) else "✖ " .. tostring(h.Amount)
		hitMarker.TextColor3 = if h.Kind == "Repair" then Theme.Colors.Good elseif h.Kind == "Structure" then Theme.Colors.Warn else Color3.new(1, 1, 1)
		hitMarker.TextTransparency = 0
		TweenService:Create(hitMarker, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end
end

local function onReveal(r: any)
	for _, item in r.List do
		local pos = if typeof(item) == "Vector3" then item else item.Pos
		local target: Instance? = nil
		if r.Kind == "Animals" then
			local match = workspace:FindFirstChild("Match")
			local wild = match and match:FindFirstChild("Wildlife")
			if wild then
				for _, m in wild:GetChildren() do
					if m:GetAttribute("AnimalId") == item.Id then
						target = m
					end
				end
			end
		end
		if target then
			local h = Instance.new("Highlight")
			h.FillColor = Color3.fromRGB(255, 90, 60)
			h.OutlineColor = Color3.fromRGB(255, 200, 150)
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.FillTransparency = 0.7
			h.Parent = target
			Debris:AddItem(h, r.Duration or 8)
		else
			-- Beacon pillar at the revealed spot (crates or out-of-stream animals)
			local pillar = part({ Size = Vector3.new(1.2, 40, 1.2), Position = pos + Vector3.new(0, 20, 0), Color = if r.Kind == "Crates" then Theme.Colors.Warn else Theme.Colors.Bad, Material = Enum.Material.Neon, Transparency = 0.45 })
			Debris:AddItem(pillar, r.Duration or 8)
		end
	end
end

function Effects.Start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFx"
	fxFolder.Parent = workspace
	local gui = UI.new("ScreenGui", { Name = "Fx", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1, Parent = player:WaitForChild("PlayerGui") })
	vignette = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	hitMarker = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 30, 0.5, -30), Size = UDim2.fromOffset(120, 30), BackgroundTransparency = 1, Font = Theme.FontBlack, TextSize = 22, TextStrokeTransparency = 0.3, TextTransparency = 1, Text = "", Parent = gui })

	State.On("Fx", onFx)
	State.On("Hit", onHit)
	State.On("Reveal", onReveal)
	State.On("MatchEvent", function(ev)
		if ev.Name == "FireOut" then
			local match = workspace:FindFirstChild("Match")
			if match then
				for _, fire in match:GetDescendants() do
					if fire.Name == "Campfire" and fire:IsA("Model") and fire:GetAttribute("Team") == ev.Data.Team and fire.PrimaryPart then
						burst(fire.PrimaryPart.Position + Vector3.new(0, 2, 0), Color3.fromRGB(220, 225, 230), 80, 18, 1.4)
					end
				end
			end
		end
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		-- arrows
		for id, a in arrows do
			a.T += dt
			a.Vel -= Vector3.new(0, a.Gravity * dt, 0)
			a.Pos += a.Vel * dt
			a.Model:PivotTo(CFrame.lookAt(a.Pos, a.Pos + a.Vel))
			if a.T > 4 then
				a.Model:Destroy()
				arrows[id] = nil
			end
		end
		acc += dt
		if acc < 0.15 then
			return
		end
		acc = 0
		-- pouring water streams + Trailblazer trails + Sharpshooter marks
		local now = workspace:GetServerTimeNow()
		local myTeam = player:GetAttribute("Team")
		for _, p in Players:GetPlayers() do
			local char = p.Character
			if char then
				local pouring = char:GetAttribute("Action") == "Pour"
				local held = char:FindFirstChild("HeldItem")
				local em = pourEmitters[char]
				if pouring and held and held:IsA("Model") and held.PrimaryPart and not em then
					local pe = Instance.new("ParticleEmitter")
					pe.Color = ColorSequence.new(Color3.fromRGB(150, 200, 255))
					pe.Size = NumberSequence.new(0.35, 0.1)
					pe.Transparency = NumberSequence.new(0.2, 0.8)
					pe.Speed = NumberRange.new(6, 9)
					pe.Acceleration = Vector3.new(0, -40, 0)
					pe.Lifetime = NumberRange.new(0.5, 0.8)
					pe.Rate = 60
					pe.EmissionDirection = Enum.NormalId.Bottom
					pe.Parent = held.PrimaryPart
					pourEmitters[char] = pe
				elseif not pouring and em then
					em:Destroy()
					pourEmitters[char] = nil
				end
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and (p:GetAttribute("Bursting") or 0) > now and not root:FindFirstChild("BurstTrail") then
					local pe = Instance.new("ParticleEmitter")
					pe.Name = "BurstTrail"
					pe.Color = ColorSequence.new(Color3.fromRGB(120, 230, 150))
					pe.Size = NumberSequence.new(0.6, 0)
					pe.Lifetime = NumberRange.new(0.3, 0.5)
					pe.Rate = 40
					pe.Speed = NumberRange.new(0, 1)
					pe.LightEmission = 0.6
					pe.Parent = root
					Debris:AddItem(pe, math.max(0.2, (p:GetAttribute("Bursting") :: number) - now))
				end
				local marked = p ~= player and p:GetAttribute("MarkedTeam") == myTeam and (p:GetAttribute("MarkedUntil") or 0) > now
				if marked and not marks[p] then
					local h = Instance.new("Highlight")
					h.FillColor = Color3.fromRGB(255, 60, 60)
					h.FillTransparency = 0.75
					h.OutlineColor = Color3.fromRGB(255, 120, 120)
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = char
					marks[p] = h
				elseif not marked and marks[p] then
					marks[p]:Destroy()
					marks[p] = nil
				end
			end
		end
		for char, em in pourEmitters do
			if not char.Parent then
				em:Destroy()
				pourEmitters[char] = nil
			end
		end
	end)
	player:GetAttributeChangedSignal("Warming"):Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			burst(root.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 190, 110), 4, 3, 0.3)
		end
	end)
end

return Effects
