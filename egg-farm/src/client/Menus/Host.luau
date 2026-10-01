--!strict
-- Menu host: owns the MenuRouter, builds panels lazily, shows/hides them, draws the dimmers and
-- the single confirm modal, and passes snapshots / 4 Hz ticks to the visible panel only.
--
-- Layers (DisplayOrder): 9 panel dimmer (full screen, sinks clicks), 10 panels (safe area),
-- 11 modal dimmer, 12 modal. While anything is open, Host.IsBlocking() is true and
-- Host.OnBlockingChanged listeners fire (HUD disables Spawn, Prompts disables world prompts).
--
-- Menu modules return { Name, Title, Icon, Color, Tabs?, MaxSize?, Build(host, panel) -> inst }
-- where inst = { Refresh(snap)?, Tick(now)?, OnShow(tab?, opts?)?, OnTab(tab)? }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuRouter = require(Shared:WaitForChild("Logic"):WaitForChild("MenuRouter"))
local Tutorial = require(Shared:WaitForChild("Logic"):WaitForChild("Tutorial"))

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Layout = require(UI.Layout)
local Panel = require(UI.Panel)
local Modal = require(UI.Modal)

local Toasts = require(script.Parent.Parent.Controllers.Toasts)
local SoundC = require(script.Parent.Parent.Controllers.Sound)

export type MenuModule = {
	Name: string,
	Title: string,
	Icon: string,
	Color: Color3,
	Tabs: { { id: string, label: string, color: Color3? } }?,
	MaxSize: Vector2?,
	Build: (host: any, panel: Panel.Handle) -> any,
}

local Host = {}
Host.__index = Host

function Host.new(store: any, modules: { MenuModule })
	local defs: { [string]: MenuRouter.PanelDef } = {}
	local byName: { [string]: MenuModule } = {}
	for _, m in modules do
		local tabs: { string }? = nil
		if m.Tabs then
			local list = {}
			for _, t in m.Tabs do
				table.insert(list, t.id)
			end
			tabs = list
		end
		defs[m.Name] = { tabs = tabs }
		byName[m.Name] = m
	end
	defs.__modal_only = {}

	local self: any = setmetatable({
		Store = store,
		Router = MenuRouter.new(defs),
		modules = byName,
		built = {} :: { [string]: { panel: Panel.Handle, inst: any } },
		shown = nil :: string?,
		openOpts = nil :: any,
		blocking = false,
		blockingListeners = {} :: { (boolean) -> () },
	}, Host)

	-- panel dimmer
	local _, dimRoot = Layout.Layer("EggFarmMenuDim", 9, true)
	local dim = Instance.new("TextButton")
	dim.Name = "Dimmer"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Active = true
	dim.Modal = true -- frees the mouse in first person while a menu is open
	dim.BackgroundColor3 = Theme.Color.Dim
	dim.BackgroundTransparency = 0.45
	dim.Size = UDim2.fromScale(1, 1)
	dim.Visible = false
	dim.Parent = dimRoot
	dim.Activated:Connect(function()
		if self.Router:Modal() == nil then
			self.Router:Back()
		end
	end)
	self.dim = dim

	local _, panelRoot = Layout.Layer("EggFarmMenus", 10)
	self.panelRoot = panelRoot

	-- modal dimmer + modal
	local _, mdimRoot = Layout.Layer("EggFarmModalDim", 11, true)
	local mdim = Instance.new("TextButton")
	mdim.Name = "ModalDimmer"
	mdim.Text = ""
	mdim.AutoButtonColor = false
	mdim.Active = true
	mdim.Modal = true
	mdim.BackgroundColor3 = Theme.Color.Dim
	mdim.BackgroundTransparency = 0.4
	mdim.Size = UDim2.fromScale(1, 1)
	mdim.Visible = false
	mdim.Parent = mdimRoot
	self.mdim = mdim
	local _, modalRoot = Layout.Layer("EggFarmModal", 12)
	self.modal = Modal.new(modalRoot)
	mdim.Activated:Connect(function()
		local cur = self.modal.Current
		if cur and cur.cancelText then
			if cur.onCancel then
				cur.onCancel()
			end
		end
	end)

	self.Router:Subscribe(function()
		self:_sync()
	end)

	store.OnChanged(function(snap: any)
		self:_refresh(snap)
	end)

	-- 4 Hz timers for the visible panel (countdowns, rejected-state expiry)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local name = self.shown
		local b = name and self.built[name]
		if b and b.inst.Tick then
			b.inst.Tick(store.Now())
		end
	end)
	return self
end

function Host:_build(name: string): { panel: Panel.Handle, inst: any }?
	local b = self.built[name]
	if b then
		return b
	end
	local m: MenuModule? = self.modules[name]
	if not m then
		return nil
	end
	local mod = m :: MenuModule
	local panel = Panel.new({
		name = mod.Name,
		title = mod.Title,
		icon = mod.Icon,
		color = mod.Color,
		tabs = mod.Tabs,
		maxSize = mod.MaxSize,
		onTab = function(id)
			self.Router:SetTab(id)
		end,
		onClose = function()
			self.Router:Close()
		end,
		onBack = function()
			self.Router:Back()
		end,
		parent = self.panelRoot,
	})
	local ok, inst = pcall(mod.Build, self, panel)
	if not ok then
		warn("[EggFarm] menu " .. name .. " failed to build: " .. tostring(inst))
		inst = {}
	end
	b = { panel = panel, inst = inst }
	self.built[name] = b
	return b
end

function Host:_setBlocking(on: boolean)
	if self.blocking == on then
		return
	end
	self.blocking = on
	local list: { (boolean) -> () } = table.clone(self.blockingListeners)
	for _, fn in list do
		task.spawn(fn, on)
	end
end

function Host:_sync()
	local r = self.Router
	local want: string? = r:Current()
	-- hide the old panel
	if self.shown and self.shown ~= want then
		local old = self.built[self.shown]
		if old then
			old.panel:Hide()
		end
		self.shown = nil
	end
	if want then
		local b = self:_build(want)
		if b then
			local tab = r:GetTab(want)
			if b.panel.Tabs and tab then
				b.panel.Tabs:Select(tab)
			end
			b.panel:SetBack(r.returnTo ~= nil)
			local first = self.shown ~= want
			self.shown = want
			b.panel:Show()
			if first and b.inst.OnShow then
				b.inst.OnShow(tab, self.openOpts)
			elseif b.inst.OnTab then
				b.inst.OnTab(tab)
			end
			self.openOpts = nil
			local snap = self.Store.Get()
			if snap and b.inst.Refresh then
				b.inst.Refresh(snap)
			end
		end
	end
	self.dim.Visible = want ~= nil
	-- modal
	local modalId = r:Modal()
	if modalId then
		local data = r.modalData
		self.mdim.Visible = true
		if data and self.modal.Current ~= data then
			self.modal:Show(data)
		end
	else
		self.mdim.Visible = false
		if self.modal.Current then
			self.modal:Hide()
		end
	end
	self:_setBlocking(r:IsBlockingWorld())
end

function Host:_refresh(snap: any)
	local name = self.shown
	local b = name and self.built[name]
	if b and b.inst.Refresh then
		b.inst.Refresh(snap)
	end
	-- tabs hidden by the tutorial
	self:_applyReveals(snap)
end

function Host:_applyReveals(snap: any)
	local rev = Tutorial.Reveals(snap.tutorial.step, snap.tutorial.done)
	local farm = self.built.Farm
	if farm and farm.panel.Tabs then
		local tabs = farm.panel.Tabs
		tabs:SetVisible("Housing", rev.housing)
		tabs:SetVisible("Shipping", rev.shipping)
		tabs:SetVisible("Workers", rev.workers)
		tabs:SetVisible("Silos", rev.nav)
	end
end

------------------------------------------------------------------------------------------------
-- Public API used by menus, the HUD and controllers
------------------------------------------------------------------------------------------------

-- opts: { returnTo = true (Back returns to the current panel), slot = n (scroll to a slot) }
function Host:Open(name: string, tab: string?, opts: any?): boolean
	self.openOpts = opts
	local ok = self.Router:Open(name, tab, opts and opts.returnTo)
	if ok and self.shown == name then
		-- reopened with a new tab or slot while already visible
		local b = self.built[name]
		if b and b.inst.OnShow and opts then
			b.inst.OnShow(self.Router:GetTab(name), opts)
		end
	end
	self.openOpts = nil
	return ok
end

function Host:Toggle(name: string, tab: string?)
	if self.Router:IsOpen(name) then
		self.Router:Close()
	else
		self:Open(name, tab)
	end
end

function Host:Close()
	self.Router:Close()
end

function Host:IsOpen(name: string): boolean
	return self.Router:IsOpen(name)
end

function Host:IsBlocking(): boolean
	return self.Router:IsBlockingWorld()
end

function Host:OnBlockingChanged(fn: (boolean) -> ()): () -> ()
	table.insert(self.blockingListeners, fn)
	return function()
		local i = table.find(self.blockingListeners, fn)
		if i then
			table.remove(self.blockingListeners, i)
		end
	end
end

-- Shows the confirm modal. Returns false if another modal is already open.
-- opts: UI/Modal ShowOpts without the callbacks; onYes runs after the modal closes.
function Host:Confirm(opts: any, onYes: () -> (), onNo: (() -> ())?): boolean
	local data = table.clone(opts)
	data.cancelText = data.cancelText or "Cancel"
	data.onConfirm = function()
		self.Router:CloseModal()
		onYes()
	end
	data.onCancel = function()
		self.Router:CloseModal()
		if onNo then
			onNo()
		end
	end
	return self.Router:OpenModal("confirm", data)
end

-- A modal with a single button (Welcome back, info). Returns false if one is already open.
function Host:Notice(id: string, opts: any, onOk: (() -> ())?): boolean
	local data = table.clone(opts)
	data.cancelText = nil
	data.onConfirm = function()
		self.Router:CloseModal()
		if onOk then
			onOk()
		end
	end
	return self.Router:OpenModal(id, data)
end

function Host:Toast(text: string, kind: string?)
	Toasts.Show(text, kind)
end

function Host:Sound(name: string)
	SoundC.Play(name)
end

function Host:Reveals(): { [string]: boolean }
	local snap = self.Store.Get()
	if not snap then
		return Tutorial.Reveals(1, false)
	end
	return Tutorial.Reveals(snap.tutorial.step, snap.tutorial.done)
end

-- Request helper for simple (non-PurchaseButton) actions: toasts the rejection message.
function Host:Request(action: any): any
	local res = self.Store.Request(action)
	if not res.ok and res.code ~= "busy" then
		self:Sound("error")
		self:Toast(res.message or "That didn't work.", "bad")
	end
	return res
end

return Host
