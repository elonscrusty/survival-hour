-- Remote names in one place. The server creates them; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	"State", -- server -> client: full profile snapshot
	"Notify", -- server -> client: toast text
	"Race", -- server -> client: race state updates
	"Hatched", -- server -> client: hatch reveal
	"Equip", -- client -> server: uid
	"Ride", -- client -> server: true/false
	"Release", -- client -> server: uid
	"Dash", -- client -> server
	"BuyCosmetic", -- client -> server: cosmetic id
	"SetCosmetic", -- client -> server: kind, id or nil (applies to ridden pet)
	"Rename", -- client -> server: uid, name
	"LeaveRace", -- client -> server: give up the current race
	"TutorialDone", -- client -> server
	"ClaimDaily", -- client -> server: "Login" or a quest id
	"SetMuted", -- client -> server: true/false
}

Net.Functions = {
	"Hatch", -- client -> server: egg id -> ok, species | error
	"Redeem", -- client -> server: code -> ok, message
}

local folder: Folder

function Net.Init()
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, n in Net.Events do
			local r = Instance.new("RemoteEvent")
			r.Name = n
			r.Parent = folder
		end
		for _, n in Net.Functions do
			local r = Instance.new("RemoteFunction")
			r.Name = n
			r.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
end

function Net.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
