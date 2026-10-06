--!strict
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory=require(Shared.Logic.Inventory)
local Config=require(Shared.Config)
local Models=require(Shared.Models)
local Service={}
local ctx:any
local riders:any={}
function Service.Uid(player:any) return riders[player] and riders[player].Uid end
function Service.Stop(player:any)
 local ride=riders[player]; if not ride then return end
 riders[player]=nil
 if ride.Model then ride.Model:Destroy() end
 if ride.Velocity then ride.Velocity:Destroy() end
 if ride.Attachment then ride.Attachment:Destroy() end
 local root=ctx.Util.Root(player); if root then root:SetNetworkOwnershipAuto() end
 local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if humanoid then humanoid.WalkSpeed=ride.WalkSpeed; humanoid.AutoRotate=true end
 player:SetAttribute("Mount",nil)
 ctx.StateService.Dirty(player)
end
function Service.Init(c:any)
 ctx=c; local U=c.Util
 U.Function("Mount",function(player:any,s:any,uid:any)
  if uid==nil or uid=="" then Service.Stop(player); return {ok=true} end
  if not U.IsStr(uid,64) then return U.Fail("Invalid creature") end
  local creature=Inventory.Find(s.Profile,uid)
  if not creature or not creature.Potions or not (creature.Potions.Ride or creature.Potions.Fly) or c.CreatureService.Busy(player,uid) then return U.Fail("Creature cannot be ridden") end
  local root=U.Root(player); local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if not root or not humanoid or humanoid.Health<=0 then return U.Fail("Character unavailable") end
  Service.Stop(player)
  local model=Models.Creature(creature.Species,creature.Element,creature.Rarity,"Adult",{Neon=creature.Neon,Cosmetics=creature.Cosmetics})
  model.Name="Mount_"..player.UserId; model.Parent=workspace
  for _,part in model:GetDescendants() do if part:IsA("BasePart") then part.CanCollide=false; part.Anchored=true end end
  root:SetNetworkOwner(nil)
  local attachment=Instance.new("Attachment"); attachment.Parent=root
  local velocity=Instance.new("LinearVelocity"); velocity.Attachment0=attachment; velocity.RelativeTo=Enum.ActuatorRelativeTo.World; velocity.MaxForce=math.huge; velocity.VectorVelocity=Vector3.zero; velocity.Enabled=false; velocity.Parent=root
  riders[player]={Uid=uid,Fly=creature.Potions.Fly,Model=model,Attachment=attachment,Velocity=velocity,Direction=Vector3.zero,Flying=false,InputAt=os.clock(),Last=root.Position,WalkSpeed=humanoid.WalkSpeed}
  humanoid.WalkSpeed=Config.Ride.WalkSpeed; player:SetAttribute("Mount",uid); c.StateService.Dirty(player); return {ok=true}
 end)
 U.Event("MountInput",function(player:any,_:any,direction:any,flying:any)
  local ride=riders[player]
  if not ride or typeof(direction)~="Vector3" or not U.IsFinite(direction.X) or not U.IsFinite(direction.Y) or not U.IsFinite(direction.Z) or not U.IsBool(flying) then return end
  ride.Direction=if direction.Magnitude>1 then direction.Unit else direction
  ride.Flying=flying and ride.Fly; ride.InputAt=os.clock()
 end)
 U.OnPlayerRemoving(Service.Stop,true)
end
function Service.Start()
 RunService.Heartbeat:Connect(function(dt:any)
  for player,ride in riders do
   local root=ctx.Util.Root(player); local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
   if not root or not humanoid or humanoid.Health<=0 then Service.Stop(player); continue end
   local direction=if os.clock()-ride.InputAt<0.5 then ride.Direction else Vector3.zero
   ride.Velocity.Enabled=ride.Flying
   if ride.Flying then
    if root.Position.Y>=Config.Ride.MaxAltitude then direction=Vector3.new(direction.X,math.min(0,direction.Y),direction.Z) end
    ride.Velocity.VectorVelocity=direction*Config.Ride.FlySpeed
   else humanoid:Move(Vector3.new(direction.X,0,direction.Z),false) end
   if (root.Position-ride.Last).Magnitude>math.max(12,Config.Ride.FlySpeed*dt*Config.Ride.SpeedTolerance) then root.CFrame=CFrame.new(ride.Last) end
   ride.Last=root.Position
   ride.Model:PivotTo(root.CFrame*CFrame.new(0,-3,0))
  end
 end)
end
return Service
