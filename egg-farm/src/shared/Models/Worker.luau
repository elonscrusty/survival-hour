--!strict
-- Farm workers, one look per tier (Data/Workers): Farmhand, Egg Runner, Rancher, Foreman,
-- Robo Picker, Jet Courier, Mech Hauler, Star Porter. Blocky figures about 5 studs tall, facing -Z,
-- Root at the feet. Rig groups for the walk cycle: legL, legR, armL, armR (pivots as model
-- attributes Pivot_<group>). Model attribute CarryOffset: where a carried crate sits (Root space).

local Kit = require("./Kit")

local Worker = {}

type Look = {
	shirt: Color3,
	pants: Color3,
	skin: Color3,
	hat: string,
	hatColor: Color3,
	extra: string?,
	scale: number?,
}

local F = Kit.Fixed
local LOOKS: { Look } = {
	{ shirt = Color3.fromRGB(206, 64, 54), pants = Color3.fromRGB(62, 96, 168), skin = F.skin, hat = "straw", hatColor = F.hay },
	{ shirt = Color3.fromRGB(255, 196, 50), pants = Color3.fromRGB(60, 60, 70), skin = Color3.fromRGB(198, 150, 110), hat = "cap", hatColor = Color3.fromRGB(230, 70, 60) },
	{ shirt = Color3.fromRGB(120, 84, 170), pants = Color3.fromRGB(70, 80, 110), skin = F.skin, hat = "cowboy", hatColor = Color3.fromRGB(130, 86, 50), extra = "bandana" },
	{ shirt = Color3.fromRGB(255, 140, 30), pants = Color3.fromRGB(50, 64, 90), skin = Color3.fromRGB(150, 104, 74), hat = "hardhat", hatColor = F.yellow, extra = "clipboard" },
	{ shirt = F.metal, pants = F.darkMetal, skin = F.metal, hat = "robot", hatColor = Color3.fromRGB(80, 230, 255) },
	{ shirt = Color3.fromRGB(40, 170, 170), pants = Color3.fromRGB(40, 50, 70), skin = F.skin, hat = "helmet", hatColor = F.white, extra = "jetpack" },
	{ shirt = F.darkMetal, pants = Color3.fromRGB(50, 52, 58), skin = F.darkMetal, hat = "mech", hatColor = Color3.fromRGB(255, 170, 40), extra = "mech" },
	{ shirt = F.white, pants = Color3.fromRGB(220, 224, 236), skin = F.white, hat = "astro", hatColor = Color3.fromRGB(255, 200, 60), extra = "star" },
}
Worker.Tiers = #LOOKS

function Worker.Build(tier: number?): Model
	local look = LOOKS[math.clamp(tier or 1, 1, #LOOKS)]
	local s = look.scale or 1
	if look.extra == "mech" then
		s = 1.25
	end
	local m, _root = Kit.Model("Worker", CFrame.identity, Vector3.new(0.2, 0.2, 0.2))
	local function p(name: string, size: Vector3, pos: Vector3, color: Color3, rig: string?, opts: { [string]: any }?): BasePart
		local o: any = table.clone(opts or {})
		o.name, o.size, o.cf, o.color = name, size * s, CFrame.new(pos * s), color
		o.collide = false
		o.shadow = false
		local part = Kit.Part(m, o)
		if rig then
			part:SetAttribute("Rig", rig)
		end
		return part
	end
	-- body
	p("LegL", Vector3.new(0.85, 2, 0.9), Vector3.new(-0.48, 1, 0), look.pants, "legL")
	p("LegR", Vector3.new(0.85, 2, 0.9), Vector3.new(0.48, 1, 0), look.pants, "legR")
	p("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), look.shirt)
	p("ArmL", Vector3.new(0.7, 1.9, 0.75), Vector3.new(-1.38, 3.05, 0), look.shirt, "armL")
	p("ArmR", Vector3.new(0.7, 1.9, 0.75), Vector3.new(1.38, 3.05, 0), look.shirt, "armR")
	p("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), look.skin)
	local hc = look.hatColor
	if look.hat == "straw" then
		p("HatBrim", Vector3.new(2.4, 0.15, 2.4), Vector3.new(0, 5.25, 0), hc)
		p("HatTop", Vector3.new(1.3, 0.55, 1.3), Vector3.new(0, 5.55, 0), hc)
		p("Bib", Vector3.new(1.4, 1.1, 0.12), Vector3.new(0, 2.6, -0.52), look.pants)
	elseif look.hat == "cap" then
		p("Cap", Vector3.new(1.3, 0.45, 1.3), Vector3.new(0, 5.35, 0), hc)
		p("Visor", Vector3.new(1.1, 0.12, 0.7), Vector3.new(0, 5.15, -0.9), hc)
	elseif look.hat == "cowboy" then
		p("HatBrim", Vector3.new(2.6, 0.15, 2.0), Vector3.new(0, 5.25, 0), hc)
		p("HatTop", Vector3.new(1.2, 0.7, 1.2), Vector3.new(0, 5.65, 0), hc)
	elseif look.hat == "hardhat" then
		p("Hard", Vector3.new(1.45, 0.8, 1.45), Vector3.new(0, 5.35, 0), hc, nil, { shape = "Ball" })
		p("HardBrim", Vector3.new(1.6, 0.12, 1.7), Vector3.new(0, 5.2, -0.1), hc)
		p("Stripe", Vector3.new(2.02, 0.25, 1.02), Vector3.new(0, 3.2, 0), Color3.fromRGB(230, 230, 210), nil, { material = Enum.Material.Neon })
	elseif look.hat == "robot" then
		p("Visor", Vector3.new(1.0, 0.35, 0.1), Vector3.new(0, 4.7, -0.62), hc, nil, { material = Enum.Material.Neon })
		p("Antenna", Vector3.new(0.12, 0.7, 0.12), Vector3.new(0, 5.5, 0), F.darkMetal)
		p("AntennaTip", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 5.9, 0), hc, nil, { material = Enum.Material.Neon, shape = "Ball" })
	elseif look.hat == "helmet" then
		p("Helmet", Vector3.new(1.5, 1.45, 1.5), Vector3.new(0, 4.75, 0), hc)
		p("Visor", Vector3.new(1.1, 0.5, 0.1), Vector3.new(0, 4.75, -0.76), F.glass, nil, { transparency = 0.2 })
	elseif look.hat == "mech" then
		p("Cockpit", Vector3.new(1.0, 0.5, 0.1), Vector3.new(0, 4.65, -0.62), hc, nil, { material = Enum.Material.Neon })
		p("PadL", Vector3.new(1.0, 0.6, 1.2), Vector3.new(-1.4, 4.1, 0), hc)
		p("PadR", Vector3.new(1.0, 0.6, 1.2), Vector3.new(1.4, 4.1, 0), hc)
	elseif look.hat == "astro" then
		p("Helmet", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 4.7, 0), F.white, nil, { shape = "Ball" })
		p("Visor", Vector3.new(1.1, 0.6, 0.15), Vector3.new(0, 4.75, -0.72), hc, nil, { reflect = 0.3 })
	end
	if look.extra == "bandana" then
		p("Bandana", Vector3.new(1.25, 0.35, 1.25), Vector3.new(0, 4.05, 0), Kit.Fixed.red)
	elseif look.extra == "clipboard" then
		p("Clipboard", Vector3.new(0.12, 1.0, 0.8), Vector3.new(-1.78, 2.6, -0.3), F.cream, "armL")
	elseif look.extra == "jetpack" then
		for _, x in { -0.45, 0.45 } do
			p("Jet", Vector3.new(0.7, 1.6, 0.7), Vector3.new(x, 3.1, 0.85), F.metal)
			p("Flame", Vector3.new(0.45, 0.6, 0.45), Vector3.new(x, 2.0, 0.85), F.orange, nil, { material = Enum.Material.Neon })
		end
	elseif look.extra == "star" then
		p("Badge", Vector3.new(0.6, 0.6, 0.1), Vector3.new(-0.5, 3.4, -0.52), hc, nil, { material = Enum.Material.Neon })
		p("Pack", Vector3.new(1.6, 1.8, 0.7), Vector3.new(0, 3.1, 0.85), Color3.fromRGB(200, 204, 216))
		p("PackLight", Vector3.new(0.3, 0.3, 0.1), Vector3.new(0.5, 3.6, 1.22), Color3.fromRGB(120, 240, 255), nil, { material = Enum.Material.Neon })
	end
	m:SetAttribute("Pivot_legL", Vector3.new(-0.48, 2, 0) * s)
	m:SetAttribute("Pivot_legR", Vector3.new(0.48, 2, 0) * s)
	m:SetAttribute("Pivot_armL", Vector3.new(-1.38, 3.9, 0) * s)
	m:SetAttribute("Pivot_armR", Vector3.new(1.38, 3.9, 0) * s)
	m:SetAttribute("CarryOffset", Vector3.new(0, 3.0, -1.5) * s)
	return m
end

return Worker
