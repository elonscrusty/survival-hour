--!nonstrict
-- Resolves the ids in Shared/IconIds to showable images. Uploads done as Decals give a
-- Decal id, which an ImageLabel can't display; the image inside it has its own id.
-- InsertService can open Decals owned by the experience's creator, so each id is tried
-- once: a Decal's Texture is published as an attribute on ReplicatedStorage.ImageMap
-- (name = the listed id). Plain Image ids fail to load here and stay as they are.
-- Clients (UI/Icons) prefer the resolved texture and update when it arrives.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IconIds"))

local ImageService = {}

local folder: Folder

function ImageService.Init(_ctx)
	folder = Instance.new("Folder")
	folder.Name = "ImageMap"
	folder.Parent = ReplicatedStorage
end

local function resolve(id: number)
	local ok, model = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if not ok or not model then
		return
	end
	local decal = model:FindFirstChildWhichIsA("Decal", true)
	if decal and decal.Texture ~= "" then
		folder:SetAttribute(tostring(id), decal.Texture)
	end
	model:Destroy()
end

function ImageService.Start()
	local seen = {}
	local running = 0
	for _, id in IconIds do
		if type(id) == "number" and id > 0 and not seen[id] then
			seen[id] = true
			while running >= 8 do
				task.wait(0.1)
			end
			running += 1
			task.spawn(function()
				resolve(id)
				running -= 1
			end)
		end
	end
end

return ImageService
