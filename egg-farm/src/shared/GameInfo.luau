--!strict
-- Rename the game here. Every player-facing mention of the game name reads from this module.
-- (Also change "name" in default.project.json / test.project.json if you want the place
-- file names to match; see README "Renaming".)

return {
	Name = "Egg Farm",
	ShortName = "Egg Farm",
	Tagline = "Spawn chickens. Collect eggs. Ship them out. Build an egg empire of your own!",
	SaveStoreName = "EggFarm_Profiles_v1", -- DataStore name. Changing it starts every player fresh!
	Currency = {
		Cash = "Cash",
		Gold = "Gold Eggs",
		Star = "Star Eggs",
	},
}
