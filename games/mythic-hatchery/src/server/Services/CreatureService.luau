--!strict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory=require(Shared.Logic.Inventory)
local Rewards=require(Shared.Logic.Rewards)
local Economy=require(Shared.Logic.Economy)
local Fusion=require(Shared.Logic.Fusion)
local Potions=require(Shared.Potions)
local Cosmetics=require(Shared.Cosmetics)
local Config=require(Shared.Config)
local Service={}
local ctx:any
function Service.Busy(player:any,uid:any,ignoreBattle:any)
 local s=ctx.DataService.Get(player); if not s then return true end
 if s.Profile.PendingTrade or s.TradeBusy then return true end
 for _,h in s.Profile.Habitats do if h.Creature==uid then return true end end
 if Inventory.IsBusy(s.Profile,uid) or ctx.TradeService.OfferedSet(player)[uid] then return true end
 if ctx.RideService and ctx.RideService.Uid(player)==uid then return true end
 return not ignoreBattle and ctx.BattleService and ctx.BattleService.IsBusy(player,uid) or false
end
function Service.Init(c:any)
 ctx=c; local U=c.Util
 local function creature(s:any,uid:any) return U.IsStr(uid,64) and Inventory.Find(s.Profile,uid) end
 U.Function("EquipCreature",function(player:any,s:any,uid:any,equip:any)
  if not creature(s,uid) or not U.IsBool(equip) or equip and Service.Busy(player,uid) then return U.Fail("Unavailable creature") end
  local ok,err=Inventory.Equip(s.Profile,uid,equip); if not ok then return U.Fail(err) end
  c.StateService.Dirty(player); return {ok=true}
 end)
 U.Function("EquipBest",function(player:any,s:any)
  Inventory.UnequipAll(s.Profile)
  local list=table.clone(s.Profile.Creatures)
  local Level=require(Shared.Logic.Level)
  table.sort(list,function(a:any,b:any) return Level.Power(a)>Level.Power(b) end)
  for _,v in list do if not Service.Busy(player,v.Uid) then Inventory.Equip(s.Profile,v.Uid,true) end end
  c.StateService.Dirty(player); return {ok=true}
 end)
 U.Function("UnequipAll",function(player:any,s:any) Inventory.UnequipAll(s.Profile); c.StateService.Dirty(player); return {ok=true} end)
 U.Function("LockCreature",function(player:any,s:any,uid:any,locked:any)
  if not creature(s,uid) or not U.IsBool(locked) or Service.Busy(player,uid) then return U.Fail("Unavailable creature") end
  Inventory.Lock(s.Profile,uid,locked); c.StateService.Dirty(player); return {ok=true}
 end)
 U.Function("ReleaseCreatures",function(player:any,s:any,uids:any)
  if type(uids)~="table" or #uids<1 or #uids>60 then return U.Fail("Invalid selection") end
  for _,uid in uids do if not creature(s,uid) or Service.Busy(player,uid) then return U.Fail("Unavailable creature") end end
  local coins,err=Inventory.Delete(s.Profile,uids,c.TradeService.OfferedSet(player)); if not coins then return U.Fail(err) end
  c.StateService.Dirty(player); return {ok=true,coins=coins}
 end)
 U.Function("Fuse",function(player:any,s:any,a:any,b:any)
  local ca,cb=creature(s,a),creature(s,b)
  if not ca or not cb then return U.Fail("Choose two creatures") end
  local busy={}; for _,v in s.Profile.Creatures do if Service.Busy(player,v.Uid) then busy[v.Uid]=true end end
  local uid=game:GetService("HttpService"):GenerateGUID(false)
  local plan,err=Fusion.Prepare(ca,cb,uid,busy,s.Profile.Coins,1,Config.EggStorage-#s.Profile.EggBag)
  if not plan then return U.Fail(err) end
  Economy.Spend(s.Profile,"Coins",plan.Cost); Inventory.RemoveUnchecked(s.Profile,plan.Consume); table.insert(s.Profile.EggBag,plan.Egg)
  s.Profile.Stats.Fused=(s.Profile.Stats.Fused or 0)+1; Rewards.AddQuestProgress(s.Profile,"Fuse",1,os.time())
  c.StateService.Dirty(player); return {ok=true,egg=plan.Egg}
 end)
 U.Function("UsePotion",function(player:any,s:any,uid:any,id:any)
  local v=creature(s,uid); local potion=U.IsStr(id,32) and Potions.ById[id]
  if not v or not potion or Service.Busy(player,uid) then return U.Fail("Unavailable creature or potion") end
  v.Potions=v.Potions or {}
  if v.Potions[id] then return U.Fail("Already applied") end
  if not Economy.Spend(s.Profile,"Gems",potion.Gems) then return U.Fail("Not enough gems") end
  v.Potions[id]=true; if id=="Neon" then v.Neon=true end
  c.StateService.Dirty(player); return {ok=true}
 end)
 U.Function("BuyCosmetic",function(player:any,s:any,id:any)
  local cosmetic=U.IsStr(id,32) and Cosmetics.ById[id]; if not cosmetic then return U.Fail("Unknown cosmetic") end
  s.Profile.Cosmetics=s.Profile.Cosmetics or {}
  if s.Profile.Cosmetics[id] then return {ok=true} end
  if not Economy.Spend(s.Profile,"Coins",cosmetic.Coins) then return U.Fail("Not enough coins") end
  s.Profile.Cosmetics[id]=true; c.StateService.Dirty(player); return {ok=true}
 end)
 U.Function("WearCosmetic",function(player:any,s:any,uid:any,slot:any,id:any)
  local v=creature(s,uid)
  if not v or not table.find(Cosmetics.Slots,slot) or type(id)~="string" or Service.Busy(player,uid) then return U.Fail("Invalid cosmetic request") end
  if id~="" and (not Cosmetics.ById[id] or Cosmetics.ById[id].Slot~=slot or not s.Profile.Cosmetics[id]) then return U.Fail("Buy that cosmetic first") end
  v.Cosmetics=v.Cosmetics or {}; v.Cosmetics[slot]=if id=="" then nil else id
  c.StateService.Dirty(player); return {ok=true}
 end)
 U.Function("RenameCreature",function(player:any,s:any,uid:any,name:any)
  local v=creature(s,uid); if not v or not U.IsStr(name,24) or Service.Busy(player,uid) then return U.Fail("Invalid name or creature") end
  local ok,result=pcall(function() return game:GetService("TextService"):FilterStringAsync(name,player.UserId):GetNonChatStringForBroadcastAsync() end)
  if not ok then return U.Fail("Name filtering unavailable") end
  if not creature(s,uid) or Service.Busy(player,uid) then return U.Fail("Creature became unavailable") end
  v.Name=result; c.StateService.Dirty(player); return {ok=true,name=result}
 end)
end
return Service
