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

function CraftService._onCraft(p: Player, recipeId: any)
	if type(recipeId) ~= "string" or not p:GetAttribute("InMatch") or not ctx.Util.IsAlive(p) then
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
			ctx.Util.Notify(p, "Requires workbench level " .. recipe.Level .. ".", "error")
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
	if recipe.Kind == "Resource" then
		-- rope: paying 3 plants frees 3 slots, result takes 1: always fits
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
		InventoryModel.AddResource(inv, recipe.Result, recipe.Count)
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
	ctx.InventoryService.Sync(p)
	ctx.StorageService.SyncTeam(team)
	ctx.Util.NotifyTeam(team, p.DisplayName .. " upgraded the workbench to level " .. (level + 1) .. "! New recipes unlocked.", "success")
	ctx.Util.PlaySound("Build", ctx.CampService.GetCamp(team).Workbench.PrimaryPart)
	for _, mate in ctx.Util.TeamPlayers(team) do
		CraftService.Push(mate)
	end
end

return CraftService
