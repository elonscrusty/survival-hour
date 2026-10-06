local Profile = require("../src/shared/Logic/Profile")
local Inventory = require("../src/shared/Logic/Inventory")
local Economy = require("../src/shared/Logic/Economy")
local Config = require("../src/shared/Config")
local function fresh() local p=Profile.Default(); p.Creatures={}; p.Index={}; return p end
local function add(p,rarity) return Inventory.Add(p,{Species="Dragon",Element="Nature",Rarity=rarity or "Common"}) end
return {
["starter is persisted exactly once and rides immediately"] = function(t)
 local p=Profile.Default(); t.eq(#p.Creatures,1); local c=p.Creatures[1]; t.eq(c.Species,"Dragon"); t.eq(c.Element,"Nature"); t.eq(c.Rarity,"Common"); t.eq(c.Level,1); t.ok(c.Potions.Ride); t.ok(c.Potions.Fly); t.no(Profile.GrantStarter(p)); local q=Profile.Sanitize(p); t.eq(#q.Creatures,1); t.eq(q.Creatures[1].Uid,c.Uid); q.Creatures={}; t.eq(#Profile.Sanitize(q).Creatures,0)
end,
["corrupt profile clamps and removes duplicates"] = function(t)
 local p=fresh(); local c=add(p); local raw=table.clone(p); raw.Coins=0/0; raw.Creatures={c,c,{Species="Bad"}}; local q=Profile.Sanitize(raw); t.eq(q.Coins,0); t.eq(#q.Creatures,2); t.ok(q.Creatures[1].Uid~=q.Creatures[2].Uid)
end,
["habitat roundtrip preserves capped storage and busy ownership"] = function(t)
 local p=Profile.Default(); local c=p.Creatures[1]; p.Habitats["1"]={Level=2,Creature=c.Uid,Power=99999,Coins=1e15,UpdatedAt=100}; p.Habitats["2"]={Level=1,Creature=c.Uid,Power=1,Coins=0,UpdatedAt=100}; local q=Profile.Sanitize(p); t.eq(q.Habitats["1"].Creature,c.Uid); t.eq(q.Habitats["1"].Power,1); t.no(q.Habitats["2"].Creature); t.eq(q.Habitats["1"].Coins,7200)
end,
["receipts dedupe bound and trade guards survive"] = function(t)
 local p=Profile.Default(); for i=1,120 do Profile.RecordReceipt(p,tostring(i),i) end; t.no(Profile.HasReceipt(p,"1")); t.ok(Profile.HasReceipt(p,"120")); p.PendingTrade="trade"; p.AppliedTrades={"done"}; local q=Profile.Sanitize(p); t.eq(q.PendingTrade,"trade"); t.eq(q.AppliedTrades[1],"done")
end,
["state copies creatures habitats and conceals incubator seed"] = function(t)
 local p=Profile.Default(); p.Incubators["1"]={Egg={Uid="egg1",Egg="MeadowEgg",Tier=1},StartAt=0,EndAt=60,Seed=123,Luck=1}; local s=Profile.BuildState(p,{Now=10}); t.eq(s.Incubators["1"].Seed,0); s.Creatures[1].Potions.Ride=false; t.ok(p.Creatures[1].Potions.Ride); s.Habitats["1"]={Level=9,Power=0,Coins=0,UpdatedAt=0}; t.eq(p.Habitats["1"].Level,1)
end,
["fused eggs and incubators round trip with copied odds"] = function(t)
 local F=require("../src/shared/Logic/Fusion"); local p=Profile.Default(); local a=p.Creatures[1]; local b=Inventory.Add(p,{Species="Griffin",Rarity="Rare",Element="Fire"}); local plan=F.Prepare(a,b,"fused1",{},100000,1,10); t.ok(plan); table.insert(p.EggBag,plan.Egg); local q=Profile.Sanitize(p); t.eq(#q.EggBag,1); t.eq(q.EggBag[1].Fused.Hybrid,"Wyvern"); local state=Profile.BuildState(q,{Now=1}); state.EggBag[1].Fused.Species[1].Weight=99; t.ok(q.EggBag[1].Fused.Species[1].Weight~=99)
end,
["purchased hatch slots and battle stats persist"] = function(t)
 local p=Profile.Default(); p.Passes.HatchSlots=true; p.Stats.Battles=7; p.Stats.BattleWins=3
 for i=4,5 do p.Incubators[tostring(i)]={Egg={Uid="egg" .. i,Egg="MeadowEgg",Tier=1},StartAt=100,EndAt=160,Seed=i,Luck=2} end
 local q=Profile.Sanitize(p); t.eq(q.HatchSlots,5); t.ok(q.Incubators["4"]); t.ok(q.Incubators["5"]); t.no(q.Incubators[4]); t.ok(q.Habitats["1"]); t.no(q.Habitats[1]); t.eq(q.Stats.Battles,7); t.eq(q.Stats.BattleWins,3)
 local state=Profile.BuildState(q,{Now=120}); t.eq(state.HatchSlots,5); t.eq(state.Stats.Battles,7); t.eq(state.Stats.BattleWins,3); t.eq(state.Incubators["5"].Seed,0)
 q.Passes.HatchSlots=nil; t.eq(Profile.BuildState(q,{Now=120}).HatchSlots,3); local r=Profile.Sanitize(q); t.ok(r.Incubators["5"],"occupied egg survives pass refresh")
end,

["habitat multiplier snapshots survive reload through boost expiry"] = function(t)
 local p=Profile.Default(); local c=p.Creatures[1]; p.Habitats["1"]={Level=1,Creature=c.Uid,Power=999,Coins=5,UpdatedAt=100,BasePower=999,RateMult=3,BoostMult=2,BoostUntil=150}
 local q=Profile.Sanitize(p); t.eq(q.Habitats["1"].BasePower,1); t.eq(q.Habitats["1"].Power,1); t.eq(q.Habitats["1"].RateMult,3); t.eq(q.Habitats["1"].BoostUntil,150)
 local H=require("../src/shared/Logic/Habitat"); H.Accrue(q.Habitats["1"],160); t.eq(math.floor(q.Habitats["1"].Coins*100+0.5),3800); local r=Profile.Sanitize(q); t.eq(r.Habitats["1"].Power,1)
end,

["retired quest kinds regenerate current tasks"] = function(t)
 local R=require("../src/shared/Logic/Rewards")
 for _,kind in {"Care","Race","Break"} do
  local p=Profile.Default(); p.Quests={Day=20000,List={{Kind=kind,Goal=5,Progress=2,Gems=1,Claimed=false}}}; local q=Profile.Sanitize(p); t.eq(q.Quests.Day,-1); t.eq(#q.Quests.List,0); t.ok(R.EnsureQuests(q,20000)); for _,quest in q.Quests.List do t.ok(quest.Kind~=kind) end
 end
end,

}
