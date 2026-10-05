# Pet Expedition: system contracts

Server, client and models are built separately. This file pins how they connect. Shared data:
`src/shared/{Config,Areas,Pets,Eggs,Products,Net,Types}.luau`.

## Game loop (one paragraph)
Players walk across 6 islands (Meadow → Starfall, laid out along +X). They hatch eggs at egg stands
(coins, or gems for the Prism Egg) and equip their best pets (3 + bonuses). Tapping a breakable (coin pile,
crate, chest, gem rock, big chest) sends their equipped pets to attack it; damage comes from pet power, and
coins/gems are credited when it breaks (split by damage dealt). Coins open gates to the next island.
**Expeditions** are the idle loop: from the Expedition Board, a player sends up to 3 unequipped pets to an
opened island for 5 min / 30 min / 2 h / 8 h. They come back with coins, sometimes gems, free eggs, and a
chance at that island's expedition-only pet. Timers run on `os.time()`, so they finish while offline.
Other systems: Golden/Rainbow crafting (5 → 1), pet levels, rebirth (resets coins and gates for a
permanent coin bonus), daily streak, playtime gifts, 3 daily quests, Index (collection) rewards, trading,
boosts and game passes.

## Ownership
| Area | Owner |
|---|---|
| `src/shared/*.luau` (data above), `docs/CONTRACTS.md`, `tools/`, `tests/run.luau`, `tests/Data.spec.luau` | integrator |
| `src/server/**`, `src/shared/Logic/**`, `tests/<Logic>.spec.luau` | server pass |
| `src/client/**` | client pass |
| `src/shared/Models/**`, `models/**`, `renders/**`, `tests/Models.spec.luau` | models pass |

Do not edit files you don't own. If a contract change is needed, note it in your final report.

## Requires
String requires relative to the module (`require("./X")` = sibling, `require("../Config")` from
`Logic/`). Code in `src/server`/`src/client` reaches shared modules via
`game:GetService("ReplicatedStorage"):WaitForChild("Shared")`. Logic modules must not use Roblox types
or services (they run in the CLI Luau for tests). No Color3/Vector3 in `Config`.

## Remotes (`Net.luau`)
- RemoteFunctions return `{ ok = true, ... }` or `{ ok = false, err = "readable reason" }`. Payloads
  listed next to each name in `Net.luau`. The server validates every argument type and range, rate-limits
  per player per remote, and never trusts client values for prices, rewards or odds.
- `State` (server → client): full `Types.PlayerState` snapshot. Sent on `ClientReady` and after any change
  (coalesced, at most ~5 per second).
- `Notify(kind, data)` kinds:
  - `Toast` `{ Text, Tone = "good"|"bad"|"info" }`
  - `Reward` `{ Coins?, Gems?, Position? (Vector3) }` (pickup popups when a breakable breaks)
  - `Broken` `{ Id, Kind, Position }` (break effect, sent to everyone nearby)
  - `LevelUp` `{ Uid, Level }`
  - `Discovered` `{ PetId }` (first time a species enters the player's Index)
  - `ServerLuck` `{ By, Until }` (broadcast)
  - `Purchased` `{ Name }`
  - `TradeRequest` `{ FromUserId, FromName }`
- `Trade(view: TradeView?)`: the open trade window; nil closes it.
- `SetTarget(breakableId?)`: client → server. Server checks the breakable exists, is within
  `Config.MaxTargetDistance` of the character and is on an island the player has opened.
- `ClientReady()`: client → server once UI is ready.

## Replicated attributes (for rendering other players' pets)
- `Player:GetAttribute("Pets")`: JSON string (HttpService) array of `{ Uid, Id, Variant, Shiny }` for the
  player's equipped pets. Updated by the server whenever equipment changes.
- `Player:GetAttribute("Target")`: breakable id string the player's pets are attacking, or `""`.
- `Player:GetAttribute("Vip")`: boolean.
- Breakables live in `workspace.Breakables` as Models tagged `Breakable` with attributes `Id`, `Kind`,
  `Area`, `Hp`, `MaxHp`. The server updates `Hp`; it destroys the model on break.

## World (`Models/World.luau`, built by the server at boot)
`World.Build(): WorldInfo` creates `workspace.World` and returns
`{ Spawns = {[areaId]=CFrame}, Zones = {[areaId]={ {Center:Vector3, Size:Vector3} }}, Bounds = {[areaId]={Min,Max}} }`.
Zones are flat rectangles on the ground (Center.Y = ground top) where the server spawns breakables.
Interactables are tagged with CollectionService and carry a `ProximityPrompt` child (client listens via
`ProximityPromptService.PromptTriggered`, checks the tag on the prompt's ancestor model, opens UI):
| Tag | Attributes | Purpose |
|---|---|---|
| `EggStand` | `EggId` | hatch menu for that egg; the stand shows the egg model on a pedestal |
| `Gate` | `AreaId` | gate into that area; child Part `Barrier` (CanCollide). Client makes it non-collidable locally once the area is opened and hides it. |
| `ExpeditionBoard` | | expeditions menu (Meadow hub) |
| `CraftMachine` | | Golden/Rainbow crafting menu (Meadow hub) |
| `RebirthStatue` | | rebirth menu (Meadow hub) |
| `IndexBook` | | Index (collection) menu (Meadow hub) |
| `AreaBounds` | `AreaId` | invisible, non-colliding box covering the island (client area banner) |
A `SpawnLocation` sits in the Meadow.

## Models (`Models/init.luau`)
- `Models.Pet(petId, variant, shiny): Model`: anchored, CanCollide/CanQuery/CanTouch false,
  PrimaryPart `Root` (invisible), pivot at the bottom centre, facing -Z, roughly 2.5–4.5 studs tall
  (bigger for higher rarity). Golden = gold metallic recolour, Rainbow = cycling/rainbow colours
  (static stripes are fine; the client may animate), Shiny = sparkle ParticleEmitter attached to Root.
- `Models.Egg(eggId): Model` (≈3 studs tall, same pivot rules).
- `Models.Breakable(kind, areaId): Model` (anchored, CanCollide true, themed per area; sizes ≈ CoinPile 3,
  Crate 4, Chest 5, GemRock 4, BigChest 8 studs wide).
All built from primitives at runtime (no uploaded meshes), so they work in Studio immediately.

## Persistence
DataStore `Config.DataStoreName`, key `p_<UserId>`, session-locked (`Config.SessionLockSeconds`),
autosave every `Config.AutosaveSeconds`, saved on leave and `BindToClose`. Receipts are deduped by
`PurchaseId` stored in the profile. In Studio without API access the server falls back to memory.

## Compliance
- Odds are shown for every egg before hatching.
- `PolicyService:GetPolicyInfoForPlayerAsync`: if `ArePaidRandomItemsRestricted`, the player cannot
  hatch the Prism Egg (`CanBuyGemEggs = false`); if `IsPaidItemTradingAllowed` is false, trading is off
  (`CanTrade = false`).
- Trades: both sides must be ready, then a `Config.TradeConfirmSeconds` countdown; any change resets
  readiness. Items move atomically on the server. Locked pets and pets on expeditions can't be offered.
