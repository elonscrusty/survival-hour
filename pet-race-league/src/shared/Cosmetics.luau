-- Cosmetics: trails and pet paint. Looks only, never stats.
-- Price = coins; Robux-only items have Price = nil and are unlocked by a product
-- (see Products.luau).
export type Cosmetic = {
	Id: string,
	Kind: string, -- "Trail" | "Paint"
	Name: string,
	Price: number?,
	Colors: { { number } },
}

local Cosmetics = {}

local list: { Cosmetic } = {
	{ Id = "TrailDust", Kind = "Trail", Name = "Dust Trail", Price = 150, Colors = { { 200, 180, 140 }, { 240, 230, 200 } } },
	{ Id = "TrailSky", Kind = "Trail", Name = "Sky Trail", Price = 600, Colors = { { 90, 170, 255 }, { 255, 255, 255 } } },
	{ Id = "TrailFire", Kind = "Trail", Name = "Fire Trail", Price = 1800, Colors = { { 255, 60, 0 }, { 255, 220, 40 } } },
	{ Id = "TrailRainbow", Kind = "Trail", Name = "Rainbow Trail", Price = nil, Colors = { { 255, 0, 0 }, { 255, 200, 0 }, { 0, 200, 80 }, { 0, 120, 255 }, { 170, 0, 255 } } },
	{ Id = "PaintGold", Kind = "Paint", Name = "Gold Paint", Price = 2500, Colors = { { 255, 200, 50 } } },
	{ Id = "PaintShadow", Kind = "Paint", Name = "Shadow Paint", Price = 1200, Colors = { { 40, 40, 55 } } },
	{ Id = "PaintGalaxy", Kind = "Paint", Name = "Galaxy Paint", Price = nil, Colors = { { 80, 40, 160 } } },
}

Cosmetics.List = list
Cosmetics.ById = {} :: { [string]: Cosmetic }
for _, c in list do
	Cosmetics.ById[c.Id] = c
end

return Cosmetics
