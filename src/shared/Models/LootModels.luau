--!nonstrict
-- Care package (with parachute + beacon) and hidden forest crate.

local Build = require("./Build")
local Skins = require("./Skins")

local LootModels = {}

local CRATE = Color3.fromRGB(120, 140, 90)
local CRATE_DARK = Color3.fromRGB(80, 96, 60)

function LootModels.CarePackage(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("CarePackage")
	local box = Build.Part({ Name = "Box", Size = Vector3.new(5, 4, 5), CFrame = CFrame.new(0, 2, 0), Color = CRATE, Material = Enum.Material.WoodPlanks, Parent = m })
	for _, y in { 0.4, 3.6 } do
		Build.Decor({ Name = "Trim", Size = Vector3.new(5.2, 0.5, 5.2), CFrame = CFrame.new(0, y, 0), Color = CRATE_DARK, Material = Enum.Material.Wood, Parent = m })
	end
	for _, x in { -2.4, 2.4 } do
		Build.Decor({ Name = "Strap", Size = Vector3.new(0.5, 4.2, 5.25), CFrame = CFrame.new(x, 2, 0), Color = Color3.fromRGB(230, 120, 40), Material = Enum.Material.Fabric, Parent = m })
	end
	-- Icon plates on four sides
	for i = 0, 3 do
		local plate = Build.Decor({ Name = "Plate", Size = Vector3.new(2, 2, 0.1), CFrame = CFrame.Angles(0, math.rad(90 * i), 0) * CFrame.new(0, 2, -2.56), Color = Color3.fromRGB(245, 240, 225), Material = Enum.Material.SmoothPlastic, Parent = m })
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(100, 100)
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = "✚"
		tl.TextScaled = true
		tl.TextColor3 = Color3.fromRGB(230, 120, 40)
		tl.Font = Enum.Font.GothamBlack
		tl.Parent = sg
		sg.Parent = plate
	end
	-- Parachute (removed on landing)
	local chute = Build.Model("Parachute", m)
	local canopy = Build.Decor({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(16, 7, 16), CFrame = CFrame.new(0, 17, 0), Color = Color3.fromRGB(235, 120, 50), Material = Enum.Material.Fabric, Parent = chute })
	Build.Decor({ Name = "Inner", Shape = Enum.PartType.Ball, Size = Vector3.new(15, 6, 15), CFrame = CFrame.new(0, 16.6, 0), Color = Color3.fromRGB(245, 240, 225), Material = Enum.Material.Fabric, Parent = chute })
	for i = 0, 3 do
		local a = math.rad(45 + 90 * i)
		local top = Vector3.new(math.cos(a) * 6.5, 15, math.sin(a) * 6.5)
		local bottom = Vector3.new(math.cos(a) * 2.2, 4, math.sin(a) * 2.2)
		local mid = (top + bottom) / 2
		Build.Decor({ Name = "Line", Size = Vector3.new(0.1, 0.1, (top - bottom).Magnitude), CFrame = CFrame.lookAt(mid, top), Color = Color3.fromRGB(230, 230, 230), Material = Enum.Material.SmoothPlastic, Parent = chute, CastShadow = false })
	end
	chute.PrimaryPart = canopy
	-- Beacon (smoke + light) shown after landing
	local beacon = Build.Decor({ Name = "Beacon", Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(0, 4.4, 0), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Parent = m })
	local smoke = Instance.new("Smoke")
	smoke.Name = "Signal"
	smoke.Color = Color3.fromRGB(255, 130, 60)
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 12
	smoke.Size = 4
	smoke.Enabled = false
	smoke.Parent = beacon
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Range = 18
	light.Brightness = 2
	light.Parent = beacon
	Build.SetPivot(m, box, CFrame.new())
	m:PivotTo(cf)
	if Skins.Enabled() then
		local k = 5 / Skins.Width("SM_CarePackage_Crate")
		-- crate (with lid) on the model; canopy + lines inside Parachute so Land() removes them
		Skins.Dress(m, "SM_CarePackage_Crate", { scale = k })
		local top = m:GetPivot() * CFrame.new(0, 3.4 * k, 0)
		Skins.Dress(m, "SM_Parachute_Canopy", { scale = k, cf = top, parent = chute, noHide = true, extra = true })
		Skins.Dress(m, "SM_Parachute_Lines", { scale = k, cf = top, parent = chute, noHide = true, extra = true })
	end
	if parent then
		m.Parent = parent
	end
	return m
end

function LootModels.Land(m: Model)
	local chute = m:FindFirstChild("Parachute")
	if chute then
		chute:Destroy()
	end
	local beacon = m:FindFirstChild("Beacon")
	local smoke = beacon and beacon:FindFirstChild("Signal") :: Smoke?
	if smoke then
		smoke.Enabled = true
	end
end

function LootModels.ForestCrate(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("ForestCrate")
	local box = Build.Part({ Name = "Box", Size = Vector3.new(2.6, 2, 2.2), CFrame = CFrame.new(0, 1, 0), Color = Color3.fromRGB(128, 96, 62), Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Decor({ Name = "Lid", Size = Vector3.new(2.8, 0.35, 2.4), CFrame = CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(4)), Color = Color3.fromRGB(96, 70, 44), Material = Enum.Material.Wood, Parent = m })
	Build.Decor({ Name = "Rope", Size = Vector3.new(0.25, 2.1, 2.3), CFrame = CFrame.new(0.4, 1.05, 0), Color = Color3.fromRGB(205, 180, 120), Material = Enum.Material.Fabric, Parent = m })
	-- Moss so it blends into the forest floor.
	Build.Decor({ Name = "Moss", Size = Vector3.new(1.4, 0.2, 1.2), CFrame = CFrame.new(-0.6, 2.3, 0.3), Color = Color3.fromRGB(84, 118, 64), Material = Enum.Material.Grass, Parent = m })
	Build.SetPivot(m, box, CFrame.new())
	m:PivotTo(cf)
	if Skins.Enabled() then
		local name = Skins.Pick({ "SM_SupplyCrate_Small01", "SM_SupplyCrate_Small02", "SM_SupplyCrate_Small03" }, cf)
		Skins.Dress(m, name, { scale = 2.6 / Skins.Width(name) * 1.1 })
	end
	if parent then
		m.Parent = parent
	end
	return m
end

return LootModels
