--!strict
-- Per-creature potions, bought with gems and applied to one creature forever
-- (they travel with it in trades). Ride/Fly need the creature to be Adult+ to use,
-- but can be applied at any stage.

export type Potion = { Id: string, Name: string, Gems: number, Blurb: string }

local Potions = {}

Potions.List = {
	{ Id = "Ride", Name = "Ride Potion", Gems = 150, Blurb = "Ride this creature once it's an Adult." },
	{ Id = "Fly", Name = "Fly Potion", Gems = 300, Blurb = "Fly this creature once it's an Adult (needed for sky races)." },
	{ Id = "Neon", Name = "Neon Potion", Gems = 200, Blurb = "Makes this creature glow in its element's colours (+10% coins)." },
} :: { Potion }

Potions.NeonCoinMult = 1.1

Potions.ById = {} :: { [string]: Potion }
for _, p in Potions.List do
	Potions.ById[p.Id] = p
end

return Potions
