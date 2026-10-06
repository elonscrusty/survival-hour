--!nonstrict
-- Egg hatching. The server checks the egg, the island, the player's distance
-- to the egg stand (when the map has one), cooldown, triple-hatch pass,
-- PolicyService (gem eggs), storage room and price, then rolls with the
-- player's current luck. Odds come only from shared Eggs data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Eggs = require(Shared:WaitForChild("Eggs"))
local Logic = Shared:WaitForChild("Logic")
local Economy = require(Logic:WaitForChild("Economy"))
local Hatch = require(Logic:WaitForChild("Hatch"))
local Inventory = require(Logic:WaitForChild("Inventory"))
local Profile = require(Logic:WaitForChild("Profile"))
local Rewards = require(Logic:WaitForChild("Rewards"))
local Schema = require(Logic:WaitForChild("Schema"))

local HatchService = {}

local ctx: any
local random = Random.new()

local MAX_STAND_DISTANCE = 45 -- studs from the egg stand

function HatchService.Init(c)
	ctx = c
	ctx.Util.Function("HatchEgg", HatchService._hatch)
end

function HatchService._hatch(player: Player, s, eggId: any, count: any)
	local U = ctx.Util
	if not U.IsStr(eggId, 32) then
		return U.Fail("Unknown egg")
	end
	local egg = Eggs.ById[eggId]
	if not egg then
		return U.Fail("Unknown egg")
	end
	if count == nil then
		count = 1
	end
	if count ~= 1 and count ~= 3 then
		return U.Fail("You can open 1 or 3 eggs")
	end
	local p = s.Profile
	if count == 3 and not Economy.HasPass(p, "TripleHatch") then
		return U.Fail("Triple Hatch needs the Triple Hatch pass")
	end
	local now = os.clock()
	if now - (s.LastHatch or 0) < Config.HatchCooldown then
		return U.Fail("Slow down a little")
	end
	if not p.Areas[egg.Area] then
		return U.Fail("Open that island first")
	end
	if egg.Currency == "Gems" and not s.CanBuyGemEggs then
		return U.Fail("This egg isn't available for your account")
	end
	local standPos = ctx.WorldService.TaggedPosition("EggStand", "EggId", egg.Id)
	if standPos and U.DistTo(player, standPos) > MAX_STAND_DISTANCE then
		return U.Fail("Walk up to the egg first")
	end
	if Inventory.FreeSpace(p) < count then
		return U.Fail("Your pet storage is full")
	end
	local cost = egg.Cost * count
	if not Economy.Spend(p, egg.Currency, cost) then
		return U.Fail(if egg.Currency == "Gems" then "Not enough gems" else "Not enough coins")
	end
	s.LastHatch = now

	local luck = ctx.StateService.LuckMult(s)
	local results = {}
	for _ = 1, count do
		local id = Hatch.Pick(egg, luck, random:NextNumber())
		local shiny = random:NextNumber() < Config.ShinyChance
		local pet, discovered = Inventory.Add(p, { Id = id, Shiny = shiny })
		if pet then
			table.insert(results, Profile.CopyPet(pet))
			if discovered then
				ctx.RewardService.Discovered(player, pet.Id)
			end
			-- New players' first pets go straight to work.
			if #p.Equipped < Economy.MaxEquip(p) then
				Inventory.Equip(p, pet.Uid, true)
			end
		end
	end
	p.Stats.Hatched = math.min(Schema.MaxStat, p.Stats.Hatched + #results)
	Rewards.AddQuestProgress(p, "Hatch", #results, os.time())
	ctx.StateService.Dirty(player)
	return { ok = true, pets = results }
end

return HatchService
