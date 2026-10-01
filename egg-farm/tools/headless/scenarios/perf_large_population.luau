-- (g) Full server (8 players), every farm maxed at the last egg with a huge population; run 10
-- simulated minutes. Measures Lua time (os.clock inside the mock, so it includes mock overhead
-- and is NOT a Roblox frame time), visible chicken rigs vs Flock caps, and snapshot sizes.
H.boot()
local N = 8
local names = { "Alice", "Bob", "Cara", "Dev", "Eli", "Fay", "Gus", "Hana" }
local cs = {}
for i = 1, N do
	cs[i] = H.join(names[i])
end
for i = 1, N do
	Lib.waitSnap(cs[i])
end
local a = cs[1]
local Modifiers = H.serverRequire("ReplicatedStorage.Shared.Logic.Modifiers")
local Flock = H.serverRequire("ReplicatedStorage.Shared.Logic.Flock")
local FarmService = H.serverRequire("ServerScriptService.Server.Services.FarmService")
for i = 1, N do
	Lib.dev(cs[i], "egg", 10)
	Lib.dev(cs[i], "maxed")
	Lib.dev(cs[i], "boosts")
end
Lib.request(a, { type = "setSetting", id = "flock", value = "high" })
for i = 1, N do
	local st, farm = Lib.state(cs[i])
	local cap = Modifiers.TotalCapacity(st, farm:Mods(FarmService.Now()))
	st.population = cap
	farm.dirty = true
	Lib.request(cs[i], { type = "setAutoSpawn", value = true })
end
H.wait(10)
local s = Lib.snap(a)
H.note("fixture", { egg = s.egg, population = s.population, capacity = s.capacity, houses = Lib.state(a).housing[1].tier, cashRate = s.rates.cash })
-- stand Alice in the middle of her plot so neighbours are within view distance
local plot = Lib.plotOf(a)
a:teleport(plot.Warehouse.DepositRing.Position + Vector3.new(0, 3, 0))

local PlotLayout = H.serverRequire("ReplicatedStorage.Shared.Logic.PlotLayout")
local ownIndex = a.player:GetAttribute("PlotIndex")
local function chickens(c)
	return c:run(function()
		local fv = workspace:FindFirstChild("FarmVisuals")
		local total, own = 0, 0
		local perPlot = {}
		for _, m in fv:GetChildren() do
			if m:IsA("Model") and m.Name == "Chicken" then
				-- the invisible Root isn't posed by Rig (only visible parts move), so use the Body
				local body = m:FindFirstChild("Body")
				local p = body and body.Position or Vector3.new(0, -9999, 0)
				if p.Y > -1000 then
					total += 1
					for i = 1, PlotLayout.PlotCount do
						local b = PlotLayout.Bounds(i)
						if p.X >= b.x0 and p.X <= b.x1 and p.Z >= b.z0 and p.Z <= b.z1 then
							perPlot[i] = (perPlot[i] or 0) + 1
							if i == ownIndex then
								own += 1
							end
						end
					end
				end
			end
		end
		return total, own, perPlot
	end)
end

H.section("10 simulated minutes at 30 fps")
local M = H.M
for _, ctx in M.contexts do
	ctx.cpu = 0
end
local snapStats0 = table.clone(M.netStats.Snapshot or { messages = 0, bytes = 0, maxBytes = 0 })
local frames = 0
local srv, cli, allCli = {}, {}, {}
local maxChickens, maxOwn, maxOther = 0, 0, 0
local wall0 = M.realClock()
local SECONDS = tonumber(M.ARGS.SECONDS) or 600
M.profile = M.ARGS.PROFILE == "1"
local dt = 1 / 30
local nextCount = 0
while frames * dt < SECONDS do
	local s0, c0 = M.serverCtx.cpu, a.ctx.cpu
	local all0 = 0
	for i = 1, N do
		all0 += cs[i].ctx.cpu
	end
	M.frame(dt)
	frames += 1
	local all1 = 0
	for i = 1, N do
		all1 += cs[i].ctx.cpu
	end
	table.insert(srv, (M.serverCtx.cpu - s0) * 1000)
	table.insert(cli, (a.ctx.cpu - c0) * 1000)
	table.insert(allCli, (all1 - all0) * 1000)
	if M.clock >= nextCount then
		nextCount = M.clock + 5
		local t, o, per = chickens(a)
		maxChickens = math.max(maxChickens, t)
		maxOwn = math.max(maxOwn, o)
		for i, n in per do
			if i ~= ownIndex then
				maxOther = math.max(maxOther, n)
			end
		end
	end
end
local wall = M.realClock() - wall0
local function stats(list)
	local sorted = table.clone(list)
	table.sort(sorted)
	local sum = 0
	for _, v in list do
		sum += v
	end
	return {
		avg = math.floor(sum / #list * 1000) / 1000,
		p50 = math.floor(sorted[math.ceil(#sorted * 0.5)] * 1000) / 1000,
		p95 = math.floor(sorted[math.ceil(#sorted * 0.95)] * 1000) / 1000,
		max = math.floor(sorted[#sorted] * 1000) / 1000,
	}
end
local ss, cc, aa = stats(srv), stats(cli), stats(allCli)
H.note("frames simulated", { frames = frames, simSeconds = SECONDS, wallSeconds = math.floor(wall * 10) / 10 })
H.note("server Lua ms per frame (8 farms, Heartbeat + 4 Hz economy + 5 Hz zones)", ss)
H.note("one client Lua ms per frame (HUD + visuals, flock=high)", cc)
H.note("all 8 clients Lua ms per frame (sum)", aa)
-- 4 Hz server economy ticks: frames where the server did real work
local tickFrames = {}
for _, v in srv do
	if v > ss.p50 * 2 then
		table.insert(tickFrames, v)
	end
end
if #tickFrames > 0 then
	H.note("server frames with a farm tick", stats(tickFrames))
end
if M.profile then
	local rows = {}
	for k, v in M.prof do
		table.insert(rows, { k = k, ms = v * 1000 })
	end
	table.sort(rows, function(x, y)
		return x.ms > y.ms
	end)
	for i = 1, math.min(15, #rows) do
		H.log(string.format("  prof %8.1f ms total  %6.3f ms/frame  %s", rows[i].ms, rows[i].ms / frames, rows[i].k))
	end
end

H.section("visible chicken rigs vs Flock caps")
local high = Flock.Caps.high.plot
local otherMax = Flock.Other.plot * (N - 1)
H.check("own plot rigs <= high cap (" .. high .. ")", maxOwn <= high and maxOwn > 0, { maxOwn = maxOwn })
H.check("any other player's plot shows <= " .. Flock.Other.plot .. " rigs", maxOther <= Flock.Other.plot, { maxOtherPlot = maxOther })
H.check("all visible rigs <= own cap + 4 per other plot (" .. (high + otherMax) .. ")", maxChickens <= high + otherMax, { maxTotal = maxChickens })
-- stand on the boulevard between plots so several neighbours are within view distance
local o1 = PlotLayout.Origin(ownIndex)
a:teleport(Vector3.new(o1.x + 100, 3, 0))
H.wait(2)
local tB, oB, perB = chickens(a)
local maxOtherB, plotsShown = 0, 0
for i, n in perB do
	if i ~= ownIndex then
		maxOtherB = math.max(maxOtherB, n)
		plotsShown += 1
	end
end
H.check("from the boulevard: neighbours visible, each <= " .. Flock.Other.plot .. " rigs", plotsShown > 0 and maxOtherB <= Flock.Other.plot, { perPlot = perB, total = tB })
a:teleport(plot.Warehouse.DepositRing.Position + Vector3.new(0, 3, 0))
Lib.request(a, { type = "setSetting", id = "flock", value = "low" })
H.wait(3)
local tLow, oLow = chickens(a)
H.check("flock=low shrinks own plot to <= " .. Flock.Caps.low.plot, oLow <= Flock.Caps.low.plot and oLow > 0, { own = oLow, total = tLow })
-- relative cost of the flock setting (same mock, same farm): 10 s at each setting
local function clientMsPerFrame(seconds)
	local c0, f0 = a.ctx.cpu, 0
	local n = math.floor(seconds * 30)
	for _ = 1, n do
		M.frame(1 / 30)
	end
	return (a.ctx.cpu - c0) * 1000 / n
end
local lowMs = clientMsPerFrame(10)
Lib.request(a, { type = "setSetting", id = "flock", value = "high" })
H.wait(2)
local highMs = clientMsPerFrame(10)
Lib.request(a, { type = "setSetting", id = "flock", value = "low" })
H.wait(2)
H.note("client Lua ms/frame by flock setting (mock, relative)", { low = math.floor(lowMs * 1000) / 1000, high = math.floor(highMs * 1000) / 1000 })
local fvParts = a:run(function()
	local n = 0
	for _, d in workspace:FindFirstChild("FarmVisuals"):GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end)
H.note("client FarmVisuals BaseParts (flock=low, incl. pooled vehicles/workers)", fvParts)

H.section("network payloads")
local sn = M.netStats.Snapshot
local msgs = sn.messages - snapStats0.messages
local bytes = sn.bytes - snapStats0.bytes
H.note("Snapshot remote over the run (all 8 players)", { messages = msgs, perPlayerPerSecond = math.floor(msgs / N / SECONDS * 100) / 100, avgBytes = math.floor(bytes / math.max(1, msgs)), maxBytes = sn.maxBytes })
H.check("snapshots throttled (~4/s cap per player plus forced pushes after actions)", msgs / N / SECONDS <= 4.5, msgs / N / SECONDS)
H.check("snapshot JSON size under 8 KB", sn.maxBytes < 8192, sn.maxBytes)
local fe = M.netStats.FarmEvent
H.note("FarmEvent remote", fe and { messages = fe.messages, maxBytes = fe.maxBytes })
local act = M.netStats.Action
H.note("Action requests (auto spawn is server-side)", act and act.messages)
H.note("Lua heap KB (whole process: mock + 9 contexts)", math.floor(gcinfo()))
H.emitFile("tools/headless/out/perf.json", H.json({ server = ss, client = cc, allClients = aa, maxChickens = maxChickens, maxOwn = maxOwn, snapshot = { messages = msgs, avgBytes = math.floor(bytes / math.max(1, msgs)), maxBytes = sn.maxBytes }, frames = frames, wall = wall }))
