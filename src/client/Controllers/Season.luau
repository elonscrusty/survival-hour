--!nonstrict
-- Seasonal look (Config.Seasons; the server sets the workspace "Season" attribute): a colour
-- grade, a thin ground mist that follows the camera, and jack-o'-lanterns built from
-- primitives round the lobby fire and beside your own Campfire in a match.
-- Client-side and purely visual: nothing is placed at other players' camps (no position
-- hints), nothing collides or can be targeted, and gameplay never changes.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Seasons = require(Shared:WaitForChild("Logic"):WaitForChild("Seasons"))
local Build = require(Shared:WaitForChild("Models"):WaitForChild("Build"))

local Season = {}

local player = Players.LocalPlayer

-- The running season's Config entry, or nil (shared with the Lobby banner / Locker tags).
function Season.Current(): any
	return Seasons.Find(Config.Seasons :: any, workspace:GetAttribute("Season"))
end

-- A small carved pumpkin: squashed orange ball, stem, glowing eyes and mouth, a warm light.
local function lantern(cf: CFrame, glow: Color3, parent: Instance): Model
	local m = Build.Model("JackOLantern", parent)
	local body = Build.Decor({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 1.9, 2.4), CFrame = cf, Color = Color3.fromRGB(226, 112, 28), Material = Enum.Material.SmoothPlastic, Parent = m })
	Build.Decor({ Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 0.35, 0.35), CFrame = cf * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(80)), Color = Color3.fromRGB(80, 110, 50), Material = Enum.Material.Wood, Parent = m })
	local face = { { -0.45, 0.25, 0.4, 0.35 }, { 0.45, 0.25, 0.4, 0.35 }, { 0, -0.3, 1, 0.22 } }
	for i, f in face do
		Build.Decor({ Name = "Face" .. i, Size = Vector3.new(f[3], f[4], 0.12), CFrame = cf * CFrame.new(f[1], f[2], -1.08), Color = glow, Material = Enum.Material.Neon, CastShadow = false, Parent = m })
	end
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 10
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = body
	m.PrimaryPart = body
	return m
end

-- Ground height under a point (ignores our own decor and characters).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function ground(pos: Vector3, ignore: { Instance }): number
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -20, 0), rayParams)
	return if hit then hit.Position.Y else pos.Y
end

function Season.Start()
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "SeasonGrade"
	grade.Parent = Lighting
	-- ground mist: one soft emitter that follows the camera (cheap on mobile)
	local holder = Instance.new("Part")
	holder.Name = "SeasonMist"
	holder.Size = Vector3.new(110, 1, 110)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Parent = workspace.CurrentCamera
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Rate = 0
	mist.Lifetime = NumberRange.new(7, 10)
	mist.Speed = NumberRange.new(0.4, 1.2)
	mist.SpreadAngle = Vector2.new(180, 10)
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 14) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.88), NumberSequenceKeypoint.new(1, 1) })
	mist.RotSpeed = NumberRange.new(-8, 8)
	mist.LightInfluence = 1
	mist.Parent = holder

	local decor = Instance.new("Folder")
	decor.Name = "SeasonDecor"
	decor.Parent = workspace
	local lights: { PointLight } = {}
	local lobbyDone = false
	local campFire: Model? = nil -- own Campfire decorated this match
	local active: any = nil

	local function clearDecor()
		decor:ClearAllChildren()
		table.clear(lights)
		lobbyDone = false
		campFire = nil
	end
	local function place(cf: CFrame, glow: Color3, parent: Instance)
		local m = lantern(cf, glow, parent)
		local light = (m.PrimaryPart :: BasePart):FindFirstChildOfClass("PointLight")
		if light then
			table.insert(lights, light)
		end
	end

	local function apply()
		local s = Season.Current()
		if s == active then
			return
		end
		active = s
		local atmo = s and s.Atmosphere
		local info = TweenInfo.new(3)
		TweenService:Create(grade, info, {
			TintColor = if atmo then atmo.Tint else Color3.new(1, 1, 1),
			Saturation = if atmo then atmo.Saturation or 0 else 0,
			Contrast = if atmo then atmo.Contrast or 0 else 0,
		}):Play()
		mist.Color = ColorSequence.new(if atmo and atmo.Mist then atmo.Mist else Color3.new(1, 1, 1))
		mist.Rate = if atmo and atmo.Mist then 6 else 0
		clearDecor()
	end
	workspace:GetAttributeChangedSignal("Season"):Connect(apply)
	apply()

	-- Lanterns: placed once round the lobby fire, and beside your own Campfire when it exists.
	task.spawn(function()
		while true do
			local atmo = active and active.Atmosphere
			if atmo and atmo.Glow then
				local char = player.Character
				local ignore = { decor, char or decor }
				if not lobbyDone then
					local lobby = workspace:FindFirstChild("Lobby")
					local fire = lobby and lobby:FindFirstChild("LobbyFire")
					if fire and fire:IsA("Model") then
						lobbyDone = true
						local c = fire:GetPivot().Position
						for i = 0, 5 do
							local a = math.rad(i * 60)
							local p = c + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
							local y = ground(p, ignore)
							place(CFrame.lookAt(Vector3.new(p.X, y + 0.9, p.Z), Vector3.new(c.X, y + 0.9, c.Z)), atmo.Glow, decor)
						end
					end
				end
				if campFire and not campFire.Parent then
					-- match over (or the camp was rebuilt): drop its lanterns
					local old = decor:FindFirstChild("Camp")
					if old then
						old:Destroy()
					end
					for i = #lights, 1, -1 do
						if not lights[i].Parent then
							table.remove(lights, i)
						end
					end
					campFire = nil
				end
				local team = player:GetAttribute("Team")
				local match = workspace:FindFirstChild("Match")
				if not campFire and match and team and player:GetAttribute("InMatch") then
					for _, fire in match:GetDescendants() do
						if fire.Name == "Campfire" and fire:IsA("Model") and fire:GetAttribute("Team") == team then
							campFire = fire
							local folder = Instance.new("Folder")
							folder.Name = "Camp"
							folder.Parent = decor
							local c = fire:GetPivot().Position
							for _, a in { 0.6, 3.7 } do
								local p = c + Vector3.new(math.cos(a) * 5.5, 0, math.sin(a) * 5.5)
								local y = ground(p, { decor, fire, char or decor })
								place(CFrame.lookAt(Vector3.new(p.X, y + 0.9, p.Z), Vector3.new(c.X, y + 0.9, c.Z)), atmo.Glow, folder)
							end
							break
						end
					end
				end
			end
			task.wait(4)
		end
	end)

	-- Mist follows the camera near the ground; lantern lights flicker a little.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if mist.Rate > 0 then
			local cam = workspace.CurrentCamera.CFrame.Position
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local y = if root then root.Position.Y - 2.5 else cam.Y - 4
			holder.CFrame = CFrame.new(cam.X, y, cam.Z)
		end
		acc += dt
		if acc < 0.12 or #lights == 0 then
			return
		end
		acc = 0
		for _, l in lights do
			if l.Parent then
				l.Brightness = 1.2 + math.random() * 0.5
			end
		end
	end)
end

return Season
