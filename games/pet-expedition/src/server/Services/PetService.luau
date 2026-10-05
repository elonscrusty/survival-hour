--!nonstrict
-- Pet management remotes (equip, equip best, unequip all, delete, lock,
-- craft) and pet XP / levels. Pets offered in an open trade can't be deleted,
-- crafted or sent away until the trade ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = Shared:WaitForChild("Logic")
local Inventory = require(Logic:WaitForChild("Inventory"))
local PetMath = require(Logic:WaitForChild("PetMath"))
local Profile = require(Logic:WaitForChild("Profile"))
local Rewards = require(Logic:WaitForChild("Rewards"))
local Schema = require(Logic:WaitForChild("Schema"))

local PetService = {}

local ctx: any
local MAX_DELETE = 500

function PetService.Init(c)
	ctx = c
	local U = ctx.Util

	U.Function("EquipPet", function(player, s, uid, equip)
		if not U.IsStr(uid, Schema.MaxUidLength) or not U.IsBool(equip) then
			return U.Fail("Bad request")
		end
		local ok, err = Inventory.Equip(s.Profile, uid, equip)
		if not ok then
			return U.Fail(err or "Can't do that")
		end
		ctx.StateService.Dirty(player)
		return { ok = true }
	end)

	U.Function("EquipBest", function(player, s)
		Inventory.EquipBest(s.Profile)
		ctx.StateService.Dirty(player)
		return { ok = true }
	end)

	U.Function("UnequipAll", function(player, s)
		Inventory.UnequipAll(s.Profile)
		ctx.BreakableService.ClearTarget(player)
		ctx.StateService.Dirty(player)
		return { ok = true }
	end)

	U.Function("DeletePets", function(player, s, uids)
		local list, err = Schema.UidList(uids, MAX_DELETE)
		if not list then
			return U.Fail(err or "Bad pet list")
		end
		local coins, err2 = Inventory.Delete(s.Profile, list, ctx.TradeService.OfferedSet(player))
		if not coins then
			return U.Fail(err2 or "Can't delete those pets")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, coins = coins }
	end)

	U.Function("LockPet", function(player, s, uid, locked)
		if not U.IsStr(uid, Schema.MaxUidLength) or not U.IsBool(locked) then
			return U.Fail("Bad request")
		end
		local ok, err = Inventory.Lock(s.Profile, uid, locked)
		if not ok then
			return U.Fail(err or "Can't do that")
		end
		ctx.StateService.Dirty(player)
		return { ok = true }
	end)

	U.Function("CraftPet", function(player, s, uid)
		if not U.IsStr(uid, Schema.MaxUidLength) then
			return U.Fail("Bad request")
		end
		local made, err = Inventory.Craft(s.Profile, uid, ctx.TradeService.OfferedSet(player))
		if not made then
			return U.Fail(err or "Can't craft that")
		end
		Rewards.AddQuestProgress(s.Profile, "Craft", 1, os.time())
		ctx.Util.Toast(player, string.format("Made a %s pet!", made.Variant), "good")
		ctx.StateService.Dirty(player)
		return { ok = true, pet = Profile.CopyPet(made) }
	end)
end

-- Gives XP to every equipped pet of a player. Sends LevelUp notifications.
function PetService.GiveXp(player: Player, s, xp: number)
	for _, pet in Inventory.EquippedPets(s.Profile) do
		local gained = PetMath.AddXp(pet, xp)
		if gained > 0 then
			ctx.Util.Notify(player, "LevelUp", { Uid = pet.Uid, Level = pet.Level })
		end
	end
end

PetService.MaxLevel = Config.PetMaxLevel

return PetService
