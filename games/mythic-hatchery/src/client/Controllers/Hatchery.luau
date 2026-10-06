--!strict
-- A touch-first client. UI predictions are display-only; the server owns all mutations.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Eggs = require(Shared:WaitForChild("Eggs"))
local Hatch = require(Shared:WaitForChild("Logic"):WaitForChild("Hatch"))
local Habitat = require(Shared:WaitForChild("Logic"):WaitForChild("Habitat"))
local Moves = require(Shared:WaitForChild("Moves"))
local Potions = require(Shared:WaitForChild("Potions"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Areas = require(Shared:WaitForChild("Areas"))
local Gameplay = require(Shared:WaitForChild("Gameplay"))
local Config = require(Shared:WaitForChild("Config"))
local Products = require(Shared:WaitForChild("Products"))
local Species = require(Shared:WaitForChild("Species"))
local Elements = require(Shared:WaitForChild("Elements"))
local Models = require(Shared:WaitForChild("Models"))
local player = Players.LocalPlayer
local Followers = require("./Followers")
local Client = {}
local gui: ScreenGui? = nil
local connections: {RBXScriptConnection} = {}
local pageConnections: {RBXScriptConnection} = {}
local timers: {() -> ()} = {}
-- Validated network snapshots are deliberately dynamic at this boundary.
local data: any = nil
local battle: any = nil
local trade: any = nil
local incomingTrade: any = nil
local tradeKey = ""
local tradeReceived = 0
local savedCamera: any = nil
local lifetime = 0
local offset = 0
local battleReceived = 0
local page = "Habitat"
local selected: string? = nil
local team: {string} = {}
local fusion: {string} = {}
local offer: {string} = {}
local expeditionTeam: {string} = {}
local sessionStart: number? = nil
local flying = false
local vertical = 0
local fingerprint = ""
local battleFingerprint = ""
local pending: {[string]: boolean} = {}
local body: ScrollingFrame
local panel: Frame
local wallet: TextLabel
local notice: TextLabel
local rideControls: Frame
local render: () -> ()
local layout: () -> ()=function() end
local expandedBattle=false
local ink = Color3.fromRGB(241, 235, 219)
local plum = Color3.fromRGB(30, 22, 45)
local cardColor = Color3.fromRGB(48, 37, 66)
local gold = Color3.fromRGB(219, 172, 77)
local mint = Color3.fromRGB(91, 157, 137)
local function now(): number return DateTime.now().UnixTimestampMillis / 1000 + offset end
local function pretty(n: number): string
	if n >= 1e6 then return string.format("%.1fm", n/1e6) end
	if n >= 1e3 then return string.format("%.1fk", n/1e3) end
	return tostring(math.floor(n))
end
local function timeText(n: number): string
	n = math.max(0, math.ceil(n))
	return string.format("%d:%02d", math.floor(n/60), n%60)
end
local function make(class: string, props: {[string]: any}): any
	local i: any = Instance.new(class :: any)
	for k,v in props do i[k] = v end
	return i
end
local function round(i: Instance, radius: number)
	make("UICorner", {CornerRadius=UDim.new(0,radius),Parent=i})
end
local function listen(signal: RBXScriptSignal, fn: any, pageOnly: boolean?)
	table.insert(if pageOnly then pageConnections else connections, signal:Connect(fn))
end
local function say(text: string) notice.Text = text end
local function call(name: string, ...: any)
	if pending[name] then return end
	pending[name] = true
	local args = table.pack(...)
	local generation=lifetime
	task.spawn(function()
		local ok,res = pcall(function() return Net.Function(name):InvokeServer(table.unpack(args,1,args.n)) end)
		pending[name] = nil
		if not gui or generation~=lifetime then return end
		if not ok or type(res) ~= "table" then say("Connection problem. Try again.")
		elseif res.ok ~= true then say(tostring(res.err or "Please try again."))
		else say(tostring(res.message or (name .. " complete"))) end
	end)
end
local function label(parent: Instance, text: string, height: number?): TextLabel
	return make("TextLabel", {BackgroundTransparency=1,Size=UDim2.new(1,0,0,height or 44),Text=text,TextColor3=ink,TextSize=17,Font=Enum.Font.Gotham,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Parent=parent})
end
local function button(parent: Instance, text: string, fn: () -> (), enabled: boolean?): TextButton
	local active = enabled ~= false
	local b: TextButton = make("TextButton", {Size=UDim2.new(1,0,0,48),Text=text,TextColor3=ink,TextSize=16,Font=Enum.Font.GothamBold,BackgroundColor3=if active then mint else Color3.fromRGB(65,59,73),AutoButtonColor=active,TextWrapped=true,Parent=parent})
	round(b,10)
	listen(b.Activated,function() if active and b:GetAttribute("Available")~=false then fn() end end,true)
	return b
end
local function available(b: TextButton,enabled: boolean)
 b:SetAttribute("Available",enabled); b.AutoButtonColor=enabled
 b.BackgroundColor3=if enabled then mint else Color3.fromRGB(65,59,73)
end
local function sessionMinutes(): number
 return if sessionStart then (os.clock()-(sessionStart :: number))/60 else 0
end
local function card(title: string): Frame
	local f: Frame = make("Frame",{Size=UDim2.new(1,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=cardColor,BorderSizePixel=0,Parent=body})
	round(f,14)
	make("UIPadding",{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),Parent=f})
	make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,Parent=f})
	local l = label(f,title,38); l.Font=Enum.Font.GothamBold; l.TextColor3=gold; l.TextSize=20
	return f
end
local function timer(parent: Instance, getText: () -> string,height: number?)
	local l = label(parent,getText(),height or 60)
	table.insert(timers,function() if l.Parent then l.Text=getText() end end)
end
local function creature(uid: string?): any
	if not data then return nil end
	for _,c in data.Creatures or {} do if c.Uid == uid then return c end end
	return nil
end
local function name(c: any): string return tostring(c.Name or c.Species) .. " · " .. tostring(c.Rarity) .. " · " .. tostring(c.Element) .. " · Lv " .. tostring(c.Level or 1) end
local function busy(uid: string): boolean
	if not data then return true end
	for _,s in data.Habitats or {} do if s.Creature == uid then return true end end
	for _,e in data.Expeditions or {} do if table.find(e.Creatures or {},uid) then return true end end
	if data.Riding == uid then return true end
	if trade then for _,c in trade.Me.Creatures or {} do if c.Uid == uid then return true end end end
	return false
end
local function preview(parent: Instance,c: any)
	local viewport: ViewportFrame = make("ViewportFrame",{Size=UDim2.new(1,0,0,140),BackgroundTransparency=1,Ambient=Color3.fromRGB(190,190,190),LightColor=Color3.new(1,1,1),Parent=parent})
	local world = make("WorldModel",{Parent=viewport})
	local ok,model = pcall(Models.Creature,c.Species,c.Element,c.Rarity,"Adult",{Neon=c.Neon or (c.Potions and c.Potions.Neon),Cosmetics=c.Cosmetics})
	if ok and typeof(model) == "Instance" and model:IsA("Model") then
		model.Parent=world; model:PivotTo(CFrame.new())
		local cf,size=model:GetBoundingBox(); local distance=math.max(size.X,size.Y,size.Z)*1.8
		local camera: Camera=make("Camera",{CFrame=CFrame.lookAt(cf.Position+Vector3.new(distance*.65,distance*.3,distance),cf.Position),Parent=viewport})
		viewport.CurrentCamera=camera
	end
end
local function toggle(list: {string},uid: string,limit: number)
	local index=table.find(list,uid)
	if index then table.remove(list,index) elseif #list<limit then table.insert(list,uid) else say("Choose up to "..limit.." creatures") end
	render()
end
local function oddsText(weights: {[string]: number}): string
	local keys={}; for key in weights do table.insert(keys,key) end; table.sort(keys)
	local chunks={}; for _,key in keys do table.insert(chunks,string.format("%s %.2f%%",key,weights[key])) end
	return table.concat(chunks," · ")
end
local function showOdds(parent: Instance,egg: any,fused: any?)
	local ok,odds=pcall(Hatch.Odds,egg,data.LuckMult or 1,fused)
	if ok then
		for _,axis in {"Species","Rarity","Element"} do
			local text=axis..": "..oddsText(odds[axis]); label(parent,text,math.max(50,math.ceil(#text/38)*21))
		end
	end
end
local function habitatPage()
	local intro=card("Your habitat")
	label(intro,"Assigned creatures earn coins online and offline until storage fills. Collect manually. No passive XP.",74)
	if #data.Creatures<3 then label(intro,"First adventure: buy two Meadow eggs in Hatchery, incubate 60s, hatch, then choose three creatures in Battle.",88) end
	button(intro,"Collect all coins",function() call("HabitatCollect") end)
	for slot=1,data.HabitatSlots or 3 do
		local s=data.Habitats and data.Habitats[tostring(slot)]
		if not s then continue end
		local f=card("Slot "..slot.." · upgrade "..s.Level)
		local c=creature(s.Creature)
		label(f,if c then name(c) else "Empty slot",54)
		timer(f,function()
			local current=data.Habitats[tostring(slot)]; local cap=Habitat.Capacity(current)
			local coins=math.min(cap,current.Coins+math.max(0,now()-current.UpdatedAt)*Habitat.Rate(current))
			return pretty(coins).." / "..pretty(cap).." stored · "..string.format("%.1f",Habitat.Rate(current)).." coins/s"
		end)
		button(f,"Collect",function() call("HabitatCollect",slot) end)
		if c then button(f,"Remove from habitat",function() call("HabitatRemove",slot) end)
		else
			button(f,"Assign selected creature",function() if selected then call("HabitatAssign",selected,slot) else say("Choose a creature in Creatures first") end end,selected~=nil and not busy(selected :: string))
		end
		button(f,"Upgrade · "..pretty(Habitat.UpgradeCost(s)).." coins",function() call("HabitatUpgrade",slot) end,s.Level<Gameplay.Habitat.MaxUpgrade)
	end
	local f=card("More slots")
	button(f,"Unlock next slot · "..pretty(Gameplay.Habitat.UpgradeCost*2^((data.HabitatSlots or 3)-Gameplay.Habitat.BaseSlots+1)).." coins",function() call("HabitatUnlock") end,(data.HabitatSlots or 3)<Gameplay.Habitat.MaxSlots)
end
local function creaturePage()
	local f=card("Creature collection")
	label(f,"Choose a creature for habitat, shop or riding. Battle participation is the only source of levels.",68)
	for _,c in data.Creatures or {} do
		button(f,(if selected==c.Uid then "✓ " else "")..name(c)..(if busy(c.Uid) then " · busy" else ""),function() selected=c.Uid; render() end)
	end
	local c=creature(selected)
	if c then
		local detail=card(name(c)); preview(detail,c)
		label(detail,"Battle XP: "..tostring(c.Xp or 0).." · "..(if c.Locked then "Locked" else "Unlocked"))
		button(detail,if c.Locked then "Unlock creature" else "Lock creature",function() call("LockCreature",c.Uid,not c.Locked) end)
		button(detail,if table.find(data.Equipped or {},c.Uid) then "Recall companion" else "Follow me",function() call("EquipCreature",c.Uid,table.find(data.Equipped or {},c.Uid)==nil) end,not busy(c.Uid))
		button(detail,"Ride / fly",function() call("Mount",c.Uid) end,not busy(c.Uid) and c.Potions and (c.Potions.Ride or c.Potions.Fly))
		label(detail,"Unlocked moves",28)
		for _,move in Moves.For(c) do label(detail,move.Name.." · "..move.Kind,30) end
	end
end
local function hatcheryPage()
	local f=card("Incubators")
	for slot=1,data.HatchSlots or 1 do
		local incubator=data.Incubators[tostring(slot)]
		if incubator then
			label(f,"Slot "..slot.." · "..incubator.Egg.Egg)
			timer(f,function() return "Hatches in "..timeText(incubator.EndAt-now()) end)
			local hatchButton=button(f,"Hatch slot "..slot,function() call("Hatch",slot) end)
			local skipButton=button(f,"Finish early",function() call("SkipIncubation",slot) end)
			table.insert(timers,function()
				local remaining=incubator.EndAt-now()
				available(hatchButton,remaining<=0); available(skipButton,remaining>0)
				skipButton.Text="Finish early · "..math.max(Config.IncubateSkipMinGems,math.ceil(math.max(0,remaining)/30)*Config.IncubateSkipGemsPer30s).." gems"
			end)
		else label(f,"Slot "..slot.." · empty") end
	end
	local bag=card("Egg bag")
	if #(data.EggBag or {})==0 then label(bag,"Buy an egg below to begin") end
	for _,egg in data.EggBag or {} do
		button(bag,"Incubate "..egg.Egg,function() call("Incubate",egg.Uid) end)
		if egg.Fused then showOdds(bag,Eggs.ById[egg.Egg],egg.Fused) end
	end
	for _,egg in Eggs.List do
		if Eggs.OnSale(egg,now()) and (data.Areas[egg.Area] or egg.Kind=="Premium" or egg.Kind=="Limited") then
			local e=card(egg.Name.." · "..pretty(egg.Cost).." "..egg.Currency)
			label(e,"Incubation "..timeText(egg.IncubateSeconds).." · independent rolls",42)
			showOdds(e,egg,nil)
			button(e,"Buy one egg",function() call("BuyEgg",egg.Id,1) end,egg.Currency~="Gems" or data.CanBuyGemEggs)
		end
	end
end
local function battleClock(): number
	return (battle and (battle.ServerTime or battle.Now) or 0)+(os.clock()-battleReceived)
end
local function battlePage()
	local running=battle and battle.Status=="Running"
	local f=card(if running then "Active creature commands" else "Optional trainer battles")
	if running then f.BackgroundTransparency=.25 else
		label(f,"Three creatures, one active. Opponents are matched by team strength. Habitat creatures cannot join.",72)
		label(f,"Arena points: "..tostring(data.ArenaPoints or 0))
	end
	if not battle then
		label(f,"Selected "..#team.." / 3")
		for _,c in data.Creatures or {} do button(f,(if table.find(team,c.Uid) then "✓ " else "")..name(c),function() toggle(team,c.Uid,3) end,not busy(c.Uid)) end
		button(f,"Save team",function() call("SetBattleTeam",table.clone(team)) end,#team==3)
		local saved=data.BattleTeam or {}
		local matches=#saved==3 and #team==3
		for index,uid in team do if saved[index]~=uid then matches=false end end
		button(f,"Find opponent",function() call("BattleJoin") end,matches)
		if #team==3 and not matches then label(f,"Save this team before searching") end
		return
	end
	if battle.Status=="Queued" then label(f,"Searching for a similar strength opponent…",60); button(f,"Leave queue",function() call("BattleLeave") end); return end
	local mine: any=nil; local enemy: any=nil
	for _,side in battle.Sides or {} do if side.UserId==player.UserId then mine=side else enemy=side end end
	if not mine then label(f,"Watching battle"); return end
	if battle.Status~="Running" then label(f,"Result: "..(if battle.Winner==nil then "Draw" elseif battle.Winner==player.UserId then "Victory" else "Defeat").." · creatures recover after battle",74) end
	local active=mine.Fighters[mine.Active]
	if active and battle.Status=="Running" then
		timer(f,function()
			local currentMine: any=nil; local currentEnemy: any=nil
			for _,side in battle.Sides do if side.UserId==player.UserId then currentMine=side else currentEnemy=side end end
			local mineActive=currentMine and currentMine.Fighters[currentMine.Active]
			local enemyActive=currentEnemy and currentEnemy.Fighters[currentEnemy.Active]
			return (if mineActive then "You · "..mineActive.Creature.Species.."  "..pretty(mineActive.Hp).."/"..pretty(mineActive.MaxHp).." HP" else "").."\n"..(if enemyActive then "Enemy · "..enemyActive.Creature.Species.."  "..pretty(enemyActive.Hp).."/"..pretty(enemyActive.MaxHp).." HP" else "")
		end,46)
		timer(f,function()
			local current: any=nil; for _,s in battle.Sides do if s.UserId==player.UserId then current=s end end
			return "Moves ready in "..timeText((current.MoveAt or 0)-battleClock()).." · swap "..timeText((current.SwapAt or 0)-battleClock())
		end,28)
		local unlocked=Moves.For(active.Creature)
		local movesFrame: Frame=make("Frame",{Size=UDim2.new(1,0,0,math.ceil(#unlocked/2)*56),BackgroundTransparency=1,Parent=f})
		make("UIGridLayout",{CellSize=UDim2.new(.5,-4,0,48),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder,Parent=movesFrame})
		for _,move in unlocked do
			local b=button(movesFrame,move.Name.." · "..move.Kind,function() call("BattleMove",move.Id) end)
			table.insert(timers,function()
				local current: any=nil; for _,side in battle.Sides do if side.UserId==player.UserId then current=side end end
				available(b,current~=nil and battleClock()>=(current.MoveAt or 0))
			end)
		end
	end
	for _,side in {mine,enemy} do
		if not side then continue end
		local own=side.UserId==player.UserId
		local title=label(f,if own then "Your team" else "Opponent · "..side.UserId,30); title.TextColor3=gold
		for index,fighter in side.Fighters do
			timer(f,function()
				local latestSide: any=nil
				for _,current in battle.Sides or {} do if current.UserId==side.UserId then latestSide=current end end
				local current=latestSide and latestSide.Fighters[index] or fighter
				return (if latestSide and latestSide.Active==index then "▶ " else "")..name(current.Creature).."\nHP "..pretty(current.Hp).." / "..pretty(current.MaxHp)
			end)
			if own then
				local b=button(f,"Swap to "..fighter.Creature.Species,function() call("BattleSwap",index) end,fighter.Hp>0 and index~=mine.Active and battle.Status=="Running")
				table.insert(timers,function()
					local current: any=nil; for _,sideNow in battle.Sides do if sideNow.UserId==player.UserId then current=sideNow end end
					available(b,current~=nil and battleClock()>=(current.SwapAt or 0))
				end)
			end
		end
	end
	button(f,"Leave battle",function() call("BattleLeave") end)
end
local function fusionPage()
	local f=card("Fusion")
	label(f,"Fusion permanently consumes BOTH parents. You receive an egg with improved rarity odds and a possible hidden hybrid. Hatchling starts at level 1.",112)
	for _,c in data.Creatures or {} do button(f,(if table.find(fusion,c.Uid) then "✓ " else "")..name(c),function() toggle(fusion,c.Uid,2) end,not busy(c.Uid) and not c.Locked) end
	if #fusion==2 then
		label(f,"Selected parents will be destroyed. This cannot be undone.",60)
		button(f,"Confirm: consume both parents",function() call("Fuse",fusion[1],fusion[2]); table.clear(fusion) end)
	end
end
local function shopPage()
	local c=creature(selected)
	local f=card("Potion shop")
	label(f,if c then "Apply to "..name(c) else "Select a creature in Creatures first",58)
	for _,p in Potions.List do button(f,p.Name.." · "..p.Gems.." gems",function() if c then call("UsePotion",c.Uid,p.Id) end end,c~=nil and not busy(c.Uid) and not c.Potions[p.Id]) end
	local cosmetics=card("Cosmetics")
	for _,item in Cosmetics.List do
		local owned=data.Cosmetics[item.Id]==true
		button(cosmetics,item.Name..(if owned then " · wear" else " · "..pretty(item.Coins).." coins"),function()
			if owned then if c then call("WearCosmetic",c.Uid,item.Slot,item.Id) else say("Select a creature first") end else call("BuyCosmetic",item.Id) end
		end)
	end
	if c then for _,slot in Cosmetics.Slots do button(cosmetics,"Remove "..slot,function() call("WearCosmetic",c.Uid,slot,"") end) end end
end
local function rewardsPage()
	local f=card("Daily rewards")
	label(f,"Streak "..tostring(data.Daily.Streak))
	button(f,"Claim daily",function() call("ClaimDaily") end,data.Daily.CanClaim)
	local gifts=card("Playtime gifts")
 timer(gifts,function() return "Played this session: "..math.floor(sessionMinutes()).." min" end)
 for index,gift in Config.PlaytimeGifts do
  local claimed=data.Playtime.Claimed[tostring(index)]
  local b=button(gifts,(if claimed then "Claimed · " else "Claim · ")..tostring(gift.Minutes).." minutes",function() call("ClaimPlaytime",index) end,not claimed)
  table.insert(timers,function() available(b,not claimed and sessionMinutes()>=(gift.Minutes or 0)) end)
 end
	local q=card("Quests")
	for index,quest in data.Quests or {} do
		label(q,quest.Kind.." · "..pretty(quest.Progress).." / "..pretty(quest.Goal).." · "..quest.Gems.." gems",52)
		button(q,if quest.Claimed then "Claimed" else "Claim reward",function() call("ClaimQuest",index) end,not quest.Claimed and quest.Progress>=quest.Goal)
	end
	local world=card("Explore")
	for _,area in Areas.List do button(world,area.Name..(if data.Areas[area.Id] then " · travel" else " · "..pretty(area.GateCost).." coins"),function() call(if data.Areas[area.Id] then "Teleport" else "OpenGate",area.Id) end) end
	local rebirth=card("Rebirth")
	label(rebirth,"Resets coins and unlocked regions for a permanent earning multiplier. Cost "..pretty(data.RebirthCost or 0).." coins.",84)
	button(rebirth,"Confirm rebirth reset",function() call("Rebirth") end,data.Coins >= (data.RebirthCost or math.huge))
end
local function expeditionsPage()
 local f=card("Expeditions")
 label(f,"Send available creatures for coins, gems and possible eggs. They cannot battle, earn XP or ride while away.",84)
 for slot=1,data.ExpeditionSlots or 1 do
  local e=data.Expeditions[tostring(slot)]
  if e then
   label(f,"Slot "..slot.." · "..e.Area)
   timer(f,function() return "Returns in "..timeText(e.EndAt-now()) end)
   local claim=button(f,"Claim expedition "..slot,function() call("ClaimExpedition",slot) end)
   local skip=button(f,"Finish early",function() call("SkipExpedition",slot) end)
   table.insert(timers,function()
    local left=e.EndAt-now(); available(claim,left<=0); available(skip,left>0)
    skip.Text="Finish early · "..math.max(5,math.ceil(math.max(0,left)/60)*Config.ExpeditionSkipGemsPerMinute).." gems"
   end)
  else label(f,"Slot "..slot.." · empty") end
 end
 local choose=card("Choose up to three creatures")
 for _,c in data.Creatures do button(choose,(if table.find(expeditionTeam,c.Uid) then "✓ " else "")..name(c),function() toggle(expeditionTeam,c.Uid,Config.MaxPetsPerExpedition) end,not busy(c.Uid)) end
 for _,area in Areas.List do if data.Areas[area.Id] then
  local dest=card(area.Name)
  for _,duration in Config.ExpeditionDurations do
   button(dest,duration.Key.." · "..timeText(duration.Seconds),function() call("StartExpedition",area.Id,duration.Key,table.clone(expeditionTeam)) end,#expeditionTeam>0)
  end
 end end
end
local function indexPage()
 local f=card("Collection index")
 local count=0
 for _,species in Species.List do for _,element in Elements.List do if data.Index[species.Id.."|"..element.Id] then count+=1 end end end
 local total=#Species.List*#Elements.List
 label(f,count.." / "..total.." species and element combinations")
 for tier,reward in Config.IndexRewards do
  local needed=math.ceil(total*(reward.Fraction or 0)); local claimed=data.IndexClaimed[tostring(tier)]
  button(f,(if claimed then "Claimed · " else "Claim · ")..needed.." discoveries · "..tostring(reward.Gems or 0).." gems",function() call("ClaimIndex",tier) end,not claimed and count>=needed)
 end
 for _,species in Species.List do
  local discovered={}; for _,element in Elements.List do if data.Index[species.Id.."|"..element.Id] then table.insert(discovered,element.Name) end end
  label(f,(if species.Hybrid and #discovered==0 then "???" else species.Name).." · "..(if #discovered==0 then "Undiscovered" else table.concat(discovered,", ")),54)
 end
end
local function storePage()
 local f=card("Passes and boosts")
 label(f,"Tap an available item to see its current Robux price in Roblox's purchase prompt.",70)
 if not data.CanBuyGemEggs then label(f,"Paid luck and paid random eggs are unavailable for this account.",62) end
 local function purchase(item: any,isPass: boolean)
  if item.Id==0 then if RunService:IsStudio() then call("DevPurchase",item.Key) end; return end
  local ok=pcall(function()
   if isPass then MarketplaceService:PromptGamePassPurchase(player,item.Id) else MarketplaceService:PromptProductPurchase(player,item.Id) end
  end)
  if not ok then say("Purchase prompt unavailable. Try again.") end
 end
 for _,pass in Products.Passes do
  if pass.Key=="AutoFarm" or pass.Key=="RingChampion" then continue end
  local owned=data.Passes[pass.Key]; local text=pass.Name..(if owned then " · owned" elseif pass.Id==0 then (if RunService:IsStudio() then " · Studio test" else " · coming soon") else " · view price")
  label(f,pass.Blurb,54); button(f,text,function() purchase(pass,true) end,not owned and (pass.Id>0 or RunService:IsStudio()) and (pass.Key~="Lucky" or data.CanBuyGemEggs))
 end
 local boosts=card("Gems and temporary boosts")
 for _,product in Products.Products do
  local title=if product.Boost=="Growth2x" then "2x Battle XP (30 min)" else product.Name
  button(boosts,title..(if product.Id==0 then (if RunService:IsStudio() then " · Studio test" else " · coming soon") else " · view price"),function() purchase(product,false) end,(product.Id>0 or RunService:IsStudio()) and ((product.Boost~="Luck2x" and product.Kind~="ServerLuck") or data.CanBuyGemEggs))
 end
 local active=card("Active boosts")
 for key,definition in Config.Boosts do timer(active,function() return (if key=="Growth2x" then "2x Battle XP" else definition.Name).." · "..timeText((data.Boosts[key] or 0)-now()) end) end
 if RunService:IsStudio() then
  local dev=card("Studio test tools")
  for _,action in {"Coins1M","Gems1000","FinishExpeditions","OpenGates"} do button(dev,action,function() call("DevAction",action) end) end
 end
end
local function tradePage()
	local f=card("Creature trading")
	if not data.CanTrade then label(f,"Trading unavailable for this account"); return end
	if not trade then
		if incomingTrade then
			label(f,"Incoming request · "..tostring(incomingTrade.FromName or "Trainer"))
			local uid=incomingTrade.FromUserId
			button(f,"Accept request",function() call("TradeRespond",uid,true); incomingTrade=nil end)
			button(f,"Decline request",function() call("TradeRespond",uid,false); incomingTrade=nil; render() end)
		end
		for _,other in Players:GetPlayers() do if other~=player then button(f,"Request trade · "..other.DisplayName,function() call("TradeRequest",other.UserId) end) end end
		return
	end
	label(f,"Trading with "..trade.Them.Name)
	timer(f,function() return if trade.Countdown then "Completes in "..timeText(trade.Countdown-(os.clock()-tradeReceived)) else "Review both offers" end)
	for _,c in trade.Them.Creatures or {} do label(f,"Their offer: "..name(c),54) end
	label(f,if trade.Them.Ready then "Other trainer is ready" else "Other trainer is reviewing")
	label(f,"Your offer: "..#(trade.Me.Creatures or {}).." creatures")
	for _,c in data.Creatures or {} do button(f,(if table.find(offer,c.Uid) then "✓ " else "")..name(c),function() toggle(offer,c.Uid,trade.MaxCreatures or 4) end,not c.Locked and (not busy(c.Uid) or table.find(offer,c.Uid)~=nil)) end
	button(f,"Update creature offer",function() call("TradeSetOffer",table.clone(offer),0) end)
	label(f,"Review the other offer before readying. A successful trade transfers your offered creatures permanently.",78)
	button(f,if trade.Me.Ready then "Unready" else "Ready to trade",function() call("TradeReady",not trade.Me.Ready) end)
	button(f,"Cancel trade",function() call("TradeCancel") end)
end
render=function()
	if not gui then return end
	layout()
	for _,conn in pageConnections do conn:Disconnect() end; table.clear(pageConnections); table.clear(timers)
	for _,child in body:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	if not data then local f=card("Loading your hatchery…"); label(f,"Connecting to your saved collection",48); return end
	local pages: {[string]: () -> ()}={Habitat=habitatPage,Creatures=creaturePage,Hatchery=hatcheryPage,Battle=battlePage,Fusion=fusionPage,Shop=shopPage,Rewards=rewardsPage,Trade=tradePage,Expeditions=expeditionsPage,Index=indexPage,Store=storePage}
	local handler=pages[page]; if handler then handler() end
end
local function gates()
 if not data then return end
 for _,model in CollectionService:GetTagged("Gate") do
  local id=model:GetAttribute("AreaId")
  if type(id)=="string" then
   local barrier=model:FindFirstChild("Barrier",true)
   if barrier and barrier:IsA("BasePart") then
    barrier.CanCollide=not data.Areas[id]; barrier.Transparency=if data.Areas[id] then 1 else .3
   end
  end
 end
end
local function stateKey(d: any): string
	local slots={}; for key,s in d.Habitats or {} do slots[key]={Level=s.Level,Creature=s.Creature,Power=s.Power} end
	return HttpService:JSONEncode({Creatures=d.Creatures,HabitatSlots=d.HabitatSlots,Slots=slots,EggBag=d.EggBag,Incubators=d.Incubators,BattleTeam=d.BattleTeam,Riding=d.Riding,Cosmetics=d.Cosmetics,Daily=d.Daily,Quests=d.Quests,Areas=d.Areas,Expeditions=d.Expeditions,Index=d.Index,IndexClaimed=d.IndexClaimed,PlaytimeClaimed=d.Playtime and d.Playtime.Claimed,Passes=d.Passes,Equipped=d.Equipped,CanTrade=d.CanTrade,CanBuyGemEggs=d.CanBuyGemEggs})
end
local function restoreCamera()
 local camera=Workspace.CurrentCamera
 if camera and savedCamera then
  camera.CameraType=savedCamera.Type; camera.CameraSubject=savedCamera.Subject; camera.CFrame=savedCamera.CFrame
 end
 savedCamera=nil
end
local function watchArena()
 local camera=Workspace.CurrentCamera
 if not camera then return end
 if battle and battle.Status=="Running" then
  local center: Vector3?=nil
  if typeof(battle.VisualCenter)=="Vector3" then center=battle.VisualCenter else
   local zones=CollectionService:GetTagged("BattleArenaBounds")
   local zone=zones[1]
   if zone and zone:IsA("BasePart") then center=zone.Position-Vector3.new(0,7,0) end
  end
  if center then
   if not savedCamera then savedCamera={Type=camera.CameraType,Subject=camera.CameraSubject,CFrame=camera.CFrame} end
   camera.CameraType=Enum.CameraType.Scriptable
   local portrait=camera.ViewportSize.Y>camera.ViewportSize.X
   camera.CFrame=CFrame.lookAt(center+Vector3.new(0,25,45),center+Vector3.new(0,if portrait then -10 else 3,0))
  end
 else restoreCamera() end
end
function Client.Destroy()
	lifetime+=1; restoreCamera(); Followers.Destroy(); sessionStart=nil; table.clear(expeditionTeam)
	table.clear(pending)
	for _,conn in connections do conn:Disconnect() end
	for _,conn in pageConnections do conn:Disconnect() end
	table.clear(connections); table.clear(pageConnections); table.clear(timers)
	if gui then gui:Destroy(); gui=nil end
	expandedBattle=false; layout=function() end
	data=nil; battle=nil; trade=nil; incomingTrade=nil; tradeKey=""; fingerprint=""; battleFingerprint=""; vertical=0; flying=false
end
function Client.Init()
	Client.Destroy()
	Followers.Init()
	gui=make("ScreenGui",{Name="MythicHatchery",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=10,Parent=player:WaitForChild("PlayerGui")})
	panel=make("Frame",{Size=UDim2.fromOffset(420,620),Position=UDim2.new(0,12,0.5,0),AnchorPoint=Vector2.new(0,.5),BackgroundColor3=plum,BorderSizePixel=0,Parent=gui}); round(panel,18)
	local scale: UIScale=make("UIScale",{Parent=panel})
	local function resize()
		local camera=Workspace.CurrentCamera; if not camera then return end
		local v=camera.ViewportSize
		scale.Scale=math.clamp(v.X/1600,1,1.1)
		layout()
	end
	local cameraConnection: RBXScriptConnection?=nil
	local function watchCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		if Workspace.CurrentCamera then cameraConnection=Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize); table.insert(connections,cameraConnection :: RBXScriptConnection) end
		resize()
	end
	listen(Workspace:GetPropertyChangedSignal("CurrentCamera"),watchCamera); watchCamera()
	local title=label(panel,"MYTHIC HATCHERY",42); title.Position=UDim2.fromOffset(14,4)
	wallet=label(panel,"Loading…",34); wallet.Position=UDim2.fromOffset(14,44); wallet.TextColor3=gold
	local tabs: ScrollingFrame=make("ScrollingFrame",{Size=UDim2.new(1,-24,0,54),Position=UDim2.fromOffset(12,82),BackgroundTransparency=1,AutomaticCanvasSize=Enum.AutomaticSize.X,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.X,Parent=panel})
	make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),Parent=tabs})
	for _,tab in {"Habitat","Creatures","Hatchery","Battle","Fusion","Shop","Rewards","Trade","Expeditions","Index","Store"} do
		local b: TextButton=make("TextButton",{Size=UDim2.fromOffset(100,44),Text=tab,TextSize=15,Font=Enum.Font.GothamBold,TextColor3=ink,BackgroundColor3=cardColor,Parent=tabs}); round(b,10)
		listen(b.Activated,function() page=tab; expandedBattle=false; body.CanvasPosition=Vector2.zero; render() end)
	end
	body=make("ScrollingFrame",{Size=UDim2.new(1,-24,1,-196),Position=UDim2.fromOffset(12,144),AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=5,BackgroundTransparency=1,BorderSizePixel=0,Parent=panel})
	make("UIListLayout",{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder,Parent=body})
	notice=label(panel,"Welcome. Your starter can ride and fly immediately.",44); notice.Position=UDim2.new(0,12,1,-48); notice.Size=UDim2.new(1,-24,0,44); notice.TextSize=14
	local expand: TextButton=make("TextButton",{Size=UDim2.fromOffset(74,30),Position=UDim2.new(1,-86,0,5),Text="Menus",TextSize=14,Font=Enum.Font.GothamBold,TextColor3=ink,BackgroundColor3=cardColor,Visible=false,Parent=panel}); round(expand,8)
 listen(expand.Activated,function() expandedBattle=true; render() end)
 layout=function()
  local camera=Workspace.CurrentCamera; if not camera then return end
  local v=camera.ViewportSize
  local compact=page=="Battle" and battle~=nil and battle.Status=="Running" and not expandedBattle
  local portrait=v.Y>v.X
  local height=if compact and portrait then math.min(620,v.Y*.52) else math.min(620,math.max(220,v.Y-56))
  panel.Size=UDim2.fromOffset(math.min(420,(v.X-24)/scale.Scale),height/scale.Scale)
  panel.Position=if compact and portrait then UDim2.new(0,12,1,-12) else UDim2.new(0,12,.5,0)
  panel.AnchorPoint=if compact and portrait then Vector2.new(0,1) else Vector2.new(0,.5)
  panel.BackgroundTransparency=if compact then .18 else 0
  wallet.Visible=not compact; tabs.Visible=not compact; notice.Visible=not compact; expand.Visible=compact
  title.Text=if compact then "TRAINER ARENA" else "MYTHIC HATCHERY"; title.TextSize=if compact then 17 else 20
  title.Size=UDim2.new(1,if compact then -110 else -28,0,if compact then 32 else 42)
  body.Position=UDim2.fromOffset(12,if compact then 40 else 144)
  body.Size=UDim2.new(1,-24,1,if compact then -50 else -196)
 end
	local hide: TextButton=make("TextButton",{Size=UDim2.fromOffset(110,44),Position=UDim2.new(1,-122,0,10),Text="Menu / world",TextSize=14,Font=Enum.Font.GothamBold,TextColor3=ink,BackgroundColor3=plum,Parent=gui}); round(hide,10)
	listen(hide.Activated,function() panel.Visible=not panel.Visible end)
	rideControls=make("Frame",{Size=UDim2.fromOffset(150,192),Position=UDim2.new(1,-162,.5,-50),BackgroundTransparency=1,Visible=false,Parent=gui})
	make("UIListLayout",{Padding=UDim.new(0,8),Parent=rideControls})
	local function rideButton(text: string,fn: () -> ()): TextButton
		local b: TextButton=make("TextButton",{Size=UDim2.fromOffset(150,40),Text=text,TextSize=16,Font=Enum.Font.GothamBold,BackgroundColor3=plum,TextColor3=ink,Parent=rideControls}); round(b,10); listen(b.Activated,fn); return b
	end
	rideButton("Fly / land",function() flying=not flying end)
	local up=rideButton("Ascend ↑",function() end); local down=rideButton("Descend ↓",function() end)
	for _,entry in {{Button=up,Direction=1},{Button=down,Direction=-1}} do
		local b=entry.Button; local direction=entry.Direction
		listen(b.InputBegan,function(input: InputObject) if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then vertical=direction end end)
		listen(b.InputEnded,function(input: InputObject) if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then vertical=0 end end)
	end
	rideButton("Dismount",function() call("Mount",nil); vertical=0; flying=false end)
	listen(UserInputService.InputBegan,function(input: InputObject,processed: boolean)
		if processed then return end
		if input.KeyCode==Enum.KeyCode.Space then vertical=1 elseif input.KeyCode==Enum.KeyCode.LeftControl then vertical=-1 elseif input.KeyCode==Enum.KeyCode.F and data and data.Riding then flying=not flying end
	end)
	listen(UserInputService.InputEnded,function(input: InputObject) if input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.LeftControl then vertical=0 end end)
	local function updatePlayers() if page=="Trade" and not trade then render() end end
 listen(Players.PlayerAdded,updatePlayers); listen(Players.PlayerRemoving,updatePlayers)
	listen(ProximityPromptService.PromptTriggered,function(prompt: ProximityPrompt,who: Player)
  if who~=player then return end
  local model=prompt:FindFirstAncestorOfClass("Model")
  if not model then return end
  if CollectionService:HasTag(model,"EggStand") or CollectionService:HasTag(model,"Hatchery") then page="Hatchery"
  elseif CollectionService:HasTag(model,"HabitatPlot") then page="Habitat"
  elseif CollectionService:HasTag(model,"BattleArena") then page="Battle"
  elseif CollectionService:HasTag(model,"FusionAltar") then page="Fusion"
  elseif CollectionService:HasTag(model,"CosmeticShop") then page="Shop"
  elseif CollectionService:HasTag(model,"Gate") then call("OpenGate",model:GetAttribute("AreaId")); return
  else return end
  panel.Visible=true; body.CanvasPosition=Vector2.zero; render()
 end)
	listen(player:GetAttributeChangedSignal("Mount"),function()
  local uid=player:GetAttribute("Mount")
  rideControls.Visible=uid~=nil
  if data then data.Riding=uid; render() end
  if uid then panel.Visible=false else flying=false; vertical=0 end
 end)
	listen(Net.Event("State").OnClientEvent,function(snapshot: any)
		if type(snapshot)~="table" or type(snapshot.Creatures)~="table" then return end
		data=snapshot
		local start=os.clock()-((data.Playtime and data.Playtime.SessionMinutes) or 0)*60
		if not sessionStart or start<sessionStart then sessionStart=start end
		data.Riding=player:GetAttribute("Mount")
		if type(snapshot.ServerTime)=="number" then offset=snapshot.ServerTime-DateTime.now().UnixTimestampMillis/1000 end
		wallet.Text=pretty(data.Coins).." coins  ·  "..pretty(data.Gems).." gems"
		rideControls.Visible=data.Riding~=nil
		local key=stateKey(data)
		if key~=fingerprint then
			gates()
			local first=fingerprint==""; fingerprint=key
			if first then team=table.clone(data.BattleTeam or {}); selected=data.Creatures[1] and data.Creatures[1].Uid end
			render()
		end
	end)
	listen(Net.Event("Battle").OnClientEvent,function(view: any)
		battle=if type(view)=="table" then view else nil; battleReceived=os.clock(); watchArena()
		local sides={}; if battle then for _,side in battle.Sides or {} do
			local fs={}; for _,fighter in side.Fighters do table.insert(fs,{Uid=fighter.Creature.Uid,Level=fighter.Creature.Level,Alive=fighter.Hp>0}) end
			table.insert(sides,{UserId=side.UserId,Active=side.Active,Fighters=fs})
		end end
		local key=HttpService:JSONEncode({Id=battle and battle.Id,Status=battle and battle.Status,Sides=sides})
		if key~=battleFingerprint then battleFingerprint=key; if page=="Battle" then render() end end
	end)
	listen(Net.Event("Trade").OnClientEvent,function(view: any)
  trade=if type(view)=="table" then view else nil; tradeReceived=os.clock()
  local key=HttpService:JSONEncode({Id=trade and trade.Id,Me=trade and trade.Me,Them=trade and trade.Them,Status=trade and trade.Status})
  if key~=tradeKey then
   tradeKey=key
   if trade then incomingTrade=nil; offer={}; for _,c in trade.Me.Creatures or {} do table.insert(offer,c.Uid) end; page="Trade"; panel.Visible=true end
   if page=="Trade" then render() end
  end
 end)
	listen(Net.Event("Notify").OnClientEvent,function(kind: string,payload: any)
		payload=if type(payload)=="table" then payload else {}
		if kind=="TradeRequest" then
   incomingTrade=payload; page="Trade"; panel.Visible=true; render()
		else say(tostring(payload.Text or payload.Message or kind)) end
	end)
	local tickTime=0; local mountTime=0; local retryTime=0
	listen(RunService.Heartbeat,function(dt: number)
		tickTime+=dt; mountTime+=dt; retryTime+=dt
		if tickTime>=.25 then tickTime=0; for _,update in timers do update() end; watchArena() end
		if retryTime>=5 and not data then retryTime=0; Net.Event("ClientReady"):FireServer() end
		if mountTime>=.1 and data and data.Riding then
			mountTime=0
			local character=player.Character; local humanoid=character and character:FindFirstChildOfClass("Humanoid")
			local move=if humanoid then humanoid.MoveDirection else Vector3.zero
			local direction=move+Vector3.new(0,if flying then vertical else 0,0)
			if direction.Magnitude>1 then direction=direction.Unit end
			Net.Event("MountInput"):FireServer(direction,flying)
		end
	end)
	listen(script.Destroying,Client.Destroy)
	render(); Net.Event("ClientReady"):FireServer()
end
return Client
