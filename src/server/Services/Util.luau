--!nonstrict
-- Shared server helpers: ordered player-join hooks, rate-limited remote
-- handlers, argument validation and character queries.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local RateLimiter = require(Shared:WaitForChild("Logic"):WaitForChild("RateLimiter"))

local Util = {}

local ctx: any
local joinHooks: { (Player) -> () } = {}
local leaveHooks: { (Player) -> () } = {}
local joined: { [Player]: boolean } = {}
local limiter = RateLimiter.New(Config.RateLimits)
local rejectLog: { [Player]: number } = {}

function Util.Init(c)
	ctx = c
	Players.PlayerAdded:Connect(Util.FirePlayerAdded)
	Players.PlayerRemoving:Connect(function(p)
		for _, fn in leaveHooks do
			local ok, err = pcall(fn, p)
			if not ok then
				warn("[Util] leave hook error:", err)
			end
		end
		joined[p] = nil
		rejectLog[p] = nil
		RateLimiter.Forget(limiter, p)
	end)
end

function Util.OnPlayerAdded(fn: (Player) -> ())
	table.insert(joinHooks, fn)
end

function Util.OnPlayerRemoving(fn: (Player) -> ())
	table.insert(leaveHooks, fn)
end

function Util.FirePlayerAdded(p: Player)
	if joined[p] then
		return
	end
	joined[p] = true
	for _, fn in joinHooks do
		task.spawn(function()
			local ok, err = pcall(fn, p)
			if not ok then
				warn("[Util] join hook error:", err)
			end
		end)
	end
end

-- Connects a client->server remote with rate limiting and error isolation.
function Util.Connect(remoteName: string, bucket: string, handler: (Player, ...any) -> ())
	Net.Event(remoteName).OnServerEvent:Connect(function(player: Player, ...)
		if not RateLimiter.Allow(limiter, player, bucket, os.clock()) then
			rejectLog[player] = (rejectLog[player] or 0) + 1
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[%s] handler error from %s: %s", remoteName, player.Name, tostring(err)))
		end
	end)
end

function Util.Allow(player: Player, bucket: string): boolean
	return RateLimiter.Allow(limiter, player, bucket, os.clock())
end

-- Validation ------------------------------------------------------------------------

function Util.IsFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Util.IsInt(n: any, lo: number?, hi: number?): boolean
	if not Util.IsFinite(n) or n ~= math.floor(n) then
		return false
	end
	if lo and n < lo then
		return false
	end
	if hi and n > hi then
		return false
	end
	return true
end

function Util.IsStr(s: any, maxLen: number?): boolean
	return type(s) == "string" and #s <= (maxLen or 64)
end

function Util.IsVec3(v: any): boolean
	return typeof(v) == "Vector3" and Util.IsFinite(v.X) and Util.IsFinite(v.Y) and Util.IsFinite(v.Z)
end

function Util.IsUnit(v: any): boolean
	return Util.IsVec3(v) and math.abs(v.Magnitude - 1) < 0.05
end

function Util.IsCFrame(c: any): boolean
	if typeof(c) ~= "CFrame" then
		return false
	end
	local p = c.Position
	return Util.IsVec3(p) and Util.IsFinite(c.LookVector.X)
end

-- Characters -------------------------------------------------------------------------

function Util.Root(player: Player): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Util.Humanoid(player: Player): Humanoid?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChildOfClass("Humanoid")
end

function Util.IsAlive(player: Player): boolean
	local hum = Util.Humanoid(player)
	return hum ~= nil and hum.Health > 0 and player:GetAttribute("LifeState") == "Alive"
end

function Util.DistTo(player: Player, pos: Vector3): number
	local r = Util.Root(player)
	if not r then
		return math.huge
	end
	return (r.Position - pos).Magnitude
end

function Util.Team(player: Player): number
	return (player:GetAttribute("Team") :: number?) or 0
end

function Util.InMatch(player: Player): boolean
	return player:GetAttribute("InMatch") == true
end

-- One-shot character action for the procedural animator (Controllers/Animation):
-- the client plays the pose for a short window after ActionAt.
function Util.SetAction(player: Player, action: string, item: string?)
	local char = player.Character
	if char then
		char:SetAttribute("Action", action)
		char:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		if item then
			char:SetAttribute("ActionItem", item)
		end
	end
end

function Util.Notify(player: Player, text: string, kind: string?)
	Net.FireClient("Notify", player, text, kind or "info")
end

function Util.NotifyTeam(team: number, text: string, kind: string?)
	for _, p in Players:GetPlayers() do
		if Util.Team(p) == team and Util.InMatch(p) then
			Net.FireClient("Notify", p, text, kind or "info")
		end
	end
end

function Util.MatchPlayers(): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if Util.InMatch(p) then
			table.insert(out, p)
		end
	end
	return out
end

function Util.TeamPlayers(team: number): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if Util.InMatch(p) and Util.Team(p) == team then
			table.insert(out, p)
		end
	end
	return out
end

-- Returns the Player owning a model (character), or nil.
function Util.PlayerFromPart(part: Instance): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local p = Players:GetPlayerFromCharacter(model)
		if p then
			return p
		end
		-- FindFirstAncestorOfClass starts at the parent, so nested models
		-- (e.g. a held item inside the character) still resolve.
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function Util.Now(): number
	return workspace:GetServerTimeNow()
end

-- Sounds (server-side spatial one-shots replicate to everyone nearby)
local SoundLib = require(Shared:WaitForChild("Sounds"))

function Util.PlaySound(name: string, parent: Instance?)
	if parent then
		SoundLib.PlayAt(name, parent)
		-- the same sound is gameplay noise for wildlife (Config.Noise)
		local r = (Config.Noise :: any)[name]
		if r and ctx and ctx.WildlifeService then
			local pos = if parent:IsA("BasePart") then parent.Position elseif parent:IsA("Attachment") then parent.WorldPosition else nil
			if pos then
				ctx.WildlifeService.Noise(pos, r)
			end
		end
	end
end

function Util.MakeSound(name: string, parent: Instance): Sound?
	local s = SoundLib.Make(name)
	if s then
		s.Parent = parent
	end
	return s
end

-- Awards a Roblox badge by Config.Badges key (no-op until the badge id is filled in).
-- Runs in the background and never errors; each badge is tried at most once per session.
local badgeTried: { [Player]: { [string]: boolean } } = setmetatable({}, { __mode = "k" }) :: any
function Util.AwardBadge(player: Player, key: string)
	local id = (Config.Badges :: any)[key]
	if type(id) ~= "number" or id <= 0 then
		return
	end
	local tried = badgeTried[player] or {}
	badgeTried[player] = tried
	if tried[key] then
		return
	end
	tried[key] = true
	task.spawn(function()
		local BadgeService = game:GetService("BadgeService")
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if ok and not has then
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		end
	end)
end

-- Folder helper under workspace
function Util.Folder(name: string, parent: Instance?): Folder
	local p = parent or workspace
	local f = p:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = p
	return nf
end

return Util
