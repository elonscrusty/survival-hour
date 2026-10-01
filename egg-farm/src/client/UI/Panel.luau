--!strict
-- Main menu panel: coloured header with icon + title, close X, optional back arrow, optional tab
-- strip, and a Body frame for content. Sized relative to the screen with a maximum size, so it
-- fits a 360x640 portrait phone and a widescreen monitor alike.

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Icon = require(script.Parent.Icon)
local Button = require(script.Parent.Button)
local TabStrip = require(script.Parent.TabStrip)

local Panel = {}

export type Handle = {
	Frame: Frame,
	Body: Frame,
	Tabs: TabStrip.Handle?,
	Title: TextLabel,
	SetBack: (Handle, boolean) -> (),
	SetTitle: (Handle, string) -> (),
	Show: (Handle) -> (),
	Hide: (Handle) -> (),
}

export type Opts = {
	name: string,
	title: string,
	icon: string,
	color: Color3,
	tabs: { TabStrip.Tab }?,
	onTab: ((string) -> ())?,
	onClose: () -> (),
	onBack: () -> (),
	maxSize: Vector2?,
	parent: Instance,
}

function Panel.new(o: Opts): Handle
	local frame = Instance.new("Frame")
	frame.Name = o.name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(1, -24, 1, -24)
	frame.BackgroundColor3 = Theme.Color.Panel
	frame.Active = true -- sinks clicks so they never reach the world behind
	frame.Visible = false
	frame.ZIndex = 2
	Util.Corner(frame, 22)
	Util.Stroke(frame, 4, Theme.Color.Ink, true)
	Util.Gradient(frame, Color3.new(1, 1, 1), Color3.fromRGB(236, 226, 206))
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = o.maxSize or Theme.Size.PanelMax
	limit.Parent = frame
	local pop = Instance.new("UIScale")
	pop.Parent = frame

	-- header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = o.color
	header.Size = UDim2.new(1, 0, 0, 62)
	header.ZIndex = 2
	Util.Corner(header, 20)
	Util.Stroke(header, 4, Theme.Color.Ink, true)
	Util.Gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	header.Parent = frame
	local ic = Icon.new(o.icon, 46)
	ic.Position = UDim2.fromOffset(14, 8)
	ic.ZIndex = 3
	ic.Parent = header
	local title = Util.Text({
		text = o.title,
		size = UDim2.new(1, -200, 1, -8),
		position = UDim2.fromOffset(68, 2),
		textSize = Theme.Text.XL,
		font = Theme.Font.Title,
		xAlign = Enum.TextXAlignment.Left,
		outline = true,
		z = 3,
		parent = header,
	})

	local close = Button.new({
		name = "Close",
		icon = "close",
		iconSize = 30,
		color = Theme.Color.Red,
		size = UDim2.fromOffset(60, 60),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 10, 0, -10),
		z = 5,
		onClick = o.onClose,
		parent = frame,
	})
	close.Instance.ZIndex = 5
	local back = Button.new({
		name = "Back",
		icon = "back",
		iconSize = 30,
		color = Theme.Color.Blue,
		size = UDim2.fromOffset(60, 60),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -56, 0, -10),
		z = 5,
		onClick = o.onBack,
		parent = frame,
	})
	back:SetVisible(false)

	local top = 70
	local tabs: TabStrip.Handle? = nil
	if o.tabs then
		local onTab = o.onTab
		tabs = TabStrip.new({
			tabs = o.tabs,
			onSelect = function(id)
				if onTab then
					onTab(id)
				end
			end,
			size = UDim2.new(1, -24, 0, 52),
			position = UDim2.fromOffset(12, 66),
			parent = frame,
		})
		top = 124
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(12, top)
	body.Size = UDim2.new(1, -24, 1, -(top + 12))
	body.ZIndex = 2
	body.Parent = frame

	local h: any = { Frame = frame, Body = body, Tabs = tabs, Title = title }
	function h.SetBack(self: Handle, on: boolean)
		back:SetVisible(on)
	end
	function h.SetTitle(self: Handle, text: string)
		self.Title.Text = text
	end
	function h.Show(self: Handle)
		if not self.Frame.Visible then
			self.Frame.Visible = true
			pop.Scale = 0.88
			Util.Tween(pop, Theme.Tween.Pop, { Scale = 1 })
		end
	end
	function h.Hide(self: Handle)
		self.Frame.Visible = false
	end
	frame.Parent = o.parent
	return h :: Handle
end

return Panel
