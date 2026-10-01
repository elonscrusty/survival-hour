# Headless integration harness: results

**This is an offline MOCK of Roblox, not Roblox.** It runs the real game scripts (server
`Main.server.luau` + services + World, every client `Main.client.luau` + UI, menus, controllers,
visuals, and the test place's `TestSetup`/`DevPanel`) inside the Luau CLI against a hand-written
Roblox API mock. A pass here means the game logic, wiring and UI code paths behave as expected
under the mock's rules; it does **not** replace a Studio playtest (see "What the mock does not
model").

## How to run

```bash
bash tools/headless/run.sh                         # every scenario (perf takes ~7 min wall)
bash tools/headless/run.sh fresh_player_tutorial menus_route
python3 tools/headless/run.py --list
python3 tools/headless/run.py perf_large_population --set SECONDS=60 --set PROFILE=1
# offline images (after the render_dump scenario has written tools/headless/out/*.json)
python3 tools/headless/run.py render_dump
python3 tools/headless/render_world.py --samples 16   # Blender bpy, Cycles CPU, 960x540
python3 tools/headless/render_ui.py                   # PIL layout sketches
```

Output lines are `PASS` / `FAIL` / `NOTE` with the observed values in brackets, then a
"mock diagnostics" block (runtime errors in game threads, `warn` output, properties written that
the mock does not model, property type errors, network serialization warnings) and
`RESULT <passed> passed, <failed> failed, <errors> runtime errors`. Logs: `tools/headless/out/`
(git-ignored). Exit code 1 if any scenario has a FAIL, a runtime error or crashes.

Tools: Luau CLI (`/tmp/sh-tools/luau/luau`), Rojo (`rojo sourcemap test.project.json`), Python 3,
Blender `bpy` 5.0.1 (world renders only), Pillow (UI sketches only).

## How it works

| File | Role |
|---|---|
| `tools/headless/run.py` | Runs `rojo sourcemap test.project.json --include-non-scripts`, embeds every script's source and the project's `$properties`, concatenates the mock + `scenarios/_lib.luau` + one scenario into a single Luau chunk, runs it, and writes `@@FILE` blocks to disk. |
| `mock/00_types.luau` | Vector3, Vector2, CFrame (full rotation math, lookAt, Angles, Lerp...), Color3, UDim/UDim2, sequences, TweenInfo, deterministic `Random`, `Enum`, `typeof`. |
| `mock/10_sched.luau` | Manual clock (`workspace:GetServerTimeNow()`, `os.clock`, `os.time`, `tick` all follow it), execution contexts, cooperative scheduler (`task.spawn/defer/delay/wait/cancel`), signals, per-context CPU accounting, optional per-handler profiler. |
| `mock/20_instance.luau` | Instance tree: ~120 classes with defaults, Parent/children/Find*/WaitForChild/GetDescendants/Clone/Destroy, attributes (+ changed signals), property-changed signals, Model pivots/bounding boxes, ownership + client overlays (replication model below). Reading an unknown member raises "X is not a valid member of Y"; assigning a wrong type raises "Unable to assign property". |
| `mock/30_services.luau` | DataModel/services, RunService (Heartbeat/RenderStepped per frame), Players + fake Player objects + simple characters (HumanoidRootPart you can move or walk at WalkSpeed), RemoteEvent/RemoteFunction over a simulated network (30 ms one-way latency, payloads copied like Roblox serialization and flagged when mixed/sparse/function-valued), ProximityPrompt triggering, instant TweenService, Debris, MarketplaceService stub (records prompts, never buys), UserInputService/GuiService/ContextActionService stubs, per-client following camera. |
| `mock/40_loader.luau` | Builds the DataModel from the sourcemap, `require` by instance and by string (`./`, `../`, `@self`) with one module cache per context, runs server Scripts, copies StarterPlayerScripts into each player's PlayerScripts and runs the LocalScripts there. |
| `mock/50_harness.luau` | GUI layout engine (AbsolutePosition/AbsoluteSize), JSON, world/UI dumps and the scenario API `H` (boot, join/leave, run code as a client, click buttons, press keys, walk/teleport, trigger prompts, dev commands, checks). |
| `scenarios/*.luau` | The scenarios below. `_lib.luau` holds shared helpers. |
| `render_world.py`, `render_ui.py` | Offline renderers for the dumps. |

**Contexts and replication.** The server and each client run in their own context: separate
module caches (every client gets its own copy of every client and shared module), their own
`Players.LocalPlayer`, `RunService:IsClient()`, camera and input state. All contexts share one
instance tree (ReplicatedStorage, Workspace, the plots), which stands in for replication.
Instances a client creates (its GUIs, `Workspace.FarmVisuals`, beams) are invisible to the server
and to other clients. A client writing a property or attribute of a server instance writes a
client-local overlay (e.g. `Prompts` disabling other players' board prompts only on that client).
The test place mapping (`test.project.json`) is used, so saves go to the in-memory store and
Robux purchases go through the simulated checkout.

## What the mock does NOT model

- **Physics**: nothing falls or collides; characters stand where they are put and walk in a
  straight line at `Humanoid.WalkSpeed`; raycasts return nil; no Touched events.
- **Rendering**: nothing is drawn. GUI geometry comes from an approximate layout engine (UDim2,
  UIScale, UIPadding, size/aspect constraints, list/grid layouts, AutomaticSize, safe-area insets
  of 58 px top bar plus phone notches); text width is estimated at 0.55 x TextSize per
  character; rotation, images and rich text are ignored.
- **Networking**: one process, fixed 30 ms one-way latency, no bandwidth limits, packet loss,
  remote throttling or StreamingEnabled. Server property changes are visible to clients at once.
- **Signals** fire immediately (Roblox's default is Deferred); tweens complete instantly.
- **DataStores / ProfileStore**: never touched (the production adapter is not exercised).
- **Real input**: a "tap" fires InputBegan, MouseButton1Down/Up, InputEnded, Activated and
  MouseButton1Click on the button; hit testing is limited to "button visible" plus "not covered by
  a visible full-screen Modal button on a higher layer". Keys go through ContextActionService
  bindings only.
- **Timing**: CPU numbers are Luau-CLI time inside the mock, where every Vector3/CFrame is a Lua
  table and every property access goes through a metatable. Use them to compare runs, not as
  phone frame times.

## Scenario results (latest run)

Run on 2026-10-01 against the current `egg-farm/` tree. Totals after the coordinator's fixes: **all scenarios pass, 0 runtime errors** across 9 scenarios (`smoke` is a 3-check boot
test). Every scenario also reported no unmodelled property writes, no property type errors and
no network serialization warnings (no mixed/sparse tables or functions in any remote payload).

### a. fresh_player_tutorial: 35 PASS
One new player, driven only through the client's real UI paths (HUD buttons, tab buttons, row
purchase buttons, a world board ProximityPrompt).
- Plot 1 claimed (`OwnerUserId` = 1001), character spawned 3.5 studs from `Plot1.Spawn`,
  `RespawnLocation` = that spawn.
- Step 1 HUD: only SPAWN visible; banner "TUTORIAL  1 / 7"; the tutorial arrow sits over SPAWN.
- 24 taps on the SPAWN button -> 24 `spawn` requests -> population 24/100 -> step 2; counters revealed.
- After 12 s House1 held 34 eggs (lay rate 2.4/s); walking into House1's CollectRing -> carried 39/100
  -> step 3; walking into the DepositRing -> basket emptied, 40 deposited -> step 4.
- First vehicle sale at t = 28.3 s ($40) -> step 5; the Farm button appears; the Farm panel opens
  with only the Shipping tab visible.
- Farming loop until cash >= $300 (t = 174 s), Vehicle 1 upgrade button -> tier 2 (1 request) -> step 6.
- $500 reached at t = 357 s -> step 7 (Housing + Shipping tabs visible, Workers/Silos hidden).
- Triggering the `Housing` board prompt (slot 1) opens Farm > Housing; upgrading House 1 ($250)
  -> `tutorial.done`; navigation, Auto, all Farm tabs revealed; tutorial overlay disabled.
- Simulated time to finish the tutorial: **363 s**. PlayerGui instances: 1627.

### b. two_player_isolation: 21 PASS
- Alice -> Plot 1, Bob -> Plot 2, both spawned on their own plot.
- Alice standing in Bob's CollectRing for 3 s collects nothing (Bob's House1 kept growing 39 -> 74);
  standing in Bob's DepositRing deposits nothing.
- Alice's dev commands (cash/gold/tutorial) and 10 actions (spawn, upgrades, buys, settings,
  code, daily, auto spawn, a forged action naming Bob's plot/userId) leave Bob's farm byte-identical
  and Bob's plot attributes at `1,0,0,0`.
- Bob's board prompt is disabled on Alice's client (stays enabled for the server); a forced
  `PromptTriggered` opens nothing for Alice. Bob's Lucky Fox: disabled on Alice's client, a forced
  trigger by Alice is refused by the server, Bob catches it (+$200).
- Alice's client cannot see Bob's PlayerGui; each client has exactly one own `FarmVisuals`; the
  server sees none.

### c. menus_route: 48 PASS
- Each HUD nav button (Shop, Eggs, Quests, Settings, Daily, Boosts, Gifts, Upgrades, Farm) opens
  exactly its panel with the dimmer; every tab button switches tabs (Shop 4, Boosts 2, Upgrades 2,
  Farm 4); other HUD buttons can't be tapped through the dimmer; Close closes.
- Shop -> Codes -> Back returns to Shop. All 18 menu/tab targets via `Host:Open` open alone with the
  right tab. All 10 menus built without errors.
- While a menu is open SPAWN sends nothing and `ProximityPromptService.Enabled` is false on that
  client only.
- Three rapid taps on a purchase button (two in the same frame, one a frame later, 30 ms latency)
  -> **exactly one** request and one level bought; a later tap sends a fresh request.
- Boosts SHOP with Confirm Gold Eggs on: confirm modal first (0 requests), confirm double-tapped
  -> 1 request, -20 Gold Eggs, modal closed. Backspace closes the open menu.
- Epic upgrades (Gold Eggs) open the Confirm Gold Eggs modal first and send no request until confirmed (added after the first run found they bought on tap).

### d. progression_rebirth: 15 PASS
- Upgrades update plot attributes (`HouseTiers 3,1,0,0`, `VehicleTiers 1,1,...`, `Silos 1`) and
  rebuild House1 (18 -> 21 parts).
- Fixture `egg 1` (Farm Value = goal 100,000) -> Eggs panel REBIRTH -> confirm modal (35 text
  lines listing rewards/resets/keeps, no request yet) -> Rebirth -> egg 2 with one request, panel closed.
- Every `State.RESET_FIELDS` entry equals a fresh farm; every `KEPT_FIELDS` entry unchanged;
  +30 Gold Eggs (= egg 2's rebirthGold). Plot `Egg` = 2, houses back to `1,0,0,0`, 272 parts recoloured.
- Leak check, 4 cycles of (fixture egg 2 + maxed -> rebirth to egg 3): plot descendants
  663 maxed / 591 fresh **every cycle**; client `FarmVisuals` descendants 14 every cycle.

### e. reconnect_and_saves: 14 PASS (after the MemoryAdapter fix below)
- Leave saves to the memory store and releases the lock and plot; rejoin restores the same farm
  (cash 999,050, houses 2,1,0,0, vehicle tier 2, code EGGFARM kept: re-redeeming says "already").
- `failload` then rejoin: kicked with "We couldn't load your farm safely, so nothing was changed.
  Please rejoin in a moment.", no plot held, save byte-identical; the next rejoin loads normally.
- `failsave` then leave: the retry saves the latest farm (houses 2,2,0,0) and unlocks; rejoin has it.
- 4 failed saves in a row: gives up (`[Data] release ... save failed` warning), lock released,
  previous copy intact, immediate rejoin works.

### f. shop_codes_boosts: 26 PASS
- Before the tutorial a code is refused ("Finish the tutorial first!").
- Shop > Passes > x2 Cash (R$ 249), double tap -> one Commerce call, pass granted, receipt
  `TEST-x2cash-1`, button shows OWNED; further taps send nothing; the server answers `owned`.
- Checkout cancel -> nothing granted; fail -> "(Test) Purchase failed. Nothing was charged.";
  success -> +50 Gold Eggs. Commerce refuses Gold-Egg items. No MarketplaceService prompt opened.
- Codes UI: `eggfarm` -> "Code redeemed!" +25; `EGGFARM` again -> already redeemed; `NOPE` ->
  doesn't exist; `TESTEXPIRED` -> expired; blank -> "Type a code first." with no request.
- Boosts SHOP: Cash x3 Boost asks to confirm, -20 Gold Eggs; BOOSTS > USE starts it with
  1199.4 s left on the server clock (sale multiplier 6 = x2 Cash pass x 3); still active at 19 min,
  expired after 20 min; `BoostUsed` and `BoostEnded` reached the client.

### g. perf_large_population: 7 PASS
8 players (full server), every farm at egg 10 `maxed` with all boosts, population 3,200,000
(= capacity), Auto Spawn on, Alice on flock = high; 18,000 frames (600 simulated s at 30 fps),
340 s wall.

| Measure (mock Luau time, see "Timing" above) | avg | p50 | p95 | max |
|---|---|---|---|---|
| Server, per frame (8 farms: 4 Hz economy, 5 Hz zones, snapshots) | 0.30 ms | 0.003 ms | 2.2 ms | 10.4 ms |
| Server, frames that ran a farm tick | 1.10 ms | 0.31 ms | 3.4 ms | 10.4 ms |
| One client, per frame (HUD + visuals, flock = high) | 5.46 ms | 4.99 ms | 11.6 ms | 26.5 ms |
| All 8 clients summed, per frame | 18.3 ms | 17.9 ms | 38.4 ms | 120 ms |

- Client cost by flock setting (same farm, 10 s each): low 1.69 ms/frame, high 5.79 ms/frame.
  A 30 s profiled run put ~98% of client time in the `Visuals` Heartbeat (posing ~120 chicken rigs
  with Lua-table CFrames); HUD/menus/tutorial together were < 0.15 ms/frame.
- Visible chicken rigs: own plot max **120** (= high cap), 24 at low (= low cap); from the
  boulevard, neighbour plots show 4 each (= cap); total max 132 (cap 148). Client FarmVisuals:
  399 BaseParts at flock = low.
- Snapshot remote: 9,675 messages = 2.0 per player per second, avg 2,911 bytes, max 2,935 bytes
  (JSON size of the copied payload). FarmEvent: 7,472 messages, max 52 bytes. Lua heap for the
  whole process (mock + 9 contexts): ~98 MB.

### render_dump: 3 PASS (first run: 2 PASS, 1 FAIL, since fixed)
Writes the world/UI dumps for the images below and checks that visible HUD buttons don't overlap
and stay on screen: OK at 1280x720 and 390x844 (portrait phone), **FAIL at 844x390 (landscape
phone): the left column (Shop/Eggs/Quests) overlaps the bottom-left quick column
(Upgrades/Farm)**, see `offline_ui_hud_844x390.png`. In `Hud.luau` the left column's three 68-logical-px buttons are centred at 44 % of the height and the quick column (Upgrades, Farm) is anchored to the bottom; with a ~300 px tall safe area at UI scale 0.81 (about 367 logical px) Quests spans roughly y 205-273 and Upgrades 211-279. It still overlaps with a smaller 36 px top inset. The layout engine is approximate (insets and text are estimates), so confirm in Studio's device emulator (iPhone landscape) before changing it.

## Bugs found

| Where | Problem | Status |
|---|---|---|
| `src/server/Persistence/MemoryAdapter.luau` (test place saves) | `Release` retried a failed final save by calling `MemoryStore.Release` again, but `MemoryStore.Release` clears the session lock even when its save fails, so every retry answered "session lost" and the player's progress since the last save was dropped. | **Fixed**: retries go through `store:Save` (keeps the lock), then `store:Release`; after 3 failed tries it still unlocks and keeps the last good copy. Unit tests and `tools/check.sh` green. |
| `src/client/Menus/Upgrades.luau` | Epic upgrades (Gold Eggs) didn't use the Confirm Gold Eggs dialog. | **Fixed** by the coordinator: Epic rows ask first when `confirmSpend` is on (menus_route now checks it). |
| `src/client/Controllers/Hud.luau` | Landscape phone: left nav column overlapped the quick column (approximate layout). | **Fixed** by the coordinator: on short landscape screens the quick column sits beside the left column; render_dump passes at 844x390. Still confirm in Studio's emulator. |

No Lua runtime errors, `warn` output (other than the deliberate failed-load/failed-save warnings),
missing instances, wrong require paths or replication-unsafe payloads were found in the code paths
the scenarios exercise.

## Offline images

All images are offline renders of what the real World/Models/Visuals code generated inside the
mock (every BasePart's class, shape, size, CFrame, colour, material and transparency), drawn by
Blender Cycles (CPU, 16 samples, 960x540) or PIL. They are **not Roblox screenshots**: no Roblox
lighting, materials, textures, terrain, particles, billboard GUIs or fonts.

| Image | What |
|---|---|
| `docs/screenshots/offline_start_thirdperson.png` | Fresh farm (egg 1 theme) after the first SPAWN taps, camera behind the character at the plot spawn. |
| `docs/screenshots/offline_start_aerial.png` | Same state from above the boulevard. |
| `docs/screenshots/offline_late_thirdperson.png` | Maxed farm on egg 7 (different theme), houses tier 9, vehicles tier 7, workers, 5 silos, flock = high. |
| `docs/screenshots/offline_late_aerial.png` | Same from above. |
| `docs/screenshots/offline_ui_tutorial_1280x720.png`, `..._390x844.png` | HUD at tutorial step 1 (only SPAWN, banner, arrow). |
| `docs/screenshots/offline_ui_hud_1280x720.png`, `..._390x844.png`, `..._844x390.png` | Full HUD after the tutorial (desktop, phone portrait, phone landscape). |
| `docs/screenshots/offline_ui_farm_1280x720.png`, `..._390x844.png` | Farm > Housing panel open. |

UI images are rough 2D layout sketches (boxes, colours, strokes, estimated text) over a flat
sky/grass stand-in; icons appear as their component frames.
