-- The Pets menu: every pet you own, its stats, and Ride / Rename / Release.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Pets = require(Shared.Pets)
local Net = require(Shared.Net)
local PetModel = require(Shared.PetModel)
local PetStats = require(Shared.Logic.PetStats)
local Profile = require(Shared.Logic.Profile)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.Hud)

local PetMenu = {}

local panel: Frame
local grid: ScrollingFrame
local detail: Frame
local countLabel: TextLabel
local selected: string? = nil
local confirmRelease: string? = nil

local STAT_COLORS = { Speed = UI.Colors.Blue, Jump = Color3.fromRGB(255, 120, 60), Stamina = UI.Colors.Green }

local function petName(p: any): string
	local s = Pets.ById[p.Species]
	return p.Nick or (s and s.Name) or p.Species
end

local function preview(parent: Instance, p: any)
	local built = PetModel.Build(p.Species, 1, p.Paint)
	for _, d in built.Model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	UI.Viewport(parent, built.Model)
end

local function renderDetail()
	detail:ClearAllChildren()
	local d = State.Data
	local p = d and selected and Profile.FindPet(d, selected)
	if not p then
		UI.Text({ Text = "Tap a pet", Size = UDim2.new(1, 0, 0, 40), TextColor3 = UI.Colors.Muted }, detail)
		return
	end
	local s = Pets.ById[p.Species]
	local rar = Pets.Rarities[s.Rarity]
	local view = UI.Frame({ Size = UDim2.new(1, 0, 0.36, 0), BackgroundColor3 = UI.Colors.PanelLight }, detail)
	UI.Corner(view, 12)
	preview(view, p)
	UI.Text({ Text = petName(p), Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.37, 0) }, detail)
	UI.Text({ Text = s.Rarity .. " " .. s.Name, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0.37, 30), TextColor3 = UI.Rgb(rar.Color), Font = UI.Body }, detail)
	local ride = PetStats.Ride(p)
	local y = 0.37
	for i, stat in Config.Stats.Names do
		local lvl = p.Levels[stat] or 1
		local xp = p.Xp[stat] or 0
		local need = PetStats.XpToNext(lvl)
		local row = UI.Frame({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, y, 54 + (i - 1) * 30), BackgroundTransparency = 1 }, detail)
		UI.Text({ Text = stat .. " " .. lvl, Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Font = UI.Body }, row)
		local bar = UI.Frame({ Size = UDim2.new(0.58, 0, 0.6, 0), Position = UDim2.new(0.42, 0, 0.2, 0), BackgroundColor3 = Color3.fromRGB(28, 45, 110) }, row)
		UI.Corner(bar, 6)
		local fill = UI.Frame({ Size = UDim2.new(if lvl >= Config.Stats.MaxLevel then 1 else math.clamp(xp / need, 0, 1), 0, 1, 0), BackgroundColor3 = STAT_COLORS[stat] }, bar)
		UI.Corner(fill, 6)
	end
	UI.Text({
		Text = string.format("Speed %.0f  Jump %.0f  Dashes %d", ride.WalkSpeed, ride.JumpPower, ride.DashCharges),
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, y, 146),
		TextColor3 = UI.Colors.Muted,
		Font = UI.Body,
	}, detail)

	local by = UDim2.new(0, 0, 1, -44)
	if d.Equipped == p.Uid then
		UI.Text({ Text = "RIDING", Size = UDim2.new(0.48, 0, 0, 40), Position = by, TextColor3 = UI.Colors.Green }, detail)
	else
		UI.Button({ Text = "Ride", Size = UDim2.new(0.48, 0, 0, 40), Position = by, BackgroundColor3 = UI.Colors.Green }, detail, function()
			Net.Event("Equip"):FireServer(p.Uid)
		end)
		local refund = rar.Refund
		UI.Button({
			Text = if confirmRelease == p.Uid then "Sure? +" .. refund else "Release",
			Size = UDim2.new(0.48, 0, 0, 40),
			Position = UDim2.new(0.52, 0, 1, -44),
			BackgroundColor3 = UI.Colors.Red,
		}, detail, function()
			if confirmRelease == p.Uid then
				confirmRelease = nil
				selected = d.Equipped
				Net.Event("Release"):FireServer(p.Uid)
			else
				confirmRelease = p.Uid
				renderDetail()
			end
		end)
	end
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.66, 0, 0, 34)
	box.Position = UDim2.new(0, 0, 1, -86)
	box.PlaceholderText = "Nickname..."
	box.Text = ""
	box.Font = UI.Body
	box.TextScaled = true
	box.TextColor3 = Color3.new(1, 1, 1)
	box.BackgroundColor3 = Color3.fromRGB(28, 45, 110)
	box.ClearTextOnFocus = false
	UI.Corner(box, 8)
	box.Parent = detail
	UI.Button({ Text = "Name", Size = UDim2.new(0.3, 0, 0, 34), Position = UDim2.new(0.7, 0, 1, -86), BackgroundColor3 = UI.Colors.Purple }, detail, function()
		Net.Event("Rename"):FireServer(p.Uid, string.sub(box.Text, 1, 20))
	end)
end

local function renderGrid()
	for _, c in grid:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local d = State.Data
	if not d then
		return
	end
	countLabel.Text = #d.Pets .. "/" .. Profile.Capacity(d) .. " pets"
	local sorted = table.clone(d.Pets)
	table.sort(sorted, function(a, b)
		if (a.Uid == d.Equipped) ~= (b.Uid == d.Equipped) then
			return a.Uid == d.Equipped
		end
		local ra, rb = Pets.Rank(a.Species), Pets.Rank(b.Species)
		if ra ~= rb then
			return ra > rb
		end
		return PetStats.Power(a) > PetStats.Power(b)
	end)
	for i, p in sorted do
		local s = Pets.ById[p.Species]
		local card = UI.Button({
			Text = "",
			LayoutOrder = i,
			BackgroundColor3 = if p.Uid == selected then UI.Colors.Blue else UI.Colors.PanelLight,
		}, grid, function()
			selected = p.Uid
			confirmRelease = nil
			renderGrid()
			renderDetail()
		end)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = UI.Rgb(Pets.Rarities[s.Rarity].Color)
			stroke.Thickness = 3
		end
		local vp = UI.Frame({ Size = UDim2.new(1, 0, 0.72, 0), BackgroundTransparency = 1 }, card)
		preview(vp, p)
		UI.Text({ Text = petName(p), Size = UDim2.new(1, -6, 0.16, 0), Position = UDim2.new(0, 3, 0.7, 0), Font = UI.Body }, card)
		UI.Text({ Text = "Lv " .. PetStats.Power(p), Size = UDim2.new(1, -6, 0.13, 0), Position = UDim2.new(0, 3, 0.86, 0), TextColor3 = UI.Colors.Muted, Font = UI.Body }, card)
		if p.Uid == d.Equipped then
			UI.Text({ Text = "RIDING", Size = UDim2.new(1, 0, 0.16, 0), TextColor3 = UI.Colors.Green, Rotation = -8 }, card)
		end
	end
end

function PetMenu.Open()
	panel.Visible = true
	if not selected and State.Data then
		selected = State.Data.Equipped
	end
	renderGrid()
	renderDetail()
end

function PetMenu.Start()
	local body
	panel, body = UI.Modal("My Pets", UDim2.fromScale(0.9, 0.85))
	countLabel = UI.Text({ Text = "", Size = UDim2.fromOffset(160, 30), Position = UDim2.new(1, -230, 0, 14), TextColor3 = UI.Colors.Muted, ZIndex = 11, Font = UI.Body }, panel)
	grid = Instance.new("ScrollingFrame")
	grid.Size = UDim2.new(0.6, -6, 1, 0)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(104, 124)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	UI.Pad(grid, 4)
	detail = UI.Frame({ Size = UDim2.new(0.4, -6, 1, 0), Position = UDim2.new(0.6, 6, 0, 0), BackgroundTransparency = 1 }, body)
	Hud.SetOpener("Pets", PetMenu.Open)
	State.OnChange(function()
		if panel.Visible then
			renderGrid()
			renderDetail()
		end
	end)
end

return PetMenu
