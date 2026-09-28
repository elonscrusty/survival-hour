--!nonstrict
-- Procedural wildlife animation + attack warnings (client-side, nearby only).
-- Legs cycle with ground speed; telegraphs (Lunge, Roar, Swipe, Swoop) get a
-- distinct pose, a red flash and a "!" marker so players can react.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Creatures = {}

local player = Players.LocalPlayer

type Rig = { Model: Model, Motors: { [string]: Motor6D }, Phase: number, Flash: Highlight?, Warn: BillboardGui? }
local rigs: { [Model]: Rig } = {}

local function getRig(m: Model): Rig
	local r = rigs[m]
	if r then
		return r
	end
	local motors = {}
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	r = { Model = m, Motors = motors, Phase = math.random() * 10, Flash = nil, Warn = nil }
	rigs[m] = r
	return r
end

local function warnMarker(r: Rig, show: boolean)
	if show and not r.Warn then
		local root = r.Model.PrimaryPart
		if not root then
			return
		end
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(40, 40)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = root
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = "!"
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamBlack
		tl.TextColor3 = Color3.fromRGB(255, 80, 60)
		tl.TextStrokeTransparency = 0
		tl.Parent = bb
		bb.Parent = r.Model
		r.Warn = bb
		local h = Instance.new("Highlight")
		h.FillColor = Color3.fromRGB(255, 60, 40)
		h.FillTransparency = 0.6
		h.OutlineTransparency = 0.2
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = r.Model
		r.Flash = h
	elseif not show and r.Warn then
		r.Warn:Destroy()
		r.Warn = nil
		if r.Flash then
			r.Flash:Destroy()
			r.Flash = nil
		end
	end
end

local function animate(r: Rig, dt: number)
	local m = r.Model
	local root = m.PrimaryPart
	if not root then
		return
	end
	local species = m:GetAttribute("Species")
	local tele = m:GetAttribute("Telegraph") :: string?
	local teleAge = workspace:GetServerTimeNow() - ((m:GetAttribute("TelegraphAt") :: number?) or 0)
	local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
	local M = r.Motors
	local active = tele ~= nil and tele ~= "Dead" and tele ~= "Strike" and teleAge < 1.2
	warnMarker(r, active)

	if species == "Bat" then
		r.Phase += dt * (if tele == "Swoop" and teleAge < 0.6 then 6 else 16)
		local flap = math.sin(r.Phase) * math.rad(55)
		if M.WingL then
			M.WingL.Transform = CFrame.Angles(0, 0, flap)
		end
		if M.WingR then
			M.WingR.Transform = CFrame.Angles(0, 0, -flap)
		end
		return
	end

	r.Phase += dt * math.clamp(speed / 3, 0, 9)
	local amp = math.rad(35) * math.clamp(speed / 10, 0, 1)
	local s = math.sin(r.Phase)
	local legs = { LegFL = s, LegBR = s, LegFR = -s, LegBL = -s }
	for name, v in legs do
		local motor = M[name]
		if motor then
			motor.Transform = CFrame.Angles(v * amp, 0, 0)
		end
	end
	local body = CFrame.identity
	local neck = CFrame.Angles(math.sin(r.Phase * 2) * math.rad(3), 0, 0)
	local t = os.clock()
	if speed < 1 and not active then
		-- idle life: breathing, looking around; prey graze with the head down
		local seed = (m:GetAttribute("AnimalId") or 0) % 7
		local look = math.sin(t * 0.7 + seed) * math.rad(20)
		if (species == "Deer" or species == "Rabbit") and math.sin(t * 0.25 + seed) > 0.3 then
			neck = CFrame.Angles(math.rad(-40), look * 0.3, 0)
		else
			neck = CFrame.Angles(math.sin(t * 1.6) * math.rad(3), look, 0)
		end
		body = CFrame.new(0, math.sin(t * 2.2 + seed) * 0.04, 0)
	end
	if tele == "Dead" then
		-- topple over instead of snapping sideways
		local k = math.clamp(teleAge / 0.6, 0, 1)
		body = CFrame.Angles(0, 0, math.rad(85 * (1 - (1 - k) ^ 2)))
	elseif active then
		if tele == "Lunge" then
			body = CFrame.Angles(math.rad(-10), 0, 0) * CFrame.new(0, -0.4, 0)
			neck = CFrame.Angles(math.rad(-15), 0, 0)
		elseif tele == "Roar" then
			body = CFrame.Angles(math.rad(18), 0, 0)
			neck = CFrame.Angles(math.rad(35), 0, 0)
			if M.LegFL then
				M.LegFL.Transform = CFrame.Angles(math.rad(-40), 0, 0)
			end
			if M.LegFR then
				M.LegFR.Transform = CFrame.Angles(math.rad(-40), 0, 0)
			end
		elseif tele == "Swipe" then
			if M.LegFR then
				M.LegFR.Transform = CFrame.Angles(math.rad(-80 + 60 * math.clamp(teleAge / 0.5, 0, 1)), 0, 0)
			end
			neck = CFrame.Angles(math.rad(-10), math.rad(15), 0)
		end
	elseif tele == "Strike" and teleAge < 0.25 then
		neck = CFrame.Angles(math.rad(-25), 0, 0)
	end
	-- startled: head up, body tense for a moment
	local alertAge = workspace:GetServerTimeNow() - ((m:GetAttribute("AlertAt") :: number?) or 0)
	if alertAge < 0.45 and tele ~= "Dead" then
		local k = math.sin(math.clamp(alertAge / 0.45, 0, 1) * math.pi)
		neck = CFrame.Angles(math.rad(35 * k), 0, 0)
		body = CFrame.Angles(math.rad(6 * k), 0, 0) * body
	end
	-- hit flinch
	local hitAge = workspace:GetServerTimeNow() - ((m:GetAttribute("HitAt") :: number?) or 0)
	if hitAge < 0.25 and tele ~= "Dead" then
		local k = math.sin(hitAge / 0.25 * math.pi)
		body = CFrame.Angles(math.rad(-6 * k), 0, math.rad(8 * k)) * body
		neck = CFrame.Angles(math.rad(15 * k), 0, 0) * neck
	end
	if M.Body then
		M.Body.Transform = body
	end
	if M.Neck then
		M.Neck.Transform = neck
	end
	if M.Tail then
		M.Tail.Transform = CFrame.Angles(0, math.sin(r.Phase * 1.5) * math.rad(20), 0)
	end
end

function Creatures.Start()
	RunService.RenderStepped:Connect(function(dt)
		local match = workspace:FindFirstChild("Match")
		local wild = match and match:FindFirstChild("Wildlife")
		local cam = workspace.CurrentCamera.CFrame.Position
		if wild then
			for _, m in wild:GetChildren() do
				if m:IsA("Model") and m.PrimaryPart and (m.PrimaryPart.Position - cam).Magnitude < 160 then
					animate(getRig(m), dt)
				end
			end
		end
		for m in rigs do
			if not m.Parent then
				rigs[m] = nil
			end
		end
	end)
	local _ = player
end

return Creatures
