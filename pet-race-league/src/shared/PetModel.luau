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
		Footprint = Vector2.new(s.Body[1] * scale, (s.Body[3] + s.Head * 0.3) * scale),
	}
end

-- Legendary and Mythic pets glitter.
local function sparkle(built: Built, s: any)
	if Pets.Rarities[s.Rarity].Rank < 5 then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(s.Accent), Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Rate = if Pets.Rarities[s.Rarity].Rank >= 6 then 10 else 5
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(1, 2.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = built.Root
end

-- scale: overall size (grows with level). paint: cosmetic id or nil.
function PetModel.Build(speciesId: string, scale: number, paint: string?): Built
	local s = Pets.ById[speciesId] or Pets.ById.Pup
	local built = fromMesh(s, scale, paint) or PetModel.BuildParts(s, scale, paint)
	sparkle(built, s)
	return built
end

-- The part-built look (used until the 3D models are uploaded).
function PetModel.BuildParts(s: any, scale: number, paint: string?): Built
	local model = Instance.new("Model")
	model.Name = s.Name
	local k = scale
	local color = rgb(s.Color)
	local paintDef = paint and Cosmetics.ById[paint]
	if paintDef and paintDef.Kind == "Paint" then
		color = rgb(paintDef.Colors[1])
	end
	local accent = rgb(s.Accent)
	local dark = Color3.fromRGB(25, 20, 35)
	local white = Color3.new(1, 1, 1)
	local blush = Color3.fromRGB(255, 120, 150)
	local bx, by, bz = s.Body[1] * k, s.Body[2] * k, s.Body[3] * k
	local legH = s.Legs * k
	local hs = s.Head * k
	local bodyY = legH + by / 2

	-- Chibi layout (same as blender/build.py): bean body, big head over the front.
	local body = part(model, "Body", Vector3.new(bx, by, bz), CFrame.new(0, bodyY, 0), color, "Ball")
	model.PrimaryPart = body
	part(model, "Back", Vector3.new(bx * 0.96, by * 0.96, bz * 0.6), CFrame.new(0, bodyY + by * 0.06, bz * 0.18), color, "Ball")
	part(model, "Belly", Vector3.new(bx * 0.8, by * 0.8, bz * 0.78), CFrame.new(0, bodyY - by * 0.14, -bz * 0.1), accent, "Ball")

	local headCf = CFrame.new(0, legH + by * 0.85 + hs * 0.2, -bz * 0.4)
	local head = part(model, "Head", Vector3.new(hs * 1.04, hs * 0.96, hs), headCf, color, "Ball")
	part(model, "Snout", Vector3.new(hs * 0.42, hs * 0.28, hs * 0.26), headCf * CFrame.new(0, -hs * 0.17, -hs * 0.38), accent, "Ball")
	part(model, "Nose", Vector3.new(hs * 0.13, hs * 0.09, hs * 0.07), headCf * CFrame.new(0, -hs * 0.09, -hs * 0.51), dark, "Ball")
	for _, side in { -1, 1 } do
		local eye = headCf * CFrame.new(side * hs * 0.2, hs * 0.05, -hs * 0.455)
		part(model, "Eye", Vector3.new(hs * 0.19, hs * 0.26, hs * 0.1), eye, dark, "Ball")
		part(model, "Shine", Vector3.new(hs * 0.08, hs * 0.08, hs * 0.04), eye * CFrame.new(-side * hs * 0.03, hs * 0.06, -hs * 0.045), white, "Ball")
		part(model, "Shine2", Vector3.new(hs * 0.035, hs * 0.035, hs * 0.02), eye * CFrame.new(side * hs * 0.035, -hs * 0.06, -hs * 0.04), white, "Ball")
		part(model, "Blush", Vector3.new(hs * 0.14, hs * 0.08, hs * 0.06), headCf * CFrame.new(side * hs * 0.33, -hs * 0.12, -hs * 0.36), blush, "Ball")
	end

	-- Ears
	if s.Ears then
		for _, side in { -1, 1 } do
			if s.Ears == "Long" then
				local cf = headCf * CFrame.new(side * hs * 0.18, hs * 0.78, hs * 0.04) * CFrame.Angles(0, 0, side * -0.2)
				part(model, "Ear", Vector3.new(hs * 0.24, hs * 0.8, hs * 0.14), cf, color, "Ball")
				part(model, "EarIn", Vector3.new(hs * 0.13, hs * 0.6, hs * 0.06), cf * CFrame.new(0, 0, -hs * 0.055), accent, "Ball")
			elseif s.Ears == "Round" then
				local cf = headCf * CFrame.new(side * hs * 0.34, hs * 0.38, hs * 0.03)
				part(model, "Ear", Vector3.new(hs * 0.32, hs * 0.32, hs * 0.16), cf, color, "Ball")
				part(model, "EarIn", Vector3.new(hs * 0.18, hs * 0.18, hs * 0.07), cf * CFrame.new(0, 0, -hs * 0.06), Color3.fromRGB(255, 170, 190), "Ball")
			else
				local cf = headCf * CFrame.new(side * hs * 0.3, hs * 0.5, hs * 0.02) * CFrame.Angles(0, 0, side * -0.25)
				part(model, "Ear", Vector3.new(hs * 0.3, hs * 0.42, hs * 0.14), cf, color, "Ball")
				part(model, "EarIn", Vector3.new(hs * 0.16, hs * 0.28, hs * 0.06), cf * CFrame.new(0, -hs * 0.03, -hs * 0.05), Color3.fromRGB(255, 170, 190), "Ball")
			end
		end
	end

	if s.Horn then
		local horn = part(model, "Horn", Vector3.new(hs * 0.14, hs * 0.55, hs * 0.14), headCf * CFrame.new(0, hs * 0.68, -hs * 0.24) * CFrame.Angles(-0.3, 0, 0), Color3.fromRGB(255, 205, 80))
		if s.Neon then
			horn.Material = Enum.Material.Neon
		end
	end

	-- Stubby legs on hip joints (Welds, so the client can swing them while running).
	local legs = {}
	local legLen = legH + by * 0.35
	for _, lx in { -1, 1 } do
		for _, lz in { -1, 1 } do
			local x, z = lx * bx * 0.27, lz * bz * 0.28
			local leg = part(model, "Leg", Vector3.new(bx * 0.3, legLen, bx * 0.3), CFrame.new(x, legLen / 2, z), color, "Ball")
			local foot = part(model, "Paw", Vector3.new(bx * 0.36, bx * 0.24, bx * 0.42), CFrame.new(x, bx * 0.11, z - bx * 0.05), accent, "Ball")
			local fw = Instance.new("WeldConstraint")
			fw.Part0 = leg
			fw.Part1 = foot
			fw.Parent = foot
			local hip = Instance.new("Weld")
			hip.Name = "LegJoint"
			hip.Part0 = body
			hip.Part1 = leg
			hip.C0 = body.CFrame:ToObjectSpace(CFrame.new(x, legLen, z))
			hip.C1 = CFrame.new(0, legLen / 2, 0)
			hip:SetAttribute("Phase", if lx * lz > 0 then 0 else math.pi)
			hip.Parent = leg
			table.insert(legs, leg)
		end
	end

	-- Tail
	if s.Tail then
		local tailCf = CFrame.new(0, bodyY + by * 0.15, bz * 0.48)
		if s.Tail == "Short" then
			part(model, "Tail", Vector3.new(bx * 0.3, bx * 0.3, bx * 0.3), tailCf, accent, "Ball")
		elseif s.Tail == "Fluffy" then
			part(model, "Tail", Vector3.new(bx * 0.42, bx * 0.42, bz * 0.48), tailCf * CFrame.new(0, by * 0.35, bz * 0.16) * CFrame.Angles(0.7, 0, 0), color, "Ball")
		else
			part(model, "Tail", Vector3.new(bx * 0.16, bx * 0.16, bz * 0.55), tailCf * CFrame.new(0, by * 0.2, bz * 0.22) * CFrame.Angles(0.6, 0, 0), color, "Ball")
		end
	end

	-- Wings
	if s.Wings then
		for _, side in { -1, 1 } do
			local w = part(model, "Wing", Vector3.new(bx * 0.9, by * 0.1, bz * 0.42), CFrame.new(side * bx * 0.85, bodyY + by * 0.38, 0) * CFrame.Angles(0, side * -0.2, side * 0.55), accent, "Ball")
			if s.Neon then
				w.Material = Enum.Material.Neon
			end
		end
	end

	if s.Neon then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 12 * k
		light.Brightness = 1.5
		light.Parent = body
	end

	-- Weld everything else to the body (legs and paws are already jointed).
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= body and p.Name ~= "Leg" and p.Name ~= "Paw" then
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
	return { Model = model, Root = body, Height = legH + by, Legs = legs, Footprint = Vector2.new(bx, bz + hs * 0.3) }
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
