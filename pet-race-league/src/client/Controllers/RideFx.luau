-- Riding feel, all visual and local:
--   * the local player sits on their pet (the default sit pose; played by the owner,
--     so other players see it too)
--   * every ridden pet bounces and leans while it runs, and part-built pets swing
--     their legs (each client animates the pets it can see)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RideFx = {}

local player = Players.LocalPlayer
local sitTrack: AnimationTrack? = nil

local function stopSit()
	if sitTrack then
		sitTrack:Stop(0.2)
		sitTrack = nil
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
	-- The sit animation from the character's default Animate script.
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

-- Per pet: the rest pose of its ride weld and leg joints, and its run phase.
type Rig = { Weld: Weld?, Base: CFrame?, Joints: { { Weld: Weld, Base: CFrame, Phase: number } }, T: number }
local rigs: { [Model]: Rig } = {}

local function rigFor(model: Model): Rig
	local r = rigs[model]
	if r then
		return r
	end
	local joints = {}
	local rideWeld: Weld? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") then
			if d.Name == "LegJoint" then
				table.insert(joints, { Weld = d, Base = d.C0, Phase = d:GetAttribute("Phase") or 0 })
			elseif d.Name == "RideWeld" then
				rideWeld = d
			end
		end
	end
	r = { Weld = rideWeld, Base = rideWeld and rideWeld.C0, Joints = joints, T = 0 }
	rigs[model] = r
	model.Destroying:Once(function()
		rigs[model] = nil
	end)
	return r
end

function RideFx.Start()
	player:GetAttributeChangedSignal("Riding"):Connect(updateSit)
	player.CharacterAdded:Connect(function()
		sitTrack = nil
		task.wait(0.5)
		updateSit()
	end)
	updateSit()

	RunService.RenderStepped:Connect(function(dt)
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local pet = char and char:FindFirstChild("RiddenPet")
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if pet and pet:IsA("Model") and root then
				local r = rigFor(pet)
				local v = root.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				local run = math.clamp(speed / 20, 0, 1)
				r.T += dt * (6 + speed * 0.35)
				local swing = math.sin(r.T) * 0.7 * run
				for _, j in r.Joints do
					j.Weld.C0 = j.Base * CFrame.Angles(math.sin(r.T + j.Phase) * 0.7 * run, 0, 0)
				end
				if r.Weld and r.Base then
					local bob = math.abs(math.sin(r.T)) * 0.35 * run
					local lean = -0.06 * run + swing * 0.04
					r.Weld.C0 = r.Base * CFrame.new(0, bob, 0) * CFrame.Angles(lean, 0, 0)
				end
			end
		end
	end)
end

return RideFx
