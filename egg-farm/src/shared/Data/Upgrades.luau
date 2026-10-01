--!strict
-- Upgrades ("research"). COMMON upgrades cost Cash and reset on rebirth; EPIC upgrades cost
-- Gold Eggs and are kept forever. Both groups and the reset rule are REPORTED for the reference
-- (docs/REFERENCE_RESEARCH.md section 8); several roles are named after reported upgrades
-- (laying rate, egg value, house extension, internal hatchery, fleet size, auto clicker,
-- lab discount, silo capacity). NAMES, EFFECT SIZES, PRICES AND LEVEL CAPS ARE DESIGN VALUES.
--
-- price(level) = base * growth ^ level   (level = levels already owned; Common also x costScale)
-- `stat` is the modifier the upgrade feeds (see Logic/Modifiers.luau); `per` is the amount per level.

export type Upgrade = {
	id: string,
	name: string,
	desc: string,
	icon: string,
	stat: string,
	per: number,
	max: number,
	base: number,
	growth: number,
	unlockEgg: number,
}

local common: { Upgrade } = {
	{ id = "feed", name = "Premium Feed", desc = "+10% laying rate per level", icon = "feed", stat = "layPct", per = 0.10, max = 25, base = 60, growth = 1.45, unlockEgg = 1 },
	{ id = "polish", name = "Polished Shells", desc = "+25% egg value per level", icon = "shine", stat = "valuePct", per = 0.25, max = 25, base = 120, growth = 1.5, unlockEgg = 1 },
	{ id = "basket", name = "Bigger Basket", desc = "Carry twice as many eggs per level", icon = "basket", stat = "carryMul", per = 2, max = 12, base = 80, growth = 2.6, unlockEgg = 1 },
	{ id = "nestbox", name = "Roomy Nest Boxes", desc = "+50% egg storage in every house", icon = "nest", stat = "storagePct", per = 0.5, max = 15, base = 150, growth = 2.0, unlockEgg = 1 },
	{ id = "hatchery", name = "Coop Hatchery", desc = "Each house hatches +2 chickens/min", icon = "hatch", stat = "hatchPerHouse", per = 2 / 60, max = 20, base = 300, growth = 1.7, unlockEgg = 1 },
	{ id = "spawner", name = "Bigger Clutch", desc = "+1 chicken per Spawn tap", icon = "chick", stat = "spawnPerTap", per = 1, max = 9, base = 500, growth = 3.2, unlockEgg = 1 },
	{ id = "extension", name = "House Extension", desc = "+5% housing capacity per level", icon = "house", stat = "capacityPct", per = 0.05, max = 20, base = 2000, growth = 1.9, unlockEgg = 1 },
	{ id = "loading", name = "Quick Loading", desc = "-5% vehicle trip time per level", icon = "clock", stat = "tripPct", per = 0.05, max = 8, base = 1500, growth = 2.2, unlockEgg = 1 },
	{ id = "training", name = "Worker Training", desc = "+25% worker carry per level", icon = "worker", stat = "workerPct", per = 0.25, max = 12, base = 2500, growth = 2.1, unlockEgg = 1 },
	{ id = "fleet", name = "Fleet Permit", desc = "+1 vehicle slot", icon = "truck", stat = "vehicleSlots", per = 1, max = 4, base = 25000, growth = 12, unlockEgg = 1 },
	{ id = "bunkhouse", name = "Bunkhouse", desc = "+1 worker slot", icon = "bunk", stat = "workerSlots", per = 1, max = 4, base = 40000, growth = 10, unlockEgg = 2 },
	{ id = "shoes", name = "Running Boots", desc = "+6% walk speed per level", icon = "boot", stat = "speedPct", per = 0.06, max = 5, base = 1000, growth = 3, unlockEgg = 1 },
	{ id = "golden_yolk", name = "Golden Yolk", desc = "Double egg value", icon = "yolk", stat = "valueMul", per = 2, max = 1, base = 500000, growth = 1, unlockEgg = 2 },
	{ id = "super_nest", name = "Super Nest", desc = "+15% laying rate and egg value", icon = "star", stat = "layValuePct", per = 0.15, max = 10, base = 2e6, growth = 2.5, unlockEgg = 4 },
}

local epic: { Upgrade } = {
	{ id = "auto_clicker", name = "Auto Clicker", desc = "Auto Spawn +1 chicken/sec per level", icon = "auto", stat = "autoSpawnRate", per = 1, max = 20, base = 25, growth = 1.5, unlockEgg = 1 },
	{ id = "golden_touch", name = "Golden Touch", desc = "+10% egg value per level (kept forever)", icon = "shine", stat = "epicValuePct", per = 0.10, max = 50, base = 15, growth = 1.25, unlockEgg = 1 },
	{ id = "hen_whisperer", name = "Hen Whisperer", desc = "+10% laying rate per level (kept forever)", icon = "feed", stat = "epicLayPct", per = 0.10, max = 50, base = 15, growth = 1.25, unlockEgg = 1 },
	{ id = "hatch_overdrive", name = "Hatch Overdrive", desc = "+50% Coop Hatchery speed per level", icon = "hatch", stat = "hatchPct", per = 0.5, max = 10, base = 30, growth = 1.6, unlockEgg = 1 },
	{ id = "lab_discount", name = "Lab Discount", desc = "-4% Common upgrade prices per level", icon = "lab", stat = "commonDiscount", per = 0.04, max = 10, base = 40, growth = 1.7, unlockEgg = 1 },
	{ id = "silo_capacity", name = "Silo Capacity", desc = "+15 min offline time per silo per level", icon = "silo", stat = "siloMinutes", per = 15, max = 8, base = 35, growth = 1.8, unlockEgg = 1 },
	{ id = "combo_master", name = "Combo Master", desc = "+1 max Cash Multiplier per level", icon = "combo", stat = "comboMax", per = 1, max = 10, base = 50, growth = 1.6, unlockEgg = 1 },
	{ id = "pack_mule", name = "Pack Mule", desc = "+50% carry capacity per level", icon = "basket", stat = "epicCarryPct", per = 0.5, max = 10, base = 20, growth = 1.5, unlockEgg = 1 },
}

local byId: { [string]: Upgrade } = {}
for _, u in common do
	byId[u.id] = u
end
for _, u in epic do
	byId[u.id] = u
end

return {
	Common = common,
	Epic = epic,
	ById = byId,
}
