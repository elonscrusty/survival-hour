--!strict
-- Economy rules built from the evidence catalog. Pure: no Roblox APIs, so the CLI tests run it.
-- Anything marked placeholder in the catalog stays a placeholder here; see docs/CATALOG.md.
local BigNum = require("./BigNum")
local Catalog = require("../Catalog")
type Big = BigNum.Big

export type PadDef = {
	id: string,
	name: string,
	bizId: string,
	kind: string, -- "unlock" | "cash" | "speed" | "auto" | "structure" | "minigame"
	cost: number,
	mult: number?,
	requires: string?, -- pad id
	order: number,
	model: string?,
	status: string,
}

export type BizDef = {
	id: string,
	name: string,
	product: string,
	index: number,
	unlockPad: string,
	baseOutput: number,
	cycleTime: number,
	pads: { PadDef }, -- upgrade pads, excludes the unlock pad
}

local Economy = {}

Economy.Catalog = Catalog
Economy.businesses = {} :: { BizDef }
Economy.bizById = {} :: { [string]: BizDef }
Economy.pads = {} :: { PadDef } -- every pad in plot order (unlock pads included)
Economy.padById = {} :: { [string]: PadDef }

local generic = Catalog.generic_business
local prestige = Catalog.prestige

do
	local order = 0
	local prevUnlock: string? = nil
	for i, b in Catalog.businesses do
		local unlockId = "biz:" .. b.id
		order += 1
		local unlockPad: PadDef = {
			id = unlockId,
			name = b.name,
			bizId = b.id,
			kind = "unlock",
			cost = b.unlock.value,
			requires = prevUnlock,
			order = order,
			model = nil,
			status = b.unlock.status,
		}
		table.insert(Economy.pads, unlockPad)
		Economy.padById[unlockId] = unlockPad
		prevUnlock = unlockId

		local def: BizDef = {
			id = b.id,
			name = b.name,
			product = b.product,
			index = i,
			unlockPad = unlockId,
			baseOutput = if b.baseOutput then b.baseOutput.value else b.unlock.value * generic.outputPerUnlockCost.value,
			cycleTime = if b.cycleTime then b.cycleTime.value else generic.cycleTime.value,
			pads = {},
		}
		for _, p in b.pads do
			order += 1
			local pad: PadDef = {
				id = b.id .. ":" .. p.id,
				name = p.name,
				bizId = b.id,
				kind = p.kind,
				cost = p.cost,
				mult = p.mult,
				requires = if p.requires then b.id .. ":" .. p.requires else unlockId,
				order = order,
				model = p.model,
				status = p.status,
			}
			table.insert(def.pads, pad)
			table.insert(Economy.pads, pad)
			Economy.padById[pad.id] = pad
		end
		table.insert(Economy.businesses, def)
		Economy.bizById[b.id] = def
	end
end

-- Stand-shaped output curve (level 1 = 1.0). Observed/derived for levels 1-4, placeholder after.
local shapeCache: { number } = {}
for _, o in Catalog.stand_level_shape.observed do
	shapeCache[o.level] = o.output
end
local INC_GROWTH = Catalog.stand_level_shape.extrapolate.incrementGrowth

function Economy.levelShape(level: number): number
	if level <= 0 then
		return 0
	end
	local cached = shapeCache[level]
	if cached then
		return cached
	end
	-- closed form of increments growing by INC_GROWTH beyond the last observed level
	local n = #shapeCache
	local lastInc = shapeCache[n] - shapeCache[n - 1]
	local k = level - n
	local sum = lastInc * INC_GROWTH * (INC_GROWTH ^ k - 1) / (INC_GROWTH - 1)
	return shapeCache[n] + sum
end

-- Base output per cycle at a level (before multipliers).
function Economy.baseOutput(biz: BizDef, level: number): number
	return biz.baseOutput * Economy.levelShape(level)
end

local standCosts: { number } = {}
for _, o in Catalog.level_costs_stand.observed do
	standCosts[o.index + 1] = o.cost
end
local COST_GROWTH = Catalog.level_costs_stand.extrapolate.growth

-- Cost of the next level when `bought` level upgrades are already owned (bought = level - 1).
-- Returned as a log10 to stay safe for very deep levels; use levelCost for a Big.
local function levelCostLog(biz: BizDef, bought: number): number
	if biz.id == "stand" then
		local c = standCosts[bought + 1]
		if c then
			return math.log10(c)
		end
		local n = #standCosts
		return math.log10(standCosts[n]) + (bought + 1 - n) * math.log10(COST_GROWTH)
	end
	local first = biz.baseOutput / generic.outputPerUnlockCost.value * generic.firstLevelCostPerUnlockCost.value
	return math.log10(first) + bought * math.log10(COST_GROWTH)
end

local function fromLog(l: number): Big
	local e = math.floor(l)
	return BigNum.fromParts(10 ^ (l - e), e)
end

function Economy.priceMult(ascensions: number): Big
	return BigNum.powN(prestige.ascensionPriceMult.value, ascensions)
end

function Economy.levelCost(biz: BizDef, bought: number, ascensions: number): Big
	return BigNum.roundCents(BigNum.mul(fromLog(levelCostLog(biz, bought)), Economy.priceMult(ascensions)))
end

-- Total cost of the next `count` levels.
function Economy.levelCostRange(biz: BizDef, bought: number, count: number, ascensions: number): Big
	local total = BigNum.zero
	for i = 0, count - 1 do
		total = BigNum.add(total, Economy.levelCost(biz, bought + i, ascensions))
	end
	return total
end

function Economy.padCost(pad: PadDef, ascensions: number): Big
	return BigNum.roundCents(BigNum.mul(BigNum.new(pad.cost), Economy.priceMult(ascensions)))
end

export type MultState = {
	pads: { [string]: boolean },
	forever: { [string]: boolean },
	investors: Big,
	evolutions: number,
	ascensions: number,
	speedUp: boolean,
}

function Economy.ownsPad(s: MultState, padId: string): boolean
	return s.pads[padId] == true or s.forever[padId] == true
end

function Economy.investorBonus(investors: Big): Big
	-- 1 + investors * bonusPerInvestor
	return BigNum.add(BigNum.new(1), BigNum.mulN(investors, prestige.cashBonusPerInvestor.value))
end

function Economy.cashMult(s: MultState, biz: BizDef): Big
	local m = 1
	for _, p in biz.pads do
		if p.kind == "cash" and Economy.ownsPad(s, p.id) then
			m *= p.mult or 1
		end
	end
	local big = BigNum.new(m)
	big = BigNum.mul(big, Economy.investorBonus(s.investors))
	big = BigNum.mul(big, BigNum.powN(prestige.ascensionCashMult.value, s.ascensions))
	return big
end

function Economy.speedMult(s: MultState, biz: BizDef): Big
	local m = 1
	for _, p in biz.pads do
		if p.kind == "speed" and Economy.ownsPad(s, p.id) then
			m *= p.mult or 1
		end
	end
	if s.speedUp then
		m *= 2
	end
	return BigNum.mul(BigNum.new(m), BigNum.powN(prestige.evolutionSpeedMult.value, s.evolutions))
end

function Economy.isAutomated(s: MultState, biz: BizDef): boolean
	for _, p in biz.pads do
		if p.kind == "auto" and Economy.ownsPad(s, p.id) then
			return true
		end
	end
	return false
end

-- Output of one completed cycle, rounded to cents while small.
function Economy.cycleOutput(s: MultState, biz: BizDef, level: number): Big
	return BigNum.roundCents(BigNum.mulN(Economy.cashMult(s, biz), Economy.baseOutput(biz, level)))
end

-- Cycles per second as a Big.
function Economy.cyclesPerSecond(s: MultState, biz: BizDef): Big
	return BigNum.mulN(Economy.speedMult(s, biz), 1 / biz.cycleTime)
end

-- Investors offered for a rebirth from lifetime cash this run (placeholder award rule).
function Economy.investorsOffered(lifetime: Big, doubled: boolean): Big
	local minCash = BigNum.new(prestige.rebirthMinCash.value)
	if BigNum.lt(lifetime, minCash) then
		return BigNum.zero
	end
	local n = BigNum.floor(BigNum.sqrt(BigNum.div(lifetime, minCash)))
	if doubled then
		n = BigNum.mulN(n, 2)
	end
	return n
end

function Economy.evolutionThreshold(evolutions: number): Big
	return BigNum.mul(BigNum.new(prestige.evolutionFirstInvestors.value), BigNum.powN(prestige.evolutionGrowth.value, evolutions))
end

function Economy.recipeName(evolutions: number): string
	local list = prestige.recipes.value
	local n = #list
	if evolutions < n then
		return list[evolutions + 1]
	end
	return list[n] .. "+" .. tostring(evolutions - n + 1)
end

return Economy
