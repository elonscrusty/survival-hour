-- (d) Late-game fixtures, REBIRTH through the client's Eggs menu (confirm modal), reset/kept
-- fields, world models swapped and recoloured, and no leaked instances over repeated cycles.
H.boot()
local a = H.join("Alice")
Lib.waitSnap(a)
local plot, idx = Lib.plotOf(a)
local State = H.serverRequire("ReplicatedStorage.Shared.Logic.State")
local Eggs = H.serverRequire("ReplicatedStorage.Shared.Data.Eggs")

local function partsIn(root)
	return H.countDescendants(root, function(d)
		return d:IsA("BasePart")
	end)
end
local function colorHistogram(root)
	local h = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local k = d.Color:ToHex()
			h[k] = (h[k] or 0) + 1
		end
	end
	return h
end
local function houseModel(slot)
	local houses = plot:FindFirstChild("Houses")
	local hm = houses and houses:FindFirstChild("House" .. slot)
	return hm
end
local function houseParts(slot)
	local hm = houseModel(slot)
	return hm and partsIn(hm) or 0
end

H.section("upgrades change the world models")
Lib.dev(a, "tutorial")
Lib.dev(a, "cash")
H.wait(1)
local p0 = partsIn(plot)
local h1 = houseParts(1)
local h1Part = (function()
	for _, d in houseModel(1):GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "CollectRing" and d.Name ~= "Anchor" then
			return d
		end
	end
end)()
for _, act in { { type = "upgradeHouse", slot = 1 }, { type = "upgradeHouse", slot = 1 }, { type = "buyHouse", slot = 2 }, { type = "buyVehicle", slot = 2 }, { type = "buildSilo" } } do
	local r = Lib.request(a, act)
	H.wait(0.2)
end
H.wait(8)
local s = Lib.state(a)
H.check("plot attributes follow the farm", plot:GetAttribute("HouseTiers") == string.format("%d,%d,%d,%d", s.housing[1].tier, s.housing[2].tier, s.housing[3].tier, s.housing[4].tier), { HouseTiers = plot:GetAttribute("HouseTiers"), VehicleTiers = plot:GetAttribute("VehicleTiers"), Silos = plot:GetAttribute("Silos") })
H.check("House1 model was rebuilt for the new tier", h1Part.Parent == nil or houseParts(1) ~= h1, { partsBefore = h1, partsAfter = houseParts(1), tier = s.housing[1].tier })
H.check("House2 model exists after buying slot 2", houseParts(2) > 2, houseParts(2))
H.note("plot BasePart count: fresh -> upgraded", { fresh = p0, upgraded = partsIn(plot) })

H.section("REBIRTH through the Eggs menu")
Lib.dev(a, "egg", 1)
Lib.request(a, { type = "buyCommon", id = "spawnPerTap" })
Lib.request(a, { type = "useBoost", id = "x" })
H.wait(1)
local before = Lib.state(a)
local snapshotBefore = {}
for _, k in State.KEPT_FIELDS do
	snapshotBefore[k] = H.json(before[k])
end
local goldBefore, egg0 = before.gold, before.egg
local themeColors0 = colorHistogram(plot)
H.check("fixture: egg 1 with Farm Value at the goal", Lib.snap(a).canRebirth == true, { egg = before.egg, cash = before.cash, requirement = Eggs.List[1].requirement })
a:click(Lib.hud(a, "Eggs"))
H.wait(0.3)
local eggsPanel = Lib.panel(a, "Eggs")
local rb
for _, d in eggsPanel:GetDescendants() do
	if d:IsA("TextButton") and d.Name == "Button" and a:isShown(d) then
		local l = d:FindFirstChild("Label")
		if l and l.Text == "REBIRTH" then
			rb = d
		end
	end
end
H.check("Eggs panel shows an enabled REBIRTH button", rb ~= nil)
local n0 = Lib.actionCount()
a:click(rb)
H.wait(0.3)
local modal = a:playerGui():FindFirstChild("EggFarmModal")
local modalTexts = {}
local yes
for _, d in modal:GetDescendants() do
	if d:IsA("TextLabel") and a:isShown(d) and d.Text ~= "" then
		table.insert(modalTexts, d.Text)
	end
	if d:IsA("TextButton") and a:isShown(d) then
		local l = d:FindFirstChild("Label")
		if l and l.Text == "Rebirth" then
			yes = d
		end
	end
end
H.check("rebirth asks for confirmation listing resets/keeps (no request yet)", yes ~= nil and Lib.actionCount() == n0, { lines = #modalTexts, sample = { modalTexts[1], modalTexts[2] } })
a:click(yes)
H.wait(1)
local after = Lib.state(a)
H.check("rebirth moved to egg 2 with one request", after.egg == egg0 + 1 and Lib.actionCount() - n0 == 1, { egg = after.egg, requests = Lib.actionCount() - n0 })
H.check("panel closed after a successful rebirth", #Lib.openPanels(a) == 0, Lib.openPanels(a))
local resetOk, resetBad = true, {}
local fresh = State.New(0)
for _, k in State.RESET_FIELDS do
	local want = H.json(fresh[k])
	local got = H.json(after[k])
	if want ~= got then
		resetOk = false
		resetBad[k] = got
	end
end
H.check("every RESET field is back to a fresh farm", resetOk, if resetOk then State.RESET_FIELDS else resetBad)
local keptBad = {}
for _, k in State.KEPT_FIELDS do
	if k ~= "gold" and k ~= "egg" and k ~= "rebirths" and k ~= "lastSeen" and k ~= "stats" and k ~= "quests" and k ~= "gifts" then
		if H.json(after[k]) ~= snapshotBefore[k] then
			keptBad[k] = { before = snapshotBefore[k], after = H.json(after[k]) }
		end
	end
end
local cnt = 0
for _ in keptBad do
	cnt += 1
end
H.check("KEPT fields unchanged (epic, boosts, codes, settings, tutorial, passes, receipts, ...)", cnt == 0, if cnt == 0 then "all kept" else keptBad)
H.check("rebirth granted Gold Eggs", after.gold == goldBefore + Eggs.List[2].rebirthGold, { before = goldBefore, after = after.gold, expected = Eggs.List[2].rebirthGold })
H.wait(6)
H.check("plot Egg attribute and world rebuilt for egg 2", plot:GetAttribute("Egg") == 2 and plot:GetAttribute("HouseTiers") == "1,0,0,0", { Egg = plot:GetAttribute("Egg"), HouseTiers = plot:GetAttribute("HouseTiers") })
local themeColors1 = colorHistogram(plot)
local changed = 0
for k, n in themeColors1 do
	if not themeColors0[k] then
		changed += n
	end
end
H.check("theme recoloured the plot (parts with new colours)", changed > 20, { partsWithNewColours = changed })

H.section("no leaked instances over repeated upgrade + rebirth cycles")
local counts = {}
local clientCounts = {}
local function clientVisuals()
	return a:run(function()
		local fv = workspace:FindFirstChild("FarmVisuals")
		return fv and #fv:GetDescendants() or -1
	end)
end
for cycle = 1, 4 do
	Lib.dev(a, "egg", 2)
	Lib.dev(a, "maxed")
	H.wait(8)
	local maxed = H.countDescendants(plot)
	Lib.request(a, { type = "rebirth", expect = 2 })
	H.wait(8)
	local freshN = H.countDescendants(plot)
	table.insert(counts, { maxed = maxed, fresh = freshN, egg = Lib.state(a).egg })
	table.insert(clientCounts, clientVisuals())
end
local stable = true
for i = 2, #counts do
	if counts[i].maxed ~= counts[1].maxed or counts[i].fresh ~= counts[1].fresh then
		stable = false
	end
end
H.check("plot descendant counts identical every cycle (egg2 maxed / egg3 fresh)", stable, counts)
H.check("client FarmVisuals descendants stable across cycles", clientCounts[2] == clientCounts[#clientCounts], clientCounts)
local ws = H.countDescendants(workspace)
H.note("workspace descendants after cycles", ws)
H.emitFile("tools/headless/out/progression_counts.json", H.json({ cycles = counts, client = clientCounts }))
