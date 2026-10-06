--!strict
-- World interactables: proximity prompts open the right menu per tag,
-- gates open locally once their island is bought, prompt texts show prices,
-- and the Islands window lists every island with Teleport / Open buttons.

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared:WaitForChild("Areas"))
local Eggs = require(Shared:WaitForChild("Eggs"))
local Types = require(Shared:WaitForChild("Types"))

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local Format = require("../Core/Format")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Toasts = require("../UI/Toasts")

type PlayerState = Types.PlayerState

local World = {}

local TAGS = { "EggStand", "Gate", "ExpeditionBoard", "CraftMachine", "RebirthStatue", "IndexBook" }

-- Finds the nearest ancestor (or self) carrying one of our tags.
local function taggedAncestor(inst: Instance): (Instance?, string?)
	local cur: Instance? = inst
	while cur and cur ~= workspace and cur ~= game do
		for _, tag in TAGS do
			if CollectionService:HasTag(cur, tag) then
				return cur, tag
			end
		end
		cur = cur.Parent
	end
	return nil, nil
end

function World.OpenGate(areaId: string)
	local a = Areas.ById[areaId]
	local d = State.Data
	if not a or not d then
		return
	end
	if d.Areas[areaId] then
		Toasts.Show(a.Name .. " is already open!", "info")
		return
	end
	-- previous island must be open first
	local prev = Areas.List[a.Index - 1]
	if prev and not d.Areas[prev.Id] then
		Toasts.Show("Open " .. prev.Name .. " first!", "bad")
		return
	end
	local canAfford = d.Coins >= a.GateCost
	Windows.Confirm(
		"Open " .. a.Name .. "?",
		a.Blurb .. "\n\nCost: " .. Theme.Icons.Coins .. " <b>" .. Format.num(a.GateCost) .. "</b>"
			.. (if canAfford then "" else "\n<font color=\"#F05454\">You need " .. Format.num(a.GateCost - d.Coins) .. " more coins.</font>"),
		"Open " .. Theme.Icons.Coins .. Format.num(a.GateCost),
		if canAfford then "Green" else "Grey",
		function()
			local res = Remote.CallOnce("OpenGate", areaId)
			if res then
				Sounds.Play("Reward")
				Toasts.Banner(a.Name .. " unlocked!", "New egg and new treasure ahead", Theme.Colors.Coins, 3)
			end
		end
	)
end

-- Gates ------------------------------------------------------------------------

local function setBarrier(gate: Instance, open: boolean)
	local barrier = gate:FindFirstChild("Barrier", true)
	if barrier and barrier:IsA("BasePart") then
		barrier.CanCollide = not open
		barrier.LocalTransparencyModifier = if open then 1 else 0
		for _, d in barrier:GetDescendants() do
			if d:IsA("Decal") then
				d.LocalTransparencyModifier = if open then 1 else 0
			elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Beam") then
				(d :: any).Enabled = not open
			end
		end
	end
end

local function refreshGate(gate: Instance)
	local d = State.Data
	local areaId = gate:GetAttribute("AreaId")
	if type(areaId) ~= "string" then
		return
	end
	local a = Areas.ById[areaId]
	local open = d ~= nil and d.Areas[areaId] == true
	setBarrier(gate, open)
	for _, p in gate:GetDescendants() do
		if p:IsA("ProximityPrompt") then
			p.Enabled = not open
			if a then
				p.ObjectText = a.Name
				p.ActionText = "Open " .. Theme.Icons.Coins .. Format.num(a.GateCost)
			end
		end
	end
end

local function refreshStand(stand: Instance)
	local eggId = stand:GetAttribute("EggId")
	local egg = if type(eggId) == "string" then Eggs.ById[eggId] else nil
	if not egg then
		return
	end
	for _, p in stand:GetDescendants() do
		if p:IsA("ProximityPrompt") then
			p.ObjectText = egg.Name
			p.ActionText = "Hatch " .. (if egg.Currency == "Gems" then Theme.Icons.Gems else Theme.Icons.Coins) .. Format.num(egg.Cost)
		end
	end
end

local function refreshAll()
	for _, g in CollectionService:GetTagged("Gate") do
		refreshGate(g)
	end
end

-- Islands window -----------------------------------------------------------------

local islandsWin: Windows.Window
local islandList: ScrollingFrame

local function buildIslands()
	islandsWin = Windows.Create("Islands", { Title = "Islands", Icon = Theme.Icons.Islands, Color = Theme.Tones.Blue.Top })
	islandList = Kit.scroll({ Size = UDim2.fromScale(1, 1), Parent = islandsWin.Body }, {
		Kit.list(Enum.FillDirection.Vertical, 10),
		Kit.pad(4, 10, 4, 4),
	})
end

local islandsSig = ""

local function renderIslands(force: boolean?)
	if not islandsWin.IsOpen then
		return
	end
	local d = State.Data
	if not d then
		return
	end
	-- rebuild only when an island opens or a gate becomes affordable
	local sig = ""
	for _, a in Areas.List do
		sig ..= (if d.Areas[a.Id] then "1" else "0") .. (if d.Coins >= a.GateCost then "1" else "0")
	end
	if sig == islandsSig and not force then
		return
	end
	islandsSig = sig
	Kit.clear(islandList)
	for i, a in Areas.List do
		local open = d.Areas[a.Id] == true
		local prevOpen = i == 1 or d.Areas[Areas.List[i - 1].Id] == true
		local row = Kit.panel({
			Size = UDim2.new(1, -8, 0, 96),
			LayoutOrder = i,
			BackgroundColor3 = if open then Theme.Colors.Panel else Theme.Colors.PanelDark,
			Parent = islandList,
		})
		Kit.fitLabel(tostring(i), 34, {
			Size = UDim2.fromOffset(56, 80),
			Position = UDim2.fromOffset(8, 8),
			Color = Theme.Colors.Coins,
			Outline = true,
			Parent = row,
		})
		Kit.fitLabel(a.Name, 26, {
			Size = UDim2.new(1, -300, 0, 34),
			Position = UDim2.fromOffset(70, 8),
			Align = "Left",
			Parent = row,
		})
		Kit.fitLabel(a.Blurb .. "  " .. Theme.Icons.Coins .. "x" .. Format.num(a.CoinMult), 16, {
			Size = UDim2.new(1, -300, 0, 44),
			Position = UDim2.fromOffset(70, 44),
			Align = "Left",
			Font = Theme.FontBody,
			Color = Theme.Colors.TextDim,
			Parent = row,
		})
		local btnProps = {
			Size = UDim2.fromOffset(210, 64),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Parent = row,
		}
		if open then
			Kit.button("Teleport", "Blue", btnProps, function()
				local res = Remote.CallOnce("Teleport", a.Id)
				if res then
					Windows.Close()
				end
			end)
		elseif prevOpen then
			local b = Kit.button("Open " .. Theme.Icons.Coins .. Format.num(a.GateCost), "Green", btnProps, function()
				World.OpenGate(a.Id)
			end)
			if d.Coins < a.GateCost then
				Kit.setButton(b, { Tone = "Yellow" })
			end
		else
			Kit.button(Theme.Icons.Lock .. " Locked", "Grey", btnProps, function()
				Toasts.Show("Open " .. Areas.List[i - 1].Name .. " first!", "info")
			end)
		end
	end
end

function World.Init()
	buildIslands()
	islandsWin.Opened:Connect(function()
		renderIslands(true)
	end)
	local gatesSig: string? = nil
	State.Changed:Connect(function(d: any)
		-- gates only change when the opened islands do (open, rebirth)
		local sig = ""
		for _, a in Areas.List do
			sig ..= if d and d.Areas[a.Id] then "1" else "0"
		end
		if sig ~= gatesSig then
			gatesSig = sig
			refreshAll()
		end
		renderIslands()
	end)

	CollectionService:GetInstanceAddedSignal("Gate"):Connect(refreshGate)
	CollectionService:GetInstanceAddedSignal("EggStand"):Connect(refreshStand)
	for _, g in CollectionService:GetTagged("Gate") do
		refreshGate(g)
	end
	for _, s in CollectionService:GetTagged("EggStand") do
		refreshStand(s)
	end
	-- prompts can stream in after their model; refresh texts when they appear
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local inst, tag = taggedAncestor(prompt)
		if inst and tag == "Gate" then
			refreshGate(inst)
		elseif inst and tag == "EggStand" then
			refreshStand(inst)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who ~= game:GetService("Players").LocalPlayer then
			return
		end
		local inst, tag = taggedAncestor(prompt)
		if not inst or not tag then
			return
		end
		if tag == "EggStand" then
			local eggId = inst:GetAttribute("EggId")
			if type(eggId) == "string" then
				Windows.Open("Hatch", eggId, inst)
			end
		elseif tag == "Gate" then
			local areaId = inst:GetAttribute("AreaId")
			if type(areaId) == "string" then
				World.OpenGate(areaId)
			end
		elseif tag == "ExpeditionBoard" then
			Windows.Open("Expeditions")
		elseif tag == "CraftMachine" then
			Windows.Open("Craft")
		elseif tag == "RebirthStatue" then
			Windows.Open("Rebirth")
		elseif tag == "IndexBook" then
			Windows.Open("Index")
		end
	end)
end

return World
