-- Headless Roblox mock, part 1: manual clock, execution contexts (server / client N / harness),
-- cooperative scheduler (task library), signals, and per-context CPU accounting.
--
-- Every coroutine is tagged with the context that created it, so `Players.LocalPlayer`,
-- `RunService:IsClient()`, instance visibility and require caches resolve per context.

local realOs = os
local realClock = os.clock
M.realClock = realClock
M.realOs = realOs

M.clock = 0 -- simulated seconds since server start
M.EPOCH = 1790035200 -- 2026-09-22 00:00:00 UTC at clock 0 (any fixed day works)
M.frameCount = 0

function M.serverNow()
	return M.EPOCH + M.clock
end

------------------------------------------------------------------------------------------ contexts
local ctxOf = setmetatable({}, { __mode = "k" })
M.ctxOf = ctxOf
M.harnessCtx = { kind = "harness", name = "harness", modules = {}, cpu = 0 }
M.serverCtx = { kind = "server", name = "server", modules = {}, cpu = 0 }
M.contexts = { M.serverCtx }

local function cur()
	local co = coroutine.running()
	return ctxOf[co] or M.harnessCtx
end
M.cur = cur

------------------------------------------------------------------------------------------ errors
M.errors = {}
M.warnings = {}
M.quiet = false
local realPrint = print
M.realPrint = realPrint

function M.reportError(ctx, msg, tb)
	local entry = { ctx = ctx and ctx.name or "?", msg = tostring(msg), tb = tb, t = M.clock }
	table.insert(M.errors, entry)
	realPrint(string.format("[ERROR %s t=%.2f] %s", entry.ctx, M.clock, entry.msg))
	if tb and tb ~= "" then
		realPrint("    " .. string.gsub(tb, "\n", "\n    "))
	end
end

------------------------------------------------------------------------------------------ CPU
-- exclusive real time per context (nested cross-context work is attributed to the inner one)
local stack = {}
local function enter(ctx)
	local now = realClock()
	local top = stack[#stack]
	if top then
		top.ctx.cpu += now - top.t0
	end
	table.insert(stack, { ctx = ctx, t0 = now })
end
local function leave()
	local now = realClock()
	local e = table.remove(stack)
	e.ctx.cpu += now - e.t0
	local top = stack[#stack]
	if top then
		top.t0 = now
	end
end

------------------------------------------------------------------------------------------ threads
local function newThread(ctx, fn)
	local co = coroutine.create(fn)
	ctxOf[co] = ctx
	return co
end
M.newThread = newThread

-- Resume a thread, accounting its CPU to its context and reporting uncaught errors.
local function resume(co, ...)
	local ctx = ctxOf[co] or M.harnessCtx
	if ctx.dead then
		return false
	end
	if coroutine.status(co) ~= "suspended" then
		return false
	end
	enter(ctx)
	local res = table.pack(coroutine.resume(co, ...))
	leave()
	if not res[1] then
		M.reportError(ctx, res[2], debug.traceback(co))
	end
	return table.unpack(res, 1, res.n)
end
M.resume = resume

-- Run fn(...) in a new thread of ctx immediately (like task.spawn).
function M.spawnIn(ctx, fn, ...)
	local co = newThread(ctx, fn)
	resume(co, ...)
	return co
end

local sleeping = {} -- { co, wake, seq, args?, start }
local deferred = {}
local seqN = 0
M.sleeping = sleeping

local function schedule(co, delay, args)
	seqN += 1
	table.insert(sleeping, { co = co, wake = M.clock + math.max(delay or 0, 0), seq = seqN, args = args, start = M.clock })
end
M.schedule = schedule

local function isMain(co)
	return ctxOf[co] == nil and not coroutine.isyieldable()
end

local task = {}
function task.spawn(f, ...)
	if type(f) == "thread" then
		resume(f, ...)
		return f
	end
	local co = newThread(cur(), f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = if type(f) == "thread" then f else newThread(cur(), f)
	table.insert(deferred, { co = co, args = table.pack(...) })
	return co
end
function task.delay(t, f, ...)
	local co = if type(f) == "thread" then f else newThread(cur(), f)
	schedule(co, t, table.pack(...))
	return co
end
function task.wait(t)
	t = t or 0
	local co = coroutine.running()
	if isMain(co) then
		-- the harness main thread "waits" by advancing the simulation
		M.advance(t)
		return t
	end
	local start = M.clock
	schedule(co, t, nil)
	coroutine.yield()
	return M.clock - start
end
function task.cancel(co)
	for i = #sleeping, 1, -1 do
		if sleeping[i].co == co then
			table.remove(sleeping, i)
		end
	end
	for i = #deferred, 1, -1 do
		if deferred[i].co == co then
			table.remove(deferred, i)
		end
	end
	pcall(coroutine.close, co)
end
function task.synchronize() end
function task.desynchronize() end
M.task = task

-- legacy globals
M.globals.task = task
M.globals.wait = function(t)
	local e = task.wait(t or 0.03)
	return e, M.clock
end
M.globals.delay = function(t, f)
	task.delay(t, f)
end
M.globals.spawn = function(f)
	task.defer(f)
end
M.globals.tick = function()
	return M.serverNow()
end
M.globals.time = function()
	return M.clock
end
M.globals.elapsedTime = function()
	return M.clock
end
M.globals.os = {
	clock = function()
		return M.clock
	end,
	time = function(t)
		if t then
			return realOs.time(t)
		end
		return math.floor(M.serverNow())
	end,
	date = function(f, t)
		return realOs.date(f, t or math.floor(M.serverNow()))
	end,
	difftime = realOs.difftime,
}
M.globals.print = function(...)
	if M.quiet then
		return
	end
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	realPrint("[" .. cur().name .. "] " .. table.concat(parts, " ", 1, parts.n))
end
M.globals.warn = function(...)
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	local msg = table.concat(parts, " ", 1, parts.n)
	table.insert(M.warnings, { ctx = cur().name, msg = msg, t = M.clock })
	if not M.quiet then
		realPrint("[WARN " .. cur().name .. string.format(" t=%.2f] ", M.clock) .. msg)
	end
end
-- coroutines created by game code inherit the creating context
M.globals.coroutine = setmetatable({
	create = function(f)
		return newThread(cur(), f)
	end,
	wrap = function(f)
		local co = newThread(cur(), f)
		return function(...)
			local r = table.pack(coroutine.resume(co, ...))
			if not r[1] then
				error(r[2], 2)
			end
			return table.unpack(r, 2, r.n)
		end
	end,
}, { __index = coroutine })

------------------------------------------------------------------------------------------ signals
local SignalMt = {}
M.TYPE[SignalMt] = "RBXScriptSignal"
local Signal = {}
SignalMt.__index = Signal
local ConnMt = {}
M.TYPE[ConnMt] = "RBXScriptConnection"
local ConnMethods = {}
ConnMt.__index = function(c, k)
	if k == "Connected" then
		return rawget(c, "connected")
	end
	return ConnMethods[k]
end
function ConnMethods.Disconnect(c)
	if not c.connected then
		return
	end
	c.connected = false
	local list = c.signal.conns
	local i = table.find(list, c)
	if i then
		table.remove(list, i)
	end
end

-- opts.onConnect(ctx) is called when a context connects (remote event queues flush there)
function M.Signal(name, opts)
	return setmetatable({ name = name or "Signal", conns = {}, waiters = {}, opts = opts }, SignalMt)
end
function Signal.Connect(s, fn)
	assert(type(fn) == "function", "Attempt to connect failed: Passed value is not a function")
	local ctx = cur()
	local c = setmetatable({ fn = fn, ctx = ctx, connected = true, signal = s }, ConnMt)
	table.insert(s.conns, c)
	if s.opts and s.opts.onConnect then
		s.opts.onConnect(ctx)
	end
	return c
end
function Signal.Once(s, fn)
	local c
	c = Signal.Connect(s, function(...)
		ConnMethods.Disconnect(c)
		fn(...)
	end)
	return c
end
Signal.ConnectParallel = Signal.Connect
function Signal.Wait(s)
	local co = coroutine.running()
	assert(not isMain(co), "Signal:Wait() from the harness main thread")
	table.insert(s.waiters, co)
	return coroutine.yield()
end
-- Fire to every connection whose context passes `filter` (nil = all). Handlers run immediately,
-- each in its own thread of the connecting context (Roblox "Immediate" signal behaviour).
function Signal.FireFor(s, filter, ...)
	if #s.conns > 0 then
		local list = table.clone(s.conns)
		for _, c in list do
			if c.connected and not c.ctx.dead and (filter == nil or filter(c.ctx)) then
				local co = newThread(c.ctx, c.fn)
				if M.profile then
					local t0 = realClock()
					resume(co, ...)
					local key = M.profKey(c.fn, s.name)
					M.prof[key] = (M.prof[key] or 0) + (realClock() - t0)
				else
					resume(co, ...)
				end
			end
		end
	end
	if #s.waiters > 0 then
		local keep = {}
		local ws = s.waiters
		s.waiters = keep
		for _, co in ws do
			local ctx = ctxOf[co]
			if ctx and filter and not filter(ctx) then
				table.insert(keep, co)
			else
				resume(co, ...)
			end
		end
	end
end
function Signal.Fire(s, ...)
	Signal.FireFor(s, nil, ...)
end
function Signal.HasConnections(s, ctx)
	for _, c in s.conns do
		if c.connected and (ctx == nil or c.ctx == ctx) then
			return true
		end
	end
	return false
end
M.SignalApi = Signal

-- optional profiler: inclusive real time per (script:line of the handler, signal name)
M.profile = false
M.prof = {}
local profNames = setmetatable({}, { __mode = "k" })
function M.profKey(fn, sig)
	local k = profNames[fn]
	if not k then
		local src, line = debug.info(fn, "sl")
		src = string.gsub(src or "?", "^Players%.[^%.]+%.PlayerScripts%.", "")
		k = src .. ":" .. tostring(line)
		profNames[fn] = k
	end
	return k .. " <" .. sig .. ">"
end

------------------------------------------------------------------------------------------ frame loop
M.frameHooks = {} -- harness hooks run every frame before Heartbeat (character walking etc.)
M.netQueue = {} -- { at, seq, fn }

local function runDeferred()
	local guard = 0
	while #deferred > 0 do
		guard += 1
		if guard > 10000 then
			M.reportError(M.harnessCtx, "deferred thread storm (>10000 re-defers in one frame)")
			table.clear(deferred)
			break
		end
		local list = table.clone(deferred)
		table.clear(deferred)
		for _, d in list do
			resume(d.co, table.unpack(d.args, 1, d.args.n))
		end
	end
end
M.runDeferred = runDeferred

local function wakeSleepers()
	if #sleeping == 0 then
		return
	end
	local due = {}
	local keep = {}
	for _, s in sleeping do
		if s.wake <= M.clock + 1e-9 then
			table.insert(due, s)
		else
			table.insert(keep, s)
		end
	end
	if #due == 0 then
		return
	end
	table.clear(sleeping)
	for _, s in keep do
		table.insert(sleeping, s)
	end
	table.sort(due, function(a, b)
		if a.wake == b.wake then
			return a.seq < b.seq
		end
		return a.wake < b.wake
	end)
	for _, s in due do
		if s.args then
			resume(s.co, table.unpack(s.args, 1, s.args.n))
		else
			resume(s.co, M.clock - s.start)
		end
	end
end

local function deliverNet()
	if #M.netQueue == 0 then
		return
	end
	local due, keep = {}, {}
	for _, m in M.netQueue do
		if m.at <= M.clock + 1e-9 then
			table.insert(due, m)
		else
			table.insert(keep, m)
		end
	end
	M.netQueue = keep
	table.sort(due, function(a, b)
		return a.seq < b.seq
	end)
	for _, m in due do
		m.fn()
	end
end

M.FRAME = 1 / 30
-- One frame: clock advances, sleepers wake, network delivers, Heartbeat fires per context.
function M.frame(dt)
	dt = dt or M.FRAME
	M.clock += dt
	M.frameCount += 1
	for _, h in table.clone(M.frameHooks) do
		h(dt)
	end
	wakeSleepers()
	runDeferred()
	deliverNet()
	runDeferred()
	if M.onFrame then
		M.onFrame(dt)
	end
	runDeferred()
end

function M.advance(seconds, dt)
	dt = dt or M.FRAME
	local target = M.clock + seconds
	while M.clock + 1e-9 < target do
		M.frame(math.min(dt, target - M.clock))
	end
	runDeferred()
end
