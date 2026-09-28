--!strict
-- Persistent profile schema and every rule that mutates it: receipts, account
-- XP / levels, Coins, Diamonds, classes, power-ups, cosmetics, daily / weekly
-- bonuses and match rewards. Pure Luau so idempotency can be tested without
-- Roblox (tests/ProfileRules.spec.luau).
--
-- Schema v2 (Survival Wars): the old three-level powerups are retired; Diamonds
-- spent on them are refunded by Reconcile so players can buy classes/power-ups.

local Classes = require("../Classes")
local Perks = require("../Perks")
local Cosmetics = require("../Cosmetics")
local Progression = require("../Progression")
local Challenges = require("./Challenges")

export type Profile = {
	Version: number,
	Diamonds: number,
	Coins: number,
	XP: number,
	Level: number, -- derived from XP (stored for leaderboards)
	Class: string,
	OwnedClasses: { [string]: boolean },
	Perk: string?,
	OwnedPerks: { [string]: boolean },
	Cosmetics: { [string]: boolean },
	Wearing: { [string]: string }, -- cosmetic type -> id
	Stats: { [string]: number },
	Credits: { Revive: { [string]: number }, CarePackage: number, Bandage: number }, -- legacy (off sale)
	Receipts: { string }, -- recently processed PurchaseIds (bounded)
	RewardedMatches: { string },
	Wins: number,
	Matches: number,
	Kills: number,
	Eliminations: number,
	Daily: { Day: number, Streak: number },
	Weekly: { Week: number, Matches: number, Wins: number, Claimed: boolean },
	Settings: { [string]: any },
	Challenges: Challenges.State, -- daily / weekly gameplay challenges (Logic/Challenges)
}


export type ProductLike = {
	Kind: string,
	Tier: number?,
	Amount: number?,
	Powerup: string?,
	Level: number?,
	Bundle: string?,
}

local ProfileRules = {}

ProfileRules.SchemaVersion = 2

-- Player settings: key -> default. Validated on write (ProfileRules.SetSetting).
ProfileRules.SettingDefaults = {
	ReduceMotion = false, -- no FOV punch / damage roll / sprint widen
	ShowGuide = true, -- Survival Guide tracker
	Ambience = 0.8, -- 0..1 ambience/music volume
	UiSounds = true,
} :: { [string]: any }

-- Old (v1) powerups: unlock price and upgrade multipliers, for the refund.
local OLD_POWERUPS = { Trailblazer = 100, Scavenger = 175, Hunter = 150, Climber = 200, Craftsman = 125, Sharpshooter = 250 }
local OLD_MULT = { 1, 0.8, 1.5 }

function ProfileRules.New(): Profile
	return {
		Version = ProfileRules.SchemaVersion,
		Diamonds = 0,
		Coins = 0,
		XP = 0,
		Level = 1,
		Class = Classes.Default,
		OwnedClasses = { [Classes.Default] = true },
		Perk = nil,
		OwnedPerks = {},
		Cosmetics = {},
		Wearing = {},
		Stats = {},
		Credits = { Revive = {}, CarePackage = 0, Bandage = 0 },
		Receipts = {},
		RewardedMatches = {},
		Wins = 0,
		Matches = 0,
		Kills = 0,
		Eliminations = 0,
		Daily = { Day = -1, Streak = 0 },
		Weekly = { Week = -1, Matches = 0, Wins = 0, Claimed = false },
		Settings = table.clone(ProfileRules.SettingDefaults),
		Challenges = Challenges.New(),
	}
end

-- Validates and stores one setting (same type as its default; numbers 0..1).
function ProfileRules.SetSetting(p: Profile, key: any, value: any): boolean
	local default = if type(key) == "string" then ProfileRules.SettingDefaults[key] else nil
	if default == nil or type(value) ~= type(default) then
		return false
	end
	if type(value) == "number" then
		if value ~= value then
			return false
		end
		value = math.clamp(value, 0, 1)
	end
	p.Settings[key] = value
	return true
end

local MAX_VALUE = 1e9 -- sanity cap for any stored number (corrupt / tampered saves)

local function num(v: any, default: number): number
	return if type(v) == "number" and v == v and math.abs(v) <= MAX_VALUE then v else default
end

-- Fills in missing fields from older/partial saves without discarding data.
function ProfileRules.Reconcile(data: any): Profile
	local p = ProfileRules.New()
	if type(data) ~= "table" then
		return p
	end
	p.Diamonds = math.max(0, math.floor(num(data.Diamonds, 0)))
	p.Coins = math.max(0, math.floor(num(data.Coins, 0)))
	p.XP = math.max(0, math.floor(num(data.XP, 0)))
	p.Level = (Progression.LevelFromXP(p.XP))
	-- v1 -> v2: refund Diamonds spent on retired powerups
	if num(data.Version, 1) < 2 and type(data.Owned) == "table" then
		for id, lvl in data.Owned do
			local price = OLD_POWERUPS[id]
			if price and type(lvl) == "number" then
				for l = 1, math.clamp(math.floor(lvl), 1, 3) do
					p.Diamonds += math.floor(price * OLD_MULT[l] + 0.5)
				end
			end
		end
	end
	if type(data.OwnedClasses) == "table" then
		for id, v in data.OwnedClasses do
			if Classes.ById[id] and v == true then
				p.OwnedClasses[id] = true
			end
		end
	end
	if type(data.Class) == "string" and p.OwnedClasses[data.Class] then
		p.Class = data.Class
	end
	if type(data.OwnedPerks) == "table" then
		for id, v in data.OwnedPerks do
			if Perks.ById[id] and v == true then
				p.OwnedPerks[id] = true
			end
		end
	end
	if type(data.Perk) == "string" and p.OwnedPerks[data.Perk] then
		p.Perk = data.Perk
	end
	if type(data.Cosmetics) == "table" then
		for id, v in data.Cosmetics do
			if Cosmetics.ById[id] and v == true then
				p.Cosmetics[id] = true
			end
		end
	end
	if type(data.Wearing) == "table" then
		for typ, id in data.Wearing do
			local def = if type(id) == "string" then Cosmetics.ById[id] else nil
			if def and def.Type == typ and p.Cosmetics[id] then
				p.Wearing[typ] = id
			end
		end
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
		p.Credits.CarePackage = math.max(0, num(c.CarePackage, 0))
		p.Credits.Bandage = math.max(0, num(c.Bandage, 0))
	end
	for _, key in { "Receipts", "RewardedMatches" } do
		if type(data[key]) == "table" then
			for _, r in data[key] do
				if type(r) == "string" then
					table.insert((p :: any)[key], r)
				end
			end
		end
	end
	p.Wins = num(data.Wins, 0)
	p.Matches = num(data.Matches, 0)
	p.Kills = num(data.Kills, 0)
	p.Eliminations = num(data.Eliminations, 0)
	if type(data.Daily) == "table" then
		p.Daily = { Day = num(data.Daily.Day, -1), Streak = num(data.Daily.Streak, 0) }
	end
	if type(data.Weekly) == "table" then
		p.Weekly = { Week = num(data.Weekly.Week, -1), Matches = num(data.Weekly.Matches, 0), Wins = num(data.Weekly.Wins, 0), Claimed = data.Weekly.Claimed == true }
	end
	p.Challenges = Challenges.Reconcile(data.Challenges)
	if type(data.Settings) == "table" then
		for k, v in data.Settings do
			ProfileRules.SetSetting(p, k, v)
		end
	end
	ProfileRules.GrantLevelCosmetics(p)
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

-- Applies a receipt exactly once. Returns "AlreadyGranted" or "Granted" and a note.
-- Coins and cosmetic bundles are the only products on sale (non-pay-to-win); the
-- legacy kinds still resolve so an old receipt can never be lost.
function ProfileRules.ApplyReceipt(p: Profile, purchaseId: string, product: ProductLike, memory: number): (string, string)
	if ProfileRules.HasReceipt(p, purchaseId) then
		return "AlreadyGranted", "duplicate"
	end
	local note = ""
	local kind = product.Kind
	if kind == "Coins" then
		p.Coins += product.Amount or 0
		note = "coins"
	elseif kind == "Bundle" then
		local list: { string } = Cosmetics.Bundles[product.Bundle or ""] or {}
		for _, id in list do
			if p.Cosmetics[id] then
				-- already owned: refund its coin value
				local def = Cosmetics.ById[id]
				p.Coins += if def then def.Price else 0
			else
				p.Cosmetics[id] = true
			end
		end
		note = "bundle"
	elseif kind == "Diamonds" then
		p.Diamonds += product.Amount or 0
		note = "diamonds (legacy)"
	elseif kind == "Unlock" or kind == "Upgrade" then
		-- retired powerup products: refund at the old unlock price
		p.Diamonds += OLD_POWERUPS[product.Powerup or ""] or 0
		note = "refunded-as-diamonds"
	elseif kind == "Revive" then
		local key = tostring(product.Tier or 1)
		p.Credits.Revive[key] = (p.Credits.Revive[key] or 0) + 1
		note = "revive-credit (legacy)"
	elseif kind == "CarePackage" then
		p.Credits.CarePackage += 1
		note = "package-credit (legacy)"
	elseif kind == "Bandage" then
		p.Credits.Bandage += product.Amount or 1
		note = "bandage-credit (legacy)"
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
	if n > 1 then
		p.Credits.Revive[key] = n - 1
	else
		p.Credits.Revive[key] = nil
	end
	return true
end

-- Classes & power-ups (Diamonds) -----------------------------------------------------

function ProfileRules.BuyClass(p: Profile, id: string): (boolean, string?)
	local def = Classes.ById[id]
	if not def then
		return false, "Unknown class"
	end
	if p.OwnedClasses[id] then
		return false, "Already owned"
	end
	if p.Diamonds < def.Price then
		return false, "Not enough Diamonds"
	end
	p.Diamonds -= def.Price
	p.OwnedClasses[id] = true
	return true, nil
end

function ProfileRules.EquipClass(p: Profile, id: string): (boolean, string?)
	if not p.OwnedClasses[id] then
		return false, "Not owned"
	end
	p.Class = id
	return true, nil
end

function ProfileRules.BuyPerk(p: Profile, id: string): (boolean, string?)
	local def = Perks.ById[id]
	if not def then
		return false, "Unknown power-up"
	end
	if p.OwnedPerks[id] then
		return false, "Already owned"
	end
	if p.Diamonds < def.Price then
		return false, "Not enough Diamonds"
	end
	p.Diamonds -= def.Price
	p.OwnedPerks[id] = true
	return true, nil
end

function ProfileRules.EquipPerk(p: Profile, id: string?): (boolean, string?)
	if id == nil then
		p.Perk = nil
		return true, nil
	end
	if not p.OwnedPerks[id] then
		return false, "Not owned"
	end
	p.Perk = id
	return true, nil
end

-- Cosmetics (Coins) -------------------------------------------------------------------

function ProfileRules.BuyCosmetic(p: Profile, id: string): (boolean, string?)
	local def = Cosmetics.ById[id]
	if not def then
		return false, "Unknown cosmetic"
	end
	if p.Cosmetics[id] then
		return false, "Already owned"
	end
	if def.Price <= 0 then
		return false, if def.Level then "Unlocked at level " .. def.Level else "Not sold"
	end
	if p.Coins < def.Price then
		return false, "Not enough Coins"
	end
	p.Coins -= def.Price
	p.Cosmetics[id] = true
	return true, nil
end

function ProfileRules.WearCosmetic(p: Profile, typ: string, id: string?): (boolean, string?)
	if id == nil then
		p.Wearing[typ] = nil
		return true, nil
	end
	local def = Cosmetics.ById[id]
	if not def or def.Type ~= typ or not p.Cosmetics[id] then
		return false, "Not owned"
	end
	p.Wearing[typ] = id
	return true, nil
end

-- Level-reward cosmetics (titles / nameplates) for the current level.
function ProfileRules.GrantLevelCosmetics(p: Profile): { string }
	local granted = {}
	for _, def in Cosmetics.List do
		if def.Level and p.Level >= def.Level and not p.Cosmetics[def.Id] then
			p.Cosmetics[def.Id] = true
			table.insert(granted, def.Id)
		end
	end
	return granted
end

-- XP / Coins --------------------------------------------------------------------------

export type XPResult = { Levels: number, NewLevel: number, Coins: number, Diamonds: number, Cosmetics: { string } }

-- Adds XP, applying level-up rewards (Coins every 5 levels, 1 Diamond every 10,
-- title/nameplate unlocks at milestones).
function ProfileRules.AddXP(p: Profile, amount: number): XPResult
	local before = p.Level
	p.XP += math.max(0, math.floor(amount))
	p.Level = (Progression.LevelFromXP(p.XP))
	local res: XPResult = { Levels = p.Level - before, NewLevel = p.Level, Coins = 0, Diamonds = 0, Cosmetics = {} }
	for _, r in Progression.LevelRewards(before, p.Level) do
		p.Coins += r.Coins
		p.Diamonds += r.Diamonds
		res.Coins += r.Coins
		res.Diamonds += r.Diamonds
	end
	res.Cosmetics = ProfileRules.GrantLevelCosmetics(p)
	return res
end

function ProfileRules.AddCoins(p: Profile, amount: number)
	p.Coins += math.max(0, math.floor(amount))
end

-- Match rewards (exactly once per match id) ---------------------------------------------

-- Placement rewards (1st: 500 XP, 250 Coins, EXACTLY 2 Diamonds; 2nd: 250 XP, 100 Coins;
-- 3rd: 50 Coins). Returns xp, coins, diamonds granted (zeros if already rewarded).
function ProfileRules.AwardPlacement(p: Profile, matchId: string, place: number, memory: number): (number, number, number)
	if table.find(p.RewardedMatches, matchId) then
		return 0, 0, 0
	end
	pushBounded(p.RewardedMatches, matchId, memory)
	local xp, coins, diamonds = Progression.Placement(place)
	if place == 1 then
		p.Wins += 1
	end
	ProfileRules.AddXP(p, xp)
	p.Coins += coins
	p.Diamonds += diamonds
	return xp, coins, diamonds
end

-- Kept for older callers: a win = placement 1.
function ProfileRules.AwardWin(p: Profile, matchId: string, _diamonds: number, memory: number): boolean
	local _, _, d = ProfileRules.AwardPlacement(p, matchId, 1, memory)
	return d > 0
end

function ProfileRules.AddStat(p: Profile, stat: string, amount: number)
	if amount > 0 then
		p.Stats[stat] = (p.Stats[stat] or 0) + amount
	end
end

-- Daily / weekly bonuses ----------------------------------------------------------------

function ProfileRules.CanClaimDaily(p: Profile, now: number): boolean
	return p.Daily.Day ~= Progression.DayNumber(now)
end

function ProfileRules.ClaimDaily(p: Profile, now: number): number
	local day = Progression.DayNumber(now)
	if p.Daily.Day == day then
		return 0
	end
	local streak = if p.Daily.Day == day - 1 then p.Daily.Streak + 1 else 1
	p.Daily = { Day = day, Streak = streak }
	local coins = Progression.DailyCoins(streak)
	p.Coins += coins
	return coins
end

-- Counts a finished match toward this week's bonus.
function ProfileRules.NoteMatch(p: Profile, now: number, won: boolean)
	local week = Progression.WeekNumber(now)
	if p.Weekly.Week ~= week then
		p.Weekly = { Week = week, Matches = 0, Wins = 0, Claimed = false }
	end
	p.Weekly.Matches += 1
	if won then
		p.Weekly.Wins += 1
	end
end

function ProfileRules.CanClaimWeekly(p: Profile, now: number): boolean
	return p.Weekly.Week == Progression.WeekNumber(now) and not p.Weekly.Claimed and p.Weekly.Matches >= Progression.WeeklyMatches
end

function ProfileRules.ClaimWeekly(p: Profile, now: number): number
	if not ProfileRules.CanClaimWeekly(p, now) then
		return 0
	end
	p.Weekly.Claimed = true
	local coins = Progression.WeeklyCoins(p.Weekly.Wins)
	p.Coins += coins
	return coins
end

return ProfileRules
