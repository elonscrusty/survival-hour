-- Builds a race track from parts using Logic/TrackLayout. The track sits high in the
-- sky, far from the lobby, and runs along +X. Lane width is Tracks.Width (along Z).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tracks = require(Shared.Tracks)
local TrackLayout = require(Shared.Logic.TrackLayout)

local TrackBuilder = {}

TrackBuilder.Origin = Vector3.new(0, 400, 3000)

local Util: any
local current: Folder? = nil

local THEMES = {
	Meadow = { Floor = Color3.fromRGB(120, 205, 95), FloorMat = Enum.Material.Grass, Wall = Color3.fromRGB(255, 255, 255), Prop = Color3.fromRGB(255, 120, 80) },
	Canyon = { Floor = Color3.fromRGB(215, 150, 90), FloorMat = Enum.Material.Sandstone, Wall = Color3.fromRGB(150, 85, 50), Prop = Color3.fromRGB(110, 70, 45) },
	Sky = { Floor = Color3.fromRGB(240, 245, 255), FloorMat = Enum.Material.SmoothPlastic, Wall = Color3.fromRGB(140, 200, 255), Prop = Color3.fromRGB(255, 170, 230) },
}

export type Built = {
	Folder: Folder,
	Layout: TrackLayout.Layout,
	Track: any,
	ToWorld: (x: number, y: number, z: number?) -> Vector3,
	StartPositions: { Vector3 },
}

function TrackBuilder.Init(ctx)
	Util = ctx.Util
end

function TrackBuilder.Clear()
	if current then
		current:Destroy()
		current = nil
	end
end

function TrackBuilder.Build(track: any): Built
	TrackBuilder.Clear()
	local folder = Instance.new("Folder")
	folder.Name = "RaceTrack"
	local layout = TrackLayout.Build(track.Segments)
	local theme = THEMES[track.Theme] or THEMES.Meadow
	local W = Tracks.Width
	local O = TrackBuilder.Origin
	local function at(x: number, y: number, z: number?): Vector3
		return O + Vector3.new(x, y, z or 0)
	end

	local function floor(x0: number, x1: number, y: number, color: Color3?, mat: Enum.Material?, name: string?)
		local thick = 4
		return Util.Part({
			Size = Vector3.new(x1 - x0, thick, W),
			CFrame = CFrame.new(at((x0 + x1) / 2, y - thick / 2)),
			Color = color or theme.Floor,
			Material = mat or theme.FloorMat,
			Name = name or "Floor",
		}, folder)
	end

	-- Start area and finish run-off.
	floor(-40, 0, 0, theme.Floor, theme.FloorMat, "StartArea")
	local fy = layout.Pieces[#layout.Pieces].Y1
	floor(layout.Length, layout.Length + 50, fy, theme.Floor, theme.FloorMat, "FinishArea")

	for _, p in layout.Pieces do
		local L = p.X1 - p.X0
		if p.Kind == "Straight" or p.Kind == "Zigzag" or p.Kind == "Hurdles" then
			floor(p.X0, p.X1, p.Y0)
		elseif p.Kind == "Boost" then
			floor(p.X0, p.X1, p.Y0, Color3.fromRGB(255, 220, 60), Enum.Material.Neon, "Boost")
			for i = 1, math.floor(L / 10) do
				local arrow = Util.Part({
					Size = Vector3.new(4, 0.2, 10),
					CFrame = CFrame.new(at(p.X0 + i * 10 - 5, p.Y0 + 0.1)) * CFrame.Angles(0, math.rad(45), 0),
					Color = Color3.fromRGB(255, 120, 0),
					Material = Enum.Material.Neon,
					CanCollide = false,
					Name = "Arrow",
				}, folder)
				arrow.CanQuery = false
			end
		elseif p.Kind == "Mud" then
			floor(p.X0, p.X1, p.Y0, Color3.fromRGB(100, 70, 45), Enum.Material.Mud, "Mud")
		elseif p.Kind == "Ramp" then
			local rise = p.Y1 - p.Y0
			local len = math.sqrt(L * L + rise * rise)
			local angle = math.atan2(rise, L)
			Util.Part({
				Size = Vector3.new(len + 1, 4, W),
				CFrame = CFrame.new(at(p.X0 + L / 2, (p.Y0 + p.Y1) / 2)) * CFrame.Angles(0, 0, angle) * CFrame.new(0, -2, 0),
				Color = theme.Floor,
				Material = theme.FloorMat,
				Name = "Ramp",
			}, folder)
		elseif p.Kind == "Steps" then
			local n = p.Count or 1
			local stepL = L / n
			for k = 1, n do
				local top = p.Y0 + (p.Rise or 0) * k
				local bottom = p.Y0 - 4
				Util.Part({
					Size = Vector3.new(stepL, top - bottom, W),
					CFrame = CFrame.new(at(p.X0 + (k - 0.5) * stepL, (top + bottom) / 2)),
					Color = if k % 2 == 0 then theme.Floor else theme.Wall,
					Material = theme.FloorMat,
					Name = "Step",
				}, folder)
			end
		elseif p.Kind == "Gap" then
			-- warning stripes on the edge before the gap
			Util.Part({
				Size = Vector3.new(1.5, 0.2, W),
				CFrame = CFrame.new(at(p.X0 - 0.75, p.Y0 + 0.1)),
				Color = Color3.fromRGB(255, 60, 60),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Name = "GapEdge",
			}, folder)
		end

		if p.Kind == "Hurdles" then
			local n = p.Count or 1
			for k = 1, n do
				local x = p.X0 + L * k / (n + 1)
				local h = p.H or 3
				Util.Part({
					Size = Vector3.new(1.5, h, W),
					CFrame = CFrame.new(at(x, p.Y0 + h / 2)),
					Color = if k % 2 == 0 then theme.Wall else theme.Prop,
					Name = "Hurdle",
				}, folder)
			end
		elseif p.Kind == "Zigzag" then
			local n = p.Count or 4
			for k = 1, n do
				local x = p.X0 + L * k / (n + 1)
				local side = if k % 2 == 0 then 1 else -1
				Util.Part({
					Size = Vector3.new(4, 12, W * 0.6),
					CFrame = CFrame.new(at(x, p.Y0 + 6, side * W * 0.2)),
					Color = theme.Prop,
					Name = "Pillar",
				}, folder)
			end
		end
	end

	-- Side rails (low and visible) plus tall invisible walls so nobody falls off sideways.
	local totalX0, totalX1 = -40, layout.Length + 50
	local midX = (totalX0 + totalX1) / 2
	local spanX = totalX1 - totalX0
	local low = layout.MinY - 40
	local high = layout.MaxY + 40
	for _, side in { -1, 1 } do
		Util.Part({
			Size = Vector3.new(spanX, high - low, 2),
			CFrame = CFrame.new(at(midX, (low + high) / 2, side * (W / 2 + 1))),
			Transparency = 1,
			Name = "SideWall",
		}, folder)
	end
	for _, p in layout.Pieces do
		if p.Kind ~= "Gap" and p.Kind ~= "Ramp" and p.Kind ~= "Steps" then
			for _, side in { -1, 1 } do
				Util.Part({
					Size = Vector3.new(p.X1 - p.X0, 2.5, 1),
					CFrame = CFrame.new(at((p.X0 + p.X1) / 2, p.Y0 + 1.25, side * (W / 2 - 0.5))),
					Color = theme.Wall,
					Name = "Rail",
				}, folder)
			end
		end
	end
	-- Back wall behind the start.
	Util.Part({
		Size = Vector3.new(2, 40, W),
		CFrame = CFrame.new(at(-41, 20)),
		Transparency = 1,
		Name = "BackWall",
	}, folder)

	-- Checkpoint arches (skip [1], the start line).
	for i, cp in layout.Checkpoints do
		if i > 1 then
			for _, side in { -1, 1 } do
				Util.Part({
					Size = Vector3.new(1, 10, 1),
					CFrame = CFrame.new(at(cp.X, cp.Y + 5, side * (W / 2 - 1))),
					Color = Color3.fromRGB(120, 230, 255),
					Material = Enum.Material.Neon,
					CanCollide = false,
					Name = "Checkpoint",
				}, folder)
			end
		end
	end

	-- Start and finish arches.
	local function arch(x: number, y: number, label: string, color: Color3)
		for _, side in { -1, 1 } do
			Util.Part({
				Size = Vector3.new(2, 16, 2),
				CFrame = CFrame.new(at(x, y + 8, side * (W / 2 - 1))),
				Color = color,
				Name = "ArchPost",
			}, folder)
		end
		local top = Util.Part({
			Size = Vector3.new(2, 4, W),
			CFrame = CFrame.new(at(x, y + 18)),
			Color = color,
			Name = "ArchTop",
		}, folder)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Left
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 25
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = label
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Parent = gui
		gui.Parent = top
		Util.Part({
			Size = Vector3.new(3, 0.2, W),
			CFrame = CFrame.new(at(x, y + 0.1)),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Name = "Line",
		}, folder)
	end
	arch(0, 0, "START", Color3.fromRGB(80, 200, 120))
	arch(layout.Length, fy, "FINISH", Color3.fromRGB(255, 80, 160))

	-- Floating clouds/scenery far below so the sky track doesn't feel empty.
	local rng = Random.new(#track.Id)
	for _ = 1, 18 do
		local c = Util.Part({
			Size = Vector3.new(rng:NextNumber(30, 70), rng:NextNumber(8, 16), rng:NextNumber(30, 60)),
			CFrame = CFrame.new(at(rng:NextNumber(-60, layout.Length + 60), layout.MinY - rng:NextNumber(60, 140), rng:NextNumber(-150, 150))),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.15,
			CanCollide = false,
			Name = "Cloud",
		}, folder)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = c
	end

	folder.Parent = workspace
	current = folder

	local starts = {}
	for i = 1, 8 do
		local row = math.floor((i - 1) / 4)
		local col = (i - 1) % 4
		table.insert(starts, at(-8 - row * 12, 4, (col - 1.5) * (W / 4.5)))
	end

	return {
		Folder = folder,
		Layout = layout,
		Track = track,
		ToWorld = at,
		StartPositions = starts,
	}
end

return TrackBuilder
