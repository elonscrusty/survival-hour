--!nonstrict
-- Client weather (MatchState.Weather): Clear, Cloudy, Rain, Storm, Fog.
-- The server grades lighting and fog; here a single rain emitter follows the camera (cheap
-- on mobile), the image is tinted, and storms add wind-slanted rain, lightning (day or night)
-- and thunder that trails the flash by distance. Purely visual; gameplay never changes.

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
	local storm = false
	local current = ""
	local GRADES = {
		Clear = { 0, 0, Color3.new(1, 1, 1) },
		Cloudy = { -0.06, -0.01, Color3.fromRGB(240, 242, 245) },
		Rain = { -0.18, -0.04, Color3.fromRGB(225, 232, 240) },
		Storm = { -0.28, -0.07, Color3.fromRGB(205, 214, 228) },
		Fog = { -0.1, 0.02, Color3.fromRGB(236, 238, 240) },
	}
	local function apply()
		local w = if player:GetAttribute("InMatch") == true then (ms:GetAttribute("Weather") or "Clear") else "Clear"
		if w == current then
			return
		end
		current = w
		raining = w == "Rain" or w == "Storm"
		storm = w == "Storm"
		local info = TweenInfo.new(6)
		TweenService:Create(rain, info, { Rate = if storm then 1100 elseif raining then 600 else 0 }):Play()
		-- storm wind slants the rain
		rain.Acceleration = if storm then Vector3.new(38, 0, 14) else Vector3.zero
		local g = GRADES[w] or GRADES.Clear
		TweenService:Create(grade, info, { Saturation = g[1], Brightness = g[2], TintColor = g[3] }):Play()
	end
	ms:GetAttributeChangedSignal("Weather"):Connect(apply)
	player:GetAttributeChangedSignal("InMatch"):Connect(apply)
	apply()

	local nextFlash = os.clock() + 10
	RunService.Heartbeat:Connect(function()
		if raining then
			local cam = workspace.CurrentCamera.CFrame.Position
			holder.CFrame = CFrame.new(cam + Vector3.new(0, 45, 0))
			-- lightning: distant flashes at night in a shower, near and frequent in a storm
			if (storm or ms:GetAttribute("Phase") == "Night") and os.clock() > nextFlash then
				nextFlash = os.clock() + (if storm then math.random(6, 16) else math.random(12, 30))
				local near = storm and math.random() < 0.5
				flash.Brightness = if near then 0.6 else 0.35
				TweenService:Create(flash, TweenInfo.new(if near then 0.25 else 0.4), { Brightness = 0 }):Play()
				if storm then
					-- thunder rolls in after the flash (sooner when the strike is close)
					task.delay(if near then 0.4 else math.random(12, 30) / 10, function()
						Weather.Thunder(near)
					end)
				end
			end
		end
	end)
end

-- Set by the Sound controller (keeps sound playback in one place).
Weather.Thunder = function(_near: boolean) end

return Weather
