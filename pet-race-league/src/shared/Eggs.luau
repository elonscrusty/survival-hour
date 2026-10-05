-- Eggs are bought with Coins (earned by racing and training). Weights are relative.
export type Egg = {
	Id: string,
	Name: string,
	Price: number,
	Color: { number },
	Odds: { { Pet: string, W: number } },
}

local Eggs = {}

local list: { Egg } = {
	{
		Id = "Meadow",
		Name = "Meadow Egg",
		Price = 100,
		Color = { 120, 235, 95 },
		Odds = {
			{ Pet = "Pup", W = 30 },
			{ Pet = "Kitty", W = 30 },
			{ Pet = "Bunny", W = 25 },
			{ Pet = "Piggy", W = 8 },
			{ Pet = "Fox", W = 5 },
			{ Pet = "Panda", W = 2 },
		},
	},
	{
		Id = "Forest",
		Name = "Forest Egg",
		Price = 450,
		Color = { 255, 150, 60 },
		Odds = {
			{ Pet = "Fox", W = 30 },
			{ Pet = "Penguin", W = 26 },
			{ Pet = "Deer", W = 20 },
			{ Pet = "Wolf", W = 15 },
			{ Pet = "Tiger", W = 7 },
			{ Pet = "Unicorn", W = 2 },
		},
	},
	{
		Id = "Sky",
		Name = "Sky Egg",
		Price = 1500,
		Color = { 95, 185, 255 },
		Odds = {
			{ Pet = "Wolf", W = 30 },
			{ Pet = "Tiger", W = 28 },
			{ Pet = "Unicorn", W = 24 },
			{ Pet = "Griffin", W = 10 },
			{ Pet = "Dragon", W = 6 },
			{ Pet = "Phoenix", W = 1.5 },
			{ Pet = "Cosmic Cat", W = 0.5 },
		},
	},
}

Eggs.List = list
Eggs.ById = {} :: { [string]: Egg }
for _, e in list do
	Eggs.ById[e.Id] = e
end

return Eggs
