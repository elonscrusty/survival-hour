local Profile = require("../src/shared/Logic/Profile")
local Inventory = require("../src/shared/Logic/Inventory")
local Economy = require("../src/shared/Logic/Economy")
local Config = require("../src/shared/Config")
local function fresh() local p=Profile.Default(); p.Creatures={}; p.Index={}; return p end
local function add(p,rarity) return Inventory.Add(p,{Species="Dragon",Element="Nature",Rarity=rarity or "Common"}) end
return {
["rarity and level control power"] = function(t)
 local M=require("../src/shared/Logic/PetMath"); local p=fresh(); local c=add(p); local d=add(p,"Mythic"); t.ok(M.Power(d)>M.Power(c)); local old=M.Power(c); c.Level=10; t.ok(M.Power(c)>old)
end,
["xp levels up and caps without growth"] = function(t)
 local M=require("../src/shared/Logic/PetMath"); local p=fresh(); local c=add(p); t.eq(M.AddXp(c,M.XpToNext(1)),1); t.eq(c.Level,2); t.eq(c.Xp,0); t.eq(M.AddXp(c,0/0),0); M.AddXp(c,1e12); t.eq(c.Level,50); t.eq(c.Xp,0)
end,
["stable sort and refund"] = function(t) local M=require("../src/shared/Logic/PetMath"); local p=fresh(); local a=add(p); local b=add(p); t.eq(M.Stronger(a,b),a.Uid<b.Uid); t.ok(M.DeleteRefund(a)>=1) end,
}
