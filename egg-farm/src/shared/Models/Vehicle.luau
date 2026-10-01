--!strict
-- Shipping vehicles, one model per tier (Data/Vehicles): Farm Pickup, Delivery Van, Box Truck,
-- Egg Hauler, Double Trailer, Road Train, Hover Freighter, Sky Barge. Front faces -Z, Root at
-- ground level in the middle. Fixed colours (vehicles are not themed). Model attributes:
--   Length      overall length in studs (<= 24, fits a dock bay lane)
--   LoadOffset  Vector3 (Root space) where the egg crate sits when the vehicle is loaded
-- Max width is 8 studs so neighbouring bays (12 studs apart) never overlap.

local Kit = require("./Kit")

local Vehicle = {}

local F = Kit.Fixed
local TIRE = Color3.fromRGB(34, 34, 38)

function Vehicle.Build(tier: number?): Model
	local t = math.clamp(tier or 1, 1, 8)
	local m, _root = Kit.Model("Vehicle", CFrame.identity, Vector3.new(0.2, 0.2, 0.2))
	local function p(name: string, size: Vector3, pos: Vector3, color: Color3, opts: { [string]: any }?): BasePart
		local o: any = table.clone(opts or {})
		o.name, o.size, o.cf, o.color = name, size, CFrame.new(pos), color
		o.collide = false
		o.shadow = if o.shadow == nil then size.Magnitude > 8 else o.shadow
		return Kit.Part(m, o)
	end
	local function wheel(x: number, z: number, d: number)
		p("Wheel", Vector3.new(0.9, d, d), Vector3.new(x, d / 2, z), TIRE, { shape = "Cylinder", shadow = false })
	end
	local function wheels(halfW: number, zs: { number }, d: number)
		for _, z in zs do
			wheel(-halfW, z, d)
			wheel(halfW, z, d)
		end
	end
	local function lights(halfW: number, y: number, z: number)
		p("Light", Vector3.new(0.8, 0.5, 0.15), Vector3.new(-halfW + 0.7, y, z), Color3.fromRGB(255, 246, 200), { material = Enum.Material.Neon })
		p("Light", Vector3.new(0.8, 0.5, 0.15), Vector3.new(halfW - 0.7, y, z), Color3.fromRGB(255, 246, 200), { material = Enum.Material.Neon })
	end
	local function cab(z: number, len: number, h: number, w: number, color: Color3)
		p("Cab", Vector3.new(w, h, len), Vector3.new(0, 1.6 + h / 2, z), color)
		p("Windshield", Vector3.new(w - 0.6, h * 0.4, 0.2), Vector3.new(0, 1.6 + h * 0.68, z - len / 2 - 0.05), F.glass, { transparency = 0.15 })
		lights(w / 2, 2.2, z - len / 2 - 0.05)
	end
	local length, load = 12, Vector3.new(0, 2.5, 3)
	if t == 1 then -- Farm Pickup
		local red = Color3.fromRGB(214, 58, 48)
		p("Chassis", Vector3.new(6, 1, 12), Vector3.new(0, 1.3, 0), red)
		cab(-2.4, 4.6, 2.8, 5.6, red)
		p("BedL", Vector3.new(0.4, 1.2, 6.6), Vector3.new(-2.8, 2.4, 2.7), red)
		p("BedR", Vector3.new(0.4, 1.2, 6.6), Vector3.new(2.8, 2.4, 2.7), red)
		p("Tailgate", Vector3.new(6, 1.2, 0.4), Vector3.new(0, 2.4, 5.8), red)
		wheels(2.9, { -3.8, 3.8 }, 2.2)
	elseif t == 2 then -- Delivery Van
		length, load = 13, Vector3.new(0, 6.5, 1.5)
		p("Body", Vector3.new(6, 4.6, 9.5), Vector3.new(0, 3.5, 1.6), F.white)
		p("Hood", Vector3.new(6, 2.2, 3.2), Vector3.new(0, 2.3, -4.7), F.white)
		p("Windshield", Vector3.new(5.4, 1.8, 0.2), Vector3.new(0, 4.4, -3.2), F.glass, { transparency = 0.15 })
		p("Stripe", Vector3.new(6.1, 0.7, 9.6), Vector3.new(0, 3.2, 1.6), Color3.fromRGB(60, 150, 230))
		p("Rack", Vector3.new(5, 0.3, 6), Vector3.new(0, 5.95, 1.5), F.darkMetal)
		lights(3, 2.4, -6.35)
		wheels(2.9, { -4, 4 }, 2.2)
	elseif t == 3 then -- Box Truck
		length, load = 16, Vector3.new(0, 8.4, 2.4)
		p("Chassis", Vector3.new(6, 1, 15.5), Vector3.new(0, 1.3, 0), F.darkMetal)
		cab(-5.8, 4, 3.6, 6.6, Color3.fromRGB(56, 112, 210))
		p("Box", Vector3.new(7, 6, 11), Vector3.new(0, 4.8, 2.2), F.yellow)
		Kit.Egg(m, CFrame.new(-3.55, 4.8, 2.2), Vector3.new(0.2, 3.4, 2.6), { name = "Logo", color = F.white, collide = false, shadow = false })
		Kit.Egg(m, CFrame.new(3.55, 4.8, 2.2), Vector3.new(0.2, 3.4, 2.6), { name = "Logo", color = F.white, collide = false, shadow = false })
		wheels(3.1, { -5.6, 3.2, 6.2 }, 2.4)
	elseif t == 4 then -- Egg Hauler (semi with a giant egg on the flatbed)
		length, load = 18, Vector3.new(0, 3.1, -1.6)
		cab(-6.5, 5, 4.2, 6.6, Color3.fromRGB(200, 40, 40))
		p("Stack", Vector3.new(0.5, 3, 0.5), Vector3.new(-3.0, 6.6, -4.4), F.metal, { shape = "Block" })
		p("Stack", Vector3.new(0.5, 3, 0.5), Vector3.new(3.0, 6.6, -4.4), F.metal)
		p("Flatbed", Vector3.new(7, 0.8, 13), Vector3.new(0, 2.0, 2.4), Color3.fromRGB(150, 100, 60), { material = Enum.Material.Wood })
		Kit.Egg(m, CFrame.new(0, 5.4, 4.6), Vector3.new(5.2, 6.4, 5.2), { name = "BigEgg", color = F.cream, collide = false, shadow = true })
		wheels(3.1, { -6.5, 3.5, 6.8 }, 2.4)
	elseif t == 5 then -- Double Trailer
		length, load = 22, Vector3.new(0, 7.7, -2)
		cab(-8.6, 4.6, 4.2, 6.6, Color3.fromRGB(40, 150, 90))
		p("Trailer1", Vector3.new(7, 5.4, 8), Vector3.new(0, 4.6, -2), F.white)
		p("Trailer2", Vector3.new(7, 5.4, 8), Vector3.new(0, 4.6, 7), F.white)
		p("Band1", Vector3.new(7.1, 1, 8.1), Vector3.new(0, 3.2, -2), Color3.fromRGB(40, 150, 90))
		p("Band2", Vector3.new(7.1, 1, 8.1), Vector3.new(0, 3.2, 7), Color3.fromRGB(40, 150, 90))
		p("Hitch", Vector3.new(1, 0.6, 1.2), Vector3.new(0, 2.2, 2.5), F.darkMetal)
		wheels(3.1, { -8.6, -0.5, 4.5, 9.5 }, 2.2)
	elseif t == 6 then -- Road Train
		length, load = 24, Vector3.new(0, 7.2, -3.6)
		cab(-9.5, 5, 4.4, 6.8, Color3.fromRGB(240, 150, 30))
		p("Bullbar", Vector3.new(6.8, 1.6, 0.4), Vector3.new(0, 2.2, -12.2), F.metal)
		local colors = { Color3.fromRGB(200, 60, 50), Color3.fromRGB(60, 120, 210), Color3.fromRGB(250, 200, 50) }
		for i, z in { -3.6, 2.6, 8.8 } do
			p("Trailer", Vector3.new(6.8, 4.6, 5.6), Vector3.new(0, 4.3, z), colors[i])
		end
		wheels(3.2, { -9.5, -3.6, 2.6, 8.8 }, 2.2)
	elseif t == 7 then -- Hover Freighter
		length, load = 18, Vector3.new(0, 5.6, 2.5)
		p("Hull", Vector3.new(7, 3, 13), Vector3.new(0, 3.4, 1.5), F.metal)
		p("Nose", Vector3.new(7, 3, 4), Vector3.new(0, 3.4, -7), F.metal, { shape = "Wedge" })
		p("Canopy", Vector3.new(4.5, 1.4, 3), Vector3.new(0, 5.6, -3.5), F.glass, { transparency = 0.1, reflect = 0.2 })
		p("Stripe", Vector3.new(7.1, 0.5, 13.1), Vector3.new(0, 3.0, 1.5), Color3.fromRGB(120, 240, 255), { material = Enum.Material.Neon })
		for _, x in { -2.6, 2.6 } do
			for _, z in { -3.5, 6 } do
				Kit.Column(m, CFrame.new(x, 1.0, z), 0.6, 2.4, { name = "HoverPad", color = Color3.fromRGB(120, 240, 255), material = Enum.Material.Neon, collide = false, shadow = false })
			end
		end
		p("Fin", Vector3.new(0.4, 2.5, 2.5), Vector3.new(0, 6, 7.2), F.darkMetal, { shape = "Wedge" })
	else -- Sky Barge
		length, load = 20, Vector3.new(0, 8.4, 2)
		local hull = Color3.fromRGB(150, 96, 60)
		p("Hull", Vector3.new(7.5, 3, 14), Vector3.new(0, 6.2, 1), hull, { material = Enum.Material.Wood })
		p("Bow", Vector3.new(7.5, 3, 4), Vector3.new(0, 6.2, -8), hull, { shape = "Wedge", material = Enum.Material.Wood })
		p("Deck", Vector3.new(7, 0.3, 14), Vector3.new(0, 7.75, 1), Color3.fromRGB(190, 140, 90), { material = Enum.Material.Wood })
		Kit.Egg(m, CFrame.new(0, 15, 1), Vector3.new(7.5, 6, 15), { name = "Balloon", color = Color3.fromRGB(230, 90, 200), collide = false, shadow = true })
		for _, x in { -3, 3 } do
			for _, z in { -4, 6 } do
				p("Rope", Vector3.new(0.15, 4.6, 0.15), Vector3.new(x, 10, z), Color3.fromRGB(230, 220, 190))
			end
		end
		p("PropHub", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 6.5, 8.3), F.darkMetal)
		p("Prop", Vector3.new(5, 0.6, 0.2), Vector3.new(0, 6.5, 8.75), F.metal)
		p("Glow", Vector3.new(5, 0.4, 10), Vector3.new(0, 4.6, 1), Color3.fromRGB(255, 200, 90), { material = Enum.Material.Neon, transparency = 0.3 })
	end
	m:SetAttribute("Length", length)
	m:SetAttribute("LoadOffset", load)
	m:SetAttribute("Tier", t)
	return m
end

return Vehicle
