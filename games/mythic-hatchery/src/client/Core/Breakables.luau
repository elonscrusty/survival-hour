--!strict
-- Index of breakables in workspace (CollectionService tag "Breakable"), by
-- their `Id` attribute, with cached bounds for effects and pet positioning.

local CollectionService = game:GetService("CollectionService")

local Signal = require("./Signal")

local Breakables = {}

export type Info = {
	Id: string,
	Model: Model,
	Kind: string,
	Area: string,
	Center: Vector3, -- bounding box centre
	Size: Vector3,
	Bottom: number, -- Y of the bounding box bottom
	BoundsAt: number,
}

Breakables.Added = Signal.new() -- (info)
Breakables.Removed = Signal.new() -- (id, info)

local byId: { [string]: Info } = {}
local byModel: { [Instance]: Info } = {}

local function measure(info: Info)
	local ok, cf, size = pcall(function()
		return info.Model:GetBoundingBox()
	end)
	if ok and cf and size then
		info.Center = (cf :: CFrame).Position
		info.Size = size :: Vector3
		info.Bottom = info.Center.Y - (size :: Vector3).Y / 2
	end
	info.BoundsAt = os.clock()
end

local function add(inst: Instance)
	if not inst:IsA("Model") or byModel[inst] then
		return
	end
	local id = inst:GetAttribute("Id")
	if type(id) ~= "string" then
		-- the server may set Id just after tagging; try again when it arrives
		local conn: RBXScriptConnection? = nil
		conn = inst:GetAttributeChangedSignal("Id"):Connect(function()
			if conn then
				conn:Disconnect()
			end
			add(inst)
		end)
		return
	end
	local kind = inst:GetAttribute("Kind")
	local area = inst:GetAttribute("Area")
	local info: Info = {
		Id = id,
		Model = inst,
		Kind = if type(kind) == "string" then kind else "CoinPile",
		Area = if type(area) == "string" then area else "",
		Center = inst:GetPivot().Position,
		Size = Vector3.new(4, 3, 4),
		Bottom = inst:GetPivot().Position.Y,
		BoundsAt = 0,
	}
	measure(info)
	byId[id] = info
	byModel[inst] = info
	Breakables.Added:Fire(info)
	-- parts can stream in a moment later; measure again
	task.delay(1, function()
		if byModel[inst] == info then
			measure(info)
		end
	end)
end

local function remove(inst: Instance)
	local info = byModel[inst]
	if not info then
		return
	end
	byModel[inst] = nil
	if byId[info.Id] == info then
		byId[info.Id] = nil
	end
	Breakables.Removed:Fire(info.Id, info)
end

function Breakables.Get(id: string?): Info?
	if not id or id == "" then
		return nil
	end
	local info = byId[id]
	if info and info.Model.Parent == nil then
		return nil
	end
	return info
end

function Breakables.FromModel(inst: Instance?): Info?
	local cur = inst
	while cur and cur ~= workspace do
		local info = byModel[cur]
		if info then
			return info
		end
		cur = cur.Parent
	end
	return nil
end

function Breakables.All(): { [string]: Info }
	return byId
end

function Breakables.Init()
	CollectionService:GetInstanceAddedSignal("Breakable"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Breakable"):Connect(remove)
	for _, inst in CollectionService:GetTagged("Breakable") do
		add(inst)
	end
end

return Breakables
