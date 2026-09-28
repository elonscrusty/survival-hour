--!nonstrict
-- UI sounds, ambience and event stingers (local-only playback).

local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundLib = require(ReplicatedStorage.Shared.Sounds)
local State = require("../State")
local UI = require("../UI/UI")
local Weather = require("./Weather")

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

local function settings(): { [string]: any }
	local prof = State.Get("Profile")
	return (prof and prof.Settings) or {}
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
		s:SetAttribute("BaseVolume", s.Volume)
		local vol = settings().Ambience
		if type(vol) == "number" then
			s.Volume *= vol
		end
		s:Play()
		ambient = s
	end
end


function SoundCtl.Start()
	Weather.Thunder = function(_near: boolean)
		SoundCtl.Play("Thunder")
	end
	UI.ClickSound = function()
		if settings().UiSounds ~= false then
			SoundCtl.Play("UiClick")
		end
	end
	State.On("Profile", function()
		local vol = settings().Ambience
		if ambient and type(vol) == "number" then
			local base = ambient:GetAttribute("BaseVolume")
			ambient.Volume = (if type(base) == "number" then base else ambient.Volume) * vol
		end
	end)
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
		elseif name == "SurvivorsLeft" then
			SoundCtl.Play(if ev.Data.Final then "Dusk" else "Notify")
		elseif name == "Dangerous" then
			SoundCtl.Play("Alarm")
		elseif name == "WorldEvent" then
			local d = ev.Data or {}
			if d.Stage == "Start" and d.Kind ~= "Condition" then
				SoundCtl.Play(if d.Kind == "Thunderstorm" then "Thunder" elseif d.Kind == "PredatorSurge" then "WolfGrowl" else "Sunset")
			elseif d.Stage == "Found" then
				SoundCtl.Play("Reward")
			end
		elseif name == "FireUnderAttack" then
			SoundCtl.Play("Alarm")
		elseif name == "Upgraded" then
			SoundCtl.Play("LevelUp")
		elseif name == "LootReveal" then
			local d = ev.Data or {}
			SoundCtl.Play(if d.Tier == "Rare" or d.Tier == "VeryRare" then "LevelUp" else "Reward")
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
	local rainLoop: Sound? = nil
	local nextHowl = os.clock() + 25
	local nextSurgeHowl = 0
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
		-- wolf surge: howls from the real direction of the pack (the clue that lets players
		-- choose to go hunting or steer clear); stops when the surge ends
		local surge = ms:GetAttribute("SurgePos")
		if inMatch and typeof(surge) == "Vector3" and workspace:GetServerTimeNow() < ((ms:GetAttribute("SurgeUntil") :: number?) or 0) and os.clock() > nextSurgeHowl then
			nextSurgeHowl = os.clock() + math.random(10, 18)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local s = SoundLib.Make("WolfGrowl")
			if root and s then
				local flat = (surge - root.Position) * Vector3.new(1, 0, 1)
				local dist = math.min(flat.Magnitude, 110)
				local spot = Instance.new("Part")
				spot.Anchored = true
				spot.CanCollide = false
				spot.CanQuery = false
				spot.Transparency = 1
				spot.Size = Vector3.one
				spot.Position = root.Position + (if flat.Magnitude > 1 then flat.Unit else Vector3.xAxis) * dist + Vector3.new(0, 8, 0)
				spot.Parent = workspace.CurrentCamera
				s.RollOffMaxDistance = 500
				s.RollOffMinDistance = 70
				s.Parent = spot
				s:Play()
				game:GetService("Debris"):AddItem(spot, 6)
			end
		end
		-- night soundscape: now and then a distant howl or growl from somewhere in the dark
		-- (a random far bearing — atmosphere, never a real position, so it gives nothing away)
		if inMatch and ms:GetAttribute("Phase") == "Night" and ms:GetAttribute("Event") ~= "PredatorSurge" and os.clock() > nextHowl then
			nextHowl = os.clock() + math.random(20, 45)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local s = SoundLib.Make(if math.random() < 0.7 then "WolfGrowl" else "BearRoar")
			if root and s then
				local a = math.random() * math.pi * 2
				local spot = Instance.new("Part")
				spot.Anchored = true
				spot.CanCollide = false
				spot.CanQuery = false
				spot.Transparency = 1
				spot.Size = Vector3.one
				spot.Position = root.Position + Vector3.new(math.cos(a) * 90, 10, math.sin(a) * 90)
				spot.Parent = workspace.CurrentCamera
				s.RollOffMaxDistance = 400
				s.RollOffMinDistance = 60
				s.Volume *= 0.7
				s.Parent = spot
				s:Play()
				game:GetService("Debris"):AddItem(spot, 6)
			end
		end
		-- endgame tension: in the final three the ambience settles lower and slower
		if ambient then
			local left = ms:GetAttribute("Remaining")
			local tense = inMatch and type(left) == "number" and left <= 3 and left >= 2
			ambient.PlaybackSpeed = if tense then 0.9 else 1
		end
		-- rain loop layered over the ambience during showers
		local wantRain = inMatch and (ms:GetAttribute("Weather") == "Rain" or ms:GetAttribute("Weather") == "Storm")
		if wantRain and not rainLoop then
			rainLoop = SoundLib.Make("Rain")
			if rainLoop then
				rainLoop.Looped = true
				rainLoop.Parent = SoundService
				rainLoop:Play()
			end
		elseif not wantRain and rainLoop then
			rainLoop:Destroy()
			rainLoop = nil
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
