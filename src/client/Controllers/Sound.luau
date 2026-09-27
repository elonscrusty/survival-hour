--!nonstrict
-- UI sounds, ambience and event stingers (local-only playback).

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundLib = require(ReplicatedStorage.Shared.Sounds)
local State = require("../State")
local UI = require("../UI/UI")

local SoundCtl = {}

local cache: { [string]: Sound } = {}
local ambient: Sound? = nil

function SoundCtl.Play(name: string)
	local s = cache[name]
	if not s then
		local made = SoundLib.Make(name)
		if not made then
			return
		end
		made.Parent = SoundService
		cache[name] = made
		s = made
	end
	(s :: Sound):Play()
end

local function setAmbient(name: string)
	if ambient then
		ambient:Stop()
		ambient:Destroy()
		ambient = nil
	end
	local s = SoundLib.Make(name)
	if s then
		s.Looped = true
		s.Parent = SoundService
		s:Play()
		ambient = s
	end
end

function SoundCtl.Start()
	UI.ClickSound = function()
		SoundCtl.Play("UiClick")
	end
	State.On("Notify", function(n)
		if n.Kind == "error" then
			SoundCtl.Play("UiError")
		else
			SoundCtl.Play("Notify")
		end
	end)
	State.On("MatchEvent", function(ev)
		local name = ev.Name
		if name == "Phase" then
			SoundCtl.Play(if ev.Data.Phase == "Night" then "Dusk" else "Dawn")
			setAmbient(if ev.Data.Phase == "Night" then "AmbientNight" else "AmbientDay")
		elseif name == "FireOut" then
			SoundCtl.Play("FireOut")
		elseif name == "MatchEnded" then
			SoundCtl.Play(if ev.Data.Won then "Victory" else "Defeat")
		elseif name == "Died" or name == "Eliminated" then
			SoundCtl.Play("Death")
		elseif name == "ReturnedToLobby" then
			setAmbient("AmbientDay")
		end
	end)
	State.On("Hit", function(h)
		if h.Kind == "Hurt" then
			SoundCtl.Play("HitFlesh")
		end
	end)
end

return SoundCtl
