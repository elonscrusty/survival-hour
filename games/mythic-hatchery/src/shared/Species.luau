--!strict
-- Creature species. Data-driven: adding a species is a new entry here plus a
-- model in models/ (gen_models.py builds every stage and element from it).
-- Hybrids are hidden species that only come from cross-species fusion of their
-- two Parents; they never appear in egg odds and show as "???" in the Index
-- until discovered.

export type Species = {
	Id: string,
	Name: string,
	Flier: boolean, -- has wings (flies with the Fly potion; the rest "sky-swim")
	Hybrid: boolean,
	Parents: { string }?, -- hybrids only
	Look: string, -- art brief for the model generator
}

local Species = {}

Species.List = {
	{ Id = "Dragon", Name = "Dragon", Flier = true, Hybrid = false, Look = "classic dragon: horns, wings, spiky tail, chunky legs" },
	{ Id = "Griffin", Name = "Griffin", Flier = true, Hybrid = false, Look = "eagle head and wings, lion body and tail tuft" },
	{ Id = "Phoenix", Name = "Phoenix", Flier = true, Hybrid = false, Look = "big bird with a crest and long flowing tail feathers" },
	{ Id = "Hydra", Name = "Hydra", Flier = false, Hybrid = false, Look = "sturdy serpent body with three necks and heads, fins" },
	{ Id = "Unicorn", Name = "Unicorn", Flier = false, Hybrid = false, Look = "horse with a spiral horn, flowing mane and tail" },

	-- Hidden hybrids (cross-species fusion only).
	{ Id = "Wyvern", Name = "Wyvern", Flier = true, Hybrid = true, Parents = { "Dragon", "Griffin" }, Look = "dragon head and tail on a griffin's feathered wings and lion legs" },
	{ Id = "Emberwyrm", Name = "Emberwyrm", Flier = true, Hybrid = true, Parents = { "Dragon", "Phoenix" }, Look = "slim dragon with phoenix tail plumes and a feather crest" },
	{ Id = "Pegasus", Name = "Pegasus", Flier = true, Hybrid = true, Parents = { "Griffin", "Unicorn" }, Look = "winged horse with a short horn and eagle-feather wings" },
	{ Id = "Leviathan", Name = "Leviathan", Flier = false, Hybrid = true, Parents = { "Hydra", "Dragon" }, Look = "huge single-headed sea serpent with dragon horns and fin wings" },
	{ Id = "Chimera", Name = "Chimera", Flier = true, Hybrid = true, Parents = { "Griffin", "Hydra" }, Look = "lion body, eagle wings and a serpent-headed tail" },
	{ Id = "Solaris", Name = "Solaris", Flier = true, Hybrid = true, Parents = { "Phoenix", "Unicorn" }, Look = "glowing horse with a flame mane, horn and feathered wings" },
} :: { Species }

Species.ById = {} :: { [string]: Species }
Species.Base = {} :: { Species } -- non-hybrids, in list order
Species.HybridOf = {} :: { [string]: string } -- "A|B" (sorted) -> hybrid id

local function pairKey(a: string, b: string): string
	if a > b then
		a, b = b, a
	end
	return a .. "|" .. b
end

for _, s in Species.List do
	Species.ById[s.Id] = s
	if s.Hybrid then
		local p = s.Parents :: { string }
		Species.HybridOf[pairKey(p[1], p[2])] = s.Id
	else
		table.insert(Species.Base, s)
	end
end

-- The hidden hybrid for two parent species, or nil.
function Species.Hybrid(a: string, b: string): string?
	if a == b then
		return nil
	end
	return Species.HybridOf[pairKey(a, b)]
end

return Species
