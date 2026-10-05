-- Animates every pet this client can see, using Logic/PetAnim:
--   * ridden pets (in characters) and following pets (workspace.Pets)
--   * preview pets in viewports (hatch reveal, pet menu), registered by those screens
-- Part-built pets are posed through their "J_<Joint>" Welds; uploaded mesh pets
-- through Bones with the same names. Everything here is local and visual only.
-- Also: the local player's sit pose while riding, blinking, dust puffs when running,
-- a landing squash and happy hops (hatching, levelling up).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PetAnim = require(Shared.Logic.PetAnim)
local Net = require(Shared.Net)

local PetAnimator = {}

local player = Players.LocalPlayer
local sitTrack: AnimationTrack? = nil

-- Mesh bones are authored in Blender, whose bone axes differ from Roblox's:
-- rotations/moves about X and Z flip sign. (Check in Studio once models are uploaded.)
local BONE_AXIS = { X = -1, Y = 1, Z = -1 }

type Joint = { Weld: Weld?, Bone: Bone?, Rest: CFrame }
type Rig = {
	Model: Model,
	Root: BasePart?,
	Joints: { [string]: Joint },
	Eyes: { { Mesh: SpecialMesh, Scale: Vector3 } },
	Shines: { BasePart },
	Open: number,
	Grounded: boolean,
	MoveT: number,
	Seed: number,
	Phase: number,
	Air: number,
	Land: number,
	Happy: number,
	HappyUntil: number,
	Look: number,
	LookGoal: number,
	LookAt: number,
	LastPos: Vector3?,
	Speed: number,
	VelY: number,
	Size: number,
	Dust: ParticleEmitter?,
	Preview: boolean,
	Owner: Player?,
}

local rigs: { [Model]: Rig } = {}
local onScreen: (Instance) -> boolean

local function scan(model: Model, preview: boolean, owner: Player?): Rig
	local joints = {}
	local eyes = {}
	local shines = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and string.sub(d.Name, 1, 2) == "J_" then
			joints[string.sub(d.Name, 3)] = { Weld = d, Rest = d.C0 }
		elseif d:IsA("Bone") and table.find(PetAnim.Joints, d.Name) then
			joints[d.Name] = { Bone = d, Rest = CFrame.new() }
		elseif d:IsA("BasePart") and d.Name == "Eye" then
			-- blink by squashing the eye's SpecialMesh (cheap; no physics rebuild)
			local m = d:FindFirstChildOfClass("SpecialMesh")
			if m then
				table.insert(eyes, { Mesh = m, Scale = m.Scale })
			end
		elseif d:IsA("BasePart") and d.Name == "Shine" then
			table.insert(shines, d)
		end
	end
	local _, size = model:GetBoundingBox()
	local root = model.PrimaryPart
	local r: Rig = {
		Model = model,
		Root = root,
		Joints = joints,
		Eyes = eyes,
		Shines = shines,
		Open = 1,
		Grounded = true,
		MoveT = 0,
		Seed = math.random(1, 1000),
		Phase = math.random() * 6,
		Air = 0,
		Land = 0,
		Happy = 0,
		HappyUntil = 0,
		Look = 0,
		LookGoal = 0,
		LookAt = 0,
		Speed = 0,
		VelY = 0,
		Size = size.Y,
		Preview = preview,
		Owner = owner,
	}
	if root and not preview then
		local dust = Instance.new("ParticleEmitter")
		dust.Name = "Dust"
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Color = ColorSequence.new(Color3.fromRGB(235, 225, 205))
		dust.Transparency = NumberSequence.new(0.35, 1)
		dust.Size = NumberSequence.new(0.6, 2.2)
		dust.Lifetime = NumberRange.new(0.4, 0.7)
		dust.Speed = NumberRange.new(1, 3)
		dust.SpreadAngle = Vector2.new(60, 60)
		dust.EmissionDirection = Enum.NormalId.Top
		dust.Rate = 0
		dust.LightInfluence = 0.5
		dust.Parent = root
		r.Dust = dust
	end
	rigs[model] = r
	model.Destroying:Once(function()
		rigs[model] = nil
	end)
	return r
end

-- Screens with a preview pet call this so it idles, blinks and (optionally) hops.
function PetAnimator.Register(model: Model, happySeconds: number?)
	local r = rigs[model] or scan(model, true, nil)
	if happySeconds then
		r.HappyUntil = os.clock() + happySeconds
	end
end

-- Makes the local player's pet hop for a moment (level up, win).
function PetAnimator.Cheer(seconds: number)
	local char = player.Character
	local pet = char and char:FindFirstChild("RiddenPet")
	if pet and pet:IsA("Model") then
		local r = rigs[pet] or scan(pet, false, player)
		r.HappyUntil = os.clock() + seconds
	end
end

local function toCF(o: PetAnim.Offset, ax: { X: number, Y: number, Z: number }?): CFrame
	local sx, sy, sz = 1, 1, 1
	if ax then
		sx, sy, sz = ax.X, ax.Y, ax.Z
	end
	return CFrame.new(o.x * sx, o.y * sy, o.z * sz) * CFrame.Angles(o.rx * sx, o.ry * sy, o.rz * sz)
end

local function step(r: Rig, dt: number, now: number, vel: Vector3?)
	-- Movement: from the rider's root, or from how far the pet moved since last frame.
	local root = r.Root
	if not r.Preview and root then
		local v = vel
		if not v then
			-- Followers: the replicated position arrives in steps, so measure the move
			-- over the time since it last changed and skip frames where it didn't.
			local pos = root.Position
			r.MoveT += dt
			if r.LastPos and pos ~= r.LastPos then
				v = (pos - r.LastPos) / math.max(r.MoveT, 1 / 60)
				r.MoveT = 0
			elseif r.MoveT > 0.25 then
				v = Vector3.zero
			end
			if not r.LastPos or pos ~= r.LastPos then
				r.LastPos = pos
			end
		end
		if v then
			local flat = Vector3.new(v.X, 0, v.Z).Magnitude
			r.Speed += (flat - r.Speed) * math.min(1, dt * 8)
			r.VelY += (v.Y - r.VelY) * math.min(1, dt * 10)
		end
	end
	local run = math.clamp(r.Speed / 22, 0, 1)
	local airborne = math.abs(r.VelY) > 6
	if airborne then
		r.Grounded = false
	elseif not r.Grounded then
		-- touchdown (once): squash and a puff of dust
		r.Grounded = true
		if r.Air > 0.6 then
			r.Land = 1
			if r.Dust then
				r.Dust:Emit(10)
			end
		end
	end
	r.Air += ((if airborne then 1 else 0) - r.Air) * math.min(1, dt * 10)
	r.Land = math.max(0, r.Land - dt * 4)
	r.Happy += ((if now < r.HappyUntil then 1 else 0) - r.Happy) * math.min(1, dt * 6)
	if now > r.LookAt then
		r.LookAt = now + 1.5 + math.random() * 3
		r.LookGoal = (math.random() - 0.5) * 1.1
	end
	r.Look += (r.LookGoal - r.Look) * math.min(1, dt * 3)
	r.Phase += PetAnim.CycleSpeed(run) * dt

	local pose = PetAnim.Sample({ Run = run, Air = r.Air, Land = r.Land, Happy = r.Happy, Look = r.Look, Size = r.Size }, now + r.Seed, r.Phase)
	for name, j in r.Joints do
		local o = pose[name]
		if o then
			if j.Weld then
				j.Weld.C0 = j.Rest * toCF(o)
			elseif j.Bone then
				j.Bone.Transform = toCF(o, BONE_AXIS)
			end
		end
	end
	local open = math.max(0.08, PetAnim.Blink(now, r.Seed))
	if open ~= r.Open then
		r.Open = open
		for _, e in r.Eyes do
			e.Mesh.Scale = Vector3.new(e.Scale.X, e.Scale.Y * open, e.Scale.Z)
		end
		for _, sh in r.Shines do
			sh.LocalTransparencyModifier = if open < 0.5 then 1 else 0
		end
	end
	if r.Dust then
		r.Dust.Rate = if run > 0.45 and r.Air < 0.3 then 14 * run else 0
	end
end

local function stopSit()
	if sitTrack then
		local t = sitTrack
		sitTrack = nil
		t:Stop(0.2)
		task.delay(0.3, function()
			t:Destroy()
		end)
	end
end

local function updateSit()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not player:GetAttribute("Riding") or not animator or not char then
		stopSit()
		return
	end
	if sitTrack then
		return
	end
	-- The sit pose from the character's default Animate script.
	local animate = char:FindFirstChild("Animate")
	local sit = animate and animate:FindFirstChild("sit")
	local anim = sit and sit:FindFirstChildOfClass("Animation")
	if not anim then
		return
	end
	local track = (animator :: Animator):LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.2)
	sitTrack = track
end

-- Is this preview model's ViewportFrame visible (every GUI ancestor shown)?
onScreen = function(m: Instance): boolean
	local node = m.Parent
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("ScreenGui") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

function PetAnimator.Start()
	player:GetAttributeChangedSignal("Riding"):Connect(updateSit)
	player.CharacterAdded:Connect(function()
		sitTrack = nil
		task.wait(0.5)
		updateSit()
	end)
	updateSit()
	Net.Event("Notify").OnClientEvent:Connect(function(_, kind)
		if kind == "Level" then
			PetAnimator.Cheer(1.5)
		end
	end)
	Net.Event("Race").OnClientEvent:Connect(function(kind, data)
		if kind == "Results" and data and data.Mine and data.Mine.Place == 1 then
			PetAnimator.Cheer(3)
		end
	end)

	local pets: Instance? = workspace:FindFirstChild("Pets")
	if not pets then
		task.spawn(function()
			pets = workspace:WaitForChild("Pets", 60)
		end)
	end
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		-- ridden pets: use the rider's real velocity
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local pet = char and char:FindFirstChild("RiddenPet")
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if pet and pet:IsA("Model") and hrp then
				local r = rigs[pet] or scan(pet, false, p)
				step(r, dt, now, hrp.AssemblyLinearVelocity)
			end
		end
		-- followers
		if pets then
			for _, m in (pets :: Instance):GetChildren() do
				if m:IsA("Model") then
					step(rigs[m] or scan(m, false, nil), dt, now, nil)
				end
			end
		end
		-- previews (only while their viewport is actually on screen); forget world
		-- pets that were removed without being destroyed
		for m, r in rigs do
			if r.Preview then
				if m.Parent and onScreen(m) then
					step(r, dt, now, nil)
				end
			elseif not m.Parent then
				rigs[m] = nil
			end
		end
	end)
end

return PetAnimator
