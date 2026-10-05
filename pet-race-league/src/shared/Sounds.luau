-- Sound effects. Ids are Roblox's built-in engine sounds (always available, no
-- licensing needed), retuned with Pitch. Music is off until the owner picks a track
-- they have the rights to use (their own upload or a Creator Store track licensed
-- for experiences) and puts its id in Music.
local Sounds = {}

Sounds.Effects = {
	Click = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.4, Pitch = 1.2 },
	Coin = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.6, Pitch = 1.8 },
	Level = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.7, Pitch = 2.2 },
	Error = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.5, Pitch = 0.6 },
	Xp = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.2, Pitch = 2.6 },
	Beep = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.8, Pitch = 1.0 },
	Go = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.9, Pitch = 1.6 },
	Dash = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.6, Pitch = 1.4 },
	Fall = { Id = "rbxasset://sounds/action_falling.ogg", Volume = 0.6, Pitch = 1.0 },
	Land = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.6, Pitch = 1.0 },
	Hatch = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.35, Pitch = 1.6 },
	Wobble = { Id = "rbxasset://sounds/action_get_up.mp3", Volume = 0.5, Pitch = 1.3 },
}

-- Background music: put a licensed audio asset id here, e.g. "rbxassetid://123".
Sounds.Music = nil :: string?
Sounds.MusicVolume = 0.25

return Sounds
