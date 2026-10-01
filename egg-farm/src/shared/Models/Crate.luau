--!strict
-- Egg crate carried by workers and loaded on vehicles: a wooden box with three eggs on top.
-- PrimaryPart "Root" is the box, centred; the model's bottom is 0.7 studs below the pivot.

local Kit = require("./Kit")

local Crate = {}

function Crate.Build(scale: number?): Model
	local s = scale or 1
	local m = Instance.new("Model")
	m.Name = "EggCrate"
	local box = Kit.Part(m, {
		name = "Root",
		size = Vector3.new(2.4, 1.4, 1.8) * s,
		cf = CFrame.identity,
		color = Color3.fromRGB(176, 120, 70),
		material = Enum.Material.Wood,
		collide = false,
		shadow = false,
	})
	m.PrimaryPart = box
	Kit.Part(m, {
		name = "Band",
		size = Vector3.new(2.5, 0.3, 1.9) * s,
		cf = CFrame.new(0, 0.2 * s, 0),
		color = Color3.fromRGB(130, 84, 48),
		collide = false,
		shadow = false,
	})
	for i, x in { -0.7, 0, 0.7 } do
		Kit.Egg(m, CFrame.new(x * s, 0.95 * s, (if i == 2 then -0.15 else 0.15) * s), Vector3.new(0.6, 0.8, 0.6) * s, {
			name = "Egg",
			color = Kit.Fixed.cream,
			collide = false,
			shadow = false,
		})
	end
	return m
end

return Crate
