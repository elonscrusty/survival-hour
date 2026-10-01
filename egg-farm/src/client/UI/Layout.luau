--!strict
-- Screen layers and the viewport-driven UIScale.
-- Every ScreenGui gets a full-size `Root` frame holding a UIScale. The root is sized 1/scale of
-- the screen so its children are laid out in LOGICAL pixels (a phone ~480 logical px on its short
-- side, a desktop ~830) and then scaled up or down. Safe areas: HUD and menu layers use
-- ScreenInsets.CoreUISafeInsets (notches + Roblox top bar); dimmers use ScreenInsets.None so they
-- cover the whole screen.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Layout = {}

Layout.BASE = 480 -- logical px on the short side of a phone
Layout.MIN_SCALE = 0.72
Layout.MAX_SCALE = 1.3

local scale = 1
local roots: { { root: Frame, ui: UIScale } } = {}
local listeners: { (number, Vector2) -> () } = {}

local function viewport(): Vector2
	local cam = Workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1280, 720)
end

function Layout.ComputeScale(v: Vector2): number
	local short = math.min(v.X, v.Y)
	return math.clamp(short / Layout.BASE, Layout.MIN_SCALE, Layout.MAX_SCALE)
end

function Layout.Scale(): number
	return scale
end

-- Logical size of the screen (what children of a Root see).
function Layout.Logical(): Vector2
	local v = viewport()
	return Vector2.new(v.X / scale, v.Y / scale)
end

function Layout.IsPortrait(): boolean
	local v = viewport()
	return v.Y > v.X
end

local function apply()
	scale = Layout.ComputeScale(viewport())
	for _, r in roots do
		r.ui.Scale = scale
		r.root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	local logical = Layout.Logical()
	for _, fn in table.clone(listeners) do
		task.spawn(fn, scale, logical)
	end
end

function Layout.OnChanged(fn: (number, Vector2) -> ()): () -> ()
	table.insert(listeners, fn)
	return function()
		local i = table.find(listeners, fn)
		if i then
			table.remove(listeners, i)
		end
	end
end

-- Creates a ScreenGui layer and returns (gui, root).
function Layout.Layer(name: string, order: number, fullScreen: boolean?): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = if fullScreen then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	local ui = Instance.new("UIScale")
	ui.Scale = scale
	ui.Parent = root
	root.Parent = gui
	table.insert(roots, { root = root, ui = ui })
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, root
end

local started = false
function Layout.Start()
	if started then
		return
	end
	started = true
	local conn: RBXScriptConnection? = nil
	local function hook()
		if conn then
			conn:Disconnect()
		end
		local cam = Workspace.CurrentCamera
		if cam then
			conn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
		end
		apply()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
	hook()
end

return Layout
