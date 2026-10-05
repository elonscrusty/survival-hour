--!strict
-- Profiles: defaults for new players, sanitising of loaded (possibly old or
-- corrupted) data, and building the client's PlayerState snapshot.

local Config = require("../Config")
local Pets = require("../Pets")
local Areas = require("../Areas")
local Products = require("../Products")
local Types = require("../Types")
local Economy = require("./Economy")
local Inventory = require("./Inventory")
local Expedition = require("./Expedition")
local PetMath = require("./PetMath")
local Rewards = require("./Rewards")
local Schema = require("./Schema")

type Profile = Schema.Profile
type PetInstance = Schema.PetInstance

export type StateContext = {
	Now: number,
	Premium: boolean?,
	InGroup: boolean?,
	ServerLuckUntil: number?,
	CanBuyGemEggs: boolean?,
	CanTrade: boolean?,
}

local Profile = {}

Profile.MaxPets = 3000 -- hard cap on stored pets (bounds the save size)
Profile.MaxExtraStorage = 10000

function Profile.Default(): Profile
	local settings: { [string]: any } = {}
	for k, v in Schema.SettingDefaults do
		settings[k] = v
	end
	return {
		Version = Config.Version,
		Coins = Schema.StartCoins,
		Gems = 0,
		Rebirths = 0,
		Areas = { [Schema.StartArea] = true },
		Pets = {},
		NextUid = 0,
		Equipped = {},
		Expeditions = {},
		Passes = {},
		Boosts = {},
		Index = {},
		IndexClaimed = {},
		Daily = { Streak = 0, LastDay = -1 },
		Quests = { Day = -1, List = {} },
		Stats = { Hatched = 0, Broken = 0, Expeditions = 0, CoinsEarned = 0, Crafted = 0 },
		Settings = settings,
		ExtraEquip = 0,
		ExtraStorage = 0,
		Receipts = {},
		Playtime = { Day = -1, Minutes = 0, Claimed = {} },
		ExpeditionMult = {},
		PendingTrade = nil,
		AppliedTrades = {},
	}
end

local function tbl(v: any): { [any]: any }
	return if type(v) == "table" then v else {}
end

local function sanitizePets(p: Profile, raw: any)
	local list: { PetInstance } = {}
	local needUid: { PetInstance } = {}
	local seen: { [string]: boolean } = {}
	local maxNum = p.NextUid
	for _, r in tbl(raw) do
		if #list >= Profile.MaxPets then
			break
		end
		if type(r) ~= "table" or type(r.Id) ~= "string" or not Pets.ById[r.Id] then
			continue
		end
		local variant = if type(r.Variant) == "string" and table.find(Config.Variants, r.Variant) then r.Variant else "Normal"
		local level = Schema.ClampInt(r.Level, 1, Config.PetMaxLevel)
		local xp = if level >= Config.PetMaxLevel then 0 else Schema.ClampInt(r.Xp, 0, PetMath.XpToNext(level) - 1)
		local pet: PetInstance = {
			Uid = "",
			Id = r.Id,
			Variant = variant,
			Shiny = r.Shiny == true,
			Level = level,
			Xp = xp,
			Locked = r.Locked == true,
		}
		local uid = r.Uid
		if type(uid) == "string" and #uid > 0 and #uid <= Schema.MaxUidLength and not seen[uid] then
			seen[uid] = true
			pet.Uid = uid
			local n = tonumber(uid)
			if n and Schema.IsFinite(n) and n > maxNum then
				maxNum = math.min(math.floor(n), 1e15)
			end
		else
			table.insert(needUid, pet)
		end
		table.insert(list, pet)
	end
	p.Pets = list
	p.NextUid = maxNum
	-- Pets with a missing or duplicate uid get a fresh one (never dropped).
	for _, pet in needUid do
		pet.Uid = Inventory.NewUid(p)
	end
	for _, pet in list do
		p.Index[pet.Id] = true
	end
end

local function sanitizeExpeditions(p: Profile, raw: any)
	local maxSlots = Config.BaseExpeditionSlots + 2
	local used: { [string]: boolean } = {}
	p.Expeditions = {}
	local src = tbl(raw)
	-- Slots in order, so a pet listed twice always stays with the lower slot.
	for slot = 1, maxSlots do
		local e = src[tostring(slot)]
		if type(e) ~= "table" then
			continue
		end
		if type(e.Area) ~= "string" or not Areas.ById[e.Area] then
			continue
		end
		if type(e.Duration) ~= "string" or not Expedition.Duration(e.Duration) then
			continue
		end
		if not Schema.IsFinite(e.StartAt) or not Schema.IsFinite(e.EndAt) then
			continue
		end
		local pets: { string } = {}
		for _, uid in tbl(e.Pets) do
			if #pets >= Config.MaxPetsPerExpedition then
				break
			end
			if type(uid) == "string" and not used[uid] and Inventory.Find(p, uid) then
				used[uid] = true
				table.insert(pets, uid)
			end
		end
		if #pets == 0 then
			continue
		end
		p.Expeditions[tostring(slot)] = {
			Area = e.Area,
			Duration = e.Duration,
			Pets = pets,
			StartAt = math.floor(e.StartAt),
			EndAt = math.floor(e.EndAt),
			Seed = Schema.ClampInt(e.Seed, 1, 2147483646),
		}
	end
end

local function sanitizeQuests(p: Profile, raw: any)
	local q = tbl(raw)
	local list: { Schema.Quest } = {}
	local ok = Schema.IsInt(q.Day)
	for _, r in tbl(q.List) do
		if type(r) ~= "table" or type(r.Kind) ~= "string" or not Schema.IsFinite(r.Goal) or r.Goal < 1 then
			ok = false
			break
		end
		local goal = math.floor(r.Goal)
		table.insert(list, {
			Kind = r.Kind,
			Goal = goal,
			Progress = Schema.ClampInt(r.Progress, 0, goal),
			Gems = Schema.ClampInt(r.Gems, 0, 1000),
			Claimed = r.Claimed == true,
		})
	end
	if not ok or #list > Config.QuestsPerDay then
		p.Quests = { Day = -1, List = {} } -- regenerated on next use
	else
		p.Quests = { Day = q.Day, List = list }
	end
end

-- Builds a valid profile from anything loaded from the DataStore (nil for a
-- new player). Unknown fields are dropped; bad values are clamped.
function Profile.Sanitize(raw: any): Profile
	local p = Profile.Default()
	if type(raw) ~= "table" then
		return p
	end
	p.Coins = if raw.Coins == nil then Schema.StartCoins else Schema.ClampInt(raw.Coins, 0, Schema.MaxCoins)
	p.Gems = Schema.ClampInt(raw.Gems, 0, Schema.MaxGems)
	p.Rebirths = Schema.ClampInt(raw.Rebirths, 0, Config.MaxRebirths)
	for id, v in tbl(raw.Areas) do
		if v == true and type(id) == "string" and Areas.ById[id] then
			p.Areas[id] = true
		end
	end
	for key, v in tbl(raw.Passes) do
		if v == true and type(key) == "string" and Products.PassByKey[key] then
			p.Passes[key] = true
		end
	end
	for key, v in tbl(raw.Boosts) do
		if type(key) == "string" and Config.Boosts[key] and Schema.IsFinite(v) then
			p.Boosts[key] = math.floor(v)
		end
	end
	for id, v in tbl(raw.Index) do
		if v == true and type(id) == "string" and Pets.ById[id] then
			p.Index[id] = true
		end
	end
	for key, v in tbl(raw.IndexClaimed) do
		local n = tonumber(key)
		if v == true and n and Schema.IsInt(n, 1, #Config.IndexRewards) then
			p.IndexClaimed[tostring(n)] = true
		end
	end
	p.ExtraEquip = Schema.ClampInt(raw.ExtraEquip, 0, Config.MaxEquipCap)
	p.ExtraStorage = Schema.ClampInt(raw.ExtraStorage, 0, Profile.MaxExtraStorage)
	p.NextUid = Schema.ClampInt(raw.NextUid, 0, 1e15)
	sanitizePets(p, raw.Pets)
	sanitizeExpeditions(p, raw.Expeditions)

	local busy = Inventory.BusySet(p)
	local maxEquip = Economy.MaxEquip(p)
	for _, uid in tbl(raw.Equipped) do
		if #p.Equipped >= maxEquip then
			break
		end
		if type(uid) == "string" and not busy[uid] and not table.find(p.Equipped, uid) and Inventory.Find(p, uid) then
			table.insert(p.Equipped, uid)
		end
	end

	local daily = tbl(raw.Daily)
	p.Daily.Streak = Schema.ClampInt(daily.Streak, 0, 1e6)
	p.Daily.LastDay = if Schema.IsInt(daily.LastDay) then daily.LastDay else -1
	sanitizeQuests(p, raw.Quests)

	local stats = tbl(raw.Stats)
	local outStats: { [string]: number } = p.Stats :: any
	for key in outStats do
		outStats[key] = Schema.ClampInt(stats[key], 0, Schema.MaxStat)
	end
	local settings = tbl(raw.Settings)
	for key, default in Schema.SettingDefaults do
		local v = settings[key]
		p.Settings[key] = if type(v) == "boolean" then v else default
	end

	for id, at in tbl(raw.Receipts) do
		if type(id) == "string" and #id <= 128 and Schema.IsFinite(at) then
			p.Receipts[id] = at
		end
	end
	Profile.TrimReceipts(p)

	local play = tbl(raw.Playtime)
	if Schema.IsInt(play.Day) then
		p.Playtime.Day = play.Day
		p.Playtime.Minutes = if Schema.IsFinite(play.Minutes) then math.clamp(play.Minutes, 0, 24 * 60) else 0
		for key, v in tbl(play.Claimed) do
			local n = tonumber(key)
			if v == true and n and Schema.IsInt(n, 1, #Config.PlaytimeGifts) then
				p.Playtime.Claimed[tostring(n)] = true
			end
		end
	end

	for slot, mult in tbl(raw.ExpeditionMult) do
		if type(slot) == "string" and p.Expeditions[slot] and Schema.IsFinite(mult) and mult > 0 then
			p.ExpeditionMult[slot] = math.min(mult, Schema.MaxCoinMult)
		end
	end
	if type(raw.PendingTrade) == "string" and #raw.PendingTrade > 0 and #raw.PendingTrade <= 64 then
		p.PendingTrade = raw.PendingTrade
	end
	for _, id in tbl(raw.AppliedTrades) do
		if type(id) == "string" and #id <= 64 and #p.AppliedTrades < Schema.MaxAppliedTrades then
			table.insert(p.AppliedTrades, id)
		end
	end
	return p
end

-- Keeps only the newest Schema.MaxReceipts purchase ids.
function Profile.TrimReceipts(p: Profile)
	local list: { { Id: string, At: number } } = {}
	for id, at in p.Receipts do
		table.insert(list, { Id = id, At = at })
	end
	if #list <= Schema.MaxReceipts then
		return
	end
	table.sort(list, function(a, b)
		if a.At ~= b.At then
			return a.At > b.At
		end
		return a.Id > b.Id
	end)
	local kept: { [string]: number } = {}
	for i = 1, Schema.MaxReceipts do
		kept[list[i].Id] = list[i].At
	end
	p.Receipts = kept
end

function Profile.HasReceipt(p: Profile, purchaseId: string): boolean
	return p.Receipts[purchaseId] ~= nil
end

function Profile.RecordReceipt(p: Profile, purchaseId: string, now: number)
	p.Receipts[purchaseId] = now
	Profile.TrimReceipts(p)
end

function Profile.SetSetting(p: Profile, key: any, value: any): (boolean, string?)
	if type(key) ~= "string" or Schema.SettingDefaults[key] == nil then
		return false, "Unknown setting"
	end
	if type(value) ~= "boolean" then
		return false, "Bad value"
	end
	p.Settings[key] = value
	return true, nil
end

function Profile.CopyPet(pet: PetInstance): PetInstance
	return {
		Uid = pet.Uid,
		Id = pet.Id,
		Variant = pet.Variant,
		Shiny = pet.Shiny,
		Level = pet.Level,
		Xp = pet.Xp,
		Locked = pet.Locked,
	}
end

local function copySet(t: { [string]: boolean }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for k, v in t do
		if v then
			out[k] = true
		end
	end
	return out
end

-- The snapshot sent to the owning client.
function Profile.BuildState(p: Profile, c: StateContext): Types.PlayerState
	local now = c.Now
	local mult: Economy.MultContext = { Now = now, Premium = c.Premium, InGroup = c.InGroup, ServerLuckUntil = c.ServerLuckUntil }
	local day = Rewards.DayNumber(now)
	local pets: { PetInstance } = {}
	for _, pet in p.Pets do
		table.insert(pets, Profile.CopyPet(pet))
	end
	local exps: { [string]: Types.Expedition } = {}
	for key, e in p.Expeditions do
		exps[key] = {
			Area = e.Area,
			Duration = e.Duration,
			Pets = table.clone(e.Pets),
			StartAt = e.StartAt,
			EndAt = e.EndAt,
			Seed = 0, -- the reward seed stays on the server
		}
	end
	local boosts: { [string]: number } = {}
	for key, expires in p.Boosts do
		if expires > now then
			boosts[key] = expires
		end
	end
	local quests: { Schema.Quest } = {}
	local questList: { Schema.Quest } = Rewards.QuestsFor(p, day)
	for _, q in questList do
		table.insert(quests, { Kind = q.Kind, Goal = q.Goal, Progress = q.Progress, Gems = q.Gems, Claimed = q.Claimed })
	end
	local settings: { [string]: any } = {}
	for k, v in p.Settings do
		settings[k] = v
	end
	local serverLuck = c.ServerLuckUntil
	return {
		Coins = p.Coins,
		Gems = p.Gems,
		Rebirths = p.Rebirths,
		CoinMult = Economy.CoinMult(p, mult),
		LuckMult = Economy.LuckMult(p, mult),
		Areas = copySet(p.Areas),
		Pets = pets,
		Equipped = table.clone(p.Equipped),
		MaxEquip = Economy.MaxEquip(p),
		MaxStorage = Economy.MaxStorage(p),
		Expeditions = exps,
		ExpeditionSlots = Economy.ExpeditionSlots(p),
		Passes = copySet(p.Passes),
		Boosts = boosts,
		ServerLuckUntil = if serverLuck and serverLuck > now then serverLuck else 0,
		Index = copySet(p.Index),
		IndexClaimed = copySet(p.IndexClaimed),
		Daily = Rewards.DailyStatus(p, day),
		Quests = quests,
		-- SessionMinutes keeps its name for the client; it is minutes played today.
		Playtime = {
			SessionMinutes = math.floor(Rewards.PlaytimeMinutes(p, now)),
			Claimed = if p.Playtime.Day == day then copySet(p.Playtime.Claimed) else {},
		},
		Stats = {
			Hatched = p.Stats.Hatched,
			Broken = p.Stats.Broken,
			Expeditions = p.Stats.Expeditions,
			CoinsEarned = p.Stats.CoinsEarned,
			Crafted = p.Stats.Crafted,
		},
		Settings = settings,
		RebirthCost = if p.Rebirths >= Config.MaxRebirths then 0 else Economy.RebirthCost(p.Rebirths),
		CanBuyGemEggs = c.CanBuyGemEggs ~= false,
		CanTrade = c.CanTrade ~= false,
		ServerTime = now,
	}
end

return Profile
