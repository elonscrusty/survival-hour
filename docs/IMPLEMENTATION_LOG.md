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

## Phase 2: progression, tools, stamina, healing (done, not yet playtested)

| Spec rule | Change | Where |
|---|---|---|
| Workbench Tiers I–V with the spec costs | `Recipes.WorkbenchUpgrades[2..5]` = spec values; `MaxWorkbenchLevel = 5`. Paid from pack + your storage (unchanged mechanism). Tier IV adds a forge, Tier V a steel top; the plate reads I–V. Craft UI shows roman tiers. | `Recipes`, `Models/Camp`, `Craft` |
| Start with nothing; Crude Axe / Pickaxe / Spear at spec costs | Tier I recipes: 8 Stick + 3 Stone + 3 Fibre, 10 + 5 + 3, 12 + 3 + 5 | `Recipes`, `Items` |
| Small tree = EXACTLY 4 Wood (Crude Axe+), large = EXACTLY 16 (Stone Axe+) | New `Resources.Yield` + `MinTier`; `ResourceRules.YieldFor` spreads the exact total over the hits by damage, so any tool power gives exactly 4 / 16. Medium trees give 8 (Crude+). | `Resources`, `ResourceRules` |
| Small stone = 3 Stone (Crude Pickaxe+), large = 12 (Stone Pickaxe+); loose → hands | `RockPile` is now the small deposit (pickaxe); new `LargeRockPile` node (double-size model) placed fairly in every sector; loose stones stay hand-gathered | `Resources`, `Flora`, `GatherService` |
| Tool tiers Crude/Stone/Iron/Steel, ~40/100/225/450 hits, break at 0 | 8 tools generated from one tier table (`CrudeAxe` … `SteelPickaxe`) with `ToolTier`; wear 1 per successful hit (hooks for class/power-up modifiers). Second tool slot (`Tool2`, key 4; Utility moved to 5) so an axe and a pickaxe fit together. Prompts auto-equip the best matching tool. | `Items`, `InventoryModel`, `GatherService`, `Hud`, `Inventory`, `Input` |
| Stamina 100 | New `StaminaService`: hold Shift / L3 (touch: RUN toggle) to sprint ×1.4, drains 12/s, regen 14/s after 1.2 s, exhausted until 20. `Spend`/`Drain` ready for melee/blocking (Phase 4). HUD stamina bar. | `StaminaService`, `Movement` (client), `Hud`, `Config.Stamina` |
| No fast passive regen; timed interruptible healing 20/50/100 | Fire warmth 2 → 0.5 HP/s; food 5/8 HP. Bandage (pouch, craftable anywhere from 4 Fibre) +20 in 3 s; First Aid (Tier II) +50 in 5 s; Medkit (Tier IV) +100 in 8 s. One `InventoryService.Heal` channel, interrupted by damage, slows you while applying. | `Config.Healing`, `InventoryService`, `Recipes` |

Also: the pre-existing `LayoutGen fair_resources` failure is fixed (the test used old node names), so all unit tests pass.

**Decisions:** D42 medium trees = 8 Wood with a Crude Axe; D43 First Aid / Medkit are pack items (drop on death like materials); bandages stay in the kept pouch; D44 Canteen stays Tier II.

**Tests:** `Recipes.spec` rewritten for the tiers and spec costs; `ResourceRules.spec` gains `exact_yields_any_tool` and `tool_tiers`; skins suite adds Workbench IV/V, `LargeRockPile` and all tiered tool models (27 checks).
