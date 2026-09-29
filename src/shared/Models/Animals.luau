--!nonstrict
-- Wildlife rigs built from primitives: wolf, bear, deer, rabbit, boar (+ bat).
--
-- Wolf and Bear: a Humanoid with an invisible HumanoidRootPart. Visible body
-- parts are welded/Motor6D'd so the client-side CreatureAnimator can drive
-- leg, head and tail joints procedurally (no uploaded animations exist; see
-- DECISIONS D34). Motor6D names used by the animator: LegFL, LegFR, LegBL,
-- LegBR, Neck, Tail.
-- Bat: a physics-driven flyer (AlignPosition/AlignOrientation) with WingL/WingR motors.
--
-- Mesh look: once a species' part meshes are uploaded (blender/assets/animals.py,
-- SM_<Species>_Body/Head/LegF/LegB/Tail, SM_Bat_Body/Wing), each one is welded to
-- its rig part and the primitive parts are hidden. The parts keep their joints,
-- names and hitbox role, so the procedural animation moves the meshes.

local Build = require("./Build")
local Skins = require("./Skins")

local Animals = {}

export type Spec = { Body: Color3, Dark: Color3, Belly: Color3, Scale: number, Eye: Color3 }

local function motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p0
	return m
end

local function bodyPart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
	return Build.Part({ Name = name, Size = size, CFrame = CFrame.new(), Color = color, Material = material or Enum.Material.Fabric, Parent = parent, Anchored = false, CanCollide = false, CanQuery = true, Massless = true, Shape = shape })
end

local function weld(p0: BasePart, p1: BasePart, offset: CFrame)
	p1.CFrame = p0.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p1
end

-- Shared quadruped builder.
local function quadruped(name: string, spec: Spec, dims: { [string]: number }): Model
	local s = spec.Scale
	local m = Build.Model(name)
	local hrp = Build.Part({ Name = "HumanoidRootPart", Size = Vector3.new(dims.W, dims.H, dims.L) * s, CFrame = CFrame.new(0, 0, 0), Transparency = 1, Parent = m, Anchored = false, CanCollide = true, CanQuery = true })
	m.PrimaryPart = hrp

	local torso = bodyPart(m, "Torso", Vector3.new(dims.W, dims.H * 0.9, dims.L) * s, spec.Body)
	motor("Body", hrp, torso, CFrame.new(0, 0, 0), CFrame.new())
	local belly = bodyPart(m, "Belly", Vector3.new(dims.W * 0.8, dims.H * 0.3, dims.L * 0.8) * s, spec.Belly)
	weld(torso, belly, CFrame.new(0, -dims.H * 0.35 * s, 0))
	local chest = bodyPart(m, "Chest", Vector3.new(dims.W * 1.1, dims.H * 1.05, dims.L * 0.4) * s, spec.Dark)
	weld(torso, chest, CFrame.new(0, 0.1 * s, -dims.L * 0.35 * s))

	-- Head on a neck motor
	local head = bodyPart(m, "Head", Vector3.new(dims.W * 0.8, dims.H * 0.75, dims.L * 0.3) * s, spec.Body)
	motor("Neck", torso, head, CFrame.new(0, dims.H * 0.35 * s, -dims.L * 0.55 * s), CFrame.new(0, 0, dims.L * 0.05 * s))
	local snout = bodyPart(m, "Snout", Vector3.new(dims.W * 0.45, dims.H * 0.35, dims.L * 0.25) * s, spec.Belly)
	weld(head, snout, CFrame.new(0, -dims.H * 0.12 * s, -dims.L * 0.2 * s))
	local nose = bodyPart(m, "Nose", Vector3.new(0.3, 0.25, 0.2) * s, Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	weld(snout, nose, CFrame.new(0, 0.1 * s, -dims.L * 0.13 * s))
	for _, x in { -1, 1 } do
		local eye = bodyPart(m, "Eye", Vector3.new(0.22, 0.22, 0.1) * s, spec.Eye, Enum.Material.Neon)
		weld(head, eye, CFrame.new(x * dims.W * 0.22 * s, dims.H * 0.12 * s, -dims.L * 0.151 * s))
		local ear = bodyPart(m, "Ear", Vector3.new(dims.W * 0.18, dims.H * dims.Ear, 0.2 * s) * s, spec.Dark)
		weld(head, ear, CFrame.new(x * dims.W * 0.28 * s, dims.H * 0.45 * s, dims.L * 0.05 * s) * CFrame.Angles(0, 0, math.rad(-x * 12)))
	end

	-- Legs
	local legLen = dims.Leg * s
	for _, leg in { { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } } do
		local part = bodyPart(m, leg[1], Vector3.new(dims.W * 0.28 * s, legLen, dims.W * 0.3 * s), spec.Dark)
		motor(leg[1], torso, part,
			CFrame.new(leg[2] * dims.W * 0.32 * s, -dims.H * 0.3 * s, leg[3] * dims.L * 0.36 * s),
			CFrame.new(0, legLen / 2, 0))
		local paw = bodyPart(m, "Paw", Vector3.new(dims.W * 0.32 * s, 0.3 * s, dims.W * 0.4 * s), spec.Dark)
		weld(part, paw, CFrame.new(0, -legLen / 2, -0.1 * s))
	end

	-- Tail
	local tail = bodyPart(m, "TailPart", Vector3.new(dims.W * 0.2, dims.W * 0.2, dims.Tail) * s, spec.Body)
	motor("Tail", torso, tail, CFrame.new(0, dims.H * 0.25 * s, dims.L * 0.5 * s), CFrame.new(0, 0, -dims.Tail * 0.5 * s) * CFrame.Angles(math.rad(-25), 0, 0))

	local hum = Instance.new("Humanoid")
	-- R15 rig type makes the Humanoid honour HipHeight (R6 would look for leg parts).
	hum.RigType = Enum.HumanoidRigType.R15
	Instance.new("Animator").Parent = hum -- uploaded clips (AnimationIds) play through it
	-- leg top sits 0.3H below centre, root bottom is 0.5H below centre, paws add ~0.15
	hum.HipHeight = legLen - dims.H * 0.2 * s + 0.15 * s
	hum.DisplayName = name
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 0
	hum.HealthDisplayDistance = 60
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.Parent = m
	-- Hitbox parts stay queryable for melee/arrow detection
	return m
end

function Animals.Wolf(): Model
	return quadruped("Wolf", {
		Body = Color3.fromRGB(110, 108, 104),
		Dark = Color3.fromRGB(70, 68, 66),
		Belly = Color3.fromRGB(170, 164, 150),
		Eye = Color3.fromRGB(255, 210, 90),
		Scale = 1,
	}, { W = 1.6, H = 1.7, L = 4.2, Leg = 2.4, Tail = 2.4, Ear = 0.45 })
end

function Animals.Bear(): Model
	return quadruped("Bear", {
		Body = Color3.fromRGB(96, 64, 40),
		Dark = Color3.fromRGB(66, 44, 28),
		Belly = Color3.fromRGB(140, 104, 72),
		Eye = Color3.fromRGB(255, 120, 60),
		Scale = 1.8,
	}, { W = 2.2, H = 2.2, L = 4, Leg = 2.1, Tail = 0.6, Ear = 0.3 })
end

-- Prey and boar (Survival Wars). Same quadruped rig, so the client animator drives them.
local function headOf(m: Model): BasePart
	return m:FindFirstChild("Head") :: BasePart
end

function Animals.Deer(): Model
	local m = quadruped("Deer", {
		Body = Color3.fromRGB(150, 104, 66),
		Dark = Color3.fromRGB(108, 72, 46),
		Belly = Color3.fromRGB(226, 206, 176),
		Eye = Color3.fromRGB(30, 24, 20),
		Scale = 1.1,
	}, { W = 1.3, H = 1.6, L = 3.8, Leg = 3.2, Tail = 0.5, Ear = 0.5 })
	local head = headOf(m)
	for _, x in { -1, 1 } do
		local beam = bodyPart(m, "Antler", Vector3.new(0.18, 1.6, 0.18), Color3.fromRGB(214, 196, 160), Enum.Material.Wood)
		weld(head, beam, CFrame.new(x * 0.35, 1.2, 0.1) * CFrame.Angles(0, 0, math.rad(-x * 25)))
		local tine = bodyPart(m, "Antler", Vector3.new(0.14, 0.8, 0.14), Color3.fromRGB(214, 196, 160), Enum.Material.Wood)
		weld(head, tine, CFrame.new(x * 0.7, 1.6, -0.2) * CFrame.Angles(math.rad(-30), 0, math.rad(-x * 10)))
	end
	return m
end

function Animals.Rabbit(): Model
	local m = quadruped("Rabbit", {
		Body = Color3.fromRGB(150, 130, 110),
		Dark = Color3.fromRGB(120, 100, 84),
		Belly = Color3.fromRGB(236, 228, 214),
		Eye = Color3.fromRGB(20, 20, 20),
		Scale = 0.45,
	}, { W = 1.4, H = 1.4, L = 2.2, Leg = 1.1, Tail = 0.6, Ear = 1.2 })
	return m
end

function Animals.Boar(): Model
	local m = quadruped("Boar", {
		Body = Color3.fromRGB(84, 66, 54),
		Dark = Color3.fromRGB(54, 42, 34),
		Belly = Color3.fromRGB(120, 100, 86),
		Eye = Color3.fromRGB(200, 90, 50),
		Scale = 1.05,
	}, { W = 1.8, H = 1.8, L = 3.4, Leg = 1.5, Tail = 0.6, Ear = 0.35 })
	local snout = m:FindFirstChild("Snout") :: BasePart
	for _, x in { -1, 1 } do
		local tusk = bodyPart(m, "Tusk", Vector3.new(0.16, 0.6, 0.16), Color3.fromRGB(236, 226, 200), Enum.Material.SmoothPlastic)
		weld(snout, tusk, CFrame.new(x * 0.35, 0.2, -0.2) * CFrame.Angles(math.rad(-30), 0, math.rad(-x * 15)))
	end
	return m
end

-- Rig part -> mesh asset. Left and right legs share a mesh; the left bat wing is
-- the right one turned over (a rotation about the forward axis).
local FLIP = CFrame.Angles(0, 0, math.pi)

local function meshesFor(species: string, antlered: boolean?): ({ [string]: string }, { [string]: CFrame })
	if species == "Bat" then
		return { Body = "SM_Bat_Body", WingLPart = "SM_Bat_Wing", WingRPart = "SM_Bat_Wing" }, { WingLPart = FLIP }
	end
	local head = "SM_" .. species .. "_Head"
	if species == "Deer" and (if antlered ~= nil then antlered else math.random() < 0.5) then
		head = "SM_Deer_Head_Antlered" -- bucks and does
	end
	local p = "SM_" .. species .. "_"
	return {
		Torso = p .. "Body",
		Head = head,
		LegFL = p .. "LegF",
		LegFR = p .. "LegF",
		LegBL = p .. "LegB",
		LegBR = p .. "LegB",
		TailPart = p .. "Tail",
	}, {}
end

-- Welds each part's mesh onto it (visual only: massless, no collision or queries).
-- Needs every mesh of the set; otherwise the primitive look stays.
local function dress(m: Model, species: string, antlered: boolean?)
	local set, offsets = meshesFor(species, antlered)
	for _, asset in set do
		if not Skins.Has(asset) then
			return
		end
	end
	-- both deer heads must be in, or some deer would dress and others not
	if species == "Deer" and not (Skins.Has("SM_Deer_Head") and Skins.Has("SM_Deer_Head_Antlered")) then
		return
	end
	Skins.Hide(m)
	-- a doe's hidden primitive antlers must not take hits above its head
	if set.Head == "SM_Deer_Head" then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Antler" then
				d.CanQuery = false
				d.CanTouch = false
			end
		end
	end
	for partName, asset in set do
		local part = m:FindFirstChild(partName) :: BasePart?
		local skin = if part then Skins.Visual(asset) else nil
		if part and skin then
			skin:PivotTo(part.CFrame * (offsets[partName] or CFrame.new()))
			for _, p in skin:GetChildren() do
				if p:IsA("BasePart") then
					p.Anchored = false
					p.Massless = true
					p.Parent = m
					local w = Instance.new("WeldConstraint")
					w.Part0 = part
					w.Part1 = p
					w.Parent = p
				end
			end
			skin:Destroy()
		end
	end
end

-- `antlered` (deer only, optional) forces a buck (true) or doe (false); random otherwise.
function Animals.Build(species: string, antlered: boolean?): Model
	local f = (Animals :: any)[species]
	local m = f()
	dress(m, species, antlered)
	return m
end

function Animals.Bat(): Model
	local m = Build.Model("Bat")
	local body = Build.Part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(), Color = Color3.fromRGB(50, 40, 48), Material = Enum.Material.Fabric, Parent = m, Anchored = false, CanCollide = false, CanQuery = true })
	m.PrimaryPart = body
	local head = bodyPart(m, "Head", Vector3.new(1, 1, 1), Color3.fromRGB(60, 48, 56), Enum.Material.Fabric, Enum.PartType.Ball)
	weld(body, head, CFrame.new(0, 0.3, -0.9))
	for _, x in { -1, 1 } do
		local eye = bodyPart(m, "Eye", Vector3.new(0.18, 0.18, 0.1), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		weld(head, eye, CFrame.new(x * 0.22, 0.1, -0.48))
		local ear = bodyPart(m, "Ear", Vector3.new(0.2, 0.6, 0.2), Color3.fromRGB(50, 40, 48))
		weld(head, ear, CFrame.new(x * 0.25, 0.55, 0))
		local wing = bodyPart(m, if x < 0 then "WingLPart" else "WingRPart", Vector3.new(3.2, 0.1, 1.8), Color3.fromRGB(40, 30, 40), Enum.Material.Fabric)
		motor(if x < 0 then "WingL" else "WingR", body, wing, CFrame.new(x * 0.7, 0.2, 0), CFrame.new(-x * 1.6, 0, 0))
		local tip = Build.Part({ Class = "WedgePart", Name = "WingTip", Size = Vector3.new(0.1, 1.2, 1.6), CFrame = CFrame.new(), Color = Color3.fromRGB(40, 30, 40), Material = Enum.Material.Fabric, Parent = m, Anchored = false, CanCollide = false, CanQuery = false, Massless = true })
		weld(wing, tip, CFrame.new(x * 2, 0, 0.2) * CFrame.Angles(0, 0, math.rad(90 * x)))
	end
	local att = Instance.new("Attachment")
	att.Name = "Fly"
	att.Parent = body
	local ap = Instance.new("AlignPosition")
	ap.Name = "Mover"
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 4000
	ap.MaxVelocity = 26
	ap.Responsiveness = 18
	ap.Parent = body
	local ao = Instance.new("AlignOrientation")
	ao.Name = "Facing"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 4000
	ao.Responsiveness = 20
	ao.Parent = body
	local hum = Instance.new("Humanoid")
	hum.DisplayName = "Bat"
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.HealthDisplayDistance = 50
	hum.NameDisplayDistance = 0
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.PlatformStand = true
	hum.Parent = m
	return m
end

return Animals
