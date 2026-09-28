--!strict
-- Remote registry. The server creates every remote at boot; clients wait for
-- them. Using one list prevents typos between client and server.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.Events = {
	-- server -> client
	"Notify", -- (text, kind)
	"InventorySync", -- (snapshot)
	"ProfileSync", -- (profile view)
	"LobbySync", -- (lobby view)
	"MatchEvent", -- (eventName, payload)
	"MapData", -- (map summary)
	"ChannelState", -- (state table | nil)
	"StorageSync", -- (storageId, items, mode)
	"CraftSync", -- (workbench level, team storage totals)
	"HitFeedback", -- (kind, amount)
	"Fx", -- (fxName, payload) broadcast visual/audio effects
	"AbilitySync", -- (cooldownEndsAt, active info)
	"Reveal", -- (kind, list) personal highlights (crates, animals)
	-- client -> server
	"Equip",
	"SwapWeapons",
	"DropItem",
	"Attack",
	"BlockState",
	"UseBandage",
	"Eat", -- (resourceId) eat berries/mushrooms from the pack
	"ChannelStop",
	"Craft",
	"UpgradeWorkbench",
	"PlaceStructure",
	"StorageAction",
	"UseAbility",
	"RequestRevive",
	"BuyInMatch",
	"LobbyAction",
	"DevCommand",
	"ClientReady",
	"Sprint", -- (bool) hold-to-sprint state
	"LeaveMatch", -- eliminated players go back to the lobby early
}

local folder: Folder

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
		end
		folder = f :: Folder
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder
end

function Net.Init()
	assert(RunService:IsServer(), "Net.Init is server-only")
	local f = getFolder()
	for _, name in Net.Events do
		if not f:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = f
		end
	end
end

function Net.Event(name: string): RemoteEvent
	assert(table.find(Net.Events, name), "Unknown remote " .. name)
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name) :: RemoteEvent
	end
	return f:WaitForChild(name) :: RemoteEvent
end

-- Convenience helpers ------------------------------------------------------------------

function Net.FireClient(name: string, player: Player, ...: any)
	Net.Event(name):FireClient(player, ...)
end

function Net.FireAll(name: string, ...: any)
	Net.Event(name):FireAllClients(...)
end

function Net.FireList(name: string, players: { Player }, ...: any)
	local ev = Net.Event(name)
	for _, p in players do
		if p.Parent then
			ev:FireClient(p, ...)
		end
	end
end

return Net
