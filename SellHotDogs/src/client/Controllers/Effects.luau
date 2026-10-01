--!strict
-- Sounds and short build/cash effects. Repeated effects are throttled so very fast production
-- never floods the screen or speakers. Effects never change timing or grants.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)

local Effects = {}

-- Engine-bundled sounds (shipped with every Roblox client). Replace with uploaded originals
-- from assets/audio when available (see docs/ASSET_PROVENANCE.md).
local SOUNDS = {
	click = "rbxasset://sounds/clickfast.wav",
	cash = "rbxasset://sounds/electronicpingshort.wav",
	build = "rbxasset://sounds/swoosh.wav",
	error = "rbxasset://sounds/button.wav",
}
local lastPlayed: { [string]: number } = {}

function Effects.play(name: string, volume: number?, minGap: number?)
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < (minGap or 0.08) then
		return
	end
	lastPlayed[name] = now
	local id = SOUNDS[name]
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 3)
end

local function myPlot(): Instance?
	local i = Players.LocalPlayer:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Plots")
	return if plots and i then plots:FindFirstChild("Plot" .. tostring(i)) else nil
end
Effects.myPlot = myPlot

local function modelFor(plot: Instance, id: string): Instance?
	if id:sub(1, 4) == "biz:" then
		return plot:FindFirstChild(id:sub(5))
	elseif id:sub(1, 5) == "tier:" then
		local rest = id:sub(6)
		local biz, t = rest:match("^(.-):(%d+)$")
		return plot:FindFirstChild("Tier_" .. tostring(biz) .. "_" .. tostring(t))
	elseif id:sub(1, 6) == "decor:" then
		return plot:FindFirstChild("Decor_" .. id:sub(7))
	end
	return plot:FindFirstChild("Prop_" .. id)
end

-- Grow a model out of the ground (client-side only; the server copy is untouched).
local function growIn(m: Model)
	local ok = pcall(function()
		m:ScaleTo(0.05)
	end)
	if not ok then
		return
	end
	local v = Instance.new("NumberValue")
	v.Value = 0.05
	v.Changed:Connect(function(x)
		pcall(function()
			m:ScaleTo(math.max(0.05, x))
		end)
	end)
	local tw = Kit.tween(v, 0.55, { Value = 1 }, Enum.EasingStyle.Back)
	tw.Completed:Connect(function()
		pcall(function()
			m:ScaleTo(1)
		end)
		v:Destroy()
	end)
end

local function confetti(at: Vector3, amount: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(at)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(14, 26)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Size = NumberSequence.new(0.9, 0.2)
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Kit.C.ketchup),
		ColorSequenceKeypoint.new(0.5, Kit.C.mustard),
		ColorSequenceKeypoint.new(1, Kit.C.green),
	})
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = p
	e:Emit(amount)
	Debris:AddItem(p, 3)
end
Effects.confetti = confetti

-- Small camera bump so a purchase is felt.
local function bump()
	local ch = Players.LocalPlayer.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	task.spawn(function()
		for i = 1, 6 do
			hum.CameraOffset = Vector3.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.5, 0) * (1 - i / 7)
			task.wait(0.03)
		end
		hum.CameraOffset = Vector3.zero
	end)
end

-- Newly built things in the player's plot: grow in, confetti, sound, bump.
function Effects.built(ids: { string })
	local plot = myPlot()
	if not plot then
		return
	end
	Effects.play("build", 0.6, 0.2)
	local count = 0
	for _, id in ids do
		local m = modelFor(plot, id)
		if m and m:IsA("Model") then
			count += 1
			if count > 6 then
				break -- a big catch-up (rejoin/reset) only animates a few
			end
			growIn(m)
			local okPivot, pivot = pcall(function()
				return m:GetPivot()
			end)
			if okPivot then
				confetti(pivot.Position + Vector3.new(0, 4, 0), 40)
			end
			local h = Instance.new("Highlight")
			h.FillColor = Kit.C.mustard
			h.OutlineColor = Kit.C.white
			h.FillTransparency = 0.4
			h.Parent = m
			Kit.tween(h, 1.2, { FillTransparency = 1, OutlineTransparency = 1 })
			Debris:AddItem(h, 1.3)
		end
	end
	if count > 0 then
		bump()
	end
end

function Effects.init()
	State.Notify:Connect(function(kind, data)
		if kind == "built" then
			Effects.built(data)
		elseif kind == "cash" then
			Effects.play("cash", 0.5, 0.15)
		elseif kind == "toast" and data.kind == "error" then
			Effects.play("error", 0.3, 0.3)
		end
	end)
end

return Effects
