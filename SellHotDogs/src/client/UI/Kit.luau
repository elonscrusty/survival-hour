--!strict
-- Small UI kit: theme colours, instance builder, buttons with pressed/disabled feedback,
-- and a scaled design canvas that respects device safe areas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Kit = {}

Kit.C = {
	bg = Color3.fromRGB(255, 248, 232),
	panel = Color3.fromRGB(255, 252, 244),
	ink = Color3.fromRGB(70, 42, 26),
	inkSoft = Color3.fromRGB(130, 100, 80),
	green = Color3.fromRGB(76, 190, 80),
	greenDark = Color3.fromRGB(46, 140, 54),
	blue = Color3.fromRGB(56, 150, 235),
	blueDark = Color3.fromRGB(32, 100, 180),
	gold = Color3.fromRGB(250, 196, 40),
	goldDark = Color3.fromRGB(200, 140, 20),
	red = Color3.fromRGB(226, 66, 56),
	redDark = Color3.fromRGB(160, 36, 30),
	mustard = Color3.fromRGB(242, 194, 48),
	ketchup = Color3.fromRGB(216, 58, 46),
	violet = Color3.fromRGB(140, 90, 230),
	teal = Color3.fromRGB(40, 175, 195),
	grey = Color3.fromRGB(170, 165, 160),
	white = Color3.new(1, 1, 1),
	shadow = Color3.fromRGB(60, 35, 20),
}
local C = Kit.C
Kit.FONT = Enum.Font.FredokaOne
Kit.FONT_BODY = Enum.Font.GothamBold

function Kit.new(class: string, props: { [string]: any }, children: { any }?): any
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local new = Kit.new

function Kit.corner(r: number?): any
	return new("UICorner", { CornerRadius = UDim.new(0, r or 14) })
end

function Kit.stroke(color: Color3?, t: number?): any
	return new("UIStroke", { Color = color or C.shadow, Thickness = t or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function Kit.textStroke(t: number?): UIStroke
	return new("UIStroke", { Color = C.shadow, Thickness = t or 2, Transparency = 0.2 })
end

function Kit.pad(px: number): any
	local u = UDim.new(0, px)
	return new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

function Kit.label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = Kit.FONT,
		TextColor3 = C.white,
		TextScaled = true,
		Text = "",
	}
	for k, v in props do
		if k ~= "MaxText" then
			base[k] = v
		end
	end
	local l = new("TextLabel", base)
	if props.TextColor3 == nil or props.TextColor3 == C.white then
		Kit.textStroke().Parent = l
	end
	local maxSize = props.MaxText or 40
	new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8, Parent = l })
	return l
end

export type Button = {
	frame: TextButton,
	text: TextLabel,
	setEnabled: (boolean) -> (),
	setPending: (boolean) -> (),
	setText: (string) -> (),
	setColor: (Color3, Color3) -> (),
}

-- Chunky game button: coloured face, dark lip, shrink on press, grey when disabled.
function Kit.button(props: { text: string, color: Color3?, dark: Color3?, size: UDim2, pos: UDim2?, anchor: Vector2?, parent: Instance?, onClick: () -> (), textSize: number?, icon: string? }): Button
	local color, dark = props.color or C.green, props.dark or C.greenDark
	local enabled, pending = true, false
	local holder = new("TextButton", {
		Size = props.size,
		Position = props.pos or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundColor3 = dark,
		AutoButtonColor = false,
		Text = "",
		Parent = props.parent,
	}, { Kit.corner(12) })
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = color,
		Parent = holder,
	}, { Kit.corner(12) })
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 225)), Rotation = 90, Parent = face })
	local text: TextLabel
	if props.icon then
		-- icon on the left, label on the right
		local h = props.size.Y.Offset - 13
		Kit.icon(props.icon, math.max(16, h), face, UDim2.new(0, 4, 0.5, 0), Vector2.new(0, 0.5))
		text = Kit.label({ Text = props.text, Size = UDim2.new(1, -(h + 12), 1, -8), Position = UDim2.fromOffset(h + 8, 4), Parent = face, MaxText = props.textSize or 30 })
	else
		text = Kit.label({ Text = props.text, Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Parent = face, MaxText = props.textSize or 30 })
	end
	local scale = new("UIScale", { Parent = holder })
	local function paint()
		local on = enabled and not pending
		face.BackgroundColor3 = if on then color else C.grey
		holder.BackgroundColor3 = if on then dark else Color3.fromRGB(120, 115, 110)
		text.TextTransparency = if pending then 0.4 else 0
	end
	holder.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
	end)
	holder.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	holder.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	holder.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	holder.Activated:Connect(function()
		if enabled and not pending then
			props.onClick()
		end
	end)
	local b: Button = {
		frame = holder,
		text = text,
		setEnabled = function(on)
			enabled = on
			paint()
		end,
		setPending = function(on)
			pending = on
			paint()
		end,
		setText = function(s)
			if text.Text ~= s then
				text.Text = s
			end
		end,
		setColor = function(c, d)
			color, dark = c, d
			paint()
		end,
	}
	return b
end

function Kit.panel(props: { size: UDim2, pos: UDim2?, anchor: Vector2?, parent: Instance?, color: Color3? }): Frame
	return new("Frame", {
		Size = props.size,
		Position = props.pos or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundColor3 = props.color or C.panel,
		Parent = props.parent,
	}, { Kit.corner(18), Kit.stroke(C.shadow, 4) })
end

function Kit.bar(parent: Instance, size: UDim2, pos: UDim2, color: Color3): (Frame, Frame)
	local back = new("Frame", { Size = size, Position = pos, BackgroundColor3 = Color3.fromRGB(60, 50, 40), Parent = parent }, { Kit.corner(8) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, Parent = back }, { Kit.corner(8) })
	return back, fill
end

-- Design canvas: children are laid out for >= 1100 x 620 "design pixels" and scaled to fit,
-- inside the device safe area (notches, Roblox top bar).
function Kit.canvas(name: string, order: number): (ScreenGui, Frame)
	local gui = new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
	local s = new("UIScale", { Parent = root })
	local function fit()
		local okSize, abs = pcall(function()
			return gui.AbsoluteSize
		end)
		if not okSize or abs.X < 2 then
			abs = Vector2.new(1280, 720) -- before the first layout pass
		end
		if abs.X < 2 then
			return
		end
		local k = math.clamp(math.min(abs.X / 1100, abs.Y / 620), 0.5, 1.3)
		s.Scale = k
		root.Size = UDim2.fromOffset(abs.X / k, abs.Y / k)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return gui, root
end

---------------------------------------------------------------- icons
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared.AssetIds)
local Icons = require(Shared.Icons)
local Models = require(Shared.Models)

local function frameCamera(vp: ViewportFrame, m: Model)
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local p, s = d.CFrame.Position, d.Size / 2
			minV = Vector3.new(math.min(minV.X, p.X - s.X), math.min(minV.Y, p.Y - s.Y), math.min(minV.Z, p.Z - s.Z))
			maxV = Vector3.new(math.max(maxV.X, p.X + s.X), math.max(maxV.Y, p.Y + s.Y), math.max(maxV.Z, p.Z + s.Z))
		end
	end
	if minV.X == math.huge then
		return
	end
	local centre = (minV + maxV) / 2
	local radius = (maxV - minV).Magnitude / 2
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = radius / math.tan(math.rad(15)) * 1.05
	cam.CFrame = CFrame.lookAt(centre + Vector3.new(0.75, 0.55, -1).Unit * dist, centre)
	cam.Parent = vp
	vp.CurrentCamera = cam
end

-- A square picture for `key` (see Shared/Icons). Uploaded render > live 3D preview > emoji.
function Kit.icon(key: string, size: number, parent: Instance?, pos: UDim2?, anchor: Vector2?): GuiObject
	local def = Icons[key] or { model = key, emoji = "⭐" }
	local imageId = AssetIds.Images[def.model]
	local base = {
		Size = UDim2.fromOffset(size, size),
		Position = pos or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
		BackgroundTransparency = 1,
		Parent = parent,
	}
	if imageId then
		local img = new("ImageLabel", base)
		-- the server resolves the uploaded Decal to its image (ReplicatedStorage.ImageIds)
		task.spawn(function()
			local ids = ReplicatedStorage:WaitForChild("ImageIds", 60)
			if not ids then
				return
			end
			local function set()
				local tex = ids:GetAttribute(def.model)
				if typeof(tex) == "string" then
					img.Image = tex
				end
			end
			set()
			if img.Image == "" then
				local conn: RBXScriptConnection
				conn = ids:GetAttributeChangedSignal(def.model):Connect(function()
					set()
					conn:Disconnect()
				end)
				img.Destroying:Once(function()
					conn:Disconnect()
				end)
			end
		end)
		img.ScaleType = Enum.ScaleType.Fit
		return img
	end
	if Models.hasMesh(def.model) or Models.has(def.model) then
		local vp = new("ViewportFrame", base)
		vp.Ambient = Color3.fromRGB(200, 200, 200)
		vp.LightColor = Color3.new(1, 1, 1)
		vp.LightDirection = Vector3.new(-1, -1.5, 1)
		local m = Models.build(def.model)
		m:PivotTo(CFrame.new())
		m.Parent = vp
		frameCamera(vp, m)
		return vp
	end
	local l = Kit.label({ Text = def.emoji, Size = base.Size, Position = base.Position, AnchorPoint = base.AnchorPoint, Parent = parent, MaxText = 80 })
	return l
end

---------------------------------------------------------------- motion
-- Pop a frame in from small with a little overshoot (panels, dialogs, banners).
function Kit.popIn(frame: GuiObject, delay: number?)
	local s = frame:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = frame })
	s.Scale = 0.6
	task.delay(delay or 0, function()
		TweenService:Create(s, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

-- Quick bounce (cash gained, button became available).
function Kit.pulse(frame: GuiObject, amount: number?)
	local s = frame:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = frame })
	s.Scale = 1 + (amount or 0.12)
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Gentle continuous wiggle for things that want attention (returns a stop function).
function Kit.wiggle(frame: GuiObject): () -> ()
	local alive = true
	task.spawn(function()
		while alive and frame.Parent do
			TweenService:Create(frame, TweenInfo.new(0.12), { Rotation = 6 }):Play()
			task.wait(0.12)
			TweenService:Create(frame, TweenInfo.new(0.12), { Rotation = -6 }):Play()
			task.wait(0.12)
			TweenService:Create(frame, TweenInfo.new(0.12), { Rotation = 0 }):Play()
			task.wait(1.6)
		end
	end)
	return function()
		alive = false
		frame.Rotation = 0
	end
end

function Kit.tween(inst: Instance, t: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

return Kit
