--!nonstrict
-- Studio-only DEV panel. The server ignores these commands outside Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local Panels = require("./Panels")

local Dev = {}

local player = Players.LocalPlayer

function Dev.Start()
	if not workspace:GetAttribute("DevEnabled") then
		return
	end
	local gui = UI.new("ScreenGui", { Name = "DevButton", ResetOnSpawn = false, DisplayOrder = 30, Parent = player:WaitForChild("PlayerGui") })
	UI.button("⚙ DEV", { Size = UDim2.fromOffset(80, 36), Position = UDim2.new(0, 12, 0, 56), BackgroundColor3 = Color3.fromRGB(90, 50, 120), TextSize = 14, Parent = gui }, function()
		Panels.Toggle("Dev")
	end)
	local body = Panels.Create("Dev", "DEV TOOLS (STUDIO ONLY)", Vector2.new(640, 560))
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(196, 46), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	local cmds = {
		{ "Start local match", "StartMatch" },
		{ "Skip phase", "SkipPhase" },
		{ "End match (my team wins)", "EndMatch" },
		{ "+20 of every material", "GiveResources" },
		{ "Give Stone Axe", "GiveItem", "StoneAxe" },
		{ "Give Stone Pickaxe", "GiveItem", "StonePickaxe" },
		{ "Give Canteen", "GiveItem", "Canteen" },
		{ "Fill canteen", "FillCanteen" },
		{ "Give Bow", "GiveItem", "Bow" },
		{ "Give Arrows", "GiveItem", "Arrow" },
		{ "Give Sword", "GiveItem", "Sword" },
		{ "Give Shield", "GiveItem", "Shield" },
		{ "Give Pistol", "GiveItem", "Pistol" },
		{ "Give Bullets", "GiveItem", "Bullet" },
		{ "Give Armor", "GiveItem", "Armor" },
		{ "Give Hammer", "GiveItem", "RepairHammer" },
		{ "Give Bandages", "GiveItem", "Bandage" },
		{ "Workbench Lv 2", "BenchLevel", 2 },
		{ "Workbench Lv 3", "BenchLevel", 3 },
		{ "Workbench Lv 5", "BenchLevel", 5 },
		{ "Spawn Wolf", "SpawnAnimal", "Wolf" },
		{ "Spawn Bear", "SpawnAnimal", "Bear" },
		{ "Spawn Bat", "SpawnAnimal", "Bat" },
		{ "Drop care package", "DropPackage" },
		{ "Extinguish Fox fire", "Extinguish", 1 },
		{ "Extinguish Owl fire", "Extinguish", 2 },
		{ "Take 25 damage", "Damage" },
		{ "Kill me", "Kill" },
		{ "+100 diamonds", "Diamonds" },
		{ "Complete challenges", "CompleteChallenges" },
	}
	for i, c in cmds do
		UI.button(c[1], { LayoutOrder = i, TextSize = 13, BackgroundColor3 = Theme.Colors.PanelLighter, Parent = body }, function()
			Net.Event("DevCommand"):FireServer(c[2], c[3])
		end)
	end
end

return Dev
