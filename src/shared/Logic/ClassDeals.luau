--!strict
-- Class Hall rules: daily deals and rarity stars. Pure Luau so the server price
-- and the client display agree, and so it is tested without Roblox
-- (tests/ClassDeals.spec.luau).
--
-- Each UTC day (Progression.DayNumber) two purchasable classes are discounted:
-- one by 20%, one by 10%. The pick is seeded from the day number only, so every
-- server and client shows the same deals. The free default class never gets one.
-- Deals only lower a Diamond price; classes stay sidegrades bought with earned
-- Diamonds (never Robux).

local Classes = require("../Classes")
local Rng = require("./Rng")

local ClassDeals = {}

ClassDeals.Percents = { 20, 10 } -- first pick gets 20% off, second 10%

-- Classes that can be on deal: paid, not the default, in shop order.
local function eligible(list: { Classes.Def }): { Classes.Def }
	local out = {}
	for _, d in list do
		if d.Price > 0 and d.Id ~= Classes.Default then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b)
		return a.Order < b.Order
	end)
	return out
end

-- Deals for a day: { [classId] = percent off }. `list` defaults to Classes.List.
function ClassDeals.Deals(day: number, list: { Classes.Def }?): { [string]: number }
	local pool = eligible(list or Classes.List)
	local deals: { [string]: number } = {}
	if #pool == 0 then
		return deals
	end
	local rng = Rng.new(math.floor(day) * 7919 + 104729)
	rng:Next() -- the first draws after a small seed are correlated; skip a couple
	rng:Next()
	for _, pct in ClassDeals.Percents do
		if #pool == 0 then
			break
		end
		local i = rng:Int(1, #pool)
		deals[pool[i].Id] = pct
		table.remove(pool, i)
	end
	return deals
end

-- Percent off for one class today (0 when it has no deal).
function ClassDeals.Percent(id: string, day: number): number
	return ClassDeals.Deals(day)[id] or 0
end

-- The Diamond price the server charges today (rounded to the nearest Diamond).
function ClassDeals.Price(def: Classes.Def, day: number): number
	local pct = ClassDeals.Percent(def.Id, day)
	if pct <= 0 or def.Price <= 0 then
		return def.Price
	end
	return math.max(1, math.floor(def.Price * (100 - pct) / 100 + 0.5))
end

-- Seconds until the deals change (next UTC midnight).
function ClassDeals.SecondsLeft(now: number): number
	return 86400 - math.floor(now) % 86400
end

-- "5h 12m" / "12m" for the Class Hall timer.
function ClassDeals.LeftText(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h, m = s // 3600, (s % 3600) // 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", math.max(1, m))
end

-- Rarity stars shown on class cards, from the full (undiscounted) price.
function ClassDeals.Stars(price: number): number
	if price <= 0 then
		return 1
	elseif price <= 75 then
		return 2
	elseif price <= 150 then
		return 3
	end
	return 4
end

return ClassDeals
