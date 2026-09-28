--!nonstrict
-- UI sounds, ambience and event stingers (local-only playback).

local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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

local ambientName: string? = nil
local function setAmbient(name: string)
	if name == ambientName then
		return
	end
	ambientName = name
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
		elseif type(n.Text) == "string" and string.sub(n.Text, 1, 6) == "LEVEL " then
			SoundCtl.Play("LevelUp")
		elseif type(n.Text) == "string" and string.find(n.Text, "Purchase complete", 1, true) then
			SoundCtl.Play("Purchase")
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
		elseif name == "FireCritical" then
			SoundCtl.Play("Alarm")
		elseif name == "Sunset" then
			SoundCtl.Play("Sunset")
		elseif name == "Reward" then
			SoundCtl.Play("Reward")
		elseif name == "HurtCue" then
			SoundCtl.Play("HurtCue")
		elseif name == "ReturnedToLobby" then
			setAmbient("AmbientLobby")
		end
	end)
	-- Context ambience: lobby / cave override the day-night loop.
	local player = Players.LocalPlayer
	local ms = ReplicatedStorage:WaitForChild("MatchState")
	local FOOT = {
		[Enum.Material.Grass] = "FootGrass", [Enum.Material.LeafyGrass] = "FootLeaves", [Enum.Material.Ground] = "FootLeaves",
		[Enum.Material.Mud] = "FootMud", [Enum.Material.Rock] = "FootStone", [Enum.Material.Slate] = "FootStone",
		[Enum.Material.Cobblestone] = "FootStone", [Enum.Material.Wood] = "FootWood", [Enum.Material.WoodPlanks] = "FootWood",
		[Enum.Material.Metal] = "FootMetal", [Enum.Material.DiamondPlate] = "FootMetal",
	}
	local defaultRun: { [Sound]: string } = setmetatable({}, { __mode = "k" }) :: any
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local inMatch = player:GetAttribute("InMatch") == true
		if not inMatch then
			setAmbient("AmbientLobby")
		elseif player:GetAttribute("InCave") then
			setAmbient("AmbientCave")
		else
			setAmbient(if ms:GetAttribute("Phase") == "Night" then "AmbientNight" else "AmbientDay")
		end
		-- surface footsteps (only when a licensed clip is configured)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local run = root and root:FindFirstChild("Running") :: Sound?
		if hum and run then
			if not defaultRun[run] then
				defaultRun[run] = run.SoundId
			end
			local id = SoundLib.Resolve(FOOT[hum.FloorMaterial] or "")
			run.SoundId = id or defaultRun[run]
		end
	end)
	State.On("Hit", function(h)
		if h.Kind == "Hurt" then
			SoundCtl.Play("HitFlesh")
		end
	end)
end

return SoundCtl
