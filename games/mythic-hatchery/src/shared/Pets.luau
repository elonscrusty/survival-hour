--!strict
-- Every pet species. Power = Config.RarityPower[Rarity] * area PowerMult
-- (computed by Logic/PetMath). Source says how it is obtained:
--   Egg        hatched from Egg
--   Expedition found only on expeditions to Area
--   Gem        hatched from the Prism Egg (bought with gems)
-- Look is a short art brief; the model generator (models/gen_models.py) builds
-- a model for every Id.

export type Pet = {
	Id: string,
	Name: string,
	Rarity: string,
	Area: string,
	Source: string,
	Egg: string?,
	Look: string,
}

local Pets = {}

Pets.List = {
	-- Sunny Meadow
	{ Id = "Puppy", Name = "Puppy", Rarity = "Common", Area = "Meadow", Source = "Egg", Egg = "MeadowEgg", Look = "tan puppy, floppy ears, red collar" },
	{ Id = "Kitten", Name = "Kitten", Rarity = "Uncommon", Area = "Meadow", Source = "Egg", Egg = "MeadowEgg", Look = "orange tabby kitten, stripes" },
	{ Id = "Bunny", Name = "Bunny", Rarity = "Rare", Area = "Meadow", Source = "Egg", Egg = "MeadowEgg", Look = "white bunny, long pink-lined ears" },
	{ Id = "Fox", Name = "Fox", Rarity = "Epic", Area = "Meadow", Source = "Egg", Egg = "MeadowEgg", Look = "red fox, white chest, bushy tail" },
	{ Id = "HoneyBear", Name = "Honey Bear", Rarity = "Legendary", Area = "Meadow", Source = "Egg", Egg = "MeadowEgg", Look = "golden bear cub holding a honey pot, bee wings" },
	{ Id = "SunflowerSprite", Name = "Sunflower Sprite", Rarity = "Epic", Area = "Meadow", Source = "Expedition", Look = "tiny green sprite wearing a sunflower petal hat" },

	-- Mushroom Grove
	{ Id = "Toadstool", Name = "Toadstool", Rarity = "Common", Area = "Grove", Source = "Egg", Egg = "GroveEgg", Look = "walking red-spotted mushroom with stubby feet" },
	{ Id = "Snail", Name = "Snail", Rarity = "Uncommon", Area = "Grove", Source = "Egg", Egg = "GroveEgg", Look = "snail with a mossy spiral shell" },
	{ Id = "Frog", Name = "Frog", Rarity = "Rare", Area = "Grove", Source = "Egg", Egg = "GroveEgg", Look = "green frog with a leaf hat" },
	{ Id = "Owl", Name = "Owl", Rarity = "Epic", Area = "Grove", Source = "Egg", Egg = "GroveEgg", Look = "round brown owl, big yellow eyes" },
	{ Id = "GlowcapDragon", Name = "Glowcap Dragon", Rarity = "Legendary", Area = "Grove", Source = "Egg", Egg = "GroveEgg", Look = "purple dragon with glowing mushroom spines" },
	{ Id = "FairyMoth", Name = "Fairy Moth", Rarity = "Legendary", Area = "Grove", Source = "Expedition", Look = "fluffy moth with glowing teal wings" },

	-- Frostbite Peaks
	{ Id = "Penguin", Name = "Penguin", Rarity = "Common", Area = "Frost", Source = "Egg", Egg = "FrostEgg", Look = "penguin with a red scarf" },
	{ Id = "SnowBunny", Name = "Snow Bunny", Rarity = "Uncommon", Area = "Frost", Source = "Egg", Egg = "FrostEgg", Look = "pale blue bunny with earmuffs" },
	{ Id = "ArcticFox", Name = "Arctic Fox", Rarity = "Rare", Area = "Frost", Source = "Egg", Egg = "FrostEgg", Look = "white fox with icy blue tail tip" },
	{ Id = "Yeti", Name = "Yeti", Rarity = "Epic", Area = "Frost", Source = "Egg", Egg = "FrostEgg", Look = "shaggy white yeti cub, blue face" },
	{ Id = "AuroraWolf", Name = "Aurora Wolf", Rarity = "Legendary", Area = "Frost", Source = "Egg", Egg = "FrostEgg", Look = "dark wolf with glowing aurora stripes" },
	{ Id = "PolarKing", Name = "Polar King", Rarity = "Legendary", Area = "Frost", Source = "Expedition", Look = "polar bear wearing an ice crown and cape" },

	-- Coral Cove
	{ Id = "Crab", Name = "Crab", Rarity = "Common", Area = "Coral", Source = "Egg", Egg = "CoralEgg", Look = "red crab with big claws" },
	{ Id = "Turtle", Name = "Turtle", Rarity = "Uncommon", Area = "Coral", Source = "Egg", Egg = "CoralEgg", Look = "sea turtle with a green patterned shell" },
	{ Id = "Pufferfish", Name = "Pufferfish", Rarity = "Rare", Area = "Coral", Source = "Egg", Egg = "CoralEgg", Look = "round yellow pufferfish with spikes" },
	{ Id = "Octopus", Name = "Octopus", Rarity = "Epic", Area = "Coral", Source = "Egg", Egg = "CoralEgg", Look = "pink octopus with curly tentacles" },
	{ Id = "Narwhal", Name = "Narwhal", Rarity = "Legendary", Area = "Coral", Source = "Egg", Egg = "CoralEgg", Look = "blue narwhal with a spiral golden horn" },
	{ Id = "PearlSeahorse", Name = "Pearl Seahorse", Rarity = "Legendary", Area = "Coral", Source = "Expedition", Look = "pearly seahorse with a pearl on its crest" },

	-- Ember Volcano
	{ Id = "LavaSlime", Name = "Lava Slime", Rarity = "Common", Area = "Volcano", Source = "Egg", Egg = "VolcanoEgg", Look = "orange glowing slime blob" },
	{ Id = "Salamander", Name = "Salamander", Rarity = "Uncommon", Area = "Volcano", Source = "Egg", Egg = "VolcanoEgg", Look = "red salamander with yellow spots" },
	{ Id = "EmberBat", Name = "Ember Bat", Rarity = "Rare", Area = "Volcano", Source = "Egg", Egg = "VolcanoEgg", Look = "black bat with glowing ember wings" },
	{ Id = "LavaGolem", Name = "Lava Golem", Rarity = "Epic", Area = "Volcano", Source = "Egg", Egg = "VolcanoEgg", Look = "rock golem with lava cracks" },
	{ Id = "InfernoDragon", Name = "Inferno Dragon", Rarity = "Legendary", Area = "Volcano", Source = "Egg", Egg = "VolcanoEgg", Look = "red dragon with flame horns and wings" },
	{ Id = "Phoenix", Name = "Phoenix", Rarity = "Mythic", Area = "Volcano", Source = "Expedition", Look = "fiery bird with long glowing tail feathers" },

	-- Starfall Isles
	{ Id = "CometCat", Name = "Comet Cat", Rarity = "Common", Area = "Starfall", Source = "Egg", Egg = "StarEgg", Look = "navy cat with a comet tail" },
	{ Id = "MoonBunny", Name = "Moon Bunny", Rarity = "Uncommon", Area = "Starfall", Source = "Egg", Egg = "StarEgg", Look = "lilac bunny with a crescent moon mark" },
	{ Id = "NebulaFox", Name = "Nebula Fox", Rarity = "Rare", Area = "Starfall", Source = "Egg", Egg = "StarEgg", Look = "purple-pink fox with star speckles" },
	{ Id = "GalaxyAxolotl", Name = "Galaxy Axolotl", Rarity = "Epic", Area = "Starfall", Source = "Egg", Egg = "StarEgg", Look = "dark blue axolotl with glowing frills" },
	{ Id = "CelestialDragon", Name = "Celestial Dragon", Rarity = "Legendary", Area = "Starfall", Source = "Egg", Egg = "StarEgg", Look = "white-gold dragon with a halo and star wings" },
	{ Id = "CosmicUnicorn", Name = "Cosmic Unicorn", Rarity = "Mythic", Area = "Starfall", Source = "Egg", Egg = "StarEgg", Look = "starry unicorn with glowing horn and mane" },
	{ Id = "VoidKraken", Name = "Void Kraken", Rarity = "Mythic", Area = "Starfall", Source = "Expedition", Look = "black kraken with violet glowing eyes and tentacles" },

	-- Prism Egg (gems)
	{ Id = "CrystalPup", Name = "Crystal Pup", Rarity = "Rare", Area = "Starfall", Source = "Gem", Egg = "PrismEgg", Look = "puppy made of pale blue crystal" },
	{ Id = "PrismFox", Name = "Prism Fox", Rarity = "Epic", Area = "Starfall", Source = "Gem", Egg = "PrismEgg", Look = "fox with rainbow prism fur" },
	{ Id = "RainbowUnicorn", Name = "Rainbow Unicorn", Rarity = "Legendary", Area = "Starfall", Source = "Gem", Egg = "PrismEgg", Look = "white unicorn with rainbow mane" },
	{ Id = "DiamondDragon", Name = "Diamond Dragon", Rarity = "Mythic", Area = "Starfall", Source = "Gem", Egg = "PrismEgg", Look = "dragon of faceted diamond, glowing cyan" },
} :: { Pet }

Pets.ById = {} :: { [string]: Pet }
for i, p in Pets.List do
	Pets.ById[p.Id] = p
end

return Pets
