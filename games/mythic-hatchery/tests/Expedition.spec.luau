local Profile = require("../src/shared/Logic/Profile")
local Inventory = require("../src/shared/Logic/Inventory")
local Economy = require("../src/shared/Logic/Economy")
local Config = require("../src/shared/Config")
local function fresh() local p=Profile.Default(); p.Creatures={}; p.Index={}; return p end
local function add(p,rarity) return Inventory.Add(p,{Species="Dragon",Element="Nature",Rarity=rarity or "Common"}) end
return {
["start validates and freezes multiplier"] = function(t)
 local E=require("../src/shared/Logic/Expedition"); local p=fresh(); local c=add(p); t.no(E.Start(p,"Bad","Short",{c.Uid},0,1)); local key,e=E.Start(p,"Meadow","Short",{c.Uid},0,1,nil,2.5); t.ok(key); t.ok(Inventory.IsBusy(p,c.Uid)); t.eq(p.ExpeditionMult[key],2.5); t.no(E.Start(p,"Meadow","Short",{c.Uid},0,1))
end,
["deterministic claim is timer gated and paid once without xp"] = function(t)
 local E=require("../src/shared/Logic/Expedition"); local p=fresh(); local c=add(p); local key,e=E.Start(p,"Meadow","Short",{c.Uid},0,42); local a=E.RollReward(p,e); local b=E.RollReward(p,e); t.eq(a.Coins,b.Coins); t.eq(a.Gems,b.Gems); t.no(E.Claim(p,key,0)); local result=E.Claim(p,key,e.EndAt); t.ok(result); t.no(E.Claim(p,key,e.EndAt)); t.eq(c.Xp,0); t.no(Inventory.IsBusy(p,c.Uid)); t.eq(p.Stats.Expeditions,1)
end,
["skip spends gems only once"] = function(t)
 local E=require("../src/shared/Logic/Expedition"); local p=fresh(); local c=add(p); local key,e=E.Start(p,"Meadow","Short",{c.Uid},0,1); t.no(E.Skip(p,key,0)); p.Gems=100000; local cost=E.Skip(p,key,0); t.ok(cost); t.eq(e.EndAt,0); t.no(E.Skip(p,key,0))
end,
}
