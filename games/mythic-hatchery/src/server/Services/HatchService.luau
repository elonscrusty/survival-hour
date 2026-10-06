--!strict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Eggs=require(Shared.Eggs)
local Areas=require(Shared.Areas)
local Config=require(Shared.Config)
local Rewards=require(Shared.Logic.Rewards)
local Economy=require(Shared.Logic.Economy)
local Inventory=require(Shared.Logic.Inventory)
local Incubation=require(Shared.Logic.Incubation)
local Service={}
local random=Random.new()
function Service.Init(c:any)
 local U=c.Util
 local function get(s:any,index:any)
  return U.IsInt(index,1,Config.BaseHatchSlots+Config.PassHatchSlots) and s.Profile.Incubators[tostring(index)]
 end
 U.Function("BuyEgg",function(player:any,s:any,id:any,count:any)
  local egg=U.IsStr(id,32) and Eggs.ById[id]; count=count or 1
  if not egg or not U.IsInt(count,1,3) or not Eggs.OnSale(egg,os.time()) then return U.Fail("Egg unavailable") end
  if not s.Profile.Areas[egg.Area] then return U.Fail("Open that region first") end
  if egg.Currency=="Gems" and not s.CanBuyGemEggs then return U.Fail("Paid random items unavailable for your account") end
  if #s.Profile.EggBag+count>Config.EggStorage then return U.Fail("Egg bag full") end
  if os.clock()-(s.LastEggBuy or -10)<Config.BuyCooldown then return U.Fail("Slow down") end
  local position=c.WorldService.TaggedPosition("EggStand","EggId",id)
  if position and U.DistTo(player,position)>45 then return U.Fail("Walk to the egg stand") end
  if not Economy.Spend(s.Profile,egg.Currency,egg.Cost*count) then return U.Fail("Not enough currency") end
  s.LastEggBuy=os.clock(); local result={}
  for _=1,count do
   local item={Uid=game:GetService("HttpService"):GenerateGUID(false),Egg=id,Tier=Areas.ById[egg.Area].Index}
   table.insert(s.Profile.EggBag,item); table.insert(result,item)
  end
  c.StateService.Dirty(player); return {ok=true,eggs=result}
 end)
 U.Function("Incubate",function(player:any,s:any,uid:any,index:any)
  if not U.IsStr(uid,64) then return U.Fail("Unknown egg") end
  local p=s.Profile; local max=Config.BaseHatchSlots+(if Economy.HasPass(p,"HatchSlots") then Config.PassHatchSlots else 0)
  if index==nil then for i=1,max do if not p.Incubators[tostring(i)] then index=i; break end end end
  if not U.IsInt(index,1,max) or p.Incubators[tostring(index)] then return U.Fail("No free incubator") end
  local found
  for i,item in p.EggBag do if item.Uid==uid then found=i; break end end
  if not found then return U.Fail("Unknown egg") end
  local item=p.EggBag[found]; local egg=Eggs.ById[item.Egg]
  if egg.Currency=="Gems" and not s.CanBuyGemEggs then return U.Fail("Paid random items unavailable") end
  p.Incubators[tostring(index)]=Incubation.New(item,os.time(),random:NextInteger(1,2147483646),c.StateService.LuckMult(s),Economy.HasPass(p,"FastIncubation"))
  table.remove(p.EggBag,found); c.StateService.Dirty(player); return {ok=true,slot=index}
 end)
 U.Function("SkipIncubation",function(player:any,s:any,index:any)
  local inc=get(s,index); if not inc then return U.Fail("Empty incubator") end
  local remaining=inc.EndAt-os.time(); if remaining<=0 then return {ok=true,gems=0} end
  local cost=math.max(Config.IncubateSkipMinGems,math.ceil(remaining/30)*Config.IncubateSkipGemsPer30s)
  if not Economy.Spend(s.Profile,"Gems",cost) then return U.Fail("Not enough gems") end
  inc.EndAt=os.time(); c.StateService.Dirty(player); return {ok=true,gems=cost}
 end)
 U.Function("Hatch",function(player:any,s:any,index:any)
  local inc=get(s,index); if not inc or os.time()<inc.EndAt then return U.Fail("Egg is still incubating") end
  if Inventory.FreeSpace(s.Profile)<1 then return U.Fail("Creature storage full") end
  local egg=Eggs.ById[inc.Egg.Egg]
  if egg.Currency=="Gems" and not s.CanBuyGemEggs then return U.Fail("Paid random items unavailable") end
  local result,rollErr=Incubation.Roll(inc,os.time())
  if not result then return U.Fail(rollErr or "Unable to hatch") end
  local spec={Species=result.Species,Rarity=result.Rarity,Element=result.Element,Tier=inc.Egg.Tier,Level=1,Xp=0,Edition=egg.Edition,HatchedAt=os.time()}
  local creature,discovered,err=Inventory.Add(s.Profile,spec)
  if not creature then return U.Fail(err or "Unable to hatch") end
  s.Profile.Incubators[tostring(index)]=nil; s.Profile.Stats.Hatched+=1
  Rewards.AddQuestProgress(s.Profile,"Hatch",1,os.time())
  c.StateService.Dirty(player); return {ok=true,creature=creature,new=discovered}
 end)
end
return Service
