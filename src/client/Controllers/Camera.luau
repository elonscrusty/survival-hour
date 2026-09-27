--!nonstrict
-- Third-person camera with limited zoom (StarterPlayer: 6–24 studs), an
-- over-the-shoulder aim mode, a crosshair, and the shared aim-direction helper
-- used by combat and building.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require("../State")
local UI = require("../UI/UI")

local CameraCtl = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

CameraCtl.Aiming = false
local crosshair: Frame? = nil

local function character(): Model?
	return player.Character
end

function CameraCtl.Start()
	player.CameraMaxZoomDistance = Config.Camera.MaxZoom
	player.CameraMinZoomDistance = Config.Camera.MinZoom

	local gui = UI.new("ScreenGui", { Name = "Crosshair", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3, Parent = player:WaitForChild("PlayerGui") })
	local ch = UI.new("Frame", { Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = gui })
	for _, spec in { { 0, -9, 2, 7 }, { 0, 9, 2, 7 }, { -9, 0, 7, 2 }, { 9, 0, 7, 2 } } do
		UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, spec[1], 0.5, spec[2]), Size = UDim2.fromOffset(spec[3], spec[4]), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = ch }, { UI.new("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4 }) })
	end
	UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.fromRGB(255, 200, 120), BorderSizePixel = 0, Parent = ch })
	crosshair = ch

	RunService:BindToRenderStep("SurvivalHourAim", Enum.RenderPriority.Camera.Value + 1, function()
		local char = character()
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not root then
			return
		end
		-- Climber passive: faster upward climbing (the character is client-simulated).
		local bonus = (player:GetAttribute("ClimbBonus") :: number?) or 0
		if bonus > 0 and hum:GetState() == Enum.HumanoidStateType.Climbing then
			local v = root.AssemblyLinearVelocity
			if v.Y > 0.5 then
				local target = hum.WalkSpeed * 0.7 * (1 + bonus)
				if v.Y < target then
					root.AssemblyLinearVelocity = Vector3.new(v.X, target, v.Z)
				end
			end
		end
		if CameraCtl.Aiming and hum.Health > 0 then
			hum.AutoRotate = false
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		else
			hum.AutoRotate = true
		end
	end)
end

function CameraCtl.SetAiming(on: boolean)
	if CameraCtl.Aiming == on then
		return
	end
	CameraCtl.Aiming = on
	local char = character()
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		TweenService:Create(hum, TweenInfo.new(0.15), { CameraOffset = if on then Vector3.new(2.2, 0.6, 0) else Vector3.zero }):Play()
	end
	TweenService:Create(camera, TweenInfo.new(0.15), { FieldOfView = if on then Config.Camera.AimFov else Config.Camera.DefaultFov }):Play()
	if crosshair then
		crosshair.Visible = on
	end
	if not State.Get("IsTouch") then
		UserInputService.MouseBehavior = if on then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	end
end

-- Direction from the character's head toward what the player is aiming at.
-- PC without aim: through the mouse cursor. Aiming / touch / gamepad: screen centre.
function CameraCtl.AimDirection(assist: boolean?): Vector3
	local char = character()
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
		return camera.CFrame.LookVector
	end
	local ray: Ray
	local useMouse = not CameraCtl.Aiming and not State.Get("IsTouch") and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
	if useMouse then
		local m = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(m.X, m.Y)
	else
		local vp = camera.ViewportSize
		ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char :: Instance }
	params.IgnoreWater = true
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local target = if hit then hit.Position else ray.Origin + ray.Direction * 500
	local dir = target - head.Position
	if dir.Magnitude < 0.5 then
		dir = camera.CFrame.LookVector
	end
	dir = dir.Unit
	if assist and State.Get("IsTouch") then
		dir = CameraCtl._assist(head.Position, dir)
	end
	return dir
end

-- Touch aim assist: nudge toward the closest enemy/animal inside a small cone.
function CameraCtl._assist(origin: Vector3, dir: Vector3): Vector3
	local best, bestAngle = nil, math.rad(Config.Combat.AimAssistAngle)
	local myTeam = player:GetAttribute("Team")
	local function consider(part: BasePart?)
		if not part then
			return
		end
		local to = part.Position - origin
		if to.Magnitude > 200 then
			return
		end
		local ang = math.acos(math.clamp(dir:Dot(to.Unit), -1, 1))
		if ang < bestAngle then
			best, bestAngle = to.Unit, ang
		end
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("InMatch") and p:GetAttribute("Team") ~= myTeam and p.Character then
			consider(p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso") :: BasePart?)
		end
	end
	local match = workspace:FindFirstChild("Match")
	local wild = match and match:FindFirstChild("Wildlife")
	if wild then
		for _, m in wild:GetChildren() do
			if m:IsA("Model") then
				consider(m.PrimaryPart)
			end
		end
	end
	return best or dir
end

return CameraCtl
