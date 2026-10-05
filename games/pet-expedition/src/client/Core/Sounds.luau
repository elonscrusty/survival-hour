--!strict
-- Client sounds. Uses sounds that ship with the Roblox client so nothing has
-- to be uploaded; swap any `Id` for a licensed rbxassetid:// later.
-- Respects the Sfx and Music settings.

local SoundService = game:GetService("SoundService")

local State = require("./State")

local Sounds = {}

export type SoundDef = { Id: string, Volume: number, Speed: number }

Sounds.Defs = {
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.5, Speed = 1.1 },
	Open = { Id = "rbxasset://sounds/button.wav", Volume = 0.4, Speed = 0.85 },
	Coin = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Speed = 1.5 },
	Gem = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Speed = 2 },
	Reward = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 1 },
	Break = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.45, Speed = 0.8 },
	Target = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.35, Speed = 1.3 },
	EggShake = { Id = "rbxasset://sounds/button.wav", Volume = 0.35, Speed = 0.6 },
	Hatch = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Speed = 0.7 },
	Rare = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.9, Speed = 0.5 },
	Error = { Id = "rbxasset://sounds/button.wav", Volume = 0.5, Speed = 0.5 },
	Toast = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Speed = 1.25 },
} :: { [string]: SoundDef }

-- Background music track. nil until a licensed track is chosen.
Sounds.MusicId = nil :: string?
Sounds.MusicVolume = 0.25

local folder: Folder? = nil
local cache: { [string]: Sound } = {}
local music: Sound? = nil
local lastPlayed: { [string]: number } = {}

local function getFolder(): Folder
	local f = folder
	if f then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "PetExpeditionSounds"
	nf.Parent = SoundService
	folder = nf
	return nf
end

-- Plays a named sound. `pitch` multiplies the playback speed.
function Sounds.Play(name: string, pitch: number?)
	if State.Setting("Sfx", true) == false then
		return
	end
	local def = Sounds.Defs[name]
	if not def then
		return
	end
	-- don't stack the same sound more than ~25 times per second
	local now = os.clock()
	if (lastPlayed[name] or 0) > now - 0.04 then
		return
	end
	lastPlayed[name] = now
	local base = cache[name]
	if not base then
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = def.Id
		s.Volume = def.Volume
		s.Parent = getFolder()
		cache[name] = s
		base = s
	end
	local s = base:Clone()
	s.PlaybackSpeed = def.Speed * (pitch or 1)
	s.Parent = getFolder()
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local function refreshMusic()
	local want = State.Setting("Music", true) ~= false and Sounds.MusicId ~= nil
	if want and not music then
		local m = Instance.new("Sound")
		m.Name = "Music"
		m.SoundId = Sounds.MusicId :: string
		m.Looped = true
		m.Volume = Sounds.MusicVolume
		m.Parent = getFolder()
		m:Play()
		music = m
	elseif not want and music then
		music:Destroy()
		music = nil
	end
end

function Sounds.Init()
	State.Changed:Connect(refreshMusic)
end

return Sounds
