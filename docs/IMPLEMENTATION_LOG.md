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

## Phase 5: POIs, caves, chests, forest, Blender world kit (done, not yet playtested)

| Spec rule | Change | Where |
|---|---|---|
| Randomised/semi-random caves, cabins, ranger structures, shelters, campsites, ruins, supply areas, hidden spots | Each match rolls a **common** POI near every camp (Campsite / Shed / Hunting Blind / Broken Vehicle / Small Cabin), an **uncommon** one mid-way (Cabin / Ranger Station / Logging Camp / Abandoned House / Mine Entrance) and a far one that is **rare** 30% of the time (Bunker / Outpost / Industrial Site / Large Mine). One cave per sector in the cliff rim: Small 55%, Medium 35%, Large 10%. All four sectors get the same set (rotated) for fairness. | `LayoutGen` (`PoiPools`, `CaveSizes`), `Models/Landmarks` (14 POIs + cave + chests) |
| Placement respects terrain, water, spawn distance, spacing, trails, rarity | Existing LayoutGen spot checks (bounds, core/camp clearance, rim, paths, streams, occupancy) + rarity by distance band; POIs and caves add `NoBuild` zones | `LayoutGen`, `WorldService`, `BuildService` |
| Caves: small 0–1 chest Stone/Coal; medium 1–2 Iron/Coal + predators; large rare, multiple chambers, 2–4 chests, rare deposits | Tunnels (22/34/42 long) carved into the cliff terrain with slate floors, end chamber, 2 side chambers for large; lanterns → blue crystals deeper in. Coal/iron seams, large-stone in small caves, **Rich Iron Vein** (15% Rare Component) in large ones. Wolf den (medium) / bear (large) spawns at night. Ground height inside caves uses the cave floor. | `WorldService._carveCaves`, `LayoutGen.CaveNodes`, `WildlifeService._denSpawns` |
| Chest tiers Common / Uncommon / Rare / Very Rare; best chests one-time per match | Chest tier list rolled per POI by rarity; chests spawn at the POI's `ChestMount`s, take 2/3/4.5/6 s to search, open **once per match**. New tables: basic supplies → materials/stone tools/hide armour → iron/scrap/Hunting Bow/Medkit/Crowbar/Rare Component → 2 Rare Components/Crossbow/Iron armour/Steel Axe/Breaching Charge. Forest crates and the free care package use the new items too. | `Loot`, `LootService`, `Landmarks.Chest` |
| Scrap / Iron / Coal / Rare Component sources | Scrap Piles (Crude Pickaxe+) at vehicles/industrial/bunker/outpost/logging camp; Coal Seams + Iron Deposits (Stone Pickaxe+) at mines and caves; Rich Iron (Iron Pickaxe+) | `Resources`, `Flora` |
| Lush, layered forest; many variants; not one tree duplicated | The layout's middle/low/ground layers (logs, boulders, stumps, roots, snags / ferns, bushes, grass, saplings / litter, moss, flowers, mushrooms, pebbles, twigs) and extra tree species (spruce, aspen, dead snag, giant oak) are now actually built. **Mesh-first**: one MeshPart per decoration with a simple box collider only on solid kinds. | `Models/Decor`, `WorldService.BuildMatch` |
| Forest floor variety; river transitions; cliffs; waterfall | Noise-driven terrain materials (moss/LeafyGrass, leaf-litter Ground, damp Mud hollows, rock/slate rim), mud + rock banks along streams, tuned forest palette; cliff faces on the rim; waterfall rocks; riverbank strips along streams | `WorldService.writeTerrain` |
| Blender for important assets; landscape in Blender (modular, streaming-friendly, simplified collision) | **57 new Blender assets** (`blender/assets/survival_wars.py`): cliff faces, cave arch + modular tunnel segment + chamber cap, riverbank straight/bend, modular 32×32 forest-floor and clearing ground sections, trail strip, roots, flowers, sapling, 2 spruces, aspen, scrap pile, coal/iron ore, 4 chests, 14 POI buildings, 7 tools, 3 storage tiers, scrap/metal walls, floor, 3 traps, Workbench IV/V. POI meshes match the procedural collider layouts; everything falls back to procedural until imported (`Docs/IMPORT.md`). | Blender pipeline, `Export/Meshes/SW_*`, `Renders/ContactSheet_SW_*` |
| Optimise: streaming, LOD, efficient collision | All new models `Atomic` streaming; decorations are single MeshParts; LOD1 FBX exported for the large assets; colliders are single boxes; nodes/POIs use part budgets | `Decor`, `Landmarks`, Blender LOD |

**Decision D49 (landscape):** the match map stays **voxel terrain generated from the layout** (seamless collision,
StreamingEnabled chunking, per-match randomisation), dressed with Blender landscape pieces (cliff faces, riverbanks,
cave kit, trail strips). A fixed Blender terrain mesh can't follow a map that changes every match. The modular Blender
ground sections (`SM_Ground_Forest01`, `SM_Ground_Clearing01`) are for hand-built areas such as the lobby (Phase 7).

**Decision D50:** fixed a latent bug: rotated landmarks faced the wrong way in two sectors (`rotateList` now turns
yaws with the same handedness as positions; covered by `LayoutGen.spec landmark_yaw_follows_rotation`).

**Tests:** `LayoutGen.spec` (POI fairness per sector, rarity mix, yaw); `Loot.spec` (new tiers, rare components only
Rare+); skins suite builds all 14 POIs, the cave, all chests, decor, ore nodes and checks every new mesh is applied
(32 checks, library data regenerated from the catalog by `tests/skins/make_library_data.py`).

## Phase 6: meta progression (done, not yet playtested)

| Spec rule | Change | Where |
|---|---|---|
| Account XP / levels to 100; cosmetics, not power | `Progression`: XP per level 150 + 20·(L−1) (level 100 ≈ 112k XP); every 5 levels +100 Coins, every 10 levels +1 ◆; level-reward titles/nameplates at 5/10/25/50/75/100 | `Shared/Progression`, `Logic/ProfileRules` |
| XP / Coins sources (spec working targets) | Survive a night 50 XP / 10 C · kill 50 / 15 · elimination 100 / 30 · snuff a fire 150 / 40 · Workbench V 200 · 2nd place 250 XP / 100 C · win 500 XP / 250 C / **exactly 2 ◆** · 3rd 50 C. Extras (tunable): POI discovered 15 XP, wildlife 5/10 XP, chest 10/25 XP. Anti-farm: max 2 kill rewards per victim, 25 wildlife rewards per match; nothing in under-filled live matches | `PowerupService.Reward`, `MatchService.End` (placements by elimination order) |
| Coins buy cosmetics in the spec bands | 11 types: outfits, tool/weapon skins, backpack skins, campfire/workbench/storage skins, nameplates, titles, emotes, elimination effects, victory poses. Prices tested against the bands. | `Shared/Cosmetics`, `CosmeticService`, Lobby **Locker** |
| Daily / weekly bonuses | Daily 50 Coins +20 per consecutive day (max 150); weekly after 3 matches: 300 + 75 per win (max 750) | `ProfileRules.ClaimDaily/ClaimWeekly`, Lobby **Profile** |
| Diamonds buy classes and power-ups | 7 classes (Survivor free … Tracker 200) and 10 power-ups (Strong Back 40 … Second Wind 200), one of each, **locked at match join**. Effects are sidegrades through existing hooks: tool speed/wear, stamina, sprint, heal time, pack slots, search/breach speed, breach noise, extra hide, wildlife damage, fire fuel, craft time, senses. Second Wind is automatic (once per life below 25 HP). Active abilities are gone. | `Shared/Classes`, `Shared/Perks`, `PowerupService` |
| Senses without wallhacks | Hunter: wildlife within 70 studs on the map; Scavenger: containers within 40 studs; Tracker: blood trails of injured players (4 s delayed) + "someone got hurt to the NE" cues; Miner/Night Owl: slight local brightness in caves / at night | `PowerupService._sense`, `Map`, `Hud`, `Effects` |
| Crafting takes time (Craftsman −10%) | Crafting is now a 1 s + 0.5 s × tier channel, interrupted by damage or moving | `CraftService`, `Config.Craft` |
| Robux: Coin packs + cosmetic bundles only | Coins500/1200/3000/7000 and Founder/Ember bundles on sale; everything else stays off sale; owned bundle items refunded as Coins | `Products`, `ProfileRules.ApplyReceipt`, Lobby **Shop** |
| Leaderboards | OrderedDataStores (Wins, XP) written after each match, top 10 cached every 2 min, pcall everywhere | `DataService` |

**Decision D51 (profile v2):** the six three-level powerups and their challenges are retired. `Reconcile` refunds the
Diamonds spent on them (unlock + upgrade prices) once, when a v1 profile first loads; old Robux receipts still resolve
(legacy kinds). `ChallengeRules`/`Powerups` modules and their tests were removed.

**Decision D52:** Coins are granted live during the match (leaving early keeps them); placements are granted once per
MatchId at the end. The end screen shows place, XP, Coins, ◆ and level-ups.

**Tests:** `ProfileRules.spec` rewritten (15 cases: receipts, bundles, v1 refund, classes, perks, cosmetics, XP/levels,
placements once, daily streak, weekly), `Progression.spec` (8), `Cosmetics.spec` (6: bands, unique ids, bundles,
class/perk prices and effect keys, Robux sells only Coins/bundles). 131 unit tests pass.

## Phase 7: lobby refuge, UI, lighting, audio, docs (done, not yet playtested)

| Spec rule | Change | Where |
|---|---|---|
| Aesthetic forest-refuge lobby with integrated stations | Lobby rebuilt as a golden-hour clearing: layered forest ring (canopy / mid / undergrowth via mesh-first `Decor`), Blender forest-floor and clearing sections (off the paths), gathering deck round the fire, Blender stalls for the **Trading Post** and new **Outfitter** (cosmetics, with a mannequin), party area, **Ready arch**, class stands at the **Class Shrine**, six signposts and 16 path lanterns. New **Hall of Fame** station with a live leaderboard board. All props sit over the procedural lobby, which keeps every collider, prompt and label (falls back cleanly without the pack). | `Models/Refuge.luau` (new), `WorldService.BuildLobby`, `LobbyService._board` |
| Cinematic menu, cohesive UI | Title screen on first join: a slow camera orbit over the refuge fire with the title and "ENTER THE REFUGE". Lobby nav reorganised (Party · Class · Power-up · Locker · Profile · Shop · ?); the top bar shows level, ◆, Coins and loadout. | `Controllers/Lobby.luau` |
| Day / sunset / moonlit night / fog | Lighting presets Dawn → Day → Sunset (from 72 % of the day, with a banner) → moonlit Night; each tunes fog, atmosphere density/haze/colour and colour grade. The lobby uses a golden-hour preset. | `Config.Lighting`, `WorldService.ApplyLighting`, `MatchService._enterPhase`, `Hud` |
| Audio: ambience, surfaces | Context ambience (lobby / day / night / cave), sunset / reward / level-up / purchase / hurt-cue stingers, per-floor-material footstep slots that replace the default running sound once licensed clips are set. No asset ids invented. | `Sounds.luau`, `Controllers/Sound.luau` |
| Docs | GDD rewritten for Survival Wars; STATUS, README, SETUP (Coin products, leaderboards, schema v2, audio slots), MESH_SKINS (lobby props placed), TUNING (lighting + generated meta tables via `tools/gen_meta_tuning.luau`) | `docs/` |

**Tests:** skins suite +2 (refuge dressing with the pack: forest density, deck, ready arch, ground sections avoid
paths, station props, class stands, six signs, board; and without the pack everything stays procedural) → 34
checks. It caught a shadowed-local bug in the Hall of Fame board before commit.

## Continuation notes

- Every phase is implemented but **none has been playtested**. First Studio session: work through TESTING.md, import
  the Survival Wars FBX set (Docs/IMPORT.md), then tune economy numbers (Progression, Cosmetics prices, yields).
- Classes and power-ups live in `Shared/Classes` / `Shared/Perks`. The effect keys are consumed only in
  `PowerupService` (the list of known keys is enforced by `tests/Cosmetics.spec.luau`).

## UI button kit (from docs/ui/button_reference.png)

`src/client/UI/Buttons.luau` implements the six reference styles in code (no image assets): big primary
(ENTER THE REFUGE, READY UP with searching/ready states), menu tiles (icon + title + subtitle), round mobile
buttons (ATTACK red, AIM/BLOCK blue, HEAL green, SWAP, RUN), small action buttons with Coins / Diamonds / Robux
prices, tabs (Locker categories) and icon-only buttons (✖ ◀ ▶ +). Every style has Normal, Hover/Pressed (green
rim + glow), Disabled (grey, ignores clicks) and Selected/Equipped (gold rim + ✓). `UI.button` now draws in the kit
style too, so every older button (inventory, crafting, storage, spectate...) matches. Panels switched to the
reference's dark steel-slate; the equipped hotbar slot uses the gold "selected" rim.

## Final polish pass (see docs/POLISH_AUDIT.md)

| Area | Change | Where |
|---|---|---|
| Harvest / impact VFX | Fixed missing client handlers for ResourceHit/ResourceBreak/PourStart. Pooled emitters for chips, stone, leaves, dust, sparks, water, steam and blood. Rock/bush jolt. Effects for feeding the fire, Workbench upgrade and building. | `Controllers/Effects`, `GatherService`, `CampService`, `CraftService`, `BuildService` |
| Animation | Mine, Breach, Craft (one-shot and channel), Build/Repair, Feed poses. Alternating light swings and wide heavy swings. Bow draw and ranged ready poses. Reaction layers for hit flinch, block impact, guard break, equip, air and landing, sprint lean and exhausted breathing. | `Controllers/Animation`, `Util.SetAction`, `CombatService` |
| Movement / camera | Eased sprint acceleration; one eased FOV target (aim, sprint +6, damage punch); tiny damage roll; exhausted and low-health grade | `PowerupService`, `Controllers/Camera`, `Config.Camera.SprintFovBonus` |
| Campfire | Fuel bar with low/critical states, critical banner, starving flame colour (skins respected) | `Hud`, `CampService`, `Models/Camp` |
| Day / night | Afternoon lighting step | `Config.Lighting.Afternoon`, `MatchService` |
| UI motion | Panel pop-in, button press squash, notification pop and fade, lobby profile card with count-up currencies | `Panels`, `UI/Buttons`, `Notifications`, `Lobby` |
| Onboarding | Survival Guide objective tracker plus contextual one-off tips | `Controllers/Guide` |
| Death / spectate | Eliminated players get a Return to Lobby button (server-validated `LeaveMatch`); spectate arrows use the kit | `Spectate`, `MatchService._onLeaveMatch` |
| Wildlife | Hit flinch, idle breathing and look-around, prey grazing, topple-over death, impact effect | `Creatures`, `WildlifeService.Damage` |
| Protection / victory | Golden shimmer while spawn or sunrise protected; slow orbit camera for the winner | `Effects`, `Camera.Victory` |

## Polish + animation + fun pass

**Inspected:** the full loop from title → lobby → match → end → lobby, looking at the moments that decide whether
players keep playing: rewards, upgrades, the campfire, Final Life, exploration pull, night atmosphere and animation
gaps. No locked numbers were changed.

| Goal | Change | Where |
|---|---|---|
| Loot feels rewarding | Chest item reveal card, framed in the rarity colour; rare chests get a bolder frame, longer hold and a stronger sting. Rare chests also get a coloured flare | `LootService`, `Hud.LootReveal`, `Sound`, `Effects` |
| Upgrades feel significant | Team banners for "⚒ WORKBENCH TIER III" and "🔥 CAMPFIRE LEVEL 3", a spark column when the fire upgrades, the upgrader's animation, and a level-up sting | `CraftService`, `CampService`, `Hud`, `Effects`, `Sound` |
| Final hit satisfaction | The last chop or mine on a node throws 2.5× the chips plus a dust burst | `Effects` |
| Campfire tension | Your fire going out: a dark-red flash plus a "YOUR FIRE IS OUT" banner. A snuff attempt: a red flash plus an alarm | `Hud.Flash`, `Sound` |
| Final Life | A thin, slowly breathing red frame round the screen edge while alive on Final Life (never covers play) | `Hud` |
| Tool break | Splinter and spark burst, a feed line, and the break sound | `InventoryService.Wear`, `Effects`, `Hud` |
| Exploration pull | Smoke columns over lived-in POIs by day and lantern glow at the larger sites by night: things seen through the trees that make players wonder | `WorldService._poiBeacon` |
| Night soundscape | Occasional distant howls and growls from a random far bearing (atmosphere, never a real position) | `Sound` |
| Animation | Eating (hand to mouth), a weapon-ready idle (weapons carried forward, tools relaxed), crossbow reload after firing, and prey startle (head up) before bolting | `Animation`, `Creatures`, `WildlifeService` |

| Kill feedback | The attacker gets a centre "⚔ YOU DOWNED …" / "✖ ELIMINATED …" confirm; the victim's respawn screen says who or what killed them | `LivesService` (`KillerId`), `Hud` |
| Match recap | End screen adds a personal line: day reached, kills, animals, chests (tallied even when rewards are off) | `PowerupService.Stats`, `MatchService`, `Hud.showEnd` |
| Gamepad | Inventory (Y), Craft (D-pad up) and Build (D-pad down) were unreachable on a controller; now bound. Stale "ability" key notes removed from the controls header | `Input` |

## Model polish (20 meshes)

Reworked the roughest pack models (Survival Wars chests, storage, walls, Workbench IV/V, seven POIs and three held tools) in `blender/assets/survival_wars.py`. Every model keeps its published bounds and pivot (`tools/check_bounds.py`), so `AssetIds.luau` is unchanged and old or new uploads both fit. `verify_exports.py`: 368 files, 0 issues. The new versions need uploading over the same asset IDs: see `docs/MODEL_REUPLOAD.md`. Checked and left alone: the flame mesh (the game uses particle fire), wildlife rigs (creatures are procedural), and the leaf-litter/moss "dark rim" (a Blender-only preview artifact from downward faces that Roblox culls).

## Content, depth & replayability pass

**Inspected first:** care packages already fall every day (announced, contested), rain weather existed, daily and weekly login bonuses existed, the Tracker class already gets hurt cues, there was a guide for new players, and `Profile.Stats` existed but nothing fed it. None of that was rebuilt.

| Area | Change | Where |
|---|---|---|
| Match conditions | One subtle twist per match (70%), announced after the intro: Misty Valley, Rainy Season, Restless Wilds, Hungry Predators, Lost Survivors. Each stays within ~20% of normal and never changes rules | `Logic/MatchEvents`, `EventService` |
| Random events | Thunderstorm (dark, closed-in fog, slanted rain, lightning with distance-delayed thunder), heavy fog, wolf surge at night (real-direction howls as the clue), deer migration by day (herd walks across the map), survivor cache (unlit chest, a trail of dropped gear, a vague "near the ranger station" hint, bonus Rare roll). Never before 150 s into Day 1, one at a time, 150-300 s quiet gaps, no repeats back to back. Campfires, lives and combat are untouched | `EventService`, `WorldService.SetWeather`, `WildlifeService.SpawnGroup`, `LootService.AddCache`, `Weather`, `Sound`, `Hud` |
| Weather | Clear / Cloudy / Rain / Storm / Fog grade the server lighting preset instead of replacing it | `WorldService.ApplyLighting` |
| Endgame tension | "Survivor eliminated, N remain" banners; FINAL THREE and FINAL TWO moments (flash, sting, ambience settles lower and slower) | `MatchService.CheckOutcome`, `Hud`, `Sound` |
| Dangerous Survivor | Kills, eliminations and snuffed fires build notoriety; at two thresholds everyone hears the name. Never a position | `PowerupService` |
| Match recap | End screen: match length, day reached, takedowns, wildlife, resources, damage dealt/taken, fires snuffed, storage breached, places discovered, Workbench tier | `PowerupService.Stats/Tally`, `MatchService.End`, `Hud.showEnd` |
| Records | Lifetime stats in Profile (win rate, best streak, nights, wildlife, bears, fires, breaches, resources, places, crafts), shown in the Profile panel only | `PowerupService.CommitMatch`, `DataService.Push`, `Lobby` |
| Challenges | 3 daily + 2 weekly gameplay challenges, the same for everyone, Coins only. Progress = lifetime stat now minus a snapshot taken when the period started, so there's no extra tracking to break | `Logic/Challenges` (tested), `LobbyService` `ClaimChallenge` |
| Badges | First Night, First Blood, Fire Extinguisher, Explorer (25 places), Bear Hunter, Survivor, Untouchable (win, never on Final Life), Final Stand (win after your fire went out), Master Crafter. Silent until ids are filled into `Config.Badges` | `Util.AwardBadge` |
| Tracking | Work noise carries: chopping 220 studs, felling 320, building 180, breaching 300, shots and explosions 450 (default is 120) | `Sounds` (`Range`) |
| Campfire smoke | A smoke column above the canopy grows with fire tier and turns dark and heavy when the fire starves. A strong fire is also a beacon | `Models/Camp` |
| Trophies | Bear pelts (up to 2), a wolf pelt, a raid banner and an explorer's map appear on posts behind your fire. Visual only, reset every match | `CampService.AddTrophy`, `PowerupService` |
| Spectator | Bar shows FINAL LIFE for the watched player, survivors left and day/night; still locked to living players | `Spectate` |
| Dev | Studio DEV panel can force each event | `DevService`, `Dev` |

**Deferred or rejected (and why):**
- Secret locations (waterfall cave, crash site), multi-room mines, branching caves and POI variants with cellars: these need map-layout work that can only be validated by walking it in Studio. Colliders and nav would otherwise be guesses.
- Contextual music: no licensed tracks yet. The Final Three ambience shift and the event stings cover it until audio is chosen.
- Rare wildlife variants, practice range, cosmetic preview, base decorations: lower value than the loop items above. The camp trophies cover the bragging-rights part.
- Rare match items: the survivor cache's bonus Rare roll delivers the "not every match" loot moment with existing items. New items need balance playtesting first.

**Tested:** 158 unit tests (new: `MatchEvents`, `Challenges`), 34 skins/lobby checks, type check clean, Rojo build OK. Not playtested in Studio.
