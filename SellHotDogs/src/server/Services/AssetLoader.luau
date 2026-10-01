--!strict
-- Loads the uploaded Blender meshes (Shared/AssetIds) with InsertService into
-- ReplicatedStorage.Assets as Models named after the asset (pivot = centre of the footprint on
-- the ground), then asks World to swap the native-part stand-ins for them. Runs in the
-- background; anything that fails keeps its stand-in. InsertService only loads assets owned by
-- the experience's owner, so upload with the publishing account (tools/upload_assets.py).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local AssetIds = require(Shared.AssetIds)
local Config = require(Shared.Config)

local AssetLoader = {}
AssetLoader.loaded = 0
AssetLoader.failed = {} :: { string }
AssetLoader.onLoaded = nil :: ((string) -> ())?

-- Rotations to try so the loaded mesh's box matches the manifest box (uploads can come in
-- Z-up or Y-up depending on importer settings).
local ROTS = {
	CFrame.new(),
	CFrame.Angles(math.rad(-90), 0, 0),
	CFrame.Angles(math.rad(90), 0, 0),
	CFrame.Angles(0, 0, math.rad(90)),
}

local function boxError(a: Vector3, b: Vector3): number
	local ra = Vector3.new(a.X / a.Y, a.Z / a.Y, 1)
	local rb = Vector3.new(b.X / b.Y, b.Z / b.Y, 1)
	return math.abs(math.log(ra.X / rb.X)) + math.abs(math.log(ra.Y / rb.Y))
end

local function rotatedSize(s: Vector3, r: CFrame): Vector3
	local v = r:VectorToWorldSpace(s)
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

local function loadOne(name: string, rec: { id: number, size: Vector3 }, folder: Folder)
	local ok, container = pcall(InsertService.LoadAsset, InsertService, rec.id)
	if not ok or not container then
		table.insert(AssetLoader.failed, name)
		warn("[AssetLoader] could not load", name, container)
		return
	end
	local mesh: MeshPart? = nil
	for _, d in (container :: Instance):GetDescendants() do
		if d:IsA("MeshPart") and (not mesh or d.Size.Magnitude > (mesh :: MeshPart).Size.Magnitude) then
			mesh = d
		end
	end
	if not mesh then
		table.insert(AssetLoader.failed, name)
		;(container :: Instance):Destroy()
		return
	end
	local mp = mesh :: MeshPart
	-- The FBX files keep Blender's Z-up vertices plus a -90° X node rotation; the importer puts
	-- that rotation on the part. Try it first so a tie (±90° give the same box) keeps it.
	local imported = mp.CFrame.Rotation
	mp.Parent = nil
	;(container :: Instance):Destroy()
	-- pick the orientation whose proportions match the manifest, then force the exact size
	local best, bestErr = imported, boxError(rotatedSize(mp.Size, imported), rec.size) - 1e-3
	for _, r in ROTS do
		local e = boxError(rotatedSize(mp.Size, r), rec.size)
		if e < bestErr then
			best, bestErr = r, e
		end
	end
	if name == "HotDogStand" then -- one line to check orientation in Studio's Output
		print("[AssetLoader] HotDogStand size", mp.Size, "imported rot", imported:ToOrientation(), "using", best == imported)
	end
	local yaw = CFrame.Angles(0, math.rad(Config.MeshYaw or 0), 0)
	local localSize = rotatedSize(rec.size, best:Inverse())
	mp.Size = localSize
	mp.Anchored = true
	mp.CanCollide = true
	-- (CollisionFidelity can only be set by plugins/Open Cloud, not at runtime; keep the default)
	mp.CFrame = yaw * CFrame.new(0, rec.size.Y / 2, 0) * best
	mp.Name = "Mesh"
	local model = Instance.new("Model")
	model.Name = name
	mp.Parent = model
	model.PrimaryPart = mp
	model.WorldPivot = CFrame.new()
	model.Parent = folder
	AssetLoader.loaded += 1
	if AssetLoader.onLoaded then
		task.spawn(AssetLoader.onLoaded, name)
	end
end

-- Uploaded pictures are Decal assets. rbxthumb links to a Decal don't render, so load each Decal
-- (owned by the publisher, like the meshes) and publish its real image as an attribute on
-- ReplicatedStorage.ImageIds: <name> = "rbxassetid://<image id>". Kit.icon and the sky read it.
local function loadImages()
	local out = ReplicatedStorage:FindFirstChild("ImageIds")
	if not out then
		out = Instance.new("Folder")
		out.Name = "ImageIds"
		out.Parent = ReplicatedStorage
	end
	local queue = {}
	for name, id in AssetIds.Images do
		table.insert(queue, { name = name, id = id })
	end
	for _ = 1, 6 do
		task.spawn(function()
			while #queue > 0 do
				local job = table.remove(queue)
				if not job then
					break
				end
				local ok, container = pcall(InsertService.LoadAsset, InsertService, job.id)
				if ok and container then
					local decal = (container :: Instance):FindFirstChildWhichIsA("Decal", true)
					if decal and decal.Texture ~= "" then
						(out :: Instance):SetAttribute(job.name, decal.Texture)
					end
					;(container :: Instance):Destroy()
				else
					warn("[AssetLoader] could not load image", job.name, container)
				end
			end
		end)
	end
end

function AssetLoader.init()
	task.spawn(loadImages)
	local folder = ReplicatedStorage:FindFirstChild("Assets") :: Folder?
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "Assets"
		f.Parent = ReplicatedStorage
		folder = f
	end
	local queue = {}
	for name, rec in AssetIds.Models do
		if not (folder :: Folder):FindFirstChild(name) then
			table.insert(queue, { name = name, rec = rec })
		end
	end
	if #queue == 0 then
		return
	end
	print(string.format("[AssetLoader] loading %d meshes in the background", #queue))
	for _ = 1, 6 do
		task.spawn(function()
			while #queue > 0 do
				local job = table.remove(queue)
				if job then
					-- one bad asset must not stop this worker
					local res = table.pack(pcall(loadOne, job.name, job.rec, folder :: Folder))
					if not res[1] then
						table.insert(AssetLoader.failed, job.name)
						warn("[AssetLoader] could not set up", job.name, res[2])
					end
				end
			end
		end)
	end
end

return AssetLoader
