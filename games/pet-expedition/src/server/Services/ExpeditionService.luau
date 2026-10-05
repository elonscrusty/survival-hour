--!nonstrict
-- Expedition remotes. Timers use os.time(), so expeditions finish while the
-- player is offline; the reward seed is fixed at start (Logic/Expedition).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Areas = require(Shared:WaitForChild("Areas"))
local Logic = Shared:WaitForChild("Logic")
local Expedition = require(Logic:WaitForChild("Expedition"))
local Profile = require(Logic:WaitForChild("Profile"))
local Rewards = require(Logic:WaitForChild("Rewards"))
local Schema = require(Logic:WaitForChild("Schema"))

local ExpeditionService = {}

local ctx: any
local random = Random.new()
local MAX_SLOT = Config.BaseExpeditionSlots + 2

function ExpeditionService.Init(c)
	ctx = c
	local U = ctx.Util

	U.Function("StartExpedition", function(player, s, areaId, durationKey, uids)
		if not U.IsStr(areaId, 32) or not Areas.ById[areaId] then
			return U.Fail("Unknown island")
		end
		if not U.IsStr(durationKey, 16) or not Expedition.Duration(durationKey) then
			return U.Fail("Unknown duration")
		end
		local list, err = Schema.UidList(uids, Config.MaxPetsPerExpedition)
		if not list then
			return U.Fail(err or "Bad pet list")
		end
		local seed = random:NextInteger(1, 2147483646)
		local slot, _, err2 = Expedition.Start(s.Profile, areaId, durationKey, list, os.time(), seed, ctx.TradeService.OfferedSet(player))
		if not slot then
			return U.Fail(err2 or "Can't start that expedition")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, slot = tonumber(slot) }
	end)

	U.Function("ClaimExpedition", function(player, s, slot)
		if not U.IsInt(slot, 1, MAX_SLOT) then
			return U.Fail("Unknown slot")
		end
		local p = s.Profile
		local claimed, err = Expedition.Claim(p, tostring(slot), os.time(), ctx.StateService.CoinMult(s))
		if not claimed then
			return U.Fail(err or "Can't claim that")
		end
		local now = os.time()
		Rewards.AddQuestProgress(p, "Expedition", 1, now)
		Rewards.AddQuestProgress(p, "Coins", claimed.Coins, now)
		for _, id in claimed.Discovered do
			ctx.RewardService.Discovered(player, id)
		end
		local pets = {}
		for _, pet in claimed.Pets do
			table.insert(pets, Profile.CopyPet(pet))
		end
		ctx.StateService.Dirty(player)
		return {
			ok = true,
			reward = {
				Coins = if claimed.Coins > 0 then claimed.Coins else nil,
				Gems = if claimed.Gems > 0 then claimed.Gems else nil,
				Pets = pets,
			},
		}
	end)

	U.Function("SkipExpedition", function(player, s, slot)
		if not U.IsInt(slot, 1, MAX_SLOT) then
			return U.Fail("Unknown slot")
		end
		local cost, err = Expedition.Skip(s.Profile, tostring(slot), os.time())
		if not cost then
			return U.Fail(err or "Can't skip that")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, gems = cost }
	end)
end

return ExpeditionService
