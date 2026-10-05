-- Plays sound effects (and music, if one is set) on this client. Muting is saved
-- in the profile so it sticks between visits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage.Shared
local Sounds = require(Shared.Sounds)
local Net = require(Shared.Net)
local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI)

local Sound = {}

local pool: { [string]: Sound } = {}
local music: Sound? = nil

local function muted(): boolean
	return State.Data ~= nil and State.Data.Muted == true
end

function Sound.Play(name: string)
	if muted() then
		return
	end
	local s = pool[name]
	if not s then
		local def = Sounds.Effects[name]
		if not def then
			return
		end
		s = Instance.new("Sound")
		s.SoundId = def.Id
		s.Volume = def.Volume
		s.PlaybackSpeed = def.Pitch
		s.Parent = SoundService
		pool[name] = s
	end
	SoundService:PlayLocalSound(s)
end

function Sound.SetMuted(on: boolean)
	Net.Event("SetMuted"):FireServer(on)
end

function Sound.Start()
	UI.OnClick = function()
		Sound.Play("Click")
	end
	if Sounds.Music then
		local m = Instance.new("Sound")
		m.SoundId = Sounds.Music
		m.Looped = true
		m.Volume = Sounds.MusicVolume
		m.Parent = SoundService
		music = m
	end
	State.OnChange(function()
		if music then
			if muted() then
				music:Stop()
			elseif not music.IsPlaying then
				music:Play()
			end
		end
	end)
	Net.Event("Notify").OnClientEvent:Connect(function(_, kind)
		if kind == "Coins" then
			Sound.Play("Coin")
		elseif kind == "Level" or kind == "Rare" then
			Sound.Play("Level")
		elseif kind == "Error" then
			Sound.Play("Error")
		elseif kind == "Xp" then
			Sound.Play("Xp")
		end
	end)
	Net.Event("Race").OnClientEvent:Connect(function(kind)
		if kind == "Count" then
			Sound.Play("Beep")
		elseif kind == "Go" then
			Sound.Play("Go")
		elseif kind == "Fell" then
			Sound.Play("Fall")
		elseif kind == "Checkpoint" then
			Sound.Play("Xp")
		elseif kind == "Results" then
			Sound.Play("Level")
		end
	end)
	local player = Players.LocalPlayer
	local lastCharges = player:GetAttribute("DashCharges") or 0
	player:GetAttributeChangedSignal("DashCharges"):Connect(function()
		local c = player:GetAttribute("DashCharges") or 0
		if c < lastCharges then
			Sound.Play("Dash")
		end
		lastCharges = c
	end)
end

return Sound
