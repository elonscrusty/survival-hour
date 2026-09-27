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

## Phase 3: inventory slots, storage raids, building tiers, traps (done, not yet playtested)

| Spec rule | Change | Where |
|---|---|---|
| ~6 starting slots; packs 10/16/24/32/40 | The resource pack is now **slots of stacks**: `Capacity` = slots (6), each slot holds one stack. 5 craftable backpacks (Fibre I → Expedition V) are worn like armour, set the slot count, and are kept on death. Swapping to a smaller pack drops the overflow in a bag. Bonus-slot hook for Strong Back / Scavenger. | `InventoryModel` (`StackSize`, `RoomFor`, `SpaceFor`, `TrimToCapacity`, `SetPackSlots`), `InventoryService`, `Items`, `Recipes` |
| Stack targets Wood 32, Stone 24, Fibre 32, Scrap 20, Iron 16, Coal 20, Rare 5 | `InventoryModel.StackSize` (others: Stick 32, Leather/Rope 16, food 20, First Aid 5, Medkit 3, Charge 3) | `InventoryModel` |
| Wooden Crate ~12 / Reinforced Chest ~20 / Metal Locker ~30 / Survival Safe ~40-50 | Storage capacity is in stack slots (`Items[id].Stacks` = 12/20/30/45); 4 storage structures (Tiers I–IV) | `Items`, `Structures`, `StorageLedger` |
| Storage cap by Workbench I–V = 1/2/3/4/5 | `Config.Build.TierLimits.Storage`; `BuildService.LimitMax` | `BuildService` |
| Breach unlocks (not deletes); owner repairs/resecures | Enemy **Hold: Breach** (G) → the storage is *unlocked*; any enemy can then open it and take what fits. Owner **Hold: Resecure** (R, 4 s + a few materials). The old 3 s "steal 10" is gone. | `StorageService` (rewritten), `Storage` (client) |
| Breaching progression: tools → Crowbar → Sledgehammer → Breaching Charge | Breach 14/24/36/50 s by tier with an axe/pickaxe; Crowbar ×0.6 (needed for lockers), Sledgehammer ×0.4 (needed for safes), Breaching Charge 5 s on anything (60 damage in 10 studs). Raider-class hook `BreachSpeedMult`. | `Config.Storage`, `Items`, `Recipes` |
| Raiding expensive and loud | Banging every ~2 s: players within 180 studs get a "someone is breaching" feed line; the owner gets the storage name + compass side. Charges explode. | `StorageService`, `Hud` |
| Build only in own camp; no river/cave blocking; no map spam | Existing camp radius + caps; new stream clearance check (9 studs + half the footprint from any stream centre line) and a `map.NoBuild` list (caves/POIs in Phase 5) | `BuildService.Validate` |
| Tier I wall/door/floor/spikes | Wooden Door (was Tier II Gate), new Wooden Floor, Spike Barricade (now a trap) | `Items`, `Recipes`, `Structures` |
| Tier II reinforced wall/door/window/basic traps | Reinforced Wall (moved from III), Reinforced Door, Window Wall (procedural, real window gap in the collider), Tripwire Alarm, Snare | same |
| Tier III scrap defences/stronger traps/watch platform | Scrap Wall, Bear Trap, Watchtower | same |
| Tier IV/V heavy defences/gates/advanced traps | Metal Wall, Heavy Gate (IV); Advanced Alarm (V) | same |
| Traps; no turrets; cap I–V = 2/3/4/5/6 | Tripwire (alarm + compass side, 8 s cooldown), Snare (2.5 s hold, spent), Bear Trap (35 dmg + 3.5 s hold, spent), Advanced Alarm (16-stud sensor: tells you *who* and which side, no position), Spike Barricade. All share the `Trap` cap by tier. Held players can't move (`HeldUntil`). | `BuildService`, `Config.Build.TierLimits.Trap` |

**Decisions:** D45 First Aid / Medkit / Breaching Charges are pack items (drop on death). D46 Breaching needs the tool in your tool/weapon slots (not equipped). D47 Survival Safe is Tier IV. D48 tiered doors and the window wall use the procedural look (new `Skins.Unskin`), since the pack meshes don't match their shape.

**Tests:** slot/stack cases in `InventoryModel.spec` and `StorageLedger.spec`; `Recipes.spec` checks every tier's unlocks; the skins suite builds every new structure, checks door opening, the breach tag and trap triggers (28 checks).

## Phase 4: wildlife, melee, ranged, armour (done, not yet playtested)

| Spec rule | Change | Where |
|---|---|---|
| Deer flee; rabbits fast/passive; boars charge; wolves aggressive packs; bears uncommon/territorial/dangerous | New Deer, Rabbit, Boar rigs (same quadruped rig as wolf/bear, so the client animator drives them). Roles: **Prey** (roam; bolt away from players within 38/22 studs or when hit, zig-zag), **Charger** (boar: ignores you until you're within 14 studs or hit it, snorts then charges, gives up past 45), **Pack** (wolves, night only), **Territorial** (bears defend ~32 studs around where they spawned, give up when you leave). Bats aren't in the spec: kept in code, capped at 0. | `WildlifeService`, `Models/Animals` |
| Night escalation = pressure/aggression/pack size/roaming, not HP | New pure `WildlifeRules`: per night +pack size (≤+3 wolves), aggro/territory range ×1.0→1.6, spawn interval ×1→0.5, predator cap 6 → 14. Day: prey + a few boars and a rare bear, calmer ranges. Health never changes. | `Logic/WildlifeRules` (+ tests), `Config.Wildlife` |
| – | Leather now drops from every kill (day too); hooks for Hunter (extra hide), Hardy (wildlife damage), XP/Coins | `WildlifeService`, `PowerupService` |
| Melee Light / Heavy / Block; stamina and guard break matter | Tap = light (6 stamina), hold ≥0.45 s and release = heavy (×1.8 damage, ×1.6 cooldown, 18 stamina, drains 20 extra from a blocker). Right-click blocks with **any** melee weapon/tool (45%; Shield 70%), costing stamina per point blocked; running out breaks the guard (1.5 s no block). Too little stamina = weak swings. The server enforces the heavy wind-up. | `CombatService`, `Logic/CombatRules` (+ tests), `Combat` (client), `Config.Combat` |
| Tools hurt players but weapons are better | Tool damage 10–19 vs spears 16–22, sword 32 (unchanged tables) | `Items` |
| Crude Bow II, Hunting Bow III, Crossbow III/IV; headshots; no casual early one-shots | Crude Bow 22 (Tier II), Hunting Bow 34 (Tier III), Crossbow 48 with Bolts (Tier IV). Head hits ×1.75 on bows, crossbows and guns ("◎ HEADSHOT" marker); every bow/crossbow headshot stays under 100 HP (tested). | `Items`, `Recipes`, `CombatService` |
| Armour Head/Chest/Legs, Hide → Reinforced Hide → Scrap → Iron → Tactical; full set < 45–50% | 15 pieces generated from one table; full-set reduction 15/22/30/38/46% (split 25/45/30%), capped at 50%. Three worn slots, each piece wears separately and shows as a tier-coloured shell on the head/torso/legs. The old "Leather Armor" loot item is now a hide chestpiece. | `Items`, `InventoryModel`, `InventoryService`, `CombatService` |
| No downed state for solo | Unchanged (none exists) | – |

**Tests:** `WildlifeRules.spec` (4), `CombatRules.spec` (4), armour-slot case in `InventoryModel.spec`, skins suite builds the new animals and ranged weapons (30 checks).
