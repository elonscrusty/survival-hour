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
	Body: BasePart, -- the visible body (decorations hang off it); Root is the pivot part
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
		Body = mesh,
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
	e.Parent = built.Body
end

-- scale: overall size (grows with level). paint: cosmetic id or nil.
function PetModel.Build(speciesId: string, scale: number, paint: string?): Built
	local s = Pets.ById[speciesId] or Pets.ById.Pup
	local built = fromMesh(s, scale, paint) or PetModel.BuildParts(s, scale, paint)
	sparkle(built, s)
	return built
end

-- The part-built look (used until the 3D models are uploaded). A jointed rig:
-- an invisible Root at the feet, the Body jointed to it, and Head (with EarL/EarR),
-- Tail, WingL/WingR and four legs jointed to the Body. Joints are Welds named
-- "J_<Joint>" so the client animator (PetAnimator) can pose them.
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
	local pinkIn = Color3.fromRGB(255, 170, 190)
	local bx, by, bz = s.Body[1] * k, s.Body[2] * k, s.Body[3] * k
	local legH = s.Legs * k
	local hs = s.Head * k
	local bodyY = legH + by / 2

	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), white)
	root.Transparency = 1
	model.PrimaryPart = root

	-- Joins `child` to `parent` at `pivot` (world CFrame at build time).
	local function joint(name: string, parent: BasePart, child: BasePart, pivot: CFrame)
		local w = Instance.new("Weld")
		w.Name = "J_" .. name
		w.Part0 = parent
		w.Part1 = child
		w.C0 = parent.CFrame:ToObjectSpace(pivot)
		w.C1 = child.CFrame:ToObjectSpace(pivot)
		w.Parent = child
	end
	-- Rigidly attaches a decoration to the part that carries it.
	local function attach(host: BasePart, p: BasePart)
		local w = Instance.new("WeldConstraint")
		w.Part0 = host
		w.Part1 = p
		w.Parent = p
	end

	-- Body
	local body = part(model, "Body", Vector3.new(bx, by, bz), CFrame.new(0, bodyY, 0), color, "Ball")
	joint("Body", root, body, CFrame.new(0, bodyY, 0))
	attach(body, part(model, "Back", Vector3.new(bx * 0.96, by * 0.96, bz * 0.6), CFrame.new(0, bodyY + by * 0.06, bz * 0.18), color, "Ball"))
	attach(body, part(model, "Belly", Vector3.new(bx * 0.8, by * 0.8, bz * 0.78), CFrame.new(0, bodyY - by * 0.14, -bz * 0.1), accent, "Ball"))

	-- Head (pivots at the neck, behind and below its centre)
	local headCf = CFrame.new(0, legH + by * 0.85 + hs * 0.2, -bz * 0.4)
	local head = part(model, "Head", Vector3.new(hs * 1.04, hs * 0.96, hs), headCf, color, "Ball")
	joint("Head", body, head, headCf * CFrame.new(0, -hs * 0.3, hs * 0.25))
	attach(head, part(model, "Snout", Vector3.new(hs * 0.42, hs * 0.28, hs * 0.26), headCf * CFrame.new(0, -hs * 0.17, -hs * 0.38), accent, "Ball"))
	attach(head, part(model, "Nose", Vector3.new(hs * 0.13, hs * 0.09, hs * 0.07), headCf * CFrame.new(0, -hs * 0.09, -hs * 0.51), dark, "Ball"))
	for _, side in { -1, 1 } do
		local eyeCf = headCf * CFrame.new(side * hs * 0.2, hs * 0.05, -hs * 0.455)
		attach(head, part(model, "Eye", Vector3.new(hs * 0.19, hs * 0.26, hs * 0.1), eyeCf, dark, "Ball"))
		attach(head, part(model, "Shine", Vector3.new(hs * 0.08, hs * 0.08, hs * 0.04), eyeCf * CFrame.new(-side * hs * 0.03, hs * 0.06, -hs * 0.045), white, "Ball"))
		attach(head, part(model, "Shine", Vector3.new(hs * 0.035, hs * 0.035, hs * 0.02), eyeCf * CFrame.new(side * hs * 0.035, -hs * 0.06, -hs * 0.04), white, "Ball"))
		attach(head, part(model, "Blush", Vector3.new(hs * 0.14, hs * 0.08, hs * 0.06), headCf * CFrame.new(side * hs * 0.33, -hs * 0.12, -hs * 0.36), blush, "Ball"))
	end
	if s.Horn then
		local horn = part(model, "Horn", Vector3.new(hs * 0.14, hs * 0.55, hs * 0.14), headCf * CFrame.new(0, hs * 0.68, -hs * 0.24) * CFrame.Angles(-0.3, 0, 0), Color3.fromRGB(255, 205, 80))
		if s.Neon then
			horn.Material = Enum.Material.Neon
		end
		attach(head, horn)
	end

	-- Ears (pivot at the base, on the head)
	if s.Ears then
		for i, side in { 1, -1 } do
			local name = if i == 1 then "EarL" else "EarR"
			local cf, size, inSize, inCol, base
			if s.Ears == "Long" then
				cf = headCf * CFrame.new(side * hs * 0.18, hs * 0.78, hs * 0.04) * CFrame.Angles(0, 0, side * -0.2)
				size, inSize, inCol = Vector3.new(hs * 0.24, hs * 0.8, hs * 0.14), Vector3.new(hs * 0.13, hs * 0.6, hs * 0.06), accent
				base = cf * CFrame.new(0, -hs * 0.35, 0)
			elseif s.Ears == "Round" then
				cf = headCf * CFrame.new(side * hs * 0.34, hs * 0.38, hs * 0.03)
				size, inSize, inCol = Vector3.new(hs * 0.32, hs * 0.32, hs * 0.16), Vector3.new(hs * 0.18, hs * 0.18, hs * 0.07), pinkIn
				base = cf * CFrame.new(0, -hs * 0.12, 0)
			else
				cf = headCf * CFrame.new(side * hs * 0.3, hs * 0.5, hs * 0.02) * CFrame.Angles(0, 0, side * -0.25)
				size, inSize, inCol = Vector3.new(hs * 0.3, hs * 0.42, hs * 0.14), Vector3.new(hs * 0.16, hs * 0.28, hs * 0.06), pinkIn
				base = cf * CFrame.new(0, -hs * 0.18, 0)
			end
			local ear = part(model, "Ear", size, cf, color, "Ball")
			joint(name, head, ear, base)
			attach(ear, part(model, "EarIn", inSize, cf * CFrame.new(0, -hs * 0.02, -hs * 0.06), inCol, "Ball"))
		end
	end

	-- Legs (pivot at the hip) with round feet
	local legs = {}
	local legLen = legH + by * 0.35
	for _, def in { { "LegFL", 1, -1 }, { "LegFR", -1, -1 }, { "LegBL", 1, 1 }, { "LegBR", -1, 1 } } do
		local x, z = def[2] * bx * 0.27, def[3] * bz * 0.28
		local leg = part(model, "Leg", Vector3.new(bx * 0.3, legLen, bx * 0.3), CFrame.new(x, legLen / 2, z), color, "Ball")
		joint(def[1], body, leg, CFrame.new(x, legLen, z))
		attach(leg, part(model, "Paw", Vector3.new(bx * 0.36, bx * 0.24, bx * 0.42), CFrame.new(x, bx * 0.11, z - bx * 0.05), accent, "Ball"))
		table.insert(legs, leg)
	end

	-- Tail (pivot where it meets the body)
	if s.Tail then
		local base = CFrame.new(0, bodyY + by * 0.15, bz * 0.46)
		local tail
		if s.Tail == "Short" then
			tail = part(model, "Tail", Vector3.new(bx * 0.3, bx * 0.3, bx * 0.3), base * CFrame.new(0, 0, bx * 0.06), accent, "Ball")
		elseif s.Tail == "Fluffy" then
			tail = part(model, "Tail", Vector3.new(bx * 0.42, bx * 0.42, bz * 0.48), base * CFrame.new(0, by * 0.35, bz * 0.16) * CFrame.Angles(0.7, 0, 0), color, "Ball")
			attach(tail, part(model, "TailTip", Vector3.new(bx * 0.3, bx * 0.3, bx * 0.3), base * CFrame.new(0, by * 0.55, bz * 0.33), accent, "Ball"))
		else
			tail = part(model, "Tail", Vector3.new(bx * 0.16, bx * 0.16, bz * 0.55), base * CFrame.new(0, by * 0.2, bz * 0.22) * CFrame.Angles(0.6, 0, 0), color, "Ball")
			attach(tail, part(model, "TailTip", Vector3.new(bx * 0.26, bx * 0.26, bx * 0.26), base * CFrame.new(0, by * 0.4, bz * 0.44), accent, "Ball"))
		end
		joint("Tail", body, tail, base)
	end

	-- Wings (pivot at the shoulder)
	if s.Wings then
		for i, side in { 1, -1 } do
			local shoulder = CFrame.new(side * bx * 0.42, bodyY + by * 0.38, 0)
			local w = part(model, "Wing", Vector3.new(bx * 0.9, by * 0.1, bz * 0.42), shoulder * CFrame.Angles(0, side * -0.2, side * 0.55) * CFrame.new(side * bx * 0.42, 0, 0), accent, "Ball")
			if s.Neon then
				w.Material = Enum.Material.Neon
			end
			joint(if i == 1 then "WingL" else "WingR", body, w, shoulder)
		end
	end

	if s.Neon then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 12 * k
		light.Brightness = 1.5
		light.Parent = body
	end
	-- Pivot at the feet so callers can place the pet on the ground.
	root.PivotOffset = CFrame.new(0, -0.1, 0)
	return { Model = model, Root = root, Body = body, Height = legH + by, Legs = legs, Footprint = Vector2.new(bx, bz + hs * 0.3) }
end

-- Adds or replaces a trail behind the pet.
function PetModel.SetTrail(built: Built, trailId: string?)
	local old = built.Body:FindFirstChild("PetTrail")
	if old then
		old:Destroy()
	end
	for _, a in built.Body:GetChildren() do
		if a:IsA("Attachment") and string.sub(a.Name, 1, 5) == "Trail" then
			a:Destroy()
		end
	end
	local def = trailId and Cosmetics.ById[trailId]
	if not def or def.Kind ~= "Trail" then
		return
	end
	local size = built.Body.Size
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, size.Y * 0.3, size.Z / 2)
	a0.Parent = built.Body
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -size.Y * 0.3, size.Z / 2)
	a1.Parent = built.Body
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
	trail.Parent = built.Body
end

return PetModel
