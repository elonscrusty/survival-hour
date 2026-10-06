local Profile = require("../src/shared/Logic/Profile")
local Inventory = require("../src/shared/Logic/Inventory")
local Economy = require("../src/shared/Logic/Economy")
local Config = require("../src/shared/Config")
local function fresh() local p=Profile.Default(); p.Creatures={}; p.Index={}; return p end
local function add(p,rarity) return Inventory.Add(p,{Species="Dragon",Element="Nature",Rarity=rarity or "Common"}) end
return {
["add validates identity and unique discovery"] = function(t)
 local p=fresh(); local a,new=add(p); t.ok(new); local b,again=add(p); t.no(again); t.ok(a.Uid~=b.Uid); t.eq(a.Level,1); t.ok(p.Index["Dragon|Nature"]); t.no(Inventory.Add(p,{Species="Bad",Rarity="Common",Element="Nature"}))
end,
["capacity and uid collisions"] = function(t)
 local p=fresh(); local a=add(p); p.NextUid=0; t.ok(Inventory.NewUid(p)~=a.Uid); while Inventory.FreeSpace(p)>0 do add(p) end; t.no(add(p))
end,
["habitat and expedition creatures are busy"] = function(t)
 local p=fresh(); local a=add(p); p.Habitats["1"]={Level=1,Creature=a.Uid,Power=1,Coins=0,UpdatedAt=0}; t.ok(Inventory.IsBusy(p,a.Uid)); t.no(Inventory.Equip(p,a.Uid,true)); t.no(Inventory.Delete(p,{a.Uid})); p.Habitats={}; p.Expeditions["1"]={Creatures={a.Uid},Area="Meadow",Duration="Short",StartAt=0,EndAt=10,Seed=1}; t.ok(Inventory.IsBusy(p,a.Uid))
end,
["delete is atomic for locks blocks duplicates"] = function(t)
 local p=fresh(); local a=add(p); local b=add(p); Inventory.Lock(p,b.Uid,true); t.no(Inventory.Delete(p,{a.Uid,b.Uid})); t.eq(#p.Creatures,2); t.no(Inventory.Delete(p,{a.Uid,a.Uid})); t.no(Inventory.Delete(p,{a.Uid},{[a.Uid]=true})); t.ok(Inventory.Delete(p,{a.Uid})); t.eq(#p.Creatures,1)
end,
["equip best uses rarity and level"] = function(t)
 local p=fresh(); for _=1,6 do add(p) end; local strong=add(p,"Mythic"); Inventory.EquipBest(p); t.eq(p.Equipped[1],strong.Uid); t.eq(#p.Equipped,Economy.MaxEquip(p)); t.ok(Inventory.EquippedPower(p)>16)
end,
}
