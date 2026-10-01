--!strict
-- Boost potions. The reference REPORTS boosts such as 3x Earnings for 20 min, 10x Internal
-- Hatchery for 10 min, 10x Earnings, 50x Earnings for 2 h, "2x All Active Boosts", and a limit of
-- 5 active boosts with VIP. Which boosts exist here and their sizes are DESIGN VALUES.
-- Rules (design, tested in Boosts.spec): boosts run on server real time (they keep counting while
-- offline); using a boost that is already active adds its duration (capped); different boosts
-- multiply; "Boost Booster" doubles the bonus part of every other active boost.

export type Boost = {
	id: string,
	name: string,
	desc: string,
	icon: string,
	stat: string, -- "earn" | "lay" | "hatch" | "booster"
	mult: number,
	duration: number, -- seconds
}

local list: { Boost } = {
	{ id = "earn3", name = "Cash x3", desc = "Triple cash from sales for 20 min", icon = "cash", stat = "earn", mult = 3, duration = 20 * 60 },
	{ id = "earn10", name = "Cash x10", desc = "10x cash from sales for 10 min", icon = "cash", stat = "earn", mult = 10, duration = 10 * 60 },
	{ id = "lay2", name = "Laying x2", desc = "Chickens lay twice as fast for 15 min", icon = "feed", stat = "lay", mult = 2, duration = 15 * 60 },
	{ id = "hatch10", name = "Hatchery x10", desc = "Coop Hatchery 10x faster for 10 min", icon = "hatch", stat = "hatch", mult = 10, duration = 10 * 60 },
	{ id = "booster", name = "Boost Booster", desc = "Doubles every other active boost for 10 min", icon = "booster", stat = "booster", mult = 2, duration = 10 * 60 },
}

local byId: { [string]: Boost } = {}
for _, b in list do
	byId[b.id] = b
end

return {
	List = list,
	ById = byId,
	MaxActive = 3,
	MaxActiveVip = 5,
	MaxDuration = 6 * 3600, -- one boost can be stacked up to 6 hours
	MaxInventory = 999,
}
