--!strict
-- Builds the roadside world and every plot, then shows/hides each plot's pads, buildings and
-- props to match its owner's profile. Hidden pieces wait in ServerStorage (cheap to toggle).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Economy = require(Shared.Logic.Economy)
local Game = require(Shared.Logic.Game)
local Format = require(Shared.Logic.Format)
local Models = require("./Models")

local C = Models.Colors
local part = Models.part

local World = {}

export type Plot = {
	index: number,
	origin: CFrame,
	folder: Folder,
	hidden: Folder,
	owner: Player?,
	pads: { [string]: BasePart }, -- pad parts
	padModels: { [string]: Model }, -- prop shown once the pad is owned
	buildings: { [string]: Model },
	anchors: { [string]: BasePart },
	prompts: { [string]: ProximityPrompt },
	extras: { [string]: Model }, -- portal, staircase, investor kiosk
	sign: BasePart,
	shown: { [string]: boolean? }, -- keyed by "pad:"/"prop:"/"biz:"/"extra:" + id
}

World.plots = {} :: { Plot }
-- callbacks set by GameService
World.onPadTouched = nil :: ((Player, string) -> ())?
World.onBizPrompt = nil :: ((Player, string) -> ())?
World.onExtraPrompt = nil :: ((Player, string) -> ())?

local function setupLighting()
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(120, 115, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 145, 140)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.6
	local function ensure(cls: string, name: string): Instance
		local x = Lighting:FindFirstChild(name)
		if not x then
			x = Instance.new(cls)
			x.Name = name
			x.Parent = Lighting
		end
		return x :: Instance
	end
	local atm = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atm.Density = 0.22
	atm.Haze = 0.6
	atm.Color = Color3.fromRGB(200, 230, 255)
	atm.Decay = Color3.fromRGB(150, 200, 240)
	atm.Glare = 0.15
	ensure("Sky", "Sky")
	local cc = ensure("ColorCorrectionEffect", "Vibrance") :: ColorCorrectionEffect
	cc.Saturation = 0.18
	cc.Contrast = 0.05
	cc.Brightness = 0.02
	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 1.6
end

local function tree(parent: Instance, pos: Vector3, scale: number)
	local m = Instance.new("Model")
	m.Name = "Tree"
	Models.part(m, Vector3.new(1.4, 6, 1.4) * scale, CFrame.new(pos + Vector3.new(0, 3 * scale, 0)), C.woodDark)
	local leaf = Color3.fromRGB(90, 185, 85)
	local p1 = Models.part(m, Vector3.new(7, 7, 7) * scale, CFrame.new(pos + Vector3.new(0, 8 * scale, 0)), leaf)
	p1.Shape = Enum.PartType.Ball
	local p2 = Models.part(m, Vector3.new(5, 5, 5) * scale, CFrame.new(pos + Vector3.new(1.8, 6.8, 1) * scale), Color3.fromRGB(110, 200, 95))
	p2.Shape = Enum.PartType.Ball
	m.Parent = parent
end

local function flowers(parent: Instance, pos: Vector3, w: number)
	part(parent, Vector3.new(w, 0.6, 3), CFrame.new(pos + Vector3.new(0, 0.3, 0)), C.woodDark)
	local cols = { C.ketchup, C.mustard, C.cream, C.violet }
	for i = 0, math.floor(w / 1.5) - 1 do
		local f = part(parent, Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos + Vector3.new(-w / 2 + 0.75 + i * 1.5, 1, (i % 2) * 0.8 - 0.4)), cols[i % #cols + 1])
		f.Shape = Enum.PartType.Ball
		f.CanCollide = false
	end
end

local function buildEnvironment()
	local env = Instance.new("Folder")
	env.Name = "Environment"
	env.Parent = workspace
	local width = Layout.PLOT_SPACING * Config.Plots + 400
	local cx = Layout.PLOT_SPACING * (Config.Plots - 1) / 2
	local ground = part(env, Vector3.new(width, 2, 900), CFrame.new(cx, -1, 160), Color3.fromRGB(110, 190, 90), { material = Enum.Material.Grass, name = "Ground" })
	ground.CastShadow = false
	-- the road along the front of every plot
	part(env, Vector3.new(width, 0.2, 16), CFrame.new(cx, 0.1, Layout.ROAD_Z), Color3.fromRGB(70, 72, 80), { material = Enum.Material.Asphalt, name = "Road" })
	for x = -width / 2, width / 2, 12 do
		part(env, Vector3.new(6, 0.22, 0.6), CFrame.new(cx + x, 0.12, Layout.ROAD_Z), C.mustard, { collide = false })
	end
	for _, dz in { -9.5, 9.5 } do
		part(env, Vector3.new(width, 0.5, 3), CFrame.new(cx, 0.25, Layout.ROAD_Z + dz), Color3.fromRGB(225, 220, 210), { material = Enum.Material.Concrete })
	end
	-- far side of the road: trees and a little hill line
	for x = -width / 2 + 10, width / 2 - 10, 18 do
		tree(env, Vector3.new(cx + x + (x % 7), 0, Layout.ROAD_Z - 22 - (x % 11)), 1 + (x % 5) / 10)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "FallbackSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(cx, 0.5, Layout.ROAD_Z)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Parent = env
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

local function label(parent: BasePart, title: string, sub: string, color: Color3)
	local bb = Instance.new("BillboardGui")
	bb.Name = "PadLabel"
	bb.Size = UDim2.fromScale(9, 3.2)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = parent
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.55)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = title
	t.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Color3.fromRGB(40, 30, 20)
	st.Parent = t
	local p = Instance.new("TextLabel")
	p.Name = "Price"
	p.BackgroundTransparency = 1
	p.Position = UDim2.fromScale(0, 0.55)
	p.Size = UDim2.fromScale(1, 0.45)
	p.Font = Enum.Font.FredokaOne
	p.TextScaled = true
	p.TextColor3 = color
	p.Text = sub
	p.Parent = bb
	local st2 = st:Clone()
	st2.Parent = p
end

local function makePad(plot: Plot, pad: Economy.PadDef, pos: Vector3)
	local cf = plot.origin * CFrame.new(pos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local isUnlock = pad.kind == "unlock"
	local d = if isUnlock then 10 else 7
	local base = part(plot.hidden, Vector3.new(0.5, d, d), cf, if isUnlock then C.mustard else C.relish, { shape = Enum.PartType.Cylinder, name = pad.id })
	base.CanCollide = false
	base.CastShadow = false
	base:SetAttribute("PadId", pad.id)
	base:SetAttribute("Plot", plot.index)
	local ring = part(base, Vector3.new(0.55, d * 0.78, d * 0.78), cf * CFrame.new(0.02, 0, 0), C.cream, { shape = Enum.PartType.Cylinder, collide = false })
	ring.CastShadow = false
	ring.Name = "Ring"
	local core = part(base, Vector3.new(0.6, d * 0.66, d * 0.66), cf * CFrame.new(0.04, 0, 0), if isUnlock then C.ketchup else C.teal, { shape = Enum.PartType.Cylinder, collide = false, neon = false })
	core.CastShadow = false
	core.Name = "Core"
	label(base, pad.name, Format.cash(pad.cost), Color3.fromRGB(140, 255, 140))
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "NewSparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(0.6, 1.2)
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(30, 30)
	sparkle.Size = NumberSequence.new(0.5)
	sparkle.Color = ColorSequence.new(C.mustard)
	sparkle.EmissionDirection = Enum.NormalId.Right -- local +X is world up for this cylinder
	sparkle.Parent = base
	base.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and player == plot.owner and World.onPadTouched then
			World.onPadTouched(player, pad.id)
		end
	end)
	plot.pads[pad.id] = base
end

local function buildPlot(index: number): Plot
	local origin = Layout.plotOrigin(index)
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder.Parent = workspace:WaitForChild("Plots")
	local hidden = Instance.new("Folder")
	hidden.Name = "Plot" .. index
	hidden.Parent = ServerStorage:WaitForChild("PlotStore")
	local plot: Plot = {
		index = index,
		origin = origin,
		folder = folder,
		hidden = hidden,
		owner = nil,
		pads = {},
		padModels = {},
		buildings = {},
		anchors = {},
		prompts = {},
		extras = {},
		sign = nil :: any,
		shown = {},
	}
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder

	-- driveway, central path and lot bases
	part(decor, Vector3.new(14, 0.3, 370), origin * CFrame.new(0, 0.15, 185), Color3.fromRGB(235, 222, 196), { material = Enum.Material.Pebble, name = "Path" })
	for id, lot in Layout.lots do
		local base = part(decor, Vector3.new(lot.size.X, 0.4, lot.size.Y), origin * CFrame.new(lot.pos + Vector3.new(0, 0.2, 0)), if id == "stand" then Color3.fromRGB(240, 226, 196) else Color3.fromRGB(214, 222, 228), { material = Enum.Material.Concrete, name = id .. "Lot" })
		base.CastShadow = false
		if id ~= "stand" and id ~= "hotdogx" then
			-- spur from the central path (half-width 7) to the lot's inner edge
			local inner = math.abs(lot.pos.X) - lot.size.X / 2
			local sign = if lot.pos.X > 0 then 1 else -1
			part(decor, Vector3.new(inner - 7 + 1, 0.3, 8), origin * CFrame.new(sign * (7 + inner) / 2, 0.16, lot.pos.Z), Color3.fromRGB(235, 222, 196), { material = Enum.Material.Pebble })
		end
	end
	-- plot border hedges with a gap at the road
	for _, x in { -Layout.PLOT_HALF_WIDTH, Layout.PLOT_HALF_WIDTH } do
		part(decor, Vector3.new(3, 3, Layout.PLOT_DEPTH - 20), origin * CFrame.new(x, 1.5, Layout.PLOT_DEPTH / 2 + 4), Color3.fromRGB(80, 160, 70), { material = Enum.Material.Grass })
	end
	-- landscaping kept off lots, pads and the path
	for _, z in { 64, 140, 220, 300, 372 } do
		tree(decor, origin.Position + Vector3.new(-98, 0, z), 1.1)
		tree(decor, origin.Position + Vector3.new(98, 0, z + 8), 1.2)
	end
	for _, z in { 64, 128, 212, 292 } do
		flowers(decor, origin.Position + Vector3.new(-12, 0, z), 6)
		flowers(decor, origin.Position + Vector3.new(12, 0, z), 6)
	end
	-- plot sign by the road
	local signModel = Instance.new("Model")
	signModel.Name = "PlotSign"
	part(signModel, Vector3.new(0.8, 7, 0.8), origin * CFrame.new(-11, 3.5, -8), C.woodDark)
	part(signModel, Vector3.new(0.8, 7, 0.8), origin * CFrame.new(11, 3.5, -8), C.woodDark)
	plot.sign = Models.sign(signModel, Vector3.new(24, 3.4, 0.5), origin * CFrame.new(0, 7.6, -8), C.mustard, "Open plot", C.ketchup)
	signModel.Parent = decor

	-- spawn point
	local spawn = Instance.new("Part")
	spawn.Name = "SpawnPoint"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.CFrame = origin * CFrame.new(Layout.spawn)
	spawn.Parent = folder

	-- pads, buildings, props, label anchors
	for _, pad in Economy.pads do
		if pad.kind == "unlock" then
			makePad(plot, pad, Layout.unlockPos(pad.bizId))
		end
	end
	local anchors = Instance.new("Folder")
	anchors.Name = "Anchors"
	anchors.Parent = folder
	for _, biz in Economy.businesses do
		local lot = Layout.lots[biz.id]
		local b = Models.build(Models.BUILDING_FOR[biz.id])
		Models.place(b, origin * CFrame.new(lot.pos), plot.hidden)
		b.Name = biz.id
		plot.buildings[biz.id] = b
		local nProps = 0
		for _, pad in biz.pads do
			if pad.kind ~= "structure" then
				nProps += 1
			end
		end
		local slot = 0
		for k, pad in biz.pads do
			makePad(plot, pad, Layout.padPos(biz.id, k))
			local prop = Models.build(pad.model or "Sign")
			if pad.kind == "structure" then
				-- floors and walls belong to the whole lot
				Models.place(prop, origin * CFrame.new(lot.pos), plot.hidden)
			else
				slot += 1
				Models.fit(prop, Layout.PROP_SLOT)
				Models.place(prop, origin * CFrame.new(Layout.propPos(biz.id, slot, nProps)), plot.hidden)
			end
			prop.Name = "Prop_" .. pad.id
			plot.padModels[pad.id] = prop
		end
		local anchor = part(anchors, Vector3.new(1, 1, 1), origin * CFrame.new(lot.pos + Vector3.new(0, if biz.id == "stand" then 17 else 24, -lot.size.Y / 2 + 2)), C.white, { transparency = 1, collide = false, name = biz.id })
		anchor.CanQuery = false
		anchor:SetAttribute("BizId", biz.id)
		plot.anchors[biz.id] = anchor
		-- Sell/Start prompt on the front of the lot
		local promptPart = part(anchors, Vector3.new(1, 1, 1), origin * CFrame.new(lot.pos + Vector3.new(0, 3, -lot.size.Y / 2 + 4)), C.white, { transparency = 1, collide = false, name = biz.id .. "Prompt" })
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Sell"
		prompt.ObjectText = biz.name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = promptPart
		prompt.Triggered:Connect(function(player)
			if player == plot.owner and World.onBizPrompt then
				World.onBizPrompt(player, biz.id)
			end
		end)
		plot.prompts[biz.id] = prompt
	end

	-- prestige landmarks (shown when relevant)
	local function extra(name: string, model: string, pos: Vector3, action: string, text: string)
		local m = Models.build(model)
		Models.place(m, origin * CFrame.new(pos), plot.hidden)
		m.Name = name
		local pp = part(m, Vector3.new(1, 1, 1), origin * CFrame.new(pos + Vector3.new(0, 3, -4)), C.white, { transparency = 1, collide = false })
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = text
		prompt.ObjectText = ""
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = pp
		prompt.Triggered:Connect(function(player)
			if player == plot.owner and World.onExtraPrompt then
				World.onExtraPrompt(player, action)
			end
		end)
		plot.extras[name] = m
	end
	extra("InvestorKiosk", "AlienInvestor", Layout.investorDesk + Vector3.new(-10, 0, 0), "investors", "Alien Investors")
	extra("Portal", "CosmicPortal", Layout.portal, "evolve", "Void Evolution")
	extra("Staircase", "Staircase", Layout.staircase, "ascend", "Ascension")

	-- ingredient racks (always there; crates are spawned by the Pickups service)
	for i, pos in Layout.racks do
		local r = Models.build("IngredientRack")
		Models.place(r, origin * CFrame.new(pos) * CFrame.Angles(0, if pos.X > 0 then math.rad(-90) else math.rad(90), 0), decor)
		r.Name = "Rack" .. i
	end
	return plot
end

function World.init()
	setupLighting()
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
	local store = Instance.new("Folder")
	store.Name = "PlotStore"
	store.Parent = ServerStorage
	buildEnvironment()
	for i = 1, Config.Plots do
		table.insert(World.plots, buildPlot(i))
	end
end

function World.assign(player: Player): Plot?
	for _, plot in World.plots do
		if plot.owner == nil then
			plot.owner = player
			player:SetAttribute("Plot", plot.index)
			return plot
		end
	end
	return nil
end

function World.release(player: Player)
	for _, plot in World.plots do
		if plot.owner == player then
			plot.owner = nil
			player:SetAttribute("Plot", nil)
			local pickups = plot.folder:FindFirstChild("Pickups")
			if pickups then
				pickups:Destroy()
			end
			World.reset(plot)
		end
	end
end

function World.plotOf(player: Player): Plot?
	local i = player:GetAttribute("Plot")
	local plot = if type(i) == "number" then World.plots[i] else nil
	return if plot and plot.owner == player then plot else nil
end

local function show(plot: Plot, key: string, inst: Instance, on: boolean, parent: Instance)
	if (plot.shown[key] == true) == on then
		return
	end
	plot.shown[key] = on or nil
	inst.Parent = if on then parent else plot.hidden
end

function World.reset(plot: Plot)
	for id, inst in plot.pads do
		show(plot, "pad:" .. id, inst, false, plot.folder)
	end
	for id, inst in plot.padModels do
		show(plot, "prop:" .. id, inst, false, plot.folder)
	end
	for id, inst in plot.buildings do
		show(plot, "biz:" .. id, inst, false, plot.folder)
	end
	for id, inst in plot.extras do
		show(plot, "extra:" .. id, inst, false, plot.folder)
	end
	for _, pr in plot.prompts do
		pr.Enabled = false
	end
	local tl = plot.sign:FindFirstChild("Text", true) :: TextLabel?
	if tl then
		tl.Text = "Open plot"
	end
end

-- Match the plot to its owner's profile. Returns ids of things that just appeared.
function World.sync(plot: Plot, p: any, name: string): { string }
	local appeared = {}
	local ms = Game.multState(p)
	for _, pad in Economy.pads do
		local owned = Game.owns(p, pad.id)
		local visible = not owned and Game.padVisible(p, pad)
		local padPart = plot.pads[pad.id]
		if visible and not plot.shown["pad:" .. pad.id] then
			local price = padPart:FindFirstChild("PadLabel") and (padPart :: any).PadLabel.Price
			if price then
				price.Text = Format.cash(Game.padCost(p, pad))
			end
		end
		show(plot, "pad:" .. pad.id, padPart, visible, plot.folder)
		if pad.kind == "unlock" then
			local b = plot.buildings[pad.bizId]
			local on = owned
			if on and not plot.shown["biz:" .. pad.bizId] then
				table.insert(appeared, pad.id)
			end
			show(plot, "biz:" .. pad.bizId, b, on, plot.folder)
		else
			local m = plot.padModels[pad.id]
			local on = owned and Game.bizOwned(p, pad.bizId)
			if on and not plot.shown["prop:" .. pad.id] then
				table.insert(appeared, pad.id)
			end
			show(plot, "prop:" .. pad.id, m, on, plot.folder)
		end
	end
	for _, biz in Economy.businesses do
		local owned = Game.bizOwned(p, biz.id)
		plot.prompts[biz.id].Enabled = owned and not require(Shared.Logic.Economy).isAutomated(ms, biz)
	end
	-- landmarks: kiosk once investors are on offer or held, portal once evolution progress shows,
	-- staircase once every pad is owned
	local offered = Game.investorsOffered(p)
	show(plot, "extra:InvestorKiosk", plot.extras.InvestorKiosk, offered.m > 0 or p.investors.m > 0 or (p.stats.rebirths or 0) > 0, plot.folder)
	show(plot, "extra:Portal", plot.extras.Portal, p.investors.m > 0 or p.evolutions > 0, plot.folder)
	show(plot, "extra:Staircase", plot.extras.Staircase, (Game.canAscend(p)) or p.ascensions > 0, plot.folder)
	local tl = plot.sign:FindFirstChild("Text", true) :: TextLabel?
	if tl and tl.Text ~= name then
		tl.Text = name
	end
	local standSign = plot.buildings.stand:FindFirstChild("NameSign")
	local st = standSign and standSign:FindFirstChild("Text", true) :: TextLabel?
	if st then
		local recipe = Economy.recipeName(p.evolutions)
		st.Text = if recipe == "Classic" then "HOT DOGS" else string.upper(recipe) .. " DOGS"
	end
	return appeared
end

return World
