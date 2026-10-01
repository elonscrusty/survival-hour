-- Headless Roblox mock, part 3: DataModel, services, players/characters, remotes (simulated
-- network with latency and serialization copy), prompts, marketplace stub, input stubs.

local V = M.Vector3.new
local CFrame = M.CFrame
local Vector2 = M.Vector2
local Enum = M.Enum
local typeof = M.typeof
local Signal = M.Signal
local SignalApi = M.SignalApi
local cur = M.cur
local Classes = M.Classes
local def = M.defClass
local isInst = M.isInst
local isA = M.isA
local canSee = M.canSee
local getSignal = M.getSignal
local newInstance = M.newInstance

------------------------------------------------------------------------------------------ DataModel
def("DataModel", "Instance", { JobId = "headless-job-1", PlaceId = 0, GameId = 0, PlaceVersion = 0, CreatorId = 0, CreatorType = Enum.CreatorType.User, PrivateServerId = "", PrivateServerOwnerId = 0 }, {
	events = { "Loaded", "Close" },
})
local game = newInstance("DataModel", nil)
rawget(game, "_p").Name = "Game"
M.game = game
M.bindToClose = {}
local services = {}
M.services = services

local GM = Classes.DataModel.methods
function GM.GetService(g, name)
	local s = services[name]
	if s then
		return s
	end
	if not Classes[name] or not Classes[name].service then
		error("'" .. tostring(name) .. "' is not a valid Service name", 2)
	end
	s = newInstance(name, nil)
	rawget(s, "_p").Name = name
	rawset(s, "_isService", true)
	services[name] = s
	M.setParent(s, game)
	if M.serviceInit[name] then
		M.serviceInit[name](s)
	end
	return s
end
function GM.FindService(g, name)
	return services[name]
end
function GM.BindToClose(g, fn)
	table.insert(M.bindToClose, { fn = fn, ctx = cur() })
end
function GM.IsLoaded()
	return true
end
Classes.DataModel.getters.Workspace = function()
	return GM.GetService(game, "Workspace")
end
M.serviceInit = {}

------------------------------------------------------------------------------------------ Workspace
M.serviceInit.Workspace = function(ws)
	local terrain = newInstance("Terrain", nil)
	rawget(terrain, "_p").Name = "Terrain"
	M.setParent(terrain, ws)
	rawget(ws, "_p").Terrain = terrain
	local cam = newInstance("Camera", nil)
	rawget(cam, "_p").Name = "Camera"
	M.setParent(cam, ws)
	M.serverCamera = cam
end
local WS = Classes.Workspace
WS.getters.CurrentCamera = function(ws)
	local ctx = cur()
	if ctx.kind == "client" then
		return ctx.camera
	end
	return M.serverCamera
end
WS.setters.CurrentCamera = function() end
function WS.methods.GetServerTimeNow()
	return M.serverNow()
end
function WS.methods.GetRealPhysicsFPS()
	return 60
end
M.bulkMoved = 0
function WS.methods.BulkMoveTo(ws, parts, cfs, mode)
	if #parts ~= #cfs then
		error("BulkMoveTo: partList and cframeList must have the same length", 2)
	end
	for i, p in parts do
		if not isInst(p) or not isA(p, "BasePart") then
			error("BulkMoveTo: element " .. i .. " is not a BasePart", 2)
		end
		M.rawSet(p, "CFrame", cfs[i], false)
	end
	M.bulkMoved += #parts
end
function WS.methods.Raycast()
	return nil
end
WS.methods.Blockcast = WS.methods.Raycast
WS.methods.Spherecast = WS.methods.Raycast
WS.methods.Shapecast = WS.methods.Raycast
function WS.methods.GetPartBoundsInBox()
	return {}
end
WS.methods.GetPartBoundsInRadius = WS.methods.GetPartBoundsInBox
WS.methods.GetPartsInPart = WS.methods.GetPartBoundsInBox
function WS.methods.FindPartOnRay()
	return nil, V(0, 0, 0), V(0, 1, 0)
end
WS.methods.FindPartOnRayWithIgnoreList = WS.methods.FindPartOnRay
WS.methods.FindPartOnRayWithWhitelist = WS.methods.FindPartOnRay

------------------------------------------------------------------------------------------ RunService
M.serviceInit.RunService = function(rs)
	for _, n in { "Heartbeat", "Stepped", "RenderStepped", "PreRender", "PreSimulation", "PostSimulation", "PreAnimation" } do
		getSignal(rs, n)
	end
end
Classes.RunService.eventSet = { Heartbeat = true, Stepped = true, RenderStepped = true, PreRender = true, PreSimulation = true, PostSimulation = true, PreAnimation = true }
local RSM = Classes.RunService.methods
function RSM.IsServer()
	return cur().kind ~= "client"
end
function RSM.IsClient()
	return cur().kind == "client"
end
function RSM.IsStudio()
	return false
end
function RSM.IsRunning()
	return true
end
function RSM.IsRunMode()
	return false
end
function RSM.IsEdit()
	return false
end
M.renderSteps = {}
function RSM.BindToRenderStep(rs, name, prio, fn)
	table.insert(M.renderSteps, { name = name, prio = prio, fn = fn, ctx = cur() })
end
function RSM.UnbindFromRenderStep(rs, name)
	local ctx = cur()
	for i = #M.renderSteps, 1, -1 do
		if M.renderSteps[i].name == name and M.renderSteps[i].ctx == ctx then
			table.remove(M.renderSteps, i)
		end
	end
end

-- per-frame engine events
M.onFrame = function(dt)
	local rs = services.RunService
	if not rs then
		return
	end
	local clientOnly = function(ctx)
		return ctx.kind == "client"
	end
	for _, r in table.clone(M.renderSteps) do
		if not r.ctx.dead then
			M.spawnIn(r.ctx, r.fn, dt)
		end
	end
	SignalApi.FireFor(getSignal(rs, "RenderStepped"), clientOnly, dt)
	SignalApi.FireFor(getSignal(rs, "PreRender"), clientOnly, dt)
	SignalApi.Fire(getSignal(rs, "Stepped"), M.clock, dt)
	SignalApi.Fire(getSignal(rs, "PreSimulation"), dt)
	SignalApi.Fire(getSignal(rs, "PostSimulation"), dt)
	SignalApi.Fire(getSignal(rs, "Heartbeat"), dt)
end

------------------------------------------------------------------------------------------ TweenService (instant)
local TweenMt = {}
M.TYPE[TweenMt] = "Instance"
M.tweens = 0
function Classes.TweenService.methods.Create(ts, inst, info, goal)
	if not isInst(inst) then
		error("TweenService:Create: Instance expected", 2)
	end
	for k, v in goal do
		-- validate now (Roblox errors at Create for bad properties)
		local _ = inst[k]
	end
	local completed = Signal("Completed")
	local tw = {
		Instance = inst,
		TweenInfo = info,
		PlaybackState = Enum.PlaybackState.Begin,
		Completed = completed,
	}
	function tw.Play(self)
		M.tweens += 1
		if rawget(inst, "_destroyed") then
			return
		end
		for k, v in goal do
			inst[k] = v
		end
		self.PlaybackState = Enum.PlaybackState.Completed
		SignalApi.Fire(completed, Enum.PlaybackState.Completed)
	end
	function tw.Cancel(self)
		self.PlaybackState = Enum.PlaybackState.Cancelled
	end
	function tw.Pause(self)
		self.PlaybackState = Enum.PlaybackState.Paused
	end
	function tw.Destroy(self) end
	return tw
end
function Classes.TweenService.methods.GetValue(ts, alpha)
	return alpha
end

------------------------------------------------------------------------------------------ Debris
function Classes.Debris.methods.AddItem(d, inst, t)
	M.task.delay(t or 10, function()
		if not rawget(inst, "_destroyed") then
			inst:Destroy()
		end
	end)
end

------------------------------------------------------------------------------------------ CollectionService
function Classes.CollectionService.methods.GetTagged(cs, tag)
	local out = {}
	for inst in M.tags[tag] or {} do
		if canSee(cur(), inst) then
			table.insert(out, inst)
		end
	end
	return out
end
function Classes.CollectionService.methods.AddTag(cs, inst, tag)
	inst:AddTag(tag)
end
function Classes.CollectionService.methods.RemoveTag(cs, inst, tag)
	inst:RemoveTag(tag)
end
function Classes.CollectionService.methods.HasTag(cs, inst, tag)
	return inst:HasTag(tag)
end
function Classes.CollectionService.methods.GetInstanceAddedSignal(cs, tag)
	return Signal("InstanceAdded:" .. tag)
end
Classes.CollectionService.methods.GetInstanceRemovedSignal = Classes.CollectionService.methods.GetInstanceAddedSignal

------------------------------------------------------------------------------------------ misc services
function Classes.TextService.methods.GetTextSize(ts, text, size, font, frame)
	return Vector2.new(#tostring(text) * size * 0.55, size)
end
function Classes.HttpService.methods.GenerateGUID()
	M.guidN = (M.guidN or 0) + 1
	return string.format("{00000000-0000-0000-0000-%012d}", M.guidN)
end
function Classes.HttpService.methods.JSONEncode(hs, v)
	return M.json(v)
end
function Classes.DataStoreService.methods.GetDataStore()
	error("DataStoreService is not available in the headless mock (the test place uses memory saves)", 2)
end
Classes.DataStoreService.methods.GetGlobalDataStore = Classes.DataStoreService.methods.GetDataStore
Classes.DataStoreService.methods.GetOrderedDataStore = Classes.DataStoreService.methods.GetDataStore
function Classes.PolicyService.methods.GetPolicyInfoForPlayerAsync()
	return { ArePaidRandomItemsRestricted = false, AllowedExternalLinkReferences = {}, IsPaidItemTradingAllowed = true, IsSubjectToChinaPolicies = false }
end
function Classes.LocalizationService.methods.GetCountryRegionForPlayerAsync()
	return "US"
end
function Classes.BadgeService.methods.AwardBadge()
	return false
end
function Classes.BadgeService.methods.UserHasBadgeAsync()
	return false
end
function Classes.ContentProvider.methods.PreloadAsync() end
function Classes.SoundService.methods.PlayLocalSound(ss, sound)
	M.stats.localSounds = (M.stats.localSounds or 0) + 1
end
function Classes.GroupService.methods.GetGroupsAsync()
	return {}
end
function Classes.SocialService.methods.CanSendGameInviteAsync()
	return false
end
function Classes.SocialService.methods.PromptGameInvite() end

------------------------------------------------------------------------------------------ MarketplaceService (records, never buys)
M.marketPrompts = {}
local MS = Classes.MarketplaceService
MS.eventSet = { PromptGamePassPurchaseFinished = true, PromptProductPurchaseFinished = true, PromptPurchaseFinished = true, PromptBundlePurchaseFinished = true, PromptPremiumPurchaseFinished = true }
M.KNOWN.ProcessReceipt = true
local function recordPrompt(kind)
	return function(ms, player, id)
		table.insert(M.marketPrompts, { kind = kind, player = player and player.Name, id = id, ctx = cur().name, t = M.clock })
	end
end
MS.methods.PromptProductPurchase = recordPrompt("product")
MS.methods.PromptGamePassPurchase = recordPrompt("gamepass")
MS.methods.PromptPurchase = recordPrompt("asset")
MS.methods.PromptPremiumPurchase = recordPrompt("premium")
MS.methods.PromptSubscriptionPurchase = recordPrompt("subscription")
function MS.methods.UserOwnsGamePassAsync()
	return false
end
function MS.methods.PlayerOwnsAsset()
	return false
end
function MS.methods.GetProductInfo(ms, id)
	return { Name = "Product " .. tostring(id), PriceInRobux = 0, IsForSale = false }
end

------------------------------------------------------------------------------------------ input-ish services (per context state)
local UIS = Classes.UserInputService
UIS.eventSet = { InputBegan = true, InputEnded = true, InputChanged = true, LastInputTypeChanged = true, TouchStarted = true, TouchEnded = true, TouchTap = true, WindowFocused = true, WindowFocusReleased = true, JumpRequest = true, TextBoxFocused = true, TextBoxFocusReleased = true, GamepadConnected = true, GamepadDisconnected = true }
local function ctxFlag(name, default)
	return function()
		local ctx = cur()
		local o = ctx.opts or {}
		if o[name] ~= nil then
			return o[name]
		end
		return default
	end
end
UIS.getters.TouchEnabled = ctxFlag("touch", false)
UIS.getters.KeyboardEnabled = function()
	return not ctxFlag("touch", false)()
end
UIS.getters.MouseEnabled = UIS.getters.KeyboardEnabled
UIS.getters.GamepadEnabled = function()
	return false
end
UIS.getters.AccelerometerEnabled = function()
	return false
end
UIS.getters.GyroscopeEnabled = UIS.getters.AccelerometerEnabled
UIS.getters.VREnabled = UIS.getters.AccelerometerEnabled
UIS.getters.PreferredInput = function()
	return if ctxFlag("touch", false)() then Enum.PreferredInput.Touch else Enum.PreferredInput.KeyboardAndMouse
end
for _, k in { "TouchEnabled", "KeyboardEnabled", "MouseEnabled", "GamepadEnabled", "AccelerometerEnabled", "GyroscopeEnabled", "VREnabled", "PreferredInput", "MouseBehavior", "MouseIconEnabled", "MouseDeltaSensitivity", "ModalEnabled", "OverrideMouseIconBehavior" } do
	M.KNOWN[k] = true
end
function UIS.methods.GetLastInputType()
	return if ctxFlag("touch", false)() then Enum.UserInputType.Touch else Enum.UserInputType.MouseButton1
end
function UIS.methods.GetFocusedTextBox()
	return nil
end
function UIS.methods.IsKeyDown()
	return false
end
function UIS.methods.GetMouseLocation()
	return Vector2.new(0, 0)
end
function UIS.methods.GetConnectedGamepads()
	return {}
end
function UIS.methods.GetKeysPressed()
	return {}
end
function UIS.methods.GetStringForKeyCode(uis, k)
	return tostring(k.Name)
end
function UIS.methods.GetImageForKeyCode()
	return ""
end

local GS = Classes.GuiService
GS.eventSet = { MenuOpened = true, MenuClosed = true }
GS.getters.MenuIsOpen = function()
	return false
end
GS.getters.TopbarInset = function()
	local ctx = cur()
	local vp = ctx.camera and ctx.camera.ViewportSize or Vector2.new(1280, 720)
	return M.globals.Rect.new(0, 0, vp.X, 58)
end
M.KNOWN.MenuIsOpen = true
M.KNOWN.TopbarInset = true
M.KNOWN.SelectedObject = true
M.KNOWN.AutoSelectGuiEnabled = true
M.KNOWN.GuiNavigationEnabled = true
M.KNOWN.TouchControlsEnabled = true
function GS.methods.GetGuiInset()
	return Vector2.new(0, 58), Vector2.new(0, 0)
end
function GS.methods.IsTenFootInterface()
	return false
end
function GS.methods.OpenBrowserWindow() end

-- ContextActionService: bindings per context; the harness presses keys through M.pressKey
local CAS = Classes.ContextActionService
M.actions = {}
function CAS.methods.BindAction(cas, name, fn, touchButton, ...)
	local ctx = cur()
	M.actions[ctx] = M.actions[ctx] or {}
	M.actions[ctx][name] = { fn = fn, keys = { ... }, prio = 0 }
end
function CAS.methods.BindActionAtPriority(cas, name, fn, touchButton, prio, ...)
	local ctx = cur()
	M.actions[ctx] = M.actions[ctx] or {}
	M.actions[ctx][name] = { fn = fn, keys = { ... }, prio = prio }
end
function CAS.methods.UnbindAction(cas, name)
	local ctx = cur()
	if M.actions[ctx] then
		M.actions[ctx][name] = nil
	end
end
function CAS.methods.UnbindAllActions()
	M.actions[cur()] = {}
end
function CAS.methods.GetButton()
	return nil
end
function CAS.methods.SetTitle() end
function CAS.methods.SetImage() end
function CAS.methods.SetPosition() end
function CAS.methods.SetDescription() end

------------------------------------------------------------------------------------------ ProximityPromptService
local PPS = Classes.ProximityPromptService
PPS.eventSet = { PromptTriggered = true, PromptTriggerEnded = true, PromptShown = true, PromptHidden = true, PromptButtonHoldBegan = true, PromptButtonHoldEnded = true }

------------------------------------------------------------------------------------------ network
M.latency = 0.03 -- one-way seconds
M.netSeq = 0
M.netStats = {} -- remote name -> { messages, bytes }
M.netWarnings = {}
M.trackNet = true

local function netWarn(msg)
	if not M.netWarnings[msg] then
		M.netWarnings[msg] = 0
	end
	M.netWarnings[msg] += 1
end

-- Copies a value the way the Roblox network would (tables are copied, metatables dropped,
-- functions become nil, Instances pass by reference if the receiver can see them). Flags mixed
-- and sparse tables, which Roblox mangles.
local function netCopy(v, receiver, path, depth)
	local t = type(v)
	if t == "function" then
		netWarn("function value dropped at " .. path)
		return nil
	elseif t == "thread" then
		netWarn("thread dropped at " .. path)
		return nil
	elseif t == "number" then
		if v ~= v then
			netWarn("NaN sent at " .. path)
		end
		return v
	elseif t ~= "table" then
		return v
	end
	if isInst(v) then
		if receiver and not canSee(receiver, v) then
			netWarn("instance not replicated to receiver at " .. path)
			return nil
		end
		return v
	end
	local mt = getmetatable(v)
	if mt and M.TYPE[mt] then
		return v -- immutable datatype
	end
	if depth > 30 then
		netWarn("table nesting too deep at " .. path)
		return nil
	end
	local out = {}
	local nNum, nStr, maxN = 0, 0, 0
	for k, x in v do
		local kt = type(k)
		if kt == "number" then
			nNum += 1
			if k > maxN then
				maxN = k
			end
		elseif kt == "string" then
			nStr += 1
		else
			netWarn("non string/number key dropped at " .. path)
			continue
		end
		out[k] = netCopy(x, receiver, path .. "." .. tostring(k), depth + 1)
	end
	if nNum > 0 and nStr > 0 then
		netWarn("mixed table (number+string keys) at " .. path)
	elseif nNum > 0 and maxN ~= nNum then
		netWarn("sparse array (holes) at " .. path)
	end
	return out
end
M.netCopy = netCopy

local function packCopy(receiver, name, ...)
	local n = select("#", ...)
	local args = { ... }
	local out = { n = n }
	for i = 1, n do
		out[i] = netCopy(args[i], receiver, name .. "#" .. i, 0)
	end
	if M.trackNet then
		local st = M.netStats[name]
		if not st then
			st = { messages = 0, bytes = 0, maxBytes = 0 }
			M.netStats[name] = st
		end
		local bytes = #M.json(table.move(out, 1, n, 1, {}))
		st.messages += 1
		st.bytes += bytes
		if bytes > st.maxBytes then
			st.maxBytes = bytes
		end
	end
	return out
end

local function enqueue(fn)
	M.netSeq += 1
	table.insert(M.netQueue, { at = M.clock + M.latency, seq = M.netSeq, fn = fn })
end
M.enqueue = enqueue

local function ctxForPlayer(player)
	return rawget(player, "_ctx")
end

-- remote events queue until a listener connects in the receiving context (Roblox behaviour)
local pendingEvents = setmetatable({}, { __mode = "k" }) -- signal -> ctx -> list
local function deliverEvent(sig, ctx, args)
	if ctx.dead then
		return
	end
	if SignalApi.HasConnections(sig, ctx) then
		SignalApi.FireFor(sig, function(c)
			return c == ctx
		end, table.unpack(args, 1, args.n))
	else
		pendingEvents[sig] = pendingEvents[sig] or {}
		pendingEvents[sig][ctx] = pendingEvents[sig][ctx] or {}
		table.insert(pendingEvents[sig][ctx], args)
	end
end
local function remoteSignalHook(inst, sig)
	sig.opts = {
		onConnect = function(ctx)
			local p = pendingEvents[sig]
			local list = p and p[ctx]
			if list and #list > 0 then
				p[ctx] = nil
				M.task.defer(function()
					for _, args in list do
						SignalApi.FireFor(sig, function(c)
							return c == ctx
						end, table.unpack(args, 1, args.n))
					end
				end)
			end
		end,
	}
end
M.signalHooks.OnClientEvent = remoteSignalHook
M.signalHooks.OnServerEvent = remoteSignalHook

local RE = Classes.RemoteEvent.methods
function RE.FireServer(r, ...)
	local ctx = cur()
	if ctx.kind ~= "client" then
		error("FireServer can only be called from the client", 2)
	end
	local args = packCopy(M.serverCtx, r.Name, ...)
	local player = ctx.player
	enqueue(function()
		if ctx.dead then
			return
		end
		local a = { n = args.n + 1, player }
		for i = 1, args.n do
			a[i + 1] = args[i]
		end
		deliverEvent(getSignal(r, "OnServerEvent"), M.serverCtx, a)
	end)
end
function RE.FireClient(r, player, ...)
	local ctx = cur()
	if ctx.kind == "client" then
		error("FireClient can only be called from the server", 2)
	end
	if not isInst(player) or not isA(player, "Player") then
		error("FireClient: player argument must be a Player", 2)
	end
	local target = ctxForPlayer(player)
	if not target then
		return
	end
	local args = packCopy(target, r.Name, ...)
	enqueue(function()
		deliverEvent(getSignal(r, "OnClientEvent"), target, args)
	end)
end
function RE.FireAllClients(r, ...)
	for _, p in services.Players:GetPlayers() do
		RE.FireClient(r, p, ...)
	end
end

local RF = Classes.RemoteFunction.methods
function RF.InvokeServer(r, ...)
	local ctx = cur()
	if ctx.kind ~= "client" then
		error("InvokeServer can only be called from the client", 2)
	end
	local co = coroutine.running()
	if not coroutine.isyieldable() then
		error("InvokeServer from a non-yieldable thread", 2)
	end
	local args = packCopy(M.serverCtx, r.Name, ...)
	local player = ctx.player
	local function attempt(tries)
		if ctx.dead then
			return
		end
		local cb = rawget(r, "_p").OnServerInvoke
		if not cb then
			if tries > 300 then
				M.resume(co, false, "OnServerInvoke never set for " .. r.Name)
				return
			end
			M.schedule(M.newThread(M.serverCtx, function()
				attempt(tries + 1)
			end), M.FRAME)
			return
		end
		M.spawnIn(M.serverCtx, function()
			local res = table.pack(pcall(cb, player, table.unpack(args, 1, args.n)))
			local back
			if res[1] then
				back = packCopy(ctx, r.Name .. ":return", table.unpack(res, 2, res.n))
			end
			enqueue(function()
				if ctx.dead then
					return
				end
				if res[1] then
					M.resume(co, true, back)
				else
					M.resume(co, false, res[2])
				end
			end)
		end)
	end
	enqueue(function()
		attempt(0)
	end)
	local ok, payload = coroutine.yield()
	if not ok then
		error(payload, 2)
	end
	return table.unpack(payload, 1, payload.n)
end
function RF.InvokeClient(r, player, ...)
	error("InvokeClient is not modelled by the headless mock", 2)
end

------------------------------------------------------------------------------------------ Players
local PL = Classes.Players
PL.getters.LocalPlayer = function()
	local ctx = cur()
	return if ctx.kind == "client" then ctx.player else nil
end
M.KNOWN.LocalPlayer = true
PL.eventSet = { PlayerAdded = true, PlayerRemoving = true, PlayerMembershipChanged = true }
function PL.methods.GetPlayers(pl)
	local out = {}
	for _, ch in rawget(pl, "_kids") do
		if isA(ch, "Player") then
			table.insert(out, ch)
		end
	end
	return out
end
function PL.methods.GetPlayerByUserId(pl, id)
	for _, p in PL.methods.GetPlayers(pl) do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
function PL.methods.GetPlayerFromCharacter(pl, ch)
	for _, p in PL.methods.GetPlayers(pl) do
		if rawget(p, "_p").Character == ch then
			return p
		end
	end
	return nil
end
function PL.methods.GetNameFromUserIdAsync(pl, id)
	return "User" .. tostring(id)
end
function PL.methods.GetUserThumbnailAsync()
	return "rbxasset://textures/ui/GuiImagePlaceholder.png", true
end
function PL.methods.GetFriendsAsync()
	return { GetCurrentPage = function()
		return {}
	end, IsFinished = true }
end
function PL.methods.GetHumanoidDescriptionFromUserId()
	return nil
end

local PM = Classes.Player.methods
M.kicks = {}
function PM.Kick(p, msg)
	if cur().kind == "client" and cur().player ~= p then
		error("Cannot kick a non-local Player from a LocalScript", 2)
	end
	table.insert(M.kicks, { player = rawget(p, "_p").Name, userId = rawget(p, "_p").UserId, msg = msg, t = M.clock })
	M.globals.print("(mock) Kick " .. rawget(p, "_p").Name .. ": " .. tostring(msg))
	-- the client disconnects shortly after; PlayerRemoving fires then
	M.task.delay(0.1, function()
		if rawget(p, "_parent") ~= nil then
			M.removePlayer(p)
		end
	end)
end
function PM.LoadCharacter(p)
	if cur().kind == "client" then
		error("LoadCharacter can only be called by the backend server", 2)
	end
	M.loadCharacter(p)
end
function PM.LoadCharacterAsync(p)
	PM.LoadCharacter(p)
end
function PM.GetMouse(p)
	return { Hit = CFrame.identity, Target = nil, X = 0, Y = 0, Button1Down = Signal("Button1Down"), Move = Signal("Move") }
end
function PM.IsInGroup()
	return false
end
function PM.GetRankInGroup()
	return 0
end
function PM.HasAppearanceLoaded()
	return true
end
function PM.GetFriendsOnline()
	return {}
end
function PM.IsFriendsWith()
	return false
end
function PM.GetJoinData()
	return {}
end
function PM.RequestStreamAroundAsync() end
function PM.ClearCharacterAppearance() end
function PM.DistanceFromCharacter(p, pos)
	local ch = rawget(p, "_p").Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	return r and (r.Position - pos).Magnitude or 0
end

-- builds a minimal R15-ish character at the player's RespawnLocation (or the origin)
function M.loadCharacter(p)
	local pp = rawget(p, "_p")
	local old = pp.Character
	if old then
		SignalApi.Fire(getSignal(p, "CharacterRemoving"), old)
		old:Destroy()
	end
	local model = newInstance("Model", nil)
	rawget(model, "_p").Name = pp.Name
	local root = newInstance("Part", nil)
	rawget(root, "_p").Name = "HumanoidRootPart"
	root.Size = V(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	M.setParent(root, model)
	local head = newInstance("Part", nil)
	rawget(head, "_p").Name = "Head"
	head.Size = V(1.2, 1.2, 1.2)
	head.Color = M.Color3.fromRGB(255, 204, 153)
	M.setParent(head, model)
	local torso = newInstance("Part", nil)
	rawget(torso, "_p").Name = "UpperTorso"
	torso.Size = V(2, 1.6, 1)
	torso.Color = M.Color3.fromRGB(60, 120, 200)
	M.setParent(torso, model)
	local legs = newInstance("Part", nil)
	rawget(legs, "_p").Name = "LowerTorso"
	legs.Size = V(2, 2, 1)
	legs.Color = M.Color3.fromRGB(40, 50, 80)
	M.setParent(legs, model)
	local hum = newInstance("Humanoid", nil)
	rawget(hum, "_p").Name = "Humanoid"
	local sp = services.StarterPlayer
	hum.WalkSpeed = sp and sp.CharacterWalkSpeed or 16
	hum.DisplayName = pp.DisplayName
	M.setParent(hum, model)
	rawget(model, "_p").PrimaryPart = root
	local spawn = pp.RespawnLocation
	local cf = CFrame.new(0, 5, 0)
	if spawn and rawget(spawn, "_parent") then
		cf = spawn.CFrame + V(0, spawn.Size.Y / 2 + 3, 0)
	end
	M.placeCharacter(model, cf)
	pp.Character = model
	M.setParent(model, services.Workspace)
	M.propChanged(p, "Character")
	SignalApi.Fire(getSignal(p, "CharacterAdded"), model)
	return model
end

-- pose the simple rig around a root CFrame
function M.placeCharacter(model, cf)
	local root = model:FindFirstChild("HumanoidRootPart")
	M.rawSet(root, "CFrame", cf, false)
	local head = model:FindFirstChild("Head")
	if head then
		M.rawSet(head, "CFrame", cf * CFrame.new(0, 1.9, 0), false)
	end
	local torso = model:FindFirstChild("UpperTorso")
	if torso then
		M.rawSet(torso, "CFrame", cf * CFrame.new(0, 0.5, 0), false)
	end
	local legs = model:FindFirstChild("LowerTorso")
	if legs then
		M.rawSet(legs, "CFrame", cf * CFrame.new(0, -1.5, 0), false)
	end
end

-- Humanoid:MoveTo: the harness walker moves the character at WalkSpeed
M.walkers = {}
function M.humanoidMoveTo(h, pos)
	local model = rawget(h, "_parent")
	if not model then
		return
	end
	M.walkers[model] = { target = pos, hum = h }
end
table.insert(M.frameHooks, function(dt)
	for model, w in M.walkers do
		local root = rawget(model, "_parent") and model:FindFirstChild("HumanoidRootPart")
		if not root then
			M.walkers[model] = nil
			continue
		end
		local p = root.Position
		local flat = V(w.target.X, p.Y, w.target.Z)
		local d = flat - p
		local dist = d.Magnitude
		local step = w.hum.WalkSpeed * dt
		local look = if dist > 1e-6 then CFrame.lookAt(p, flat) else root.CFrame
		if dist <= step then
			M.placeCharacter(model, look.Rotation + flat)
			M.walkers[model] = nil
			local s = M.peekSignal(w.hum, "MoveToFinished")
			if s then
				SignalApi.Fire(s, true)
			end
		else
			M.placeCharacter(model, look.Rotation + (p + d.Unit * step))
		end
	end
end)

-- default camera: each client's Camera follows its character (CameraType Custom), 14 studs
-- behind and 8 above the root part, like the default third-person camera at rest
table.insert(M.frameHooks, function(dt)
	for ctx in M.clients do
		local cam = ctx.camera
		local p = ctx.player
		local ch = p and rawget(p, "_p").Character
		local root = ch and rawget(ch, "_parent") and ch:FindFirstChild("HumanoidRootPart")
		if cam and root and cam.CameraType == Enum.CameraType.Custom then
			local cf = root.CFrame
			local eye = cf.Position - cf.LookVector * 14 + V(0, 8, 0)
			M.rawSet(cam, "CFrame", CFrame.lookAt(eye, cf.Position + V(0, 2, 0)), false)
		end
	end
end)
