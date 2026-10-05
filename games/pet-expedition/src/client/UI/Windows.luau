--!strict
-- Screen layers, modal windows and a tiny router so controllers can open each
-- other's menus by name without requiring each other (Windows.Open("Shop", "Gems")).
-- One window is open at a time; opening another closes the current one.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Theme = require("./Theme")
local Kit = require("./Kit")
local Signal = require("../Core/Signal")
local Sounds = require("../Core/Sounds")

local Windows = {}

export type Window = {
	Name: string,
	Root: Frame,
	Body: Frame,
	Header: Frame,
	Title: TextLabel,
	Opened: Signal.Signal,
	Closed: Signal.Signal,
	IsOpen: boolean,
}

-- (name?) whenever the open window changes
Windows.Changed = Signal.new()
-- (name) when a Show was refused because a locked window is open
Windows.Refused = Signal.new()

local player = Players.LocalPlayer
local guis: { [string]: ScreenGui } = {}
local windows: { [string]: Window } = {}
local routes: { [string]: (...any) -> () } = {}
local current: Window? = nil
local backdrop: TextButton? = nil
local locked: string? = nil

local LAYERS = {
	Hud = 1,
	Windows = 5,
	Popups = 8,
	Overlay = 12,
	Toasts = 15,
}

-- ScreenGui for a layer, created on first use.
function Windows.Gui(layer: string): ScreenGui
	local g = guis[layer]
	if g then
		return g
	end
	local sg: ScreenGui = Kit.new("ScreenGui", {
		Name = "PE_" .. layer,
		ResetOnSpawn = false,
		DisplayOrder = LAYERS[layer] or 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = if layer == "Overlay" then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets,
		IgnoreGuiInset = layer == "Overlay",
		Parent = player:WaitForChild("PlayerGui"),
	})
	guis[layer] = sg
	return sg
end

local function getBackdrop(): TextButton
	local b = backdrop
	if b then
		return b
	end
	local nb: TextButton = Kit.new("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Backdrop,
		BackgroundTransparency = 0.45,
		Size = UDim2.new(1, 0, 1, 200),
		Position = UDim2.fromOffset(0, -100),
		Visible = false,
		ZIndex = 0,
		Parent = Windows.Gui("Windows"),
	})
	nb.Activated:Connect(function()
		Windows.Close()
	end)
	backdrop = nb
	return nb
end

export type WindowOptions = {
	Title: string,
	Icon: string?,
	Color: Color3?,
	Size: Vector2?,
}

-- Creates a (hidden) window. Content goes into window.Body.
function Windows.Create(name: string, opts: WindowOptions): Window
	local size = opts.Size or Vector2.new(860, 540)
	local color = opts.Color or Theme.Colors.Header
	local root: Frame = Kit.panel({
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Visible = false,
		ZIndex = 2,
		StrokeThickness = 4,
		Corner = 20,
		Parent = Windows.Gui("Windows"),
	})
	Kit.autoScale(root, 1)
	-- swallow clicks so they don't fall through to the backdrop
	Kit.new("TextButton", {
		Name = "Blocker",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		AutoButtonColor = false,
		Parent = root,
	})
	local header: Frame = Kit.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = root,
	}, {
		Kit.corner(20),
		Kit.gradient(Theme.Lighten(color, 0.15), Theme.Darken(color, 0.1)),
	})
	-- square off the header's bottom corners
	Kit.new("Frame", {
		Name = "Square",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = Theme.Darken(color, 0.1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = header,
	})
	local title = Kit.fitLabel((opts.Icon and (opts.Icon .. "  ") or "") .. opts.Title, 34, {
		Name = "Title",
		Size = UDim2.new(1, -150, 1, -10),
		Position = UDim2.fromOffset(24, 5),
		Align = "Left",
		Outline = Theme.Darken(color, 0.45),
		ZIndex = 3,
		Parent = header,
	})
	local close = Kit.button(Theme.Icons.Close, "Red", {
		Name = "Close",
		Size = UDim2.fromOffset(56, 52),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		TextSize = 30,
		ZIndex = 4,
		Parent = header,
	}, function()
		Windows.Close()
	end)
	close:SetAttribute("Shortcut", "Close")
	local body: Frame = Kit.box({
		Name = "Body",
		Size = UDim2.new(1, -28, 1, -80),
		Position = UDim2.fromOffset(14, 70),
		ZIndex = 2,
		Parent = root,
	})
	local w: Window = {
		Name = name,
		Root = root,
		Body = body,
		Header = header,
		Title = title,
		Opened = Signal.new(),
		Closed = Signal.new(),
		IsOpen = false,
	}
	windows[name] = w
	return w
end

function Windows.Get(name: string): Window?
	return windows[name]
end

function Windows.CurrentName(): string?
	local c = current
	return if c then c.Name else nil
end

function Windows.IsOpen(name: string): boolean
	local c = current
	return c ~= nil and c.Name == name
end

-- Shows a created window (closing any other).
-- Locks the named window open (e.g. an active trade): backdrop taps, Esc and
-- Windows.Close() no longer close it, and other windows are refused until
-- Windows.Lock(nil). Only Windows.Close(true) closes it.
function Windows.Lock(name: string?)
	locked = name
end

function Windows.LockedName(): string?
	return locked
end

-- Shows a created window (closing any other). Returns false when refused.
function Windows.Show(name: string, ...: any): boolean
	local w = windows[name]
	if not w then
		return false
	end
	if locked and locked ~= name then
		Windows.Refused:Fire(name)
		return false
	end
	local c = current
	if c and c ~= w then
		Windows.Close()
	end
	local already = w.IsOpen
	current = w
	w.IsOpen = true
	getBackdrop().Visible = true
	w.Root.Visible = true
	if not already then
		Kit.pop(w.Root, 0.8)
		Sounds.Play("Open")
	end
	w.Opened:Fire(...)
	Windows.Changed:Fire(name)
	return true
end

-- Closes the open window. A locked window only closes with force = true.
function Windows.Close(force: boolean?)
	local c = current
	if not c then
		return
	end
	if locked == c.Name and not force then
		return
	end
	current = nil
	c.IsOpen = false
	c.Root.Visible = false
	getBackdrop().Visible = false
	c.Closed:Fire()
	Windows.Changed:Fire(nil)
end

function Windows.Toggle(name: string, ...: any)
	if Windows.IsOpen(name) then
		Windows.Close()
	else
		Windows.Open(name, ...)
	end
end

-- Router: controllers register how to open their menu (with arguments).
function Windows.Register(name: string, fn: (...any) -> ())
	routes[name] = fn
end

function Windows.Open(name: string, ...: any)
	local fn = routes[name]
	if fn then
		fn(...)
	else
		Windows.Show(name, ...)
	end
end

-- Popup confirm dialog (above windows).
function Windows.Confirm(title: string, text: string, yesText: string, tone: string?, onYes: () -> (), noText: string?)
	local gui = Windows.Gui("Popups")
	local shade: TextButton = Kit.new("TextButton", {
		Name = "Confirm",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Backdrop,
		BackgroundTransparency = 0.4,
		Size = UDim2.new(1, 0, 1, 200),
		Position = UDim2.fromOffset(0, -100),
		Parent = gui,
	})
	local box: Frame = Kit.panel({
		Size = UDim2.fromOffset(460, 270),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Corner = 20,
		StrokeThickness = 4,
		Parent = shade,
	})
	Kit.autoScale(box, 1.05)
	Kit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = box })
	Kit.fitLabel(title, 30, {
		Size = UDim2.new(1, -30, 0, 44),
		Position = UDim2.fromOffset(15, 12),
		Parent = box,
	})
	Kit.fitLabel(text, 20, {
		Size = UDim2.new(1, -40, 0, 110),
		Position = UDim2.fromOffset(20, 58),
		Font = Theme.FontBody,
		Color = Theme.Colors.TextDim,
		Rich = true,
		Parent = box,
	})
	local function close()
		shade:Destroy()
	end
	Kit.button(noText or "Cancel", "White", {
		Size = UDim2.fromOffset(190, 64),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -18),
		Parent = box,
	}, close)
	Kit.button(yesText, tone or "Green", {
		Size = UDim2.fromOffset(210, 64),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -18),
		Parent = box,
	}, function()
		close()
		onYes()
	end)
	shade.Activated:Connect(close)
	Kit.pop(box)
end

-- Escape closes the open window (PC).
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		Windows.Close()
	end
end)

return Windows
