-- Shared scenario helpers (included before every scenario).
local Lib = {}
M.Lib = Lib

-- boot the server and join one player; wait for the first snapshot on the client
function Lib.start(names, opts)
	H.boot()
	local clients = {}
	for i, n in names do
		clients[i] = H.join(n, opts and opts[i])
	end
	for _, c in clients do
		Lib.waitSnap(c)
	end
	return clients
end

function Lib.store(c)
	return c:require("Client.Store")
end

function Lib.snap(c)
	return Lib.store(c).Get()
end

function Lib.waitSnap(c, timeout)
	return H.waitUntil(function()
		local ok, s = pcall(function()
			return c.ctx.started and Lib.store(c).Get()
		end)
		return ok and s
	end, timeout or 15)
end

-- the server's live FarmState for a player
function Lib.state(c)
	local FarmService = H.serverRequire("ServerScriptService.Server.Services.FarmService")
	local f = FarmService.Get(c.player)
	return f and f.state, f
end

-- Store.Request through the client's real request path
function Lib.request(c, action, timeout)
	local Store = Lib.store(c)
	return c:run(function()
		return Store.Request(action)
	end, timeout)
end

function Lib.dev(c, cmd, arg)
	return c:run(function()
		local rs = game:GetService("ReplicatedStorage")
		return rs:WaitForChild("DevCommand"):InvokeServer(cmd, arg)
	end)
end

function Lib.plotOf(c)
	local idx = c.player:GetAttribute("PlotIndex")
	return idx and workspace.Plots:FindFirstChild("Plot" .. idx), idx
end

function Lib.ringPos(part)
	return part.Position + H.Vector3.new(0, 3, 0)
end

-- the visible TextLabel whose text starts with `prefix` (optionally under `under`)
function Lib.label(c, prefix, under)
	for _, d in c:findAllGui(function(d)
		return d:IsA("TextLabel") and string.sub(d.Text, 1, #prefix) == prefix
	end, under) do
		if c:isShown(d) then
			return d
		end
	end
	return nil
end

-- the PurchaseButton (TextButton "Button" in the row's Action area) of the Card row whose title
-- starts with `prefix`
function Lib.rowButton(c, prefix, under)
	local lbl = Lib.label(c, prefix, under)
	if not lbl then
		return nil, "no row titled " .. prefix
	end
	local card = lbl
	while card and card.Name ~= "Card" do
		card = card.Parent
	end
	local action = card and card:FindFirstChild("Action")
	if not action then
		return nil, "row has no Action"
	end
	for _, d in action:GetDescendants() do
		if d:IsA("TextButton") and d.Name == "Button" then
			return d, lbl
		end
	end
	return nil, "no button in row"
end

function Lib.panel(c, name)
	local menus = c:playerGui():FindFirstChild("EggFarmMenus")
	return menus and menus.Root:FindFirstChild(name)
end

-- names of the main panels currently shown
function Lib.openPanels(c)
	local out = {}
	local menus = c:playerGui():FindFirstChild("EggFarmMenus")
	for _, p in menus.Root:GetChildren() do
		if p:IsA("GuiObject") and c:isShown(p) then
			table.insert(out, p.Name)
		end
	end
	table.sort(out)
	return out
end

function Lib.hud(c, name)
	local hud = c:playerGui():FindFirstChild("EggFarmHud")
	return hud and c:findGui(name, nil, hud)
end

-- count requests that reached the server for the Action remote
function Lib.actionCount()
	local st = H.M.netStats.Action
	return st and st.messages or 0
end
