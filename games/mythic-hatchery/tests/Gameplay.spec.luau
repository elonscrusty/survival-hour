--!strict
local Level = require("../src/shared/Logic/Level")
local Habitat = require("../src/shared/Logic/Habitat")
local Battle = require("../src/shared/Logic/Battle")
local Moves = require("../src/shared/Moves")
local Gameplay = require("../src/shared/Gameplay")

local function creature(uid: string, level: number?): Level.Creature
	return {
 Uid = uid, Species = "Dragon", Element = "Fire", Rarity = "Common", Level = level or 1, Xp = 0, Neon = false }
end
local function team(prefix: string): { Level.Creature }
	return { creature(prefix .. "1"), creature(prefix .. "2"), creature(prefix .. "3") }
end
local function battle()
	return Battle.New("test", 10, 20, team("a"), team("b"), 100)
end
return {
	["Neon improves habitat income by ten percent"] = function(t: any)
		local c=creature("neon"); c.Neon=true
		local h=Habitat.New(100); Habitat.Assign(h,c,100); Habitat.Accrue(h,200)
		t.ok(math.abs(h.Coins-11)<1e-6)
	end,

	["offline habitat boosts expire at their saved time"] = function(t: any)
		local h = Habitat.New(100) :: any
		Habitat.Assign(h, creature("income"), 100)
		h.RateMult = 3; h.BoostUntil = 150; h.BoostMult = 2
		Habitat.Accrue(h, 200)
		t.ok(math.abs(h.Coins - 45) < 1e-6)
		t.ok(math.abs(Habitat.Rate(h) - 0.3) < 1e-6)
		Habitat.Accrue(h, 250)
		t.ok(math.abs(h.Coins - 60) < 1e-6)
	end,
	["XP levels up repeatedly and caps without overflow"] = function(t: any)
		local c = creature("x")
		Level.AddXp(c, Level.XpToNext(1) + Level.XpToNext(2) + 7)
		t.eq(c.Level, 3); t.eq(c.Xp, 7)
		Level.AddXp(c, 1e12); t.eq(c.Level, Gameplay.MaxLevel); t.eq(c.Xp, 0)
	end,
	["invalid XP cannot change progression"] = function(t: any)
		local c = creature("x")
		for _, xp in { -5, 0 / 0, math.huge } do t.no(Level.AddXp(c, xp)); t.eq(c.Level, 1); t.eq(c.Xp, 0) end
	end,
	["rarity and levels substantially increase power"] = function(t: any)
		local c = creature("x")
		local initial = Level.Power(c)
		c.Level = 20; t.ok(Level.Power(c) > initial * 3)
		c.Rarity = "Mythic"; t.ok(Level.Power(c) > initial * 16)
	end,
	["habitat earns offline up to capacity and never gives XP"] = function(t: any)
		local c = creature("x")
		local slot = Habitat.New(100)
		t.ok(Habitat.Assign(slot, c, 100))
		Habitat.Accrue(slot, 100 + 1e6)
		t.eq(slot.Coins, Habitat.Capacity(slot)); t.eq(c.Xp, 0); t.eq(c.Level, 1)
	end,
	["collect is repeat safe and keeps fractional coins"] = function(t: any)
		local slot = Habitat.New(100)
		t.ok(Habitat.Assign(slot, creature("x"), 100))
		local expected = math.floor(Habitat.Rate(slot) * 13)
		t.eq(Habitat.Collect(slot, 113), expected); t.eq(Habitat.Collect(slot, 113), 0)
	end,
	["removing creature settles earned coins and stops production"] = function(t: any)
		local slot = Habitat.New(100)
		t.ok(Habitat.Assign(slot, creature("x"), 100))
		Habitat.Remove(slot, 120)
		local coins = slot.Coins
		Habitat.Accrue(slot, 500); t.eq(slot.Coins, coins); t.eq(slot.Creature, nil)
	end,
	["clock rollback cannot mint habitat coins"] = function(t: any)
		local slot = Habitat.New(100)
		t.ok(Habitat.Assign(slot, creature("x"), 100))
		Habitat.Accrue(slot, 90); Habitat.Accrue(slot, 100); t.eq(slot.Coins, 0)
	end,
	["upgrade settles at old rate then improves income and storage"] = function(t: any)
		local slot = Habitat.New(100)
		t.ok(Habitat.Assign(slot, creature("x"), 100))
		local oldRate, oldCap = Habitat.Rate(slot), Habitat.Capacity(slot)
		local cost = Habitat.UpgradeCost(slot)
		local ok, spent = Habitat.Upgrade(slot, cost, 120)
		t.ok(ok); t.eq(spent, cost); t.eq(slot.Coins, oldRate * 20)
		t.ok(Habitat.Rate(slot) > oldRate); t.ok(Habitat.Capacity(slot) > oldCap)
	end,
	["failed upgrade does not spend or upgrade"] = function(t: any)
		local slot = Habitat.New(100)
		t.no(Habitat.Upgrade(slot, 0, 120)); t.eq(slot.Level, 1)
	end,
	["cannot replace occupied habitat assignment"] = function(t: any)
		local slot = Habitat.New(100)
		t.ok(Habitat.Assign(slot, creature("a"), 100)); t.no(Habitat.Assign(slot, creature("b"), 100))
		t.eq(slot.Creature, "a")
	end,
	["two starting moves unlock additional moves with battle levels"] = function(t: any)
		local c = creature("x")
		t.eq(#Moves.For(c), 2)
		c.Level = Gameplay.MaxLevel; t.eq(#Moves.For(c), 6)
	end,
	["one shared move cooldown blocks every other move"] = function(t: any)
		local b = battle()
		local moves = Moves.For(creature("x"))
		t.ok(Battle.Move(b, 10, moves[1].Id, 100))
		t.no(Battle.Move(b, 10, moves[2].Id, 100.5))
		t.ok(Battle.Move(b, 10, moves[2].Id, 100 + Gameplay.Battle.MoveCooldown))
	end,
	["opponents command independently in real time"] = function(t: any)
		local b = battle()
		local move = Moves.For(creature("x"))[1].Id
		t.ok(Battle.Move(b, 10, move, 100)); t.ok(Battle.Move(b, 20, move, 100))
	end,
	["swaps have a separate longer cooldown and preserve move cooldown"] = function(t: any)
		local b = battle()
		local move = Moves.For(creature("x"))[1].Id
		t.ok(Battle.Move(b, 10, move, 100)); t.ok(Battle.Swap(b, 10, 2, 100))
		t.no(Battle.Move(b, 10, move, 100)); t.no(Battle.Swap(b, 10, 3, 101))
		t.ok(Battle.Swap(b, 10, 3, 100 + Gameplay.Battle.SwapCooldown))
	end,
	["unknown locked moves and outsiders cannot deal damage"] = function(t: any)
		local b = battle()
		local before = b.Sides[2].Fighters[1].Hp
		t.no(Battle.Move(b, 99, "Strike", 100)); t.no(Battle.Move(b, 10, "madeup", 100))
		local high = creature("x", Gameplay.MaxLevel)
		t.no(Battle.Move(b, 10, Moves.For(high)[6].Id, 100))
		t.eq(b.Sides[2].Fighters[1].Hp, before)
	end,
	["invalid times and swaps leave state unchanged"] = function(t: any)
		local b = battle()
		t.no(Battle.Swap(b, 10, 0 / 0, 100)); t.no(Battle.Swap(b, 10, 1.5, 100))
		t.no(Battle.Move(b, 10, Moves.For(creature("x"))[1].Id, math.huge))
		t.no(Battle.Move(b, 10, Moves.For(creature("x"))[1].Id, 99))
		t.eq(b.Sides[1].Active, 1)
	end,
	["XP only goes to participants and more contribution gets more"] = function(t: any)
		local b = battle()
		local side = b.Sides[1]
		side.Fighters[1].Contribution = 100
		side.Fighters[2].Entered = true; side.Fighters[2].Contribution = 10
		Battle.Forfeit(b, 20, 110)
		local reward = Battle.Reward(b, 10)
		t.ok(reward ~= nil)
		local r = reward :: Battle.Reward
		t.ok(r.Xp.a1 > r.Xp.a2); t.eq(r.Xp.a3, nil)
		local total = 0; for _, xp in r.Xp do total += xp end
		t.eq(total, Gameplay.Battle.WinXp)
	end,
	["winner and loser rewards include coins and arena points"] = function(t: any)
		local b = battle(); Battle.Forfeit(b, 20, 110)
		local win = Battle.Reward(b, 10) :: Battle.Reward
		local lose = Battle.Reward(b, 20) :: Battle.Reward
		t.ok(win.Coins > lose.Coins); t.ok(lose.Coins > 0)
		t.ok(win.Points > 0); t.ok(lose.Points < 0)
		t.no(Battle.Move(b, 10, Moves.For(creature("x"))[1].Id, 111))
	end,
	["matching compares the complete selected team"] = function(t: any)
		t.ok(Battle.CanMatch(team("a"), team("b")))
		local strong = team("b"); strong[3].Level = Gameplay.MaxLevel; strong[3].Rarity = "Mythic"
		t.no(Battle.CanMatch(team("a"), strong))
	end,
	["duplicate team uids are refused"] = function(t: any)
		local duplicate = team("a"); duplicate[2].Uid = duplicate[1].Uid
		t.no(pcall(function() Battle.New("test", 10, 20, duplicate, team("b"), 100) end))
	end,
}
