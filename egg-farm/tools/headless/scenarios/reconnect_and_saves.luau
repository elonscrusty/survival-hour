-- (e) Leave + rejoin on the same server restores the memory save; a failed load kicks without
-- touching the save; a failed final save is retried.
H.boot()
local USER = 4242
local a = H.join("Alice", { userId = USER })
Lib.waitSnap(a)
local Data = H.serverRequire("ServerScriptService.Server.Services.DataService")
local adapter = Data.Adapter()
local store = adapter.store
local KEY = "Player_" .. USER

local function key(s)
	local h, v = {}, {}
	for i, x in s.housing do
		h[i] = x.tier
	end
	for i, x in s.vehicles do
		v[i] = x.tier
	end
	return H.json({ cash = math.floor(s.cash), gold = s.gold, egg = s.egg, pop = s.population, houses = h, vehicles = v, codes = s.codes, tut = s.tutorial.done, common = s.common })
end

H.section("leave and rejoin restores the save")
Lib.dev(a, "tutorial")
Lib.dev(a, "cash")
Lib.dev(a, "gold")
for _, act in { { type = "upgradeHouse", slot = 1 }, { type = "buyHouse", slot = 2 }, { type = "upgradeVehicle", slot = 1 }, { type = "redeemCode", text = "EGGFARM" } } do
	Lib.request(a, act)
end
for i = 1, 10 do
	Lib.request(a, { type = "spawn" })
end
H.wait(1)
local k1 = key(Lib.state(a))
local saves0 = store.saves
H.leave(a)
H.wait(1)
local peek = store:Peek(KEY)
H.check("leaving saved the farm to the memory store and released the lock", peek ~= nil and store.saves > saves0 and store.records[KEY].lock == nil, { saves = store.saves - saves0, lock = store.records[KEY].lock })
local plotFree = true
for _, p in workspace.Plots:GetChildren() do
	if p:GetAttribute("OwnerUserId") == USER then
		plotFree = false
	end
end
H.check("the plot was released", plotFree)
local a2 = H.join("Alice", { userId = USER })
Lib.waitSnap(a2)
local k2 = key(Lib.state(a2))
H.check("rejoin restores the same farm", k1 == k2, if k1 == k2 then k2 else { before = k1, after = k2 })
H.check("rejoined client got a snapshot with the restored cash", math.floor(Lib.snap(a2).cash) == math.floor(Lib.state(a2).cash), Lib.snap(a2).cash)
local again = Lib.request(a2, { type = "redeemCode", text = "EGGFARM" })
H.check("redeemed code stays redeemed after rejoin", again.code == "code_used", again)
local plot2 = Lib.plotOf(a2)
H.check("rejoined player owns a plot whose world matches the save", plot2 ~= nil and plot2:GetAttribute("HouseTiers") == "2,1,0,0", plot2 and plot2:GetAttribute("HouseTiers"))

H.section("failed load: kicked, save untouched")
local beforeFail = H.json(store:Peek(KEY))
Lib.dev(a2, "failload")
H.leave(a2)
H.wait(1)
local afterLeave = H.json(store:Peek(KEY))
local kicks0 = #H.M.kicks
local a3 = H.join("Alice", { userId = USER })
H.wait(2)
local kick = H.M.kicks[#H.M.kicks]
H.check("rejoin with a failing load is kicked with the friendly message", #H.M.kicks == kicks0 + 1 and kick.userId == USER, kick and kick.msg)
H.check("kicked player is gone and owns no plot", a3.player.Parent == nil and (function()
	for _, p in workspace.Plots:GetChildren() do
		if p:GetAttribute("OwnerUserId") == USER then
			return false
		end
	end
	return true
end)())
H.check("save data intact after the failed load", H.json(store:Peek(KEY)) == afterLeave, "unchanged")
local a4 = H.join("Alice", { userId = USER })
Lib.waitSnap(a4)
H.check("next rejoin loads normally with the same farm", key(Lib.state(a4)) == k2, key(Lib.state(a4)))

H.section("failed final save is retried")
Lib.request(a4, { type = "upgradeHouse", slot = 2 })
H.wait(0.5)
local k5 = key(Lib.state(a4))
Lib.dev(a4, "failsave")
local warns0 = #H.M.warnings
H.leave(a4)
H.wait(1)
local newWarn = {}
for i = warns0 + 1, #H.M.warnings do
	table.insert(newWarn, H.M.warnings[i].msg)
end
local rec = store.records[KEY]
H.check("one failed save on leave: the retry saves the latest farm", key(store:Peek(KEY)) == k5 and rec.lock == nil, { saved = key(store:Peek(KEY)), expected = k5, lock = rec.lock, warnings = newWarn })
local a5 = H.join("Alice", { userId = USER })
Lib.waitSnap(a5)
H.check("rejoin after the retried save has the latest farm", key(Lib.state(a5)) == k5, key(Lib.state(a5)))


H.section("three failed saves in a row: gives up but unlocks (last good copy kept)")
Lib.request(a5, { type = "upgradeHouse", slot = 2 })
H.wait(0.5)
Lib.dev(a5, "failsave")
Lib.dev(a5, "failsave")
Lib.dev(a5, "failsave")
Lib.dev(a5, "failsave")
H.leave(a5)
H.wait(1)
rec = store.records[KEY]
H.check("after exhausting retries the lock is released and the previous copy is intact", rec.lock == nil and key(store:Peek(KEY)) == k5, { lock = rec.lock, saved = key(store:Peek(KEY)) })
store.failSaves = 0
local a6 = H.join("Alice", { userId = USER })
Lib.waitSnap(a6)
H.check("player can rejoin right away (no stale lock)", a6.player.Parent ~= nil and Lib.state(a6) ~= nil)
