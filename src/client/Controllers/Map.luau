--!nonstrict
-- Minimap + full map (M). North-up. Shows paths, streams, landmarks, your
-- camp and build zone, enemy camps your clan has discovered, care package
-- markers, you and your teammates, plus personal reveals (Scavenger crates,
-- Hunter animals) and Sharpshooter marks.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")
local Panels = require("./Panels")

local MapCtl = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local mini: Frame
local full: Frame
local canvases: { Frame } = {}
local dynamic: { [Frame]: Frame } = {}
local packages: { [number]: { X: number, Z: number, Landed: boolean } } = {}
local camps: { [number]: { X: number, Z: number } } = {}
local reveals: { { Kind: string, Pos: Vector3, Until: number, Label: string } } = {}

local LANDMARK_GLYPH = { Glade = "✿", RockOutcrop = "▲", Ruins = "Π", Pond = "≈", Thicket = "⁂", FallenGiant = "═" }

local function toMap(data: any, x: number, z: number): UDim2
	local H = data.HalfSize
	local u = (x - data.Origin[1] + H) / (2 * H)
	local v = (z - data.Origin[2] + H) / (2 * H)
	return UDim2.fromScale(math.clamp(u, 0, 1), math.clamp(v, 0, 1))
end

local function segment(parent: Frame, size: Vector2, a: UDim2, b: UDim2, color: Color3, thick: number, dotted: boolean?)
	local ax, ay = a.X.Scale * size.X, a.Y.Scale * size.Y
	local bx, by = b.X.Scale * size.X, b.Y.Scale * size.Y
	local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
	if len < 0.5 then
		return
	end
	local f = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
		Size = UDim2.fromOffset(len + (if dotted then 0 else 1), thick),
		Rotation = math.deg(math.atan2(by - ay, bx - ax)),
		BackgroundColor3 = color,
		BackgroundTransparency = if dotted then 0.25 else 0,
		BorderSizePixel = 0,
		Parent = parent,
	})
	return f
end

local function marker(parent: Instance, glyph: string, color: Color3, size: number, pos: UDim2, z: number?): TextLabel
	return UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Text = glyph,
		TextScaled = true,
		Font = Theme.FontBlack,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		ZIndex = z or 3,
		Parent = parent,
	})
end

local function drawStatic(canvas: Frame, px: number)
	UI.clear(canvas)
	local data = State.Get("Map")
	if not data then
		return
	end
	local size = Vector2.new(px, px)
	local thick = math.max(1.5, px / 160)
	for _, s in data.Streams do
		for i = 1, #s - 1 do
			segment(canvas, size, toMap(data, s[i][1], s[i][2]), toMap(data, s[i + 1][1], s[i + 1][2]), Color3.fromRGB(90, 160, 230), thick * 1.6)
		end
	end
	for _, p in data.Paths do
		for i = 1, #p - 1 do
			segment(canvas, size, toMap(data, p[i][1], p[i][2]), toMap(data, p[i + 1][1], p[i + 1][2]), Color3.fromRGB(176, 140, 96), thick, true)
		end
	end
	if px >= 300 then
		for _, l in data.Landmarks do
			marker(canvas, LANDMARK_GLYPH[l.Type] or "•", Color3.fromRGB(220, 230, 200), 16, toMap(data, l.X, l.Z), 2)
		end
	end
	marker(canvas, "◎", Color3.fromRGB(230, 220, 190), if px >= 300 then 22 else 12, toMap(data, data.Origin[1], data.Origin[2]), 2)
	-- build zone ring for own camp
	if data.MyCamp then
		local r = data.BuildRadius / (2 * data.HalfSize) * px * 2
		local ring = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = toMap(data, data.MyCamp.X, data.MyCamp.Z), Size = UDim2.fromOffset(r, r), BackgroundTransparency = 1, Parent = canvas }, { UI.corner(UDim.new(0.5, 0)), UI.new("UIStroke", { Color = Config.Teams[data.MyTeam].Color, Thickness = 1.5, Transparency = 0.3 }) })
		ring.ZIndex = 2
	end
end

local function drawDynamic(canvas: Frame, px: number)
	local layer = dynamic[canvas]
	if not layer then
		return
	end
	UI.clear(layer)
	local data = State.Get("Map")
	if not data then
		return
	end
	local big = px >= 300
	local s = if big then 26 else 16
	local myTeam = player:GetAttribute("Team")
	-- camps
	for team, c in camps do
		local def = Config.Teams[team]
		marker(layer, def.Symbol, def.Color, s, toMap(data, c.X, c.Z), 4)
		local ms = ReplicatedStorage:FindFirstChild("MatchState")
		if big and ms and ms:GetAttribute("Fire" .. team) == false then
			marker(layer, "✖", C.Bad, s * 0.8, toMap(data, c.X, c.Z), 5)
		end
		if big then
			local lab = marker(layer, def.Name .. (if team == myTeam then " (you)" else ""), def.Color, 14, toMap(data, c.X, c.Z), 4)
			lab.Size = UDim2.fromOffset(120, 14)
			lab.Position += UDim2.fromOffset(0, 18)
		end
	end
	-- packages
	for _, p in packages do
		marker(layer, "✚", C.Accent, s, toMap(data, p.X, p.Z), 6)
	end
	-- reveals
	local now = os.clock()
	for i = #reveals, 1, -1 do
		local r = reveals[i]
		if now > r.Until then
			table.remove(reveals, i)
		else
			marker(layer, r.Label, if r.Kind == "Crates" then C.Warn else C.Bad, s * 0.8, toMap(data, r.Pos.X, r.Pos.Z), 6)
		end
	end
	-- players
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and p:GetAttribute("InMatch") then
			local sameTeam = p:GetAttribute("Team") == myTeam
			local marked = p:GetAttribute("MarkedTeam") == myTeam and (p:GetAttribute("MarkedUntil") or 0) > workspace:GetServerTimeNow()
			if p == player then
				local look = root.CFrame.LookVector
				local arrow = marker(layer, "▲", Color3.new(1, 1, 1), s, toMap(data, root.Position.X, root.Position.Z), 8)
				arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
			elseif sameTeam then
				marker(layer, "●", Config.Teams[myTeam].Color, s * 0.6, toMap(data, root.Position.X, root.Position.Z), 7)
			elseif marked then
				marker(layer, "◉", C.Bad, s * 0.8, toMap(data, root.Position.X, root.Position.Z), 7)
			end
		end
	end
end

local function makeCanvas(parent: Instance, px: number): Frame
	local canvas = UI.new("Frame", { Size = UDim2.fromOffset(px, px), BackgroundColor3 = Color3.fromRGB(46, 74, 44), BorderSizePixel = 0, ClipsDescendants = true, Parent = parent }, { UI.corner(UDim.new(0, 8)), UI.stroke(C.Stroke, 2, 0) })
	local static = UI.new("Frame", { Name = "Static", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = canvas })
	local dyn = UI.new("Frame", { Name = "Dynamic", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = canvas })
	dynamic[canvas] = dyn
	canvas:SetAttribute("Px", px)
	table.insert(canvases, canvas)
	static:SetAttribute("Px", px)
	return canvas
end

function MapCtl.Start()
	local gui = UI.new("ScreenGui", { Name = "Minimap", ResetOnSpawn = false, DisplayOrder = 2, Parent = player:WaitForChild("PlayerGui") })
	mini = makeCanvas(gui, 180)
	mini.AnchorPoint = Vector2.new(1, 0)
	mini.Position = UDim2.new(1, -12, 0, 8)
	local body = Panels.Create("Map", "MAP", Vector2.new(600, 660))
	full = makeCanvas(body, 560)
	UI.text("Enemy camps appear once a clanmate spots them. ✚ = care package · ◎ = centre stones · dashed = paths · blue = streams", { Position = UDim2.fromOffset(0, 566), Size = UDim2.new(1, 0, 0, 34), TextSize = 12, TextColor3 = C.TextDim, Parent = body })

	local function redrawStatic()
		for _, cv in canvases do
			drawStatic(cv:FindFirstChild("Static") :: Frame, cv:GetAttribute("Px") :: number)
		end
	end
	State.On("Map", function(data)
		camps = {}
		for _, c in data.Camps do
			camps[c.Team] = { X = c.X, Z = c.Z }
		end
		redrawStatic()
	end)
	State.On("MatchEvent", function(ev)
		local d = ev.Data
		if ev.Name == "CampRevealed" and d.Camp then
			camps[d.Team] = { X = d.Camp.X, Z = d.Camp.Z }
		elseif ev.Name == "CarePackage" then
			packages[d.Id] = { X = d.X, Z = d.Z, Landed = false }
		elseif ev.Name == "CarePackageOpened" then
			packages[d.Id] = nil
		elseif ev.Name == "Loading" or ev.Name == "ReturnedToLobby" then
			packages = {}
			camps = {}
			reveals = {}
		end
	end)
	State.On("Reveal", function(r)
		for _, item in r.List do
			local pos = if typeof(item) == "Vector3" then item else item.Pos
			table.insert(reveals, { Kind = r.Kind, Pos = pos, Until = os.clock() + (r.Duration or 8), Label = if r.Kind == "Crates" then "▣" else "☗" })
		end
	end)
	State.On("Action", function(a)
		if a.Down and a.Name == "Map" and player:GetAttribute("InMatch") then
			Panels.Toggle("Map")
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		mini.Visible = player:GetAttribute("InMatch") == true and State.Get("Map") ~= nil
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		if mini.Visible then
			drawDynamic(mini, 180)
		end
		if Panels.IsOpen("Map") then
			drawDynamic(full, 560)
		end
	end)
end

return MapCtl
