# Survival Wars implementation log

Running log for the *Survival Wars: Master Continuation Specification*. Newest phase at the bottom.
The requirement-by-requirement status is in [SPEC_AUDIT.md](SPEC_AUDIT.md). All numbers are in
`src/shared/Config.luau` (or the data modules) and are **tunable, not final** until playtested.

**How to verify after each change:**
- `cd tests && luau run.luau`: unit tests (1 known pre-existing failure: `LayoutGen fair_resources`).
- `python tests/skins/bundle.py`: builder and mesh-skin mock tests.
- `luau-lsp analyze` with Roblox definitions: no new diagnostics vs. the previous commit.

---

## Phase 0: audit (done)
- Wrote `docs/SPEC_AUDIT.md`. Every spec requirement is marked ✅ / 🟡 / ❌ with an implementation phase.
- Nothing rebuilt: the existing systems (lobby, matchmaking, camps, gathering, crafting, building,
  storage theft, wildlife, loot, powerups, data store, mesh skins) are all kept.

## Phase 1: core match rules (done, not yet playtested in Studio)

| Spec rule | Change | Where |
|---|---|---|
| Solo, min 4 players, own camp each | `MaxPerTeam = 1`, `MinPlayers = MaxPlayers = 4`; parties capped at `MaxPerTeam` (invite says "solo"). Team code is kept: teams come back by raising `MaxPerTeam`. | `Config.Match`, `LobbyService` |
| Burning fire = unlimited respawns | `Lives.FreeRespawns = math.huge` (replicated as `FreeRespawns = -1`). The paid revive window never opens. | `Config.Lives`, `LivesRules`, `LivesService` |
| Respawn 8 / 12 / 16 / 20 s cap | `Lives.RespawnDelays`; `LivesRules.RespawnDelay` by death count; the HUD counts down from `RespawnAt` | `LivesRules`, `LivesService`, `Hud` |
| Protected players can't deal damage | `CombatService.DamagePlayer` and `BuildService.Damage` ignore attackers inside `ProtectedUntil` (3 s spawn protection) | Combat, Build |
| Sunrise: 15 s invincibility for players alive then | `LivesService._onPhase` extends `ProtectedUntil` on each Day ≥ 2 | `LivesService`, `Config.Match.SunriseProtection` |
| Fuel: start 50 %, L1 full = 8 min, 1 Wood = +2 %, 0 % = out for good | New pure `FireRules` + fuel loop in `CampService` (burns during Day/Night only). Owner **Add Wood** prompt feeds as much Wood as fits. Low-fuel warning at 15 %. | `Logic/FireRules`, `CampService` |
| Full-fuel L1–L5 = 8 … 12 min | `Fire.FullFuelSeconds`; levelling keeps the fuel % | `FireRules` |
| Fire upgrades L2–L5 (Wood/Stone/Scrap/Iron/Rare) | Owner **Upgrade Fire** prompt; materials are *contributed* over several trips (a pack can't hold 32 Wood + 18 Stone). Fire gets bigger, brighter and smokier (`Camp.SetFire`). | `CampService`, `Models/Camp` |
| Nights 1–2 no snuffing; Night 3+ day and night | `FireRules.SnuffAllowed(phase, day)`; `MatchState.SnuffOpen` replicates it; "FIRES EXPOSED" announcement at Night 3 | `MatchService`, `CampService`, `Prompts`, `Hud` |
| Snuff 8/10/12/15/20 s by level; damage/move/release cancels | Channel duration by level; new `MoveTolerance` (2.5 studs) on channels | `ChannelService`, `CampService` |
| Owner warning with direction, no wallhack | `FireUnderAttack` carries a compass bearing from the fire (HUD shows "Raider on the NE side") | `CampService`, `Hud` |
| Fire out = final life | Message changed; logic was already correct | `MatchService` |
| Win = exactly 2 Diamonds | `WinDiamonds = 2` | `Config.Match` |
| Non-pay-to-win Robux | `Products.OnSale` marks Revive, CarePackage, Bandage, Diamonds, Unlock and Upgrade off sale. `PurchaseService.Prompt`, `LobbyService`, `LootService` refuse them; the shop UIs hide them and the in-match shop button is hidden. Definitions stay so old receipts still resolve. | `Products`, services, `Shop`, `Lobby` |
| Scrap / Iron / Coal / Rare Component | Added as resources (items, pickups, storage). **No source yet**, so fire L3+ is unreachable until Phase 2–5 add scrap, ore and chests. | `Items`, `InventoryModel`, `ItemModels` |

**Decisions made (open in the spec):**
- **D37:** Snuffing still needs a **filled canteen** (the existing pour mechanic, Workbench II). The spec
  doesn't mention a tool; this keeps working content and adds cost. Remove the canteen checks in
  `CampService._onPour` to allow bare-handed snuffing.
- **D38:** Wood adds 2 % of *capacity* at every level, so one Wood buys more seconds on a bigger fire.
- **D39:** If a fire dies while its owner waits to respawn, the owner is eliminated (unchanged rule:
  you can't respawn at a dead fire).
- **D40:** Fuel only burns during Day/Night, not during the intro countdown.
- **D41:** Enemy fire fuel isn't replicated to other players; the owner sees it (`FireFuel`, `FireLevel`,
  `FireNeeds` player attributes). Everyone sees the fire's size and brightness.

**Tests added:** `tests/FireRules.spec.luau` (8), 2 new cases in `LivesRules.spec`, and a
`Campfire: level/fuel visuals` case in the skins suite.

**Known follow-ups:** `docs/TUNING.md`, `GDD.md` and the lobby intro text still describe 4-player clans
and paid revives. They'll be updated when the meta (Phase 6) and UI (Phase 7) are reworked.
