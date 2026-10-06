--!strict
-- Turns server Notify messages into toasts and banners:
-- Toast, Discovered, LevelUp, Purchased, ServerLuck. (Reward/Broken are
-- handled by Farming, TradeRequest by Trade.) Also adds the VIP chat tag.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local State = require("../Core/State")
local PetInfo = require("../Core/PetInfo")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Toasts = require("../UI/Toasts")
local HatchAnim = require("./HatchAnim")

local Notifications = {}

local lastLevelToast = 0

local function onNotify(kind: string, data: { [string]: any })
	if kind == "Toast" then
		local tone = if data.Tone == "good" or data.Tone == "bad" or data.Tone == "info" then data.Tone else "info"
		Toasts.Show(tostring(data.Text or ""), tone)
	elseif kind == "Discovered" then
		-- the hatch animation already shows "NEW!"
		if HatchAnim.Playing or type(data.PetId) ~= "string" then
			return
		end
		Toasts.Show(Theme.Icons.Index .. " New pet discovered: <b>" .. PetInfo.Name(data.PetId) .. "</b>!", "purple", { PetId = data.PetId })
	elseif kind == "LevelUp" then
		local uid = data.Uid
		local pet = if type(uid) == "string" then State.PetByUid(uid) else nil
		-- many pets can level at once; keep it to one toast per second
		local now = os.clock()
		if now - lastLevelToast < 1 then
			return
		end
		lastLevelToast = now
		local name = if pet then PetInfo.FullName(pet) else "Your pet"
		Toasts.Show("⬆ " .. name .. " reached level " .. tostring(data.Level or "?") .. "!", "good", {
			PetId = if pet then pet.Id else nil,
			Variant = if pet then pet.Variant else nil,
			Shiny = if pet then pet.Shiny else nil,
			Duration = 2.5,
		})
	elseif kind == "Purchased" then
		Sounds.Play("Rare")
		Toasts.Show("🎉 Thank you! You got <b>" .. tostring(data.Name or "your item") .. "</b>", "gold", { Duration = 5 })
	elseif kind == "ServerLuck" then
		local d = State.Data
		if not d or not d.CanBuyGemEggs then
			return
		end
		Sounds.Play("Reward")
		Toasts.Banner(
			Theme.Icons.Luck .. " Server Luck x" .. tostring(Config.ServerLuckMult) .. "!",
			"Thanks to " .. tostring(data.By or "a kind player") .. "! Everyone hatches luckier.",
			Theme.Colors.Luck,
			4
		)
	end
end

-- VIP chat tag and golden name (TextChatService).
local function setupChat()
	local ok, err = pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage): any
			local source = message.TextSource
			if not source then
				return nil
			end
			local p = Players:GetPlayerByUserId(source.UserId)
			if not p or p:GetAttribute("Vip") ~= true then
				return nil
			end
			local props = Instance.new("TextChatMessageProperties")
			props.PrefixText = "<font color=\"#FFC828\">[VIP]</font> <font color=\"#FFD700\">" .. message.PrefixText .. "</font>"
			return props
		end
	end)
	if not ok then
		warn("[Notifications] chat tag setup failed: " .. tostring(err))
	end
end

function Notifications.Init()
	State.Notify:Connect(onNotify)
	setupChat()
end

return Notifications
