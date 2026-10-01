--!strict
-- Remote objects. The server creates them; clients wait for them.
--   Action   (RemoteFunction)  client -> server: FarmAction -> ActionResult
--   Snapshot (RemoteEvent)     server -> owner:  FarmSnapshot (throttled, only when changed)
--   FarmEvent(RemoteEvent)     server -> owner:  (name, data) for effects and toasts
--   Commerce (RemoteFunction)  client -> server: { productId } -> result (checkout adapter)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local DEFS: { [string]: string } = {
	Action = "RemoteFunction",
	Commerce = "RemoteFunction",
	Snapshot = "RemoteEvent",
	FarmEvent = "RemoteEvent",
}

local folder: Folder
if RunService:IsServer() then
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
	end
	folder = f :: Folder
	for name, class in DEFS do
		if not folder:FindFirstChild(name) then
			local r = Instance.new(class)
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.Get(name: string): Instance
	assert(DEFS[name], "unknown remote " .. name)
	return folder:WaitForChild(name)
end

return Net
