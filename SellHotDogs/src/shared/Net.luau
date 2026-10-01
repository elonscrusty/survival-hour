--!strict
-- Remote names in one place. The server creates them; clients wait for them.
--   Action   (client -> server)  Action:FireServer(name, ...)
--   State    (server -> owner)   full snapshot of the player's own game state
--   Notify   (server -> owner)   toasts, effects, phone and race updates: (kind, data)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local NAMES = { "Action", "State", "Notify" }

local folder: Folder
if RunService:IsServer() then
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
	end
	folder = f :: Folder
	for _, n in NAMES do
		if not folder:FindFirstChild(n) then
			local r = Instance.new("RemoteEvent")
			r.Name = n
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
