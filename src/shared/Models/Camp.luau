--!nonstrict
-- Camp models: campfire (burning / extinguished states), workbench (3 levels),
-- spawn pads, banners and a clan-themed hut. Pivot = ground centre.

local Build = require("./Build")
local Skins = require("./Skins")

local Camp = {}

local STONE = Color3.fromRGB(120, 118, 112)
local WOOD = Color3.fromRGB(130, 92, 58)
local WOOD_DARK = Color3.fromRGB(92, 64, 40)
local CHAR = Color3.fromRGB(40, 34, 30)

local function place(m: Model, primary: BasePart, cf: CFrame, parent: Instance?): Model
	Build.SetPivot(m, primary, CFrame.new())
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	return m
end

function Camp.Campfire(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("Campfire")
	local base = Build.Part({ Name = "Hearth", Size = Vector3.new(7, 0.6, 7), CFrame = CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(70, 62, 56), Material = Enum.Material.Slate, Parent = m })
	-- stone ring
	for i = 0, 9 do
		local a = math.rad(i * 36)
		Build.Part({ Name = "RingStone", Size = Vector3.new(1.6, 1.2, 1.3), CFrame = CFrame.new(math.cos(a) * 3.6, 0.6, math.sin(a) * 3.6) * CFrame.Angles(0, -a, 0.1 * (i % 3)), Color = if i % 2 == 0 then STONE else Color3.fromRGB(100, 98, 94), Material = Enum.Material.Slate, Parent = m })
	end
	-- logs in a teepee
	for i = 0, 4 do
		local a = math.rad(i * 72)
		Build.Part({ Name = "Log", Size = Vector3.new(0.9, 4.6, 0.9), CFrame = CFrame.new(math.cos(a) * 0.9, 1.9, math.sin(a) * 0.9) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(-22)), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	end
	local embers = Build.Decor({ Name = "Embers", Size = Vector3.new(3, 0.4, 3), CFrame = CFrame.new(0, 0.7, 0), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Parent = m })
	local core = Build.Decor({ Name = "FireCore", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 2.6, 0), Transparency = 1, Parent = m })

	local fire = Instance.new("Fire")
	fire.Name = "Flame"
	fire.Size = 9
	fire.Heat = 14
	fire.Color = Color3.fromRGB(255, 140, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = core

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Range = 40
	light.Brightness = 2.2
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Shadows = true
	light.Parent = core

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Rate = 8
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Speed = NumberRange.new(4, 8)
	sparks.SpreadAngle = Vector2.new(20, 20)
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20))
	sparks.Acceleration = Vector3.new(0, 3, 0)
	sparks.Parent = core

	local smoke = Instance.new("Smoke")
	smoke.Name = "Smoke"
	smoke.Color = Color3.fromRGB(90, 90, 90)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 4
	smoke.Size = 2
	smoke.Enabled = false
	smoke.Parent = core

	-- Light-radius ring (visible guide for "animals avoid this"), faint team tint.
	local ring = Build.Decor({ Name = "SafeRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 90, 90), CFrame = CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = teamColor, Material = Enum.Material.ForceField, Transparency = 0.85, Parent = m, CastShadow = false })
	ring:SetAttribute("TeamTint", true)

	embers:SetAttribute("Burning", true)
	place(m, base, cf, parent)
	-- mesh-pack look; the Fire/Glow/Sparks/Smoke on FireCore and the team SafeRing stay
	if Skins.Enabled() then
		Skins.Dress(m, "SM_Campfire_Burning", { scale = 1.2, keep = { SafeRing = true } })
	end
	return m
end

-- Burning look for a fire level (1-5) and fuel (0..1): higher levels are bigger,
-- brighter and smokier; a nearly empty fire shrinks so owners can read it at a glance.
function Camp.SetFire(m: Model, level: number, fuel: number)
	local core = m:FindFirstChild("FireCore")
	if not core then
		return
	end
	local lv = math.clamp(level, 1, 5) - 1
	local f = 0.45 + 0.55 * math.clamp(fuel / 0.3, 0, 1) -- full size above 30% fuel
	local flame = core:FindFirstChild("Flame") :: Fire?
	if flame and flame.Enabled then
		flame.Size = (9 + lv * 2.2) * f
		flame.Heat = 14 + lv * 3
	end
	local glow = core:FindFirstChild("Glow") :: PointLight?
	if glow and glow.Enabled then
		glow.Range = math.min(60, (40 + lv * 5) * (0.6 + 0.4 * f))
		glow.Brightness = (2.2 + lv * 0.35) * f
		-- a starving fire burns deep red; a healthy one warm gold
		if not m:GetAttribute("FlameSkin") then
			local starving = math.clamp(1 - fuel / 0.15, 0, 1)
			glow.Color = Color3.fromRGB(255, 190, 110):Lerp(Color3.fromRGB(255, 90, 40), starving)
		end
	end
	if flame and flame.Enabled and not m:GetAttribute("FlameSkin") then
		local starving = math.clamp(1 - fuel / 0.15, 0, 1)
		flame.Color = Color3.fromRGB(255, 150, 50):Lerp(Color3.fromRGB(200, 60, 20), starving)
		flame.SecondaryColor = Color3.fromRGB(255, 220, 120):Lerp(Color3.fromRGB(120, 30, 10), starving)
	end
	local sparks = core:FindFirstChild("Sparks") :: ParticleEmitter?
	if sparks and sparks.Enabled then
		sparks.Rate = (8 + lv * 5) * f
	end
	local smoke = core:FindFirstChild("Smoke") :: Smoke?
	if smoke then
		smoke.Enabled = lv > 0
		smoke.Opacity = 0.08 + lv * 0.05
		smoke.Size = 2 + lv
	end
end

-- Switches a campfire model to its extinguished look (permanent).
function Camp.Extinguish(m: Model)
	Skins.Swap(m, "SM_Campfire_Extinguished")
	local core = m:FindFirstChild("FireCore")
	if core then
		local flame = core:FindFirstChild("Flame") :: Fire?
		if flame then
			flame.Enabled = false
		end
		local glow = core:FindFirstChild("Glow") :: PointLight?
		if glow then
			glow.Enabled = false
		end
		local sparks = core:FindFirstChild("Sparks") :: ParticleEmitter?
		if sparks then
			sparks.Enabled = false
		end
		local smoke = core:FindFirstChild("Smoke") :: Smoke?
		if smoke then
			smoke.Enabled = true
			smoke.Opacity = 0.35
		end
	end
	local embers = m:FindFirstChild("Embers") :: BasePart?
	if embers then
		embers.Color = CHAR
		embers.Material = Enum.Material.Slate
	end
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") and d.Name == "Log" then
			d.Color = CHAR
		end
	end
	local ring = m:FindFirstChild("SafeRing") :: BasePart?
	if ring then
		ring.Transparency = 1
	end
end

-- Workbench. Level changes add visible upgrades (vice, tool rack, anvil + banner).
function Camp.Workbench(cf: CFrame, level: number, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("Workbench")
	local top = Build.Part({ Name = "Top", Size = Vector3.new(8, 0.8, 4), CFrame = CFrame.new(0, 3.4, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = m })
	for _, x in { -3.4, 3.4 } do
		for _, z in { -1.5, 1.5 } do
			Build.Part({ Name = "Leg", Size = Vector3.new(0.7, 3, 0.7), CFrame = CFrame.new(x, 1.5, z), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m })
		end
	end
	Build.Part({ Name = "Shelf", Size = Vector3.new(7.4, 0.4, 3.4), CFrame = CFrame.new(0, 1, 0), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks, Parent = m, CanCollide = false })
	-- level 1: saw + log
	Build.Decor({ Name = "Saw", Size = Vector3.new(3, 0.1, 0.8), CFrame = CFrame.new(-1.5, 3.85, 0.6), Color = Color3.fromRGB(190, 190, 196), Material = Enum.Material.Metal, Parent = m })
	Build.Cyl("LogPiece", 2.2, 1.2, CFrame.new(2.2, 4.4, -0.6) * CFrame.Angles(math.rad(90), 0, 0), WOOD, Enum.Material.Wood, m, false)
	if level >= 2 then
		-- tool rack with rope coil
		Build.Part({ Name = "Rack", Size = Vector3.new(8, 4, 0.4), CFrame = CFrame.new(0, 5.8, 1.9), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks, Parent = m, CanCollide = false })
		Build.Cyl("Rope", 0.6, 1.6, CFrame.new(-2.5, 6, 1.6) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(205, 180, 120), Enum.Material.Fabric, m, false)
		Build.Decor({ Name = "Hide", Size = Vector3.new(2.2, 2.4, 0.15), CFrame = CFrame.new(1.6, 6, 1.65), Color = Color3.fromRGB(150, 92, 60), Material = Enum.Material.Fabric, Parent = m })
	end
	if level >= 3 then
		-- anvil + team pennant
		Build.Part({ Name = "Anvil", Size = Vector3.new(2.2, 1.2, 1.2), CFrame = CFrame.new(5.6, 2.2, 0), Color = Color3.fromRGB(70, 72, 78), Material = Enum.Material.Metal, Parent = m })
		Build.Part({ Name = "AnvilBase", Size = Vector3.new(1.2, 1.6, 1.2), CFrame = CFrame.new(5.6, 0.8, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m })
		Build.Decor({ Name = "Pennant", Class = "WedgePart", Size = Vector3.new(0.1, 2.4, 3), CFrame = CFrame.new(-4.2, 7.6, 1.9) * CFrame.Angles(0, math.rad(90), math.rad(180)), Color = teamColor, Material = Enum.Material.Fabric, Parent = m })
	end
	if level >= 4 then
		-- Tier IV: stone forge with glowing coals and a chimney
		Build.Part({ Name = "Forge", Size = Vector3.new(3.4, 2.6, 3), CFrame = CFrame.new(-6.4, 1.3, 0.4), Color = Color3.fromRGB(96, 90, 86), Material = Enum.Material.Brick, Parent = m })
		local coals = Build.Decor({ Name = "ForgeCoals", Size = Vector3.new(2.4, 0.3, 2), CFrame = CFrame.new(-6.4, 2.7, 0.4), Color = Color3.fromRGB(255, 110, 40), Material = Enum.Material.Neon, Parent = m })
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 140, 70)
		glow.Range = 12
		glow.Brightness = 1.4
		glow.Parent = coals
		Build.Part({ Name = "ForgeChimney", Size = Vector3.new(1.4, 5, 1.4), CFrame = CFrame.new(-6.9, 5.2, 1.3), Color = Color3.fromRGB(80, 76, 72), Material = Enum.Material.Brick, Parent = m, CanCollide = false })
	end
	if level >= 5 then
		-- Tier V: steel-plated top and a rack of steel tools
		Build.Decor({ Name = "SteelPlate", Size = Vector3.new(8.1, 0.12, 4.1), CFrame = CFrame.new(0, 3.86, 0), Color = Color3.fromRGB(170, 176, 186), Material = Enum.Material.DiamondPlate, Parent = m })
		for i = -1, 1 do
			Build.Decor({ Name = "SteelTool", Size = Vector3.new(0.25, 2.6, 0.25), CFrame = CFrame.new(i * 1.6 + 0.5, 6.4, 1.62), Color = Color3.fromRGB(196, 202, 212), Material = Enum.Material.Metal, Parent = m })
		end
	end
	local lvl = Build.Decor({ Name = "LevelPlate", Size = Vector3.new(2.4, 1, 0.1), CFrame = CFrame.new(0, 2.6, -2.05), Color = teamColor, Material = Enum.Material.SmoothPlastic, Parent = m })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(120, 50)
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = ({ "I", "II", "III", "IV", "V" })[level] or ("LV " .. level)
	tl.Font = Enum.Font.GothamBlack
	tl.TextScaled = true
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.Parent = sg
	sg.Parent = lvl
	m:SetAttribute("Level", level)
	place(m, top, cf, parent)
	if Skins.Enabled() then
		-- Tier IV/V have their own meshes (forge, steel top); without them the L3 mesh
		-- is used and the procedural forge / steel parts stay visible.
		local own = level >= 4 and Skins.Has("SM_Workbench_Level0" .. math.min(level, 5))
		local name = if own then "SM_Workbench_Level0" .. math.min(level, 5) else "SM_Workbench_Level0" .. math.clamp(level, 1, 3)
		local scale = if own then 1.0 else ({ 1.3, 1.12, 1.0 })[math.clamp(level, 1, 3)]
		local keep = if own then { Pennant = true, ForgeCoals = true } else { Pennant = true, Forge = true, ForgeCoals = true, ForgeChimney = true, SteelPlate = true, SteelTool = true }
		Skins.Dress(m, name, { scale = scale, keep = keep })
	end
	return m
end

function Camp.SpawnPad(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("SpawnPad")
	local pad = Build.Part({ Name = "Pad", Size = Vector3.new(5, 0.4, 5), CFrame = CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(120, 100, 80), Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Decor({ Name = "Mark", Size = Vector3.new(3, 0.1, 3), CFrame = CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(45), 0), Color = teamColor, Material = Enum.Material.Fabric, Parent = m, CastShadow = false })
	return place(m, pad, cf, parent)
end

function Camp.Banner(cf: CFrame, teamColor: Color3, symbol: string, parent: Instance?): Model
	local m = Build.Model("Banner")
	local pole = Build.Cyl("Pole", 14, 0.6, CFrame.new(0, 7, 0), WOOD_DARK, Enum.Material.Wood, m)
	Build.Part({ Name = "Cross", Size = Vector3.new(5, 0.4, 0.4), CFrame = CFrame.new(0, 13.4, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	local cloth = Build.Decor({ Name = "Cloth", Size = Vector3.new(4.4, 6, 0.15), CFrame = CFrame.new(0, 10.2, 0.2), Color = teamColor, Material = Enum.Material.Fabric, Parent = m })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.CanvasSize = Vector2.new(100, 140)
		sg.LightInfluence = 1
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = symbol
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamBlack
		tl.TextColor3 = Color3.fromRGB(255, 248, 230)
		tl.Parent = sg
		sg.Parent = cloth
	end
	return place(m, pole, cf, parent)
end

-- Decorative hut whose style depends on the clan motif.
function Camp.Hut(cf: CFrame, motif: string, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("Hut")
	local wallColor = if motif == "Cedar" then Color3.fromRGB(150, 84, 58)
		elseif motif == "Slate" then Color3.fromRGB(110, 114, 120)
		elseif motif == "Antler" then Color3.fromRGB(120, 100, 84)
		else Color3.fromRGB(170, 140, 90)
	local roofColor = if motif == "Slate" then Color3.fromRGB(70, 76, 88)
		elseif motif == "Thatch" then Color3.fromRGB(200, 170, 90)
		else Build.Tint(teamColor, 0.7)
	local roofMat = if motif == "Thatch" then Enum.Material.Grass elseif motif == "Slate" then Enum.Material.Slate else Enum.Material.WoodPlanks
	local floor = Build.Part({ Name = "Floor", Size = Vector3.new(12, 0.6, 10), CFrame = CFrame.new(0, 0.3, 0), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Part({ Name = "Back", Size = Vector3.new(12, 7, 0.8), CFrame = CFrame.new(0, 3.8, 4.6), Color = wallColor, Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Part({ Name = "Side", Size = Vector3.new(0.8, 7, 9.2), CFrame = CFrame.new(5.6, 3.8, 0), Color = wallColor, Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Part({ Name = "Side", Size = Vector3.new(0.8, 7, 9.2), CFrame = CFrame.new(-5.6, 3.8, 0), Color = wallColor, Material = Enum.Material.WoodPlanks, Parent = m })
	-- open front with posts
	for _, x in { -5.6, 5.6 } do
		Build.Part({ Name = "Post", Size = Vector3.new(0.9, 7, 0.9), CFrame = CFrame.new(x, 3.8, -4.6), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m })
	end
	Build.Part({ Class = "WedgePart", Name = "Roof", Size = Vector3.new(13.4, 3.5, 5.8), CFrame = CFrame.new(0, 9.05, -2.5) * CFrame.Angles(0, math.rad(180), 0), Color = roofColor, Material = roofMat, Parent = m })
	Build.Part({ Class = "WedgePart", Name = "Roof", Size = Vector3.new(13.4, 3.5, 5.8), CFrame = CFrame.new(0, 9.05, 2.9), Color = roofColor, Material = roofMat, Parent = m })
	if motif == "Antler" then
		for _, x in { -2, 2 } do
			for i = 0, 2 do
				Build.Decor({ Name = "Antler", Size = Vector3.new(0.35, 2.2, 0.35), CFrame = CFrame.new(x, 11 + i * 0.6, 0.2) * CFrame.Angles(0, 0, math.rad((x > 0 and -1 or 1) * (20 + i * 25))), Color = Color3.fromRGB(230, 220, 196), Material = Enum.Material.SmoothPlastic, Parent = m })
			end
		end
	elseif motif == "Slate" then
		local lantern = Build.Decor({ Name = "Lantern", Size = Vector3.new(1, 1.4, 1), CFrame = CFrame.new(4.6, 6.4, -4.9), Color = teamColor, Material = Enum.Material.Neon, Parent = m })
		local l = Instance.new("PointLight")
		l.Color = teamColor
		l.Range = 14
		l.Brightness = 1.2
		l.Parent = lantern
	end
	-- bedrolls in team colour
	for _, x in { -3, 0, 3 } do
		Build.Decor({ Name = "Bedroll", Size = Vector3.new(2.2, 0.5, 5), CFrame = CFrame.new(x, 0.85, 1.4), Color = Build.Tint(teamColor, 0.85), Material = Enum.Material.Fabric, Parent = m })
	end
	return place(m, floor, cf, parent)
end

function Camp.Lantern(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("LanternPost")
	local post = Build.Cyl("Post", 7, 0.5, CFrame.new(0, 3.5, 0), WOOD_DARK, Enum.Material.Wood, m)
	Build.Part({ Name = "Arm", Size = Vector3.new(1.8, 0.3, 0.3), CFrame = CFrame.new(0.8, 6.8, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	local lamp = Build.Decor({ Name = "Lamp", Size = Vector3.new(0.9, 1.2, 0.9), CFrame = CFrame.new(1.5, 6, 0), Color = Color3.fromRGB(255, 214, 140), Material = Enum.Material.Neon, Parent = m })
	local l = Instance.new("PointLight")
	l.Range = 16
	l.Brightness = 1.4
	l.Color = Color3.fromRGB(255, 200, 130):Lerp(teamColor, 0.25)
	l.Parent = lamp
	place(m, post, cf, parent)
	if Skins.Enabled() then
		Skins.Dress(m, "SM_Camp_Lantern", { scale = 1.3, offset = CFrame.Angles(0, math.pi, 0) }) -- the PointLight keeps working in the hidden lamp
	end
	return m
end

return Camp
