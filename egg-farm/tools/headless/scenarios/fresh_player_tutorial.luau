-- (a) A brand-new player goes through the whole tutorial using the client's real UI paths.
H.boot()
local a = H.join("Alice")
local snap = Lib.waitSnap(a)
H.check("first snapshot reached the client", snap ~= nil)

H.section("plot + character")
local plot, idx = Lib.plotOf(a)
H.check("a plot was claimed for the player", plot ~= nil and plot:GetAttribute("OwnerUserId") == a.player.UserId, { plot = idx, owner = plot and plot:GetAttribute("OwnerUserId"), userId = a.player.UserId })
local spawnPart = plot and plot:FindFirstChild("Spawn")
local root = a:root()
local d = (root and spawnPart) and (root.Position - spawnPart.Position).Magnitude or -1
H.check("character spawned at the player's own plot spawn", root ~= nil and d >= 0 and d < 8, string.format("%.1f studs from Plot%d.Spawn", d, idx or 0))
H.check("RespawnLocation is the plot spawn", a.player.RespawnLocation == spawnPart)

local function step()
	local s = Lib.snap(a)
	return s and s.tutorial.step, s and s.tutorial.done
end
local function shown(name)
	local g = Lib.hud(a, name)
	return g ~= nil and a:isShown(g)
end
local function reveals()
	return { spawn = shown("Spawn"), counters = shown("CountersLeft") and shown("CountersRight"), farm = shown("Farm"), leftNav = shown("LeftNav"), auto = shown("Auto") }
end
local st = step()
H.check("tutorial starts at step 1", st == 1, st)
local r = reveals()
H.check("step 1 HUD: only SPAWN shown", r.spawn and not r.counters and not r.farm and not r.leftNav, r)
local banner = Lib.label(a, "TUTORIAL")
H.check("tutorial banner shows step 1/7", banner ~= nil and banner.Text == "TUTORIAL  1 / 7", banner and banner.Text)

H.section("spawn 20+ chickens by tapping the SPAWN button")
local spawnBtn = Lib.hud(a, "Spawn")
local before = Lib.actionCount()
local taps = 0
for i = 1, 24 do
	local ok, why = a:click(spawnBtn)
	if ok then
		taps += 1
	end
	H.wait(0.15)
end
H.wait(0.5)
local s = Lib.snap(a)
local sent = Lib.actionCount() - before
H.check("24 taps -> 24 spawn requests", sent == 24, { taps = taps, requests = sent })
H.check("population >= 20 after taps", s.population >= 20, { population = s.population, capacity = s.capacity })
st = step()
H.check("tutorial advanced to step 2 (collect)", st == 2, st)
r = reveals()
H.check("step 2 HUD: counters revealed, Farm still hidden", r.counters and not r.farm, r)

H.section("lay eggs, collect at House1, deposit at warehouse")
H.wait(12)
local state = Lib.state(a)
local houseEggs = state.housing[1].eggs
H.check("House1 laid eggs while idle", houseEggs > 0, { eggs = houseEggs, layRate = Lib.snap(a).rates.lay })
local ring = plot.Houses.House1.CollectRing
local okWalk = a:walkTo(ring.Position)
H.wait(0.6)
s = Lib.snap(a)
H.check("walking into House1 CollectRing collects eggs", okWalk and s.carried > 0, { carried = s.carried, carryCap = s.carryCap })
st = step()
H.check("tutorial advanced to step 3 (deposit)", st == 3, st)
local dep = plot.Warehouse.DepositRing
a:walkTo(dep.Position)
H.wait(0.6)
s = Lib.snap(a)
H.check("walking into the DepositRing moves the basket to the warehouse", s.carried == 0 and (s.warehouse > 0 or Lib.state(a).stats.deposited > 0), { carried = s.carried, warehouse = s.warehouse, deposited = Lib.state(a).stats.deposited })
st = step()
H.check("tutorial advanced to step 4 (sell)", st == 4, st)

H.section("vehicle sells")
local sold = H.waitUntil(function()
	local x = Lib.snap(a)
	return x and x.cash > 0 and x
end, 120)
H.check("a vehicle sale paid cash", sold ~= nil, sold and { cash = sold.cash, t = H.now() })
st = step()
H.check("tutorial advanced to step 5 (vehicle)", st == 5, st)
r = reveals()
H.check("step 5 HUD: Farm button revealed", r.farm, r)

-- keep the loop going: collect + deposit until fn() is true
local function farmLoop(fn, maxLoops)
	for i = 1, maxLoops or 40 do
		if fn() then
			return true
		end
		a:walkTo(ring.Position)
		H.wait(0.6)
		a:walkTo(dep.Position)
		H.wait(0.6)
		H.wait(8)
	end
	return fn()
end

H.section("upgrade the vehicle through the Farm > Shipping menu")
local farmBtn = Lib.hud(a, "Farm")
local okc = a:click(farmBtn)
H.wait(0.2)
local open = Lib.openPanels(a)
H.check("Farm button opens the Farm panel", okc and #open == 1 and open[1] == "Farm", open)
local farmPanel = Lib.panel(a, "Farm")
local tabs = farmPanel:FindFirstChild("Tabs", true)
local function tabVisibility()
	local tv = {}
	for _, t in { "Housing", "Shipping", "Workers", "Silos" } do
		local b = tabs and tabs:FindFirstChild(t, true)
		tv[t] = b ~= nil and a:isShown(b)
	end
	return tv
end
local tabVis = tabVisibility()
H.check("only the Shipping tab is revealed at step 5", tabVis.Shipping and not tabVis.Housing and not tabVis.Workers and not tabVis.Silos, tabVis)
local btn, lbl = Lib.rowButton(a, "Vehicle 1:", farmPanel)
H.check("Shipping page shows Vehicle 1 row with a purchase button", btn ~= nil, lbl and lbl.Text or lbl)
local Common = a:require("Client.Menus.Common")
local price = Common.Quote("upgradeVehicle", Lib.snap(a), 1)
H.note("vehicle 1 upgrade price", price)
-- close the menu while farming
a:click(farmPanel:FindFirstChild("Close", true))
H.wait(0.2)
H.check("Close button closes the panel", #Lib.openPanels(a) == 0, Lib.openPanels(a))
local enough = farmLoop(function()
	return Lib.snap(a).cash >= price
end, 60)
H.check("earned enough for the vehicle upgrade by farming", enough, { cash = Lib.snap(a).cash, price = price, t = H.now() })
a:click(farmBtn)
H.wait(0.2)
btn = Lib.rowButton(a, "Vehicle 1:", farmPanel)
local n0 = Lib.actionCount()
local clicked, why = a:click(btn)
H.wait(0.5)
local v1 = Lib.state(a).vehicles[1].tier
H.check("tapping the Shipping upgrade button upgrades Vehicle 1 to tier 2", clicked and v1 == 2, { clicked = clicked, why = why, tier = v1, requests = Lib.actionCount() - n0 })
st = step()
H.check("tutorial advanced to step 6 (earn $500)", st == 6, st)
a:click(farmPanel:FindFirstChild("Close", true))
H.wait(0.2)

H.section("earn $500")
local rich = farmLoop(function()
	return Lib.snap(a).cash >= 500
end, 80)
st = step()
H.check("reached $500 and step 7 (housing)", rich and st == 7, { cash = Lib.snap(a).cash, step = st, t = H.now() })
r = reveals()

H.section("upgrade housing through the world board prompt")
local board
for _, d in plot.Boards:GetDescendants() do
	if d:IsA("ProximityPrompt") and d:GetAttribute("Menu") == "Housing" and d:GetAttribute("Slot") == 1 then
		board = d
	end
end
H.check("plot has a Housing board prompt for slot 1", board ~= nil)
a:walkTo(board.Parent.Position)
local trig, twhy = a:triggerPrompt(board)
H.wait(0.3)
open = Lib.openPanels(a)
H.check("triggering the Housing board opens Farm (Housing tab)", trig and #open == 1 and open[1] == "Farm", { triggered = trig, why = twhy, open = open })
local hbtn, hl = Lib.rowButton(a, "House 1", farmPanel)
if not hbtn then
	hbtn, hl = Lib.rowButton(a, "Coop 1", farmPanel)
end
H.check("Housing page shows a House 1 row", hbtn ~= nil, hl and hl.Text or hl)
tabVis = tabVisibility()
H.check("step 7: Housing + Shipping tabs revealed, Workers/Silos hidden", tabVis.Housing and tabVis.Shipping and not tabVis.Workers and not tabVis.Silos, tabVis)
local hprice = Common.Quote("upgradeHouse", Lib.snap(a), 1)
H.note("house 1 upgrade price", hprice)
if Lib.snap(a).cash < hprice then
	a:click(farmPanel:FindFirstChild("Close", true))
	farmLoop(function()
		return Lib.snap(a).cash >= hprice
	end, 80)
	a:click(farmBtn)
	H.wait(0.2)
	-- reopen on Housing
	local ht = farmPanel:FindFirstChild("Tabs", true):FindFirstChild("Housing", true)
	a:click(ht)
	H.wait(0.2)
	hbtn = Lib.rowButton(a, "House 1", farmPanel)
end
local hc, hwhy = a:click(hbtn)
H.wait(0.5)
local done
st, done = step()
H.check("upgrading House 1 finishes the tutorial", hc and done == true, { clicked = hc, why = hwhy, houseTier = Lib.state(a).housing[1].tier, step = st, done = done })
r = reveals()
H.check("finished HUD: navigation + Auto revealed", r.leftNav and r.auto and r.farm and r.counters, r)
local tut = a:playerGui():FindFirstChild("EggFarmTutorial")
H.check("tutorial overlay disabled after finishing", tut ~= nil and tut.Enabled == false)
tabVis = tabVisibility()
H.check("after the tutorial all Farm tabs are revealed", tabVis.Housing and tabVis.Shipping and tabVis.Workers and tabVis.Silos, tabVis)
H.note("time to finish tutorial (simulated seconds)", math.floor(H.now()))
local guiCount = H.countDescendants(a:playerGui())
H.note("PlayerGui instances", guiCount)
