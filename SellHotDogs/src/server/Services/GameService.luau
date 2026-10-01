--!strict
-- Owns the production loop, player actions and state sync. Every action re-validates the
-- request (ownership, range, prerequisites, affordability, rate) and runs without yielding,
-- so repeated or simultaneous requests cannot double-spend or double-grant.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local BigNum = require(Shared.Logic.BigNum)
local Config = require(Shared.Config)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Game = require(Shared.Logic.Game)
local Layout = require(Shared.Layout)
local Names = require(Shared.Logic.Names)
local Net = require(Shared.Net)
local Products = require(Shared.Products)
local Data = require("./Data")
local World = require("./World")

local GameService = {}

local Action = Net.get("Action")
local StateRemote = Net.get("State")
local Notify = Net.get("Notify")

type Handler = (Data.Session, ...any) -> ()
local handlers: { [string]: { fn: Handler, gap: number } } = {}

function GameService.register(name: string, gap: number, fn: Handler)
	handlers[name] = { fn = fn, gap = gap }
end

function GameService.notify(player: Player, kind: string, data: any)
	Notify:FireClient(player, kind, data)
end

function GameService.toast(player: Player, text: string, kind: string?)
	Notify:FireClient(player, "toast", { text = text, kind = kind or "info" })
end

function GameService.markDirty(s: Data.Session)
	s.rt.dirty = true
end

-- range helpers --------------------------------------------------------------

local function rootPos(player: Player): Vector3?
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function nearLot(s: Data.Session, bizId: string): boolean
	local plot = World.plotOf(s.player)
	local pos = rootPos(s.player)
	if not plot or not pos then
		return false
	end
	local lot = Layout.lots[bizId]
	local centre = (plot.origin * CFrame.new(lot.pos)).Position
	return (pos - centre).Magnitude <= Config.InteractRange + lot.size.Magnitude / 2
end

local function nearPad(s: Data.Session, padId: string): boolean
	local plot = World.plotOf(s.player)
	local pos = rootPos(s.player)
	local part = plot and plot.pads[padId]
	if not part or not pos then
		return false
	end
	return (pos - part.Position).Magnitude <= Config.PadRange
end

-- movement power ---------------------------------------------------------------

local function applyWalkSpeed(s: Data.Session)
	local ch = s.player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		local tier = Game.powerTier(s.profile, "runFaster")
		local mult = if tier > 0 then Game.POWERS.runFaster.walkMult[tier] else 1
		hum.WalkSpeed = Config.BaseWalkSpeed * mult
	end
end
GameService.applyWalkSpeed = applyWalkSpeed

-- after any purchase or reset ---------------------------------------------------

local function afterChange(s: Data.Session)
	s.dirty = true
	s.rt.dirty = true
	local plot = World.plotOf(s.player)
	if plot then
		local appeared = World.sync(plot, s.profile, s.profile.name or Names.default(s.player.DisplayName))
		local quiet = not s.rt.synced -- joining: show the plot as it is, no build fanfare
		s.rt.synced = true
		if #appeared > 0 and not quiet then
			GameService.notify(s.player, "built", appeared)
		end
	end
	for _, amount in Game.newMilestones(s.profile) do
		GameService.notify(s.player, "milestone", { kind = "cash", amount = BigNum.new(amount) })
	end
	local skip = Game.flushSkips(s.profile)
	if skip then
		GameService.toast(s.player, "Time skip paid out " .. Format.cash(skip), "cash")
	end
	applyWalkSpeed(s)
end
GameService.afterChange = afterChange

-- snapshot ---------------------------------------------------------------------

local function bigOrNil(b: any): any
	return b
end

function GameService.snapshot(s: Data.Session): any
	local p = s.profile
	local ms = Game.multState(p)
	local biz = {}
	for _, def in Economy.businesses do
		local st = p.biz[def.id]
		local owned = Game.bizOwned(p, def.id)
		local entry: any = { owned = owned }
		if owned then
			local cps = Economy.cyclesPerSecond(ms, def)
			local n1 = Game.levelCost(p, def.id, 1)
			local maxN, maxCost = 0, BigNum.zero
			if table.find(Game.bulkOptions(p), "max") then
				maxN, maxCost = Game.maxAffordable(p, def.id)
			end
			local bulk = {}
			for _, o in Game.bulkOptions(p) do
				if type(o) == "number" and o > 1 then
					bulk[tostring(o)] = Game.levelCost(p, def.id, o)
				end
			end
			entry.level = st.level
			entry.auto = Economy.isAutomated(ms, def)
			entry.running = st.running
			entry.progress = st.progress
			entry.cps = BigNum.toNumber(cps)
			entry.output = Economy.cycleOutput(ms, def, st.level)
			entry.rate = Game.bizRate(p, def.id)
			entry.cost1 = n1
			entry.bulk = bulk
			entry.maxN = maxN
			entry.maxCost = maxCost
			entry.cashMult = Economy.cashMult(ms, def)
			entry.speedMult = Economy.speedMult(ms, def)
		end
		biz[def.id] = entry
	end
	local pads = {}
	for _, pad in Economy.pads do
		local state = 0
		if p.forever[pad.id] then
			state = 3
		elseif p.pads[pad.id] then
			state = 2
		elseif Game.padVisible(p, pad) then
			state = 1
		end
		pads[pad.id] = { s = state, c = if state == 1 then Game.padCost(p, pad) else nil }
	end
	local powers = {}
	for _, pw in Economy.Catalog.powers do
		powers[pw.id] = { tier = Game.powerTier(p, pw.id), bought = p.powers[pw.id] or 0, robux = p.robux.tiers[pw.id] or 0, cost = Game.powerCost(p, pw.id) }
	end
	local owned = {}
	for _, prod in Products.list do
		owned[prod.key] = Game.productOwned(p, prod.key)
	end
	local canAsc, padsOwned, padsTotal = Game.canAscend(p)
	local next = Game.nextPad(p)
	return {
		t = workspace:GetServerTimeNow(),
		cash = p.cash,
		investors = p.investors,
		offered = Game.investorsOffered(p),
		x2 = p.robux.passes.x2investors == true,
		bonusPer = Economy.Catalog.prestige.cashBonusPerInvestor.value,
		rate = Game.incomeRate(p, false),
		autoRate = Game.incomeRate(p, true),
		evo = { n = p.evolutions, recipe = Economy.recipeName(p.evolutions), nextRecipe = Economy.recipeName(p.evolutions + 1), can = not BigNum.lt(p.investors, Economy.evolutionThreshold(p.evolutions)), progress = Game.evolutionProgress(p), need = Economy.evolutionThreshold(p.evolutions), mult = Economy.Catalog.prestige.evolutionSpeedMult.value },
		asc = { n = p.ascensions, can = canAsc, owned = padsOwned, total = padsTotal, cash = Economy.Catalog.prestige.ascensionCashMult.value, price = Economy.Catalog.prestige.ascensionPriceMult.value },
		tokens = p.foreverTokens,
		credits = p.robux.rebirthCredits,
		pendingOffline = p.pendingOffline,
		name = p.name or Names.default(s.player.DisplayName),
		canSave = s.canSave,
		loadError = s.rt.loadError,
		bulk = Game.bulkOptions(p),
		powers = powers,
		owned = owned,
		biz = biz,
		pads = pads,
		nextPad = next and next.id,
		dash = Game.owns(p, "dash:dashgame"),
		decor = p.decor,
		tiers = (function()
			local t = {}
			for _, def in Economy.businesses do
				t[def.id] = if Game.bizOwned(p, def.id) then Game.levelTier(p, def.id) else 0
			end
			return t
		end)(),
		earned = s.rt.earned,
		mock = Config.MockPurchases and game:GetService("RunService"):IsStudio(),
	}
end

local function sync(s: Data.Session)
	StateRemote:FireClient(s.player, GameService.snapshot(s))
	s.rt.earned = nil
	s.rt.dirty = false
end
GameService.sync = sync

-- actions ------------------------------------------------------------------------

local function result(s: Data.Session, ok: boolean, msg: string)
	if ok then
		afterChange(s)
	else
		GameService.toast(s.player, msg, "error")
	end
	sync(s)
end

GameService.register("click", 0.05, function(s, bizId)
	if type(bizId) ~= "string" or not Economy.bizById[bizId] then
		return
	end
	if Game.powerTier(s.profile, "manage") < 1 and not nearLot(s, bizId) then
		return GameService.toast(s.player, "Walk closer, or unlock Manage", "error")
	end
	local ok = Game.click(s.profile, bizId)
	if ok then
		s.rt.dirty = true
		sync(s)
	end
end)

GameService.register("upgrade", 0.05, function(s, bizId, count)
	if type(bizId) ~= "string" or not Economy.bizById[bizId] then
		return
	end
	if not (count == "max" or type(count) == "number") then
		return
	end
	if Game.powerTier(s.profile, "manage") < 1 and not nearLot(s, bizId) then
		return GameService.toast(s.player, "Walk closer, or unlock Manage", "error")
	end
	local tierBefore = Game.levelTier(s.profile, bizId)
	local ok, msg, n = Game.upgradeLevel(s.profile, bizId, count)
	if ok then
		GameService.notify(s.player, "leveled", { bizId = bizId, n = n, level = s.profile.biz[bizId].level })
		if Game.levelTier(s.profile, bizId) > tierBefore then
			GameService.notify(s.player, "milestone", { kind = "level", bizId = bizId, level = s.profile.biz[bizId].level })
		end
	end
	result(s, ok, msg)
end)

local function tryPad(s: Data.Session, padId: string, how: string)
	local pad = Economy.padById[padId]
	if not pad then
		return
	end
	if how == "remote" and Game.powerTier(s.profile, "remoteBuy") < 1 and not nearPad(s, padId) then
		return GameService.toast(s.player, "Step on the circle, or unlock Remote Buy", "error")
	end
	local ok, msg = Game.buyPad(s.profile, padId)
	if ok then
		GameService.notify(s.player, "bought", { padId = padId, name = pad.name, kind = pad.kind, mult = pad.mult, bizId = pad.bizId })
		if pad.kind == "unlock" then
			GameService.notify(s.player, "milestone", { kind = "unlock", name = pad.name })
		end
	end
	result(s, ok, msg)
end

GameService.register("buyPad", 0.1, function(s, padId)
	if type(padId) == "string" then
		tryPad(s, padId, "remote")
	end
end)

GameService.register("buyNext", 0.15, function(s)
	if Game.powerTier(s.profile, "remoteBuy") < 1 then
		return GameService.toast(s.player, "Remote Buy is locked", "error")
	end
	local nextPad = Game.nextPad(s.profile)
	if nextPad then
		tryPad(s, nextPad.id, "remote")
	end
end)

GameService.register("buyDecor", 0.2, function(s, id)
	if type(id) ~= "string" then
		return
	end
	local ok, msg = Game.buyDecor(s.profile, id)
	if ok then
		GameService.notify(s.player, "decor", { id = id, msg = msg })
	end
	result(s, ok, msg)
end)

GameService.register("buyPower", 0.2, function(s, id)
	if type(id) ~= "string" then
		return
	end
	local ok, msg = Game.buyPower(s.profile, id)
	if ok then
		GameService.toast(s.player, msg, "good")
	end
	result(s, ok, msg)
end)

-- Prestige can't run while value from the current run is still in flight.
local function prestigeBlocked(s: Data.Session): boolean
	if s.rt.race then
		GameService.toast(s.player, "Finish your DogDash race first", "error")
		return true
	end
	if s.rt.offer then
		s.rt.offer.state = "expired"
		GameService.notify(s.player, "phone", { offer = s.rt.offer, outcome = "expired" })
		s.rt.offer = nil
	end
	return false
end

GameService.register("rebirth", 1, function(s)
	if prestigeBlocked(s) then
		return
	end
	local ok, msg, award = Game.rebirth(s.profile)
	if ok then
		GameService.notify(s.player, "prestige", { kind = "rebirth", amount = award })
	end
	result(s, ok, msg)
end)

GameService.register("rebirthNoReset", 1, function(s)
	if prestigeBlocked(s) then
		return
	end
	local ok, msg, award = Game.rebirthNoReset(s.profile)
	if ok then
		GameService.notify(s.player, "prestige", { kind = "rebirthNoReset", amount = award })
	end
	result(s, ok, msg)
end)

GameService.register("evolve", 1, function(s)
	if prestigeBlocked(s) then
		return
	end
	local ok, msg = Game.evolve(s.profile)
	if ok then
		GameService.notify(s.player, "prestige", { kind = "evolve", recipe = Economy.recipeName(s.profile.evolutions) })
	end
	result(s, ok, msg)
end)

GameService.register("ascend", 1, function(s)
	if prestigeBlocked(s) then
		return
	end
	local ok, msg = Game.ascend(s.profile)
	if ok then
		GameService.notify(s.player, "prestige", { kind = "ascend", n = s.profile.ascensions })
	end
	result(s, ok, msg)
end)

GameService.register("forever", 0.5, function(s, padId)
	if type(padId) ~= "string" then
		return
	end
	local ok, msg = Game.useForever(s.profile, padId)
	if ok then
		GameService.toast(s.player, msg, "good")
	end
	result(s, ok, msg)
end)

GameService.register("claimOffline", 0.5, function(s)
	local ok, msg, amount = Game.claimOffline(s.profile)
	if ok then
		GameService.notify(s.player, "cash", { amount = amount, source = "offline" })
	end
	result(s, ok, msg)
end)

GameService.register("sync", 0.5, function(s)
	sync(s)
end)

-- incoming ------------------------------------------------------------------------

local lastCall: { [number]: { [string]: number } } = {} -- keyed by UserId
local burst: { [number]: { n: number, t: number } } = {}

Action.OnServerEvent:Connect(function(player: Player, name: any, ...)
	if type(name) ~= "string" then
		return
	end
	local h = handlers[name]
	local s = Data.get(player)
	if not h or not s then
		return
	end
	local now = os.clock()
	-- global burst cap: 40 requests per second per player
	local b: { n: number, t: number } = burst[player.UserId] or { n = 0, t = now }
	if now - b.t >= 1 then
		b = { n = 0, t = now }
	end
	burst[player.UserId] = b
	b.n += 1
	if b.n > 40 then
		return
	end
	local calls = lastCall[player.UserId]
	if not calls then
		calls = {}
		lastCall[player.UserId] = calls
	end
	if now - (calls[name] or 0) < h.gap then
		return
	end
	calls[name] = now
	local ok, err = pcall(h.fn :: any, s, ...)
	if not ok then
		warn("[GameService] action", name, "failed:", err)
	end
end)

-- world callbacks -------------------------------------------------------------------

local touchGap: { [number]: number } = {}
World.onPadTouched = function(player, padId)
	local s = Data.get(player)
	if not s then
		return
	end
	local now = os.clock()
	if now - (touchGap[player.UserId] or 0) < 0.4 then
		return
	end
	touchGap[player.UserId] = now
	local p = s.profile
	local pad = Economy.padById[padId]
	if not pad or Game.owns(p, padId) or not Game.padVisible(p, pad) then
		return
	end
	if BigNum.lt(p.cash, Game.padCost(p, pad)) then
		GameService.toast(player, "Need " .. Format.cash(Game.padCost(p, pad)) .. " for " .. pad.name, "error")
		return
	end
	tryPad(s, padId, "touch")
end

World.onBizPrompt = function(player, bizId)
	local h = handlers.click
	local s = Data.get(player)
	if s then
		h.fn(s, bizId)
	end
end

World.onExtraPrompt = function(player, action)
	GameService.notify(player, "open", action)
end

-- lifecycle ---------------------------------------------------------------------------

local function spawnAtPlot(player: Player, character: Model)
	local plot = World.plotOf(player)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if plot and root then
		task.wait()
		character:PivotTo(plot.origin * CFrame.new(Layout.spawn) * CFrame.Angles(0, math.pi, 0))
	end
	local s = Data.get(player)
	if s then
		applyWalkSpeed(s)
	end
end

local onLoaded: { (Data.Session) -> () } = {}
function GameService.onSessionLoaded(fn: (Data.Session) -> ())
	table.insert(onLoaded, fn)
end

function GameService.init()
	Data.Loaded:Connect(function(s: Data.Session)
		local plot = World.assign(s.player)
		if not plot then
			s.player:Kick("This server is full. Please try another server!")
			return
		end
		afterChange(s)
		sync(s)
		if s.offlineFound and BigNum.toNumber(s.profile.pendingOffline) > 0 then
			GameService.notify(s.player, "offline", { amount = s.profile.pendingOffline, seconds = nil })
		end
		if s.rt.loadError then
			GameService.notify(s.player, "loadError", s.rt.loadError)
		end
		if s.player.Character then
			task.spawn(spawnAtPlot, s.player, s.player.Character)
		end
		for _, fn in onLoaded do
			task.spawn(fn, s)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(ch)
			spawnAtPlot(player, ch)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(ch)
			spawnAtPlot(player, ch)
		end)
	end
	Data.onLeaving(function(s: Data.Session)
		World.release(s.player)
		lastCall[s.player.UserId] = nil
		burst[s.player.UserId] = nil
		touchGap[s.player.UserId] = nil
	end)

	-- production loop: fixed steps, aggregated grants, snapshots at SyncSeconds
	task.spawn(function()
		local acc, syncAcc = 0, 0
		local last = os.clock()
		while true do
			task.wait(Config.StepSeconds)
			local now = os.clock()
			local dt = math.min(now - last, 1)
			last = now
			acc += dt
			syncAcc += dt
			for _, s in Data.sessions do
				if not World.plotOf(s.player) then
					continue
				end
				local grants = Game.step(s.profile, dt)
				if #grants > 0 then
					s.dirty = true
					s.rt.dirty = true
					local earned = s.rt.earned or {}
					for _, g in grants do
						local e = earned[g.bizId]
						if e then
							e.amount = BigNum.add(e.amount, g.amount)
							e.cycles += math.max(g.cycles, 0)
						else
							earned[g.bizId] = { amount = g.amount, cycles = math.max(g.cycles, 0) }
						end
					end
					s.rt.earned = earned
					if s.rt.prevCanSee == nil or s.rt.prevPadsTick ~= nil then
						-- pads become affordable as cash grows; plot visuals don't depend on cash
					end
				end
			end
			if syncAcc >= Config.SyncSeconds then
				syncAcc = 0
				for _, s in Data.sessions do
					for _, amount in Game.newMilestones(s.profile) do
						GameService.notify(s.player, "milestone", { kind = "cash", amount = BigNum.new(amount) })
					end
				end
				for _, s in Data.sessions do
					if s.rt.dirty and World.plotOf(s.player) then
						sync(s)
					end
				end
			end
		end
	end)
end

GameService.handlers = handlers
GameService._bigOrNil = bigOrNil
return GameService
