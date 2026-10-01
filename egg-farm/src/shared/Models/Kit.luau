--!strict
-- Part kit shared by the world builders (server) and the visual models (client).
-- Everything is a native Part/WedgePart/CornerWedgePart with flat colours for a clean low-poly
-- look. Parts are Anchored, CanTouch off and CanQuery off by default; small parts don't cast
-- shadows. A part built with `role` takes its colour from the farm theme palette and keeps the
-- role as an attribute, so Kit.Recolor can repaint a whole farm when the egg (theme) changes.

local Themes = require("../Data/Themes")

local Kit = {}

export type Palette = { [string]: Color3 }

export type Opts = {
	size: Vector3,
	cf: CFrame,
	name: string?,
	role: string?, -- theme role: ground | groundEdge | path | wood | roof | accent
	shade: number?, -- 0..1 darkening applied on top of the role colour
	color: Color3?, -- fixed colour (ignored when role is set and a palette is known)
	material: Enum.Material?,
	shape: string?, -- "Block" (default) | "Ball" | "Cylinder" | "Wedge" | "CornerWedge"
	transparency: number?,
	collide: boolean?, -- default false for small parts, true for big ones
	shadow: boolean?,
	query: boolean?,
	reflect: number?,
}

Kit.Fixed = {
	white = Color3.fromRGB(245, 245, 240),
	cream = Color3.fromRGB(250, 238, 210),
	stone = Color3.fromRGB(160, 162, 168),
	darkStone = Color3.fromRGB(96, 98, 106),
	metal = Color3.fromRGB(190, 196, 204),
	darkMetal = Color3.fromRGB(70, 74, 82),
	asphalt = Color3.fromRGB(64, 66, 72),
	glass = Color3.fromRGB(170, 220, 255),
	black = Color3.fromRGB(28, 28, 32),
	orange = Color3.fromRGB(255, 150, 40),
	red = Color3.fromRGB(220, 52, 46),
	yellow = Color3.fromRGB(255, 212, 60),
	hay = Color3.fromRGB(232, 200, 110),
	leaf = Color3.fromRGB(70, 150, 70),
	trunk = Color3.fromRGB(120, 82, 52),
	skin = Color3.fromRGB(236, 190, 150),
}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Palette for a theme key (Data/Themes). Unknown keys fall back to the meadow.
function Kit.Palette(themeKey: string?): Palette
	local th = (Themes :: any)[themeKey or "meadow"] or (Themes :: any).meadow
	return {
		ground = rgb(th.ground),
		groundEdge = rgb(th.groundEdge),
		path = rgb(th.path),
		wood = rgb(th.wood),
		roof = rgb(th.roof),
		accent = rgb(th.accent),
		fog = rgb(th.fog),
		ambient = rgb(th.ambient),
	}
end

function Kit.Decor(themeKey: string?): string
	local th = (Themes :: any)[themeKey or "meadow"] or (Themes :: any).meadow
	return th.decor
end

local function shaded(c: Color3, shade: number?): Color3
	if not shade or shade == 0 then
		return c
	end
	return c:Lerp(Color3.new(0, 0, 0), math.clamp(shade, -1, 1))
end

local current: Palette = Kit.Palette("meadow")

-- Palette used for parts built with a role until the next SetPalette (builders call this first).
function Kit.SetPalette(p: Palette)
	current = p
end

function Kit.Part(parent: Instance?, o: Opts): BasePart
	local p: BasePart
	local shape = o.shape or "Block"
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	elseif shape == "CornerWedge" then
		p = Instance.new("CornerWedgePart")
	else
		local part = Instance.new("Part")
		if shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	p.Name = o.name or "Part"
	p.Anchored = true
	p.Size = o.size
	p.CFrame = o.cf
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local big = o.size.X * o.size.Y * o.size.Z > 60 or math.max(o.size.X, o.size.Y, o.size.Z) > 12
	p.CanCollide = if o.collide == nil then big else o.collide
	p.CastShadow = if o.shadow == nil then big else o.shadow
	p.CanTouch = false
	p.CanQuery = o.query == true
	p.Transparency = o.transparency or 0
	p.Reflectance = o.reflect or 0
	if o.role then
		p:SetAttribute("Role", o.role)
		if o.shade then
			p:SetAttribute("Shade", o.shade)
		end
		p.Color = shaded(current[o.role] or o.color or Kit.Fixed.white, o.shade)
	else
		p.Color = shaded(o.color or Kit.Fixed.white, o.shade)
	end
	p.Parent = parent
	return p
end

-- Vertical cylinder standing on `base` (centre of its bottom face).
function Kit.Column(parent: Instance?, base: CFrame, height: number, diameter: number, o: { [string]: any }?): BasePart
	local opts: any = table.clone(o or {})
	opts.shape = "Cylinder"
	opts.size = Vector3.new(height, diameter, diameter)
	opts.cf = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	return Kit.Part(parent, opts :: Opts)
end

-- Gable roof over a box of width w (x) and depth d (z), ridge along x, eaves at `cf` height.
-- Returns the two wedges.
function Kit.Gable(parent: Instance?, cf: CFrame, w: number, d: number, h: number, o: { [string]: any }?)
	local base: any = o or {}
	local a: any = table.clone(base)
	a.shape, a.size, a.cf = "Wedge", Vector3.new(w, h, d / 2), cf * CFrame.new(0, h / 2, -d / 4)
	local b: any = table.clone(base)
	b.shape, b.size, b.cf = "Wedge", Vector3.new(w, h, d / 2), cf * CFrame.new(0, h / 2, d / 4) * CFrame.Angles(0, math.pi, 0)
	return Kit.Part(parent, a :: Opts), Kit.Part(parent, b :: Opts)
end

-- Ellipsoid: a block part with a Sphere SpecialMesh (that mesh type stretches to the part's Size).
function Kit.Egg(parent: Instance?, cf: CFrame, size: Vector3, o: { [string]: any }?): BasePart
	local opts: any = table.clone(o or {})
	opts.shape = "Block"
	opts.size = size
	opts.cf = cf
	local p = Kit.Part(parent, opts :: Opts)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Repaint every role-tagged part under `root` with `palette`.
function Kit.Recolor(root: Instance, palette: Palette)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local role = d:GetAttribute("Role")
			if type(role) == "string" and palette[role] then
				local shade = d:GetAttribute("Shade")
				d.Color = shaded(palette[role], if type(shade) == "number" then shade else nil)
			end
		end
	end
end

-- New Model with an invisible Root part (PrimaryPart) at `cf`.
function Kit.Model(name: string, cf: CFrame?, rootSize: Vector3?): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = name
	local root = Kit.Part(m, {
		name = "Root",
		size = rootSize or Vector3.new(1, 1, 1),
		cf = cf or CFrame.identity,
		transparency = 1,
		collide = false,
		shadow = false,
	})
	m.PrimaryPart = root
	return m, root
end

-- A SurfaceGui text label on one face of a part.
function Kit.Label(part: BasePart, text: string, face: Enum.NormalId?, color: Color3?, ppu: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label" .. (face and face.Name or "Front")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 30
	gui.LightInfluence = 0
	gui.Parent = part
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.6
	l.Text = text
	l.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = l
	return l
end

return Kit
