--!strict
-- Helpers shared by the menus: reward text, the friendly reset/kept lists for new farms,
-- price quotes from a snapshot (the snapshot carries the same fields Logic/Prices reads), and
-- small layout builders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Data = Shared:WaitForChild("Data")
local Prices = require(Logic:WaitForChild("Prices"))
local State = require(Logic:WaitForChild("State"))
local Boosts = require(Data:WaitForChild("Boosts"))
local RewardData = require(Data:WaitForChild("Rewards"))
local Eggs = require(Data:WaitForChild("Eggs"))
local GameInfo = require(Shared:WaitForChild("GameInfo"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Num = require(UI.Num)

local Common = {}

-- Prices.* need a Mods-like table; the snapshot already carries the numbers they use.
function Common.Mods(snap: any): any
	return {
		vehicleSlots = snap.vehicleSlots,
		workerSlots = snap.workerSlots,
		commonPriceMult = snap.mods and snap.mods.commonPriceMult or 1,
	}
end

function Common.Quote(kind: string, snap: any, arg: any): (number?, string?)
	if kind == "buyHouse" then
		return Prices.BuyHouse(snap, arg)
	elseif kind == "upgradeHouse" then
		return Prices.UpgradeHouse(snap, arg)
	elseif kind == "buyVehicle" then
		return Prices.BuyVehicle(snap, arg, Common.Mods(snap))
	elseif kind == "upgradeVehicle" then
		return Prices.UpgradeVehicle(snap, arg)
	elseif kind == "hireWorker" then
		return Prices.HireWorker(snap, arg, Common.Mods(snap))
	elseif kind == "upgradeWorker" then
		return Prices.UpgradeWorker(snap, arg)
	elseif kind == "silo" then
		return Prices.Silo(snap)
	elseif kind == "upgrade" then
		local p, code = Prices.Upgrade(snap, arg, Common.Mods(snap))
		return p, code
	end
	return nil, "invalid"
end

-- "5 Gold Eggs", "10 min of earnings", "1x Cash x3"
function Common.RewardLines(reward: any): { string }
	local out = {}
	if not reward then
		return out
	end
	if reward.gold and reward.gold > 0 then
		table.insert(out, Num.Short(reward.gold) .. " " .. GameInfo.Currency.Gold)
	end
	if reward.cashMinutes and reward.cashMinutes > 0 then
		table.insert(out, reward.cashMinutes .. " min of farm cash")
	end
	if reward.cash and reward.cash > 0 then
		table.insert(out, Num.Cash(reward.cash))
	end
	if reward.boosts then
		local ids = {}
		for id in reward.boosts do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local b = Boosts.ById[id]
			table.insert(out, reward.boosts[id] .. "x " .. (if b then b.name else id))
		end
	end
	return out
end

function Common.RewardText(reward: any): string
	local lines = Common.RewardLines(reward)
	return if #lines > 0 then table.concat(lines, " + ") else "-"
end

function Common.RewardIcon(reward: any): string
	if reward and reward.gold then
		return "gold"
	elseif reward and (reward.cashMinutes or reward.cash) then
		return "cash"
	end
	return "booster"
end

-- Friendly names for State.RESET_FIELDS / KEPT_FIELDS. Internal bookkeeping fields map to nil
-- and are left out of the confirmation list.
local FRIENDLY: { [string]: string } = {
	cash = "Your Cash",
	population = "Your chickens",
	invested = "Farm Value (starts again from zero)",
	housing = "Houses (back to one Little Coop)",
	carried = "Eggs in your basket",
	warehouse = "Eggs in the warehouse",
	vehicles = "Vehicles (back to one Farm Pickup)",
	workers = "Workers",
	silos = "Silos you built (Permanent Silos stay)",
	common = "Common upgrades",
	gold = GameInfo.Currency.Gold,
	stars = GameInfo.Currency.Star,
	epic = "Epic upgrades",
	boosts = "Boosts (stored and active)",
	quests = "Today's quest progress",
	daily = "Daily reward streak",
	gifts = "Playtime gifts",
	codes = "Redeemed codes",
	settings = "Settings",
	passes = "Game passes",
	offline = "Unclaimed offline earnings",
	stats = "Lifetime stats",
	rebirths = "Rebirth count",
	prestiges = "Prestige count",
}

function Common.ResetLines(prestige: boolean): { string }
	local out = {}
	for _, f in State.RESET_FIELDS do
		local name = FRIENDLY[f]
		if name then
			table.insert(out, name)
		end
	end
	if prestige then
		table.insert(out, "Your egg goes back to the " .. Eggs.List[1].name)
	end
	return out
end

function Common.KeptLines(prestige: boolean): { string }
	local out = {}
	for _, f in State.KEPT_FIELDS do
		local name = FRIENDLY[f]
		if name then
			table.insert(out, name)
		end
	end
	if not prestige then
		table.insert(out, "Every egg you've unlocked")
	end
	return out
end

-- A small section heading inside a scroll list.
function Common.Heading(parent: Instance, text: string, order: number, color: Color3?): TextLabel
	return Util.Text({
		text = text,
		size = UDim2.new(1, -8, 0, 34),
		textSize = Theme.Text.L,
		color = color or Theme.Color.TextDark,
		font = Theme.Font.Title,
		xAlign = Enum.TextXAlignment.Left,
		order = order,
		parent = parent,
	})
end

-- Empty-state line.
function Common.Note(parent: Instance, text: string, order: number): TextLabel
	return Util.Text({
		text = text,
		size = UDim2.new(1, -8, 0, 0),
		textSize = Theme.Text.S,
		color = Theme.Color.TextMuted,
		wrap = true,
		order = order,
		parent = parent,
	})
end

-- Playtime today, advanced locally between snapshots (the server counts it while you play).
function Common.Playtime(snap: any, now: number): number
	return snap.gifts.playtime + math.max(0, now - snap.serverNow)
end

-- Playtime gifts that can be claimed right now.
function Common.GiftsReady(snap: any, now: number): number
	local play = Common.Playtime(snap, now)
	local n = 0
	for i, g in RewardData.Gifts do
		if not snap.gifts.claimed[tostring(i)] and play >= g.minutes * 60 then
			n += 1
		end
	end
	return n
end

function Common.Countdown(seconds: number): string
	return Num.Duration(math.max(0, seconds))
end

return Common
