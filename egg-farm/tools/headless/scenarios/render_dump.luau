-- Dumps the ACTUAL generated world (server World builders + one client's local visuals) and the
-- PlayerGui layout to JSON for the offline renderers (tools/headless/render.py). Not Roblox
-- screenshots: geometry/colours come from the mock DataModel the real scripts built.
H.boot()
local a = H.join("Alice")
local b = H.join("Bob")
Lib.waitSnap(a)
Lib.waitSnap(b)
local plot, idx = Lib.plotOf(a)
local PlotLayout = H.serverRequire("ReplicatedStorage.Shared.Logic.PlotLayout")

local function partFilter(ctx)
	return function(d)
		if d:IsA("Terrain") then
			return false
		end
		local owner = rawget(d, "_owner")
		return owner == nil or owner == ctx
	end
end
local function cameras(tag)
	local o = PlotLayout.Origin(idx)
	local center = Vector3.new(o.x, 0, o.z)
	local spawn = plot.Spawn.Position
	local houses = plot.Houses.House1.CollectRing.Position
	local wh = plot.Warehouse.DepositRing.Position
	local target = (houses + wh) / 2
	local away = Vector3.new(spawn.X - target.X, 0, spawn.Z - target.Z).Unit
	local eye = spawn + away * 9 + Vector3.new(0, 8, 0) -- like the default camera behind the character
	-- aerial: above the plot, tilted from the boulevard side
	local toBoulevard = Vector3.new(0, 0, -o.z).Unit
	return {
		{ name = "offline_" .. tag .. "_thirdperson", pos = { eye.X, eye.Y, eye.Z }, look = { target.X, 4, target.Z }, fov = 70 },
		{ name = "offline_" .. tag .. "_aerial", pos = { center.X + toBoulevard.X * 150, 210, center.Z + toBoulevard.Z * 150 }, look = { center.X, 0, center.Z - toBoulevard.Z * 10 }, fov = 55 },
	}
end
local function dumpWorld(tag, note)
	local parts = H.M.dumpParts(workspace, partFilter(a.ctx))
	H.emitFile("tools/headless/out/world_" .. tag .. ".json", H.json({ note = note, parts = parts, cameras = cameras(tag), plot = idx }))
	H.note("world " .. tag .. " parts", #parts)
end

-- character facing the farm, standing near the spawn
local function standAtSpawn()
	local spawn = plot.Spawn.Position
	local wh = plot.Warehouse.DepositRing.Position
	local ch = a:character()
	H.M.walkers[ch] = nil
	H.M.placeCharacter(ch, CFrame.lookAt(spawn + Vector3.new(0, 3.2, 0), Vector3.new(wh.X, spawn.Y + 3.2, wh.Z)))
end

H.section("state 1: fresh farm, a few chickens (egg 1 theme)")
for i = 1, 24 do
	Lib.request(a, { type = "spawn" })
end
for i = 1, 30 do
	Lib.request(b, { type = "spawn" })
end
H.wait(20)
standAtSpawn()
H.wait(1)
dumpWorld("start", "fresh farm after the first SPAWN taps (egg 1)")

H.section("state 2: late game, maxed at egg 7 (different theme), huge flock")
Lib.dev(a, "egg", 7)
Lib.dev(a, "maxed")
Lib.request(a, { type = "setSetting", id = "flock", value = "high" })
local st, farm = Lib.state(a)
local Modifiers = H.serverRequire("ReplicatedStorage.Shared.Logic.Modifiers")
local FarmService = H.serverRequire("ServerScriptService.Server.Services.FarmService")
st.population = Modifiers.TotalCapacity(st, farm:Mods(FarmService.Now()))
farm.dirty = true
H.wait(12)
standAtSpawn()
H.wait(1)
H.note("late plot attributes", { Egg = plot:GetAttribute("Egg"), HouseTiers = plot:GetAttribute("HouseTiers"), VehicleTiers = plot:GetAttribute("VehicleTiers"), Silos = plot:GetAttribute("Silos") })
dumpWorld("late", "maxed farm on egg 7 with flock=high (egg 7 theme)")

H.section("UI layout dumps")
local function uiDump(tag, viewport, touch)
	a.ctx.opts.touch = touch
	a:setViewport(viewport)
	H.wait(0.5)
	local boxes = a:dumpUi()
	H.emitFile("tools/headless/out/ui_" .. tag .. ".json", H.json({ w = viewport.X, h = viewport.Y, boxes = boxes }))
	return boxes
end
-- fresh player HUD (tutorial step 1)
local c = H.join("Cara")
Lib.waitSnap(c)
local function uiDumpC(tag, viewport)
	c:setViewport(viewport)
	H.wait(0.5)
	H.emitFile("tools/headless/out/ui_" .. tag .. ".json", H.json({ w = viewport.X, h = viewport.Y, boxes = c:dumpUi() }))
end
uiDumpC("tutorial_1280x720", Vector2.new(1280, 720))
uiDumpC("tutorial_390x844", Vector2.new(390, 844))
uiDump("hud_1280x720", Vector2.new(1280, 720), false)
uiDump("hud_390x844", Vector2.new(390, 844), true)
uiDump("hud_844x390", Vector2.new(844, 390), true)
a:click(Lib.hud(a, "Farm"))
H.wait(0.3)
uiDump("farm_390x844", Vector2.new(390, 844), true)
uiDump("farm_1280x720", Vector2.new(1280, 720), false)

-- overlap sanity: HUD buttons must not overlap each other on either viewport
local function hudOverlaps(viewport)
	a:setViewport(viewport)
	H.wait(0.3)
	local hud = a:playerGui():FindFirstChild("EggFarmHud")
	local rects = {}
	for _, d in hud:GetDescendants() do
		if d:IsA("GuiButton") and a:isShown(d) then
			local info = H.M.guiAbs(d)
			table.insert(rects, { n = d.Name, x = info.pos.X, y = info.pos.Y, w = info.size.X, h = info.size.Y })
		end
	end
	local bad = {}
	for i = 1, #rects do
		for j = i + 1, #rects do
			local r, s = rects[i], rects[j]
			if r.x < s.x + s.w - 1 and s.x < r.x + r.w - 1 and r.y < s.y + s.h - 1 and s.y < r.y + r.h - 1 then
				table.insert(bad, r.n .. " x " .. s.n)
			end
		end
	end
	local off = {}
	for _, r in rects do
		if r.x < 0 or r.y < 0 or r.x + r.w > viewport.X or r.y + r.h > viewport.Y then
			table.insert(off, r.n)
		end
	end
	return bad, off, #rects
end
a:click(Lib.panel(a, "Farm"):FindFirstChild("Close", true))
H.wait(0.3)
for _, vp in { Vector2.new(1280, 720), Vector2.new(390, 844), Vector2.new(844, 390) } do
	local bad, off, n = hudOverlaps(vp)
	H.check(string.format("HUD buttons don't overlap and stay on screen at %dx%d (approx. layout)", vp.X, vp.Y), #bad == 0 and #off == 0, { buttons = n, overlaps = bad, offscreen = off })
end
