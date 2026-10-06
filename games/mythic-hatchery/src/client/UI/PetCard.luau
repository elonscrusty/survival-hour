--!strict
-- Pet tile used by every pet grid (inventory, crafting, expeditions, trade).
-- Rarity-coloured card with the pet picture, power, level and badges.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local Theme = require("./Theme")
local Kit = require("./Kit")
local Viewport = require("./Viewport")
local PetInfo = require("../Core/PetInfo")
local Format = require("../Core/Format")
local Sounds = require("../Core/Sounds")

type PetInstance = Types.PetInstance

local PetCard = {}

export type Flags = {
	Equipped: boolean?,
	Locked: boolean?,
	Busy: boolean?,
	Selected: boolean?,
	Marked: boolean?, -- red "to delete" outline
	Dim: boolean?,
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 110)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 90)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(140, 240, 110)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(100, 210, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 120, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 200)),
})
PetCard.RainbowSequence = RAINBOW

local function badge(text: string, color: Color3, pos: UDim2, anchor: Vector2, name: string, parent: Instance)
	local f = Kit.pill(text, color, {
		Name = name,
		Size = UDim2.fromOffset(34, 24),
		Position = pos,
		AnchorPoint = anchor,
		ZIndex = 5,
		Parent = parent,
	})
	f.Visible = false
	return f
end

-- Creates a card. size defaults to 100 x 118.
function PetCard.new(pet: PetInstance, size: Vector2?, onClick: (() -> ())?): TextButton
	local s = size or Vector2.new(100, 118)
	local rarity = PetInfo.Rarity(pet.Id)
	local rc = Theme.RarityColor(rarity)
	local card: TextButton = Kit.new("TextButton", {
		Name = pet.Uid,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(s.X, s.Y),
		BackgroundColor3 = Theme.Lighten(rc, 0.55),
		BorderSizePixel = 0,
	}, {
		Kit.corner(14),
		Kit.new("UIStroke", { Name = "Outline", Color = Theme.Darken(rc, 0.25), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Kit.new("UIScale", { Name = "Press" }),
	})
	card:SetAttribute("PetId", pet.Id)
	if pet.Variant == "Rainbow" then
		Kit.new("UIGradient", { Name = "Bg", Color = RAINBOW, Rotation = 35, Parent = card })
		card.BackgroundColor3 = Color3.new(1, 1, 1)
	elseif pet.Variant == "Golden" then
		Kit.new("UIGradient", {
			Name = "Bg",
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(240, 180, 40)),
			Parent = card,
		})
		card.BackgroundColor3 = Color3.new(1, 1, 1)
	else
		Kit.new("UIGradient", {
			Name = "Bg",
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
			Parent = card,
		})
	end
	Viewport.Pet(pet.Id, pet.Variant, pet.Shiny, {
		Size = UDim2.new(1, -8, 1, -30),
		Position = UDim2.fromOffset(4, 4),
		ZIndex = 2,
		Parent = card,
	})
	Kit.fitLabel(Theme.Icons.Boost .. Format.num(PetInfo.Power(pet)), 18, {
		Name = "Power",
		Size = UDim2.new(1, -8, 0, 24),
		Position = UDim2.new(0, 4, 1, -27),
		Outline = Theme.Darken(rc, 0.5),
		ZIndex = 4,
		Parent = card,
	})
	if (pet.Level or 1) > 1 then
		Kit.fitLabel("Lv" .. tostring(pet.Level), 14, {
			Name = "Level",
			Size = UDim2.fromOffset(40, 18),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, -28),
			Outline = true,
			Align = "Right",
			ZIndex = 4,
			Parent = card,
		})
	end
	if pet.Shiny then
		Kit.fitLabel(Theme.Icons.Shiny, 20, {
			Name = "Shiny",
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.new(0, 4, 1, -52),
			ZIndex = 4,
			Parent = card,
		})
	end
	badge(Theme.Icons.Equipped, Theme.Colors.Good, UDim2.fromOffset(-6, -6), Vector2.zero, "Equipped", card)
	badge(Theme.Icons.Lock, Theme.Colors.Warn, UDim2.new(1, 6, 0, -6), Vector2.new(1, 0), "Locked", card)
	badge(Theme.Icons.Expeditions, Theme.Colors.Info, UDim2.new(0.5, 0, 0, -6), Vector2.new(0.5, 0), "Busy", card)
	local press = card:FindFirstChild("Press") :: UIScale
	card.MouseButton1Down:Connect(function()
		Kit.tween(press, 0.08, { Scale = 0.93 })
	end)
	card.MouseButton1Up:Connect(function()
		Kit.tween(press, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	card.MouseLeave:Connect(function()
		Kit.tween(press, 0.15, { Scale = 1 })
	end)
	if onClick then
		card.Activated:Connect(function()
			Sounds.Play("Click")
			onClick()
		end)
	end
	return card
end

function PetCard.SetFlags(card: Instance, flags: Flags)
	local function show(name: string, on: boolean?)
		local b = card:FindFirstChild(name) :: GuiObject?
		if b then
			b.Visible = on == true
		end
	end
	show("Equipped", flags.Equipped)
	show("Locked", flags.Locked)
	show("Busy", flags.Busy)
	local outline = card:FindFirstChild("Outline") :: UIStroke?
	if outline then
		if flags.Marked then
			outline.Color = Theme.Colors.Bad
			outline.Thickness = 5
		elseif flags.Selected then
			outline.Color = Color3.fromRGB(40, 120, 255)
			outline.Thickness = 5
		else
			local id = card:GetAttribute("PetId")
			local rc = Theme.RarityColor(PetInfo.Rarity(if type(id) == "string" then id else ""))
			outline.Color = Theme.Darken(rc, 0.25)
			outline.Thickness = 3
		end
	end
	local pic = card:FindFirstChild("Picture") :: ViewportFrame?
	if pic then
		pic.ImageTransparency = if flags.Dim or flags.Busy then 0.55 else 0
	end
end

-- Card for a species (no instance): used by the Index and odds lists.
function PetCard.Species(petId: string, discovered: boolean, size: Vector2?): Frame
	local s = size or Vector2.new(100, 118)
	local rarity = PetInfo.Rarity(petId)
	local rc = Theme.RarityColor(rarity)
	local card: Frame = Kit.new("Frame", {
		Name = petId,
		Size = UDim2.fromOffset(s.X, s.Y),
		BackgroundColor3 = if discovered then Theme.Lighten(rc, 0.55) else Theme.Colors.PanelDark,
		BorderSizePixel = 0,
	}, {
		Kit.corner(14),
		Kit.stroke(if discovered then Theme.Darken(rc, 0.25) else Theme.Colors.Locked, 3),
		Kit.shade(0.2),
	})
	Viewport.Pet(petId, "Normal", false, {
		Size = UDim2.new(1, -8, 1, -30),
		Position = UDim2.fromOffset(4, 4),
		Silhouette = not discovered,
		Parent = card,
	})
	Kit.fitLabel(if discovered then PetInfo.Name(petId) else "???", 16, {
		Size = UDim2.new(1, -8, 0, 24),
		Position = UDim2.new(0, 4, 1, -27),
		Outline = if discovered then Theme.Darken(rc, 0.5) else Theme.Colors.Stroke,
		ZIndex = 3,
		Parent = card,
	})
	return card
end

return PetCard
