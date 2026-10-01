--!strict
-- Local theme lighting: tints the sky haze and colour grade to the local player's egg theme
-- (Data/Themes fog / ambient / accent). Client-only changes, tweened, never replicated.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared:WaitForChild("Data"):WaitForChild("Eggs"))
local Kit = require(Shared:WaitForChild("Models"):WaitForChild("Kit"))

local ThemeLighting = {}

local TWEEN = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local current: string? = nil
local tint: ColorCorrectionEffect? = nil
local original: { [string]: any }? = nil

function ThemeLighting.Init()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ThemeTint"
	cc.Parent = Lighting
	tint = cc
	original = { OutdoorAmbient = Lighting.OutdoorAmbient }
end

function ThemeLighting.Apply(egg: number?)
	local e = Eggs.List[math.clamp(math.floor(tonumber(egg) or 1), 1, Eggs.Count)]
	if not e or e.theme == current then
		return
	end
	current = e.theme
	local pal = Kit.Palette(e.theme)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		local dark = (pal.fog.R + pal.fog.G + pal.fog.B) / 3 < 0.4
		TweenService:Create(atmo, TWEEN, {
			Color = pal.fog,
			Decay = pal.fog:Lerp(Color3.new(0, 0, 0), 0.3),
			Haze = if dark then 2.2 else 1.2,
			Density = if dark then 0.36 else 0.28,
		}):Play()
	end
	local cc = tint
	if cc then
		TweenService:Create(cc, TWEEN, {
			TintColor = Color3.new(1, 1, 1):Lerp(pal.accent, 0.07),
			Saturation = 0.04,
		}):Play()
	end
	local base = original and original.OutdoorAmbient
	if typeof(base) == "Color3" then
		TweenService:Create(Lighting, TWEEN, { OutdoorAmbient = base:Lerp(pal.ambient, 0.35) }):Play()
	end
end

function ThemeLighting.Destroy()
	if tint then
		tint:Destroy()
		tint = nil
	end
	if original and typeof(original.OutdoorAmbient) == "Color3" then
		Lighting.OutdoorAmbient = original.OutdoorAmbient
	end
	current = nil
end

return ThemeLighting
