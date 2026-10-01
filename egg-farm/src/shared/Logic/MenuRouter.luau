--!strict
-- Which menu is open. PURE (no Roblox APIs) so the rules are unit-tested (tests/MenuRouter.spec).
-- Rules:
--   * At most one main panel is open. Opening another replaces it (no stacking of panels).
--   * At most one confirm modal sits on top. A second modal is refused while one is open.
--     Modals may also open with no panel (e.g. the offline "Welcome back" modal).
--   * Every panel remembers its last tab; reopening it shows that tab. Unknown tabs are ignored.
--   * Back(): closes the modal if there is one; otherwise returns to the panel this one was
--     opened from (only when opened with returnTo, e.g. Shop -> Codes); otherwise closes.
--   * Opening or closing a panel also closes the modal (a modal belongs to what was on screen).
--   * IsBlockingWorld() is true while any panel or modal is open: the HUD disables Spawn, world
--     prompts are disabled locally and a full-screen dimmer sinks clicks.

export type PanelDef = { tabs: { string }? }

export type Router = {
	defs: { [string]: PanelDef },
	panel: string?,
	modal: string?,
	modalData: any,
	returnTo: string?,
	tabs: { [string]: string },
	listeners: { () -> () },
	Open: (self: Router, name: string, tab: string?, returnTo: boolean?) -> boolean,
	Toggle: (self: Router, name: string, tab: string?) -> boolean,
	Close: (self: Router) -> (),
	CloseAll: (self: Router) -> (),
	Back: (self: Router) -> (),
	SetTab: (self: Router, tab: string) -> boolean,
	GetTab: (self: Router, name: string) -> string?,
	OpenModal: (self: Router, id: string, data: any?) -> boolean,
	CloseModal: (self: Router) -> (),
	Current: (self: Router) -> string?,
	Modal: (self: Router) -> string?,
	IsOpen: (self: Router, name: string) -> boolean,
	IsBlockingWorld: (self: Router) -> boolean,
	Subscribe: (self: Router, fn: () -> ()) -> () -> (),
}

local MenuRouter = {}

local function notify(self: Router)
	for _, fn in table.clone(self.listeners) do
		fn()
	end
end

local function validTab(def: PanelDef?, tab: string?): boolean
	return def ~= nil and def.tabs ~= nil and tab ~= nil and table.find(def.tabs, tab) ~= nil
end

function MenuRouter.new(defs: { [string]: PanelDef }): Router
	local self = {
		defs = defs,
		panel = nil,
		modal = nil,
		modalData = nil,
		returnTo = nil,
		tabs = {},
		listeners = {},
	} :: any

	function self.GetTab(r: Router, name: string): string?
		local def = r.defs[name]
		if not def or not def.tabs then
			return nil
		end
		return r.tabs[name] or def.tabs[1]
	end

	function self.Open(r: Router, name: string, tab: string?, returnTo: boolean?): boolean
		local def = r.defs[name]
		if not def then
			return false
		end
		if validTab(def, tab) then
			r.tabs[name] = tab :: string
		end
		local prev = r.panel
		if prev == name and r.modal == nil and (tab == nil or not validTab(def, tab)) then
			return true -- already showing; nothing changes
		end
		r.returnTo = if returnTo and prev and prev ~= name then prev else nil
		r.panel = name
		r.modal = nil
		r.modalData = nil
		notify(r)
		return true
	end

	function self.Toggle(r: Router, name: string, tab: string?): boolean
		if r.panel == name then
			r:Close()
			return false
		end
		return r:Open(name, tab)
	end

	function self.Close(r: Router)
		if r.panel == nil and r.modal == nil then
			return
		end
		r.panel = nil
		r.returnTo = nil
		r.modal = nil
		r.modalData = nil
		notify(r)
	end

	function self.CloseAll(r: Router)
		r:Close()
	end

	function self.Back(r: Router)
		if r.modal then
			r:CloseModal()
		elseif r.returnTo and r.defs[r.returnTo] then
			local to = r.returnTo
			r.returnTo = nil
			r.panel = to
			notify(r)
		else
			r:Close()
		end
	end

	function self.SetTab(r: Router, tab: string): boolean
		local name = r.panel
		if not name then
			return false
		end
		local def = r.defs[name]
		if not validTab(def, tab) then
			return false
		end
		if r.tabs[name] == tab then
			return true
		end
		r.tabs[name] = tab
		notify(r)
		return true
	end

	function self.OpenModal(r: Router, id: string, data: any?): boolean
		if r.modal ~= nil then
			return false
		end
		r.modal = id
		r.modalData = data
		notify(r)
		return true
	end

	function self.CloseModal(r: Router)
		if r.modal == nil then
			return
		end
		r.modal = nil
		r.modalData = nil
		notify(r)
	end

	function self.Current(r: Router): string?
		return r.panel
	end

	function self.Modal(r: Router): string?
		return r.modal
	end

	function self.IsOpen(r: Router, name: string): boolean
		return r.panel == name
	end

	function self.IsBlockingWorld(r: Router): boolean
		return r.panel ~= nil or r.modal ~= nil
	end

	function self.Subscribe(r: Router, fn: () -> ()): () -> ()
		table.insert(r.listeners, fn)
		return function()
			local i = table.find(r.listeners, fn)
			if i then
				table.remove(r.listeners, i)
			end
		end
	end

	return self :: Router
end

return MenuRouter
