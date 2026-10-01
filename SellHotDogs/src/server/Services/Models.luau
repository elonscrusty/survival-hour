--!strict
-- Native-part stand-ins for every model. Each builder returns a Model whose pivot is the
-- centre of its footprint on the ground. If Carter imports the Blender meshes into
-- ReplicatedStorage.Assets.<Name> (see assets/ASSETS.md), Models.build uses those instead.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Models = {}

local C = {
	bun = Color3.fromRGB(232, 184, 107),
	bunDark = Color3.fromRGB(201, 138, 75),
	sausage = Color3.fromRGB(181, 84, 58),
	sausageDark = Color3.fromRGB(142, 59, 38),
	mustard = Color3.fromRGB(242, 194, 48),
	ketchup = Color3.fromRGB(216, 58, 46),
	relish = Color3.fromRGB(109, 190, 69),
	cream = Color3.fromRGB(255, 246, 229),
	teal = Color3.fromRGB(63, 182, 201),
	wood = Color3.fromRGB(196, 140, 86),
	woodDark = Color3.fromRGB(150, 100, 60),
	white = Color3.fromRGB(250, 250, 250),
	steel = Color3.fromRGB(200, 205, 212),
	dark = Color3.fromRGB(60, 62, 70),
	glass = Color3.fromRGB(170, 225, 240),
	violet = Color3.fromRGB(150, 90, 230),
	alien = Color3.fromRGB(120, 220, 110),
	sky = Color3.fromRGB(120, 200, 255),
}
Models.Colors = C

type Opts = { shape: Enum.PartType?, material: Enum.Material?, transparency: number?, neon: boolean?, collide: boolean?, name: string? }

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, o: Opts?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = true
	if o then
		if o.shape then
			p.Shape = o.shape
		end
		if o.material then
			p.Material = o.material
		end
		if o.neon then
			p.Material = Enum.Material.Neon
		end
		if o.transparency then
			p.Transparency = o.transparency
		end
		if o.collide == false then
			p.CanCollide = false
		end
		if o.name then
			p.Name = o.name
		end
	end
	p.Parent = parent
	return p
end
Models.part = part

local function cyl(parent: Instance, len: number, dia: number, cf: CFrame, color: Color3, o: Opts?): Part
	-- Roblox cylinders run along X
	local opts: Opts = o or {}
	opts.shape = Enum.PartType.Cylinder
	return part(parent, Vector3.new(len, dia, dia), cf, color, opts)
end

local function ball(parent: Instance, d: number, cf: CFrame, color: Color3, o: Opts?): Part
	local opts: Opts = o or {}
	opts.shape = Enum.PartType.Ball
	return part(parent, Vector3.new(d, d, d), cf, color, opts)
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns an X-axis cylinder upright

-- A hot dog lying along X, centred at cf.
function Models.hotDog(parent: Instance, cf: CFrame, scale: number, bunColor: Color3?, sausageColor: Color3?)
	local s = scale
	local bunL, bunD = 2.0 * s, 0.75 * s
	part(parent, Vector3.new(bunL, bunD * 0.55, bunD), cf * at(0, -0.12 * s, 0), bunColor or C.bun, { collide = false })
	cyl(parent, bunL, bunD * 0.6, cf * at(0, 0.05 * s, 0.22 * s), bunColor or C.bun, { collide = false })
	cyl(parent, bunL, bunD * 0.6, cf * at(0, 0.05 * s, -0.22 * s), bunColor or C.bun, { collide = false })
	cyl(parent, bunL * 1.15, 0.42 * s, cf * at(0, 0.28 * s, 0), sausageColor or C.sausage, { collide = false })
	-- mustard zigzag
	for i = -3, 3 do
		local seg = part(parent, Vector3.new(0.34 * s, 0.07 * s, 0.09 * s), cf * at(i * 0.27 * s, 0.5 * s, 0) * CFrame.Angles(0, math.rad(if i % 2 == 0 then 35 else -35), 0), C.mustard, { collide = false })
		seg.CastShadow = false
	end
end

local function sign(parent: Instance, size: Vector3, cf: CFrame, bg: Color3, text: string, textColor: Color3?): Part
	local board = part(parent, size, cf, bg, { name = "Sign" })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = board
	local tl = Instance.new("TextLabel")
	tl.Name = "Text"
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(0.94, 0.9)
	tl.Position = UDim2.fromScale(0.03, 0.05)
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.TextColor3 = textColor or C.white
	tl.Text = text
	tl.Parent = sg
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(80, 40, 20)
	stroke.Transparency = 0.3
	stroke.Parent = tl
	return board
end
Models.sign = sign

-- Striped awning made of alternating slats.
local function awning(parent: Instance, width: number, depth: number, cf: CFrame, a: Color3, b: Color3)
	local n = math.max(3, math.floor(width / 1.6))
	local w = width / n
	for i = 0, n - 1 do
		local x = -width / 2 + w * (i + 0.5)
		part(parent, Vector3.new(w, 0.3, depth), cf * at(x, 0, 0) * CFrame.Angles(math.rad(-18), 0, 0), if i % 2 == 0 then a else b)
	end
end

local B: { [string]: (Model) -> () } = {}

B.HotDogStand = function(m)
	-- counter
	part(m, Vector3.new(12, 3.6, 5), at(0, 1.8, 0), C.ketchup)
	part(m, Vector3.new(12.4, 0.4, 5.4), at(0, 3.8, 0), C.cream)
	part(m, Vector3.new(11, 1.1, 0.2), at(0, 2.2, -2.55), C.mustard)
	-- wheels
	for _, x in { -4.5, 4.5 } do
		cyl(m, 0.6, 2.4, at(x, 1.2, -2.7) * CFrame.Angles(0, math.rad(90), 0), C.dark)
		cyl(m, 0.7, 1.0, at(x, 1.2, -2.75) * CFrame.Angles(0, math.rad(90), 0), C.steel)
	end
	-- grill with sausages
	part(m, Vector3.new(4, 0.3, 2.4), at(3, 4.1, 0.6), C.dark)
	for i = 0, 3 do
		cyl(m, 2.2, 0.45, at(3, 4.45, -0.2 + i * 0.55), C.sausage)
	end
	-- buns pile and bottles
	for i = 0, 2 do
		Models.hotDog(m, at(-3 + i * 0.3, 4.3 + i * 0.5, 0.4), 0.9)
	end
	cyl(m, 1.5, 0.7, at(-0.6, 4.75, -1.4) * UP, C.mustard)
	cyl(m, 1.5, 0.7, at(0.4, 4.75, -1.4) * UP, C.ketchup)
	-- posts and awning
	for _, x in { -5.6, 5.6 } do
		cyl(m, 6.5, 0.4, at(x, 7, 2.2) * UP, C.white)
		cyl(m, 3, 0.4, at(x, 5.5, -2.2) * UP, C.white)
	end
	awning(m, 13.5, 6, at(0, 8.4, 0), C.ketchup, C.cream)
	local s = sign(m, Vector3.new(10, 2.4, 0.4), at(0, 10.6, 2.2), C.mustard, "HOT DOGS", C.ketchup)
	s.Name = "NameSign"
	-- giant mascot hot dog on the roof
	Models.hotDog(m, at(0, 12.6, 2.2), 3)
end

B.CondimentStation = function(m)
	part(m, Vector3.new(5, 0.4, 3), at(0, 2.6, 0), C.wood)
	for _, x in { -2.2, 2.2 } do
		for _, z in { -1.2, 1.2 } do
			part(m, Vector3.new(0.35, 2.4, 0.35), at(x, 1.2, z), C.woodDark)
		end
	end
	cyl(m, 3, 1.3, at(-1.4, 4.3, 0) * UP, C.mustard)
	part(m, Vector3.new(0.5, 0.9, 0.5), at(-1.4, 6.2, 0), C.mustard)
	cyl(m, 3, 1.3, at(0.2, 4.3, 0) * UP, C.ketchup)
	part(m, Vector3.new(0.5, 0.9, 0.5), at(0.2, 6.2, 0), C.ketchup)
	cyl(m, 1.6, 1.4, at(1.8, 3.6, 0) * UP, C.glass, { transparency = 0.25, material = Enum.Material.Glass })
	cyl(m, 1.2, 1.2, at(1.8, 3.5, 0) * UP, C.relish)
	cyl(m, 0.3, 1.5, at(1.8, 4.5, 0) * UP, C.relish)
end

B.BunRack = function(m)
	for _, x in { -1.9, 1.9 } do
		part(m, Vector3.new(0.4, 5, 2.2), at(x, 2.5, 0), C.woodDark)
	end
	for i = 0, 3 do
		local y = 0.7 + i * 1.3
		part(m, Vector3.new(3.8, 0.25, 2.2), at(0, y, 0), C.wood)
		for j = -1, 1 do
			part(m, Vector3.new(1.0, 0.5, 1.9), at(j * 1.15, y + 0.38, 0), C.bun)
		end
	end
end

B.CashRegister = function(m)
	part(m, Vector3.new(3, 2.6, 2.4), at(0, 1.3, 0), C.teal)
	part(m, Vector3.new(2.6, 1.2, 2), at(0, 3.2, 0), C.cream)
	part(m, Vector3.new(2.2, 0.8, 0.2), at(0, 4.2, -0.6) * CFrame.Angles(math.rad(-20), 0, 0), C.dark)
	for i = 0, 2 do
		for j = 0, 1 do
			part(m, Vector3.new(0.45, 0.2, 0.45), at(-0.6 + i * 0.6, 3.85, -0.2 + j * 0.6), C.mustard)
		end
	end
	ball(m, 0.6, at(0.9, 4.0, 0.6), C.mustard, { material = Enum.Material.Metal })
	part(m, Vector3.new(2.2, 0.5, 1.6), at(0, 2.3, -1.1), C.mustard, { name = "Drawer" })
end

B.Billboard = function(m)
	for _, x in { -4, 4 } do
		part(m, Vector3.new(0.7, 8, 0.7), at(x, 4, 0.4), C.woodDark)
	end
	local s = sign(m, Vector3.new(12, 5.5, 0.6), at(0, 9.5, 0), C.sky, "HOT DOGS  →", C.white)
	s.Name = "BillboardFace"
	Models.hotDog(m, at(0, 12.9, -0.2), 2.6)
	part(m, Vector3.new(12.6, 0.4, 1.4), at(0, 6.6, 0), C.wood)
end

B.Flyers = function(m)
	part(m, Vector3.new(0.4, 5, 0.4), at(0, 2.5, 0), C.steel)
	for i = 0, 2 do
		local f = part(m, Vector3.new(1.4, 1.9, 0.08), at(0, 2 + i * 1.1, -0.25) * CFrame.Angles(0, 0, math.rad(i * 6 - 6)), if i == 1 then C.mustard else C.cream)
		f.CanCollide = false
	end
	part(m, Vector3.new(2.6, 3.2, 0.1), at(0, 4.4, 0.3), C.ketchup)
end

B.Grill = function(m)
	cyl(m, 2.6, 4, at(0, 2.2, 0) * CFrame.Angles(0, math.rad(90), 0), C.dark)
	part(m, Vector3.new(4, 0.4, 2.6), at(0, 3.5, 0), C.dark)
	for i = -1, 1 do
		cyl(m, 3.2, 0.5, at(0, 3.95, i * 0.7), C.sausageDark)
	end
	for _, x in { -1.5, 1.5 } do
		part(m, Vector3.new(0.3, 1.2, 0.3), at(x, 0.6, 0), C.steel)
	end
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 2
	fire.Color = C.mustard
	fire.SecondaryColor = C.ketchup
	fire.Parent = part(m, Vector3.new(1, 0.2, 1), at(0, 3.2, 0), C.dark, { transparency = 1, collide = false })
end

B.Sign = function(m)
	part(m, Vector3.new(0.5, 4, 0.5), at(-1.6, 2, 0), C.woodDark)
	part(m, Vector3.new(0.5, 4, 0.5), at(1.6, 2, 0), C.woodDark)
	sign(m, Vector3.new(4.4, 2.4, 0.3), at(0, 4.4, 0), C.mustard, "DEAL!", C.ketchup)
end

B.Floor = function(m)
	part(m, Vector3.new(30, 0.5, 26), at(0, 0.25, 4), C.cream, { material = Enum.Material.SmoothPlastic })
	for i = -2, 2 do
		part(m, Vector3.new(30, 0.52, 1), at(0, 0.26, 4 + i * 5), C.mustard)
	end
end

B.Walls = function(m)
	part(m, Vector3.new(30, 7, 0.8), at(0, 3.5, 17), C.ketchup)
	part(m, Vector3.new(0.8, 7, 26), at(-15, 3.5, 4), C.cream)
	part(m, Vector3.new(0.8, 7, 26), at(15, 3.5, 4), C.cream)
	part(m, Vector3.new(31, 0.8, 1.6), at(0, 7.2, 17), C.mustard)
end

B.DeliveryBike = function(m)
	cyl(m, 0.5, 1.8, at(-1.6, 0.9, 0) * CFrame.Angles(0, math.rad(90), 0), C.dark)
	cyl(m, 0.5, 1.8, at(1.6, 0.9, 0) * CFrame.Angles(0, math.rad(90), 0), C.dark)
	part(m, Vector3.new(3.6, 0.8, 1.0), at(0, 1.5, 0), C.ketchup)
	part(m, Vector3.new(0.3, 2.0, 0.3), at(1.6, 2.4, 0) * CFrame.Angles(0, 0, math.rad(-15)), C.steel)
	part(m, Vector3.new(0.3, 0.3, 1.6), at(1.85, 3.3, 0), C.dark)
	part(m, Vector3.new(1.2, 0.4, 0.9), at(-0.3, 2.1, 0), C.dark)
	part(m, Vector3.new(1.6, 1.4, 1.4), at(-1.4, 2.8, 0), C.mustard)
	Models.hotDog(m, at(-1.4, 3.7, 0), 0.8)
end

B.Arcade = function(m)
	part(m, Vector3.new(3, 6, 2.4), at(0, 3, 0), C.violet)
	part(m, Vector3.new(2.4, 1.8, 0.2), at(0, 4.2, -1.25), C.dark)
	part(m, Vector3.new(2.2, 1.6, 0.1), at(0, 4.2, -1.36), C.teal, { neon = true })
	part(m, Vector3.new(2.6, 0.4, 1.2), at(0, 2.6, -1.4), C.cream)
	ball(m, 0.5, at(-0.6, 2.95, -1.5), C.ketchup)
	ball(m, 0.4, at(0.6, 2.9, -1.5), C.mustard)
	sign(m, Vector3.new(3, 1.0, 0.3), at(0, 6.4, -1.0), C.mustard, "DOGDASH", C.ketchup)
end

B.DeliveryVan = function(m)
	part(m, Vector3.new(11, 5, 5.4), at(0, 3.3, 0), C.cream)
	part(m, Vector3.new(3.4, 3.4, 5.2), at(5.6, 2.5, 0), C.cream)
	part(m, Vector3.new(0.2, 1.6, 4.4), at(7.35, 3.3, 0), C.glass, { material = Enum.Material.Glass, transparency = 0.2 })
	part(m, Vector3.new(11.1, 1, 5.5), at(0, 2.2, 0), C.ketchup)
	for _, x in { -3.5, 4.5 } do
		for _, z in { -2.7, 2.7 } do
			cyl(m, 0.8, 2.2, at(x, 1.1, z) * CFrame.Angles(0, math.rad(90), 0), C.dark)
		end
	end
	Models.hotDog(m, at(-0.5, 6.6, 0), 4)
end

B.DepotTruck = function(m)
	part(m, Vector3.new(11, 7, 6.4), at(-2, 4.6, 0), C.mustard)
	part(m, Vector3.new(4, 4.6, 6), at(5.6, 3.3, 0), C.ketchup)
	part(m, Vector3.new(0.2, 2, 5), at(7.65, 4.2, 0), C.glass, { material = Enum.Material.Glass, transparency = 0.2 })
	for _, x in { -5.5, -2.5, 5.5 } do
		for _, z in { -3.2, 3.2 } do
			cyl(m, 0.9, 2.4, at(x, 1.2, z) * CFrame.Angles(0, math.rad(90), 0), C.dark)
		end
	end
	sign(m, Vector3.new(9, 3, 0.2), at(-2, 5, -3.3) * CFrame.Angles(0, 0, 0), C.mustard, "DOG DEPOT", C.ketchup)
end

B.Conveyor = function(m)
	part(m, Vector3.new(10, 0.6, 2.6), at(0, 2.4, 0), C.dark)
	for _, x in { -4, 0, 4 } do
		part(m, Vector3.new(0.5, 2.1, 2.2), at(x, 1.05, 0), C.steel)
	end
	for i = -2, 2 do
		part(m, Vector3.new(1.4, 1.0, 1.4), at(i * 2, 3.2, 0), C.wood)
	end
end

B.Crates = function(m)
	for i = 0, 2 do
		for j = 0, 2 - i do
			part(m, Vector3.new(1.8, 1.8, 1.8), at(-1.9 + j * 1.95 + i * 0.95, 0.9 + i * 1.82, 0), if (i + j) % 2 == 0 then C.wood else C.bunDark)
		end
	end
end

B.Antenna = function(m)
	part(m, Vector3.new(2, 1, 2), at(0, 0.5, 0), C.steel)
	cyl(m, 9, 0.4, at(0, 5, 0) * UP, C.white)
	ball(m, 3.2, at(0, 8.2, 0), C.teal, { transparency = 0.1 })
	ball(m, 0.6, at(0, 10, 0), C.ketchup, { neon = true })
end

B.TradingTicker = function(m)
	part(m, Vector3.new(8, 1, 3), at(0, 0.5, 0), C.dark)
	part(m, Vector3.new(7.4, 6, 0.6), at(0, 4.4, 0), C.dark)
	part(m, Vector3.new(7, 5.4, 0.1), at(0, 4.4, -0.35), Color3.fromRGB(20, 40, 50), { name = "Screen" })
	-- rising chart bars
	for i = 0, 5 do
		local h = 0.8 + i * 0.7
		part(m, Vector3.new(0.7, h, 0.1), at(-2.9 + i * 1.15, 2.0 + h / 2, -0.45), if i % 2 == 0 then C.relish else C.mustard, { neon = true })
	end
	Models.hotDog(m, at(2.3, 7.0, -0.6) * CFrame.Angles(0, 0, math.rad(30)), 1.4)
end

B.LabMachine = function(m)
	part(m, Vector3.new(6, 2.4, 4), at(0, 1.2, 0), C.white)
	cyl(m, 0.4, 3.6, at(-1.2, 2.6, 0) * UP, C.steel)
	ball(m, 3.4, at(-1.2, 4.2, 0), C.glass, { transparency = 0.45, material = Enum.Material.Glass })
	Models.hotDog(m, at(-1.2, 4.0, 0), 0.9)
	cyl(m, 3.8, 1.1, at(1.8, 4.3, 0) * UP, C.relish, { transparency = 0.2, neon = true })
	cyl(m, 0.4, 1.4, at(1.8, 6.4, 0) * UP, C.steel)
	for i = 0, 2 do
		ball(m, 0.4, at(1.8 + (i - 1) * 0.3, 6.9 + i * 0.35, 0), C.relish, { transparency = 0.3, collide = false })
	end
end

B.KitchenRobot = function(m)
	cyl(m, 1, 2.4, at(0, 0.5, 0) * UP, C.dark)
	part(m, Vector3.new(2.6, 2.8, 2), at(0, 2.6, 0), C.steel, { material = Enum.Material.Metal })
	part(m, Vector3.new(1.6, 0.8, 0.2), at(0, 3, -1.05), C.teal, { neon = true })
	ball(m, 2.2, at(0, 5, 0), C.white)
	ball(m, 0.5, at(-0.45, 5.2, -0.95), C.dark)
	ball(m, 0.5, at(0.45, 5.2, -0.95), C.dark)
	cyl(m, 0.9, 0.2, at(0, 6.4, 0) * UP, C.steel)
	ball(m, 0.4, at(0, 6.9, 0), C.ketchup, { neon = true })
	part(m, Vector3.new(0.5, 2.0, 0.5), at(-1.6, 3, -0.5) * CFrame.Angles(math.rad(40), 0, 0), C.steel)
	part(m, Vector3.new(0.5, 2.0, 0.5), at(1.6, 3, -0.5) * CFrame.Angles(math.rad(40), 0, 0), C.steel)
	Models.hotDog(m, at(1.6, 3.9, -1.4), 0.7)
end

B.RepublicMonument = function(m)
	part(m, Vector3.new(14, 1.4, 14), at(0, 0.7, 0), C.cream, { material = Enum.Material.Marble })
	part(m, Vector3.new(10, 1.4, 10), at(0, 2.1, 0), C.cream, { material = Enum.Material.Marble })
	part(m, Vector3.new(6, 6, 6), at(0, 5.8, 0), C.cream, { material = Enum.Material.Marble })
	Models.hotDog(m, at(0, 13, 0) * CFrame.Angles(0, 0, math.rad(70)), 6, C.mustard, C.mustard)
	for _, x in { -6, 6 } do
		cyl(m, 9, 0.3, at(x, 6, -6) * UP, C.steel)
		part(m, Vector3.new(0.1, 2, 3.2), at(x, 9.4, -4.4), if x < 0 then C.ketchup else C.relish, { collide = false })
	end
end

B.HotDogRocket = function(m)
	part(m, Vector3.new(10, 1, 10), at(0, 0.5, 0), C.steel, { material = Enum.Material.DiamondPlate })
	-- bun halves around a sausage-shaped body standing upright
	cyl(m, 20, 5.2, at(0, 12, 0) * UP, C.sausage)
	ball(m, 5.2, at(0, 22, 0), C.sausage)
	part(m, Vector3.new(1.6, 16, 6.4), at(-2.9, 10.5, 0), C.bun)
	part(m, Vector3.new(1.6, 16, 6.4), at(2.9, 10.5, 0), C.bun)
	for i = 0, 6 do
		part(m, Vector3.new(0.6, 0.6, 5.4), at(0, 7 + i * 2, -1.6) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 30 else -30)), C.mustard, { collide = false })
	end
	for a = 0, 3 do
		local cf = CFrame.Angles(0, a * math.pi / 2, 0)
		part(m, Vector3.new(0.6, 5, 3), cf * at(0, 3.5, 3.6), C.ketchup)
	end
	ball(m, 2, at(0, 1.2, 0), C.mustard, { neon = true, collide = false })
end

B.Staircase = function(m)
	for i = 0, 15 do
		local a = math.rad(i * 26)
		local cf = CFrame.Angles(0, a, 0) * at(0, 1 + i * 1.25, 5)
		part(m, Vector3.new(4.5, 0.6, 2.4), cf, Color3.fromHSV((0.5 + i * 0.03) % 1, 0.35, 1), { neon = i % 4 == 0 })
	end
	cyl(m, 22, 1.4, at(0, 11, 0) * UP, C.cream)
	ball(m, 3, at(0, 23, 0), C.mustard, { neon = true })
end

B.CosmicPortal = function(m)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		part(m, Vector3.new(1.4, 2.2, 1.6), at(math.cos(a) * 6.4, 7.5 + math.sin(a) * 6.4, 0) * CFrame.Angles(0, 0, a), if i % 2 == 0 then C.violet else C.teal, { neon = i % 3 == 0 })
	end
	cyl(m, 0.3, 12, at(0, 7.5, 0) * CFrame.Angles(0, math.rad(90), 0), C.violet, { neon = true, transparency = 0.35, collide = false, name = "Disc" })
	part(m, Vector3.new(16, 0.6, 5), at(0, 0.3, 0), C.dark)
end

B.IngredientRack = function(m)
	for _, x in { -2.6, 2.6 } do
		part(m, Vector3.new(0.4, 5.4, 0.4), at(x, 2.7, -1.1), C.woodDark)
		part(m, Vector3.new(0.4, 5.4, 0.4), at(x, 2.7, 1.1), C.woodDark)
	end
	for i = 0, 1 do
		local y = 1.2 + i * 2
		part(m, Vector3.new(5.6, 0.3, 2.6), at(0, y, 0), C.wood)
		for j = -1, 1 do
			part(m, Vector3.new(1.4, 0.9, 1.6), at(j * 1.7, y + 0.6, 0), C.bunDark)
			for k = 0, 2 do
				cyl(m, 1.3, 0.3, at(j * 1.7, y + 1.1, -0.45 + k * 0.45), if i == 0 then C.sausage else C.bun, { collide = false })
			end
		end
	end
	awning(m, 6.4, 3.4, at(0, 5.8, 0), C.relish, C.cream)
end

B.IngredientCrate = function(m)
	part(m, Vector3.new(1.5, 0.9, 1.5), at(0, 0.45, 0), C.wood)
	for k = 0, 2 do
		cyl(m, 1.3, 0.35, at(0, 1.0, -0.42 + k * 0.42), C.sausage, { collide = false })
	end
end

B.MoneyBag = function(m)
	ball(m, 1.6, at(0, 0.8, 0), C.relish)
	cyl(m, 0.5, 0.7, at(0, 1.75, 0) * UP, C.relish)
	part(m, Vector3.new(0.9, 0.2, 0.9), at(0, 1.6, 0), C.mustard)
end

B.AlienInvestor = function(m)
	part(m, Vector3.new(1.8, 2.2, 1.2), at(0, 2.2, 0), C.dark)
	part(m, Vector3.new(0.3, 1.6, 0.1), at(0, 2.4, -0.62), C.ketchup)
	for _, x in { -0.45, 0.45 } do
		part(m, Vector3.new(0.6, 1.2, 0.7), at(x, 0.6, 0), C.dark)
	end
	ball(m, 1.9, at(0, 4.1, 0), C.alien)
	ball(m, 0.6, at(-0.4, 4.3, -0.75), C.dark)
	ball(m, 0.6, at(0.4, 4.3, -0.75), C.dark)
	cyl(m, 0.8, 0.12, at(-0.5, 5.2, 0) * UP, C.alien)
	cyl(m, 0.8, 0.12, at(0.5, 5.2, 0) * UP, C.alien)
	ball(m, 0.3, at(-0.5, 5.6, 0), C.mustard, { neon = true })
	ball(m, 0.3, at(0.5, 5.6, 0), C.mustard, { neon = true })
	part(m, Vector3.new(1.2, 0.9, 0.3), at(1.3, 1.4, 0), C.woodDark)
end

-- Business buildings (one per business, appear on unlock)
B.DashShop = function(m)
	part(m, Vector3.new(18, 9, 10), at(0, 4.5, 6), C.cream)
	part(m, Vector3.new(19, 0.8, 11), at(0, 9.4, 6), C.ketchup)
	part(m, Vector3.new(6, 6, 0.3), at(0, 3, 0.9), C.glass, { material = Enum.Material.Glass, transparency = 0.3 })
	awning(m, 18, 3, at(0, 7.5, 0), C.ketchup, C.white)
	local s = sign(m, Vector3.new(12, 2.6, 0.4), at(0, 11.4, 6), C.ketchup, "DogDash", C.white)
	s.Name = "BizSign"
	Models.hotDog(m, at(0, 13.6, 6), 3)
end

B.DepotBuilding = function(m)
	part(m, Vector3.new(30, 12, 14), at(0, 6, 8), C.mustard)
	part(m, Vector3.new(31, 1, 15), at(0, 12.5, 8), C.ketchup)
	for _, x in { -8, 0, 8 } do
		part(m, Vector3.new(6, 7, 0.3), at(x, 3.5, 0.9), C.steel, { material = Enum.Material.CorrodedMetal })
	end
	local s = sign(m, Vector3.new(16, 3, 0.4), at(0, 14.6, 8), C.ketchup, "Delivery Depot", C.white)
	s.Name = "BizSign"
end

B.TradingFloor = function(m)
	part(m, Vector3.new(22, 18, 14), at(0, 9, 8), C.glass, { material = Enum.Material.Glass, transparency = 0.15 })
	for i = 0, 3 do
		part(m, Vector3.new(22.4, 0.6, 14.4), at(0, 0.3 + i * 4.5, 8), C.white)
	end
	part(m, Vector3.new(23, 1, 15), at(0, 18.5, 8), C.teal)
	local s = sign(m, Vector3.new(16, 3, 0.4), at(0, 20.6, 8), C.teal, "Hot Dog Trading", C.white)
	s.Name = "BizSign"
end

B.LabBuilding = function(m)
	part(m, Vector3.new(22, 10, 14), at(0, 5, 8), C.white)
	ball(m, 16, at(0, 10, 8), C.glass, { material = Enum.Material.Glass, transparency = 0.35 })
	part(m, Vector3.new(22.4, 1, 14.4), at(0, 10, 8), C.relish)
	local s = sign(m, Vector3.new(16, 3, 0.4), at(0, 6, 0.8), C.relish, "Test Kitchen Labs", C.white)
	s.Name = "BizSign"
end

B.RoboticsFactory = function(m)
	part(m, Vector3.new(26, 12, 14), at(0, 6, 8), C.steel, { material = Enum.Material.Metal })
	for i = 0, 2 do
		part(m, Vector3.new(8.6, 3, 14), at(-8.6 + i * 8.6, 13.5, 8) * CFrame.Angles(0, 0, math.rad(20)), C.teal)
	end
	cyl(m, 10, 2.4, at(9, 17, 12) * UP, C.ketchup)
	local s = sign(m, Vector3.new(16, 3, 0.4), at(0, 8, 0.8), C.teal, "Kitchen Robotics", C.white)
	s.Name = "BizSign"
end

B.RepublicCapitol = function(m)
	part(m, Vector3.new(30, 2, 16), at(0, 1, 8), C.cream, { material = Enum.Material.Marble })
	for i = 0, 5 do
		cyl(m, 10, 1.6, at(-12.5 + i * 5, 7, 1.5) * UP, C.white, { material = Enum.Material.Marble })
	end
	part(m, Vector3.new(30, 2, 16), at(0, 13, 8), C.cream, { material = Enum.Material.Marble })
	ball(m, 12, at(0, 15, 9), C.mustard, { material = Enum.Material.Foil })
	local s = sign(m, Vector3.new(18, 2.6, 0.4), at(0, 13, -0.2), C.ketchup, "Hot Dog Republic", C.white)
	s.Name = "BizSign"
end

B.LaunchSite = function(m)
	part(m, Vector3.new(36, 1, 24), at(0, 0.5, 8), C.dark, { material = Enum.Material.Concrete })
	for _, x in { -12, 12 } do
		part(m, Vector3.new(2, 26, 2), at(x, 13, 14), C.ketchup)
	end
	part(m, Vector3.new(26, 2, 2), at(0, 25, 14), C.ketchup)
	local s = sign(m, Vector3.new(14, 3, 0.4), at(0, 4, -3.2), C.dark, "HotDogX", C.mustard)
	s.Name = "BizSign"
end

Models.BUILDING_FOR = {
	stand = "HotDogStand",
	dash = "DashShop",
	depot = "DepotBuilding",
	trading = "TradingFloor",
	labs = "LabBuilding",
	robotics = "RoboticsFactory",
	republic = "RepublicCapitol",
	hotdogx = "LaunchSite",
}

-- Build a model by name. Imported meshes in ReplicatedStorage.Assets win over stand-ins.
function Models.build(name: string): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local imported = assets and assets:FindFirstChild(name)
	if imported and imported:IsA("Model") then
		local m = imported:Clone()
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		return m
	end
	local m = Instance.new("Model")
	m.Name = name
	local f = B[name] or B.Sign
	f(m)
	m.WorldPivot = CFrame.new()
	return m
end

-- Shrink a model (about its pivot) so its footprint fits a square of `maxSize` studs.
-- Works on freshly built models (pivot at the origin); heights scale with it.
function Models.fit(m: Model, maxSize: number)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local p, s = d.CFrame.Position, d.Size
			local r = math.max(s.X, s.Z) / 2
			minX, maxX = math.min(minX, p.X - r), math.max(maxX, p.X + r)
			minZ, maxZ = math.min(minZ, p.Z - r), math.max(maxZ, p.Z + r)
		end
	end
	local extent = math.max(maxX - minX, maxZ - minZ)
	if extent <= maxSize or extent == -math.huge then
		return
	end
	local k = maxSize / extent
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = d.CFrame
			d.Size = d.Size * k
			d.CFrame = CFrame.new(cf.Position * k) * cf.Rotation
		elseif d:IsA("Fire") then
			d.Size = math.max(2, d.Size * k)
		end
	end
end

function Models.place(m: Model, cf: CFrame, parent: Instance): Model
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

return Models
