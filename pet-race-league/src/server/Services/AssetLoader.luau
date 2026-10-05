-- Loads the uploaded 3D models (Shared/Models with an Id) with InsertService into
-- ReplicatedStorage.PetRaceModels. Each mesh is fitted to its catalog size and
-- pivot (Logic/AssetFit also fixes uploads with the wrong unit scale or a swapped
-- up axis). InsertService only loads assets owned by the game's owner, so publish
-- the place from the account (or group) that uploaded the models.
-- Init waits up to BLOCK_FOR seconds so the lobby is usually built with meshes;
-- anything slower keeps loading and is used by whatever is built afterwards.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Models = require(Shared.Models)
local AssetFit = require(Shared.Logic.AssetFit)

local AssetLoader = {}

local WORKERS = 6
local BLOCK_FOR = 15

-- Props players can bump into. Everything else is decoration (no collisions).
-- Arches and gates stay non-solid: mesh collision is approximate and could fill
-- the opening players ride through.
local SOLID = {
	Tree_Round = true,
	Tree_Pine = true,
	Tree_Blossom = true,
	Rock = true,
	Fence = true,
	Pedestal = true,
	Pillar = true,
	TrophyStatue = true,
	LampPost = true,
}

AssetLoader.Loaded = 0
AssetLoader.Failed = {} :: { string }

local function loadMesh(id: number): (MeshPart?, string?)
	local ok, container = pcall(InsertService.LoadAsset, InsertService, id)
	if not ok or not container then
		return nil, tostring(container)
	end
	local best: MeshPart? = nil
	for _, d in container:GetDescendants() do
		if d:IsA("MeshPart") and (not best or d.Size.Magnitude > best.Size.Magnitude) then
			best = d
		end
	end
	if best then
		best.Parent = nil
		for _, c in best:GetChildren() do
			if c:IsA("PackageLink") or c:IsA("Weld") or c:IsA("WeldConstraint") then
				c:Destroy()
			end
		end
	end
	container:Destroy()
	return best, if best then nil else "no MeshPart in asset"
end

local function build(name: string, e: Models.Entry): (Model?, string?)
	local mesh, err = loadMesh(e.Id :: number)
	if not mesh then
		return nil, err
	end
	local f = AssetFit.Fit({ mesh.Size.X, mesh.Size.Y, mesh.Size.Z }, e.Size)
	local c = AssetFit.Axes(f)
	local rot = CFrame.fromMatrix(Vector3.zero, Vector3.new(c[1][1], c[1][2], c[1][3]), Vector3.new(c[2][1], c[2][2], c[2][3]), Vector3.new(c[3][1], c[3][2], c[3][3]))
	mesh.Size = Vector3.new(f.LocalSize[1], f.LocalSize[2], f.LocalSize[3])
	-- Offset = pivot - centre, so the centre sits at -Offset from the pivot (origin).
	mesh.CFrame = CFrame.new(-e.Offset[1], -e.Offset[2], -e.Offset[3]) * rot
	mesh.PivotOffset = mesh.CFrame:ToObjectSpace(CFrame.new())
	mesh.Anchored = true
	mesh.CanCollide = SOLID[name] == true
	mesh.CanQuery = SOLID[name] == true
	mesh.CanTouch = false
	mesh.Name = name
	if f.Error > 0.25 then
		warn(string.format("[AssetLoader] %s: uploaded proportions differ from the catalog by %d%%", name, math.floor(f.Error * 100)))
	end
	local m = Instance.new("Model")
	m.Name = name
	mesh.Parent = m
	m.PrimaryPart = mesh
	return m, nil
end

function AssetLoader.Init()
	local lib = Instance.new("Folder")
	lib.Name = "PetRaceModels"
	lib.Parent = ReplicatedStorage
	local queue = {}
	for name, e in Models do
		if e.Id then
			table.insert(queue, name)
		end
	end
	if #queue == 0 then
		return -- nothing uploaded yet: the game uses its part-built looks
	end
	table.sort(queue)
	local remaining = #queue
	for _ = 1, math.min(WORKERS, #queue) do
		task.spawn(function()
			while #queue > 0 do
				local name = table.remove(queue)
				local ok, item, err = pcall(build, name, Models[name])
				if ok and item then
					item.Parent = lib
					AssetLoader.Loaded += 1
				else
					table.insert(AssetLoader.Failed, name)
					warn("[AssetLoader] " .. name .. ": " .. tostring(if ok then err else item))
				end
				remaining -= 1
			end
		end)
	end
	local deadline = os.clock() + BLOCK_FOR
	while remaining > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	print(string.format("[AssetLoader] %d models loaded, %d failed, %d still loading", AssetLoader.Loaded, #AssetLoader.Failed, remaining))
end

return AssetLoader
