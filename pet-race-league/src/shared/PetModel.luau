-- Builds a pet out of simple parts. Shared so the server (riding, following) and the
-- client (hatch reveal, pet cards) draw the same thing.
-- The model faces -Z (Roblox forward). Its feet touch Y = 0 at the pivot.
local Pets = require("./Pets")
local Cosmetics = require("./Cosmetics")
local Assets = require("./Assets")

local PetModel = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, shape: string?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = true
	if shape == "Ball" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	elseif shape == "Round" then
		-- a softened block: looks friendlier than a hard cube
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Scale = Vector3.new(1.15, 1.15, 1.15)
		m.Parent = p
	end
	p.Parent = model
	return p
end

export type Built = {
	Model: Model,
	Root: BasePart,
	Height: number, -- top of the back, from the feet
	Legs: { BasePart },
	Footprint: Vector2, -- body width (X) and length (Z), for the collision box
}

-- Model name for a species in Models.luau ("Cosmic Cat" -> "Pet_CosmicCat").
function PetModel.AssetName(speciesId: string): string
	return "Pet_" .. string.gsub(speciesId, " ", "")
end

-- The uploaded 3D mesh version, when it has loaded.
local function fromMesh(s: any, scale: number, paint: string?): Built?
	local model = Assets.Clone(PetModel.AssetName(s.Id))
	local mesh = model and model.PrimaryPart
	if not model or not mesh or not mesh:IsA("MeshPart") then
		return nil
	end
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	mesh.Anchored = false
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.Massless = true
	local paintDef = paint and Cosmetics.ById[paint]
	if paintDef and paintDef.Kind == "Paint" then
		-- a painted pet is one solid colour, like a statue
		mesh.TextureID = ""
		mesh.Color = rgb(paintDef.Colors[1])
		mesh.Material = Enum.Material.SmoothPlastic
	end
	if s.Neon then
		local light = Instance.new("PointLight")
		light.Color = rgb(s.Accent)
		light.Range = 10 * scale
		light.Brightness = 1.5
		light.Parent = mesh
	end
	model.Name = s.Name
	return {
		Model = model,
		Root = mesh,
		Height = (s.Legs + s.Body[2]) * scale,
		Legs = {},
		Footprint = Vector2.new(s.Body[1] * scale, (s.Body[3] + s.Head) * scale),
	}
end

-- scale: overall size (grows with level). paint: cosmetic id or nil.
function PetModel.Build(speciesId: string, scale: number, paint: string?): Built
	local s = Pets.ById[speciesId] or Pets.ById.Pup
	local meshed = fromMesh(s, scale, paint)
	if meshed then
		return meshed
	end
	local model = Instance.new("Model")
	model.Name = s.Name
	local k = scale
	local color = rgb(s.Color)
	local paintDef = paint and Cosmetics.ById[paint]
	if paintDef and paintDef.Kind == "Paint" then
		color = rgb(paintDef.Colors[1])
	end
	local accent = rgb(s.Accent)
	local bx, by, bz = s.Body[1] * k, s.Body[2] * k, s.Body[3] * k
	local legH = s.Legs * k
	local headS = s.Head * k
	local bodyY = legH + by / 2

	local body = part(model, "Body", Vector3.new(bx, by, bz), CFrame.new(0, bodyY, 0), color, "Round")
	model.PrimaryPart = body

	-- Belly patch
	part(model, "Belly", Vector3.new(bx * 0.7, by * 0.5, bz * 0.7), CFrame.new(0, bodyY - by * 0.28, 0), accent, "Ball")

	-- Head and face
	local headCf = CFrame.new(0, legH + by * 0.95, -bz / 2 - headS * 0.15)
	local head = part(model, "Head", Vector3.new(headS, headS, headS), headCf, color, "Round")
	part(model, "Snout", Vector3.new(headS * 0.5, headS * 0.35, headS * 0.4), headCf * CFrame.new(0, -headS * 0.15, -headS * 0.48), accent, "Ball")
	part(model, "Nose", Vector3.new(headS * 0.18, headS * 0.13, headS * 0.12), headCf * CFrame.new(0, -headS * 0.05, -headS * 0.68), Color3.fromRGB(40, 30, 30), "Ball")
	for _, side in { -1, 1 } do
		part(model, "Eye", Vector3.new(headS * 0.2, headS * 0.24, headS * 0.1), headCf * CFrame.new(side * headS * 0.24, headS * 0.12, -headS * 0.52), Color3.fromRGB(20, 20, 25), "Ball")
		part(model, "Shine", Vector3.new(headS * 0.07, headS * 0.07, headS * 0.04), headCf * CFrame.new(side * headS * 0.21, headS * 0.17, -headS * 0.57), Color3.new(1, 1, 1), "Ball")
	end

	-- Ears
	if s.Ears then
		for _, side in { -1, 1 } do
			local size, offset, tilt
			if s.Ears == "Long" then
				size = Vector3.new(headS * 0.22, headS * 0.9, headS * 0.12)
				offset = CFrame.new(side * headS * 0.22, headS * 0.85, 0)
				tilt = CFrame.Angles(0, 0, side * -0.15)
			elseif s.Ears == "Round" then
				size = Vector3.new(headS * 0.32, headS * 0.32, headS * 0.12)
				offset = CFrame.new(side * headS * 0.38, headS * 0.5, 0)
				tilt = CFrame.new()
			else
				size = Vector3.new(headS * 0.28, headS * 0.42, headS * 0.12)
				offset = CFrame.new(side * headS * 0.3, headS * 0.58, 0)
				tilt = CFrame.Angles(0, 0, side * -0.25)
			end
			part(model, "Ear", size, headCf * offset * tilt, if s.Ears == "Long" then color else accent, "Ball")
		end
	end

	-- Horn
	if s.Horn then
		local horn = part(model, "Horn", Vector3.new(headS * 0.14, headS * 0.7, headS * 0.14), headCf * CFrame.new(0, headS * 0.75, -headS * 0.15) * CFrame.Angles(-0.35, 0, 0), accent)
		if s.Neon then
			horn.Material = Enum.Material.Neon
		end
	end

	-- Legs
	local legs = {}
	for _, lx in { -1, 1 } do
		for _, lz in { -1, 1 } do
			local leg = part(model, "Leg", Vector3.new(bx * 0.26, legH + by * 0.2, bx * 0.26), CFrame.new(lx * bx * 0.3, (legH + by * 0.2) / 2, lz * bz * 0.32), color)
			table.insert(legs, leg)
			part(model, "Paw", Vector3.new(bx * 0.3, bx * 0.14, bx * 0.34), CFrame.new(lx * bx * 0.3, bx * 0.07, lz * bz * 0.32 - bx * 0.03), accent, "Ball")
		end
	end

	-- Tail
	if s.Tail then
		local tailCf = CFrame.new(0, bodyY + by * 0.2, bz / 2)
		if s.Tail == "Short" then
			part(model, "Tail", Vector3.new(bx * 0.25, bx * 0.25, bx * 0.25), tailCf, accent, "Ball")
		elseif s.Tail == "Fluffy" then
			part(model, "Tail", Vector3.new(bx * 0.45, bx * 0.45, bz * 0.4), tailCf * CFrame.new(0, by * 0.2, bz * 0.15) * CFrame.Angles(0.6, 0, 0), accent, "Ball")
		else
			part(model, "Tail", Vector3.new(bx * 0.14, bx * 0.14, bz * 0.55), tailCf * CFrame.new(0, by * 0.15, bz * 0.22) * CFrame.Angles(0.5, 0, 0), color)
		end
	end

	-- Wings
	if s.Wings then
		for _, side in { -1, 1 } do
			local w = part(model, "Wing", Vector3.new(bx * 1.1, by * 0.12, bz * 0.6), CFrame.new(side * bx * 0.85, bodyY + by * 0.35, -bz * 0.05) * CFrame.Angles(0, 0, side * 0.35), accent, "Ball")
			if s.Neon then
				w.Material = Enum.Material.Neon
			end
		end
	end

	if s.Neon then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 10 * k
		light.Brightness = 1.5
		light.Parent = body
	end

	-- Weld everything to the body.
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= body then
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = p
			w.Parent = p
		end
	end
	local _ = head
	-- Pivot at the feet so callers can place the pet on the ground. A model with a
	-- PrimaryPart pivots on that part, so the offset goes on the body.
	body.PivotOffset = CFrame.new(0, -bodyY, 0)
	return { Model = model, Root = body, Height = legH + by, Legs = legs, Footprint = Vector2.new(bx, bz + headS) }
end

-- Adds or replaces a trail behind the pet.
function PetModel.SetTrail(built: Built, trailId: string?)
	local old = built.Root:FindFirstChild("PetTrail")
	if old then
		old:Destroy()
	end
	for _, a in built.Root:GetChildren() do
		if a:IsA("Attachment") and string.sub(a.Name, 1, 5) == "Trail" then
			a:Destroy()
		end
	end
	local def = trailId and Cosmetics.ById[trailId]
	if not def or def.Kind ~= "Trail" then
		return
	end
	local size = built.Root.Size
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, size.Y * 0.3, size.Z / 2)
	a0.Parent = built.Root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -size.Y * 0.3, size.Z / 2)
	a1.Parent = built.Root
	local trail = Instance.new("Trail")
	trail.Name = "PetTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.LightEmission = 0.4
	trail.FaceCamera = true
	local keys = {}
	local n = #def.Colors
	for i, c in def.Colors do
		table.insert(keys, ColorSequenceKeypoint.new(if n == 1 then 0 else (i - 1) / (n - 1), rgb(c)))
	end
	if n == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, rgb(def.Colors[1])))
	end
	trail.Color = ColorSequence.new(keys)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = built.Root
end

return PetModel
