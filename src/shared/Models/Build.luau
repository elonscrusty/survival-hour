--!nonstrict
-- Small helpers for building models from Roblox primitives.

local Build = {}

export type PartProps = {
	Name: string?,
	Shape: Enum.PartType?,
	Class: string?, -- "Part" | "WedgePart" | "CornerWedgePart" | "TrussPart"
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Anchored: boolean?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
	Transparency: number?,
	Reflectance: number?,
	CastShadow: boolean?,
	Parent: Instance?,
	Massless: boolean?,
}

function Build.Part(p: PartProps): BasePart
	local part = Instance.new((p.Class or "Part") :: any) :: BasePart
	if p.Shape and part:IsA("Part") then
		(part :: Part).Shape = p.Shape
	end
	part.Name = p.Name or "Part"
	part.Size = p.Size
	part.CFrame = p.CFrame
	part.Color = p.Color or Color3.fromRGB(160, 160, 160)
	part.Material = p.Material or Enum.Material.SmoothPlastic
	part.Anchored = if p.Anchored == nil then true else p.Anchored
	part.CanCollide = if p.CanCollide == nil then true else p.CanCollide
	part.CanQuery = if p.CanQuery == nil then true else p.CanQuery
	part.CanTouch = if p.CanTouch == nil then false else p.CanTouch
	part.Transparency = p.Transparency or 0
	part.Reflectance = p.Reflectance or 0
	part.CastShadow = if p.CastShadow == nil then true else p.CastShadow
	part.Massless = p.Massless == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if p.Parent then
		part.Parent = p.Parent
	end
	return part
end

-- Decorative part: no collision/query/touch, no shadow cost for tiny bits.
function Build.Decor(p: PartProps): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return Build.Part(p)
end

-- Cylinder whose axis points along +Y (Roblox cylinders run along X).
function Build.Cyl(name: string, height: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance?, collide: boolean?): BasePart
	return Build.Part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Parent = parent,
		CanCollide = if collide == nil then true else collide,
		CanQuery = if collide == false then false else true,
	})
end

function Build.Ball(name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance?, collide: boolean?): BasePart
	return Build.Part({
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material,
		Parent = parent,
		CanCollide = collide == true,
		CanQuery = collide == true,
	})
end

function Build.Model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

-- Sets a model's PrimaryPart and makes `pivot` (in the model's current frame)
-- its pivot. Assigning Model.WorldPivot has no effect once a PrimaryPart is
-- set (the pivot is PrimaryPart.CFrame * PivotOffset), which previously left
-- every model pivoting on its primary part's centre and half-buried.
function Build.SetPivot(model: Model, primary: BasePart, pivot: CFrame)
	model.PrimaryPart = primary
	primary.PivotOffset = primary.CFrame:ToObjectSpace(pivot)
end

-- Welds every BasePart in `model` to `root` (for unanchored assemblies).
function Build.WeldAll(model: Instance, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

function Build.SetAll(model: Instance, props: { [string]: any })
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			for k, v in props do
				(d :: any)[k] = v
			end
		end
	end
end

function Build.Tint(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

-- A billboard label (used for names, prompts' context and landmarks).
function Build.Label(adornee: BasePart, text: string, offset: Vector3, color: Color3?, maxDistance: number?): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(200, 40)
	bb.StudsOffsetWorldSpace = offset
	bb.AlwaysOnTop = false
	bb.MaxDistance = maxDistance or 80
	bb.LightInfluence = 0
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.Text = text
	tl.TextColor3 = color or Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0.4
	tl.Parent = bb
	bb.Adornee = adornee
	bb.Parent = adornee
	return bb
end

return Build
