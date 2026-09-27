--!nonstrict
-- Server-timed channelled interactions (pour, steal, open, gather, fill, bandage).
--
-- ProximityPrompts are instant triggers (HoldDuration 0); the *server* times the
-- action, so exploit clients cannot skip progress. A channel is cancelled when
-- the player takes damage (if InterruptOnDamage), dies, moves out of range, the
-- target becomes invalid, CanContinue() fails, or (for Hold channels) the
-- player releases the prompt/button.
--
-- Prompt routing: every server prompt carries an "Action" attribute; services
-- register a handler per action with ChannelService.OnPrompt.

local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

export type Spec = {
	Kind: string,
	Label: string,
	Duration: number,
	Range: number,
	Position: () -> Vector3?, -- nil = target gone
	Hold: boolean?, -- releasing cancels
	InterruptOnDamage: boolean?,
	Prompt: ProximityPrompt?,
	CanContinue: (() -> (boolean, string?))?,
	OnComplete: () -> (),
	OnCancel: ((string) -> ())?,
	Action: string?, -- character "Action" attribute while channelling (drives animations)
	TargetKey: any?, -- identifies the target for exclusivity checks (e.g. a fire's team)
}

type Active = Spec & { Player: Player, Started: number, Id: number }

local ChannelService = {}

local ctx: any
local active: { [Player]: Active } = {}
local handlers: { [string]: (Player, ProximityPrompt) -> () } = {}
local nextId = 0

function ChannelService.Init(c)
	ctx = c
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		local action = prompt:GetAttribute("Action") :: string?
		if not action then
			return
		end
		local h = handlers[action]
		if not h then
			return
		end
		if not ctx.Util.Allow(player, "Interact") then
			return
		end
		local ok, err = pcall(h, player, prompt)
		if not ok then
			warn("[ChannelService] prompt handler " .. action .. " error:", err)
		end
	end)
	ProximityPromptService.PromptTriggerEnded:Connect(function(prompt: ProximityPrompt, player: Player)
		local a = active[player]
		if a and a.Hold and a.Prompt == prompt then
			ChannelService.Cancel(player, "Released")
		end
	end)
	ctx.Util.Connect("ChannelStop", "Interact", function(player: Player)
		local a = active[player]
		if a then
			ChannelService.Cancel(player, "Cancelled")
		end
	end)
	ctx.Util.OnPlayerRemoving(function(player: Player)
		ChannelService.Cancel(player, "Left")
	end)
	ctx.MatchService.On("MatchCleanup", function()
		for p in active do
			ChannelService.Cancel(p, "Match over")
		end
	end)
end

function ChannelService.Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local t = os.clock()
		for player, a in active do
			local reason: string? = nil
			local root = ctx.Util.Root(player)
			local hum = ctx.Util.Humanoid(player)
			if not root or not hum or hum.Health <= 0 then
				reason = "You died"
			else
				local pos = a.Position()
				if not pos then
					reason = "Target is gone"
				elseif (root.Position - pos).Magnitude > a.Range + 2 then
					reason = "Moved out of range"
				elseif a.CanContinue then
					local ok, why = a.CanContinue()
					if not ok then
						reason = why or "Interrupted"
					end
				end
			end
			if reason then
				ChannelService.Cancel(player, reason)
			elseif t - a.Started >= a.Duration then
				active[player] = nil
				ChannelService._clearAction(player)
				Net.FireClient("ChannelState", player, { Id = a.Id, Done = true })
				local ok, err = pcall(a.OnComplete)
				if not ok then
					warn("[ChannelService] OnComplete error:", err)
				end
			end
		end
	end)
end

function ChannelService.OnPrompt(action: string, handler: (Player, ProximityPrompt) -> ())
	handlers[action] = handler
end

-- Creates a standard server prompt.
function ChannelService.MakePrompt(parent: Instance, action: string, actionText: string, objectText: string, range: number?, filter: string?, team: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = action .. "Prompt"
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = range or 10
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Action", action)
	if filter then
		p:SetAttribute("Filter", filter) -- "Team" | "Enemy" (client hides prompts that don't apply)
	end
	if team then
		p:SetAttribute("Team", team)
	end
	p.Parent = parent
	return p
end

function ChannelService.Begin(player: Player, spec: Spec): boolean
	if active[player] then
		ChannelService.Cancel(player, "Started something else")
	end
	nextId += 1
	local a = spec :: any
	a.Player = player
	a.Started = os.clock()
	a.Id = nextId
	active[player] = a
	if spec.Action then
		local char = player.Character
		if char then
			char:SetAttribute("Action", spec.Action)
			char:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		end
	end
	Net.FireClient("ChannelState", player, {
		Id = a.Id,
		Kind = spec.Kind,
		Label = spec.Label,
		Duration = spec.Duration,
		Hold = spec.Hold == true,
	})
	return true
end

function ChannelService._clearAction(player: Player)
	local char = player.Character
	if char and char:GetAttribute("Action") then
		char:SetAttribute("Action", nil)
	end
end

function ChannelService.Cancel(player: Player, reason: string)
	local a = active[player]
	if not a then
		return
	end
	active[player] = nil
	ChannelService._clearAction(player)
	if player.Parent then
		Net.FireClient("ChannelState", player, { Id = a.Id, Cancelled = true, Reason = reason })
	end
	if a.OnCancel then
		local ok, err = pcall(a.OnCancel, reason)
		if not ok then
			warn("[ChannelService] OnCancel error:", err)
		end
	end
end

function ChannelService.CancelFor(player: Player, reason: string)
	ChannelService.Cancel(player, reason)
end

function ChannelService.OnDamaged(player: Player)
	local a = active[player]
	if a and a.InterruptOnDamage ~= false then
		ChannelService.Cancel(player, "Interrupted by damage!")
	end
end

function ChannelService.Get(player: Player): Active?
	return active[player]
end

function ChannelService.IsBusy(player: Player, kind: string?): boolean
	local a = active[player]
	return a ~= nil and (kind == nil or a.Kind == kind)
end

-- Is anyone channelling `kind` against something identified by `key`?
function ChannelService.AnyOnTarget(kind: string, key: any): Player?
	for p, a in active do
		if a.Kind == kind and a.TargetKey == key then
			return p
		end
	end
	return nil
end

return ChannelService
