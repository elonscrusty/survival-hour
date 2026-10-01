--!strict
-- "Welcome back" modal: when snapshot.offline.pending > 0 the silos earned cash while the player
-- was away. One button claims it (claimOffline). If the claim fails the modal comes back on a
-- later snapshot (after a short cooldown) so the cash is never lost to a dropped request.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameInfo"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Num = require(UI.Num)

local Offline = {}

function Offline.Start(store: any, host: any)
	local showing = false
	local nextTry = 0

	store.OnChanged(function(snap: any)
		if showing or snap.offline.pending <= 0 or os.clock() < nextTry then
			return
		end
		local pending = snap.offline.pending
		local opened = host:Notice("offline", {
			title = "Welcome back!",
			icon = "silo",
			color = Theme.Color.GreenDark,
			text = string.format(
				"Your silos kept %s busy for %s while you were away.\n\nYou earned %s!",
				GameInfo.Name,
				Num.Duration(snap.offline.seconds),
				Num.Cash(pending)
			),
			confirmText = "Collect " .. Num.Cash(pending),
			confirmColor = Theme.Color.Green,
		}, function()
			task.spawn(function()
				local res = store.Request({ type = "claimOffline" })
				showing = false
				if res.ok then
					host:Sound("coin")
				else
					nextTry = os.clock() + 5
					if res.code ~= "not_ready" and res.code ~= "busy" then
						host:Toast(res.message or "Couldn't collect. We'll try again.", "bad")
					end
				end
			end)
		end)
		showing = opened
		if not opened then
			nextTry = os.clock() + 2 -- another modal is up; ask again shortly
		end
	end)
end

return Offline
