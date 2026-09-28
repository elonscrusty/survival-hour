--!nonstrict
-- Roblox Analytics (Creator Dashboard → Analytics): the new-player funnel, the
-- Coin / Diamond economy and match results. Presentation-free and read-only for
-- gameplay: every call is pcall-guarded and skipped in Studio, so analytics can
-- never change or break a match.
--
-- Onboarding steps 1-5 are logged only for players who haven't finished a match
-- yet; steps 6-7 when a player's first and second matches are counted.

local AnalyticsService = game:GetService("AnalyticsService")

local TelemetryService = {}

TelemetryService.Steps = {
	"Lobby loaded",
	"Readied up",
	"Match started",
	"First gather",
	"First craft",
	"Finished first match",
	"Played a second match",
}

local ctx: any
local logged: { [Player]: { [number]: boolean } } = {}
local matchStart: { [Player]: { Coins: number, Diamonds: number }? } = {}

local function safe(fn: () -> ())
	if ctx.IsStudio then
		return
	end
	local ok, err = pcall(fn)
	if not ok then
		warn("[TelemetryService]", err)
	end
end

function TelemetryService.Init(c)
	ctx = c
	ctx.Util.OnPlayerAdded(function(p: Player)
		if ctx.Mode ~= "Lobby" then
			return
		end
		task.spawn(function()
			if ctx.DataService.WaitFor(p, 60) then
				TelemetryService.Onboard(p, 1)
			end
		end)
	end)
	ctx.Util.OnPlayerRemoving(function(p: Player)
		logged[p] = nil
		matchStart[p] = nil
	end)
	ctx.MatchService.On("PlayerJoinedMatch", function(p: Player)
		matchStart[p] = TelemetryService.Snap(p)
		TelemetryService.Onboard(p, 3)
	end)
end

-- Logs onboarding step `step` (TelemetryService.Steps) once per player per server.
function TelemetryService.Onboard(p: Player, step: number)
	local session = ctx.DataService.Get(p)
	if not session or (session.State ~= "Loaded" and session.State ~= "Memory") then
		return
	end
	local matches = session.Profile.Matches
	local fits = if step <= 5 then matches == 0 elseif step == 6 then matches == 1 else matches == 2
	local seen = logged[p] or {}
	logged[p] = seen
	if not fits or seen[step] then
		return
	end
	seen[step] = true
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(p, step, TelemetryService.Steps[step])
	end)
end

-- Current wallet, for Wallet() after a change.
function TelemetryService.Snap(p: Player): { Coins: number, Diamonds: number }?
	local session = ctx.DataService.Get(p)
	local ready = session and (session.State == "Loaded" or session.State == "Memory")
	return if ready then { Coins = session.Profile.Coins, Diamonds = session.Profile.Diamonds } else nil
end

-- Logs what changed since `before` as economy sources / sinks.
-- `tx` is an Enum.AnalyticsEconomyTransactionType name (IAP, Shop, Gameplay, TimedReward...).
function TelemetryService.Wallet(p: Player, before: { Coins: number, Diamonds: number }?, tx: string, sku: string?)
	local session = ctx.DataService.Get(p)
	if not before or not session then
		return
	end
	for _, currency in { "Coins", "Diamonds" } do
		local now = session.Profile[currency]
		local delta = now - before[currency]
		-- Keep the match baseline in step so a purchase or claim during a match
		-- isn't counted again as match earnings.
		local base = matchStart[p]
		if base and base ~= before then
			base[currency] += delta
		end
		if delta ~= 0 then
			safe(function()
				AnalyticsService:LogEconomyEvent(
					p,
					if delta > 0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
					currency,
					math.abs(delta),
					now,
					tx,
					sku
				)
			end)
		end
	end
end

-- Called once a player's match is counted (MatchService.End or an early leave):
-- logs the match's Coin / Diamond earnings, the result and funnel steps 6-7.
function TelemetryService.MatchCommitted(p: Player, place: number?, early: boolean)
	TelemetryService.Wallet(p, matchStart[p], Enum.AnalyticsEconomyTransactionType.Gameplay.Name, "Match")
	matchStart[p] = nil
	safe(function()
		AnalyticsService:LogCustomEvent(p, if early then "MatchLeftEarly" else "MatchPlace", place or 0)
	end)
	TelemetryService.Onboard(p, 6)
	TelemetryService.Onboard(p, 7)
end

return TelemetryService
