--!strict
-- Persistent profile schema and every rule that mutates it: receipts,
-- diamond purchases, powerup upgrades, match rewards and deferred credits.
-- Pure Luau so idempotency can be tested without Roblox (tests/ProfileRules.spec.luau).
--
-- DataService loads/saves the table; PurchaseService and RewardService call
-- these functions and only report success once the profile has been saved.

local Powerups = require("../Powerups")

export type Profile = {
	Version: number,
	Diamonds: number,
	Owned: { [string]: number }, -- powerup id -> level (1..3)
	Equipped: string?,
	Stats: { [string]: number }, -- challenge counters
	Credits: { Revive: { [string]: number }, CarePackage: number, Bandage: number },
	Receipts: { string }, -- recently processed PurchaseIds (bounded)
	RewardedMatches: { string },
	Wins: number,
	Matches: number,
}

export type ProductLike = {
	Kind: string,
	Tier: number?,
	Amount: number?,
	Powerup: string?,
	Level: number?,
}

local ProfileRules = {}

ProfileRules.SchemaVersion = 1

function ProfileRules.New(): Profile
	return {
		Version = ProfileRules.SchemaVersion,
		Diamonds = 0,
		Owned = {},
		Equipped = nil,
		Stats = {},
		Credits = { Revive = {}, CarePackage = 0, Bandage = 0 },
		Receipts = {},
		RewardedMatches = {},
		Wins = 0,
		Matches = 0,
	}
end

-- Fills in missing fields from older/partial saves without discarding data.
function ProfileRules.Reconcile(data: any): Profile
	local p = ProfileRules.New()
	if type(data) ~= "table" then
		return p
	end
	p.Diamonds = if type(data.Diamonds) == "number" then math.max(0, math.floor(data.Diamonds)) else 0
	if type(data.Owned) == "table" then
		for id, lvl in data.Owned do
			if Powerups.ById[id] and type(lvl) == "number" then
				p.Owned[id] = math.clamp(math.floor(lvl), 1, Powerups.MaxLevel)
			end
		end
	end
	if type(data.Equipped) == "string" and p.Owned[data.Equipped] then
		p.Equipped = data.Equipped
	end
	if type(data.Stats) == "table" then
		for k, v in data.Stats do
			if type(k) == "string" and type(v) == "number" then
				p.Stats[k] = v
			end
		end
	end
	if type(data.Credits) == "table" then
		local c = data.Credits
		if type(c.Revive) == "table" then
			for k, v in c.Revive do
				if type(v) == "number" and v > 0 then
					p.Credits.Revive[tostring(k)] = math.floor(v)
				end
			end
		end
		p.Credits.CarePackage = if type(c.CarePackage) == "number" then math.max(0, c.CarePackage) else 0
		p.Credits.Bandage = if type(c.Bandage) == "number" then math.max(0, c.Bandage) else 0
	end
	if type(data.Receipts) == "table" then
		for _, r in data.Receipts do
			if type(r) == "string" then
				table.insert(p.Receipts, r)
			end
		end
	end
	if type(data.RewardedMatches) == "table" then
		for _, r in data.RewardedMatches do
			if type(r) == "string" then
				table.insert(p.RewardedMatches, r)
			end
		end
	end
	p.Wins = if type(data.Wins) == "number" then data.Wins else 0
	p.Matches = if type(data.Matches) == "number" then data.Matches else 0
	return p
end

local function pushBounded(list: { string }, value: string, max: number)
	table.insert(list, value)
	while #list > max do
		table.remove(list, 1)
	end
end

function ProfileRules.HasReceipt(p: Profile, purchaseId: string): boolean
	return table.find(p.Receipts, purchaseId) ~= nil
end

-- Applies a receipt exactly once. Returns "AlreadyGranted" or "Granted" and a
-- human-readable note. Every product becomes a durable profile change; in-match
-- effects (revive, package, bandage) are credits the match consumes afterwards,
-- so a purchase can never be lost because the player died, left or the match ended.
function ProfileRules.ApplyReceipt(p: Profile, purchaseId: string, product: ProductLike, memory: number): (string, string)
	if ProfileRules.HasReceipt(p, purchaseId) then
		return "AlreadyGranted", "duplicate"
	end
	local note = ""
	local kind = product.Kind
	if kind == "Diamonds" then
		p.Diamonds += product.Amount or 0
		note = "diamonds"
	elseif kind == "Unlock" then
		local id = product.Powerup :: string
		if p.Owned[id] then
			-- Already owned (race between two purchase paths): refund as diamonds.
			p.Diamonds += Powerups.UpgradePrice(id, 1)
			note = "refunded-as-diamonds"
		else
			p.Owned[id] = 1
			note = "unlocked"
		end
	elseif kind == "Upgrade" then
		local id = product.Powerup :: string
		local target = product.Level :: number
		local current = p.Owned[id] or 0
		if current == target - 1 then
			p.Owned[id] = target
			note = "upgraded"
		else
			p.Diamonds += Powerups.UpgradePrice(id, target)
			note = "refunded-as-diamonds"
		end
	elseif kind == "Revive" then
		local key = tostring(product.Tier or 1)
		p.Credits.Revive[key] = (p.Credits.Revive[key] or 0) + 1
		note = "revive-credit"
	elseif kind == "CarePackage" then
		p.Credits.CarePackage += 1
		note = "package-credit"
	elseif kind == "Bandage" then
		p.Credits.Bandage += product.Amount or 1
		note = "bandage-credit"
	else
		error("unknown product kind " .. tostring(kind))
	end
	pushBounded(p.Receipts, purchaseId, memory)
	return "Granted", note
end

function ProfileRules.ConsumeReviveCredit(p: Profile, tier: number): boolean
	local key = tostring(tier)
	local n = p.Credits.Revive[key] or 0
	if n <= 0 then
		return false
	end
	p.Credits.Revive[key] = n - 1
	if n - 1 == 0 then
		p.Credits.Revive[key] = nil
	end
	return true
end

-- Diamonds ------------------------------------------------------------------------

function ProfileRules.BuyUnlock(p: Profile, id: string): (boolean, string?)
	local def = Powerups.ById[id]
	if not def then
		return false, "Unknown powerup"
	end
	if p.Owned[id] then
		return false, "Already owned"
	end
	if p.Diamonds < def.Price then
		return false, "Not enough diamonds"
	end
	p.Diamonds -= def.Price
	p.Owned[id] = 1
	return true, nil
end

function ProfileRules.ChallengeMet(p: Profile, id: string, level: number): boolean
	local def = Powerups.ById[id]
	local ch = def and def.Challenges[level]
	if not ch then
		return false
	end
	return (p.Stats[ch.Stat] or 0) >= ch.Target
end

function ProfileRules.BuyUpgrade(p: Profile, id: string): (boolean, string?)
	local def = Powerups.ById[id]
	if not def then
		return false, "Unknown powerup"
	end
	local current = p.Owned[id]
	if not current then
		return false, "Unlock it first"
	end
	if current >= Powerups.MaxLevel then
		return false, "Already max level"
	end
	local target = current + 1
	if not ProfileRules.ChallengeMet(p, id, target) then
		return false, "Challenge not complete"
	end
	local price = Powerups.UpgradePrice(id, target)
	if p.Diamonds < price then
		return false, "Not enough diamonds"
	end
	p.Diamonds -= price
	p.Owned[id] = target
	return true, nil
end

function ProfileRules.Equip(p: Profile, id: string?): (boolean, string?)
	if id == nil then
		p.Equipped = nil
		return true, nil
	end
	if not p.Owned[id] then
		return false, "Not owned"
	end
	p.Equipped = id
	return true, nil
end

-- Match rewards (exactly once per match id) ---------------------------------------

function ProfileRules.AwardWin(p: Profile, matchId: string, diamonds: number, memory: number): boolean
	if table.find(p.RewardedMatches, matchId) then
		return false
	end
	p.Diamonds += diamonds
	p.Wins += 1
	pushBounded(p.RewardedMatches, matchId, memory)
	return true
end

function ProfileRules.AddStat(p: Profile, stat: string, amount: number)
	if amount > 0 then
		p.Stats[stat] = (p.Stats[stat] or 0) + amount
	end
end

return ProfileRules
