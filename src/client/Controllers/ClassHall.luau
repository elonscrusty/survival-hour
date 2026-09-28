--!nonstrict
-- Class Hall: the full-screen class picker opened from the lobby (Panels "Classes").
--   left    scrolling grid of class cards (hex badge, name, rarity stars, price,
--           daily deal tag, EQUIPPED state) + "Show owned" filter and deal timer
--   centre  class name, the local avatar on a turning pedestal tinted in the class
--           colours, and one BUY / EQUIP button + EXIT
--   right   perks (class Lines), summary and a play-style tip
-- Deals and stars come from Logic/ClassDeals (the server charges the same price);
-- column sizes from Logic/ClassHallLayout. Classes are Diamond sidegrades only and
-- never give starter items. Built once by Lobby (ClassHall.Build); not auto-started.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Classes)
local Progression = require(Shared.Progression)
local ClassDeals = require(Shared.Logic.ClassDeals)
local ClassHallLayout = require(Shared.Logic.ClassHallLayout)
local ClassLevels = require(Shared.Logic.ClassLevels)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local Buttons = require("../UI/Buttons")
local State = require("../State")
local Panels = require("./Panels")

local ClassHall = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local EQUIPPED_BG = Color3.fromRGB(34, 84, 40)
local RARITY = { "Common", "Uncommon", "Rare", "Epic" }

local send: (string, { [string]: any }?) -> () = function() end
local root: Frame
local leftCol: Frame
local centreCol: Frame
local rightCol: Frame
local grid: ScrollingFrame
local gridLayout: UIGridLayout
local timerLabel: TextLabel
local walletLabel: TextLabel
local ownedToggle: TextButton
local titleLabel: TextLabel
local rarityLabel: TextLabel
local stage: Frame
local viewport: ViewportFrame
local glyphLabel: TextLabel
local pedestalRing: BasePart? = nil
local actionSet: (string, string?, string?) -> () = function() end
local actionBtn: TextButton
local actionFn: (() -> ())? = nil
local perksBody: ScrollingFrame
local selected: string? = nil
local showOwned = false
local renderedDay = -1

local function rgb(c: { number }?): Color3
	return if c and c[1] then Color3.fromRGB(c[1], c[2], c[3]) else C.Text
end

local function today(): number
	return Progression.DayNumber(workspace:GetServerTimeNow())
end

local function starsText(n: number): string
	return string.format('<font color="#F2C14E">%s</font><font color="#4A5058">%s</font>', string.rep("★", n), string.rep("★", 4 - n))
end

local DIAMOND = '<font color="#7EE0FF">◆</font>'

-- Hex badge -----------------------------------------------------------------------------------------
-- A pointy-top hexagon is the union of three R x R*sqrt(3) rectangles turned 30/90/150
-- degrees. A slightly bigger hexagon behind it in the class colour draws the rim
-- (a UIStroke would draw lines where the rectangles overlap).

local function hexLayer(parent: Instance, r: number, color: Color3, z: number)
	for _, rot in { 30, 90, 150 } do
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(r, r * math.sqrt(3)),
			Rotation = rot,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = parent,
		})
	end
end

local function hexBadge(glyph: string, color: Color3, size: number, props: { [string]: any }): Frame
	local f = UI.new("Frame", props)
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(size, size)
	local r = size / 2
	hexLayer(f, r, color, 1)
	hexLayer(f, r - math.max(3, size / 16), color:Lerp(Color3.new(0, 0, 0), 0.55), 2)
	-- inner shine: a smaller, lighter hexagon for a bit of depth
	hexLayer(f, r * 0.62, color:Lerp(Color3.new(0, 0, 0), 0.35), 3)
	UI.new("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Text = glyph,
		TextScaled = true,
		Font = Theme.FontBlack,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.6),
		ZIndex = 4,
		Parent = f,
	})
	return f
end

-- Avatar stage ---------------------------------------------------------------------------------------

local camera: Camera
local world: WorldModel
local avatar: Model? = nil
local avatarHeight = 5
local tintParts: { { Part: BasePart, Kind: string } } = {}
local spin: RBXScriptConnection? = nil
local angle = 0

local function bodyKind(name: string): string?
	if string.find(name, "Torso") then
		return "Torso"
	elseif string.find(name, "Arm") or string.find(name, "Hand") then
		return "Arm"
	elseif string.find(name, "Leg") or string.find(name, "Foot") then
		return "Leg"
	end
	return nil
end

-- Paints the preview in the class colours (torso/arms; darker legs), like the Outfit
-- cosmetic does with BodyColors. Parts are coloured directly: BodyColors is not
-- guaranteed to apply inside a ViewportFrame.
local function tint(def: Classes.Def)
	local color = rgb(def.Color)
	local legs = color:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, t in tintParts do
		if t.Part.Parent then
			t.Part.Color = if t.Kind == "Leg" then legs else color
		end
	end
	if pedestalRing then
		pedestalRing.Color = color
	end
	stage.BackgroundColor3 = color:Lerp(C.Panel, 0.78)
	glyphLabel.Text = def.Glyph
	glyphLabel.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.4)
end

local function cloneAvatar(): Model?
	local char = player.Character
	if not char then
		return nil
	end
	local was = char.Archivable
	char.Archivable = true
	local ok, copy = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not copy then
		return nil
	end
	local model = copy :: Model
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ForceField") or d:IsA("BodyColors") or d:IsA("ParticleEmitter") or d:IsA("Light") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CastShadow = false
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local hrp = model:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			model.PrimaryPart = hrp
			hrp.Transparency = 1
		end
	end
	return model
end

-- Clones the local avatar onto the pedestal. Falls back to the big class glyph.
local function buildAvatar()
	if avatar then
		avatar:Destroy()
		avatar = nil
	end
	table.clear(tintParts)
	local ok, model = pcall(cloneAvatar)
	if not ok or not model then
		glyphLabel.Visible = true
		return
	end
	local placed = pcall(function()
		model:PivotTo(CFrame.new())
		local bb, size = model:GetBoundingBox()
		-- feet on the pedestal top (y = 0), centred on the turn axis
		model:PivotTo(model:GetPivot() + Vector3.new(-bb.Position.X, size.Y / 2 - bb.Position.Y, -bb.Position.Z))
		avatarHeight = math.clamp(size.Y, 2, 14)
		model.Parent = world
	end)
	if not placed then
		model:Destroy()
		glyphLabel.Visible = true
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Parent == model then
			local kind = bodyKind(d.Name)
			if kind then
				table.insert(tintParts, { Part = d, Kind = kind })
			end
		end
	end
	avatar = model
	glyphLabel.Visible = false
end

local function buildStage()
	camera = UI.new("Camera", { FieldOfView = 36 })
	viewport.CurrentCamera = camera
	camera.Parent = viewport
	world = UI.new("WorldModel", { Parent = viewport })
	-- a cylinder's axis is X: turn it upright (Shape is set before Size on purpose)
	local function disc(name: string, y: number, height: number, diameter: number): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(height, diameter, diameter)
		p.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
		p.Anchored = true
		p.Parent = world
		return p
	end
	local base = disc("Pedestal", -0.4, 0.8, 5.6)
	base.Color = Color3.fromRGB(70, 74, 80)
	base.Material = Enum.Material.Slate
	local ring = disc("Ring", -0.62, 0.12, 6.1)
	ring.Material = Enum.Material.Neon
	pedestalRing = ring
end

-- Slow orbit of the camera (cheaper than moving every avatar part each frame; the
-- round pedestal makes it read as the avatar turning).
local function place(dt: number)
	angle = (angle + dt * 0.45) % (2 * math.pi)
	local h = avatarHeight
	local target = Vector3.new(0, h * 0.5, 0)
	local dist = h * 1.6 + 3
	camera.CFrame = CFrame.lookAt(target + Vector3.new(math.sin(angle) * dist, h * 0.18, -math.cos(angle) * dist), target)
end

local function startSpin()
	if spin or not camera then
		return
	end
	angle = 0
	place(0)
	spin = RunService.RenderStepped:Connect(place)
end

local function stopSpin()
	if spin then
		spin:Disconnect()
		spin = nil
	end
end

-- Perks column ----------------------------------------------------------------------------------------

local function perkGlyph(line: string): string
	local l = string.lower(line)
	if string.sub(l, 1, 3) == "no " then
		return "⚠"
	elseif string.find(l, "quiet") then
		return "🤫"
	elseif string.find(l, "wear") or string.find(l, "durab") or string.find(l, "last") then
		return "🛠"
	elseif string.find(l, "stamina") then
		return "💨"
	elseif string.find(l, "map") or string.find(l, "sense") or string.find(l, "sees") or string.find(l, "visib") or string.find(l, "cue") then
		return "👁"
	elseif string.find(l, "hide") or string.find(l, "slot") or string.find(l, "loot") then
		return "🎒"
	elseif string.find(l, "faster") then
		return "⚡"
	end
	return "✦"
end

-- "AxeSpeed" -> "Axe speed"
local function prettyKey(k: string): string
	local s = string.gsub(k, "(%l)(%u)", function(a, b)
		return a .. " " .. string.lower(b)
	end)
	return s
end

local function renderPerks(def: Classes.Def, profile: any)
	UI.clear(perksBody)
	local color = rgb(def.Color)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	-- Class level (Logic/ClassLevels): earned by playing the class, never bought.
	local view = profile and profile.ClassLevels and profile.ClassLevels[def.Id]
	if view then
		local head = UI.new("Frame", { LayoutOrder = nextOrder(), BackgroundColor3 = C.PanelLighter, BackgroundTransparency = 0.2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = perksBody }, {
			UI.corner(UDim.new(0, 8)),
			UI.padding(8),
			UI.list(Enum.FillDirection.Vertical, 4),
		})
		UI.text(string.format("CLASS LEVEL %d / %d", view.Level, ClassLevels.Max), { LayoutOrder = 1, TextSize = 16, Font = Theme.FontBlack, TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35), Parent = head })
		if view.Need then
			UI.text(string.format("Level %d: %s while playing %s", view.Level + 1, string.lower(view.Label), def.Name), { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, Parent = head })
			local holder = UI.new("Frame", { LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Parent = head })
			local _bar, set = UI.bar({ Size = UDim2.fromScale(1, 1), Parent = holder }, color)
			set(math.clamp(view.Progress / view.Need, 0, 1), string.format("%d / %d", view.Progress, view.Need))
			for i, b in ClassLevels.Boosts(def.Effects, view.Level) do
				UI.text(string.format("⬆ %s %d%% → %d%%", prettyKey(b.Key), b.From, b.To), { LayoutOrder = 3 + i, TextSize = 12, TextColor3 = C.TextDim, Parent = head })
			end
		else
			UI.text("Max level: percentage perks are 50% stronger.", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, Parent = head })
		end
	end
	for _, line in def.Lines do
		local row = UI.new("Frame", { LayoutOrder = nextOrder(), BackgroundColor3 = C.PanelLighter, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = perksBody }, {
			UI.corner(UDim.new(0, 8)),
			UI.padding(6),
		})
		local ic = UI.icon(perkGlyph(line), color, 28, "Round")
		ic.Parent = row
		UI.text(line, { Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -36, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 14, Font = Theme.FontBold, Parent = row })
		UI.new("UISizeConstraint", { MinSize = Vector2.new(0, 28), Parent = row })
	end
	UI.text(def.Summary, { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, TextColor3 = C.TextDim, Parent = perksBody })
	if def.Tip then
		UI.text("PLAY STYLE", { LayoutOrder = nextOrder(), TextSize = 15, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = perksBody })
		UI.text(def.Tip, { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, Parent = perksBody })
	end
	UI.text("Sidegrade only: never more damage or health. Everyone starts each match with nothing.", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 12, TextColor3 = C.TextDim, Parent = perksBody })
end

-- Cards -------------------------------------------------------------------------------------------------

local function classCard(def: Classes.Def, order: number, profile: any, deals: { [string]: number }, day: number)
	local color = rgb(def.Color)
	local owned = profile.OwnedClasses[def.Id] == true
	local equipped = profile.Class == def.Id
	local viewing = selected == def.Id
	local b = UI.new("TextButton", {
		Name = def.Id,
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if equipped then EQUIPPED_BG else C.PanelLight,
		BorderSizePixel = 0,
		Parent = grid,
	}, {
		UI.corner(UDim.new(0, 10)),
		UI.new("UIStroke", {
			Color = if viewing then C.Accent elseif equipped then C.Good else C.Stroke,
			Thickness = if viewing or equipped then 3 else 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	local cardW = gridLayout.CellSize.X.Offset
	local badge = math.floor(cardW * 0.54)
	hexBadge(def.Glyph, color, badge, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Parent = b })
	local function line(text: string, y: number, h: number, max: number, props: { [string]: any }?): TextLabel
		local p = props or {}
		p.Position = UDim2.new(0, 4, y, 0)
		p.Size = UDim2.new(1, -8, h, 0)
		p.TextScaled = true
		p.RichText = true
		p.TextXAlignment = Enum.TextXAlignment.Center
		p.Parent = b
		local l = UI.text(text, p)
		UI.new("UITextSizeConstraint", { MaxTextSize = max, Parent = l })
		return l
	end
	line(string.upper(def.Name), 0.55, 0.12, 16, { Font = Theme.FontBlack, TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35) })
	line(starsText(ClassDeals.Stars(def.Price)), 0.68, 0.1, 14)
	local pct = deals[def.Id]
	local price
	if equipped then
		price = '<font color="#70D278">✓ EQUIPPED</font>'
	elseif owned then
		price = '<font color="#70D278">OWNED</font>'
	elseif pct then
		price = string.format('<font color="#8A8F95"><s>%d</s></font> %s %d', def.Price, DIAMOND, ClassDeals.Price(def, day))
	else
		price = string.format("%s %d", DIAMOND, def.Price)
	end
	line(price, 0.8, 0.13, 15, { Font = Theme.FontBlack })
	if pct and not owned then
		UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 2, 0, -4), Size = UDim2.fromOffset(48, 22), Rotation = 10, BackgroundColor3 = C.Bad, BorderSizePixel = 0, ZIndex = 6, Parent = b }, {
			UI.corner(UDim.new(0, 5)),
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "-" .. pct .. "%", Font = Theme.FontBlack, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), ZIndex = 7 }),
		})
	end
	if equipped then
		UI.new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.Good, BorderSizePixel = 0, ZIndex = 6, Parent = b }, {
			UI.corner(UDim.new(0.5, 0)),
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "✓", Font = Theme.FontBlack, TextSize = 16, TextColor3 = Color3.fromRGB(16, 40, 18), ZIndex = 7 }),
		})
	elseif not owned then
		UI.text("🔒", { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(22, 22), TextSize = 14, TextTransparency = 0.25, ZIndex = 6, Parent = b })
	end
	b.Activated:Connect(function()
		if selected ~= def.Id then
			selected = def.Id
			local sfx = UI.ClickSound
			if sfx then
				sfx()
			end
			ClassHall.Render()
		end
	end)
end

-- Render --------------------------------------------------------------------------------------------------

local function renderAction(def: Classes.Def, profile: any, deals: { [string]: number }, day: number)
	local owned = profile.OwnedClasses[def.Id] == true
	if profile.Class == def.Id then
		actionSet("EQUIPPED ✓", nil, "Disabled")
		actionFn = nil
	elseif owned then
		Buttons.setTone(actionBtn, "Green")
		actionSet("EQUIP", "Locked in when the match starts", nil)
		actionFn = function()
			send("EquipClass", { Id = def.Id })
		end
	else
		local price = ClassDeals.Price(def, day)
		local pct = deals[def.Id]
		Buttons.setTone(actionBtn, "Gold")
		local short = price - (profile.Diamonds or 0)
		local sub = if short > 0 then string.format("Need %d more ◆ (win matches to earn them)", short) elseif pct then string.format("-%d%% today · was %d", pct, def.Price) else nil
		actionSet(string.format("BUY %s %d", DIAMOND, price), sub, if short > 0 then "Disabled" else nil)
		actionFn = function()
			send("BuyClass", { Id = def.Id, Price = price })
		end
	end
end

local function updateTimer()
	timerLabel.Text = "⏳ Deals reset in " .. ClassDeals.LeftText(ClassDeals.SecondsLeft(workspace:GetServerTimeNow()))
end

function ClassHall.Render()
	if not grid or not perksBody then
		return
	end
	UI.clear(grid)
	local profile = State.Get("Profile")
	if not profile then
		UI.text("Loading your profile…", { Parent = grid })
		return
	end
	local day = today()
	renderedDay = day
	local deals = ClassDeals.Deals(day)
	if not selected or not Classes.ById[selected] then
		selected = if Classes.ById[profile.Class] then profile.Class else Classes.Default
	end
	walletLabel.Text = string.format("%s %d", DIAMOND, profile.Diamonds or 0)
	updateTimer()
	Buttons.setState(ownedToggle, if showOwned then "Selected" else "Normal")
	ownedToggle.Text = if showOwned then "☑ OWNED ONLY" else "☐ OWNED ONLY"
	for i, def in Classes.List do
		if not showOwned or profile.OwnedClasses[def.Id] then
			classCard(def, def.Order or i, profile, deals, day)
		end
	end
	local def = Classes.ById[selected :: string]
	local color = rgb(def.Color)
	titleLabel.Text = string.upper(def.Name)
	titleLabel.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
	local stars = ClassDeals.Stars(def.Price)
	rarityLabel.Text = starsText(stars) .. "  " .. (RARITY[stars] or "")
	tint(def)
	renderAction(def, profile, deals, day)
	renderPerks(def, profile)
end

-- Layout ----------------------------------------------------------------------------------------------------

local function applyRect(f: Frame, r: ClassHallLayout.Rect)
	f.Position = UDim2.fromOffset(r.X, r.Y)
	f.Size = UDim2.fromOffset(r.W, r.H)
end

local function onFit(w: number, h: number)
	if not leftCol then
		return
	end
	local lay = ClassHallLayout.Compute(w, h)
	applyRect(leftCol, lay.Left)
	applyRect(centreCol, lay.Centre)
	applyRect(rightCol, lay.Right)
	local old = gridLayout.CellSize
	gridLayout.CellSize = UDim2.fromOffset(lay.CardW, lay.CardH)
	if old.X.Offset ~= lay.CardW and Panels.IsOpen("Classes") then
		ClassHall.Render() -- badge sizes follow the card width
	end
end

local function column(name: string): Frame
	return UI.new("Frame", { Name = name, BackgroundColor3 = C.PanelLight, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = root }, {
		UI.corner(UDim.new(0, 12)),
		UI.stroke(C.Stroke, 1.5, 0.4),
	})
end

function ClassHall.Build(sendFn: (string, { [string]: any }?) -> ())
	send = sendFn
	root = Panels.CreateScreen("Classes", onFit, function()
		selected = nil
		buildAvatar()
		startSpin()
		ClassHall.Render()
	end, function()
		stopSpin()
		if avatar then
			avatar:Destroy()
			avatar = nil
		end
	end)

	-- Left: header + card grid
	leftCol = column("Cards")
	UI.text("CLASS HALL", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -130, 0, 30), TextSize = 26, Font = Theme.FontBlack, TextColor3 = C.Accent, TextWrapped = false, Parent = leftCol })
	walletLabel = UI.text("", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(120, 26), TextSize = 20, Font = Theme.FontBlack, RichText = true, TextXAlignment = Enum.TextXAlignment.Right, Parent = leftCol })
	timerLabel = UI.text("", { Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -170, 0, 30), TextSize = 13, Font = Theme.FontBold, TextColor3 = C.Warn, Parent = leftCol })
	ownedToggle = UI.button("☐ OWNED ONLY", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 40), Size = UDim2.fromOffset(150, 32), TextSize = 13, Tone = "Neutral", Parent = leftCol }, function()
		showOwned = not showOwned
		ClassHall.Render()
	end)
	grid = UI.new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = ClassHallLayout.Scroll,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = leftCol,
	}, { UI.padding(ClassHallLayout.Pad) })
	gridLayout = UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(120, 156),
		CellPadding = UDim2.fromOffset(ClassHallLayout.CardGap, ClassHallLayout.CardGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	-- Centre: title, avatar stage, action + exit
	centreCol = column("Stage")
	centreCol.BackgroundTransparency = 1
	local stroke = centreCol:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 1
	end
	titleLabel = UI.text("", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 44), TextScaled = true, Font = Theme.FontBlack, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, Parent = centreCol })
	UI.new("UITextSizeConstraint", { MaxTextSize = 40, Parent = titleLabel })
	rarityLabel = UI.text("", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 22), TextSize = 16, Font = Theme.FontBold, RichText = true, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = centreCol })
	stage = UI.new("Frame", { Name = "Avatar", Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72 - 124), BackgroundColor3 = C.Panel, BorderSizePixel = 0, Parent = centreCol }, {
		UI.corner(UDim.new(0, 14)),
		UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.6) }),
	})
	viewport = UI.new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		Parent = stage,
	})
	glyphLabel = UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.6, 0.6), TextScaled = true, Font = Theme.FontBlack, Text = "", Visible = false, ZIndex = 3, Parent = stage })
	local ok, err = pcall(buildStage)
	if not ok then
		warn("[ClassHall] stage:", err)
	end
	local btn, set = Buttons.primary("EQUIP", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -52), Size = UDim2.new(1, -16, 0, 64), Parent = centreCol }, function()
		local fn = actionFn
		if fn then
			fn()
		end
	end)
	actionBtn, actionSet = btn, set
	Buttons.action("Exit", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(0.5, 0, 0, 40), Tone = "Red" }, function()
		Panels.Close()
	end).Parent = centreCol

	-- Right: perks
	rightCol = column("Perks")
	UI.text("PERKS", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 28), TextSize = 22, Font = Theme.FontBlack, TextColor3 = C.Accent, Parent = rightCol })
	perksBody = UI.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = rightCol,
	}, { UI.padding(10), UI.list(Enum.FillDirection.Vertical, 8) })

	-- First layout now that the columns exist, then keep the deal timer fresh.
	local vp = root.Size
	onFit(vp.X.Offset, vp.Y.Offset)
	task.spawn(function()
		while root.Parent do
			task.wait(15)
			if Panels.IsOpen("Classes") then
				if today() ~= renderedDay then
					ClassHall.Render() -- new UTC day: new deals
				else
					updateTimer()
				end
			end
		end
	end)
end

return ClassHall
