--!strict
-- Audio cue registry.
--
-- `Bundled` uses sound files that ship inside every Roblox client
-- (rbxasset://sounds/...). They were confirmed to exist in the local Studio
-- install and are Roblox engine content, usable in any experience.
--
-- `AssetId` is left empty on purpose: no licensed audio was uploaded for this
-- project, and we never invent asset IDs. To add richer audio, pick licensed
-- tracks in the Creator Store (Audio → filter by Roblox-provided or your own
-- uploads) and paste the rbxassetid here. AssetId overrides Bundled.
-- A cue with neither plays nothing (silent fallback).

-- Range: how far (studs) the sound carries in 3D. Work noise carries further than the default
-- 120 on purpose: chopping, felling, building, breaching and shots let players find each other.
export type Cue = { AssetId: string?, Bundled: string?, Volume: number, Pitch: number?, Looped: boolean?, Range: number? }

local Sounds: { [string]: Cue } = {
	-- UI
	UiClick = { Bundled = "rbxasset://sounds/volume_slider.ogg", Volume = 0.4, Pitch = 1.4 },
	UiError = { Bundled = "rbxasset://sounds/volume_slider.ogg", Volume = 0.4, Pitch = 0.6 },
	UiReady = { Bundled = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.5, Pitch = 1.3 },
	Notify = { Bundled = "rbxasset://sounds/volume_slider.ogg", Volume = 0.35, Pitch = 1.0 },
	Victory = { AssetId = nil, Bundled = "rbxasset://sounds/action_get_up.mp3", Volume = 0.7, Pitch = 0.8 },
	Defeat = { Bundled = "rbxasset://sounds/action_falling.ogg", Volume = 0.6, Pitch = 0.7 },

	-- Player / combat
	Swing = { Bundled = "rbxasset://sounds/action_jump.mp3", Volume = 0.35, Pitch = 1.6 },
	HitFlesh = { Bundled = "rbxasset://sounds/ouch.ogg", Volume = 0.5, Pitch = 1.0 },
	HitStructure = { Bundled = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.6, Pitch = 0.7, Range = 240 },
	BowRelease = { Bundled = "rbxasset://sounds/action_jump.mp3", Volume = 0.4, Pitch = 2.0 },
	Gunshot = { Bundled = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.45, Pitch = 2.2, Range = 450 },
	Block = { Bundled = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.6, Pitch = 1.8 },
	Death = { Bundled = "rbxasset://sounds/oof.ogg", Volume = 0.6, Pitch = 1.0 },
	Heal = { Bundled = "rbxasset://sounds/action_get_up.mp3", Volume = 0.4, Pitch = 1.3 },

	-- Gathering / building
	Chop = { Bundled = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.55, Pitch = 1.1, Range = 220 },
	Gather = { Bundled = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.45, Pitch = 1.2 },
	Build = { Bundled = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.7, Pitch = 0.9, Range = 180 },
	Repair = { Bundled = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.5, Pitch = 1.5, Range = 150 },
	Craft = { Bundled = "rbxasset://sounds/action_get_up.mp3", Volume = 0.45, Pitch = 1.6 },
	Break = { Bundled = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.4, Pitch = 0.8 },
	ChopHeavy = { Bundled = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.7, Pitch = 0.8, Range = 260 },
	TreeCreak = { Bundled = "rbxasset://sounds/action_falling.ogg", Volume = 0.45, Pitch = 0.4, Range = 200 },
	TreeFall = { Bundled = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.65, Pitch = 0.45, Range = 320 },
	Eat = { Bundled = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.5, Pitch = 1.8 },
	ChestOpen = { Bundled = "rbxasset://sounds/action_get_up.mp3", Volume = 0.6, Pitch = 0.9 },
	Alarm = { Bundled = "rbxasset://sounds/volume_slider.ogg", Volume = 0.9, Pitch = 0.5 },
	TrapSnap = { Bundled = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.6, Pitch = 1.8 },
	Breach = { Bundled = "rbxasset://sounds/action_jump_land.mp3", Volume = 1.0, Pitch = 0.5, Range = 300 },
	Explosion = { Bundled = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 1.0, Pitch = 0.7, Range = 450 },

	-- Water / fire
	Pour = { Bundled = "rbxasset://sounds/action_swim.mp3", Volume = 0.6, Pitch = 0.9, Looped = true },
	Splash = { Bundled = "rbxasset://sounds/impact_water.mp3", Volume = 0.7, Pitch = 1.0 },
	FireOut = { Bundled = "rbxasset://sounds/impact_water.mp3", Volume = 1.0, Pitch = 0.6 },
	Fill = { Bundled = "rbxasset://sounds/action_swim.mp3", Volume = 0.5, Pitch = 1.3 },
	-- Crackle has no bundled equivalent. Add a licensed loop via AssetId.
	FireCrackle = { AssetId = nil, Volume = 0.5, Looped = true },

	-- Wildlife
	WolfGrowl = { Bundled = "rbxasset://sounds/action_falling.ogg", Volume = 0.5, Pitch = 0.45 },
	BearRoar = { Bundled = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.6, Pitch = 0.35 },
	BatScreech = { Bundled = "rbxasset://sounds/volume_slider.ogg", Volume = 0.35, Pitch = 2.5 },
	AnimalHit = { Bundled = "rbxasset://sounds/ouch.ogg", Volume = 0.45, Pitch = 0.6 },

	-- Loot
	PlaneDrone = { AssetId = nil, Volume = 0.5 },
	PackageLand = { Bundled = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.6, Pitch = 0.8 },
	Pickup = { Bundled = "rbxasset://sounds/action_get_up.mp3", Volume = 0.35, Pitch = 1.8 },
	Open = { Bundled = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.5, Pitch = 1.2 },

	-- Ambience (licensed loops recommended; silent until configured)
	AmbientDay = { AssetId = nil, Volume = 0.3, Looped = true },
	AmbientNight = { AssetId = nil, Volume = 0.3, Looped = true },
	Stream = { Bundled = "rbxasset://sounds/action_swim.mp3", Volume = 0.15, Pitch = 0.5, Looped = true },
	Dawn = { Bundled = "rbxasset://sounds/action_get_up.mp3", Volume = 0.5, Pitch = 0.9 },
	Dusk = { Bundled = "rbxasset://sounds/action_falling.ogg", Volume = 0.4, Pitch = 0.5 },
	Sunset = { Bundled = "rbxasset://sounds/action_falling.ogg", Volume = 0.3, Pitch = 0.7 },
	AmbientLobby = { AssetId = nil, Volume = 0.3, Looped = true }, -- evening forest + distant fire
	AmbientCave = { AssetId = nil, Volume = 0.35, Looped = true }, -- drips, low wind
	Wind = { AssetId = nil, Volume = 0.2, Looped = true },
	Rain = { AssetId = nil, Volume = 0.35, Looped = true }, -- rain shower loop (licensed clip needed)
	Thunder = { Bundled = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.25, Pitch = 0.3 },

	-- Progression
	Reward = { Bundled = "rbxasset://sounds/volume_slider.ogg", Volume = 0.3, Pitch = 1.8 },
	LevelUp = { Bundled = "rbxasset://sounds/action_get_up.mp3", Volume = 0.6, Pitch = 1.2 },
	Purchase = { Bundled = "rbxasset://sounds/action_get_up.mp3", Volume = 0.5, Pitch = 1.5 },
	HurtCue = { Bundled = "rbxasset://sounds/volume_slider.ogg", Volume = 0.3, Pitch = 0.8 },

	-- Surface footsteps: replace the default running sound per floor material
	-- once licensed clips are configured (silent fallback = Roblox default).
	FootGrass = { AssetId = nil, Volume = 0.4 },
	FootLeaves = { AssetId = nil, Volume = 0.4 },
	FootMud = { AssetId = nil, Volume = 0.4 },
	FootStone = { AssetId = nil, Volume = 0.4 },
	FootWood = { AssetId = nil, Volume = 0.4 },
	FootMetal = { AssetId = nil, Volume = 0.4 },
}

local SoundLib = {}
SoundLib.Cues = Sounds

function SoundLib.Resolve(name: string): (string?, Cue?)
	local cue = Sounds[name]
	if not cue then
		return nil, nil
	end
	if cue.AssetId and cue.AssetId ~= "" then
		return cue.AssetId, cue
	end
	return cue.Bundled, cue
end

-- Creates a Sound instance (not parented) or nil if the cue is silent.
function SoundLib.Make(name: string): Sound?
	local id, cue = SoundLib.Resolve(name)
	if not id or not cue then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = cue.Volume
	s.PlaybackSpeed = cue.Pitch or 1
	s.Looped = cue.Looped == true
	s.RollOffMaxDistance = cue.Range or 120
	s.RollOffMinDistance = 10
	return s
end

-- Plays a one-shot at a part/attachment; auto-cleans.
function SoundLib.PlayAt(name: string, parent: Instance)
	local s = SoundLib.Make(name)
	if not s then
		return
	end
	s.Parent = parent
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

return SoundLib
