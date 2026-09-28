--!nonstrict
-- End-of-match card: result, placement, rewards, match recap grid, PLAY AGAIN, and the
-- "Your survival story" panel beside it (below it on narrow screens). Used by Hud.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local UI = require("./UI")
local Theme = require("./Theme")

local C = Theme.Colors
local EndScreen = {}

function EndScreen.Show(gui: ScreenGui, data: any)
	local won = data.Won
	local winner = data.Winner
	local frame = UI.panel({ Name = "EndScreen", Size = UDim2.fromOffset(480, 360), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Parent = gui }, { UI.padding(16) })
	-- the result card lands with a short pop (rewards feel earned, not sluggish)
	local pop = UI.new("UIScale", { Scale = 0.6, Parent = frame })
	TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	UI.text(if won then "VICTORY" else "DEFEAT", { Size = UDim2.new(1, 0, 0, 56), TextSize = 50, Font = Theme.FontBlack, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = if won then C.Accent else C.Bad, Parent = frame })
	local wdef = Config.Teams[winner]
	UI.text(if wdef then (wdef.Symbol .. " " .. wdef.Name .. " clan kept their fire burning!") else "No clan survived.", { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 26), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	local sum = data.Summary or {}
	local ORD = { "1st", "2nd", "3rd" }
	if sum.Place then
		UI.text("Placed " .. (ORD[sum.Place] or (tostring(sum.Place) .. "th")) .. " of " .. tostring(sum.Of or "?"), { Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 22), TextSize = 17, Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	end
	local bits = { "+" .. tostring(sum.XP or 0) .. " XP", "+" .. tostring(sum.Coins or 0) .. " Coins" }
	if (data.Diamonds or 0) > 0 then
		table.insert(bits, "+" .. data.Diamonds .. " ◆")
	end
	UI.text(table.concat(bits, "   "), { Position = UDim2.fromOffset(0, 116), Size = UDim2.new(1, 0, 0, 32), TextSize = 26, Font = Theme.FontBlack, TextColor3 = if (data.Diamonds or 0) > 0 then C.Diamond else C.Accent, TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	if (sum.Levels or 0) > 0 then
		UI.text("LEVEL UP → " .. tostring(sum.Level), { Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 22), TextSize = 18, Font = Theme.FontBold, TextColor3 = C.Good, TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	end
	-- match recap: what this match was, win or lose (tallied even when rewards are off)
	local stats = sum.Stats
	if stats then
		local dur = sum.Duration or 0
		local rows = {
			{ "Match length", string.format("%d:%02d", dur // 60, dur % 60) },
			{ "Reached", "Day " .. tostring(sum.Nights or 0) },
			{ "Survivors taken down", string.format("%d  (%d out)", stats.Kills or 0, stats.Eliminations or 0) },
			{ "Wildlife hunted", tostring(stats.Animals or 0) .. (if (stats.Bears or 0) > 0 then "  (" .. stats.Bears .. " bear)" else "") },
			{ "Resources gathered", tostring(stats.Resources or 0) },
			{ "Damage dealt / taken", string.format("%d / %d", stats.DamageDealt or 0, stats.DamageTaken or 0) },
			{ "Fires snuffed", tostring(stats.FiresOut or 0) },
			{ "Storage breached", tostring(stats.Breaches or 0) },
			{ "Places discovered", tostring(stats.Pois or 0) },
			{ "Workbench tier", ({ "I", "II", "III", "IV", "V" })[sum.Bench or 1] or "I" },
		}
		local grid = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 176), Size = UDim2.new(1, 0, 0, 5 * 22), Parent = frame }, {
			UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 20), CellPadding = UDim2.fromOffset(12, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for i, r in rows do
			local cell = UI.new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = grid })
			UI.text(r[1], { Size = UDim2.fromScale(0.64, 1), TextSize = 13, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = cell })
			UI.text(r[2], { Position = UDim2.fromScale(0.64, 0), Size = UDim2.fromScale(0.36, 1), TextSize = 13, Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Right, Parent = cell })
		end
	end
	-- PLAY AGAIN: land back in the lobby already queued for the next match
	local againBtn: TextButton
	againBtn = UI.Buttons.action("▶ PLAY AGAIN", { Size = UDim2.fromOffset(200, 40), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Tone = "Green", Parent = frame }, function()
		Net.Event("PlayAgain"):FireServer()
		UI.Buttons.setState(againBtn, "Selected")
		againBtn.Text = "✓ QUEUED"
	end)
	UI.text("Returning to the lobby shortly…", { Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, -210, 0, 24), TextSize = 14, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	-- YOUR SURVIVAL STORY: a short factual timeline beside the result card (below it on narrow screens)
	local story = sum.Story
	local storyFrame: Frame? = nil
	if type(story) == "table" and #story > 0 then
		local vp = workspace.CurrentCamera.ViewportSize
		local wide = vp.X >= 1000
		local h = math.min(360, 44 + #story * 20)
		local sf = UI.panel({ Name = "Story", Size = UDim2.fromOffset(if wide then 340 else 480, h), AnchorPoint = if wide then Vector2.new(0, 0.5) else Vector2.new(0.5, 0), Position = if wide then UDim2.new(0.5, 142, 0.45, 0) else UDim2.new(0.5, 0, 0.45, 190), Parent = gui }, { UI.padding(12) })
		if wide then
			frame.Position = UDim2.new(0.5, -110, 0.45, 0)
		end
		UI.text("YOUR SURVIVAL STORY", { Size = UDim2.new(1, 0, 0, 22), TextSize = 16, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = sf })
		for i, line in story do
			local lbl = UI.text(tostring(line), { Position = UDim2.fromOffset(0, 26 + (i - 1) * 20), Size = UDim2.new(1, 0, 0, 20), TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, TextColor3 = if i == #story then C.Text else C.TextDim, TextTransparency = 1, Parent = sf })
			-- lines appear one after another, like the story being told
			task.delay(0.4 + i * 0.12, function()
				TweenService:Create(lbl, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
			end)
		end
		storyFrame = sf
	end
	task.delay(Config.Match.EndScreenLength + 2, function()
		frame:Destroy()
		if storyFrame then
			storyFrame:Destroy()
		end
	end)
end

return EndScreen
