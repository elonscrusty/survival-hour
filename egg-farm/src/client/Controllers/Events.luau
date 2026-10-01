--!strict
-- Turns FarmEvents (ARCHITECTURE.md "Remotes") into feedback: toasts, money popups, sounds and
-- the big Rebirth / Prestige banner. Popups honour settings.effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared:WaitForChild("Data"):WaitForChild("Eggs"))
local Boosts = require(Shared:WaitForChild("Data"):WaitForChild("Boosts"))
local Housing = require(Shared:WaitForChild("Data"):WaitForChild("Housing"))
local Vehicles = require(Shared:WaitForChild("Data"):WaitForChild("Vehicles"))
local Workers = require(Shared:WaitForChild("Data"):WaitForChild("Workers"))
local Upgrades = require(Shared:WaitForChild("Data"):WaitForChild("Upgrades"))
local GameInfo = require(Shared:WaitForChild("GameInfo"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Num = require(UI.Num)
local Toasts = require(script.Parent.Toasts)
local Sound = require(script.Parent.Sound)
local Common = require(script.Parent.Parent.Menus.Common)

local Events = {}

local CASH_AT = UDim2.new(0.5, 0, 0, 96)
local BASKET_AT = UDim2.new(0.5, -80, 0, 120)

function Events.Start(store: any)
	local function effects(): boolean
		local snap = store.Get()
		return snap == nil or snap.settings.effects ~= false
	end

	local handlers: { [string]: (any) -> () } = {}

	handlers.Collected = function(d)
		Sound.Play("collect")
		if effects() and (d.amount or 0) > 0 then
			Toasts.Popup("+" .. Num.Short(d.amount), Color3.fromRGB(255, 244, 220), BASKET_AT, "egg")
		end
		if d.full then
			Toasts.Show("Basket full! Take the eggs to the warehouse.", "warn")
		end
	end
	handlers.Deposited = function(d)
		Sound.Play("deposit")
		if effects() and (d.amount or 0) > 0 then
			Toasts.Popup("+" .. Num.Short(d.amount) .. " stored", Theme.Color.Good, BASKET_AT, "basket")
		end
	end
	handlers.Sold = function(d)
		Sound.Play("coin")
		if effects() and (d.cash or 0) > 0 then
			Toasts.Popup("+" .. Num.Cash(d.cash), Theme.Color.Cash, CASH_AT, "cash")
		end
	end
	handlers.Purchased = function(d)
		Sound.Play("buy")
		local text: string? = nil
		if d.kind == "house" then
			local t = Housing.Tiers[d.tier or 1]
			text = string.format("House %d: %s!", d.slot or 0, t and t.name or "upgraded")
		elseif d.kind == "vehicle" then
			local t = Vehicles.Tiers[d.tier or 1]
			text = string.format("Vehicle %d: %s!", d.slot or 0, t and t.name or "upgraded")
		elseif d.kind == "worker" then
			local t = Workers.Tiers[d.tier or 1]
			text = string.format("Worker %d: %s!", d.slot or 0, t and t.name or "hired")
		elseif d.kind == "silo" then
			text = string.format("Silo built! (%d)", d.count or 0)
		elseif (d.kind == "common" or d.kind == "epic") and d.id then
			local u = Upgrades.ById[d.id]
			text = string.format("%s: level %d", u and u.name or d.id, d.level or 0)
		end
		if text then
			Toasts.Show(text, "good")
		end
	end
	handlers.Rebirth = function(d)
		Sound.Play("rebirth")
		local egg = Eggs.List[d.to or 1]
		local sub = "Welcome to the " .. (egg and egg.name or "next egg") .. "!"
		if (d.gold or 0) > 0 then
			sub ..= "  +" .. Num.Short(d.gold) .. " " .. GameInfo.Currency.Gold
		end
		Toasts.Banner(if d.skipped then "SKIPPED!" else "REBIRTH!", sub, Theme.Color.Purple, "rebirth")
	end
	handlers.Prestige = function(d)
		Sound.Play("rebirth")
		Toasts.Banner("PRESTIGE!", string.format("+%d %s (total %d)", d.stars or 0, GameInfo.Currency.Star, d.total or 0), Theme.Color.PurpleDark, "prestige")
	end
	handlers.BoostUsed = function(d)
		local b = Boosts.ById[d.id]
		Toasts.Show((b and b.name or "Boost") .. " is running!", "good")
	end
	handlers.BoostEnded = function(d)
		local b = Boosts.ById[d.id]
		Toasts.Show((b and b.name or "A boost") .. " ended.", "info")
	end
	handlers.Reward = function(d)
		Sound.Play("claim")
		local text = Common.RewardText(d.granted)
		if text ~= "-" then
			Toasts.Show("You got " .. text .. "!", "gold")
		end
	end
	handlers.Fox = function(d)
		Sound.Play("coin")
		Toasts.Banner("LUCKY FOX!", "+" .. Num.Cash(d.cash or 0), Theme.Color.Orange, "cash")
	end
	handlers.HousingFull = function()
		Toasts.Show("Housing is full! Upgrade your houses.", "warn")
	end
	handlers.BasketFull = function()
		Toasts.Show("Your basket is full! Deposit at the warehouse.", "warn")
	end
	handlers.StorageFull = function()
		Toasts.Show("A house is full of eggs! Collect them.", "warn")
	end
	handlers.Toast = function(d)
		if type(d.text) == "string" then
			Toasts.Show(d.text, d.kind)
		end
	end

	store.OnEvent("*", function(name: string, data: any)
		local fn = handlers[name]
		if fn then
			fn(if type(data) == "table" then data else {})
		end
	end)
end

return Events
