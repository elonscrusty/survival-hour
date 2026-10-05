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
	{ Id = "Pup", Name = "Pup", Rarity = "Common", Body = { 2.2, 1.6, 3.2 }, Head = 1.5, Legs = 1.2, Color = { 196, 150, 100 }, Accent = { 120, 80, 50 }, Ears = "Round", Tail = "Short" },
	{ Id = "Kitty", Name = "Kitty", Rarity = "Common", Body = { 2, 1.5, 3 }, Head = 1.4, Legs = 1.1, Color = { 255, 170, 80 }, Accent = { 255, 240, 220 }, Ears = "Point", Tail = "Long" },
	{ Id = "Bunny", Name = "Bunny", Rarity = "Common", Body = { 2, 1.8, 2.6 }, Head = 1.4, Legs = 0.9, Color = { 245, 245, 245 }, Accent = { 255, 180, 200 }, Ears = "Long", Tail = "Fluffy" },
	{ Id = "Piggy", Name = "Piggy", Rarity = "Uncommon", Body = { 2.6, 1.9, 3.2 }, Head = 1.6, Legs = 0.9, Color = { 255, 175, 190 }, Accent = { 230, 120, 140 }, Ears = "Round", Tail = "Short" },
	{ Id = "Fox", Name = "Fox", Rarity = "Uncommon", Body = { 2, 1.5, 3.4 }, Head = 1.4, Legs = 1.3, Color = { 235, 110, 40 }, Accent = { 255, 255, 255 }, Ears = "Point", Tail = "Fluffy" },
	{ Id = "Penguin", Name = "Penguin", Rarity = "Uncommon", Body = { 2.2, 2.4, 2.2 }, Head = 1.5, Legs = 0.7, Color = { 40, 40, 50 }, Accent = { 250, 250, 250 }, Tail = "Short" },
	{ Id = "Panda", Name = "Panda", Rarity = "Rare", Body = { 2.8, 2.2, 3.4 }, Head = 1.8, Legs = 1.1, Color = { 245, 245, 245 }, Accent = { 30, 30, 30 }, Ears = "Round", Tail = "Short" },
	{ Id = "Deer", Name = "Deer", Rarity = "Rare", Body = { 2, 1.7, 3.6 }, Head = 1.3, Legs = 2, Color = { 170, 110, 60 }, Accent = { 240, 220, 190 }, Ears = "Point", Tail = "Short", Horn = true },
	{ Id = "Wolf", Name = "Wolf", Rarity = "Rare", Body = { 2.3, 1.8, 3.8 }, Head = 1.5, Legs = 1.6, Color = { 120, 125, 140 }, Accent = { 220, 220, 230 }, Ears = "Point", Tail = "Fluffy" },
	{ Id = "Tiger", Name = "Tiger", Rarity = "Epic", Body = { 2.6, 2, 4.2 }, Head = 1.7, Legs = 1.6, Color = { 255, 140, 30 }, Accent = { 30, 20, 20 }, Ears = "Round", Tail = "Long" },
	{ Id = "Unicorn", Name = "Unicorn", Rarity = "Epic", Body = { 2.4, 2.2, 4.2 }, Head = 1.6, Legs = 2.2, Color = { 255, 240, 255 }, Accent = { 255, 140, 230 }, Ears = "Point", Tail = "Long", Horn = true },
	{ Id = "Griffin", Name = "Griffin", Rarity = "Legendary", Body = { 2.6, 2.2, 4.2 }, Head = 1.6, Legs = 1.8, Color = { 230, 190, 110 }, Accent = { 255, 255, 255 }, Ears = "Point", Tail = "Long", Wings = true },
	{ Id = "Dragon", Name = "Dragon", Rarity = "Legendary", Body = { 3, 2.4, 4.8 }, Head = 1.9, Legs = 1.7, Color = { 60, 180, 90 }, Accent = { 255, 220, 80 }, Tail = "Long", Horn = true, Wings = true },
	{ Id = "Phoenix", Name = "Phoenix", Rarity = "Mythic", Body = { 2.6, 2.4, 3.8 }, Head = 1.6, Legs = 1.6, Color = { 255, 90, 30 }, Accent = { 255, 230, 60 }, Tail = "Fluffy", Wings = true, Neon = true },
	{ Id = "Cosmic Cat", Name = "Cosmic Cat", Rarity = "Mythic", Body = { 2.4, 1.9, 3.6 }, Head = 1.6, Legs = 1.6, Color = { 60, 30, 140 }, Accent = { 120, 255, 255 }, Ears = "Point", Tail = "Long", Neon = true },
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
