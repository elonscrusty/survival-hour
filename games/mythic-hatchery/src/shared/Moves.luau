--!strict
local Gameplay = require("./Gameplay")
local Species = require("./Species")
local Elements = require("./Elements")
local Level = require("./Logic/Level")
export type Move = { Id: string, Name: string, Kind: string, Power: number, UnlockLevel: number, Element: string? }
local Moves = {}
local names: { [string]: { string } } = {
	Dragon = { "Claw", "Wing Slam", "Dragon Roar", "Scale Guard", "Dragon Fury" },
	Griffin = { "Talon", "Eagle Dive", "Lion Roar", "Feather Guard", "Sky Pounce" },
	Phoenix = { "Peck", "Feather Burst", "Renewal", "Wing Guard", "Phoenix Flare" },
	Hydra = { "Bite", "Triple Strike", "Regenerate", "Coil Guard", "Hydra Rampage" },
	Unicorn = { "Horn Strike", "Hoof Kick", "Restoration", "Magic Guard", "Horn Burst" },
	Wyvern = { "Talon Bite", "Wing Dive", "Wyvern Roar", "Scale Guard", "Wyvern Fury" },
	Emberwyrm = { "Claw", "Plume Burst", "Renewal", "Feather Guard", "Ember Fury" },
	Pegasus = { "Hoof Strike", "Wing Dive", "Restoration", "Magic Guard", "Sky Charge" },
	Leviathan = { "Bite", "Tail Slam", "Regenerate", "Scale Guard", "Serpent Fury" },
	Chimera = { "Claw", "Serpent Bite", "Chimera Roar", "Wing Guard", "Triple Fury" },
	Solaris = { "Horn Strike", "Plume Burst", "Renewal", "Magic Guard", "Solar Burst" },
}
function Moves.For(c: Level.Creature): { Move }
	assert(Species.ById[c.Species] ~= nil and Elements.ById[c.Element] ~= nil, "Unknown creature")
	local labels = names[c.Species]
	local heal = c.Species == "Phoenix" or c.Species == "Hydra" or c.Species == "Unicorn" or c.Species == "Emberwyrm" or c.Species == "Pegasus" or c.Species == "Leviathan" or c.Species == "Solaris"
	local all: { Move } = {
		{ Id = c.Species .. ":1", Name = labels[1], Kind = "Damage", Power = 1, UnlockLevel = 1 },
		{ Id = "Element:" .. c.Element, Name = c.Element .. " Blast", Kind = "Damage", Power = 1, UnlockLevel = 1, Element = c.Element },
		{ Id = c.Species .. ":2", Name = labels[2], Kind = "Damage", Power = 1.15, UnlockLevel = 5 },
		{ Id = c.Species .. ":3", Name = labels[3], Kind = if heal then "Heal" else "Damage", Power = if heal then 0.8 else 1.3, UnlockLevel = 10 },
		{ Id = c.Species .. ":4", Name = labels[4], Kind = "Guard", Power = 0.8, UnlockLevel = 20 },
		{ Id = c.Species .. ":5", Name = labels[5], Kind = "Damage", Power = 1.6, UnlockLevel = 35 },
	}
	local out: { Move } = {}
	for i, move in all do
		move.UnlockLevel = Gameplay.MoveLevels[i]
		if c.Level >= move.UnlockLevel then table.insert(out, move) end
	end
	return out
end
return Moves
