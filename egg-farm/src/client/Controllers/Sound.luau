--!strict
-- Named sound cues. The ids are this game's own synthesized sounds (assets/audio/*.wav, made by
-- assets/audio/make_audio.py) uploaded to the owner's account (assets/uploaded_ids.json).
-- To change one, put another asset id you own / have licensed here (e.g. click = "rbxassetid://123").
-- Honours the server-confirmed settings: sfx (cues) and music (looping background track).

local SoundService = game:GetService("SoundService")

local Sound = {}

Sound.Ids = {
	click = "rbxassetid://136798835886474" :: string?,
	buy = "rbxassetid://103660128190074" :: string?,
	coin = "rbxassetid://100010426391431" :: string?,
	collect = "rbxassetid://100239935293288" :: string?,
	deposit = "rbxassetid://100640206640863" :: string?,
	error = "rbxassetid://78092452569613" :: string?,
	rebirth = "rbxassetid://79787407230468" :: string?,
	spawn = "rbxassetid://126269574955280" :: string?,
	claim = "rbxassetid://132065374514937" :: string?,
	music = "rbxassetid://126863563287348" :: string?,
}

Sound.Volume = {
	click = 0.4,
	buy = 0.6,
	coin = 0.5,
	collect = 0.5,
	deposit = 0.5,
	error = 0.5,
	rebirth = 0.8,
	claim = 0.7,
	spawn = 0.35,
	music = 0.25,
}

local sfxOn = true
local musicOn = true
local cache: { [string]: Sound } = {}
local musicSound: Sound? = nil
local lastPlayed: { [string]: number } = {}

local function get(name: string): Sound?
	local id = (Sound.Ids :: any)[name]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local s = cache[name]
	if not s then
		local made = Instance.new("Sound")
		made.Name = "Cue_" .. name
		made.SoundId = id
		made.Volume = (Sound.Volume :: any)[name] or 0.5
		made.Parent = SoundService
		cache[name] = made
		s = made
	end
	return s
end

function Sound.Play(name: string)
	if not sfxOn or name == "music" then
		return
	end
	-- light throttle so fast repeats (hold-to-spawn) don't stack dozens of copies
	local now = os.clock()
	if (lastPlayed[name] or 0) + 0.05 > now then
		return
	end
	lastPlayed[name] = now
	local s = get(name)
	if s then
		SoundService:PlayLocalSound(s)
	end
end

local function updateMusic()
	local s = get("music")
	if not s then
		return
	end
	musicSound = s
	s.Looped = true
	if musicOn and not s.IsPlaying then
		s:Play()
	elseif not musicOn and s.IsPlaying then
		s:Stop()
	end
end

function Sound.Apply(settings: any)
	if type(settings) ~= "table" then
		return
	end
	sfxOn = settings.sfx ~= false
	musicOn = settings.music ~= false
	updateMusic()
end

function Sound.IsMusicPlaying(): boolean
	return musicSound ~= nil and (musicSound :: Sound).IsPlaying
end

return Sound
