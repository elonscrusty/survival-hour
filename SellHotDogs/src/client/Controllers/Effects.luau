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

-- Flash newly built things in the player's plot.
function Effects.built(ids: { string })
	local plot = myPlot()
	if not plot then
		return
	end
	Effects.play("build", 0.6, 0.2)
	for _, id in ids do
		local name = if id:sub(1, 4) == "biz:" then id:sub(5) else "Prop_" .. id
		local m = plot:FindFirstChild(name)
		if m then
			local h = Instance.new("Highlight")
			h.FillColor = Kit.C.mustard
			h.OutlineColor = Kit.C.white
			h.FillTransparency = 0.2
			h.Parent = m
			Kit.tween(h, 1.2, { FillTransparency = 1, OutlineTransparency = 1 })
			Debris:AddItem(h, 1.3)
		end
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
