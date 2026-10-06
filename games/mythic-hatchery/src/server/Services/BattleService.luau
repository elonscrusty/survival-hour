--!strict
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Battle=require(Shared.Logic.Battle)
local Level=require(Shared.Logic.Level)
local Inventory=require(Shared.Logic.Inventory)
local Economy=require(Shared.Logic.Economy)
local Net=require(Shared.Net)
local Rewards=require(Shared.Logic.Rewards)
local Service={}
local ctx:any
local queue:any={}
local matches:any={}
local rewarded:any={}
local pairsLog:any={}
local Models=require(Shared.Models)
local visual:any={}
local arenaSlots:any={}
local function push(b:any)
 local models=visual[b.Id] or {}; visual[b.Id]=models
 for i,side in b.Sides do
  local active=side.Fighters[side.Active]
  if models[i] and models[i]:GetAttribute("CreatureUid")~=active.Creature.Uid then models[i]:Destroy(); models[i]=nil end
  if not models[i] and b.Status=="Running" then
   local v=active.Creature
   local model=Models.Creature(v.Species,v.Element,v.Rarity,"Adult",{Neon=v.Neon})
   model:SetAttribute("CreatureUid",v.Uid); model:SetAttribute("OwnerUserId",side.UserId)
   local slot=arenaSlots[b.Id] or 1
   local center=ctx.WorldService.Info.Arena.Center+Vector3.new(0,0,(slot-1)*30)
   model:PivotTo(CFrame.new(center+Vector3.new(if i==1 then -10 else 10,3,0),center+Vector3.new(0,3,0)))
   model.Parent=workspace; models[i]=model
  end
 end
 b.VisualCenter=ctx.WorldService.Info.Arena.Center+Vector3.new(0,0,((arenaSlots[b.Id] or 1)-1)*30)
 b.ServerTime=os.clock()
 for _,side in b.Sides do local p=Players:GetPlayerByUserId(side.UserId); if p then Net.Event("Battle"):FireClient(p,b) end end
end
local function team(player:any,s:any): {any}?
 local list={}
 for _,uid in s.Profile.BattleTeam or {} do
  local c=Inventory.Find(s.Profile,uid)
  if not c or ctx.CreatureService.Busy(player,uid,true) then return nil end
  table.insert(list,c)
 end
 return if #list==3 then list else nil
end
function Service.IsOccupied(player:any) return matches[player]~=nil or queue[player]~=nil end
function Service.IsBusy(player:any,uid:any)
 local b=matches[player]
 if b then for _,side in b.Sides do if side.UserId==player.UserId then for _,f in side.Fighters do if f.Creature.Uid==uid then return true end end end end end
 return queue[player]~=nil and table.find(queue[player].Uids,uid)~=nil
end
local function finish(b:any)
 if rewarded[b.Id] then return end
 rewarded[b.Id]=true
 local key=tostring(math.min(b.Sides[1].UserId,b.Sides[2].UserId))..":"..tostring(math.max(b.Sides[1].UserId,b.Sides[2].UserId))
 local now=os.time(); local log=pairsLog[key] or {}; pairsLog[key]=log
 for i=#log,1,-1 do if now-log[i]>600 then table.remove(log,i) end end
 local allowed=#log<3; table.insert(log,now)
 for _,side in b.Sides do
  local p=Players:GetPlayerByUserId(side.UserId); local s=p and ctx.DataService.Get(p)
  if s then
   local reward=Battle.Reward(b,side.UserId)
   local participation=0; for _,f in side.Fighters do participation+=f.Contribution end
   s.Profile.BattleClaims=s.Profile.BattleClaims or {}
   s.Profile.BattleOpponents=s.Profile.BattleOpponents or {}
   local opponent=tostring(b.Sides[if b.Sides[1].UserId==side.UserId then 2 else 1].UserId)
   local history=s.Profile.BattleOpponents[opponent]
   if not history or now-history.WindowAt>=600 then history={Count=0,WindowAt=now}; s.Profile.BattleOpponents[opponent]=history end
   history.Count+=1
   if reward and not s.Profile.BattleClaims[b.Id] then
    s.Profile.BattleClaims[b.Id]=now
    if reward.Points<0 then s.Profile.ArenaPoints=math.max(0,s.Profile.ArenaPoints+reward.Points) end
    if allowed and history.Count<=3 and participation>0 and now-(s.LastBattleReward or 0)>=15 then
     s.LastBattleReward=now
     local coins=Economy.AddCoins(s.Profile,reward.Coins,true)
     s.Profile.Stats.Battles=(s.Profile.Stats.Battles or 0)+1
     Rewards.AddQuestProgress(s.Profile,"Battle",1,now)
     Rewards.AddQuestProgress(s.Profile,"Coins",coins,now)
     if reward.Points>0 then s.Profile.ArenaPoints+=reward.Points; s.Profile.Stats.BattleWins=(s.Profile.Stats.BattleWins or 0)+1 end
     for uid,xp in reward.Xp do local c=Inventory.Find(s.Profile,uid); if c then Level.AddXp(c,xp*(if Economy.BoostActive(s.Profile,"Growth2x",now) then 2 else 1)) end end
    end
    ctx.StateService.Dirty(p)
   end
  end
  if p then matches[p]=nil end
 end
 push(b)
 task.delay(4,function()
  for _,model in visual[b.Id] or {} do model:Destroy() end; visual[b.Id]=nil; rewarded[b.Id]=nil; arenaSlots[b.Id]=nil
  for _,side in b.Sides do local p=Players:GetPlayerByUserId(side.UserId); if p and not matches[p] and not queue[p] then Net.Event("Battle"):FireClient(p,nil) end end end)
end
function Service.Init(c:any)
 ctx=c; local U=c.Util
 U.Function("SetBattleTeam",function(player:any,s:any,uids:any)
  if matches[player] or queue[player] or type(uids)~="table" or #uids~=3 then return U.Fail("Choose three available creatures outside a battle") end
  local seen={}
  for _,uid in uids do if not U.IsStr(uid,64) or seen[uid] or not Inventory.Find(s.Profile,uid) or c.CreatureService.Busy(player,uid) then return U.Fail("Unavailable or duplicate creature") end; seen[uid]=true end
  s.Profile.BattleTeam=table.clone(uids); c.StateService.Dirty(player); return {ok=true}
 end)
 U.Function("BattleJoin",function(player:any,s:any)
  if matches[player] or queue[player] or s.Profile.PendingTrade or c.TradeService.InTrade(player) then return U.Fail("Already occupied") end
  local t=team(player,s); if not t then return U.Fail("Choose three available creatures") end
  queue[player]={Team=t,Uids=table.clone(s.Profile.BattleTeam)}
  Net.Event("Battle"):FireClient(player,{Status="Queued",ServerTime=os.clock()}); return {ok=true}
 end)
 U.Function("BattleLeave",function(player:any)
  queue[player]=nil; local b=matches[player]
  if b then Battle.Forfeit(b,player.UserId,os.clock()); finish(b) else Net.Event("Battle"):FireClient(player,nil) end
  return {ok=true}
 end)
 U.Function("BattleMove",function(player:any,_:any,move:any)
  local b=matches[player]; if not b or not U.IsStr(move,64) then return U.Fail("No battle or invalid move") end
  local ok,err=Battle.Move(b,player.UserId,move,os.clock()); if not ok then return U.Fail(err) end
  if b.Status=="Done" then finish(b) else push(b) end; return {ok=true}
 end)
 U.Function("BattleSwap",function(player:any,_:any,index:any)
  local b=matches[player]; if not b or not U.IsInt(index,1,3) then return U.Fail("No battle or invalid swap") end
  local ok,err=Battle.Swap(b,player.UserId,index,os.clock()); if not ok then return U.Fail(err) end
  push(b); return {ok=true}
 end)
 U.OnPlayerRemoving(function(player:any)
  queue[player]=nil; local b=matches[player]; if b then Battle.Forfeit(b,player.UserId,os.clock()); finish(b) end
 end,true)
end
function Service.Start()
 while true do task.wait(0.5)
  for a,qa in queue do
   local sa=ctx.DataService.Get(a)
   if not sa or sa.TradeBusy or not team(a,sa) then queue[a]=nil; continue end
   for b,qb in queue do
    if a~=b and Battle.CanMatch(qa.Team,qb.Team) then
     local sb=ctx.DataService.Get(b)
     if not sb or sb.TradeBusy or not team(b,sb) then queue[b]=nil; continue end
     local occupied={}
     for _,slot in arenaSlots do occupied[slot]=true end
     local free=1; while occupied[free] do free+=1 end
     local match=Battle.New(game:GetService("HttpService"):GenerateGUID(false),a.UserId,b.UserId,qa.Team,qb.Team,os.clock())
     arenaSlots[match.Id]=free
     queue[a]=nil; queue[b]=nil; matches[a]=match; matches[b]=match; push(match); break
    end
   end
  end
  local seen={}
  for _,b in matches do if not seen[b] then seen[b]=true; if Battle.Timeout(b,os.clock()) then finish(b) else push(b) end end end
 end
end
return Service
