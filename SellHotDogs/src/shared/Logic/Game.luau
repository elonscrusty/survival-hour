--!strict
-- Every server-side rule a player action can trigger, as pure functions over a Profile.
-- Services call these after validating who is asking; the client never computes grants.
-- Each action returns (ok, code, data?) where code is a short reason shown as a toast.
local BigNum = require("./BigNum")
local Economy = require("./Economy")
local Profile = require("./Profile")
type Big = BigNum.Big
type Profile = Profile.Profile

local Game = {}

local Catalog = Economy.Catalog
local POWERS: { [string]: any } = {}
for _, pw in Catalog.powers do
	POWERS[pw.id] = pw
end
Game.POWERS = POWERS

-- Above this many cycles per second a business is treated as continuous (no per-cycle events).
Game.CONTINUOUS_CPS = 1e6
-- Upper bound of levels bought by one Max request (keeps a request's work bounded).
Game.MAX_BULK = 1000

function Game.multState(p: Profile): Economy.MultState
	return {
		pads = p.pads,
		forever = p.forever,
		investors = p.investors,
		evolutions = p.evolutions,
		ascensions = p.ascensions,
		speedUp = p.robux.passes.speedUp == true,
	}
end

function Game.owns(p: Profile, padId: string): boolean
	return p.pads[padId] == true or p.forever[padId] == true
end

function Game.bizOwned(p: Profile, bizId: string): boolean
	return Game.owns(p, "biz:" .. bizId)
end

function Game.powerTier(p: Profile, id: string): number
	local def = POWERS[id]
	if not def then
		return 0
	end
	return math.min(def.tiers, (p.powers[id] or 0) + (p.robux.tiers[id] or 0))
end

-- Bulk sizes the Stack Upgrade tier allows ("max" only at the top tier; placeholder gate).
function Game.bulkOptions(p: Profile): { any }
	local opts: { any } = { 1 }
	local tier = Game.powerTier(p, "stack")
	for i = 1, tier do
		table.insert(opts, POWERS.stack.bulk[i])
	end
	if tier >= POWERS.stack.tiers then
		table.insert(opts, "max")
	end
	return opts
end

local function earn(p: Profile, amount: Big)
	if amount.m <= 0 then
		return
	end
	p.cash = BigNum.roundCents(BigNum.add(p.cash, amount))
	p.lifetime = BigNum.add(p.lifetime, amount)
	p.totalEarned = BigNum.add(p.totalEarned, amount)
end
Game.earn = earn

local function spend(p: Profile, cost: Big): boolean
	if BigNum.lt(p.cash, cost) then
		return false
	end
	p.cash = BigNum.roundCents(BigNum.sub(p.cash, cost))
	if p.cash.m < 0 then -- float dust
		p.cash = BigNum.zero
	end
	return true
end

-- Pad visibility: its prerequisite pad is owned (unlock pads chain business to business).
function Game.padVisible(p: Profile, pad: Economy.PadDef): boolean
	if pad.requires and not Game.owns(p, pad.requires) then
		return false
	end
	if pad.kind ~= "unlock" and not Game.bizOwned(p, pad.bizId) then
		return false
	end
	return true
end

function Game.padCost(p: Profile, pad: Economy.PadDef): Big
	return Economy.padCost(pad, p.ascensions)
end

function Game.buyPad(p: Profile, padId: string): (boolean, string)
	local pad = Economy.padById[padId]
	if not pad then
		return false, "Unknown purchase"
	end
	if Game.owns(p, padId) then
		return false, "Already owned"
	end
	if not Game.padVisible(p, pad) then
		return false, "Locked"
	end
	if not spend(p, Game.padCost(p, pad)) then
		return false, "Not enough cash"
	end
	p.pads[padId] = true
	if pad.kind == "unlock" then
		local st = p.biz[pad.bizId]
		st.level, st.progress, st.running = 1, 0, false
	end
	return true, "Bought " .. pad.name
end

-- Cheapest visible pad the player does not own (Remote Buy target / guidance arrow).
function Game.nextPad(p: Profile): Economy.PadDef?
	local best: Economy.PadDef? = nil
	local bestCost: Big? = nil
	for _, pad in Economy.pads do
		if not Game.owns(p, pad.id) and Game.padVisible(p, pad) then
			local c = Game.padCost(p, pad)
			if not bestCost or BigNum.lt(c, bestCost) then
				best, bestCost = pad, c
			end
		end
	end
	return best
end

function Game.levelCost(p: Profile, bizId: string, count: number): Big
	local biz = Economy.bizById[bizId]
	local st = p.biz[bizId]
	return Economy.levelCostRange(biz, st.level - 1, count, p.ascensions)
end

-- How many levels "max" would buy right now (bounded by MAX_BULK).
function Game.maxAffordable(p: Profile, bizId: string): (number, Big)
	local biz = Economy.bizById[bizId]
	local st = p.biz[bizId]
	local total = BigNum.zero
	local n = 0
	while n < Game.MAX_BULK do
		local c = Economy.levelCost(biz, st.level - 1 + n, p.ascensions)
		local nt = BigNum.add(total, c)
		if BigNum.lt(p.cash, nt) then
			break
		end
		total = nt
		n += 1
	end
	return n, total
end

-- Buy level upgrades. `count` must be one of bulkOptions; xN buys all N or nothing.
function Game.upgradeLevel(p: Profile, bizId: string, count: any): (boolean, string, number?)
	local biz = Economy.bizById[bizId]
	if not biz then
		return false, "Unknown business"
	end
	if not Game.bizOwned(p, bizId) then
		return false, "Locked"
	end
	local allowed = false
	for _, o in Game.bulkOptions(p) do
		if o == count then
			allowed = true
		end
	end
	if not allowed then
		return false, "Bulk size locked"
	end
	local st = p.biz[bizId]
	local n: number, cost: Big
	if count == "max" then
		n, cost = Game.maxAffordable(p, bizId)
		if n == 0 then
			return false, "Not enough cash"
		end
	else
		n = count
		cost = Game.levelCost(p, bizId, n)
	end
	if not spend(p, cost) then
		return false, "Not enough cash"
	end
	st.level += n
	return true, "Upgraded", n
end

-- Manual production: start one cycle (the CLICK control). Automated businesses run themselves.
function Game.click(p: Profile, bizId: string): (boolean, string)
	local biz = Economy.bizById[bizId]
	if not biz or not Game.bizOwned(p, bizId) then
		return false, "Locked"
	end
	local st = p.biz[bizId]
	if Economy.isAutomated(Game.multState(p), biz) then
		return false, "Already automatic"
	end
	if st.running then
		return false, "Busy"
	end
	st.running = true
	st.progress = 0
	p.stats.clicks = (p.stats.clicks or 0) + 1
	return true, "Started"
end

export type Grant = { bizId: string, amount: Big, cycles: number }

-- Advance production by dt seconds. Returns one aggregated grant per business that paid out.
function Game.step(p: Profile, dt: number): { Grant }
	local grants: { Grant } = {}
	if dt <= 0 then
		return grants
	end
	local ms = Game.multState(p)
	for _, biz in Economy.businesses do
		local st = p.biz[biz.id]
		if st.level < 1 or not Game.bizOwned(p, biz.id) then
			continue
		end
		local auto = Economy.isAutomated(ms, biz)
		if not auto and not st.running then
			continue
		end
		local cpsBig = Economy.cyclesPerSecond(ms, biz)
		local out = Economy.cycleOutput(ms, biz, st.level)
		if auto and BigNum.toNumber(cpsBig) > Game.CONTINUOUS_CPS then
			-- continuous: income rate x dt, no per-cycle accounting
			local amount = BigNum.mulN(BigNum.mul(out, cpsBig), dt)
			earn(p, amount)
			st.progress, st.running = 0, true
			table.insert(grants, { bizId = biz.id, amount = amount, cycles = -1 })
			continue
		end
		local cps = BigNum.toNumber(cpsBig)
		st.progress += dt * cps
		if auto then
			st.running = true
			local n = math.floor(st.progress)
			if n >= 1 then
				st.progress -= n
				local amount = BigNum.mulN(out, n)
				earn(p, amount)
				table.insert(grants, { bizId = biz.id, amount = amount, cycles = n })
			end
		elseif st.progress >= 1 then
			st.progress, st.running = 0, false
			earn(p, out)
			table.insert(grants, { bizId = biz.id, amount = out, cycles = 1 })
		end
	end
	return grants
end

-- Income per second of one business if it ran continuously.
function Game.bizRate(p: Profile, bizId: string): Big
	local biz = Economy.bizById[bizId]
	local st = p.biz[bizId]
	if st.level < 1 or not Game.bizOwned(p, bizId) then
		return BigNum.zero
	end
	local ms = Game.multState(p)
	return BigNum.mul(Economy.cycleOutput(ms, biz, st.level), Economy.cyclesPerSecond(ms, biz))
end

-- Total income per second. autoOnly = only automated businesses (offline income).
function Game.incomeRate(p: Profile, autoOnly: boolean): Big
	local ms = Game.multState(p)
	local total = BigNum.zero
	for _, biz in Economy.businesses do
		if not autoOnly or Economy.isAutomated(ms, biz) then
			total = BigNum.add(total, Game.bizRate(p, biz.id))
		end
	end
	return total
end

-- Offline earnings for `elapsed` seconds away. 100% of automated income, no cap (none evidenced).
function Game.offlineEarnings(p: Profile, elapsed: number): Big
	if elapsed <= 0 or elapsed ~= elapsed then
		return BigNum.zero
	end
	local rate = Catalog.offline.rate.value
	return BigNum.roundCents(BigNum.mulN(Game.incomeRate(p, true), elapsed * rate))
end

-- Called when a returning player's profile loads: bank offline income for the claim popup.
function Game.applyReturn(p: Profile, now: number): Big
	local elapsed = now - p.lastSeen
	local amount = Game.offlineEarnings(p, elapsed)
	p.pendingOffline = BigNum.add(p.pendingOffline, amount)
	p.lastSeen = now
	return amount
end

function Game.claimOffline(p: Profile): (boolean, string, Big?)
	local a = p.pendingOffline
	if a.m <= 0 then
		return false, "Nothing to collect"
	end
	p.pendingOffline = BigNum.zero
	earn(p, a)
	return true, "Collected", a
end

-- Ingredient crate / money bag pickup value (placeholder rule; see catalog pickups).
function Game.pickupValue(p: Profile): Big
	local secs = Catalog.pickups.valueSeconds.value
	local v = BigNum.mulN(Game.incomeRate(p, false), secs)
	local tier = Game.powerTier(p, "expertPicker")
	if tier > 0 then
		v = BigNum.mulN(v, POWERS.expertPicker.pickupMult[tier])
	end
	return BigNum.roundCents(BigNum.max(v, BigNum.new(1)))
end

-- mult: 2 for money bags (placeholder), 1 for crates.
function Game.collectPickup(p: Profile, mult: number?): Big
	local v = BigNum.mulN(Game.pickupValue(p), mult or 1)
	earn(p, v)
	p.stats.pickups = (p.stats.pickups or 0) + 1
	return v
end

-- Powers bought with investors (spent investors reduce the cash bonus).
function Game.powerCost(p: Profile, id: string): Big?
	local def = POWERS[id]
	if not def then
		return nil
	end
	local owned = p.powers[id] or 0
	if Game.powerTier(p, id) >= def.tiers or owned >= def.tiers then
		return nil
	end
	return BigNum.new(def.investorCost[owned + 1])
end

function Game.buyPower(p: Profile, id: string): (boolean, string)
	local cost = Game.powerCost(p, id)
	if not cost then
		return false, POWERS[id] and "Max level" or "Unknown power"
	end
	if BigNum.lt(p.investors, cost) then
		return false, "Not enough investors"
	end
	p.investors = BigNum.sub(p.investors, cost)
	p.powers[id] = (p.powers[id] or 0) + 1
	return true, POWERS[id].name .. " unlocked"
end

---------------------------------------------------------------------------
-- Prestige and resets
---------------------------------------------------------------------------

function Game.investorsOffered(p: Profile): Big
	return Economy.investorsOffered(p.lifetime, p.robux.passes.x2investors == true)
end

-- Wipe the run: cash, businesses, pads. Forever pads (and any business they need) survive.
local function resetRun(p: Profile)
	p.cash = BigNum.new(Catalog.start.cash.value)
	p.lifetime = BigNum.zero
	p.pads = {}
	p.biz = Profile.freshBiz()
	for padId in p.forever do
		local pad = Economy.padById[padId]
		if pad and pad.kind == "unlock" then
			p.biz[pad.bizId].level = 1
		end
	end
end
Game._resetRun = resetRun

function Game.rebirth(p: Profile): (boolean, string, Big?)
	local award = Game.investorsOffered(p)
	if BigNum.lt(award, BigNum.new(1)) then
		return false, "No investors yet"
	end
	resetRun(p)
	p.investors = BigNum.add(p.investors, award)
	p.stats.rebirths = (p.stats.rebirths or 0) + 1
	return true, "Rebirthed", award
end

-- Rebirth Without Reset (Robux credit): take the offered investors and keep everything.
function Game.rebirthNoReset(p: Profile): (boolean, string, Big?)
	if p.robux.rebirthCredits < 1 then
		return false, "No credits"
	end
	local award = Game.investorsOffered(p)
	if BigNum.lt(award, BigNum.new(1)) then
		return false, "No investors yet"
	end
	p.robux.rebirthCredits -= 1
	p.investors = BigNum.add(p.investors, award)
	p.lifetime = BigNum.zero -- the same run cannot be cashed in twice
	return true, "Investors joined", award
end

function Game.evolutionProgress(p: Profile): number
	local need = Economy.evolutionThreshold(p.evolutions)
	return math.clamp(BigNum.toNumber(BigNum.div(p.investors, need)), 0, 1)
end

function Game.evolve(p: Profile): (boolean, string)
	if BigNum.lt(p.investors, Economy.evolutionThreshold(p.evolutions)) then
		return false, "Not enough investors"
	end
	resetRun(p)
	p.investors = BigNum.zero
	p.powers = {} -- investor-bought powers reset; Robux tiers are kept
	p.evolutions += 1
	return true, "Evolved to " .. Economy.recipeName(p.evolutions)
end

function Game.canAscend(p: Profile): (boolean, number, number)
	local owned, total = 0, 0
	for _, pad in Economy.pads do
		total += 1
		if Game.owns(p, pad.id) then
			owned += 1
		end
	end
	return owned == total, owned, total
end

function Game.ascend(p: Profile): (boolean, string)
	if not (Game.canAscend(p)) then
		return false, "Buy everything first"
	end
	resetRun(p)
	p.investors = BigNum.zero
	p.powers = {}
	p.evolutions = 0
	p.ascensions += 1
	p.foreverTokens += Catalog.prestige.ascensionForeverTokens.value
	return true, "Ascended"
end

---------------------------------------------------------------------------
-- Forever Purchase: pick a pad that stays owned through every reset.
---------------------------------------------------------------------------

function Game.foreverEligible(p: Profile, padId: string): boolean
	local pad = Economy.padById[padId]
	return pad ~= nil and pad.kind ~= "unlock" and not p.forever[padId]
end

-- Consumes exactly one token, only on a valid confirmed target.
function Game.useForever(p: Profile, padId: string): (boolean, string)
	if p.foreverTokens < 1 then
		return false, "No Forever Purchases left"
	end
	if not Game.foreverEligible(p, padId) then
		return false, "Can't pick that"
	end
	p.foreverTokens -= 1
	p.forever[padId] = true
	p.pads[padId] = nil -- now covered by forever
	return true, Economy.padById[padId].name .. " is yours forever"
end

---------------------------------------------------------------------------
-- Robux grants (called from the receipt handler, after the PurchaseId check)
---------------------------------------------------------------------------

function Game.hasReceipt(p: Profile, purchaseId: string): boolean
	return table.find(p.robux.receipts, purchaseId) ~= nil
end

local function remember(p: Profile, purchaseId: string)
	table.insert(p.robux.receipts, purchaseId)
	while #p.robux.receipts > Profile.MAX_RECEIPTS do
		table.remove(p.robux.receipts, 1)
	end
end

local function grantSkip(p: Profile, seconds: number): Big
	local rate = Game.incomeRate(p, false)
	if rate.m <= 0 then
		p.robux.skipSeconds += seconds
		return BigNum.zero
	end
	local amount = BigNum.roundCents(BigNum.mulN(rate, seconds))
	earn(p, amount)
	return amount
end

-- Pay out banked time-skip seconds once the player has income.
function Game.flushSkips(p: Profile): Big?
	if p.robux.skipSeconds > 0 and Game.incomeRate(p, false).m > 0 then
		local s = p.robux.skipSeconds
		p.robux.skipSeconds = 0
		return grantSkip(p, s)
	end
	return nil
end

local POWER_PRODUCTS = { expertPicker = true, manage = true, runFaster = true, stack = true, remoteBuy = true }
local SKIPS = { cash1h = 3600, cash24h = 86400, cash7d = 604800 }

-- Returns ok, message. ok=false means "do not record the receipt" (e.g. unknown product).
function Game.grantProduct(p: Profile, productKey: string, purchaseId: string): (boolean, string)
	if Game.hasReceipt(p, purchaseId) then
		return true, "Already granted" -- duplicate delivery: no second grant
	end
	if POWER_PRODUCTS[productKey] then
		local def = POWERS[productKey]
		p.robux.tiers[productKey] = math.min(def.tiers, (p.robux.tiers[productKey] or 0) + 1)
	elseif productKey == "speedUp" or productKey == "x2investors" then
		p.robux.passes[productKey] = true
	elseif productKey == "forever" then
		p.foreverTokens += 1
	elseif productKey == "rebirthNoReset" then
		p.robux.rebirthCredits += 1
	elseif SKIPS[productKey] then
		grantSkip(p, SKIPS[productKey])
	else
		return false, "Unknown product"
	end
	remember(p, purchaseId)
	return true, "Thanks for your purchase!"
end

-- Products that are one-time permanent unlocks and therefore "owned" once bought.
function Game.productOwned(p: Profile, productKey: string): boolean
	if productKey == "speedUp" or productKey == "x2investors" then
		return p.robux.passes[productKey] == true
	end
	local def = POWERS[productKey]
	if def then
		return (p.robux.tiers[productKey] or 0) >= def.tiers
	end
	return false
end

return Game
