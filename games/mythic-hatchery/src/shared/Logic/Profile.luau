--!strict
-- Profiles: defaults for new players, sanitising of loaded (possibly old or
-- corrupted) data, and building the client's PlayerState snapshot.

local Config = require("../Config")
local Eggs = require("../Eggs")
local Species = require("../Species")
local Cosmetics = require("../Cosmetics")
local Elements = require("../Elements")
local Gameplay = require("../Gameplay")
local Habitat = require("./Habitat")
local Areas = require("../Areas")
local Products = require("../Products")
local Types = require("../Types")
local Economy = require("./Economy")
local Inventory = require("./Inventory")
local Expedition = require("./Expedition")
local Rewards = require("./Rewards")
local Schema = require("./Schema")

type Profile = Schema.Profile
type Creature = Schema.Creature

export type StateContext = {
	Now: number,
	Premium: boolean?,
	InGroup: boolean?,
	ServerLuckUntil: number?,
	CanBuyGemEggs: boolean?,
	CanTrade: boolean?,
	NoPaidLuck: boolean?,
}

local Profile = {}

Profile.MaxCreatures = 3000 -- hard cap on stored creatures (bounds the save size)
Profile.MaxExtraStorage = 10000

function Profile.Default(): Profile
	local settings: { [string]: any } = {}
	for k, v in Schema.SettingDefaults do
		settings[k] = v
	end
	local p: Profile = {
		Version = Config.Version,
		Coins = Schema.StartCoins,
		Gems = 0,
		Rebirths = 0,
		Areas = { [Schema.StartArea] = true },
		Creatures = {}, EggBag = {}, Incubators = {}, Habitats = {}, HabitatSlots = Gameplay.Habitat.BaseSlots, ArenaPoints = 0, StarterGranted = false,
 Cosmetics = {}, HatchSlots = Config.BaseHatchSlots, BattleTeam = {}, BattleClaims = {}, BattleOpponents = {},
		NextUid = 0,
		Equipped = {},
		Expeditions = {},
		Passes = {},
		Boosts = {},
		Index = {},
		IndexClaimed = {},
		Daily = { Streak = 0, LastDay = -1 },
		Quests = { Day = -1, List = {} },
		Stats = { Hatched = 0, Broken = 0, Expeditions = 0, CoinsEarned = 0, Fused = 0, Battles = 0, BattleWins = 0 },
		Settings = settings,
		ExtraEquip = 0,
		ExtraStorage = 0,
		Receipts = {},
		Playtime = { Day = -1, Minutes = 0, Claimed = {} },
		ExpeditionMult = {},
		PendingTrade = nil,
		AppliedTrades = {},
	}
 for i=1,p.HabitatSlots do p.Habitats[tostring(i)]={Level=1,Creature=nil,Power=0,Coins=0,UpdatedAt=0} end
 Profile.GrantStarter(p)
 return p
end

local function tbl(v: any): { [any]: any }
	return if type(v) == "table" then v else {}
end

function Profile.GrantStarter(p: Profile): boolean
 if p.StarterGranted then return false end
 local creature = Inventory.Make(p, { Species="Dragon", Rarity="Common", Element="Nature", Level=1, Potions={Ride=true,Fly=true} })
 assert(creature)
 table.insert(p.Creatures, creature); p.Index["Dragon|Nature"]=true; p.StarterGranted=true
 return true
end

local function sanitizeCreatures(p: Profile, raw: any)
 p.Creatures = {}
 local seen: { [string]: boolean } = {}
 for _, r in tbl(raw) do
  if #p.Creatures >= Profile.MaxCreatures then break end
  if type(r) ~= "table" then continue end
  local c = Inventory.Make(p, r)
  if not c then continue end
  if type(r.Uid)=="string" and #r.Uid>0 and #r.Uid<=Schema.MaxUidLength and not seen[r.Uid] then
   c.Uid=r.Uid
   local n=tonumber(r.Uid); if n and Schema.IsFinite(n) then p.NextUid=math.max(p.NextUid, math.min(math.floor(n),1e15)) end
  end
  seen[c.Uid]=true; c.Locked=r.Locked==true
  for slot,id in tbl(r.Cosmetics) do
   if type(slot)=="string" and type(id)=="string" and p.Cosmetics[id] and Cosmetics.ById[id] and Cosmetics.ById[id].Slot==slot then c.Cosmetics[slot]=id end
  end
  if type(r.Name)=="string" and #r.Name<=48 then c.Name=r.Name end
  table.insert(p.Creatures,c); p.Index[c.Species .. "|" .. c.Element]=true
 end
end

local function sanitizeExpeditions(p: Profile, raw: any)
	local maxSlots = Config.BaseExpeditionSlots + 2
	local used: { [string]: boolean } = {}
	p.Expeditions = {}
	local src = tbl(raw)
	-- Slots in order, so a creature listed twice always stays with the lower slot.
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
		local creatures: { string } = {}
		for _, uid in tbl(e.Creatures) do
			if #creatures >= Config.MaxPetsPerExpedition then
				break
			end
			if type(uid) == "string" and not used[uid] and Inventory.Find(p, uid) then
				used[uid] = true
				table.insert(creatures, uid)
			end
		end
		if #creatures == 0 then
			continue
		end
		p.Expeditions[tostring(slot)] = {
			Area = e.Area,
			Duration = e.Duration,
			Creatures = creatures,
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
 local active: {[string]: boolean} = {}
 for _,def in Config.QuestPool do active[def.Kind]=true end
	for _, r in tbl(q.List) do
		if type(r) ~= "table" or type(r.Kind) ~= "string" or not active[r.Kind] or not Schema.IsFinite(r.Goal) or r.Goal < 1 then
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
 for id,v in tbl(raw.Index) do
  if v==true and type(id)=="string" then
   local species,element=string.match(id,"^([^|]+)|([^|]+)$")
   if species and element and Species.ById[species] and Elements.ById[element] then p.Index[id]=true end
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
	for id,owned in tbl(raw.Cosmetics) do if owned==true and type(id)=="string" and Cosmetics.ById[id] then p.Cosmetics[id]=true end end
 sanitizeCreatures(p, raw.Creatures)
	sanitizeExpeditions(p, raw.Expeditions)
 p.StarterGranted = raw.StarterGranted == true
 Profile.GrantStarter(p)
 p.HabitatSlots = Schema.ClampInt(raw.HabitatSlots or Gameplay.Habitat.BaseSlots, Gameplay.Habitat.BaseSlots, Gameplay.Habitat.MaxSlots)
 p.ArenaPoints = Schema.ClampInt(raw.ArenaPoints, 0, Schema.MaxStat)
 local assigned = Inventory.BusySet(p)
 for i=1,p.HabitatSlots do
  local key=tostring(i); local r=tbl(tbl(raw.Habitats)[key]); local slot: Types.HabitatSlot={Level=1,Creature=nil,Power=0,Coins=0,UpdatedAt=0}
  slot.Level=Schema.ClampInt(r.Level or 1,1,Gameplay.Habitat.MaxUpgrade)
  slot.UpdatedAt=Schema.ClampInt(r.UpdatedAt,0,1e15)
  slot.Coins=if Schema.IsFinite(r.Coins) then math.clamp(r.Coins,0,Habitat.Capacity(slot)) else 0
  if type(r.Creature)=="string" and not assigned[r.Creature] then
   local c=Inventory.Find(p,r.Creature)
   if c then
    slot.Creature=c.Uid; slot.Power=Habitat.Power(c); slot.BasePower=slot.Power
    slot.RateMult=if Schema.IsFinite(r.RateMult) and r.RateMult>0 then math.clamp(r.RateMult,1,100) else 1
    slot.BoostMult=if Schema.IsFinite(r.BoostMult) and r.BoostMult>0 then math.clamp(r.BoostMult,1,2) else 1
    slot.BoostUntil=Schema.ClampInt(r.BoostUntil,0,1e15)
    slot.Power=slot.BasePower or 1
    assigned[c.Uid]=true
   end
  end
  p.Habitats[key]=slot
 end
 local eggUids: {[string]: boolean} = {}
 local function egg(r: any): Types.EggItem?
  if type(r)~="table" or type(r.Egg)~="string" or not Eggs.ById[r.Egg]  then return nil end
  if type(r.Uid)~="string" or #r.Uid==0 or #r.Uid>Schema.MaxUidLength or eggUids[r.Uid] then return nil end
  local fused: Types.EggItem = {Uid=r.Uid,Egg=r.Egg,Tier=Schema.ClampInt(r.Tier or 1,1,6)}
  if r.Egg=="FusedEgg" then
   if type(r.Fused)~="table" then return nil end
   local function weights(rawWeights: any, valid: (string)->boolean): {{Id:string,Weight:number}}?
    if type(rawWeights)~="table" or #rawWeights<1 or #rawWeights>20 then return nil end
    local out: {{Id:string,Weight:number}}={}; local sum=0
    for _,w in rawWeights do
     if type(w)~="table" or type(w.Id)~="string" or not valid(w.Id) or not Schema.IsFinite(w.Weight) or w.Weight<0 or w.Weight>1e6 then return nil end
     sum+=w.Weight; table.insert(out,{Id=w.Id,Weight=w.Weight})
    end
    return if sum>0 then out else nil
   end
   local f=r.Fused
   local rarity=weights(f.Rarity,function(id) return table.find(Config.Rarities,id)~=nil end)
   local species=weights(f.Species,function(id) return Species.ById[id]~=nil end)
   local element=weights(f.Element,function(id) return Elements.ById[id]~=nil end)
   if not rarity or not species or not element then return nil end
   local hybrid=if type(f.Hybrid)=="string" and Species.ById[f.Hybrid] and Species.ById[f.Hybrid].Hybrid then f.Hybrid else nil
   fused.Fused={Rarity=rarity,Species=species,Element=element,Hybrid=hybrid,HybridChance=if hybrid and Schema.IsFinite(f.HybridChance) then math.clamp(f.HybridChance,0,1) else 0}
  end
  eggUids[r.Uid]=true
  return fused
 end
 for _,r in tbl(raw.EggBag) do if #p.EggBag>=300 then break end; local e=egg(r); if e then table.insert(p.EggBag,e) end end
 p.HatchSlots=Economy.HatchSlots(p)
 -- Preserve occupied purchased slots even before a pass refresh completes.
 for i=1,Config.BaseHatchSlots + Config.PassHatchSlots do
  local r=tbl(tbl(raw.Incubators)[tostring(i)]); local e=egg(r.Egg)
  if e and Schema.IsFinite(r.StartAt) and Schema.IsFinite(r.EndAt) and r.EndAt>=r.StartAt then
   p.Incubators[tostring(i)]={Egg=e,StartAt=math.floor(r.StartAt),EndAt=math.floor(r.EndAt),Seed=Schema.ClampInt(r.Seed,1,2147483646),Luck=if Schema.IsFinite(r.Luck) then math.clamp(r.Luck,1,Config.MaxLuckMult) else 1}
  end
 end
 for _,uid in tbl(raw.BattleTeam) do if #p.BattleTeam>=3 then break end; if type(uid)=="string" and Inventory.Find(p,uid) and not table.find(p.BattleTeam,uid) then table.insert(p.BattleTeam,uid) end end
 local claims: {{Id:string,At:number}}={}
 for id,at in tbl(raw.BattleClaims) do if type(id)=="string" and #id<=128 and Schema.IsFinite(at) then table.insert(claims,{Id=id,At=at}) end end
 table.sort(claims,function(a: {Id:string,At:number},b: {Id:string,At:number}) return a.At>b.At end)
 for i=1,math.min(100,#claims) do p.BattleClaims[claims[i].Id]=claims[i].At end
 local count=0
 for id,r in tbl(raw.BattleOpponents) do if count>=100 then break end; if type(id)=="string" and #id<=24 and type(r)=="table" then p.BattleOpponents[id]={Count=Schema.ClampInt(r.Count,0,1e6),WindowAt=Schema.ClampInt(r.WindowAt,0,1e15)}; count+=1 end end

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
	table.sort(list, function(a: {Id:string,At:number}, b: {Id:string,At:number})
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

function Profile.CopyCreature(c: Creature): Creature
 local out = table.clone(c)
 out.Potions=table.clone(c.Potions); out.Neon=c.Potions.Neon==true; out.Cosmetics=table.clone(c.Cosmetics)
 return out
end
Profile.CopyPet = Profile.CopyCreature

local function copyEgg(e: Types.EggItem): Types.EggItem
 local out=table.clone(e)
 if e.Fused then
  local f=e.Fused
  local function weights(list: {{Id:string,Weight:number}}): {{Id:string,Weight:number}}
   local out: {{Id:string,Weight:number}}={}; for _,w in list do table.insert(out,table.clone(w)) end; return out
  end
  out.Fused={Species=weights(f.Species),Rarity=weights(f.Rarity),Element=weights(f.Element),Hybrid=f.Hybrid,HybridChance=f.HybridChance}
 end
 return out
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
	local mult: Economy.MultContext = { Now = now, Premium = c.Premium, InGroup = c.InGroup, ServerLuckUntil = c.ServerLuckUntil, NoPaidLuck = c.NoPaidLuck }
	local day = Rewards.DayNumber(now)
	local creatures: { Creature } = {}
	for _, creature in p.Creatures do
		table.insert(creatures, Profile.CopyPet(creature))
	end
	local exps: { [string]: Types.Expedition } = {}
	for key, e in p.Expeditions do
		exps[key] = {
			Area = e.Area,
			Duration = e.Duration,
			Creatures = table.clone(e.Creatures),
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
	local state: Types.PlayerState = {
		Coins = p.Coins,
		Gems = p.Gems,
		Rebirths = p.Rebirths,
		CoinMult = Economy.CoinMult(p, mult),
		LuckMult = Economy.LuckMult(p, mult),
		Areas = copySet(p.Areas),
		Creatures = creatures,
 EggBag = table.clone(p.EggBag), Incubators = {}, HatchSlots=Economy.HatchSlots(p), Cosmetics=copySet(p.Cosmetics),
 Habitats = {}, HabitatSlots=p.HabitatSlots, ArenaPoints=p.ArenaPoints, BattleTeam=table.clone(p.BattleTeam),
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
			Fused = p.Stats.Fused,
 Battles = p.Stats.Battles, BattleWins = p.Stats.BattleWins,
		},
		Settings = settings,
		RebirthCost = if p.Rebirths >= Config.MaxRebirths then 0 else Economy.RebirthCost(p.Rebirths),
		CanBuyGemEggs = c.CanBuyGemEggs ~= false,
		CanTrade = c.CanTrade ~= false,
		ServerTime = now,
	}
 for key,slot in p.Habitats do state.Habitats[key]=table.clone(slot) end
 for key,inc in p.Incubators do state.Incubators[key]={Egg=copyEgg(inc.Egg),StartAt=inc.StartAt,EndAt=inc.EndAt,Seed=0,Luck=inc.Luck} end
 for i,e in p.EggBag do state.EggBag[i]=copyEgg(e) end
 return state
end

return Profile
