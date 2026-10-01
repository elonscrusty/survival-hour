--!nocheck
-- Headless mini-engine for smoke tests under Lune (https://lune-org.github.io).
-- It loads the BUILT place file, runs the real server and client scripts against Lune's
-- Roblox instance model (which validates every class/property name), and adds just enough
-- engine behaviour (signals, remotes, players, tasks) to drive one or more simulated players.
-- This is NOT Roblox Studio: no physics, rendering, touch, network or DataStores.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local Engine = {}
local R = roblox
Engine.errors = {}
Engine.log = {}

local function logf(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	local line = table.concat(parts, " ")
	table.insert(Engine.log, line)
	print(line)
end

---------------------------------------------------------------- signals
local Signal = {}
Signal.__index = Signal
function Signal.new(name)
	return setmetatable({ name = name, fns = {} }, Signal)
end
function Signal:Connect(fn)
	local entry = { fn = fn, on = true }
	table.insert(self.fns, entry)
	return { Disconnect = function() entry.on = false end, Connected = true }
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c.Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Fire(...)
	for _, e in table.clone(self.fns) do
		if e.on then
			local args = table.pack(...)
			task.spawn(function()
				local ok, err = pcall(e.fn, table.unpack(args, 1, args.n))
				if not ok then
					table.insert(Engine.errors, "signal " .. self.name .. ": " .. tostring(err))
					logf("[ERROR] in " .. self.name .. " handler: " .. tostring(err))
				end
			end)
		end
	end
end
function Signal:Wait()
	local co = coroutine.running()
	self:Once(function(...)
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end
Engine.Signal = Signal

-- Lune returns a fresh handle on every access, so instances get a stable id attribute.
local nextId = 0
local function idOf(inst)
	local okAlive, existing = pcall(inst.GetAttribute, inst, "__sid")
	if not okAlive then
		return -1 -- destroyed instance: its signals are gone
	end
	local id = existing
	if not id then
		nextId += 1
		id = nextId
		inst:SetAttribute("__sid", id)
	end
	return id
end
Engine.idOf = idOf

-- per-instance signals, created on first access
local signals = {}
local function sig(inst, name)
	local key = idOf(inst)
	local t = signals[key]
	if not t then
		t = {}
		signals[key] = t
	end
	if not t[name] then
		t[name] = Signal.new(name)
	end
	return t[name]
end
Engine.sig = sig

local EVENTS = {
	Instance = { "ChildAdded", "ChildRemoved", "DescendantAdded", "AncestryChanged", "Destroying", "Changed" },
	BasePart = { "Touched", "TouchEnded" },
	ProximityPrompt = { "Triggered" },
	GuiButton = { "Activated", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "MouseLeave", "MouseEnter" },
	TextBox = { "FocusLost" },
	BindableEvent = { "Event" },
	RemoteEvent = { "OnServerEvent", "OnClientEvent" },
	Player = { "CharacterAdded", "CharacterRemoving" },
	Humanoid = { "Died" },
}
for class, names in EVENTS do
	for _, n in names do
		R.implementProperty(class, n, function(self)
			return sig(self, n)
		end)
	end
end
R.implementMethod("Instance", "GetPropertyChangedSignal", function(self, prop)
	return sig(self, "Changed:" .. prop)
end)
Engine.invokers = {}
R.implementProperty("BindableFunction", "OnInvoke", function(self)
	return Engine.invokers[idOf(self)]
end, function(self, fn)
	Engine.invokers[idOf(self)] = fn
end)
R.implementMethod("BindableFunction", "Invoke", function(self, ...)
	return Engine.invokers[idOf(self)](...)
end)
R.implementMethod("BindableEvent", "Fire", function(self, ...)
	sig(self, "Event"):Fire(...)
end)

-- remotes: deep-copy arguments like the network would (tables become plain data)
local function copy(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in v do
		t[k] = copy(x)
	end
	return t
end
local function copyAll(...)
	local n = select("#", ...)
	local out = {}
	for i = 1, n do
		out[i] = copy((select(i, ...)))
	end
	return table.unpack(out, 1, n)
end
Engine.remoteTraffic = { toServer = 0, toClient = 0, bytesToClient = 0 }
R.implementMethod("RemoteEvent", "FireServer", function(self, ...)
	Engine.remoteTraffic.toServer += 1
	sig(self, "OnServerEvent"):Fire(Engine.localPlayer, copyAll(...))
end)
R.implementMethod("RemoteEvent", "FireClient", function(self, player, ...)
	Engine.remoteTraffic.toClient += 1
	local ok, enc = pcall(serde.encode, "json", { ... })
	if ok then
		Engine.remoteTraffic.bytesToClient += #enc
	end
	if player == Engine.localPlayer then
		sig(self, "OnClientEvent"):Fire(copyAll(...))
	end
	if Engine.onClientEvent then
		Engine.onClientEvent(self.Name, player, ...)
	end
end)

---------------------------------------------------------------- instance helpers
R.implementMethod("Instance", "WaitForChild", function(self, name, timeout)
	local t0 = os.clock()
	while true do
		local c = self:FindFirstChild(name)
		if c then
			return c
		end
		if os.clock() - t0 > (timeout or 5) then
			if timeout then
				return nil
			end
			error("Infinite yield: WaitForChild(" .. name .. ") on " .. self:GetFullName())
		end
		task.wait(0.05)
	end
end)
R.implementMethod("PVInstance", "PivotTo", function(self, cf)
	if self:IsA("BasePart") then
		self.CFrame = cf
		self.Position = cf.Position
		return
	end
	local old = self:GetPivot()
	local delta = cf * old:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
			d.Position = d.CFrame.Position
		end
	end
	Engine.pivots[idOf(self)] = cf
end)
Engine.pivots = {}
R.implementMethod("PVInstance", "GetPivot", function(self)
	if self:IsA("BasePart") then
		return self.CFrame
	end
	return Engine.pivots[idOf(self)] or R.CFrame.new()
end)
R.implementProperty("Model", "WorldPivot", function(self)
	return Engine.pivots[idOf(self)] or R.CFrame.new()
end, function(self, v)
	Engine.pivots[idOf(self)] = v
end)
R.implementMethod("Instance", "GetFullName", function(self)
	local parts = {}
	local i = self
	while i and i.ClassName ~= "DataModel" do
		table.insert(parts, 1, i.Name)
		i = i.Parent
	end
	return table.concat(parts, ".")
end)
R.implementMethod("Player", "Kick", function(self, msg)
	logf("[kick] " .. self.Name .. ": " .. tostring(msg))
	self.Parent = nil
end)
R.implementMethod("Sound", "Play", function() end)
R.implementMethod("ParticleEmitter", "Emit", function() end)
R.implementMethod("Model", "ScaleTo", function() end)
R.implementMethod("Model", "GetScale", function()
	return 1
end)
R.implementMethod("Workspace", "GetServerTimeNow", function()
	return os.clock()
end)

---------------------------------------------------------------- services
local function serviceStubs(dm, side)
	local players = dm:GetService("Players")
	local s = {}
	s.RunService = {
		IsServer = function()
			return side == "server"
		end,
		IsClient = function()
			return side == "client"
		end,
		IsStudio = function()
			return true
		end,
		Heartbeat = Engine.heartbeat,
		RenderStepped = Engine.renderStepped,
		Stepped = Engine.heartbeat,
	}
	s.Players = setmetatable({
		PlayerAdded = Engine.playerAdded,
		PlayerRemoving = Engine.playerRemoving,
		LocalPlayer = if side == "client" then Engine.localPlayer else nil,
		GetPlayers = function()
			return players:GetChildren()
		end,
		GetPlayerFromCharacter = function(_, ch)
			for _, p in players:GetChildren() do
				if p.Character == ch then
					return p
				end
			end
			return nil
		end,
		GetPlayerByUserId = function(_, id)
			for _, p in players:GetChildren() do
				if p.UserId == id then
					return p
				end
			end
			return nil
		end,
	}, { __index = players, __newindex = function() end })
	s.HttpService = {
		JSONEncode = function(_, v)
			return serde.encode("json", v)
		end,
		JSONDecode = function(_, v)
			return serde.decode("json", v)
		end,
		GenerateGUID = function()
			return string.format("%08x-%04x", math.random(0, 0x7fffffff), math.random(0, 0xffff))
		end,
	}
	s.TextService = {
		FilterStringAsync = function(_, text)
			-- test filter: anything containing "badword" is censored like Roblox does
			local out = text:gsub("[Bb]adword", "#######")
			return {
				GetNonChatStringForBroadcastAsync = function()
					if Engine.filterFails then
						error("filter service unavailable")
					end
					return out
				end,
			}
		end,
	}
	s.MarketplaceService = setmetatable({
		PromptGamePassPurchaseFinished = Signal.new("PromptGamePassPurchaseFinished"),
		UserOwnsGamePassAsync = function()
			return false
		end,
		GetProductInfo = function()
			return { PriceInRobux = 0 }
		end,
		PromptProductPurchase = function()
			logf("[market] PromptProductPurchase called (real purchase prompt)")
		end,
		PromptGamePassPurchase = function()
			logf("[market] PromptGamePassPurchase called (real purchase prompt)")
		end,
	}, { __newindex = function(t, k, v)
		rawset(t, k, v)
	end })
	s.TweenService = {
		Create = function(_, inst, info, goal)
			local completed = Signal.new("TweenCompleted")
			return {
				Completed = completed,
				Play = function()
					for k, v in goal do
						pcall(function()
							inst[k] = v
						end)
					end
					completed:Fire(Enum and Enum.PlaybackState and Enum.PlaybackState.Completed or nil)
				end,
				Cancel = function() end,
			}
		end,
	}
	s.Debris = { AddItem = function() end }
	s.UserInputService = { TouchEnabled = Engine.touch == true, KeyboardEnabled = Engine.touch ~= true }
	s.DataStoreService = {
		GetDataStore = function()
			error("DataStore not available in smoke tests")
		end,
	}
	return s
end

local shared = {}
function Engine.makeGame(dm, side)
	local stubs = serviceStubs(dm, side)
	shared[side] = stubs
	local g = setmetatable({}, {
		__index = function(_, k)
			if k == "GetService" then
				return function(_, name)
					return stubs[name] or dm:GetService(name)
				end
			elseif k == "BindToClose" then
				return function(_, fn)
					table.insert(Engine.closeHandlers, fn)
				end
			elseif k == "JobId" then
				return ""
			elseif k == "GameId" or k == "PlaceId" then
				return 0
			end
			return dm[k]
		end,
	})
	return g
end
Engine.closeHandlers = {}

---------------------------------------------------------------- module loader
function Engine.newSide(dm, side)
	local cache = {}
	local game = Engine.makeGame(dm, side)
	local workspaceInst = dm:GetService("Workspace")
	local runScript
	local function resolve(from, path)
		if type(path) ~= "string" then
			return path
		end
		local node = from
		local first = true
		for seg in path:gmatch("[^/]+") do
			if seg == "." then
				node = node.Parent
			elseif seg == ".." then
				node = if first then node.Parent.Parent else node.Parent
			else
				local c = node:FindFirstChild(seg)
				if not c then
					error("require: " .. path .. " not found from " .. from:GetFullName())
				end
				node = c
			end
			first = false
		end
		return node
	end
	local function requireFrom(from)
		return function(target)
			local inst = resolve(from, target)
			local key = idOf(inst)
			if cache[key] ~= nil then
				return cache[key]
			end
			local result = runScript(inst)
			cache[key] = result
			return result
		end
	end
	local function env(scriptInst)
		local e = {
			game = game,
			workspace = workspaceInst,
			script = scriptInst,
			require = requireFrom(scriptInst),
			Instance = R.Instance,
			Vector3 = R.Vector3,
			Vector2 = R.Vector2,
			CFrame = R.CFrame,
			Color3 = R.Color3,
			UDim = R.UDim,
			UDim2 = R.UDim2,
			NumberRange = R.NumberRange,
			NumberSequence = R.NumberSequence,
			ColorSequence = R.ColorSequence,
			ColorSequenceKeypoint = R.ColorSequenceKeypoint,
			NumberSequenceKeypoint = R.NumberSequenceKeypoint,
			BrickColor = R.BrickColor,
			Rect = R.Rect,
			Enum = R.Enum,
			Random = R.Random or { new = function(seed)
				local r = { seed = seed }
				function r:NextNumber(a, b)
					a, b = a or 0, b or 1
					return a + math.random() * (b - a)
				end
				function r:NextInteger(a, b)
					return math.random(a, b)
				end
				return r
			end },
			TweenInfo = { new = function(...)
				return { ... }
			end },
			task = task,
			warn = function(...)
				logf("[warn]", ...)
			end,
			print = function(...)
				logf(...)
			end,
			typeof = typeof,
			tick = os.clock,
			utf8 = utf8,
		}
		return setmetatable(e, { __index = _G })
	end
	runScript = function(inst)
		local src = inst.Source
		local fn = luau.load(src, { debugName = inst:GetFullName(), environment = env(inst) })
		return fn()
	end
	return {
		run = runScript,
		game = game,
		require = function(inst)
			return requireFrom(inst)(inst)
		end,
	}
end

---------------------------------------------------------------- world and players
Engine.heartbeat = Signal.new("Heartbeat")
Engine.renderStepped = Signal.new("RenderStepped")
Engine.playerAdded = Signal.new("PlayerAdded")
Engine.playerRemoving = Signal.new("PlayerRemoving")

function Engine.load(placePath)
	local dm = R.deserializePlace(fs.readFile(placePath))
	Engine.dm = dm
	return dm
end

function Engine.addPlayer(dm, name, userId)
	local p = R.Instance.new("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = userId
	local gui = R.Instance.new("PlayerGui")
	gui.Parent = p
	p.Parent = dm:GetService("Players")
	Engine.playerAdded:Fire(p)
	return p
end

function Engine.spawnCharacter(p)
	local ch = R.Instance.new("Model")
	ch.Name = p.Name
	local root = R.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = R.Vector3.new(2, 2, 1)
	root.Parent = ch
	local hum = R.Instance.new("Humanoid")
	hum.Parent = ch
	ch.Parent = Engine.dm:GetService("Workspace")
	p.Character = ch
	sig(p, "CharacterAdded"):Fire(ch)
	return ch
end

function Engine.removePlayer(p)
	Engine.playerRemoving:Fire(p)
	task.wait(0.2)
	p.Parent = nil
end

-- Lune cannot compute BasePart.Position from CFrame, so mirror it periodically.
function Engine.syncPositions(root)
	for _, d in (root or Engine.dm):GetDescendants() do
		if d:IsA("BasePart") then
			d.Position = d.CFrame.Position
		end
	end
end

function Engine.startClock()
	task.spawn(function()
		while true do
			task.wait(0.5)
			if Engine.dm then
				pcall(Engine.syncPositions, Engine.dm)
			end
		end
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(1 / 30)
			Engine.heartbeat:Fire(dt)
			Engine.renderStepped:Fire(dt)
		end
	end)
end

-- find a GUI button whose visible text matches, under a root
function Engine.findButton(root, textPattern)
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") then
			for _, l in d:GetDescendants() do
				if l:IsA("TextLabel") and l.Text:find(textPattern) then
					return d, l
				end
			end
		end
	end
	return nil
end

function Engine.press(button)
	sig(button, "Activated"):Fire()
end

return Engine
