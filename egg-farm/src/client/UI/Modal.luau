--!strict
-- Confirm / info modal box: title, optional sections of bullet lines (e.g. "Resets" in red,
-- "Kept" in green, "You get" in gold), and one or two buttons. The Host decides when it shows
-- (MenuRouter allows one modal at a time); this module only draws it.

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Button = require(script.Parent.Button)
local Icon = require(script.Parent.Icon)

local Modal = {}

export type Section = { title: string, items: { string }, color: Color3? }

export type ShowOpts = {
	title: string,
	text: string?,
	icon: string?,
	color: Color3?,
	sections: { Section }?,
	confirmText: string?,
	confirmColor: Color3?,
	cancelText: string?, -- nil = a single-button modal
	onConfirm: (() -> ())?,
	onCancel: (() -> ())?,
}

export type Handle = {
	Frame: Frame,
	Show: (Handle, ShowOpts) -> (),
	Hide: (Handle) -> (),
	Current: ShowOpts?,
}

function Modal.new(parent: Instance): Handle
	local box = Instance.new("Frame")
	box.Name = "Modal"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.new(1, -32, 1, -40)
	box.BackgroundColor3 = Theme.Color.Panel
	box.Active = true
	box.Visible = false
	box.ZIndex = 2
	Util.Corner(box, 22)
	Util.Stroke(box, 4, Theme.Color.Ink, true)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 520)
	limit.Parent = box
	local pop = Instance.new("UIScale")
	pop.Parent = box

	local header = Instance.new("Frame")
	header.BackgroundColor3 = Theme.Color.Orange
	header.Size = UDim2.new(1, 0, 0, 58)
	header.ZIndex = 2
	Util.Corner(header, 20)
	Util.Stroke(header, 4, Theme.Color.Ink, true)
	Util.Gradient(header)
	header.Parent = box
	local iconHolder = Instance.new("Frame")
	iconHolder.BackgroundTransparency = 1
	iconHolder.Size = UDim2.fromOffset(44, 44)
	iconHolder.Position = UDim2.fromOffset(12, 7)
	iconHolder.ZIndex = 3
	iconHolder.Parent = header
	local title = Util.Text({
		size = UDim2.new(1, -76, 1, -6),
		position = UDim2.fromOffset(64, 2),
		textSize = Theme.Text.L,
		font = Theme.Font.Title,
		xAlign = Enum.TextXAlignment.Left,
		outline = true,
		z = 3,
		parent = header,
	})

	local scroll = Util.Scroll(box, UDim2.new(1, -24, 1, -(66 + 84)), UDim2.fromOffset(12, 66))
	Util.List(scroll, 8, false, Enum.HorizontalAlignment.Left)

	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0.5, 1)
	buttons.Position = UDim2.new(0.5, 0, 1, -12)
	buttons.Size = UDim2.new(1, -24, 0, 64)
	buttons.Parent = box
	Util.List(buttons, 14, true, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

	local h: any = { Frame = box, Current = nil }

	local confirm = Button.new({
		text = "OK",
		color = Theme.Color.Green,
		size = UDim2.new(0.46, 0, 0, 62),
		order = 2,
		parent = buttons,
		onClick = function()
			local cur = h.Current
			if cur and cur.onConfirm then
				cur.onConfirm()
			end
		end,
	})
	local cancel = Button.new({
		text = "Cancel",
		color = Theme.Color.Gray,
		size = UDim2.new(0.46, 0, 0, 62),
		order = 1,
		parent = buttons,
		onClick = function()
			local cur = h.Current
			if cur and cur.onCancel then
				cur.onCancel()
			end
		end,
	})

	function h.Show(self: Handle, o: ShowOpts)
		self.Current = o
		title.Text = o.title
		header.BackgroundColor3 = o.color or Theme.Color.Orange
		Util.Clear(iconHolder)
		local ic = Icon.new(o.icon or "egg", 44)
		ic.ZIndex = 3
		ic.Parent = iconHolder
		Util.Clear(scroll, { "UIListLayout" })
		local order = 0
		if o.text then
			order += 1
			Util.Text({
				text = o.text,
				size = UDim2.new(1, -10, 0, 0),
				textSize = Theme.Text.M,
				color = Theme.Color.TextDark,
				xAlign = Enum.TextXAlignment.Left,
				wrap = true,
				order = order,
				parent = scroll,
			})
		end
		local sections: { Section } = o.sections or {}
		for _, sec in sections do
			order += 1
			Util.Text({
				text = sec.title,
				size = UDim2.new(1, -10, 0, 0),
				textSize = Theme.Text.M,
				color = sec.color or Theme.Color.TextDark,
				font = Theme.Font.Title,
				xAlign = Enum.TextXAlignment.Left,
				wrap = true,
				outline = false,
				order = order,
				parent = scroll,
			})
			for _, line in sec.items do
				order += 1
				Util.Text({
					text = "  •  " .. line,
					size = UDim2.new(1, -10, 0, 0),
					textSize = Theme.Text.S,
					color = Theme.Color.TextDark,
					xAlign = Enum.TextXAlignment.Left,
					wrap = true,
					order = order,
					parent = scroll,
				})
			end
		end
		confirm:SetText(o.confirmText or "OK")
		confirm:SetColor(o.confirmColor or Theme.Color.Green)
		cancel:SetVisible(o.cancelText ~= nil)
		cancel:SetText(o.cancelText or "Cancel")
		confirm.Instance.Size = if o.cancelText then UDim2.new(0.46, 0, 0, 62) else UDim2.new(0.7, 0, 0, 62)
		box.Visible = true
		pop.Scale = 0.85
		Util.Tween(pop, Theme.Tween.Pop, { Scale = 1 })
	end

	function h.Hide(self: Handle)
		self.Current = nil
		box.Visible = false
	end

	box.Parent = parent
	return h :: Handle
end

return Modal
