# Mythic Hatchery: system contracts

Updated October 6, 2026 to reflect the owner's approved battle and habitat decisions.
This file and `src/shared/{Gameplay,Config,Net,Types}.luau` define the integrated game.

## Game loop
Players hatch creatures, use habitats to earn coins, ride/fly across six connected regions, and
optionally battle other players. There is no racing, growth-stage gameplay, or care-task XP.
The first profile receives one Common Nature Dragon at level 1, with Ride and Fly already enabled,
and 250 coins. This starter grant persists and cannot be repeated by rejoining.

## Creature progression and battles
- Five base species and six hidden hybrids; five elements; rarities Common through Mythic.
- Levels replace growth stages. XP comes only from completed battles. Habitats and expeditions grant no XP.
- Optional PvP matches three-creature teams by total strength. One creature is active at a time.
- Players command every move in real time. Species gives main moves and element gives an elemental attack.
  Creatures start with two moves; all unlocked moves remain available.
- Every move uses a shared cooldown; swapping uses a separate longer cooldown. Provisional values are
  2 and 8 seconds in `Gameplay.luau`. Rarity and level strongly affect combat strength.
- Damage, useful healing, and absorbed shielding count toward participation. Only creatures entering
  combat receive XP; larger useful contribution receives more. Losers receive fewer rewards and lose
  arena points. Creatures recover immediately after the match; no permanent injury.
- Rewards are settled once per battle id. Repeated opponents and nonparticipating forfeits cannot farm rewards.
  Server clocks, team snapshots, move validation and rewards are authoritative.

## Habitats
One large plot per player, initially three slots, with unlockable/upgradable slots to the configured cap.
Assigned creatures produce coins online and offline until slot storage fills. Players manually collect them.
Slot upgrades improve production and storage, never passive XP. A creature must leave its habitat before
riding, battling, trading, fusion or expeditions. Settle income before changing assignments/rates/upgrades.
Coin multipliers use server snapshots; temporary coin boosts expire during offline accrual.
Persisted habitat/incubator/expedition slot keys are strings (`tostring(index)`).

## Eggs and fusion
- Egg purchases validate sale dates, region access, stand distance, currency, bag capacity and account policy.
  Eggs enter the bag; `Incubate` assigns a free slot. Three slots, plus two with HatchSlots pass.
- Incubation fixes seed and luck at placement. FastIncubation halves duration. `Hatch` requires the timer to
  finish and inventory space. Gem skips cost the configured minimum or the remaining-time charge.
- Species, rarity and element are independent rolls. UI shows all three odds tables including active luck.
  Luck boosts all rarities above the egg's lowest rarity and is capped.
- Fusion consumes two different owned, unlocked, available creatures plus the server-calculated coin cost.
  Rarity can upgrade and eligible cross-species pairs can hatch a hidden hybrid. Parent potions/cosmetics
  are lost; UI warns before confirmation. Fused hatchlings start at level 1.
- Ride, Fly and Neon potions are per creature. Cosmetic ownership belongs to the player.

## Riding, world and models
`Mount(uid)` validates ownership and availability. The server owns mounted physics, validates and rate-limits
`MountInput(Vector3, flying)`, caps speed/altitude and cleans up on death/leave/dismount.
The client sends movement intent and provides phone rise/fall/fly controls.

Regions form one continuous land along +X: Meadow, Shadow, Frost, Storm, Volcano, Sky. Natural ridges close
borders except gate archways. Owned gate barriers disable locally; the server returns players entering locked
regions. World interactable prompts open the same phone menus as HUD buttons.
`World.Build()` returns `{Spawns, Zones, Bounds, Arena={Center, Radius}}`.
World tags: EggStand(EggId), Gate(AreaId), Hatchery, FusionAltar, CosmeticShop, HabitatPlot(PlotIndex),
HabitatSlot(SlotIndex), BattleArena, AreaBounds(AreaId). Retained progression menus are also available from HUD.

`Models.Creature(species, element, rarity, visualStage, opts?)` returns an anchored noncolliding primitive
Model with PrimaryPart Root, bottom-centre pivot, Saddle/Hat/Aura attachments. Active gameplay uses visual
`"Adult"`; legacy size presets are visual only. `Models.Cosmetic(id)` and `Models.Egg(id)` build primitives.
Eleven species silhouettes, five element palettes, rarity flourishes, Neon and cosmetics use no uploaded meshes.

## Remotes and state
`Net.luau` is the complete remote registry. Functions return `{ok=true,...}` or `{ok=false,err=reason}`.
Every handler validates types/ranges, ownership, availability and rate limits; client prices, odds, positions,
combat stats and rewards are never accepted as authority. `State` is a coalesced full `Types.PlayerState` snapshot.
Server events: State, Notify, Trade, Battle. Client events: ClientReady, MountInput.
Function families: eggs/incubation; creature inventory/potions/cosmetics/fusion; habitats; battle team/queue/move/swap;
world gates/teleport/rebirth; expeditions; daily/playtime/quest/Index rewards; settings; journaled trading; Studio dev tools.
`Player.Riding` contains mount JSON or an empty string. `Player.Creatures` contains equipped-creature JSON.

## Retained systems, purchases and saving
Expeditions, rebirth, daily rewards, playtime gifts, daily quests, Species|Element Index, boosts, Server Luck,
creature-only trades, receipts and session locks remain. No gem trade offers; confirmation countdown and
journaled atomic swap persist. Busy/locked creatures are refused and cosmetic ownership does not transfer.
The retired AutoFarm/RingChampion passes are removed from the unsold catalogue. Growth2x/BoostGrowth keys
remain for save compatibility but are labelled 2x Battle XP and affect battle XP only.

DataStore key `p_<UserId>`, store from Config, separate Studio store, schema sanitation/migration, retries/backoff,
session locking, autosave, leave save and BindToClose remain. Receipt dedupe and trade recovery must not weaken.
All product ids are currently zero: live purchasing stays unavailable until configured. Studio test purchases
are explicitly simulated and refused in live servers.
PolicyService restrictions disable gem eggs and paid luck; paid-item trading restrictions disable trading.

## Code and build
`--!strict` Luau, ModuleScripts for systems, entry scripts only, no `_G`. Pure Logic is Roblox-service free.
Source relative requires permit CLI tests. `tools/prepare_runtime.py` stages Instance-based requires for Roblox;
`bash tools/check.sh` builds that staged project, and `bash tools/serve.sh` serves it with Rojo.
Run `bash tools/check.sh --quick` after changes. Studio multiplayer and phone playtests are required before release.
