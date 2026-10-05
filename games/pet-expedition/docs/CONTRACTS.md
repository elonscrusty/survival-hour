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
- Purchases: the client prompts `MarketplaceService` for configured ids (passes and products). For
  Id 0 items in Studio it calls `DevPurchase(key)` instead (the server refuses outside Studio). VIP chat
  tag is applied client-side from the `Vip` attribute (TextChatService).

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

## Pet Ring (walk-in PvP)
A roped sand ring north of the Meadow hub (`WorldInfo.Arena = { Center, Radius }`; an invisible `ArenaZone`
part tagged `Arena` with attribute `Radius`). Walking inside means fighting; walking out is safe.
- **Who fights:** while a player's character is inside (horizontal distance ≤ Radius from Center, |dy| < 12), their
  strongest equipped pets by ring strength fight: `Config.Ring.Fighters` (+`PassFighters` with the `RingChampion`
  pass), capped by how many are equipped. Breakable targeting is cleared on entry and refused while inside.
- **Strength:** `Logic/Ring.Strength(pet, passes...)` per the formula in `Config.Ring`. HP = BaseHp × strength,
  hit = BaseDamage × strength (crits per Config). Paid help (rarer pets, Xp2x boost, the extra fighter) stays
  around 2x at most; levels matter most.
- **Simulation (server):** fighters move on the ring floor (X/Z, server-side positions), pick the nearest enemy
  fighter (or one of the focused player's fighters via `RingFocus`), close to AttackRange and hit every
  AttackInterval. New arrivals have `EnterGraceSeconds` of immunity. A fighter at 0 HP faints and stays fainted until
  its owner leaves. When all of a player's fighters have fainted, the player is pushed just outside the entrance
  and gets Notify `RingOut`. Leaving or dying resets fighters (full HP next time) and the streak.
- **Rewards:** the owner of the fighter landing the KO gets `KoTrophies` and `KoCoins × CoinMult(highest island)`
  (counted only `SameVictimLimit` times per victim per `SameVictimWindow`); every hit gives pet XP `XpPerHit`, a KO
  `XpPerKo` (Xp2x boost doubles all pet XP everywhere). `Stats.Trophies`, `Stats.RingKOs`, `Stats.BestStreak`
  persist; leaderstats shows Trophies.
- **King of the Ring:** the player in the ring with the highest current streak (≥ `KingMinStreak` KOs without
  being bounced out) gets player attribute `RingKing = true` (only one at a time); clients show a crown.
- **Wild challengers:** when exactly one player is inside for `WildDelay` s, a wild pet (random species from that
  player's opened islands, strength `WildStrength` × their average fighter, Owner 0) joins; beating it gives XP and
  `WildCoins` × KoCoins, no trophies. Wild fighters leave when another player enters or the player leaves.
- **Replication:** `ReplicatedStorage.Arena` (Folder) holds one `Configuration` per fighter, named by fighter id,
  with attributes `Owner` (UserId, 0 = wild), `Uid`, `PetId`, `Variant`, `Shiny`, `Level`, `X`, `Z`, `Hp`, `MaxHp`,
  `Target` (fighter id or ""), `Fainted`, `Attack` (increments on every hit, for animation), `Crit` (bool, last hit).
  Updated every `ReplicateSeconds`. Clients render ring fighters at these positions (lerped) instead of the
  normal follow formation; wild fighters are rendered from the same data.
- **Player attributes:** `InRing` (bool), `RingStreak` (number), `RingKing` (bool).
- **Notify:** `RingKO` `{ Killer, Victim, PetId, Position }` (to players within ~120 studs of the ring),
  `RingOut` `{}` (to the bounced player), `RingKing` `{ Name }` (broadcast when the crown changes hands).
