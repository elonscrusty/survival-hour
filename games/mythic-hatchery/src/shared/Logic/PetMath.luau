--!strict
local Config = require("../Config")
local Level = require("./Level")
local Schema = require("./Schema")
type Creature = Schema.Creature
local PetMath = {}
function PetMath.RarityIndex(rarity: string): number return table.find(Config.Rarities, rarity) or 0 end
function PetMath.Power(c: Creature, _scaleArea: string?): number
 return Level.Power({Uid=c.Uid, Species=c.Species, Element=c.Element, Rarity=c.Rarity, Level=c.Level, Xp=c.Xp, Neon=c.Potions.Neon == true})
end
PetMath.XpToNext = Level.XpToNext
function PetMath.AddXp(c: Creature, xp: number): number
 if not Schema.IsFinite(xp) or xp <= 0 then return 0 end
 local old = c.Level
 local snapshot = {Uid=c.Uid, Species=c.Species, Element=c.Element, Rarity=c.Rarity, Level=c.Level, Xp=c.Xp, Neon=c.Potions.Neon == true}
 Level.AddXp(snapshot, xp); c.Level=snapshot.Level; c.Xp=snapshot.Xp
 return c.Level-old
end
function PetMath.DeleteRefund(c: Creature): number return math.max(1, math.floor(PetMath.Power(c) * Config.DeleteRefund)) end
function PetMath.StrongerAt(_scaleArea: string?): (Creature, Creature) -> boolean
 return function(a: Creature,b: Creature): boolean local pa,pb=PetMath.Power(a),PetMath.Power(b); return if pa==pb then a.Uid<b.Uid else pa>pb end
end
PetMath.Stronger = PetMath.StrongerAt(nil)
return PetMath
