--!nonstrict
-- Rebirth: resets coins and gates for a permanent coin bonus and gems
-- (Logic/Economy.Rebirth). Players standing on a now-locked island are sent
-- back to the Meadow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = Shared:WaitForChild("Logic")
local Economy = require(Logic:WaitForChild("Economy"))
local Schema = require(Logic:WaitForChild("Schema"))

local RebirthService = {}

local ctx: any

function RebirthService.Init(c)
	ctx = c
	ctx.Util.Function("Rebirth", function(player, s)
		local ok, err = Economy.Rebirth(s.Profile)
		if not ok then
			return ctx.Util.Fail(err or "Can't rebirth yet")
		end
		ctx.BreakableService.ClearTarget(player)
		local area = ctx.WorldService.AreaOf(player)
		if area and area ~= Schema.StartArea then
			ctx.WorldService.TeleportTo(player, Schema.StartArea)
		end
		ctx.Util.Toast(player, string.format("Rebirth %d! +%d gems and a permanent coin bonus.", s.Profile.Rebirths, Config.RebirthGems), "good")
		ctx.StateService.Dirty(player)
		task.spawn(ctx.DataService.SaveNow, player)
		return { ok = true, rebirths = s.Profile.Rebirths }
	end)
end

return RebirthService
