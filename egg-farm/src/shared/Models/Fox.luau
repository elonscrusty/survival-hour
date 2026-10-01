--!strict
-- The Lucky Fox: a small orange low-poly fox, about 2.6 studs tall, faces -Z, Root at the feet.
-- Rig group "tail" (pivot attribute Pivot_tail) can be wagged by whoever animates it.

local Kit = require("./Kit")

local Fox = {}

function Fox.Build(): Model
	local m, root = Kit.Model("LuckyFox", CFrame.identity, Vector3.new(2.4, 2.6, 4))
	root.CanQuery = true -- lets click/tap detection and prompts find the fox
	local orange = Color3.fromRGB(240, 128, 40)
	local white = Kit.Fixed.white
	local dark = Color3.fromRGB(50, 36, 30)
	local function p(name: string, size: Vector3, cf: CFrame, color: Color3, shape: string?, rig: string?)
		local part = Kit.Part(m, { name = name, size = size, cf = cf, color = color, shape = shape, collide = false, shadow = false })
		if rig then
			part:SetAttribute("Rig", rig)
		end
	end
	p("Body", Vector3.new(1.3, 1.1, 2.4), CFrame.new(0, 1.35, 0.1), orange)
	p("Chest", Vector3.new(1.0, 0.8, 0.5), CFrame.new(0, 1.2, -1.0), white)
	p("Head", Vector3.new(1.2, 1.0, 1.0), CFrame.new(0, 2.2, -1.2), orange)
	p("Snout", Vector3.new(0.6, 0.45, 0.7), CFrame.new(0, 2.0, -1.95), white)
	p("Nose", Vector3.new(0.22, 0.2, 0.2), CFrame.new(0, 2.15, -2.32), dark)
	p("EarL", Vector3.new(0.4, 0.55, 0.25), CFrame.new(-0.35, 2.95, -1.2), orange, "Wedge")
	p("EarR", Vector3.new(0.4, 0.55, 0.25), CFrame.new(0.35, 2.95, -1.2), orange, "Wedge")
	for i, pos in { Vector3.new(-0.4, 0.4, -0.8), Vector3.new(0.4, 0.4, -0.8), Vector3.new(-0.4, 0.4, 0.9), Vector3.new(0.4, 0.4, 0.9) } do
		p("Leg" .. i, Vector3.new(0.3, 0.8, 0.3), CFrame.new(pos), dark)
	end
	p("Tail", Vector3.new(0.7, 0.7, 1.6), CFrame.new(0, 1.7, 1.9) * CFrame.Angles(math.rad(25), 0, 0), orange, nil, "tail")
	p("TailTip", Vector3.new(0.55, 0.55, 0.5), CFrame.new(0, 2.05, 2.65) * CFrame.Angles(math.rad(25), 0, 0), white, nil, "tail")
	m:SetAttribute("Pivot_tail", Vector3.new(0, 1.5, 1.2))
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 220, 90)
	sparkle.Parent = root
	return m
end

return Fox
