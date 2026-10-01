# Egg Farm architecture

Independent Rojo project in `egg-farm/`. Native Luau, native Roblox UI, no runtime dependencies
except the vendored ProfileStore (server only).

## Places
| Project file | Output | Contents |
|---|---|---|
| `default.project.json` | `build/EggFarm.rbxlx` | The game. Real ProfileStore persistence, real MarketplaceService checkout (no product IDs configured yet, so Robux items show "not for sale yet"). |
| `test.project.json` | `build/EggFarm.Test.rbxlx` | The game plus `ServerScriptService.TestHarness` and `ReplicatedStorage.TestFixtures`: in-memory saves, simulated checkout (success / cancel / fail), developer shortcuts and late-game fixtures. Never ship this place. |

The server picks adapters at start: if `ServerScriptService.TestHarness` exists it uses the test
adapters; otherwise production ones. Test entitlements and saves never touch the real DataStore
(different store, memory only).

## Layers
- `src/shared` (ReplicatedStorage.Shared): contracts and pure rules, run by both sides and by the CLI tests.
  - `Types.luau` FarmState / FarmAction / FarmSnapshot. `Contract.luau` action names, result codes, messages, tutorial text.
  - `Data/*` catalog: Eggs, Themes, Housing, Vehicles, Workers, Silos, Upgrades, Boosts, Rewards, Products. Every number is labelled reference-verified or DESIGN.
  - `Logic/*` pure rules: `Economy` (apply/step/snapshot), `Modifiers`, `Prices`, `Rewards`, `State` (defaults + reset lists), `Tutorial`, `Validate`, `RateLimiter`, `Migrations`, `Flock` (visual cap planner), `MenuRouter`, `PurchaseState`, `PlotRegistry`.
  - `Format.luau` number formatting. `GameInfo.luau` game name (rename here). `Net.luau` remotes.
- `src/server` (ServerScriptService.Server): `Main.server.luau` boots services in order.
  - `Services/FarmService` one Economy per player, 4 Hz step, remote handling, snapshot throttling.
  - `Services/PlotService` plot assignment/release, plot attributes, calls `World` to build/update models.
  - `Services/ZoneService` server-side distance checks for collect/deposit rings and the fox.
  - `Services/DataService` load/save/release through a persistence adapter; kicks on failed loads.
  - `Services/CommerceService` checkout adapter (Roblox MarketplaceService or test simulator) + ProcessReceipt.
  - `Services/FoxService` Lucky Fox spawns.
  - `Persistence/` `ProfileStoreAdapter` (production) and `MemoryStore` (tests / test place).
  - `World/` plot layout and native-part model builders (houses per tier, warehouse, dock, silos, boards, decor, themes).
  - `Data/Codes.luau` redeem codes (server only, never replicated).
- `src/client` (StarterPlayerScripts.Client): `Main.client.luau` bootstraps.
  - `Store.luau` snapshot store + request sender (seq numbers, in-flight dedupe).
  - `UI/` kit (Theme, components, native-drawn icons). `Menus/` every panel. `Controllers/` HUD, tutorial, prompts, sound.
  - `Visuals/` bounded flock, vehicles, workers, effects, theme lighting.

## Remotes (`Net.luau`)
- `Action` RemoteFunction: client sends a FarmAction `{ type, seq, slot?, expect?, id?, index?, text?, value? }`; server replies `{ ok, code, message }`.
- `Snapshot` RemoteEvent: server -> owner, full FarmSnapshot, at most every 0.25 s and only when something changed.
- `FarmEvent` RemoteEvent: server -> owner `(name, data)`. Names: `Collected {slot, amount, full}`, `Deposited {amount}`, `Sold {slot, eggs, cash}`, `VehicleLeft {slot}`, `VehicleBack {slot}`, `Purchased {kind, slot?, tier?, id?, level?, count?}`, `Rebirth {from, to, gold, skipped?, cost?}`, `Prestige {stars, total}`, `BoostUsed {id}`, `BoostEnded {id}`, `Reward {source, granted = {gold?, cash?, boosts?}}`, `Fox {cash}`, `HousingFull`, `BasketFull`, `StorageFull`, `Toast {text, kind}`, `Checkout {productId, status}`.
- `Commerce` RemoteFunction: client asks to buy `{ productId }`; server runs the checkout adapter.

## World contract (names the server and client both rely on)
`Workspace.Plots.Plot<N>` (N = 1..8), a Model with attributes set by PlotService:
`PlotIndex`, `OwnerUserId` (0 = free), `OwnerName`, `Egg`, `Population`, `HouseTiers` ("1,0,0,0"),
`VehicleTiers` ("1,0,0,0,0,0,0,0"), `WorkerTiers`, `Silos`.
Children built by `World`:
- `Houses/House<i>` (Model per slot) containing `CollectRing` (BasePart, the collect zone) and `Anchor` (CFrame where the flock wanders).
- `Warehouse` Model containing `DepositRing` (BasePart).
- `Dock/Bay<i>` parts: vehicle parking CFrames (i = 1..8).
- `Road/P<k>` parts: ordered waypoints vehicles drive out along (and back reversed).
- `WorkerPath` Model: `Start` part near the warehouse.
- `Silos/Silo<i>` models.
- `Boards/*` parts with a `ProximityPrompt` whose attributes are `Menu` ("Housing" | "Shipping" | "Workers" | "Silos" | "Upgrades" | "Eggs") and optional `Slot`.
- `FoxSpots/*` parts: places the Lucky Fox may appear.
- `Spawn` SpawnLocation (players respawn at their own plot).
