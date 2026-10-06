--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Habitat = require(Shared.Logic.Habitat)
local Inventory = require(Shared.Logic.Inventory)
local Rewards=require(Shared.Logic.Rewards)
local Economy = require(Shared.Logic.Economy)
local Tuning = require(Shared.Gameplay).Habitat
local Models=require(Shared.Models)
local Config=require(Shared.Config)
local plots:any={}
local rendered:any={}
local Service = {}
local ctx:any
local function render(player:any,s:any)
 local plot=plots[player]; if not plot then return end
 local display=rendered[player]
 if not display then display={}; rendered[player]=display end
 for i,h in s.Profile.Habitats do
  local uid=h.Creature
  if display[i] and display[i]:GetAttribute("CreatureUid")~=uid then display[i]:Destroy(); display[i]=nil end
  if uid and not display[i] then
   local creature=Inventory.Find(s.Profile,uid)
   local attachment=plot:FindFirstChild("Slot"..i,true)
   if creature and attachment and attachment:IsA("Attachment") then
    local model=Models.Creature(creature.Species,creature.Element,creature.Rarity,"Adult",{Neon=creature.Neon,Cosmetics=creature.Cosmetics})
    model:SetAttribute("CreatureUid",uid); model:SetAttribute("OwnerUserId",player.UserId)
    model:PivotTo(attachment.WorldCFrame); model.Parent=plot; display[i]=model
   end
  end
 end
end
local function settle(s:any,h:any)
 local now=os.time()
 Habitat.Accrue(h,now)
 local creature=h.Creature and Inventory.Find(s.Profile,h.Creature)
 h.BasePower=if creature then Habitat.Power(creature) else 0
 h.Power=h.BasePower
 local boosted=Economy.BoostActive(s.Profile,"Coins2x",now)
 h.RateMult=ctx.StateService.CoinMult(s)/(if boosted then Config.CoinBoostMult else 1)
 h.BoostUntil=s.Profile.Boosts.Coins2x or 0
 h.BoostMult=Config.CoinBoostMult
end
function Service.Init(c:any)
 ctx = c
 local U = c.Util
 local function slot(s:any,index:any)
  if not U.IsInt(index, 1, s.Profile.HabitatSlots) then return nil end
  return s.Profile.Habitats[tostring(index)]
 end
 U.Function("HabitatAssign", function(player:any,s:any,uid:any,index:any)
  local h = slot(s,index)
  local creature = U.IsStr(uid,64) and Inventory.Find(s.Profile,uid)
  if not h or not creature or c.CreatureService.Busy(player,uid) then return U.Fail("Choose an available creature and empty slot") end
  if not Habitat.Assign(h,creature,os.time()) then return U.Fail("Slot occupied") end
  settle(s,h)
  Inventory.Equip(s.Profile,uid,false)
  c.StateService.Dirty(player); return {ok=true}
 end)
 U.Function("HabitatRemove", function(player:any,s:any,index:any)
  local h=slot(s,index); if not h then return U.Fail("Unknown slot") end
  settle(s,h); Habitat.Remove(h,os.time()); c.StateService.Dirty(player); return {ok=true}
 end)
 U.Function("HabitatCollect", function(player:any,s:any,index:any)
  if index~=nil and not slot(s,index) then return U.Fail("Unknown slot") end
  local amount=0
  for i,h in s.Profile.Habitats do if index==nil or i==tostring(index) then settle(s,h); amount+=Habitat.Collect(h,os.time()) end end
  local granted=Economy.AddCoins(s.Profile,amount,true); Rewards.AddQuestProgress(s.Profile,"Coins",granted,os.time()); c.StateService.Dirty(player); return {ok=true,coins=amount}
 end)
 U.Function("HabitatUpgrade",function(player:any,s:any,index:any)
  local h=slot(s,index); if not h then return U.Fail("Unknown slot") end
  settle(s,h)
  local ok,cost=Habitat.Upgrade(h,s.Profile.Coins,os.time())
  if not ok then return U.Fail("Not enough coins or maximum upgrade") end
  Economy.Spend(s.Profile,"Coins",cost); c.StateService.Dirty(player); return {ok=true,cost=cost}
 end)
 U.Function("HabitatUnlock",function(player:any,s:any)
  local p=s.Profile
  if p.HabitatSlots>=Tuning.MaxSlots then return U.Fail("All slots unlocked") end
  local cost=Tuning.UpgradeCost * 2^(p.HabitatSlots-Tuning.BaseSlots+1)
  if not Economy.Spend(p,"Coins",cost) then return U.Fail("Not enough coins") end
  p.HabitatSlots+=1; p.Habitats[tostring(p.HabitatSlots)]=Habitat.New(os.time()); c.StateService.Dirty(player); return {ok=true,cost=cost}
 end)
 c.Util.OnPlayerRemoving(function(player:any)
  if plots[player] then plots[player]:SetAttribute("OwnerUserId",nil) end
  for _,model in rendered[player] or {} do model:Destroy() end
  rendered[player]=nil; plots[player]=nil
 end)
 c.DataService.OnLoaded(function(player:any,s:any)
  for _,model in workspace:GetDescendants() do
   if model:IsA("Model") and model:GetAttribute("PlotIndex") and not model:GetAttribute("OwnerUserId") then plots[player]=model; model:SetAttribute("OwnerUserId",player.UserId); break end
  end
  render(player,s)
  for _,h in s.Profile.Habitats do settle(s,h) end
  c.StateService.Dirty(player)
 end)
end
function Service.Start()
 while true do task.wait(2)
  for player,s in ctx.DataService.All() do
   if not s.TradeBusy then
    render(player,s)
    for _,h in s.Profile.Habitats do settle(s,h) end
    ctx.StateService.Dirty(player)
   end
  end
 end
end
return Service
