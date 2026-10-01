-- Headless Roblox mock, part 4: builds the DataModel from the Rojo sourcemap (passed in by
-- run.py as M.TREE / M.SOURCES), implements require (instance and string paths) with one module
-- cache per context, runs server Scripts and per-client LocalScripts, and adds/removes players.

local V = M.Vector3.new
local Vector2 = M.Vector2
local Enum = M.Enum
local cur = M.cur
local isA = M.isA
local SignalApi = M.SignalApi
local getSignal = M.getSignal
local newInstance = M.newInstance
local game = M.game

-- Globals for game code. The Luau CLI's global table is read-only, so the Roblox globals are
-- passed to every chunk as locals declared on its first line (line numbers stay identical).
local G = table.clone(M.globals)
G.typeof = M.typeof
G.game = game
G.Game = game
G.workspace = game:GetService("Workspace")
G.Workspace = G.workspace
G.shared = {}
G.settings = function()
	return { Rendering = { QualityLevel = 10 }, Physics = {}, Network = {} }
end
G.UserSettings = function()
	return { GameSettings = { SavedQualityLevel = Enum.SavedQualitySetting.Automatic, MasterVolume = 1 }, GetService = function(self, n)
		return self.GameSettings
	end }
end
G.version = function()
	return "headless-mock"
end
local envNames, envValues = {}, {}
for k, v in G do
	table.insert(envNames, k)
end
table.sort(envNames)
for i, k in envNames do
	envValues[i] = G[k]
end
local PREFIX = "local script, require, " .. table.concat(envNames, ", ") .. " = ...; "
M.G = G

------------------------------------------------------------------------------------------ tree
local function setProps(inst, props)
	for k, v in props or {} do
		inst[k] = v
	end
end

local function build(node, parent)
	local inst
	if parent == nil then
		inst = game
	elseif parent == game and M.Classes[node.c] and M.Classes[node.c].service then
		inst = game:GetService(node.c)
	else
		inst = newInstance(node.c, nil)
		rawget(inst, "_p").Name = node.n
		M.setParent(inst, parent)
	end
	if node.s then
		rawset(inst, "_src", M.SOURCES[node.s])
		rawset(inst, "_file", node.f)
	end
	setProps(inst, node.p)
	for _, ch in node.k or {} do
		build(ch, inst)
	end
	return inst
end

------------------------------------------------------------------------------------------ require
M.compiled = {} -- source -> count (stats only)

local function compile(inst)
	local src = rawget(inst, "_src")
	if not src then
		error("Module " .. M.fullName(inst) .. " has no source", 3)
	end
	-- one-line prefix keeps line numbers identical to the file
	local chunk, err = loadstring(PREFIX .. src, "=" .. M.fullName(inst))
	if not chunk then
		error("compile error: " .. tostring(err), 3)
	end
	return chunk
end

local requireFor

-- Roblox require-by-string: "./X" = sibling, "../X" = parent's sibling, "@self/X" = child.
local function resolveString(from, path)
	local segs = string.split(path, "/")
	local cur_
	local i = 1
	if segs[1] == "@self" then
		cur_ = from
		i = 2
	elseif segs[1] == "." then
		cur_ = rawget(from, "_parent")
		i = 2
	elseif segs[1] == ".." then
		cur_ = rawget(from, "_parent")
	else
		error("require path must start with ./, ../ or @self: " .. path, 3)
	end
	while i <= #segs do
		local s = segs[i]
		if s == ".." then
			cur_ = cur_ and rawget(cur_, "_parent")
		elseif s ~= "." and s ~= "" then
			local nxt = cur_ and cur_:FindFirstChild(s)
			if not nxt then
				error("Could not resolve require \"" .. path .. "\" from " .. M.fullName(from) .. " (missing " .. s .. ")", 3)
			end
			cur_ = nxt
		end
		i += 1
	end
	return cur_
end

local LOADING = {}
local function requireIn(ctx, mod, from)
	if type(mod) == "string" then
		mod = resolveString(from, mod)
	end
	if not M.isInst(mod) or not isA(mod, "ModuleScript") then
		error("Attempted to call require with invalid argument(s).", 3)
	end
	local cache = ctx.modules
	local entry = cache[mod]
	if entry then
		if entry.state == LOADING then
			error("Requested module was required recursively: " .. M.fullName(mod), 3)
		end
		if entry.failed then
			error("Requested module experienced an error while loading: " .. M.fullName(mod), 3)
		end
		return entry.value
	end
	entry = { state = LOADING }
	cache[mod] = entry
	local chunk = compile(mod)
	M.compiled[mod] = (M.compiled[mod] or 0) + 1
	local res = table.pack(pcall(chunk, mod, requireFor(ctx, mod), table.unpack(envValues)))
	if not res[1] then
		entry.state = nil
		entry.failed = true
		error(res[2], 0)
	end
	if res.n ~= 2 then
		entry.failed = true
		error("Module code did not return exactly one value: " .. M.fullName(mod), 3)
	end
	entry.state = nil
	entry.value = res[2]
	return entry.value
end
M.requireIn = requireIn

requireFor = function(ctx, from)
	return function(x)
		return requireIn(ctx, x, from)
	end
end

-- run a Script/LocalScript body in a new thread of ctx
function M.runScript(ctx, inst)
	local chunk = compile(inst)
	local co = M.newThread(ctx, function()
		chunk(inst, requireFor(ctx, inst), table.unpack(envValues))
	end)
	M.resume(co)
	return co
end

------------------------------------------------------------------------------------------ boot
function M.buildDataModel()
	build(M.TREE, nil)
	-- engine-provided folders
	local sp = game:GetService("StarterPlayer")
	if not sp:FindFirstChild("StarterPlayerScripts") then
		local s = newInstance("StarterPlayerScripts", nil)
		rawget(s, "_p").Name = "StarterPlayerScripts"
		M.setParent(s, sp)
	end
	for _, n in { "Players", "RunService", "Lighting", "SoundService", "ReplicatedStorage", "ServerScriptService", "StarterGui" } do
		game:GetService(n)
	end
end

local function scriptsUnder(root, class)
	local out = {}
	for _, d in M.descendantsRaw(root, {}) do
		if rawget(d, "_class").name == class and rawget(d, "_src") then
			table.insert(out, d)
		end
	end
	return out
end

function M.startServer()
	local list = {}
	for _, root in { game:GetService("ServerScriptService"), game:GetService("Workspace") } do
		for _, s in scriptsUnder(root, "Script") do
			if s.RunContext ~= Enum.RunContext.Client then
				table.insert(list, s)
			end
		end
	end
	for _, s in list do
		M.runScript(M.serverCtx, s)
	end
	return #list
end

------------------------------------------------------------------------------------------ players
M.nextUserId = 1001
M.clients = {}

function M.addPlayer(name, opts)
	opts = opts or {}
	local Players = game:GetService("Players")
	local userId = opts.userId or M.nextUserId
	M.nextUserId += 1
	local p = newInstance("Player", nil)
	local pp = rawget(p, "_p")
	pp.Name = name
	pp.UserId = userId
	pp.DisplayName = opts.displayName or name
	pp.MembershipType = if opts.premium then Enum.MembershipType.Premium else Enum.MembershipType.None
	local ctx = {
		kind = "client",
		name = "client:" .. name,
		modules = {},
		cpu = 0,
		player = p,
		opts = opts,
	}
	rawset(p, "_ctx", ctx)
	table.insert(M.contexts, ctx)
	M.clients[ctx] = true
	-- per-client camera (client-owned, so invisible to others)
	local cam = newInstance("Camera", ctx)
	rawget(cam, "_p").Name = "Camera"
	rawget(cam, "_p").ViewportSize = opts.viewport or Vector2.new(1280, 720)
	ctx.camera = cam
	local pg = newInstance("PlayerGui", nil)
	rawget(pg, "_p").Name = "PlayerGui"
	M.setParent(pg, p)
	local ps = newInstance("PlayerScripts", ctx)
	rawget(ps, "_p").Name = "PlayerScripts"
	M.setParent(ps, p)
	local bp = newInstance("Backpack", nil)
	rawget(bp, "_p").Name = "Backpack"
	M.setParent(bp, p)
	M.setParent(p, Players)
	SignalApi.FireFor(getSignal(Players, "PlayerAdded"), nil, p)
	-- the client loads a moment later: StarterPlayerScripts are copied and LocalScripts run
	ctx.started = false
	M.task.delay(opts.clientDelay or 0.1, function()
		if ctx.dead then
			return
		end
		M.startClient(ctx)
	end)
	return p, ctx
end

function M.startClient(ctx)
	ctx.started = true
	local p = ctx.player
	local ps = p:FindFirstChild("PlayerScripts") or nil
	-- copy StarterPlayerScripts in the client's context (client-owned copies)
	local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	local scripts = {}
	M.spawnIn(ctx, function()
		for _, ch in sps:GetChildren() do
			local copy = ch:Clone()
			copy.Parent = ps
		end
		local sg = game:GetService("StarterGui")
		for _, ch in sg:GetChildren() do
			local copy = ch:Clone()
			copy.Parent = p:FindFirstChild("PlayerGui")
		end
	end)
	-- Clone does not copy sources; attach them
	local function attach(src, dst)
		rawset(dst, "_src", rawget(src, "_src"))
		local a, b = rawget(src, "_kids"), rawget(dst, "_kids")
		for i, ch in a do
			if b[i] then
				attach(ch, b[i])
			end
		end
	end
	local kidsSrc = rawget(sps, "_kids")
	local kidsDst = {}
	for _, ch in rawget(ps, "_kids") do
		table.insert(kidsDst, ch)
	end
	for i, ch in kidsSrc do
		if kidsDst[i] then
			attach(ch, kidsDst[i])
		end
	end
	for _, s in M.descendantsRaw(ps, {}) do
		local cn = rawget(s, "_class").name
		if rawget(s, "_src") and (cn == "LocalScript" or (cn == "Script" and s.RunContext == Enum.RunContext.Client)) then
			table.insert(scripts, s)
		end
	end
	if ctx.opts.beforeScripts then
		ctx.opts.beforeScripts(ctx)
	end
	for _, s in scripts do
		M.runScript(ctx, s)
	end
end

-- player leaves (or is kicked): PlayerRemoving fires while still parented, then the client dies
function M.removePlayer(p)
	local Players = game:GetService("Players")
	if rawget(p, "_parent") ~= Players then
		return
	end
	local ctx = rawget(p, "_ctx")
	SignalApi.FireFor(getSignal(Players, "PlayerRemoving"), nil, p)
	if ctx then
		ctx.dead = true
		M.clients[ctx] = nil
		M.actions[ctx] = nil
		-- the client's local instances vanish with it
		for _, inst in M.descendantsRaw(game, {}) do
			if rawget(inst, "_owner") == ctx and rawget(inst, "_parent") and rawget(rawget(inst, "_parent"), "_owner") ~= ctx then
				M.setParent(inst, nil)
			end
		end
	end
	local ch = rawget(p, "_p").Character
	if ch then
		ch:Destroy()
	end
	M.setParent(p, nil)
end

function M.shutdown()
	for _, b in M.bindToClose do
		M.spawnIn(b.ctx, b.fn)
	end
end
