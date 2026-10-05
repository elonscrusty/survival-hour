--!strict
-- Hatch animation: the egg(s) appear in front of the camera, shake faster and
-- faster, flash white and reveal the pet with rarity-coloured rays, its name,
-- rarity and "NEW!" when it is the first of its species. Fast Hatch shortens
-- it; triple hatches show three eggs side by side. Tap to skip the hold.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local State = require("../Core/State")
local PetInfo = require("../Core/PetInfo")
local Format = require("../Core/Format")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Viewport = require("../UI/Viewport")
local PetCard = require("../UI/PetCard")

type PetInstance = Types.PetInstance

local HatchAnim = {}

HatchAnim.Playing = false

local function rays(parent: Instance, color: Color3): Frame
	local holder: Frame = Kit.box({
		Name = "Rays",
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		ZIndex = 2,
		Parent = parent,
	})
	for i = 1, 12 do
		Kit.new("Frame", {
			Size = UDim2.fromOffset(46, 520),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = i * 15,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = holder,
		}, {
			Kit.new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.35, 0.55),
					NumberSequenceKeypoint.new(0.5, 0.2),
					NumberSequenceKeypoint.new(0.65, 0.55),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	-- soft glow disc in the middle
	Kit.new("Frame", {
		Size = UDim2.fromOffset(260, 260),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.Lighten(color, 0.4),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = holder,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	return holder
end

-- Plays the animation and yields until it finishes (or is skipped).
-- `indexBefore` is the player's Index before hatching, for "NEW!".
function HatchAnim.Play(eggId: string, pets: { PetInstance }, indexBefore: { [string]: boolean }, auto: boolean?)
	if #pets == 0 then
		return
	end
	HatchAnim.Playing = true
	local fast = State.HasPass("FastHatch")
	local total = if fast then Config.FastHatchAnimSeconds else Config.HatchAnimSeconds
	local shakeT = total * 0.62
	local holdT = if auto then 0.9 else 1.6

	local gui = Windows.Gui("Overlay")
	local root: Frame = Kit.new("Frame", {
		Name = "Hatch",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Backdrop,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	Kit.tween(root, 0.25, { BackgroundTransparency = 0.35 })
	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = Lighting
	Kit.tween(blur, 0.25, { Size = 14 })

	local stage: Frame = Kit.box({
		Size = UDim2.fromOffset(Theme.RefWidth, Theme.RefHeight),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = root,
	})
	Kit.autoScale(stage, 1)

	local n = #pets
	local spacing = if n >= 3 then 290 else 330
	local slotSize = if n >= 3 then 250 else 320
	local slots: { Frame } = {}
	local eggs: { ViewportFrame } = {}
	for i = 1, n do
		local x = (i - (n + 1) / 2) * spacing
		local slot: Frame = Kit.box({
			Size = UDim2.fromOffset(slotSize, slotSize + 120),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, x, 0.5, 0),
			Parent = stage,
		})
		slots[i] = slot
		local vp = Viewport.Egg(eggId, {
			Size = UDim2.fromOffset(slotSize, slotSize),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			ZIndex = 3,
			Angle = 0,
			Parent = slot,
		})
		Kit.pop(vp, 0.3)
		eggs[i] = vp
	end

	local skip = false
	local tapConn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			skip = true
		end
	end)

	-- shake, faster and faster
	local t0 = os.clock()
	local lastTick = 0
	local shakeConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local p = math.clamp(t / shakeT, 0, 1)
		local freq = 7 + 30 * p * p
		local amp = math.rad(5 + 16 * p)
		local angle = math.sin(t * freq) * amp
		for _, vp in eggs do
			local m = Viewport.ModelOf(vp)
			if m then
				m:PivotTo(CFrame.Angles(0, 0, angle))
			end
		end
		local period = math.pi / freq
		if t - lastTick > period * 2 then
			lastTick = t
			Sounds.Play("EggShake", 0.8 + p * 0.8)
		end
	end)
	task.wait(shakeT)
	shakeConn:Disconnect()

	-- flash
	local flash: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = root,
	})
	Kit.tween(flash, 0.45, { BackgroundTransparency = 1 })
	task.delay(0.5, function()
		flash:Destroy()
	end)

	-- reveal
	local best = 1
	local rayHolders: { Frame } = {}
	local seen: { [string]: boolean } = table.clone(indexBefore)
	for i, pet in pets do
		eggs[i]:Destroy()
		local slot = slots[i]
		local rarity = PetInfo.Rarity(pet.Id)
		local rc = Theme.RarityColor(rarity)
		best = math.max(best, PetInfo.RarityIndex(rarity))
		table.insert(rayHolders, rays(slot, rc))
		local vp = Viewport.Pet(pet.Id, pet.Variant, pet.Shiny, {
			Size = UDim2.fromOffset(slotSize, slotSize),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			ZIndex = 4,
			Spin = true,
			Parent = slot,
		})
		Kit.pop(vp, 0.2)
		local nameColor = if pet.Variant == "Golden" then Theme.Variant.Golden else rc
		local name = Kit.fitLabel(PetInfo.FullName(pet), 34, {
			Size = UDim2.new(1, 40, 0, 44),
			Position = UDim2.new(0, -20, 0, slotSize - 6),
			Color = Color3.new(1, 1, 1),
			Outline = Theme.Darken(nameColor, 0.35),
			ZIndex = 6,
			Parent = slot,
		})
		if pet.Variant == "Rainbow" then
			Kit.new("UIGradient", { Color = PetCard.RainbowSequence, Parent = name })
		end
		Kit.fitLabel(rarity .. "  " .. Theme.Icons.Boost .. Format.num(PetInfo.Power(pet)), 24, {
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 0, slotSize + 38),
			Color = rc,
			Outline = Theme.Darken(rc, 0.6),
			ZIndex = 6,
			Parent = slot,
		})
		if not seen[pet.Id] then
			seen[pet.Id] = true
			local newTag = Kit.pill("NEW!", Theme.Colors.Bad, {
				Size = UDim2.fromOffset(110, 44),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -40, 0, 30),
				Rotation = 12,
				ZIndex = 8,
				Parent = slot,
			})
			Kit.pop(newTag, 0.2)
		end
		if pet.Shiny then
			Kit.fitLabel(Theme.Icons.Shiny .. " SHINY " .. Theme.Icons.Shiny, 26, {
				Size = UDim2.new(1, 0, 0, 34),
				Position = UDim2.fromOffset(0, -10),
				Color = Color3.fromRGB(255, 250, 200),
				Outline = true,
				ZIndex = 8,
				Parent = slot,
			})
		end
	end
	Sounds.Play(if best >= PetInfo.RarityIndex("Legendary") then "Rare" else "Hatch")
	local spinConn = RunService.RenderStepped:Connect(function(dt: number)
		for _, h in rayHolders do
			h.Rotation += dt * 25
		end
	end)

	local revealT = total - shakeT + holdT
	local start = os.clock()
	skip = false
	while os.clock() - start < revealT and not (skip and os.clock() - start > 0.35) do
		task.wait()
	end
	spinConn:Disconnect()
	tapConn:Disconnect()
	Kit.tween(root, 0.2, { BackgroundTransparency = 1 })
	Kit.tween(blur, 0.2, { Size = 0 })
	task.wait(0.2)
	root:Destroy()
	blur:Destroy()
	HatchAnim.Playing = false
end

return HatchAnim
