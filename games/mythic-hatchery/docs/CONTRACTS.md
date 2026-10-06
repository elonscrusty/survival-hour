# Mythic Hatchery: system contracts

> **October 6 owner revision:** The design below predates the current decisions. Read
> [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) first for the authoritative changes:
> no racing, no Baby/Teen/Adult/Ancient growth or care progression; levels come only from battles.
> Optional PvP uses three creatures with one active, all unlocked moves, one shared move cooldown,
> and a separate longer swap cooldown. Opponents match by team strength. Habitats replace the
> primary coin loop: assigned creatures earn online/offline to a storage cap, collected manually.
> Remove a creature from its habitat before battling or riding. Starter mount can ride and fly
> immediately. Fusion still consumes both parents. Untouched legacy features are not removed by
> this revision. Existing Types/Config and server/client code need a coordinated conversion.

Server, client and models are built separately. This file pins how they connect. Shared data:
`src/shared/{Config,Areas,Species,Elements,Eggs,Potions,Cosmetics,Products,Net,Types}.luau`.
(The game was "Pet Expedition"; pets became creatures. Keep systems, rename pet → creature.)

## Game loop
Players buy eggs (coins at island stands, gems for the Mythic and Limited eggs) and incubate them in
hatch slots (real-time timers, `Config.BaseHatchSlots` + pass). Each hatch rolls a **species** (Dragon,
Griffin, Phoenix, Hydra, Unicorn), **rarity** (Common → Mythic) and **element** (Fire, Ice, Storm,
Nature, Shadow). Creatures grow **Baby → Teen → Adult → Ancient** through care tasks (Feed, Play, Sleep
on cooldown timers); neglect only pauses growth. Two **Adult+** creatures can be **fused** (both
consumed) into a Fused Egg with boosted rarity odds; a cross-species pair may roll a hidden **hybrid**.
Potions (gems) unlock **Ride**, **Fly** and **Neon** per creature. Adult+ creatures with Ride/Fly can be
ridden; fliers race in the **Sky Arena** above the hub. Everything from Pet Expedition stays: 6 regions of one
connected land (element-themed; no islands), creatures farming treasure for coins, gates, expeditions, rebirth, daily/playtime/
quests, Index, boosts, the Creature Ring, trading (creatures only) and the Robux shop. A coin shop sells
cosmetics (hats, auras, saddles).

## Ownership
| Area | Owner |
|---|---|
| `src/shared/*.luau` (data above), `docs/CONTRACTS.md`, `tools/`, `tests/run.luau`, `tests/Data.spec.luau` | integrator |
| `src/server/**`, `src/shared/Logic/**`, `tests/<Logic>.spec.luau` | server pass |
| `src/client/**` | client pass |
| `src/shared/Models/**`, `models/**`, `renders/**`, `tests/Models.spec.luau` | models pass |

## Requires
String requires relative to the module (`require("./X")`, `require("../Config")` from `Logic/`). `src/server` and
`src/client` reach shared code via `ReplicatedStorage:WaitForChild("Shared")`. Logic modules must not use Roblox
types or services (they run in the CLI Luau tests). `--!strict` everywhere, no `_G`.

## Core rules (Logic, server-authoritative)
- **Buying eggs** (`BuyEgg`): egg on sale (`Eggs.OnSale`), player within 45 studs of that egg's `EggStand` (Basic) or
  of the hub (Premium/Limited stands are in the hub), affordable, bag space (`Config.EggStorage`). Gem eggs need
  `CanBuyGemEggs`. Bought eggs go straight into free incubators, the rest into the bag.
- **Incubating**: `EndAt = now + IncubateSeconds × (FastIncubation pass ? 0.5 : 1)`. The hatch result is rolled from a
  `Seed` fixed when the egg enters the incubator, with the luck multiplier at that moment. `Hatch(slot)` after EndAt.
  `SkipIncubation` costs `max(IncubateSkipMinGems, ceil(left/30) × IncubateSkipGemsPer30s)` gems.
- **Rolls** (`Logic/Hatch`): species, rarity, element independently from the egg's weight tables. Element: the egg's
  `Element` table, else `HomeElementWeight`% for the island's element and the rest split evenly. Luck multiplies the
  weight of every rarity above the egg's lowest, renormalised, capped by `MaxLuckMult`.
- **Growth** (`Logic/Growth`): `Care(uid, task)` allowed when `now - Care[task] ≥ Cooldown`; adds `Growth` points
  (×2 with the Growth2x boost); Feed costs `FeedCost × CoinMult(highest island)` coins. Stage = highest stage whose
  `StageGrowth` ≤ growth. Ancient is the cap (growth keeps counting for nothing).
- **Farming power** = `RarityPower × StagePower × Areas[Tier].PowerMult × (Neon ? NeonCoinMult : 1)`, ×`ElementBonus`
  when farming on the island of the creature's element.
- **Fusion** (`Logic/Fusion`): both parents owned, Adult+, unlocked, not equipped-in-ring/riding/expedition/trade,
  different uids; costs `Fusion.CoinCost × CoinMult(highest)`. The Fused Egg's rarity table: the better parent's
  rarity gets weight `1 - upgradeChance`, the next tier `upgradeChance` (Mythic stays Mythic); species table: each
  parent 50%; element: each parent `(1-RandomElementChance)/2`, the rest even; `Hybrid` = `Species.Hybrid(a, b)` with
  `HybridChance`. Tier = max parent tier. Potions and cosmetics on the parents are lost (show a warning).
- **Potions**: `UsePotion(uid, id)` charges gems and sets the flag; no refunds, no stacking.
- **Riding** (`Mount(uid)`): Adult+ and Ride or Fly potion, not busy. Server sets player attribute `Riding` and the
  humanoid WalkSpeed to the ride speed. Flying is client-driven physics on the character (client has network
  ownership), only while riding a creature with the Fly potion; the server samples the root part ~4×/s and pulls
  the player back to the last good position when speed exceeds expected × `SpeedTolerance` or altitude
  > `MaxAltitude`. Dismount on death, trade swap, fusion/release of the mount, or entering the Creature Ring.
- **Trading**: creatures only (gems disabled by `TradeMaxGems = 0`), up to `TradeMaxCreatures` (16 with VipTrader),
  journaled atomic swap (already built), locked/busy creatures refused, potions/edition/growth travel with the
  creature, cosmetics are stripped (they're the owner's).
- **Release**: `ReleaseCreatures` deletes for `max(1, power × DeleteRefund)` coins; all-or-nothing.

## Remotes (`Net.luau`)
- RemoteFunctions return `{ ok = true, ... }` or `{ ok = false, err = "readable reason" }`. The server validates every
  argument's type and range, rate-limits per player per remote, and never trusts client prices, odds or rewards.
- `State`: full `Types.PlayerState` (coalesced, ≤5/s). `Trade(TradeView?)`, `Race(RaceView?)`.
- `Notify(kind, data)`: `Toast {Text, Tone}`, `Reward {Coins?, Gems?, Position?}`, `Broken {Id, Kind, Position}`,
  `StageUp {Uid, Stage}`, `Hatched {Uid}`, `Discovered {Species, Element}`, `HybridDiscovered {Species}`,
  `ServerLuck {By, Until}`, `Purchased {Name}`, `TradeRequest {FromUserId, FromName}`, `RingKO {...}`, `RingOut {}`,
  `RingKing {Name}`, `RaceResult {Place, Time, Coins, Trophies}`.
- Client → server events: `SetTarget(breakableId?)`, `ClientReady()`, `RingFocus(userId?)`, `RaceCheckpoint(index)`.
- Purchases: the client prompts `MarketplaceService` for configured ids; for Id 0 items in Studio it calls
  `DevPurchase(key)` (refused outside Studio).

## Replicated attributes
- `Player.Creatures`: JSON array of the equipped creatures `{ Uid, Species, Element, Rarity, Stage, Neon, Cosmetics }`.
- `Player.Riding`: JSON `{ Uid, Species, Element, Rarity, Stage, Neon, Cosmetics, Fly }` or `""`.
- `Player.Target` (breakable id or ""), `Player.Vip`, `Player.VipTrader`, `InRing`, `RingStreak`, `RingKing`, `Racing`.
- Breakables: `workspace.Breakables` Models tagged `Breakable` with `Id`, `Kind`, `Area`, `Hp`, `MaxHp`.

## World (`Models/World.luau`, built by the server)
`World.Build(): WorldInfo` → `{ Spawns, Zones, Bounds, Arena = {Center, Radius}, Race = { Start: CFrame, Checkpoints: { {Center: Vector3, Radius: number, CFrame: CFrame} } } }`.
Regions of one continuous landmass (Areas ids, along +X): `Meadow` (Nature, hub), `Shadow` (Shadow Grove), `Frost`
(Ice), `Storm` (Storm Coast), `Volcano` (Fire), `Sky` (a high cloud-stone plateau). Gates are archways in natural
barriers between regions; invisible walls close the rest of each border. Interactables are tagged and carry a `ProximityPrompt`:
| Tag | Attributes | Purpose |
|---|---|---|
| `EggStand` | `EggId` | buy that egg (hub: Meadow, Mythic and Limited stands; one Basic stand per island). Client hides a Limited stand when not on sale. |
| `Gate` | `AreaId` | archway between regions with child `Barrier` (client disables locally once opened) |
| `Hatchery` | | incubator menu (hub building with visible nests; incubators are also reachable from the HUD) |
| `FusionAltar` | | fusion menu (hub) |
| `CosmeticShop` | | coin shop (hub) |
| `ExpeditionBoard`, `RebirthStatue`, `IndexBook` | | as before (hub) |
| `RacePad` | | join the sky race (hub, under the Sky Arena) |
| `RaceCheckpoint` | `Index`, `Radius` | ring in the Sky Arena (client detects passing; server validates) |
| `Arena` | `Radius` | Creature Ring zone |
| `AreaBounds` | `AreaId` | region volume |

## Models (`Models/init.luau`)
- `Models.Creature(species, element, rarity, stage, opts?: { Neon: boolean?, Cosmetics: {[string]: string}? }): Model`
  — anchored, non-colliding, PrimaryPart `Root`, pivot bottom-centre facing -Z. Size from `Config.StageScale` (Adult ≈
  5–7 studs long so a player can ride it). Element sets the palette; higher rarity adds flourishes (trim, glowing
  markings, gold horns/crests, aura particles for Mythic). Neon = neon markings + element-coloured light. Has
  Attachments `Saddle` (rider seat), `Hat`, `Aura` on Root; cosmetics in opts are attached there.
- `Models.Cosmetic(id): Model`, `Models.Egg(eggId): Model`, `Models.Breakable(kind, areaId): Model` as before.
All primitives at runtime; no uploads.

## Persistence
DataStore `Config.DataStoreName` (fresh store, schema `Config.Version`, migrations in `Logic/Profile`), key `p_<UserId>`,
session-locked with retry/backoff, autosave every `Config.AutosaveSeconds`, save on leave and `BindToClose`, receipts
deduped, trades journaled, Studio uses `<name>_Studio`.

## Compliance
Odds shown for every egg before buying (species, rarity and element tables, with luck). PolicyService:
`ArePaidRandomItemsRestricted` → no gem eggs and no paid luck; `IsPaidItemTradingAllowed == false` → trading off.

## Creature Ring
As built for Pet Expedition (see `Config.Ring`), with ring strength = `min(RarityFactor × (Neon ? NeonFactor : 1),
MaxGearFactor) × StageFactor`, and `ElementEdge` damage when the attacker's element beats the defender's. Fighter
attributes use `Species`, `Element`, `Rarity`, `Stage`, `Neon` instead of pet fields. No XP (growth comes from care).

## Sky race
`RaceJoin` (must be riding a flier with the Fly potion, in the hub) → queue; the race starts `QueueSeconds` after the
first join (or when `MaxRacers` join). Racers are placed at `Race.Start`, a 3-2-1 countdown runs, then they fly through
the checkpoints in order. The client fires `RaceCheckpoint(i)` when its root passes ring i; the server checks order,
distance to the ring centre ≤ radius + 6, and `MinCheckpointSeconds` since the last. Finishing the last ring finishes
the race; places pay `Race.Coins[place] × CoinMult(highest)` and `Race.Trophies[place]`, only for the first
`DailyRewardRaces` races each UTC day. `TimeLimit` ends the race for everyone. Leaving, dismounting or dying drops out.
Best time → `Stats.BestLap`; leaderstats show Trophies.
