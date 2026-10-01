--!strict
-- Low-poly chicken (visual only, client side). About 2 studs tall, faces -Z, Root at the feet.
-- Rig groups (attribute "Rig" on parts, pivots as model attributes "Pivot_<group>"):
--   head (head, beak, comb) dips to peck; legL / legR swing while walking.

local Kit = require("./Kit")

local Chicken = {}

local VARIANTS = {
	{ body = Color3.fromRGB(250, 250, 245), tail = Color3.fromRGB(235, 235, 228) },
	{ body = Color3.fromRGB(176, 112, 62), tail = Color3.fromRGB(120, 72, 40) },
	{ body = Color3.fromRGB(246, 214, 120), tail = Color3.fromRGB(226, 176, 70) },
	{ body = Color3.fromRGB(70, 70, 78), tail = Color3.fromRGB(40, 44, 60) },
}
Chicken.Variants = #VARIANTS

function Chicken.Build(variant: number?): Model
	local v = VARIANTS[((variant or 1) - 1) % #VARIANTS + 1]
	local m, _root = Kit.Model("Chicken", CFrame.identity, Vector3.new(0.2, 0.2, 0.2))
	local function p(name: string, size: Vector3, pos: Vector3, color: Color3, rig: string?, shape: string?): BasePart
		local part = Kit.Part(m, {
			name = name,
			size = size,
			cf = CFrame.new(pos),
			color = color,
			shape = shape,
			collide = false,
			shadow = false,
		})
		if rig then
			part:SetAttribute("Rig", rig)
		end
		return part
	end
	p("Body", Vector3.new(1.2, 1.0, 1.5), Vector3.new(0, 1.0, 0.05), v.body)
	p("Tail", Vector3.new(0.9, 0.8, 0.55), Vector3.new(0, 1.55, 0.95), v.tail, nil, "Wedge")
	p("Head", Vector3.new(0.72, 0.78, 0.72), Vector3.new(0, 1.8, -0.62), v.body, "head")
	p("Beak", Vector3.new(0.26, 0.2, 0.34), Vector3.new(0, 1.72, -1.12), Kit.Fixed.orange, "head")
	p("Comb", Vector3.new(0.16, 0.32, 0.5), Vector3.new(0, 2.33, -0.62), Kit.Fixed.red, "head")
	p("LegL", Vector3.new(0.16, 0.55, 0.16), Vector3.new(-0.27, 0.27, 0.05), Kit.Fixed.orange, "legL")
	p("LegR", Vector3.new(0.16, 0.55, 0.16), Vector3.new(0.27, 0.27, 0.05), Kit.Fixed.orange, "legR")
	m:SetAttribute("Pivot_head", Vector3.new(0, 1.35, -0.45))
	m:SetAttribute("Pivot_legL", Vector3.new(-0.27, 0.55, 0.05))
	m:SetAttribute("Pivot_legR", Vector3.new(0.27, 0.55, 0.05))
	return m
end

return Chicken
