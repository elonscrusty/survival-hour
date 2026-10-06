--!strict
-- Replicated equipped creature visuals. One model per uid, rebuilt only when
-- its appearance changes. All gameplay and ownership stays on the server.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Models=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Models"))
local Followers={}
type Visual={Model: Model,Key: string,CFrame: CFrame?}
type Owner={Connections: {RBXScriptConnection},Visuals: {[string]: Visual},Order: {string}}
local owners: {[Player]: Owner}={}
local connections: {RBXScriptConnection}={}
local folder: Folder?=nil
local function remove(player: Player)
 local owner=owners[player]; if not owner then return end
 for _,conn in owner.Connections do conn:Disconnect() end
 for _,visual in owner.Visuals do visual.Model:Destroy() end
 owners[player]=nil
end
local function rebuild(player: Player)
 local owner=owners[player]; if not owner then return end
 local raw=player:GetAttribute("Creatures")
 local ok,list=pcall(function() return HttpService:JSONDecode(if type(raw)=="string" then raw else "[]") end)
 if not ok or type(list)~="table" then return end
 local keep: {[string]: boolean}={}; owner.Order={}
 for _,c in list do
  if type(c)~="table" or type(c.Uid)~="string" or c.Uid==player:GetAttribute("Mount") then continue end
  local key=HttpService:JSONEncode({c.Species,c.Element,c.Rarity,c.Neon,c.Cosmetics})
  keep[c.Uid]=true; table.insert(owner.Order,c.Uid)
  local old=owner.Visuals[c.Uid]
  if old and old.Key~=key then old.Model:Destroy(); owner.Visuals[c.Uid]=nil end
  if not owner.Visuals[c.Uid] then
   local created,model=pcall(Models.Creature,c.Species,c.Element,c.Rarity,"Adult",{Neon=c.Neon,Cosmetics=c.Cosmetics})
   if created then
    for _,part in model:GetDescendants() do if part:IsA("BasePart") then part.CanCollide=false; part.CanTouch=false; part.CanQuery=false; part.Anchored=true end end
    model.Name="Companion_"..c.Uid
    owner.Visuals[c.Uid]={Model=model,Key=key,CFrame=nil}
   end
  end
 end
 for uid,v in owner.Visuals do if not keep[uid] then v.Model:Destroy(); owner.Visuals[uid]=nil end end
end
local function add(player: Player)
 remove(player)
 local owner: Owner={Connections={},Visuals={},Order={}}; owners[player]=owner
 table.insert(owner.Connections,player:GetAttributeChangedSignal("Creatures"):Connect(function() rebuild(player) end))
 table.insert(owner.Connections,player:GetAttributeChangedSignal("Mount"):Connect(function() rebuild(player) end))
 rebuild(player)
end
function Followers.Destroy()
 for _,conn in connections do conn:Disconnect() end; table.clear(connections)
 local players={}; for player in owners do table.insert(players,player) end
 for _,player in players do remove(player) end
 if folder then folder:Destroy(); folder=nil end
end
function Followers.Init()
 Followers.Destroy()
 local newFolder=Instance.new("Folder"); newFolder.Name="CreatureCompanions"; newFolder.Parent=workspace; folder=newFolder
 for _,player in Players:GetPlayers() do add(player) end
 table.insert(connections,Players.PlayerAdded:Connect(add))
 table.insert(connections,Players.PlayerRemoving:Connect(remove))
 table.insert(connections,RunService.RenderStepped:Connect(function(dt: number)
  for player,owner in owners do
   local char=player.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
   for index,uid in owner.Order do
    local v=owner.Visuals[uid]; if not v then continue end
    if root and root:IsA("BasePart") then
     local target=root.CFrame*CFrame.new(((index-1)%3-1)*5,-2,6+math.floor((index-1)/3)*6)
     v.CFrame=if v.CFrame then v.CFrame:Lerp(target,math.min(1,dt*9)) else target
     v.Model:PivotTo(v.CFrame :: CFrame); v.Model.Parent=folder
    else v.Model.Parent=nil; v.CFrame=nil end
   end
  end
 end))
end
return Followers
