--!strict
-- Crafting machine: lists every group of matching pets (same species,
-- variant and shininess) and turns Config.CraftCost of them into the next
-- variant (Normal -> Golden -> Rainbow). Always succeeds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local State = require("../Core/State")
local PetInfo = require("../Core/PetInfo")
local Format = require("../Core/Format")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Viewport = require("../UI/Viewport")
local Inventory = require("./Inventory")

type PetInstance = Types.PetInstance

local Craft = {}

local win: Windows.Window
local list: ScrollingFrame
local note: TextLabel
local lastSig = ""

local function render()
	if not win.IsOpen then
		return
	end
	local d = State.Data
	if not d then
		return
	end
	local busy = State.BusyUids()
	local trading = State.TradeUids()
	type Group = { Key: string, Sample: PetInstance, Count: number }
	local groups: { [string]: Group } = {}
	for _, p in d.Pets do
		if PetInfo.NextVariant(p.Variant) and not p.Locked and not busy[p.Uid] and not trading[p.Uid] then
			local key = PetInfo.CraftKey(p)
			local g = groups[key]
			if g then
				g.Count += 1
			else
				groups[key] = { Key = key, Sample = p, Count = 1 }
			end
		end
	end
	local arr: { Group } = {}
	local sig = ""
	for _, g in groups do
		table.insert(arr, g)
	end
	table.sort(arr, function(a, b)
		local ra, rb = a.Count >= Config.CraftCost, b.Count >= Config.CraftCost
		if ra ~= rb then
			return ra
		end
		local pa, pb = PetInfo.Power(a.Sample), PetInfo.Power(b.Sample)
		if pa ~= pb then
			return pa > pb
		end
		return a.Key < b.Key
	end)
	for _, g in arr do
		sig ..= g.Key .. g.Count .. ";"
	end
	if sig == lastSig then
		return
	end
	lastSig = sig
	Kit.clear(list)
	note.Visible = #arr == 0
	for i, g in arr do
		local p = g.Sample
		local nextVariant = PetInfo.NextVariant(p.Variant) or "Golden"
		local rc = Theme.RarityColor(PetInfo.Rarity(p.Id))
		local ready = g.Count >= Config.CraftCost
		local row = Kit.panel({
			Size = UDim2.new(1, -10, 0, 92),
			LayoutOrder = i,
			BackgroundColor3 = if ready then Theme.Lighten(Theme.Variant[nextVariant] or rc, 0.7) else Theme.Colors.Panel,
			Parent = list,
		})
		Viewport.Pet(p.Id, p.Variant, p.Shiny, { Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(6, 6), Parent = row })
		Kit.fitLabel("➜", 34, { Size = UDim2.fromOffset(40, 80), Position = UDim2.fromOffset(88, 6), Parent = row })
		Viewport.Pet(p.Id, nextVariant, p.Shiny, { Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(128, 6), Parent = row })
		Kit.fitLabel(PetInfo.FullName(p) .. "  ➜  " .. nextVariant, 22, {
			Size = UDim2.new(1, -460, 0, 32),
			Position = UDim2.fromOffset(218, 8),
			Align = "Left",
			Parent = row,
		})
		local bar, set = Kit.bar({ Size = UDim2.new(1, -460, 0, 26), Position = UDim2.fromOffset(218, 50) }, if ready then Theme.Colors.Good else Theme.Colors.Info)
		bar.Parent = row
		set(g.Count / Config.CraftCost, math.min(g.Count, Config.CraftCost) .. "/" .. Config.CraftCost .. (if g.Count > Config.CraftCost then "  (have " .. g.Count .. ")" else ""))
		local b = Kit.button(Theme.Icons.Craft .. " Craft  " .. Theme.Icons.Boost .. Format.num(PetInfo.Power({
			Uid = "",
			Id = p.Id,
			Variant = nextVariant,
			Shiny = p.Shiny,
			Level = 1,
			Xp = 0,
			Locked = false,
		})), "Purple", {
			Size = UDim2.fromOffset(220, 64),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Parent = row,
		}, function()
			Inventory.Craft(p)
		end)
		if not ready then
			Kit.setButton(b, { Enabled = false })
		end
	end
end

function Craft.Init()
	win = Windows.Create("Craft", { Title = "Craft Golden & Rainbow", Icon = Theme.Icons.Craft, Color = Theme.Tones.Purple.Top })
	Kit.fitLabel("Combine " .. Config.CraftCost .. " matching pets into one stronger pet. Locked pets and pets on expeditions are skipped.", 18, {
		Size = UDim2.new(1, 0, 0, 30),
		Font = Theme.FontBody,
		Color = Theme.Colors.TextDim,
		Parent = win.Body,
	})
	list = Kit.scroll({
		Size = UDim2.new(1, 0, 1, -38),
		Position = UDim2.fromOffset(0, 38),
		Parent = win.Body,
	}, { Kit.list(Enum.FillDirection.Vertical, 8), Kit.pad(4, 6, 6, 4) })
	note = Kit.fitLabel("No pets to craft yet. Hatch more of the same pet!", 22, {
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 150),
		Color = Theme.Colors.TextDim,
		Visible = false,
		Parent = win.Body,
	})
	win.Opened:Connect(function()
		lastSig = ""
		render()
	end)
	State.Changed:Connect(render)
end

return Craft
