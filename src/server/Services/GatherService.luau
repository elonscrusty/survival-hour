--!nonstrict
-- Resource nodes, driven by shared/Resources (balance) and
-- Logic/ResourceRules (state machine). One service handles every node type:
--   Trees   (axe hits or the Chop prompt): Healthy -> Damaged (notch shows,
--           trunk shudders) -> Felled (top tips over, anchored tween) ->
--           Stump -> Respawning (sapling grows back) -> Healthy.
--   Harvest (hand prompt): gathers until exhausted; the model's `Yield` parts
--           hide, then return after the respawn time.
-- Respawns wait until no character/structure/animal stands on the spot.
-- Items that don't fit in the pack spill as pickups at the node, so a felled
-- tree's bonus wood is never lost.
-- Model part roles are documented in docs/OVERHAUL.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Net = require(Shared:WaitForChild("Net"))
local Resources = require(Shared:WaitForChild("Resources"))
local Logic = Shared:WaitForChild("Logic")
local ResourceRules = require(Logic:WaitForChild("ResourceRules"))
local InventoryModel = require(Logic:WaitForChild("InventoryModel"))
local Rng = require(Logic:WaitForChild("Rng"))
local Models = Shared:WaitForChild("Models")
local Flora = require(Models:WaitForChild("Flora"))
local Skins = require(Models:WaitForChild("Skins"))

local GatherService = {}

type Node = {
	Id: number,
	Def: Resources.Def,
	S: ResourceRules.State,
	Model: Model,
	Pos: Vector3,
	Prompt: ProximityPrompt?,
	Top: Model?, -- trees: everything above the stump
	TopHome: CFrame?, -- Top pivot when standing
	Yield: { BasePart }, -- harvest nodes: parts hidden while exhausted
	Notches: { BasePart },
	Anim: number, -- bumps to cancel running tweens
}

local ctx: any
local nodes: { Node } = {}
local byModel: { [Model]: Node } = {}
local rng = Rng.new(os.time())

function GatherService.Init(c)
	ctx = c
	ctx.MatchService.On("MatchStarting", GatherService._build)
	ctx.MatchService.On("MatchCleanup", function()
		nodes = {}
		byModel = {}
	end)
	ctx.ChannelService.OnPrompt("Gather", GatherService._onGatherPrompt)
end

function GatherService.Start()
	while true do
		task.wait(Resources.TickInterval)
		if ctx.MatchService.Active then
			local t = os.clock()
			for _, n in nodes do
				if n.S.State ~= "Healthy" and n.S.State ~= "Damaged" then
					local entered = ResourceRules.Advance(n.Def, n.S, t, function()
						return GatherService._spotClear(n)
					end)
					if entered then
						GatherService._show(n, entered)
					end
				end
			end
		end
	end
end

-- Building ---------------------------------------------------------------------------------

local TIER_NAMES = { "Crude", "Stone", "Iron", "Steel" }

-- "Stone Axe" style name of the weakest tool that works on a node.
local function toolNeed(def: Resources.Def): string
	return (TIER_NAMES[def.MinTier or 1] or "") .. " " .. def.RequiredTool
end

local function promptText(def: Resources.Def): (string, string)
	if def.Kind == "Tree" then
		return "Chop (" .. toolNeed(def) .. "+)", def.Label
	elseif def.RequiredTool == "Pickaxe" then
		return "Mine (" .. toolNeed(def) .. "+)", def.Label
	elseif def.PerHit.Berries or def.PerHit.Mushroom then
		return "Pick", def.Label
	end
	return "Gather", def.Label
end

function GatherService._build(map: any)
	local folder = Instance.new("Folder")
	folder.Name = "Resources"
	folder.Parent = map.Folder
	local O = map.Origin
	local modelRng = Random.new(map.Seed)
	for i, nd in map.Layout.Nodes do
		local def = Resources.Get(nd.Type)
		if not def then
			warn("[GatherService] unknown resource type " .. tostring(nd.Type))
			continue
		end
		local x, z = nd.X + O.X, nd.Z + O.Z
		local y = ctx.WorldService.GroundY(x, z) - 0.15
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, (i * 2.399) % 6.283, 0)
		local m: Model
		if def.Model == "ResourceTree" then
			m = Flora.ResourceTree(cf, modelRng, def.ModelArgs[1], nd.Species or "Pine", folder)
		else
			m = Flora[def.Model](cf, modelRng, folder)
		end
		m.Name = def.Id
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		m:SetAttribute("Node", def.Id)
		local node: Node = {
			Id = i,
			Def = def,
			S = ResourceRules.New(def),
			Model = m,
			Pos = Vector3.new(x, y, z),
			Prompt = nil,
			Top = m:FindFirstChild("Top") :: Model?,
			TopHome = nil,
			Yield = {},
			Notches = {},
			Anim = 0,
		}
		if node.Top then
			node.TopHome = node.Top:GetPivot()
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d:SetAttribute("BaseT", d.Transparency)
				if d.Name == "Notch" then
					table.insert(node.Notches, d)
				elseif d:GetAttribute("Yield") then
					table.insert(node.Yield, d)
				end
			end
		end
		if def.Kind == "Harvest" and #node.Yield == 0 then
			-- No marked yield parts: the whole model (except Root) is the yield.
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and d ~= m.PrimaryPart then
					table.insert(node.Yield, d)
				end
			end
		end
		local action, object = promptText(def)
		local p = ctx.ChannelService.MakePrompt(m.PrimaryPart, "Gather", action, object, def.Range)
		if def.RequiredTool ~= "Hand" then
			p:SetAttribute("NeedsTool", def.RequiredTool)
			p:SetAttribute("MinTier", def.MinTier or 1)
			m:SetAttribute("NeedsTool", def.RequiredTool)
		end
		p:SetAttribute("Rarity", def.Rarity)
		node.Prompt = p
		table.insert(nodes, node)
		byModel[m] = node
		if i % 40 == 0 then
			task.wait()
		end
	end
end

function GatherService.FromPart(part: Instance): Node?
	local m = part:FindFirstAncestorOfClass("Model")
	while m do
		local n = byModel[m]
		if n then
			return if ResourceRules.Available(n.S) then n else nil
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Nodes of one resource type (for UI/debug/tests).
function GatherService.Count(): number
	return #nodes
end

-- Visuals ------------------------------------------------------------------------------------

local function setParts(list: { BasePart }, visible: boolean, collide: boolean?)
	for _, d in list do
		d.Transparency = if visible then (d:GetAttribute("BaseT") :: number? or 0) else 1
		if collide ~= nil and d.CanQuery then
			d.CanCollide = collide and visible
		end
	end
end

local function topParts(n: Node): { BasePart }
	local out = {}
	if n.Top then
		for _, d in n.Top:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
	end
	return out
end

-- Remembers which Top parts collide so regrowth can restore them.
local function restoreTop(n: Node, visible: boolean)
	for _, d in topParts(n) do
		if d:GetAttribute("BaseCollide") == nil then
			d:SetAttribute("BaseCollide", d.CanCollide)
		end
		d.Transparency = if visible then (d:GetAttribute("BaseT") :: number? or 0) else 1
		d.CanCollide = visible and d:GetAttribute("BaseCollide") == true
		d.CanQuery = visible and d:GetAttribute("BaseCollide") == true
	end
end

-- Drives a model's pivot over time with an easing curve (anchored parts, no physics).
local function pivotTween(n: Node, model: Model, from: CFrame, to: CFrame, duration: number, style: Enum.EasingStyle, dir: Enum.EasingDirection)
	n.Anim += 1
	local token = n.Anim
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local a = math.clamp((os.clock() - t0) / duration, 0, 1)
			if token ~= n.Anim or not model.Parent then
				return
			end
			model:PivotTo(from:Lerp(to, TweenService:GetValue(a, style, dir)))
			if a >= 1 then
				return
			end
			task.wait()
		end
	end)
end

local function shudder(n: Node, from: Vector3)
	local top, home = n.Top, n.TopHome
	if not top or not home or n.S.State ~= "Damaged" then
		return
	end
	-- lean a couple of degrees away from the hit, then settle
	local away = (home.Position - from) * Vector3.new(1, 0, 1)
	if away.Magnitude < 0.01 then
		return
	end
	local axis = away.Unit:Cross(Vector3.yAxis)
	local lean = CFrame.fromAxisAngle(axis, math.rad(-2.5))
	local leaned = CFrame.new(home.Position) * lean * home.Rotation
	n.Anim += 1
	local token = n.Anim
	task.spawn(function()
		top:PivotTo(leaned)
		task.wait(0.08)
		if token == n.Anim and n.S.State == "Damaged" then
			top:PivotTo(home)
		end
	end)
end

local function fell(n: Node, from: Vector3)
	local top, home = n.Top, n.TopHome
	if not top or not home then
		return
	end
	for _, d in topParts(n) do
		if d:GetAttribute("BaseCollide") == nil then
			d:SetAttribute("BaseCollide", d.CanCollide)
		end
		d.CanCollide = false -- a falling tree never shoves players
	end
	local away = (home.Position - from) * Vector3.new(1, 0, 1)
	if away.Magnitude < 0.01 then
		away = home.LookVector * Vector3.new(1, 0, 1)
	end
	local axis = away.Unit:Cross(Vector3.yAxis)
	local down = CFrame.new(home.Position) * CFrame.fromAxisAngle(axis, math.rad(-86)) * home.Rotation
	pivotTween(n, top, home, down, n.Def.FellTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	ctx.Util.PlaySound("TreeCreak", n.Model.PrimaryPart)
	task.delay(n.Def.FellTime, function()
		if n.S.State == "Felled" or n.S.State == "Stump" then
			ctx.Util.PlaySound("TreeFall", n.Model.PrimaryPart)
			local landing = home.Position + away.Unit * 10
			Net.FireAll("Fx", "ResourceBreak", { Pos = landing, Kind = n.Def.Effects.Break, Big = true })
		end
	end)
end

-- Applies the look for a state the node just entered.
function GatherService._show(n: Node, state: string, from: Vector3?)
	local def = n.Def
	n.Model:SetAttribute("State", state)
	if n.Prompt then
		n.Prompt.Enabled = state == "Healthy" or state == "Damaged"
	end
	if def.Kind == "Tree" then
		-- mesh-pack stump (Skins): visible whenever the tree isn't standing
		Skins.SetTagged(n.Model, "SkinStump", state ~= "Healthy" and state ~= "Damaged")
		if state == "Healthy" then
			n.Anim += 1
			if n.Top and n.TopHome then
				local top, home = n.Top, n.TopHome
				pcall(function()
					top:ScaleTo(1)
				end)
				top:PivotTo(home)
			end
			restoreTop(n, true)
			setParts(n.Notches, false)
		elseif state == "Damaged" then
			setParts(n.Notches, true)
		elseif state == "Felled" then
			setParts(n.Notches, false)
			fell(n, from or n.Pos)
		elseif state == "Stump" then
			-- The felled trunk lies on the ground for a moment, then fades away.
			n.Anim += 1
			local token = n.Anim
			task.spawn(function()
				task.wait(2.5)
				local parts = topParts(n)
				for step = 1, 10 do
					if token ~= n.Anim then
						return
					end
					for _, d in parts do
						local base = d:GetAttribute("BaseT") :: number? or 0
						d.Transparency = base + (1 - base) * step / 10
					end
					task.wait(0.08)
				end
				if token == n.Anim then
					restoreTop(n, false)
				end
			end)
		elseif state == "Respawning" then
			-- Grow back from a sapling around the hinge (anchored scale-up).
			if n.Top and n.TopHome then
				n.Anim += 1
				local token = n.Anim
				local top, home = n.Top, n.TopHome
				top:PivotTo(home)
				pcall(function()
					top:ScaleTo(0.2)
				end)
				restoreTop(n, true)
				for _, d in topParts(n) do
					d.CanCollide = false -- saplings don't block
				end
				task.spawn(function()
					local t0 = os.clock()
					while token == n.Anim and top.Parent do
						local a = math.clamp((os.clock() - t0) / def.GrowTime, 0, 1)
						pcall(function()
							top:ScaleTo(0.2 + 0.8 * TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
						end)
						if a >= 1 then
							break
						end
						task.wait(0.1)
					end
				end)
			end
		end
	else
		if state == "Healthy" then
			setParts(n.Yield, true, true)
		elseif state == "Exhausted" then
			setParts(n.Yield, false, false)
		elseif state == "Respawning" then
			-- fade the yield back in over the grow time
			for _, d in n.Yield do
				d.Transparency = 0.75
			end
		end
	end
end

-- Spot check before respawning -----------------------------------------------------------------

function GatherService._spotClear(n: Node): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { n.Model, workspace.Terrain }
	local parts = workspace:GetPartBoundsInRadius(n.Pos + Vector3.new(0, 2, 0), Resources.RespawnClearance + n.Def.Placement.Radius * 0.5, params)
	for _, part in parts do
		if ctx.Util.PlayerFromPart(part) or ctx.BuildService.FromPart(part) or ctx.WildlifeService.FromPart(part) then
			return false
		end
	end
	return true
end

-- Hits -----------------------------------------------------------------------------------------

-- Grants items; anything that doesn't fit spills as a pickup at the node.
local function grant(p: Player, n: Node, items: { [string]: number }): { string }
	local lines = {}
	for id, count in items do
		local added = ctx.InventoryService.AddResource(p, id, count)
		ctx.PowerupService.Tally(p, "Resources", count)
		if added > 0 then
			table.insert(lines, string.format("+%d %s", added, Items[id] and Items[id].Name or id))
		end
		if added < count then
			local root = ctx.Util.Root(p)
			local at = if root then n.Pos:Lerp(root.Position, 0.5) else n.Pos
			ctx.InventoryService.SpawnPickup(id, count - added, at + Vector3.new(0, 1, 0))
		end
	end
	return lines
end

-- Applies one hit/gather. `toolType`/`power` from the equipped item (hand = nil / HandPower).
function GatherService._apply(p: Player, n: Node, toolType: string?, power: number, tier: number?): boolean
	local def = n.Def
	if not ResourceRules.ToolOk(def, toolType, tier) then
		ctx.Util.Notify(p, "You need a " .. toolNeed(def) .. " or better for that.", "warn")
		return false
	end
	local inv = ctx.InventoryService.Get(p)
	if inv then
		local room = false
		for id in def.Yield or def.PerHit do
			if InventoryModel.SpaceFor(inv, id) > 0 then
				room = true
			end
		end
		if not room then
			ctx.Util.Notify(p, "Your pack is full. Deposit at your storage or craft a bigger backpack.", "warn")
			return false
		end
	end
	local r = ResourceRules.Hit(def, n.S, toolType, power, os.clock(), rng, tier)
	if not r.Ok then
		return false
	end
	local root = ctx.Util.Root(p)
	local from = if root then root.Position else n.Pos
	local lines = grant(p, n, r.Items)
	if #lines > 0 then
		ctx.Util.Notify(p, table.concat(lines, "  "), "gain")
	end
	ctx.Util.PlaySound(if r.Finished and def.Kind == "Tree" then "ChopHeavy" else def.Sounds.Hit, n.Model.PrimaryPart)
	local hitPos = n.Pos + Vector3.new(0, if def.Kind == "Tree" then 2.5 else 1, 0)
	-- non-tree nodes (rocks, bushes, ore) get a quick client-side jolt; trees shudder server-side
	Net.FireAll("Fx", "ResourceHit", { Pos = hitPos, From = from, Kind = def.Effects.Hit, Model = if def.Kind ~= "Tree" then n.Model else nil, Last = r.Finished })
	Net.FireClient("HitFeedback", p, "Resource", r.Dealt)
	n.Model:SetAttribute("Health", n.S.Health)
	n.Model:SetAttribute("MaxHealth", n.S.Max)
	if r.Finished then
		if def.Kind == "Harvest" then
			Net.FireAll("Fx", "ResourceBreak", { Pos = hitPos, Kind = def.Effects.Break })
		end
		GatherService._show(n, n.S.State, from)
		ctx.PowerupService.OnPickup(p, def.Id)
	else
		GatherService._show(n, n.S.State, from)
		if def.Kind == "Tree" then
			shudder(n, from)
		end
	end
	return true
end

local function equippedTool(p: Player): (string?, number, string?, string?, number?)
	local id, slot = ctx.InventoryService.EquippedItem(p)
	local def = id and Items[id]
	if def and def.ToolType then
		return def.ToolType, (def.ToolPower or 1) * ctx.PowerupService.ToolSpeedMult(p, def.ToolType), id, slot, def.ToolTier
	end
	return nil, Resources.HandPower, id, slot, nil
end

-- Best carried tool slot for a node (right type, high enough tier), or nil.
local function bestToolSlot(p: Player, def: Resources.Def): string?
	local inv = ctx.InventoryService.Get(p)
	if not inv then
		return nil
	end
	local best, bestTier = nil, 0
	for _, slot in InventoryModel.SlotNames do
		local st = inv.Slots[slot]
		local tdef = st and Items[st.Id]
		if tdef and tdef.ToolType == def.RequiredTool and (tdef.ToolTier or 1) >= (def.MinTier or 1) and (tdef.ToolTier or 1) > bestTier then
			best, bestTier = slot, tdef.ToolTier or 1
		end
	end
	return best
end

-- Melee swing on a node (from CombatService). Returns true if it counted (wears the tool).
function GatherService.Hit(p: Player, n: Node, itemId: string): boolean
	if not ResourceRules.Available(n.S) or n.Def.RequiredTool == "Hand" then
		return false -- hand nodes use their prompt
	end
	local def = Items[itemId]
	local toolType = def and def.ToolType
	if not toolType then
		ctx.Util.Notify(p, "You need a " .. toolNeed(n.Def) .. " or better for that.", "warn")
		return false
	end
	local power = (def.ToolPower or 1) * ctx.PowerupService.ToolSpeedMult(p, toolType)
	return GatherService._apply(p, n, toolType, power, def.ToolTier)
end

function GatherService._onGatherPrompt(p: Player, prompt: ProximityPrompt)
	local m = prompt:FindFirstAncestorOfClass("Model")
	local n = m and byModel[m]
	if not n or not ResourceRules.Available(n.S) or not ctx.Util.IsAlive(p) or not p:GetAttribute("InMatch") then
		return
	end
	local def = n.Def
	if def.RequiredTool ~= "Hand" then
		-- Prompt chopping: auto-equip a matching tool from the Tool slot, then channel one chop.
		local toolType, _, _, _, tier = equippedTool(p)
		if not ResourceRules.ToolOk(def, toolType, tier) then
			local slot = bestToolSlot(p, def)
			if slot then
				ctx.InventoryService._onEquip(p, slot)
			else
				ctx.Util.Notify(p, "You need a " .. toolNeed(def) .. " or better for that.", "warn")
				return
			end
		end
	end
	local duration = def.HarvestTime / ctx.PowerupService.GatherMult(p)
	ctx.ChannelService.Begin(p, {
		Kind = "Gather",
		Label = if def.Kind == "Tree" then "Chopping" elseif def.RequiredTool == "Pickaxe" then "Mining" elseif def.PerHit.Berries or def.PerHit.Mushroom then "Picking" else "Gathering",
		Duration = duration,
		Range = def.Range,
		InterruptOnDamage = true,
		Action = if def.Kind == "Tree" then "Chop" elseif def.RequiredTool == "Pickaxe" then "Mine" else "Gather",
		Position = function()
			return if ResourceRules.Available(n.S) then n.Pos else nil
		end,
		OnComplete = function()
			if not ResourceRules.Available(n.S) or not ctx.Util.IsAlive(p) then
				return
			end
			local toolType, power, _, slot, tier = equippedTool(p)
			if def.RequiredTool == "Hand" then
				toolType, power, tier = nil, Resources.HandPower, nil
			end
			if GatherService._apply(p, n, toolType, power, tier) and def.RequiredTool ~= "Hand" and slot then
				ctx.InventoryService.Wear(p, slot, ctx.PowerupService.ToolWear(p, toolType))
			end
		end,
	})
end

return GatherService
