--!strict
-- Remote registry. The server creates every remote at boot (Net.Init); clients
-- wait for them. One list prevents name typos between client and server.
-- Payload shapes are documented in docs/CONTRACTS.md.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

-- RemoteFunctions (client -> server request, server returns a Result table:
-- { ok = true, ... } or { ok = false, err = "Human readable reason" }).
Net.Functions = {
	-- eggs and incubators
	"BuyEgg", -- (eggId, count 1..3) -> { ok, eggs = { EggItem } } into the egg bag
	"Incubate", -- (eggUid, slot?) -> { ok, slot } place a bag egg into a free incubator
	"Hatch", -- (slot) -> { ok, creature = Creature, new = boolean } when the timer is done
	"SkipIncubation", -- (slot) -> { ok, gems } finish early with gems
	-- creatures
	"Care", -- (uid, task "Feed"|"Play"|"Sleep") -> { ok, growth, stage, stageUp = boolean }
	"EquipCreature", -- (uid, equip: boolean)
	"EquipBest", -- ()
	"UnequipAll", -- ()
	"ReleaseCreatures", -- ({ uid }) -> { ok, coins } (delete for a small coin refund)
	"LockCreature", -- (uid, locked: boolean)
	"RenameCreature", -- (uid, name) -> { ok, name } (TextService filtered)
	"UsePotion", -- (uid, potionId) -> { ok } buys with gems and applies
	"Fuse", -- (uidA, uidB) -> { ok, egg = EggItem }
	"BuyCosmetic", -- (cosmeticId) -> { ok }
	"WearCosmetic", -- (uid, slot, cosmeticId | "") -> { ok }
	"Mount", -- (uid | nil) -> { ok } start/stop riding (Adult+ with Ride or Fly potion)
	-- world and progression
	"OpenGate", -- (areaId)
	"Teleport", -- (areaId)
	"Rebirth", -- ()
	"StartExpedition", -- (areaId, durationKey, { uid }) -> { ok, slot }
	"ClaimExpedition", -- (slot) -> { ok, reward = Reward }
	"SkipExpedition", -- (slot) -> { ok, gems }
	"ClaimDaily", -- () -> { ok, reward, streak }
	"ClaimPlaytime", -- (index) -> { ok, reward }
	"ClaimQuest", -- (index) -> { ok, reward }
	"ClaimIndex", -- (tier) -> { ok, reward }
	"SetSetting", -- (key, value) -> { ok }
	"RaceJoin", -- () -> { ok } queue for the next sky race (must be flying)
	"RaceLeave", -- () -> { ok }
	-- trading
	"TradeRequest", -- (targetUserId) -> { ok }
	"TradeRespond", -- (fromUserId, accept: boolean) -> { ok }
	"TradeSetOffer", -- ({ uid }, gems) -> { ok }
	"TradeReady", -- (ready: boolean) -> { ok }
	"TradeCancel", -- () -> { ok }
	-- Studio only
	"DevPurchase", -- (key) simulate buying a pass/product whose Id is 0
	"DevAction", -- (action) test shortcuts (DevService)
}
	"EquipPet", -- (uid, equip: boolean)
	"EquipBest", -- ()
	"UnequipAll", -- ()
	"DeletePets", -- ({ uid }) -> { ok, coins }
	"LockPet", -- (uid, locked: boolean)
	"CraftPet", -- (uid) -> { ok, pet = PetInstance } combines Config.CraftCost copies (same species, variant, shiny) into the next variant
	"OpenGate", -- (areaId)
	"Teleport", -- (areaId) to an opened area's spawn
	"Rebirth", -- ()
	"StartExpedition", -- (areaId, durationKey, { uid }) -> { ok }
	"ClaimExpedition", -- (slot) -> { ok, reward = ExpeditionReward }
	"SkipExpedition", -- (slot) -> { ok } (costs gems)
	"ClaimDaily", -- () -> { ok, reward }
	"ClaimPlaytime", -- (index) -> { ok, reward }
	"ClaimQuest", -- (index) -> { ok, reward }
	"ClaimIndex", -- (tier) -> { ok, reward }
	"SetSetting", -- (key, value) -> { ok }
	"TradeRequest", -- (targetUserId) -> { ok }
	"TradeRespond", -- (fromUserId, accept: boolean) -> { ok }
	"TradeSetOffer", -- ({ uid }, gems) -> { ok }
	"TradeReady", -- (ready: boolean) -> { ok }
	"TradeCancel", -- () -> { ok }
	"DevPurchase", -- (key) Studio only: simulate buying a pass/product whose Id is 0
	"DevAction", -- (action) Studio only: test shortcuts (DevService)
}

-- RemoteEvents.
Net.Events = {
	-- server -> client
	"State", -- (PlayerState) full snapshot of the local player's data
	"Notify", -- (kind: string, data: table) toasts / effects, see CONTRACTS.md
	"Trade", -- (TradeView | nil) current trade window state
	"Race", -- (RaceView | nil) the sky race this player is queued in or running
	-- client -> server
	"SetTarget", -- (breakableId: string?) send equipped creatures at a breakable (nil = recall)
	"RaceCheckpoint", -- (index) client reports passing a checkpoint ring; server validates position and timing
	"ClientReady", -- () UI loaded; server replies with State
	"RingFocus", -- (targetUserId: number?) in the Creature Ring, focus your creatures on that player's (nil = nearest)
}

local folder: Folder? = nil

local function getFolder(): Folder
	local existing = folder
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
		if not f then
			local nf = Instance.new("Folder")
			nf.Name = "Remotes"
			nf.Parent = ReplicatedStorage
			f = nf
		end
		folder = f
		return f :: Folder
	end
	local f = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	folder = f
	return f
end

-- Server: create every remote. Safe to call twice.
function Net.Init()
	local f = getFolder()
	for _, name in Net.Functions do
		if not f:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = f
		end
	end
	for _, name in Net.Events do
		if not f:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = f
		end
	end
end

function Net.Event(name: string): RemoteEvent
	assert(table.find(Net.Events, name), "unknown event " .. name)
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name) :: RemoteEvent
	end
	return f:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	assert(table.find(Net.Functions, name), "unknown function " .. name)
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name) :: RemoteFunction
	end
	return f:WaitForChild(name) :: RemoteFunction
end

return Net
