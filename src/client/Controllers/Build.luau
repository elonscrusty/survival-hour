--!nonstrict
-- Free-placement build mode with a live preview.
--   PC: move the mouse to position, R / Q to rotate, LMB place, RMB or B to exit.
--   Touch: aim with the camera centre, on-screen ◀ ▶ PLACE ✖ buttons.
-- Walls, gates and reinforced walls snap end-to-end to nearby clan walls.
-- The preview shows green/red using the same PlacementRules the server uses;
-- the server re-validates everything (plus terrain, characters, cost, limits).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local Net = require(Shared.Net)
local PlacementRules = require(Shared.Logic.PlacementRules)
local Structures = require(Shared.Models.Structures)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")
local Panels = require("./Panels")

local Build = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
Build.Active = false
local zoneRing: Part? = nil
local currentId: string? = nil
local ghost: Model? = nil
local yaw = 0
local lastValid = false
local lastReason: string? = nil
local ghostPos: Vector3? = nil
local touchBar: Frame
local statusLabel: TextLabel
local conn: RBXScriptConnection? = nil

-- Structures whose ends snap together (walls, doors, gates; floors snap edge to edge too).
local WALLS = {
	WoodWall = true, Gate = true, ReinforcedWall = true, ReinforcedDoor = true, WindowWall = true,
	ScrapWall = true, MetalWall = true, HeavyGate = true, WoodFloor = true,
}

local function aimPoint(): Vector3?
	local char = player.Character
	local useMouse = not State.Get("IsTouch")
	local ray
	if useMouse then
		local m = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(m.X, m.Y)
	else
		local vp = camera.ViewportSize
		ray = camera:ViewportPointToRay(vp.X / 2, vp.Y * 0.55)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if char then
		table.insert(ignore, char)
	end
	if ghost then
		table.insert(ignore, ghost)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 120, params)
	return hit and hit.Position
end

local function existingRects(): { PlacementRules.Rect }
	local out = {}
	local match = workspace:FindFirstChild("Match")
	local folder = match and match:FindFirstChild("Structures")
	if folder then
		for _, m in folder:GetChildren() do
			local root = m:IsA("Model") and m.PrimaryPart
			if root then
				local _, ry = root.CFrame:ToOrientation()
				table.insert(out, { X = root.Position.X, Z = root.Position.Z, HX = root.Size.X / 2, HZ = root.Size.Z / 2, Yaw = -math.deg(ry), Model = m })
			end
		end
	end
	return out
end

-- Snap wall ends together (keeps rotation; moves the ghost so the nearest ends meet).
local function snap(pos: Vector3, id: string, rects: { any }): Vector3
	if not WALLS[id] then
		return pos
	end
	local half = (Items[id].Size :: Vector3).X / 2
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
	local myEnds = { (cf * CFrame.new(half, 0, 0)).Position, (cf * CFrame.new(-half, 0, 0)).Position }
	local best, bestD = nil, 3.5
	for _, r in rects do
		local m = r.Model :: Model
		if m and WALLS[m:GetAttribute("Structure") or ""] and m:GetAttribute("Team") == player:GetAttribute("Team") then
			local rc = (m.PrimaryPart :: BasePart).CFrame
			for _, sx in { -r.HX, r.HX } do
				local e = (rc * CFrame.new(sx, 0, 0)).Position
				for _, mine in myEnds do
					local d = Vector3.new(e.X - mine.X, 0, e.Z - mine.Z).Magnitude
					if d < bestD then
						bestD = d
						best = Vector3.new(e.X - mine.X, 0, e.Z - mine.Z)
					end
				end
			end
		end
	end
	return if best then pos + best else pos
end

local function tint(valid: boolean)
	if not ghost then
		return
	end
	for _, d in ghost:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" and d.Name ~= "Collider" and d.Name ~= "Hurt" then
			d.Color = if valid then Color3.fromRGB(120, 230, 140) else Color3.fromRGB(240, 90, 80)
		end
	end
end

local function update()
	if not Build.Active or not currentId or not ghost then
		return
	end
	local p = aimPoint()
	if not p then
		return
	end
	local grid = Config.Build.GridSnap
	local pos = Vector3.new(math.floor(p.X / grid + 0.5) * grid, p.Y, math.floor(p.Z / grid + 0.5) * grid)
	local rects = existingRects()
	pos = snap(pos, currentId, rects)
	ghostPos = pos
	-- ease the ghost toward the target so it glides instead of teleporting
	local target = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
	local cur = ghost:GetPivot()
	ghost:PivotTo(if (cur.Position - pos).Magnitude > 12 then target else cur:Lerp(target, 0.45))
	local map = State.Get("Map")
	local camp = map and map.MyCamp
	local valid, reason = false, "No camp"
	if camp then
		local size = Items[currentId].Size :: Vector3
		local existing = {}
		for _, r in camp.StaticRects do
			table.insert(existing, r)
		end
		for _, r in rects do
			table.insert(existing, r)
		end
		valid, reason = PlacementRules.Check({ X = pos.X, Z = pos.Z, HX = size.X / 2, HZ = size.Z / 2, Yaw = -yaw }, {
			Fire = { X = camp.X, Z = camp.Z },
			ZoneRadius = Config.Build.ZoneRadius,
			Clearances = camp.Clearances,
			Existing = existing,
			LimitUsed = 0,
			LimitMax = 999,
		})
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if valid and root and Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z).Magnitude > Config.Build.MaxPlaceDistance then
			valid, reason = false, "Too far away"
		end
	end
	lastValid, lastReason = valid, reason
	tint(valid)
	local recipe = Recipes.ByResult[currentId]
	local costs = {}
	for id, n in recipe.Cost do
		table.insert(costs, n .. " " .. Items[id].Name)
	end
	statusLabel.Text = Items[currentId].Name .. "  ·  " .. table.concat(costs, ", ") .. "\n" .. (if valid then "✓ Valid spot" else "✖ " .. tostring(reason))
	statusLabel.TextColor3 = if valid then Theme.Colors.Good else Theme.Colors.Bad
end

function Build.Begin(id: string)
	if not player:GetAttribute("InMatch") or player:GetAttribute("LifeState") ~= "Alive" then
		return
	end
	Build.Stop()
	currentId = id
	Build.Active = true
	State.Set("Building", true)
	local team = player:GetAttribute("Team") or 1
	local g = Structures.Build(id, CFrame.new(0, -500, 0), Config.Teams[team].Color, workspace.CurrentCamera)
	for _, d in g:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = true
			d.CastShadow = false
			if d.Transparency < 1 then
				d.Transparency = 0.45
			end
			d.Material = Enum.Material.ForceField
		end
	end
	ghost = g
	-- show the build zone around your fire while placing
	local map = State.Get("Map")
	local camp = map and map.MyCamp
	if camp then
		local rootY = (player.Character and player.Character:GetPivot().Position.Y) or 0
		local ring = Instance.new("Part")
		ring.Name = "BuildZone"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.3, Config.Build.ZoneRadius * 2, Config.Build.ZoneRadius * 2)
		ring.CFrame = CFrame.new(camp.X, rootY - 2.8, camp.Z) * CFrame.Angles(0, 0, math.rad(90))
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.ForceField
		ring.Color = Config.Teams[team].Color
		ring.Transparency = 0.2
		ring.Parent = workspace.CurrentCamera
		zoneRing = ring
	end
	touchBar.Visible = true
	conn = RunService.RenderStepped:Connect(update)
end

function Build.Stop()
	Build.Active = false
	State.Set("Building", false)
	currentId = nil
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if zoneRing then
		zoneRing:Destroy()
		zoneRing = nil
	end
	if touchBar then
		touchBar.Visible = false
	end
end

local function rotate(dir: number)
	yaw = (yaw + dir * Config.Build.RotateStep) % 360
end

local function place()
	if not Build.Active or not currentId or not ghostPos then
		return
	end
	if not lastValid then
		State.Emit("Notify", { Text = lastReason or "Can't build there.", Kind = "error" })
		return
	end
	Net.Event("PlaceStructure"):FireServer({ Id = currentId, Pos = ghostPos, Yaw = yaw })
end

local pickerBody: ScrollingFrame

local function renderPicker()
	UI.clear(pickerBody)
	local team = player:GetAttribute("Team") or 0
	local ms = ReplicatedStorage:FindFirstChild("MatchState")
	local level = ms and ms:GetAttribute("Bench" .. team) or 1
	local order = 0
	for _, r in Recipes.List do
		if r.Kind == "Structure" then
			order += 1
			local def = Items[r.Result]
			local locked = r.Level > level
			local b = UI.button("", { LayoutOrder = order, Size = UDim2.fromOffset(170, 120), BackgroundColor3 = if locked then Theme.Colors.PanelLight else Theme.Colors.PanelLighter, Parent = pickerBody }, function()
				if not locked then
					Panels.Close()
					Build.Begin(r.Result)
				end
			end)
			local ic = UI.icon(def.Icon.Glyph, def.Icon.Color, 48, "Square", "Item_" .. r.Result)
			ic.AnchorPoint = Vector2.new(0.5, 0)
			ic.Position = UDim2.new(0.5, 0, 0, 8)
			ic.Parent = b
			UI.text(def.Name, { Position = UDim2.fromOffset(0, 60), TextSize = 15, Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
			UI.text(if locked then "🔒 Workbench Tier " .. ({ "I", "II", "III", "IV", "V" })[r.Level] else ("HP " .. tostring(def.Health) .. (if def.Limit == "Trap" then " · trap" elseif def.Stacks then " · " .. def.Stacks .. " stacks" else "")), { Position = UDim2.fromOffset(0, 84), TextSize = 13, TextColor3 = Theme.Colors.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
		end
	end
end

function Build.Start()
	local gui = UI.new("ScreenGui", { Name = "BuildMode", ResetOnSpawn = false, DisplayOrder = 6, Parent = player:WaitForChild("PlayerGui") })
	touchBar = UI.panel({ Size = UDim2.fromOffset(460, 118), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Visible = false, Parent = gui }, { UI.padding(8) })
	statusLabel = UI.text("", { Size = UDim2.new(1, 0, 0, 40), TextSize = 15, Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = touchBar })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 52), Parent = touchBar }, { UI.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })
	UI.button("◀", { Size = UDim2.fromOffset(64, 52), TextSize = 26, Parent = row }, function()
		rotate(-1)
	end)
	UI.button("▶", { Size = UDim2.fromOffset(64, 52), TextSize = 26, Parent = row }, function()
		rotate(1)
	end)
	UI.button("✓ PLACE", { Size = UDim2.fromOffset(140, 52), TextSize = 20, Font = Theme.FontBlack, Tone = "Green", Parent = row }, place)
	UI.button("✖", { Size = UDim2.fromOffset(64, 52), TextSize = 22, Tone = "Red", Parent = row }, Build.Stop)
	UI.text("PC: R/Q rotate · click to place · right-click to exit", { Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextColor3 = Theme.Colors.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = touchBar })

	pickerBody = Panels.Create("Build", "BUILD", Vector2.new(600, 330), renderPicker)
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(176, 126), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pickerBody })

	State.On("BeginBuild", Build.Begin)
	State.On("Action", function(a)
		if a.Name == "Build" and a.Down then
			if Build.Active then
				Build.Stop()
			elseif player:GetAttribute("InMatch") then
				Panels.Toggle("Build")
			end
			return
		end
		if not Build.Active then
			return
		end
		if a.Down then
			if a.Name == "Rotate" then
				rotate(if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then -1 else 1)
			elseif a.Name == "Swap" then
				rotate(-1) -- Q rotates the other way in build mode
			elseif a.Name == "Attack" and not State.Get("IsTouch") then
				place()
			elseif a.Name == "Aim" then
				Build.Stop()
			end
		end
	end)
	State.On("MatchEvent", function(ev)
		if ev.Name == "BuildResult" and ev.Data.Ok and currentId and not WALLS[currentId] then
			Build.Stop() -- single placement for non-wall structures; walls stay in build mode for chaining
		end
	end)
	player:GetAttributeChangedSignal("LifeState"):Connect(function()
		if player:GetAttribute("LifeState") ~= "Alive" then
			Build.Stop()
		end
	end)
end

return Build
