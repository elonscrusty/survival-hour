--!nonstrict
-- Crafting (equipment, ammo, rope) and shared workbench upgrades.
-- Structure recipes are "paid on placement" by BuildService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Items = require(Shared:WaitForChild("Items"))
local Recipes = require(Shared:WaitForChild("Recipes"))
local Logic = Shared:WaitForChild("Logic")
local InventoryModel = require(Logic:WaitForChild("InventoryModel"))
local StorageLedger = require(Logic:WaitForChild("StorageLedger"))

local CraftService = {}

local ctx: any
local WORKBENCH_RANGE = 14

function CraftService.Init(c)
	ctx = c
	ctx.Util.Connect("Craft", "Craft", CraftService._onCraft)
	ctx.Util.Connect("UpgradeWorkbench", "Craft", CraftService._onUpgrade)
	ctx.MatchService.On("MatchStarting", function()
		for t = 1, Config.Match.TeamCount do
			ctx.MatchService.State:SetAttribute("Bench" .. t, 1)
		end
	end)
end

local function nearWorkbench(p: Player): boolean
	local camp = ctx.CampService.GetCamp(ctx.Util.Team(p))
	return camp ~= nil and ctx.Util.DistTo(p, camp.WorkbenchCF.Position) <= WORKBENCH_RANGE
end

function CraftService.OpenFor(p: Player)
	CraftService.Push(p, true)
end

-- Sends craft UI data: level, and team storage totals (for combined-cost display).
function CraftService.Push(p: Player, open: boolean?)
	local team = ctx.Util.Team(p)
	local totals = ctx.StorageService.TeamTotals(team)
	Net.FireClient("CraftSync", p, {
		Level = ctx.CampService.GetLevel(team),
		Storage = totals,
		Open = open == true,
		NearBench = nearWorkbench(p),
	})
end

-- Crafting takes a short, interruptible channel (longer for higher tiers; the
-- Craftsman power-up shortens it). Everything is re-validated on completion.
function CraftService._onCraft(p: Player, recipeId: any)
	if type(recipeId) ~= "string" or not p:GetAttribute("InMatch") or not ctx.Util.IsAlive(p) then
		return
	end
	local recipe = Recipes.ById[recipeId]
	if not recipe or recipe.Kind == "Structure" then
		return
	end
	local inv = ctx.InventoryService.Get(p)
	if not inv or not InventoryModel.HasResources(inv, recipe.Cost) then
		ctx.Util.Notify(p, "Not enough materials in your pack.", "error")
		return
	end
	if recipe.Level > 0 and ctx.CampService.GetLevel(ctx.Util.Team(p)) < recipe.Level then
		ctx.Util.Notify(p, "Requires Workbench Tier " .. ({ "I", "II", "III", "IV", "V" })[recipe.Level] .. ".", "error")
		return
	end
	if recipe.Level > 0 and not nearWorkbench(p) then
		ctx.Util.Notify(p, "Stand at your workbench to craft that.", "error")
		return
	end
	local root = ctx.Util.Root(p)
	if not root then
		return
	end
	local start = root.Position
	local def = Items[recipe.Result]
	ctx.ChannelService.Begin(p, {
		Kind = "Craft",
		Label = "Crafting " .. (if def then def.Name else recipe.Result),
		Duration = (Config.Craft.BaseTime + Config.Craft.PerTier * recipe.Level) / ctx.PowerupService.CraftSpeedMult(p),
		Range = 8,
		MoveTolerance = 4,
		InterruptOnDamage = true,
		Action = "Craft",
		Position = function()
			return start
		end,
		OnComplete = function()
			CraftService._craftNow(p, recipeId)
		end,
	})
end

function CraftService._craftNow(p: Player, recipeId: string)
	if not p:GetAttribute("InMatch") or not ctx.Util.IsAlive(p) then
		return
	end
	local recipe = Recipes.ById[recipeId]
	if not recipe or recipe.Kind == "Structure" then
		return
	end
	local team = ctx.Util.Team(p)
	local inv = ctx.InventoryService.Get(p)
	if not inv then
		return
	end
	if recipe.Level > 0 then
		if ctx.CampService.GetLevel(team) < recipe.Level then
			ctx.Util.Notify(p, "Requires Workbench Tier " .. ({ "I", "II", "III", "IV", "V" })[recipe.Level] .. ".", "error")
			return
		end
		if not nearWorkbench(p) then
			ctx.Util.Notify(p, "Stand at your workbench to craft that.", "error")
			return
		end
	end
	if not InventoryModel.HasResources(inv, recipe.Cost) then
		ctx.Util.Notify(p, "Not enough materials in your pack.", "error")
		return
	end
	local def = Items[recipe.Result]
	-- Space checks before paying
	if recipe.Kind == "Consumable" then
		if inv.Bandages >= inv.BandageMax then
			ctx.Util.Notify(p, "Your bandage pouch is full.", "warn")
			return
		end
	elseif recipe.Kind == "Ammo" then
		if (inv.Ammo[recipe.Result] or 0) >= (inv.AmmoMax[recipe.Result] or 0) then
			ctx.Util.Notify(p, "Your ammo pouch is full.", "warn")
			return
		end
	end
	if not InventoryModel.RemoveResources(inv, recipe.Cost) then
		return
	end
	if recipe.Kind == "Resource" then
		local added = InventoryModel.AddResource(inv, recipe.Result, recipe.Count)
		local root = ctx.Util.Root(p)
		if added < recipe.Count and root then
			ctx.InventoryService.SpawnPickup(recipe.Result, recipe.Count - added, root.Position + root.CFrame.LookVector * 3)
		end
		ctx.InventoryService.Sync(p)
	elseif recipe.Kind == "Consumable" then
		InventoryModel.AddBandages(inv, recipe.Count)
		ctx.InventoryService.Sync(p)
	elseif recipe.Kind == "Ammo" then
		InventoryModel.AddAmmo(inv, recipe.Result, recipe.Count)
		ctx.InventoryService.Sync(p)
	else
		local root = ctx.Util.Root(p)
		local taken, displaced = ctx.InventoryService.Give(p, recipe.Result, 1, nil, nil)
		if taken <= 0 then
			-- Should not happen (armor/slots always accept), but never lose materials.
			for id, n in recipe.Cost do
				inv.Resources[id] += n
			end
			ctx.InventoryService.Sync(p)
			return
		end
		if displaced and root then
			ctx.InventoryService.SpawnPickup(displaced.Id, 1, root.Position + root.CFrame.LookVector * 3, displaced)
			ctx.Util.Notify(p, "Dropped your old " .. Items[displaced.Id].Name .. " to make room.", "info")
		end
	end
	ctx.Util.PlaySound("Craft", ctx.Util.Root(p))
	local cr = ctx.Util.Root(p)
	if cr then
		Net.FireAll("Fx", "Crafted", { Pos = cr.Position })
	end
	ctx.PowerupService.Tally(p, "Crafts", 1)
	ctx.Util.Notify(p, "Crafted " .. (if recipe.Count > 1 then recipe.Count .. " " else "") .. def.Name, "success")
	CraftService.Push(p)
end

function CraftService._onUpgrade(p: Player)
	if not p:GetAttribute("InMatch") or not ctx.Util.IsAlive(p) then
		return
	end
	local team = ctx.Util.Team(p)
	local level = ctx.CampService.GetLevel(team)
	if level >= Recipes.MaxWorkbenchLevel then
		ctx.Util.Notify(p, "Your workbench is already at max level.", "info")
		return
	end
	if not nearWorkbench(p) then
		ctx.Util.Notify(p, "Stand at your workbench to upgrade it.", "error")
		return
	end
	local cost = Recipes.WorkbenchUpgrades[level + 1]
	local inv = ctx.InventoryService.Get(p)
	local stores = ctx.StorageService.TeamStores(team)
	if not inv or not StorageLedger.PayCombined(cost, inv, stores) then
		ctx.Util.Notify(p, "Not enough materials (your pack + team storage).", "error")
		return
	end
	ctx.CampService.SetLevel(team, level + 1)
	ctx.PowerupService.OnWorkbenchLevel(p, team, level + 1)
	ctx.Util.SetAction(p, "Craft")
	for _, mate in ctx.Util.TeamPlayers(team) do
		Net.FireClient("MatchEvent", mate, "Upgraded", { What = "Workbench", Level = level + 1 })
	end
	Net.FireAll("Fx", "BenchUpgrade", { Pos = ctx.CampService.GetCamp(team).WorkbenchCF.Position, Level = level + 1 })
	ctx.InventoryService.Sync(p)
	ctx.StorageService.SyncTeam(team)
	ctx.Util.NotifyTeam(team, p.DisplayName .. " upgraded the workbench to level " .. (level + 1) .. "! New recipes unlocked.", "success")
	ctx.Util.PlaySound("Build", ctx.CampService.GetCamp(team).Workbench.PrimaryPart)
	for _, mate in ctx.Util.TeamPlayers(team) do
		CraftService.Push(mate)
	end
end

return CraftService
