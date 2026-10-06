local Profile = require("../src/shared/Logic/Profile")
local Inventory = require("../src/shared/Logic/Inventory")
local Economy = require("../src/shared/Logic/Economy")
local Config = require("../src/shared/Config")
local function fresh() local p=Profile.Default(); p.Creatures={}; p.Index={}; return p end
local function add(p,rarity) return Inventory.Add(p,{Species="Dragon",Element="Nature",Rarity=rarity or "Common"}) end
return {
["trade swaps preserves level potions and replays once"] = function(t)
 local T=require("../src/shared/Logic/Trade"); local a,b=fresh(),fresh(); local ca=add(a); local cb=add(b,"Rare"); cb.Level=8; cb.Potions.Ride=true; local tr=T.New("trade",1,"A",2,"B"); t.ok(T.SetOffer(tr,1,a,{ca.Uid},0)); t.ok(T.SetOffer(tr,2,b,{cb.Uid},0)); t.ok(T.SetReady(tr,1,true,0)); t.ok(T.SetReady(tr,2,true,0)); local plan=T.Plan(tr,a,b); t.ok(plan); local j=T.Journal(tr,plan); t.ok(T.ApplySide(a,j.Sides["1"],"trade")); t.no(T.ApplySide(a,j.Sides["1"],"trade")); t.eq(#a.Creatures,1); t.eq(a.Creatures[1].Level,8); t.ok(a.Creatures[1].Potions.Ride)
end,
["busy locked duplicate and gem offers reject"] = function(t)
 local T=require("../src/shared/Logic/Trade"); local p=fresh(); local c=add(p); t.no(T.ValidateOffer(p,{c.Uid,c.Uid},0)); t.no(T.ValidateOffer(p,{c.Uid},1)); c.Locked=true; t.no(T.ValidateOffer(p,{c.Uid},0)); c.Locked=false; p.Habitats["1"]={Level=1,Creature=c.Uid,Power=1,Coins=0,UpdatedAt=0}; t.no(T.ValidateOffer(p,{c.Uid},0))
end,
["offer mutation resets confirmation and journal sanitize grants no starter"] = function(t)
 local T=require("../src/shared/Logic/Trade"); local p=fresh(); local c=add(p); local tr=T.New("t",1,"A",2,"B"); T.SetOffer(tr,1,p,{c.Uid},0); T.SetReady(tr,1,true,0); T.SetReady(tr,2,true,0); T.SetOffer(tr,1,p,{},0); t.eq(tr.Status,"Open"); t.no(tr.Sides[2].Ready); local side=T.SanitizeSide({Give={},Get={c,{Species="Bad"}},GiveGems=0,GetGems=0}); t.eq(#side.Get,1); t.eq(side.Get[1].Uid,c.Uid)
end,
["transfers strip worn cosmetics but preserve progression and ownership"] = function(t)
 local T=require("../src/shared/Logic/Trade"); local a,b=fresh(),fresh(); local c=add(a); c.Cosmetics={Hat="Crown"}; c.Potions.Fly=true; c.Level=5; c.Xp=10; a.Cosmetics.Crown=true
 local tr=T.New("cosmetics",1,"A",2,"B"); T.SetOffer(tr,1,a,{c.Uid},0); T.SetReady(tr,1,true,0); T.SetReady(tr,2,true,0)
 local plan=T.Plan(tr,a,b); t.ok(plan); t.no(next(plan.B.Received[1].Cosmetics)); local j=T.Journal(tr,plan); local side=T.SanitizeSide(j.Sides["2"]); t.no(next(side.Get[1].Cosmetics)); side.Get[1].Cosmetics={Hat="Crown"}; T.ApplySide(b,side,"cosmetics")
 t.no(next(b.Creatures[1].Cosmetics)); t.eq(b.Creatures[1].Level,5); t.eq(b.Creatures[1].Xp,10); t.ok(b.Creatures[1].Potions.Fly); t.ok(a.Cosmetics.Crown); t.no(b.Cosmetics.Crown); t.eq(c.Cosmetics.Hat,"Crown"); local saved=Profile.Sanitize(a); t.ok(saved.Cosmetics.Crown); t.eq(saved.Creatures[1].Cosmetics.Hat,"Crown")
end,

}
