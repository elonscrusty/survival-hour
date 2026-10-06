--!strict
local Battle = require("../src/shared/Logic/Battle")
local Level = require("../src/shared/Logic/Level")
local Gameplay = require("../src/shared/Gameplay")
local function team(prefix: string, species: string?, level: number?): { Level.Creature }
	local result: { Level.Creature } = {}
	for i = 1, 3 do table.insert(result, { Uid = prefix .. i, Species = species or "Dragon", Element = "Fire", Rarity = "Common", Level = level or 1, Xp = 0, Neon = false }) end
	return result
end
return {
	["knockout switches reserve and defeating all three ends battle"] = function(t: any)
		local b = Battle.New("ko", 1, 2, team("a"), team("b"), 100)
		for i = 1, 3 do
			b.Sides[2].Fighters[i].Hp = 1
			t.ok(Battle.Move(b, 1, "Dragon:1", 100 + (i - 1) * Gameplay.Battle.MoveCooldown))
			t.eq(b.Sides[2].Fighters[i].Hp, 0)
		end
		t.eq(b.Status, "Done"); t.eq(b.Winner, 1)
	end,
	["damage contribution excludes overkill"] = function(t: any)
		local b = Battle.New("damage", 1, 2, team("a"), team("b"), 100)
		b.Sides[2].Fighters[1].Hp = 1
		Battle.Move(b, 1, "Dragon:1", 100)
		t.eq(b.Sides[1].Fighters[1].Contribution, 1)
	end,
	["healing contribution excludes overhealing"] = function(t: any)
		local b = Battle.New("heal", 1, 2, team("a", "Phoenix", 10), team("b"), 100)
		local f = b.Sides[1].Fighters[1]; f.Hp = f.MaxHp - 3
		t.ok(Battle.Move(b, 1, "Phoenix:3", 100)); t.eq(f.Hp, f.MaxHp); t.eq(f.Contribution, 3)
		t.no(Battle.Move(b, 1, "Phoenix:3", 102))
	end,
	["shield earns contribution only when damage is absorbed"] = function(t: any)
		local b = Battle.New("shield", 1, 2, team("a", "Dragon", 20), team("b"), 100)
		local f = b.Sides[1].Fighters[1]
		t.ok(Battle.Move(b, 1, "Dragon:4", 100)); t.eq(f.Contribution, 0)
		Battle.Move(b, 2, "Dragon:1", 100); t.eq(f.Hp, f.MaxHp); t.ok(f.Contribution > 0)
	end,
	["timeout is server controlled and draws do not lose points"] = function(t: any)
		local b = Battle.New("timeout", 1, 2, team("a"), team("b"), 100)
		t.no(Battle.Timeout(b, 101)); t.ok(Battle.Timeout(b, 100 + Gameplay.Battle.MaxSeconds))
		t.eq(b.Winner, nil); t.eq((Battle.Reward(b, 1) :: Battle.Reward).Points, 0)
		t.no(Battle.Timeout(b, 100 + Gameplay.Battle.MaxSeconds))
	end,
	["battle snapshots do not mutate owned creatures"] = function(t: any)
		local original = team("a")
		local b = Battle.New("copy", 1, 2, original, team("b"), 100)
		b.Sides[1].Fighters[1].Creature.Level = 10
		t.eq(original[1].Level, 1)
	end,
}
