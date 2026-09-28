--!nonstrict
-- Client weather: rain showers chosen by the server (MatchState.Weather).
-- A single rain emitter follows the camera (cheap on mobile), the image gets a
-- little greyer and hazier, and at night distant lightning flashes now and then.
-- Purely visual; gameplay never changes with the weather.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weather = {}

local player = Players.LocalPlayer

function Weather.Start()
	local ms = ReplicatedStorage:WaitForChild("MatchState")
	local holder = Instance.new("Part")
	holder.Name = "RainHolder"
	holder.Size = Vector3.new(90, 1, 90)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Parent = workspace.CurrentCamera
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Rate = 0
	rain.Lifetime = NumberRange.new(0.9, 1.2)
	rain.Speed = NumberRange.new(70, 85)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.Size = NumberSequence.new(0.08)
	rain.Squash = NumberSequence.new(-4) -- long thin streaks
	rain.Transparency = NumberSequence.new(0.55)
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 205, 220))
	rain.LightInfluence = 1
	rain.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	rain.Parent = holder
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "WeatherGrade"
	grade.Parent = Lighting
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "Lightning"
	flash.Parent = Lighting

	local raining = false
	local function apply()
		local want = ms:GetAttribute("Weather") == "Rain" and player:GetAttribute("InMatch") == true
		if want == raining then
			return
		end
		raining = want
		local info = TweenInfo.new(6)
		TweenService:Create(rain, info, { Rate = if want then 600 else 0 }):Play()
		TweenService:Create(grade, info, { Saturation = if want then -0.18 else 0, Brightness = if want then -0.04 else 0, TintColor = if want then Color3.fromRGB(225, 232, 240) else Color3.new(1, 1, 1) }):Play()
	end
	ms:GetAttributeChangedSignal("Weather"):Connect(apply)
	player:GetAttributeChangedSignal("InMatch"):Connect(apply)
	apply()

	local nextFlash = os.clock() + 10
	RunService.Heartbeat:Connect(function()
		if raining then
			local cam = workspace.CurrentCamera.CFrame.Position
			holder.CFrame = CFrame.new(cam + Vector3.new(0, 45, 0))
			-- distant lightning at night: a brief brightening, no damage, no noise spam
			if ms:GetAttribute("Phase") == "Night" and os.clock() > nextFlash then
				nextFlash = os.clock() + math.random(12, 30)
				flash.Brightness = 0.35
				TweenService:Create(flash, TweenInfo.new(0.4), { Brightness = 0 }):Play()
			end
		end
	end)
end

return Weather
