--!nonstrict
-- Daily streak, playtime gifts (per server session), daily quests and Index
-- rewards. All checks live in Logic/Rewards; this file wires the remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pets = require(Shared:WaitForChild("Pets"))
local Logic = Shared:WaitForChild("Logic")
local Rewards = require(Logic:WaitForChild("Rewards"))

local RewardService = {}

local ctx: any

function RewardService.Init(c)
	ctx = c
	local U = ctx.Util

	U.Function("ClaimDaily", function(player, s)
		local reward, streak, err = Rewards.ClaimDaily(s.Profile, os.time())
		if not reward then
			return U.Fail(err or "Not ready")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, reward = reward, streak = streak }
	end)

	U.Function("ClaimPlaytime", function(player, s, index)
		if not U.IsInt(index, 1, #Config.PlaytimeGifts) then
			return U.Fail("Unknown gift")
		end
		local reward, err = Rewards.ClaimPlaytime(s.Profile, RewardService.SessionMinutes(s), s.PlaytimeClaimed, index, os.time())
		if not reward then
			return U.Fail(err or "Not ready")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, reward = reward }
	end)

	U.Function("ClaimQuest", function(player, s, index)
		if not U.IsInt(index, 1, Config.QuestsPerDay) then
			return U.Fail("Unknown quest")
		end
		local reward, err = Rewards.ClaimQuest(s.Profile, index, os.time())
		if not reward then
			return U.Fail(err or "Not ready")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, reward = reward }
	end)

	U.Function("ClaimIndex", function(player, s, tier)
		if not U.IsInt(tier, 1, #Config.IndexRewards) then
			return U.Fail("Unknown reward")
		end
		local reward, err = Rewards.ClaimIndex(s.Profile, tier, os.time())
		if not reward then
			return U.Fail(err or "Not ready")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, reward = reward }
	end)
end

function RewardService.SessionMinutes(s): number
	return (os.clock() - s.JoinClock) / 60
end

-- Tells the player a species just entered their Index.
function RewardService.Discovered(player: Player, petId: string)
	if Pets.ById[petId] then
		ctx.Util.Notify(player, "Discovered", { PetId = petId })
	end
end

return RewardService
