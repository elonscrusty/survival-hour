--!nonstrict
-- Per-player match inventories, world pickups, supply bags, held-item visuals,
-- canteens and bandages. Inventories only exist while a player is in a match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Items = require(Shared:WaitForChild("Items"))
local Resources = require(Shared:WaitForChild("Resources"))
local Logic = Shared:WaitForChild("Logic")
local InventoryModel = require(Logic:WaitForChild("InventoryModel"))
local Models = Shared:WaitForChild("Models")
local ItemModels = require(Models:WaitForChild("ItemModels"))
local Build = require(Models:WaitForChild("Build"))

local InventoryService = {}

local ctx: any
local invs: { [Player]: InventoryModel.Inventory } = {}
local pickups: { [Model]: { Id: string, Count: number, Stack: any?, Expires: number } } = {}
local bags: { [Model]: { Items: { [string]: number }, Expires: number } } = {}
local pickupFolder: Folder? = nil

local function folder(): Folder
	if pickupFolder and pickupFolder.Parent then
		return pickupFolder
	end
	local match = workspace:FindFirstChild("Match")
	pickupFolder = ctx.Util.Folder("Pickups", match or workspace)
	return pickupFolder :: Folder
end

function InventoryService.Init(c)
	ctx = c
	ctx.MatchService.On("PlayerJoinedMatch", function(p: Player)
		local inv = InventoryModel.New(Config.Inventory.PackSlots, Config.Inventory.BandageMax, Config.Inventory.AmmoMax)
		inv.BonusSlots = ctx.PowerupService.BonusSlots(p)
		InventoryModel.SetPackSlots(inv, nil)
		invs[p] = inv
		InventoryService._deliverBandageCredits(p)
		InventoryService.Sync(p)
	end)
	ctx.MatchService.On("MatchCleanup", function()
		invs = {}
		pickups = {}
		bags = {}
		pickupFolder = nil
	end)
	ctx.Util.OnPlayerRemoving(function(p: Player)
		local inv = invs[p]
		if inv and ctx.MatchService.Active then
			local root = ctx.Util.Root(p)
			if root then
				InventoryService.DropOnDeath(p, root.Position)
			end
		end
		invs[p] = nil
	end)

	ctx.Util.Connect("Equip", "Default", InventoryService._onEquip)
	ctx.Util.Connect("SwapWeapons", "Default", function(p: Player)
		local inv = invs[p]
		if inv and InventoryModel.Swap(inv, "Weapon1", "Weapon2") then
			InventoryService.Sync(p)
		end
	end)
	ctx.Util.Connect("DropItem", "Interact", InventoryService._onDrop)
	ctx.Util.Connect("UseBandage", "Interact", InventoryService._onBandage)
	ctx.Util.Connect("Eat", "Interact", InventoryService._onEat)

	ctx.ChannelService.OnPrompt("Pickup", InventoryService._onPickupPrompt)
	ctx.ChannelService.OnPrompt("Bag", InventoryService._onBagPrompt)
	ctx.ChannelService.OnPrompt("Fill", InventoryService._onFillPrompt)
	ctx.MatchService.On("MatchStarting", function(map)
		for _, w in map.WaterPoints do
			local pr = ctx.ChannelService.MakePrompt(w.Part, "Fill", "Fill Canteen", "Stream", Config.Canteen.FillRange)
			pr:SetAttribute("NeedsCanteen", true)
		end
	end)

	ctx.PurchaseService.OnGranted("Bandage", function(p: Player)
		if invs[p] then
			InventoryService._deliverBandageCredits(p)
		else
			ctx.Util.Notify(p, "Bandage purchased! It's stored and will be delivered in your next match.", "success")
		end
	end)
end

function InventoryService.Start()
	-- Despawn sweep
	while true do
		task.wait(5)
		local t = os.clock()
		for m, data in pickups do
			if t > data.Expires then
				pickups[m] = nil
				m:Destroy()
			end
		end
		for m, data in bags do
			if t > data.Expires then
				bags[m] = nil
				m:Destroy()
			end
		end
	end
end

function InventoryService.Get(p: Player): InventoryModel.Inventory?
	return invs[p]
end

function InventoryService.Sync(p: Player)
	local inv = invs[p]
	if not inv then
		return
	end
	Net.FireClient("InventorySync", p, InventoryModel.Snapshot(inv))
	p:SetAttribute("Carry", InventoryModel.ResourceTotal(inv))
	InventoryService._refreshHeld(p)
end

-- Credits bought with Robux (or deferred) become bandages up to the pouch cap.
function InventoryService._deliverBandageCredits(p: Player)
	local inv = invs[p]
	local session = ctx.DataService.Get(p)
	if not inv or not session then
		return
	end
	local credits = session.Profile.Credits.Bandage
	if credits <= 0 then
		return
	end
	local added = InventoryModel.AddBandages(inv, credits)
	if added > 0 then
		session.Profile.Credits.Bandage -= added
		task.spawn(ctx.DataService.Save, p, false)
		ctx.DataService.Push(p)
		ctx.Util.Notify(p, string.format("+%d bandage%s delivered%s.", added, if added > 1 then "s" else "", if session.Profile.Credits.Bandage > 0 then " (the rest are stored for later)" else ""), "success")
		InventoryService.Sync(p)
	elseif credits > 0 then
		ctx.Util.Notify(p, "Bandage pouch full — your bandage is stored and will be delivered when there's room.", "info")
	end
end

-- Resources -------------------------------------------------------------------------------

function InventoryService.AddResource(p: Player, id: string, n: number): number
	local inv = invs[p]
	if not inv then
		return 0
	end
	local added = InventoryModel.AddResource(inv, id, n)
	if added < n then
		Net.FireClient("Notify", p, "Your pack is full (" .. inv.Capacity .. " slots). Deposit at your storage or craft a bigger backpack.", "warn")
	end
	if added > 0 then
		InventoryService.Sync(p)
	end
	return added
end

-- Adds any item (resource/equipment/ammo/bandage). Returns amount taken and
-- any displaced equipment stack (caller drops it).
function InventoryService.Give(p: Player, id: string, count: number, stack: any?, preferSlot: string?): (number, any?)
	local inv = invs[p]
	local def = Items[id]
	if not inv or not def then
		return 0, nil
	end
	local taken, displaced = 0, nil
	if def.Kind == "Resource" then
		taken = InventoryModel.AddResource(inv, id, count)
	elseif def.Kind == "Ammo" then
		taken = InventoryModel.AddAmmo(inv, id, count)
	elseif def.Kind == "Consumable" then
		taken = InventoryModel.AddBandages(inv, count)
	elseif def.Kind == "Backpack" then
		local old
		_, old = InventoryModel.AddEquipment(inv, "Backpack", stack or { Id = id })
		displaced = old
		taken = 1
		InventoryModel.SetPackSlots(inv, def.Slots)
		local overflow = InventoryModel.TrimToCapacity(inv)
		if next(overflow) then
			local root = ctx.Util.Root(p)
			if root then
				InventoryService.SpawnBag(overflow, root.Position + root.CFrame.LookVector * 3, Color3.fromRGB(150, 120, 80), "Overflow")
			end
		end
	elseif def.Kind == "Weapon" or def.Kind == "Tool" or def.Kind == "Utility" or def.Kind == "Armor" then
		local st = stack or { Id = id, Durability = def.Durability }
		if st.Id == "Canteen" and st.Filled == nil then
			st.Filled = false
		end
		local slot
		slot, displaced = InventoryModel.AddEquipment(inv, def.Kind, st, if def.Kind == "Armor" then def.ArmorSlot else preferSlot or inv.Equipped)
		if slot then
			taken = 1
			if def.Kind ~= "Armor" and inv.Equipped == nil then
				inv.Equipped = slot
			end
		end
	end
	if taken > 0 then
		InventoryService.Sync(p)
	end
	return taken, displaced
end

-- Pickups -----------------------------------------------------------------------------------

function InventoryService.SpawnPickup(id: string, count: number, pos: Vector3, stack: any?, lifetime: number?): Model?
	local def = Items[id]
	if not def or count <= 0 then
		return nil
	end
	local ground = ctx.WorldService.RaycastGround(pos, { folder() })
	local at = if ground then ground else pos
	local m = ItemModels.Pickup(id, count, CFrame.new(at) * CFrame.Angles(0, math.random() * 6.28, 0), folder())
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local label = if count > 1 then string.format("%s x%d", def.Name, count) else def.Name
	local pr = ctx.ChannelService.MakePrompt(m.PrimaryPart, "Pickup", "Pick up", label, Config.Inventory.PickupRange)
	pr.KeyboardKeyCode = Enum.KeyCode.F
	pr:SetAttribute("ItemId", id)
	pickups[m] = { Id = id, Count = count, Stack = stack, Expires = os.clock() + (lifetime or Config.Inventory.DropDespawn) }
	return m
end

function InventoryService._onPickupPrompt(p: Player, prompt: ProximityPrompt)
	local m = prompt:FindFirstAncestorOfClass("Model")
	local data = m and pickups[m]
	if not m or not data or not invs[p] or not ctx.Util.IsAlive(p) then
		return
	end
	if ctx.Util.DistTo(p, m:GetPivot().Position) > Config.Inventory.PickupRange + 2 then
		return
	end
	local inv = invs[p] :: InventoryModel.Inventory
	local taken, displaced = InventoryService.Give(p, data.Id, data.Count, data.Stack, inv.Equipped)
	if taken <= 0 then
		ctx.Util.Notify(p, "No room for that.", "warn")
		return
	end
	ctx.Util.PlaySound("Pickup", m.PrimaryPart)
	local pos = m:GetPivot().Position
	data.Count -= taken
	if data.Count <= 0 then
		pickups[m] = nil
		m:Destroy()
	else
		local def = Items[data.Id]
		prompt.ObjectText = string.format("%s x%d", def.Name, data.Count)
	end
	if displaced then
		InventoryService.SpawnPickup(displaced.Id, 1, pos + Vector3.new(0, 0.5, 0), displaced)
		ctx.Util.Notify(p, "Swapped: dropped " .. Items[displaced.Id].Name, "info")
	end
	ctx.PowerupService.OnPickup(p, data.Id)
end

-- Supply bags (death / leave drops) ---------------------------------------------------------

function InventoryService.DropOnDeath(p: Player, pos: Vector3)
	local inv = invs[p]
	if not inv then
		return
	end
	local dropped = InventoryModel.TakeAllResources(inv)
	if next(dropped) == nil then
		InventoryService.Sync(p)
		return
	end
	local team = ctx.Util.Team(p)
	local color = if Config.Teams[team] then Config.Teams[team].Color else Color3.new(1, 1, 1)
	InventoryService.SpawnBag(dropped, pos, color, p.DisplayName .. "'s Supplies", { p.Character :: Instance })
	InventoryService.Sync(p)
end

function InventoryService.SpawnBag(contents: { [string]: number }, pos: Vector3, color: Color3, label: string, ignore: { Instance }?): Model
	local ig = ignore or {}
	table.insert(ig, folder())
	local ground = ctx.WorldService.RaycastGround(pos, ig)
	local m = ItemModels.SupplyBag(CFrame.new(ground or pos), color, folder())
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local pr = ctx.ChannelService.MakePrompt(m.PrimaryPart, "Bag", "Loot", label, Config.Inventory.PickupRange)
	pr.KeyboardKeyCode = Enum.KeyCode.F
	bags[m] = { Items = contents, Expires = os.clock() + Config.Inventory.SupplyBagDespawn }
	return m
end

function InventoryService._onBagPrompt(p: Player, prompt: ProximityPrompt)
	local m = prompt:FindFirstAncestorOfClass("Model")
	local data = m and bags[m]
	local inv = invs[p]
	if not m or not data or not inv or not ctx.Util.IsAlive(p) then
		return
	end
	if ctx.Util.DistTo(p, m:GetPivot().Position) > Config.Inventory.PickupRange + 2 then
		return
	end
	local got = 0
	for id, n in data.Items do
		local add = InventoryModel.AddResource(inv, id, n)
		data.Items[id] = n - add
		got += add
		if data.Items[id] <= 0 then
			data.Items[id] = nil
		end
	end
	if got == 0 then
		ctx.Util.Notify(p, "Your pack is full.", "warn")
		return
	end
	ctx.Util.PlaySound("Pickup", m.PrimaryPart)
	if next(data.Items) == nil then
		bags[m] = nil
		m:Destroy()
	end
	InventoryService.Sync(p)
end

-- Equip / drop / swap ------------------------------------------------------------------------

function InventoryService._onEquip(p: Player, slot: any)
	local inv = invs[p]
	if not inv then
		return
	end
	if slot ~= nil and not (type(slot) == "string" and table.find(InventoryModel.SlotNames, slot)) then
		return
	end
	if slot ~= nil and inv.Slots[slot] == nil then
		return
	end
	if ctx.ChannelService.IsBusy(p, "Pour") then
		return -- keep the canteen in hand while pouring
	end
	InventoryModel.Equip(inv, slot)
	InventoryService.Sync(p)
end

function InventoryService.EquipUtility(p: Player)
	local inv = invs[p]
	if inv and inv.Slots.Utility then
		InventoryModel.Equip(inv, "Utility")
		InventoryService.Sync(p)
	end
end

function InventoryService._onDrop(p: Player, req: any)
	local inv = invs[p]
	if not inv or type(req) ~= "table" or not ctx.Util.IsAlive(p) then
		return
	end
	local root = ctx.Util.Root(p)
	if not root then
		return
	end
	local dropPos = root.Position + root.CFrame.LookVector * 3
	if type(req.Slot) == "string" and (table.find(InventoryModel.SlotNames, req.Slot) or InventoryModel.ArmorPiece(req.Slot) or req.Slot == "Backpack") then
		if ctx.ChannelService.IsBusy(p) then
			return
		end
		local st = InventoryModel.RemoveSlot(inv, req.Slot)
		if st then
			InventoryService.SpawnPickup(st.Id, 1, dropPos, st)
			if req.Slot == "Backpack" then
				InventoryModel.SetPackSlots(inv, nil)
				local overflow = InventoryModel.TrimToCapacity(inv)
				if next(overflow) then
					InventoryService.SpawnBag(overflow, dropPos + Vector3.new(0, 0, 2), Color3.fromRGB(150, 120, 80), "Overflow")
				end
			end
			InventoryService.Sync(p)
		end
	elseif type(req.Resource) == "string" and ctx.Util.IsInt(req.Count, 1, 100) then
		local n = InventoryModel.TakeResource(inv, req.Resource, req.Count)
		if n > 0 then
			InventoryService.SpawnPickup(req.Resource, n, dropPos)
			InventoryService.Sync(p)
		end
	end
end

-- Canteen ------------------------------------------------------------------------------------

function InventoryService.HasCanteen(p: Player): boolean
	local inv = invs[p]
	return inv ~= nil and inv.Slots.Utility ~= nil and (inv.Slots.Utility :: any).Id == "Canteen"
end

function InventoryService.HasFilledCanteen(p: Player): boolean
	local inv = invs[p]
	local st = inv and inv.Slots.Utility
	return st ~= nil and st.Id == "Canteen" and st.Filled == true
end

function InventoryService.UseCanteen(p: Player): boolean
	local inv = invs[p]
	local st = inv and inv.Slots.Utility
	if st and st.Id == "Canteen" and st.Filled then
		st.Filled = false
		InventoryService.Sync(p)
		return true
	end
	return false
end

function InventoryService._onFillPrompt(p: Player, prompt: ProximityPrompt)
	if not ctx.Util.IsAlive(p) then
		return
	end
	if not InventoryService.HasCanteen(p) then
		ctx.Util.Notify(p, "You need a canteen (craft at Workbench Tier II).", "error")
		return
	end
	if InventoryService.HasFilledCanteen(p) then
		ctx.Util.Notify(p, "Your canteen is already full.", "info")
		return
	end
	local part = prompt.Parent :: BasePart
	ctx.ChannelService.Begin(p, {
		Kind = "Fill",
		Label = "Filling canteen",
		Duration = Config.Canteen.FillTime,
		Range = Config.Canteen.FillRange,
		InterruptOnDamage = false,
		Action = "Fill",
		Position = function()
			return if part.Parent then part.Position else nil
		end,
		OnComplete = function()
			local inv = invs[p]
			local st = inv and inv.Slots.Utility
			if st and st.Id == "Canteen" then
				st.Filled = true
				InventoryService.Sync(p)
				ctx.Util.PlaySound("Fill", part)
				ctx.Util.Notify(p, "Canteen filled. Pour it on an enemy fire at night!", "success")
			end
		end,
	})
end

-- Bandages -------------------------------------------------------------------------------------

function InventoryService._onBandage(p: Player)
	InventoryService.Heal(p, "Bandage")
end

-- Timed, interruptible healing (spec: Bandage ~20, First Aid ~50, Medkit ~100).
-- Bandages come from the pouch; First Aid kits and Medkits from the pack.
function InventoryService.Heal(p: Player, itemId: string)
	local inv = invs[p]
	local spec = Config.Healing[itemId]
	if not inv or not spec or not ctx.Util.IsAlive(p) then
		return
	end
	local function have(): boolean
		local cur = invs[p]
		if not cur then
			return false
		end
		return if itemId == "Bandage" then cur.Bandages > 0 else (cur.Resources[itemId] or 0) > 0
	end
	if not have() then
		ctx.Util.Notify(p, "You don't have a " .. Items[itemId].Name .. ".", "info")
		return
	end
	local hum = ctx.Util.Humanoid(p)
	if not hum or hum.Health >= hum.MaxHealth then
		ctx.Util.Notify(p, "You're already at full health.", "info")
		return
	end
	local root = ctx.Util.Root(p)
	if not root then
		return
	end
	local start = root.Position
	ctx.ChannelService.Begin(p, {
		Kind = "Heal",
		Label = "Applying " .. Items[itemId].Name:lower(),
		Duration = spec.UseTime / ctx.PowerupService.HealSpeedMult(p),
		Range = 30, -- you can walk slowly while healing
		InterruptOnDamage = true,
		Action = "Bandage",
		Position = function()
			return start
		end,
		OnComplete = function()
			local h = ctx.Util.Humanoid(p)
			local cur = invs[p]
			if not cur or not have() or not h or h.Health <= 0 then
				return
			end
			if itemId == "Bandage" then
				cur.Bandages -= 1
			else
				InventoryModel.TakeResource(cur, itemId, 1)
			end
			h.Health = math.min(h.MaxHealth, h.Health + spec.Heal)
			InventoryService.Sync(p)
			local hr = ctx.Util.Root(p)
			if hr then
				Net.FireAll("Fx", "Healed", { Pos = hr.Position, Amount = spec.Heal })
			end
			ctx.Util.PlaySound("Heal", ctx.Util.Root(p))
		end,
	})
end

-- Food ------------------------------------------------------------------------------------------

local lastEat: { [Player]: number } = {}

-- Eats one food resource (berries/mushroom) from the pack. `id` nil = best food carried.
function InventoryService._onEat(p: Player, id: any)
	local inv = invs[p]
	if not inv or not ctx.Util.IsAlive(p) then
		return
	end
	if id == nil then
		local best, heal = nil, 0
		for fid, f in Resources.Food do
			if (inv.Resources[fid] or 0) > 0 and f.Heal > heal then
				best, heal = fid, f.Heal
			end
		end
		id = best
		if not id then
			ctx.Util.Notify(p, "You have no food. Pick berries or mushrooms.", "info")
			return
		end
	end
	if type(id) == "string" and Config.Healing[id] and id ~= "Bandage" then
		InventoryService.Heal(p, id)
		return
	end
	local food = type(id) == "string" and Resources.Food[id]
	if not food or (inv.Resources[id] or 0) <= 0 then
		return
	end
	local t = os.clock()
	if t - (lastEat[p] or 0) < food.Cooldown then
		return
	end
	local hum = ctx.Util.Humanoid(p)
	if not hum or hum.Health >= hum.MaxHealth then
		ctx.Util.Notify(p, "You're already at full health.", "info")
		return
	end
	lastEat[p] = t
	InventoryModel.TakeResource(inv, id, 1)
	hum.Health = math.min(hum.MaxHealth, hum.Health + food.Heal)
	InventoryService.Sync(p)
	ctx.Util.PlaySound("Eat", ctx.Util.Root(p))
	ctx.Util.SetAction(p, "Eat")
	ctx.Util.Notify(p, string.format("Ate %s  +%d HP", Items[id].Name, food.Heal), "gain")
end

-- Durability -------------------------------------------------------------------------------------

function InventoryService.Wear(p: Player, slot: string, amount: number)
	local inv = invs[p]
	if not inv then
		return
	end
	local piece = InventoryModel.ArmorPiece(slot)
	local st = if piece then inv.Armor[piece] else inv.Slots[slot]
	local name = st and Items[st.Id] and Items[st.Id].Name
	if InventoryModel.Wear(inv, slot, amount) then
		ctx.Util.Notify(p, (name or "Item") .. " broke!", "warn")
		ctx.Util.PlaySound("Break", ctx.Util.Root(p))
		local br = ctx.Util.Root(p)
		if br then
			Net.FireAll("Fx", "ToolBroke", { Pos = br.Position + Vector3.new(0, 1.5, 0) })
		end
		Net.FireClient("MatchEvent", p, "ToolBroke", { Name = name or "Item" })
	end
	InventoryService.Sync(p)
end

function InventoryService.EquippedItem(p: Player): (string, string?)
	local inv = invs[p]
	if not inv or not inv.Equipped then
		return "Fists", nil
	end
	local st = inv.Slots[inv.Equipped]
	if not st then
		return "Fists", nil
	end
	return st.Id, inv.Equipped
end

-- Held visuals ---------------------------------------------------------------------------------

function InventoryService._refreshHeld(p: Player)
	local char = p.Character
	if not char then
		return
	end
	local id = InventoryService.EquippedItem(p)
	local inv = invs[p]
	if char:GetAttribute("HeldId") ~= id then
		local old = char:FindFirstChild("HeldItem")
		if old then
			old:Destroy()
		end
		char:SetAttribute("HeldId", id)
		local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
		if id ~= "Fists" and hand and hand:IsA("BasePart") then
			local model = ItemModels.Held(id)
			if model then
				model.Name = "HeldItem"
				local handle = model.PrimaryPart :: BasePart
				handle.CFrame = hand.CFrame * ItemModels.GripFor(id)
				local weld = Instance.new("Weld")
				weld.Part0 = hand
				weld.Part1 = handle
				weld.C0 = ItemModels.GripFor(id)
				weld.Parent = handle
				model.Parent = char
				ctx.CosmeticService.DressHeld(p, model)
			end
		end
	end
	-- Canteen fill state for visuals
	local util = inv and inv.Slots.Utility
	char:SetAttribute("CanteenFilled", util ~= nil and util.Id == "Canteen" and util.Filled == true)
	-- Worn armour: one shell per piece, coloured by tier (Hide → Tactical).
	local ARMOR_BONES = { Head = { "Head" }, Chest = { "UpperTorso", "Torso" }, Legs = { "LeftUpperLeg", "RightUpperLeg" } }
	for piece, bones in ARMOR_BONES do
		local st = inv and inv.Armor[piece]
		local wantId = if st then st.Id else nil
		for _, old in char:GetChildren() do
			if old:GetAttribute("ArmorPiece") == piece and old:GetAttribute("ArmorId") ~= wantId then
				old:Destroy()
			end
		end
		local def = wantId and Items[wantId]
		if def then
			for _, boneName in bones do
				local bone = char:FindFirstChild(boneName)
				if bone and bone:IsA("BasePart") and not bone:FindFirstChild("ArmorShell") then
					local mat = if (def.Tier or 1) >= 3 then Enum.Material.Metal else Enum.Material.Fabric
					local size = bone.Size + (if piece == "Head" then Vector3.new(0.25, -0.2, 0.25) else Vector3.new(0.3, 0.1, 0.3))
					local shell = Build.Part({ Name = "ArmorShell", Size = size, CFrame = bone.CFrame * CFrame.new(0, if piece == "Head" then 0.25 else 0, 0), Color = def.Icon.Color, Material = mat, Anchored = false, CanCollide = false, CanQuery = false, Massless = true, Parent = bone })
					shell:SetAttribute("ArmorPiece", piece)
					shell:SetAttribute("ArmorId", wantId)
					local w = Instance.new("WeldConstraint")
					w.Part0 = bone
					w.Part1 = shell
					w.Parent = shell
				end
			end
		end
		-- remove stale shells parented under bones
		for _, boneName in bones do
			local bone = char:FindFirstChild(boneName)
			local shell = bone and bone:FindFirstChild("ArmorShell")
			if shell and shell:GetAttribute("ArmorId") ~= wantId then
				shell:Destroy()
			end
		end
	end
	-- Worn backpack: a pack on the back, tinted by the BackpackSkin cosmetic.
	local packId = inv and inv.Backpack and inv.Backpack.Id
	local tint = p:GetAttribute("PackSkin") :: Color3?
	local want = if packId then packId .. (if tint then tint:ToHex() else "") else nil
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local pack = torso and torso:FindFirstChild("PackShell")
	if pack and pack:GetAttribute("Key") ~= want then
		pack:Destroy()
		pack = nil
	end
	if want and not pack and torso and torso:IsA("BasePart") then
		local slots = (Items[packId :: string] and Items[packId :: string].Slots) or 10
		local k = math.clamp(slots / 25, 0.6, 1.4)
		local shell = Build.Part({ Name = "PackShell", Size = Vector3.new(1.4 * k, 1.6 * k, 0.7 * k), CFrame = torso.CFrame * CFrame.new(0, 0.1, torso.Size.Z / 2 + 0.35 * k), Color = tint or (Items[packId :: string] and Items[packId :: string].Icon.Color) or Color3.fromRGB(120, 90, 60), Material = Enum.Material.Fabric, Anchored = false, CanCollide = false, CanQuery = false, Massless = true, Parent = torso })
		shell:SetAttribute("Key", want)
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso
		w.Part1 = shell
		w.Parent = shell
	end
end

function InventoryService.OnSpawn(p: Player)
	local char = p.Character
	if char then
		char:SetAttribute("HeldId", nil)
	end
	if invs[p] then
		InventoryService.Sync(p)
	end
end

return InventoryService
