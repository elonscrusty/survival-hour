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

-- Pooled particle emitters (one anchored holder per effect kind, moved and
-- re-emitted) so harvesting and combat never create parts per hit.
local FX_KINDS = {
	Bark = { Colors = { Color3.fromRGB(120, 84, 52), Color3.fromRGB(196, 160, 110) }, Size = 0.32, Speed = 16, Life = 0.7, Grav = 45, Shape = "Chip" },
	Splinter = { Colors = { Color3.fromRGB(206, 176, 128), Color3.fromRGB(150, 112, 70) }, Size = 0.26, Speed = 14, Life = 0.6, Grav = 40, Shape = "Chip" },
	Stone = { Colors = { Color3.fromRGB(128, 126, 122), Color3.fromRGB(92, 90, 88) }, Size = 0.34, Speed = 15, Life = 0.6, Grav = 55, Shape = "Chip" },
	Leaves = { Colors = { Color3.fromRGB(96, 150, 70), Color3.fromRGB(150, 180, 80) }, Size = 0.4, Speed = 7, Life = 1.3, Grav = 6, Shape = "Leaf" },
	Berries = { Colors = { Color3.fromRGB(170, 40, 70), Color3.fromRGB(90, 140, 60) }, Size = 0.3, Speed = 8, Life = 0.8, Grav = 30, Shape = "Chip" },
	Spores = { Colors = { Color3.fromRGB(210, 240, 190), Color3.fromRGB(160, 220, 150) }, Size = 0.25, Speed = 3, Life = 1.6, Grav = -2, Shape = "Glow" },
	Dust = { Colors = { Color3.fromRGB(150, 138, 120), Color3.fromRGB(110, 100, 90) }, Size = 1.6, Speed = 5, Life = 1.1, Grav = -1, Shape = "Puff" },
	Water = { Colors = { Color3.fromRGB(170, 210, 255), Color3.fromRGB(230, 240, 255) }, Size = 0.4, Speed = 10, Life = 0.7, Grav = 40, Shape = "Chip" },
	Steam = { Colors = { Color3.fromRGB(230, 232, 236), Color3.fromRGB(180, 184, 190) }, Size = 2.4, Speed = 4, Life = 1.8, Grav = -6, Shape = "Puff" },
	Blood = { Colors = { Color3.fromRGB(150, 20, 20), Color3.fromRGB(90, 10, 10) }, Size = 0.25, Speed = 9, Life = 0.5, Grav = 50, Shape = "Chip" },
	Sparks = { Colors = { Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 150, 60) }, Size = 0.18, Speed = 14, Life = 0.35, Grav = 30, Shape = "Glow" },
}
local pool: { [string]: { Holder: BasePart, Emitter: ParticleEmitter } } = {}

local function emitter(kind: string)
	local e = pool[kind]
	if e and e.Holder.Parent then
		return e
	end
	local spec = FX_KINDS[kind] or FX_KINDS.Dust
	local holder = part({ Name = "Fx_" .. kind, Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0
	pe.Color = ColorSequence.new(spec.Colors[1], spec.Colors[2])
	pe.Lifetime = NumberRange.new(spec.Life * 0.6, spec.Life)
	pe.Speed = NumberRange.new(spec.Speed * 0.4, spec.Speed)
	pe.SpreadAngle = Vector2.new(60, 60)
	pe.Acceleration = Vector3.new(0, -spec.Grav, 0)
	pe.Drag = if spec.Shape == "Puff" then 2 else 0.5
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-240, 240)
	if spec.Shape == "Puff" then
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.Size * 0.5), NumberSequenceKeypoint.new(1, spec.Size * 1.6) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		pe.SpreadAngle = Vector2.new(180, 180)
	elseif spec.Shape == "Glow" then
		pe.Size = NumberSequence.new(spec.Size, 0)
		pe.LightEmission = 1
		pe.SpreadAngle = Vector2.new(180, 180)
	else
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.Size), NumberSequenceKeypoint.new(0.8, spec.Size * 0.8), NumberSequenceKeypoint.new(1, 0) })
		pe.Squash = NumberSequence.new(if spec.Shape == "Leaf" then 0.6 else 0.3)
	end
	pe.Parent = holder
	e = { Holder = holder, Emitter = pe }
	pool[kind] = e
	return e
end

-- Emits `count` particles of `kind` at pos, spraying along `dir` (default up).
local function emitAt(kind: string, pos: Vector3, count: number, dir: Vector3?)
	local e = emitter(kind)
	local d = if dir and dir.Magnitude > 0.01 then dir.Unit else Vector3.yAxis
	-- ParticleEmitters spray along the holder's +Y (EmissionDirection Top)
	e.Holder.CFrame = CFrame.lookAt(pos, pos + d) * CFrame.Angles(-math.pi / 2, 0, 0)
	e.Emitter:Emit(count)
end

-- Quick client-side jolt for a struck rock / bush / ore node (visual only).
local jolting: { [Model]: boolean } = {}
local function jolt(m: Model?, from: Vector3?)
	if not m or not m.Parent or jolting[m] then
		return
	end
	jolting[m] = true
	local home = m:GetPivot()
	local away = if from then (home.Position - from) * Vector3.new(1, 0, 1) else Vector3.zero
	local push = if away.Magnitude > 0.01 then away.Unit * 0.18 else Vector3.zero
	task.spawn(function()
		for _, k in { 1, -0.6, 0.3, 0 } do
			if not m.Parent then
				break
			end
			m:PivotTo(home + push * k)
			task.wait(0.03)
		end
		jolting[m] = nil
	end)
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
		emitAt(if d.Kind == "Structure" then "Splinter" else "Blood", d.Pos, if d.Kind == "Structure" then 10 else 6)
	elseif name == "Block" then
		emitAt("Sparks", d.Pos + Vector3.new(0, 1.5, 0), 14)
	elseif name == "StructureBreak" then
		for i = 1, 8 do
			local chunk = part({ Size = Vector3.new(1.2, 0.5, 0.8), Position = d.Pos + Vector3.new(math.random(-3, 3), math.random(1, 6), math.random(-3, 3)), Color = Color3.fromRGB(130, 92, 58), Material = Enum.Material.Wood, Anchored = false })
			chunk.AssemblyLinearVelocity = Vector3.new(math.random(-15, 15), math.random(10, 25), math.random(-15, 15))
			Debris:AddItem(chunk, 3 + i * 0.05)
		end
		burst(d.Pos + Vector3.new(0, 3, 0), Color3.fromRGB(140, 130, 120), 30, 14, 0.8)
	elseif name == "PackageOpen" then
		burst(d.Pos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 170, 70), 40, 20, 0.5)
	elseif name == "Cosmetic" then
		burst(d.Pos, d.Color or Color3.new(1, 1, 1), d.Count or 25, 14, 0.7)
	elseif name == "ResourceHit" then
		-- chips fly back toward the swinger, like a real strike
		local toward = if d.From then (d.From - d.Pos) * Vector3.new(1, 0, 1) + Vector3.new(0, 1.2, 0) else nil
		emitAt(d.Kind or "Dust", d.Pos, if d.Kind == "Leaves" or d.Kind == "Spores" then 8 else 12, toward)
		if d.Kind == "Stone" then
			emitAt("Dust", d.Pos, 3)
			emitAt("Sparks", d.Pos, 4, toward)
		end
		jolt(d.Model, d.From)
	elseif name == "ResourceBreak" then
		emitAt(d.Kind or "Dust", d.Pos, if d.Big then 40 else 22)
		emitAt("Dust", d.Pos, if d.Big then 10 else 5)
	elseif name == "PourStart" then
		emitAt("Water", d.Pos + Vector3.new(0, 2, 0), 18)
		emitAt("Steam", d.Pos + Vector3.new(0, 2, 0), 8)
	elseif name == "FireFed" then
		-- wood hits the fire: a flare of sparks and embers
		emitAt("Sparks", d.Pos + Vector3.new(0, 2, 0), math.clamp(6 + (d.Amount or 1), 8, 30))
		emitAt("Dust", d.Pos + Vector3.new(0, 1, 0), 3)
	elseif name == "BenchUpgrade" then
		emitAt("Sparks", d.Pos + Vector3.new(0, 3, 0), 30)
		emitAt("Dust", d.Pos + Vector3.new(0, 1, 0), 8)
		burst(d.Pos + Vector3.new(0, 4, 0), Color3.fromRGB(255, 210, 120), 20, 10, 0.5)
	elseif name == "Built" then
		emitAt("Dust", d.Pos + Vector3.new(0, 1, 0), 8)
		emitAt("Splinter", d.Pos + Vector3.new(0, 2, 0), 6)
	elseif name == "Healed" then
		-- soft green motes rising around the healed player
		burst(d.Pos + Vector3.new(0, 1, 0), Color3.fromRGB(120, 240, 140), math.clamp((d.Amount or 20) // 4, 6, 25), 5, 0.35)
	elseif name == "Crafted" then
		emitAt("Sparks", d.Pos + Vector3.new(0, 1.5, 0), 10)
	elseif name == "ChestOpened" then
		local rare = d.Tier == "Rare" or d.Tier == "VeryRare"
		if rare then
			-- rare loot: a golden (very rare: violet) flare so it reads as special
			burst(d.Pos + Vector3.new(0, 2, 0), if d.Tier == "VeryRare" then Color3.fromRGB(190, 130, 255) else Color3.fromRGB(255, 205, 90), 45, 14, 0.5)
		end
		emitAt("Dust", d.Pos + Vector3.new(0, 1, 0), if rare then 6 else 3)
	elseif name == "Blood" then
		emitAt("Blood", d.Pos, 8, d.Dir)
	end
end

-- Floating damage number above what you hit (world space, fades up and out).
local function damageNumber(pos: Vector3, amount: number, color: Color3, big: boolean)
	local anchor = part({ Name = "DmgNum", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = pos + Vector3.new(math.random() - 0.5, 2.5, math.random() - 0.5) })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(if big then 110 else 70, if big then 40 else 30)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = anchor
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Theme.FontBlack
	tl.TextScaled = true
	tl.Text = tostring(amount)
	tl.TextColor3 = color
	tl.TextStrokeTransparency = 0.2
	tl.Parent = bb
	TweenService:Create(bb, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 2.2, 0) }):Play()
	TweenService:Create(tl, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.8)
end

local function onHit(h: any)
	if h.Pos and h.Amount and (h.Kind == "Player" or h.Kind == "Animal" or h.Kind == "Headshot") then
		damageNumber(h.Pos, h.Amount, if h.Kind == "Headshot" then Color3.fromRGB(255, 205, 80) elseif h.Kind == "Animal" then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(255, 120, 100), h.Kind == "Headshot")
	end
	if h.Kind == "Hurt" then
		vignette.BackgroundTransparency = 0.55
		TweenService:Create(vignette, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	else
		hitMarker.Text = if h.Kind == "Repair" then "+" .. tostring(h.Amount)
			elseif h.Kind == "Headshot" then "◎ HEADSHOT " .. tostring(h.Amount)
			elseif h.Kind == "GuardBreak" then "GUARD BROKEN"
			else "✖ " .. tostring(h.Amount)
		hitMarker.TextColor3 = if h.Kind == "Repair" then Theme.Colors.Good
			elseif h.Kind == "Structure" then Theme.Colors.Warn
			elseif h.Kind == "Headshot" or h.Kind == "GuardBreak" then Color3.fromRGB(255, 200, 80)
			else Color3.new(1, 1, 1)
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

-- Class / power-up sight: Night Owl brightens nights a little, Miner sees a
-- little better in caves. Local-only colour correction (no x-ray, no outlines).
local function senseSight()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SenseSight"
	cc.Enabled = false
	cc.Parent = game:GetService("Lighting")
	local ms = ReplicatedStorage:WaitForChild("MatchState")
	RunService.Heartbeat:Connect(function()
		local inMatch = player:GetAttribute("InMatch") == true
		local night = ms:GetAttribute("Phase") == "Night"
		local owl = inMatch and night and player:GetAttribute("Perk") == "NightOwl"
		local miner = inMatch and player:GetAttribute("Class") == "Miner" and player:GetAttribute("InCave") == true
		local b = (if owl then 0.07 else 0) + (if miner then 0.08 else 0)
		cc.Enabled = b > 0
		cc.Brightness = b
		cc.Contrast = if b > 0 then 0.05 else 0
	end)
end

function Effects.Start()
	senseSight()
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
				-- spawn / sunrise protection: a soft golden shimmer while it lasts
				local prot = (p:GetAttribute("ProtectedUntil") or 0) > now
				local shield = char:FindFirstChild("ProtectShimmer")
				if prot and not shield then
					local h = Instance.new("Highlight")
					h.Name = "ProtectShimmer"
					h.FillColor = Color3.fromRGB(255, 220, 130)
					h.FillTransparency = 0.82
					h.OutlineColor = Color3.fromRGB(255, 235, 170)
					h.OutlineTransparency = 0.35
					h.DepthMode = Enum.HighlightDepthMode.Occluded
					h.Parent = char
				elseif not prot and shield then
					shield:Destroy()
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
