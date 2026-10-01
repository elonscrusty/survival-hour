--[[
	ClientMain.client.lua
	Starts every client module in order and wires the few things that span modules:
	music per phase, the hurt flash, and the [VIP] chat tag.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Audio = require(script.Parent:WaitForChild("Audio"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local MobileControls = require(script.Parent:WaitForChild("MobileControls"))
local VFX = require(script.Parent:WaitForChild("VFX"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local player = Players.LocalPlayer

Audio.Init()
CameraController.Init()
MobileControls.Init()
VFX.Init({
	OnLocalEvent = function(kind)
		if kind == "hurt" then
			UIBuilder.HurtFlash()
		end
	end,
})
UIBuilder.Init({ Audio = Audio, MobileControls = MobileControls })

-- Music follows the game phase.
local state = Remotes.State()
local function updateMusic()
	local inRun = player:GetAttribute("InRun") == true
	if not inRun then
		Audio.SetMusic("LobbyMusic")
	elseif (state:GetAttribute("BossMaxHP") or 0) > 0 then
		Audio.SetMusic("BossMusic")
	else
		Audio.SetMusic("BattleMusic")
	end
end
player:GetAttributeChangedSignal("InRun"):Connect(updateMusic)
state:GetAttributeChangedSignal("BossMaxHP"):Connect(updateMusic)
updateMusic()

-- [VIP] chat tag (TextChatService). The VIP attribute is set by the server.
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	if source then
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if speaker and speaker:GetAttribute("VIP") then
			props.PrefixText = '<font color="#FFD24A">[VIP]</font> ' .. message.PrefixText
		end
	end
	return props
end
