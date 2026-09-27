--!nonstrict
-- Loads the uploaded mesh models (Shared/AssetIds) with InsertService and adds
-- any that are missing from the mesh library (ReplicatedStorage.SurvivalHourAssets),
-- in the same shape the Studio setup script produces:
--   * props / structures: Model named after the asset, PrimaryPart = the mesh,
--     WorldPivot = the authored pivot (ground anchor, hinge...), sub-parts placed
--   * held items (Equippable): Tool named without "SM_", Handle = the mesh,
--     Grip at the modelled grip point
-- Each mesh is fitted to its catalog size (Logic/AssetFit), which also fixes
-- uploads that came in with the wrong unit scale or a swapped up axis.
--
-- Runs during Init and holds server start for at most BLOCK_FOR seconds (so the
-- lobby usually gets the meshes); anything slower keeps loading in the background
-- and is used by everything built afterwards (Skins re-indexes on AssetsVersion).
-- Assets already in the library (e.g. the Studio-imported pack) are left alone.
-- InsertService can only load assets owned by the experience's owner, so the
-- place must be published by the same account that uploaded the models.
-- Any failure just leaves that asset on its procedural look.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared:WaitForChild("AssetIds"))
local AssetFit = require(Shared:WaitForChild("Logic"):WaitForChild("AssetFit"))

local AssetLoaderService = {}

local WORKERS = 6
local TIMEOUT = 120 -- give up on the rest after this long
local BLOCK_FOR = 12 -- server start waits at most this long; the rest loads in the background

AssetLoaderService.Loaded = 0
AssetLoaderService.Failed = {} :: { string }

local function libraryIndex(lib: Instance): { [string]: boolean }
	local have = {}
	for _, cat in lib:GetChildren() do
		for _, item in cat:GetChildren() do
			have[item.Name] = true
		end
	end
	return have
end

-- Loads one asset id and returns its largest MeshPart (detached), or nil.
local function loadMesh(id: number): MeshPart?
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

-- Sizes and orients a mesh so its centre sits at `at * -offset` (pivot at `at`).
local function fit(mesh: MeshPart, size: { number }, offset: { number }, at: CFrame)
	local f = AssetFit.Fit({ mesh.Size.X, mesh.Size.Y, mesh.Size.Z }, size)
	local c = AssetFit.Axes(f)
	local rot = CFrame.fromMatrix(Vector3.zero, Vector3.new(c[1][1], c[1][2], c[1][3]), Vector3.new(c[2][1], c[2][2], c[2][3]), Vector3.new(c[3][1], c[3][2], c[3][3]))
	mesh.Size = Vector3.new(f.LocalSize[1], f.LocalSize[2], f.LocalSize[3])
	mesh.CFrame = at * CFrame.new(-offset[1], -offset[2], -offset[3]) * rot
	-- The upload carries its own pivot offset (possibly in other units): replace it
	-- so the part's pivot is exactly the authored pivot `at` (ground anchor, grip...).
	mesh.PivotOffset = mesh.CFrame:ToObjectSpace(at)
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	if f.Error > 0.25 then
		warn(string.format("[AssetLoader] %s: uploaded proportions differ from the catalog by %d%%", mesh.Name, math.floor(f.Error * 100)))
	end
end

local function build(name: string, e: AssetIds.Entry): (Instance?, string?)
	local mesh, err = loadMesh(e.Id)
	if not mesh then
		return nil, err
	end
	local item: Instance
	if e.Kind == "Equippable" then
		local tool = Instance.new("Tool")
		tool.Name = (string.gsub(name, "^SM_", ""))
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		mesh.Name = "Handle"
		fit(mesh, e.Size, e.Offset, CFrame.new())
		mesh.Parent = tool
		tool.Grip = mesh.CFrame:Inverse()
		item = tool
	else
		local m = Instance.new("Model")
		m.Name = name
		mesh.Name = name
		fit(mesh, e.Size, e.Offset, CFrame.new())
		mesh.Parent = m
		m.PrimaryPart = mesh
		m.WorldPivot = CFrame.new()
		item = m
	end
	for _, p in e.Parts do
		local pm = loadMesh(p.Id)
		if pm then
			pm.Name = p.Name
			fit(pm, p.Size, p.Offset, CFrame.new(table.unpack(p.Place)))
			pm.Parent = item
		end
	end
	return item, nil
end

function AssetLoaderService.Init(_ctx)
	local lib = ReplicatedStorage:FindFirstChild("SurvivalHourAssets")
	if not lib then
		lib = Instance.new("Folder")
		lib.Name = "SurvivalHourAssets"
		lib.Parent = ReplicatedStorage
	end
	local have = libraryIndex(lib)
	local queue = {}
	for name, e in AssetIds do
		local libName = if e.Kind == "Equippable" then (string.gsub(name, "^SM_", "")) else name
		if not have[libName] then
			table.insert(queue, name)
		end
	end
	if #queue == 0 then
		return
	end
	table.sort(queue)
	local started = os.clock()
	local nextIndex, running = 1, 0
	for _ = 1, WORKERS do
		running += 1
		task.spawn(function()
			while nextIndex <= #queue and os.clock() - started < TIMEOUT do
				local name = queue[nextIndex]
				nextIndex += 1
				local e = AssetIds[name]
				local ok, item, err = pcall(build, name, e)
				if ok and item then
					local cat = lib:FindFirstChild(e.Category)
					if not cat then
						cat = Instance.new("Folder")
						cat.Name = e.Category
						cat.Parent = lib
					end
					item.Parent = cat
					AssetLoaderService.Loaded += 1
					ReplicatedStorage:SetAttribute("AssetsVersion", (ReplicatedStorage:GetAttribute("AssetsVersion") or 0) + 1)
				else
					table.insert(AssetLoaderService.Failed, name .. ": " .. tostring(if ok then err else item))
				end
			end
			running -= 1
		end)
	end
	while running > 0 and os.clock() - started < BLOCK_FOR do
		task.wait(0.1)
	end
	if running > 0 then
		task.spawn(function()
			while running > 0 and os.clock() - started < TIMEOUT + 5 do
				task.wait(0.5)
			end
			AssetLoaderService._report(#queue, started)
		end)
	else
		AssetLoaderService._report(#queue, started)
	end
end

function AssetLoaderService._report(total: number, started: number)
	print(string.format("[AssetLoader] loaded %d/%d uploaded meshes in %.1fs", AssetLoaderService.Loaded, total, os.clock() - started))
	if #AssetLoaderService.Failed > 0 then
		warn("[AssetLoader] not loaded (they keep their procedural look): " .. table.concat(AssetLoaderService.Failed, "; ", 1, math.min(8, #AssetLoaderService.Failed)))
	end
end

return AssetLoaderService
