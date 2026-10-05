-- Pet species. Models are built from simple parts (see server PetModel), so no
-- uploads are needed: each species picks a body shape, colours and extras.
export type Species = {
	Id: string,
	Name: string,
	Rarity: string,
	Body: { number }, -- body size {x, y, z} at size 1
	Head: number,
	Legs: number, -- leg height
	Color: { number },
	Accent: { number },
	Ears: string?, -- "Point" | "Long" | "Round" | nil
	Tail: string?, -- "Short" | "Long" | "Fluffy" | nil
	Horn: boolean?,
	Wings: boolean?,
	Neon: boolean?,
}

local Pets = {}

Pets.Rarities = {
	Common = { Refund = 5, Rank = 1, Bonus = 0.00, Color = { 200, 200, 200 } },
	Uncommon = { Refund = 15, Rank = 2, Bonus = 0.02, Color = { 90, 210, 90 } },
	Rare = { Refund = 40, Rank = 3, Bonus = 0.04, Color = { 70, 150, 255 } },
	Epic = { Refund = 100, Rank = 4, Bonus = 0.06, Color = { 180, 90, 255 } },
	Legendary = { Refund = 250, Rank = 5, Bonus = 0.08, Color = { 255, 180, 40 } },
	Mythic = { Refund = 600, Rank = 6, Bonus = 0.10, Color = { 255, 70, 140 } },
}

local list: { Species } = {
	{ Id = "Pup", Name = "Pup", Rarity = "Common", Body = { 3.4, 2.6, 4.2 }, Head = 3.4, Legs = 1.2, Color = { 205, 140, 80 }, Accent = { 255, 228, 190 }, Ears = "Round", Tail = "Short" },
	{ Id = "Kitty", Name = "Kitty", Rarity = "Common", Body = { 3.2, 2.4, 4.2 }, Head = 3.3, Legs = 1.2, Color = { 255, 160, 60 }, Accent = { 255, 242, 225 }, Ears = "Point", Tail = "Long" },
	{ Id = "Bunny", Name = "Bunny", Rarity = "Common", Body = { 3.2, 2.8, 3.8 }, Head = 3.3, Legs = 1, Color = { 250, 250, 255 }, Accent = { 255, 160, 205 }, Ears = "Long", Tail = "Fluffy" },
	{ Id = "Piggy", Name = "Piggy", Rarity = "Uncommon", Body = { 3.8, 2.8, 4.4 }, Head = 3.4, Legs = 1, Color = { 255, 160, 190 }, Accent = { 255, 105, 150 }, Ears = "Round", Tail = "Short" },
	{ Id = "Fox", Name = "Fox", Rarity = "Uncommon", Body = { 3.2, 2.4, 4.6 }, Head = 3.2, Legs = 1.3, Color = { 255, 115, 30 }, Accent = { 255, 255, 255 }, Ears = "Point", Tail = "Fluffy" },
	{ Id = "Penguin", Name = "Penguin", Rarity = "Uncommon", Body = { 3.4, 3.4, 3.2 }, Head = 3.2, Legs = 0.9, Color = { 45, 60, 105 }, Accent = { 255, 255, 255 }, Tail = "Short" },
	{ Id = "Panda", Name = "Panda", Rarity = "Rare", Body = { 4, 3, 4.6 }, Head = 3.6, Legs = 1.2, Color = { 255, 255, 255 }, Accent = { 35, 35, 45 }, Ears = "Round", Tail = "Short" },
	{ Id = "Deer", Name = "Deer", Rarity = "Rare", Body = { 3.2, 2.6, 4.8 }, Head = 3.1, Legs = 1.8, Color = { 205, 125, 65 }, Accent = { 255, 238, 205 }, Ears = "Point", Tail = "Short", Horn = true },
	{ Id = "Wolf", Name = "Wolf", Rarity = "Rare", Body = { 3.6, 2.8, 5 }, Head = 3.4, Legs = 1.5, Color = { 125, 150, 205 }, Accent = { 240, 246, 255 }, Ears = "Point", Tail = "Fluffy" },
	{ Id = "Tiger", Name = "Tiger", Rarity = "Epic", Body = { 3.8, 3, 5.2 }, Head = 3.6, Legs = 1.5, Color = { 255, 145, 20 }, Accent = { 40, 25, 30 }, Ears = "Round", Tail = "Long" },
	{ Id = "Unicorn", Name = "Unicorn", Rarity = "Epic", Body = { 3.6, 3, 5.2 }, Head = 3.4, Legs = 1.9, Color = { 255, 246, 255 }, Accent = { 255, 115, 215 }, Ears = "Point", Tail = "Long", Horn = true },
	{ Id = "Griffin", Name = "Griffin", Rarity = "Legendary", Body = { 4, 3.2, 5.4 }, Head = 3.5, Legs = 1.7, Color = { 245, 190, 90 }, Accent = { 255, 255, 255 }, Ears = "Point", Tail = "Long", Wings = true },
	{ Id = "Dragon", Name = "Dragon", Rarity = "Legendary", Body = { 4.4, 3.4, 6 }, Head = 3.8, Legs = 1.6, Color = { 70, 210, 110 }, Accent = { 255, 215, 60 }, Tail = "Long", Horn = true, Wings = true },
	{ Id = "Phoenix", Name = "Phoenix", Rarity = "Mythic", Body = { 4, 3.2, 5 }, Head = 3.5, Legs = 1.6, Color = { 255, 80, 40 }, Accent = { 255, 225, 50 }, Tail = "Fluffy", Wings = true, Neon = true },
	{ Id = "Cosmic Cat", Name = "Cosmic Cat", Rarity = "Mythic", Body = { 3.8, 3, 5 }, Head = 3.6, Legs = 1.6, Color = { 95, 55, 210 }, Accent = { 110, 255, 255 }, Ears = "Point", Tail = "Long", Neon = true },
}

Pets.List = list
Pets.ById = {} :: { [string]: Species }
for _, s in list do
	Pets.ById[s.Id] = s
end

function Pets.RarityOf(id: string): string
	local s = Pets.ById[id]
	return s and s.Rarity or "Common"
end

function Pets.Rank(id: string): number
	return Pets.Rarities[Pets.RarityOf(id)].Rank
end

return Pets
