--!strict
-- STUB (replaced by the model pass). Public API is fixed; see docs/CONTRACTS.md.
-- Every function returns a new Model with PrimaryPart "Root" and its pivot at
-- the bottom centre, facing -Z.

local Models = {}

local function blob(name: string, size: Vector3, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.Color = color
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.CFrame = CFrame.new(0, size.Y / 2, 0)
	root.Parent = m
	m.PrimaryPart = root
	m.WorldPivot = CFrame.new()
	return m
end

function Models.Pet(petId: string, variant: string, shiny: boolean): Model
	return blob(petId, Vector3.new(2.5, 2.5, 2.5), Color3.fromRGB(240, 180, 90))
end

function Models.Egg(eggId: string): Model
	return blob(eggId, Vector3.new(2.2, 3, 2.2), Color3.fromRGB(250, 240, 220))
end

function Models.Breakable(kind: string, areaId: string): Model
	local m = blob(kind, Vector3.new(4, 3, 4), Color3.fromRGB(240, 200, 60))
	local root = m.PrimaryPart :: BasePart
	root.CanCollide = true
	return m
end

return Models
