--!strict
-- Currency, multipliers, boosts and capacity rules. Every coin or gem change
-- goes through AddCoins / SpendCoins / AddGems / SpendGems so balances stay
-- finite, whole and inside the hard caps.

local Config = require("../Config")
local Areas = require("../Areas")
local Schema = require("./Schema")

type Profile = Schema.Profile

export type MultContext = {
	Now: number,
	Premium: boolean?,
	InGroup: boolean?,
	ServerLuckUntil: number?,
	-- PolicyService restricts paid random items for this player: luck from the
	-- Lucky pass, luck boosts and server luck doesn't apply to them.
	NoPaidLuck: boolean?,
}

local Economy = {}

function Economy.HasPass(p: Profile, key: string): boolean
	return p.Passes[key] == true
end

function Economy.BoostActive(p: Profile, key: string, now: number): boolean
	local expires = p.Boosts[key]
	return type(expires) == "number" and expires > now
end

function Economy.CoinMult(p: Profile, c: MultContext): number
	local mult = 1 + Config.RebirthCoinBonus * math.max(0, p.Rebirths)
	if Economy.HasPass(p, "VIP") then
		mult *= Config.VipCoinMult
	end
	if Economy.BoostActive(p, "Coins2x", c.Now) then
		mult *= Config.CoinBoostMult
	end
	if c.Premium then
		mult *= Config.PremiumCoinMult
	end
	if c.InGroup and Config.GroupId ~= 0 then
		mult *= Config.GroupCoinMult
	end
	return mult
end

function Economy.LuckMult(p: Profile, c: MultContext): number
	if c.NoPaidLuck then
		return 1
	end
	local mult = 1
	if Economy.HasPass(p, "Lucky") then
		mult *= Config.LuckyPassMult
	end
	if Economy.BoostActive(p, "Luck2x", c.Now) then
		mult *= Config.LuckBoostMult
	end
	local serverUntil = c.ServerLuckUntil
	if serverUntil and serverUntil > c.Now then
		mult *= Config.ServerLuckMult
	end
	return math.min(mult, Config.MaxLuckMult)
end

function Economy.MaxEquip(p: Profile): number
	local n = Config.BaseEquip + math.max(0, p.ExtraEquip)
	if Economy.HasPass(p, "MoreEquip") then
		n += 3
	end
	return math.min(n, Config.MaxEquipCap)
end

function Economy.MaxStorage(p: Profile): number
	local n = Config.BaseStorage + math.max(0, p.ExtraStorage)
	if Economy.HasPass(p, "BigBackpack") then
		n += 150
	end
	return n
end

function Economy.ExpeditionSlots(p: Profile): number
	local n = Config.BaseExpeditionSlots
	if Economy.HasPass(p, "MoreExpeditions") then
		n += 2
	end
	return n
end

function Economy.RebirthCost(rebirths: number): number
	return Config.RebirthBaseCost * Config.RebirthCostGrowth ^ math.max(0, rebirths)
end

-- Adds coins (rounded down, capped). Returns the amount actually added.
-- `earned` counts the coins toward Stats.CoinsEarned (gameplay income).
function Economy.AddCoins(p: Profile, amount: number, earned: boolean?): number
	if not Schema.IsFinite(amount) or amount <= 0 then
		return 0
	end
	local before = p.Coins
	p.Coins = math.min(Schema.MaxCoins, math.floor(before + amount))
	local added = p.Coins - before
	if earned and added > 0 then
		p.Stats.CoinsEarned = math.min(Schema.MaxStat, p.Stats.CoinsEarned + added)
	end
	return added
end

function Economy.CanAfford(p: Profile, currency: string, amount: number): boolean
	if not Schema.IsFinite(amount) or amount < 0 then
		return false
	end
	if currency == "Coins" then
		return p.Coins >= amount
	elseif currency == "Gems" then
		return p.Gems >= amount
	end
	return false
end

-- Removes currency if the player can afford it. Returns success.
function Economy.Spend(p: Profile, currency: string, amount: number): boolean
	if not Economy.CanAfford(p, currency, amount) then
		return false
	end
	amount = math.ceil(amount)
	if currency == "Coins" then
		p.Coins = math.max(0, p.Coins - amount)
	else
		p.Gems = math.max(0, p.Gems - amount)
	end
	return true
end

function Economy.AddGems(p: Profile, amount: number): number
	if not Schema.IsFinite(amount) or amount <= 0 then
		return 0
	end
	local before = p.Gems
	p.Gems = math.min(Schema.MaxGems, math.floor(before + amount))
	return p.Gems - before
end

-- Starts or extends a personal boost. Stacks by extending, capped at
-- Config.MaxBoostSeconds from now. Returns the new expiry (0 if unknown key).
function Economy.ApplyBoost(p: Profile, key: string, now: number): number
	local def = Config.Boosts[key]
	if not def then
		return 0
	end
	local current = p.Boosts[key]
	local from = if type(current) == "number" and current > now then current else now
	local expires = math.min(from + def.Seconds, now + Config.MaxBoostSeconds)
	p.Boosts[key] = expires
	return expires
end

-- Removes expired boosts. Returns true if anything was removed.
function Economy.PruneBoosts(p: Profile, now: number): boolean
	local changed = false
	for key, expires in p.Boosts do
		if type(expires) ~= "number" or expires <= now then
			p.Boosts[key] = nil
			changed = true
		end
	end
	return changed
end

-- Server-wide luck: returns the new expiry after one more purchase.
function Economy.ExtendServerLuck(currentUntil: number, now: number): number
	local from = if currentUntil > now then currentUntil else now
	return math.min(from + Config.ServerLuckSeconds, now + Config.MaxBoostSeconds)
end

export type Share = { Coins: number, Gems: number, Credit: boolean }

Economy.MinCreditShare = 0.05 -- damage share needed for credit (quests, XP, min 1 coin)

-- Splits a broken breakable's loot by damage dealt. `damage` is a list (one
-- entry per contributor). Coins are returned unrounded (the caller applies
-- each player's coin multiplier, then rounds). Gems use a largest-remainder
-- split, so they always add up to exactly `gems` and never more. Contributors
-- with at least MinCreditShare of the damage get Credit (and >= 1 coin).
function Economy.SplitBreak(damage: { number }, coins: number, gems: number): { Share }
	local out: { Share } = {}
	local total = 0
	for _, d in damage do
		if Schema.IsFinite(d) and d > 0 then
			total += d
		end
	end
	local gemTotal = if Schema.IsFinite(gems) and gems > 0 then math.floor(gems) else 0
	local coinTotal = if Schema.IsFinite(coins) and coins > 0 then coins else 0
	local rema: { { I: number, R: number, D: number } } = {}
	local given = 0
	for i, d in damage do
		local dmg = if Schema.IsFinite(d) and d > 0 then d else 0
		local share = if total > 0 then dmg / total else 0
		local credit = share >= Economy.MinCreditShare
		local c = coinTotal * share
		if credit then
			c = math.max(1, c)
		end
		local exact = gemTotal * share
		local g = math.floor(exact)
		given += g
		out[i] = { Coins = c, Gems = g, Credit = credit }
		table.insert(rema, { I = i, R = exact - g, D = dmg })
	end
	table.sort(rema, function(a, b)
		if a.R ~= b.R then
			return a.R > b.R
		end
		if a.D ~= b.D then
			return a.D > b.D
		end
		return a.I < b.I
	end)
	local left = gemTotal - given
	for _, r in rema do
		if left <= 0 or total <= 0 then
			break
		end
		if r.D > 0 then
			out[r.I].Gems += 1
			left -= 1
		end
	end
	return out
end

export type CapEntry = { At: number, N: number }

-- Rolling-window cap (e.g. Config.BreakGemsPerHour). `log` holds what was
-- granted recently and is updated in place. Returns how much of `amount` may
-- be granted now (0..amount).
function Economy.CapRolling(log: { CapEntry }, now: number, amount: number, cap: number, window: number): number
	local i = 1
	while i <= #log do
		if now - log[i].At >= window then
			table.remove(log, i)
		else
			i += 1
		end
	end
	if not Schema.IsFinite(amount) or amount <= 0 then
		return 0
	end
	local used = 0
	for _, e in log do
		used += e.N
	end
	local allowed = math.max(0, math.min(math.floor(amount), math.floor(cap) - used))
	if allowed > 0 then
		table.insert(log, { At = now, N = allowed })
	end
	return allowed
end

-- Opens the next island's gate. Islands open in order.
function Economy.OpenGate(p: Profile, areaId: string): (boolean, string?)
	local area = Areas.ById[areaId]
	if not area then
		return false, "Unknown island"
	end
	if p.Areas[areaId] then
		return false, "Already open"
	end
	local prev = Areas.List[area.Index - 1]
	if prev and not p.Areas[prev.Id] then
		return false, "Open " .. prev.Name .. " first"
	end
	if not Economy.Spend(p, "Coins", area.GateCost) then
		return false, "Not enough coins"
	end
	p.Areas[areaId] = true
	return true, nil
end

-- Rebirth: costs coins, resets coins and gates, keeps pets / gems / passes,
-- grants gems and a permanent coin bonus.
function Economy.Rebirth(p: Profile): (boolean, string?)
	if p.Rebirths >= Config.MaxRebirths then
		return false, "Maximum rebirths reached"
	end
	local cost = Economy.RebirthCost(p.Rebirths)
	if p.Coins < cost then
		return false, "Not enough coins"
	end
	p.Coins = 0
	p.Areas = { [Schema.StartArea] = true }
	p.Rebirths += 1
	Economy.AddGems(p, Config.RebirthGems)
	return true, nil
end

-- Highest opened island (by unlock order).
function Economy.HighestArea(p: Profile): string
	local best = Schema.StartArea
	for _, a in Areas.List do
		if p.Areas[a.Id] then
			best = a.Id
		end
	end
	return best
end

return Economy
