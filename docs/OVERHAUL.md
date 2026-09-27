# SURVIVAL WARS: Overhaul Plan & Contracts

> **SURVIVAL WARS** · *Gather. Build. Hunt. Survive.*

Survival Hour becomes Survival Wars. The working core stays: four clans, campfires as lives, day/night, raids, building, storage, wildlife, loot, powerups, matchmaking and data. The overhaul adds a lush, layered, functional forest, a data-driven resource framework, points of interest with chests, food, and a sharper PvP identity.

## Loop
Explore → Gather → Loot → Craft/Build → Upgrade → Fight → Survive → push farther → better resources → fight other survivors.

Better resources and loot sit farther from your camp and closer to the contested centre and the sector borders. The loot tiers are: campsites (common chests), cabins/abandoned houses (uncommon/rare), caves (rare/epic). Rich spots are also where rival clans meet.

## Phase 1 (this pass)
1. Rebrand to SURVIVAL WARS (lobby title, HUD intro, docs).
2. **Resource framework** (`shared/Resources.luau` data + `shared/Logic/ResourceRules.luau` pure logic + generic `GatherService`).
3. **Choppable trees** with real health and states: Healthy → Damaged → Felled → Stump → Respawning → Healthy. Small/medium/large sizes differ in hits and wood.
4. **Renewable resources**: trees, berry bushes, mushrooms, loose stones, rock piles, twig piles and fibre plants. All balancing lives in `Resources.luau`.
5. **Lush forest**: many vegetation variants (`shared/Models/Flora.luau`), layered ground/low/middle/upper density driven by noise, clearings, trails, terrain grass decoration, richer terrain materials and elevation, cliffs, streams, ponds and a small waterfall per sector.
6. **Points of interest** (`shared/Models/Landmarks.luau`): cabin, abandoned house, campsite and cave, each with tiered chests.
7. **Food**: berries and mushrooms are gathered and eaten to heal.

Later phases: PvP depth (bounties / kill rewards / loot-on-kill tuning), environmental threats, further weapons and tools.

## Performance budgets
- Decorative tree ≤ 12 parts; bush ≤ 5; ground-cover item ≤ 4; resource node ≤ 14.
- Decor parts use `Build.Decor` (no collide/query/touch). Only trunks, rocks and logs collide.
- Tiny parts (< 1.5 studs) set `CastShadow = false`.
- Every model is built around the origin with its pivot at ground centre and finished with `Build.SetPivot(m, primary, pivotCF)` then `m:PivotTo(cf)`. Never assign `Model.WorldPivot` when a PrimaryPart exists; it has no effect.
- Colours vary per instance through the `rng` argument, never the global `math.random`.

## Model builder contract (Flora / Landmarks)
Every builder has the signature `(cf: CFrame, rng: Random, parent: Instance?) -> Model` unless listed otherwise. `rng` is a seeded `Random`; builders pick their variant, scale jitter and colour jitter from it, so the same seed gives the same model.

### Resource models (used by GatherService)
Resource models need part roles so the service can drive their states:

| Role | How it is marked | Service behaviour |
|------|------------------|-------------------|
| `Root` | the PrimaryPart, invisible, `CanQuery=true`, `CanCollide=false`, footprint-sized, bottom at y=0 | prompt parent + hit target |
| `Top` | a child **Model** named `Top` whose pivot is the hinge at stump height (`Build.SetPivot(top, trunkPart, CFrame.new(0, hingeY, 0))`) | trees only: tilted 90° over ~1.4 s when felled, then hidden; scaled 0.2→1 when regrowing |
| `Stump` | parts named `Stump` | trees only: always visible (the base of the trunk) |
| `Chop` | parts named `Notch`, `Transparency = 1` | trees only: shown when Damaged |
| `Yield` | parts with attribute `Yield = true` | bushes/mushrooms/stones/twigs/fibre: hidden while exhausted, shown when respawned |

A tree's collidable, queryable trunk parts live inside `Top` (plus the `Stump`). Hand-gathered models mark their pickable bits with `Yield`. If a model has no `Yield` parts, the service hides every part except `Root`.

Required resource builders (Flora):
- `Flora.ResourceTree(cf, rng, size: "Small"|"Medium"|"Large", species: "Pine"|"Oak"|"Birch", parent)`
- `Flora.DeadTree(cf, rng, parent)` (resource: dry wood; `Top` + `Stump` like trees)
- `Flora.BerryBush(cf, rng, parent)` (`Yield` = berries)
- `Flora.MushroomPatch(cf, rng, parent)` (`Yield` = caps)
- `Flora.LooseStones(cf, rng, parent)` (`Yield` = stones)
- `Flora.RockPile(cf, rng, parent)` (`Yield` = the smaller chunks, the main boulder stays)
- `Flora.TwigPile(cf, rng, parent)` (`Yield` = twigs)
- `Flora.FibrePlant(cf, rng, parent)` (`Yield` = fronds/buds)

### Decorative models (Flora)
`Pine`, `Spruce`, `Oak`, `Birch`, `Aspen` (≥ 2 silhouettes each where it makes sense), `GiantTree` (landmark canopy tree), `DeadSnag`, `FallenLog`, `Stump`, `Sapling`, `Bush` (3+ looks), `Fern`, `TallGrass`, `FlowerPatch`, `Mushrooms`, `Roots`, `MossPatch`, `LeafLitter`, `Twigs`, `Pebbles`, `Boulder` (3+ looks), `CliffRock(cf, rng, size: Vector3, parent)` (a jagged wall segment), `WaterfallRocks(cf, rng, height, parent)` (stepped rocks with a thin falling-water sheet and a mist emitter).

### Landmarks
- `Landmarks.Cabin(cf, rng, parent)`: small log cabin with doorway, window gaps, porch, stove pipe; enterable; one chest mount point.
- `Landmarks.AbandonedHouse(cf, rng, parent)`: two-room ruined timber house, partially collapsed roof and broken walls; 1–2 chest mount points.
- `Landmarks.Campsite(cf, rng, parent)`: tent(s), dead fire pit, log seats, backpack/crate clutter; 1 chest mount point.
- `Landmarks.CaveEntrance(cf, rng, parent)`: a rock arch/overhang facade that frames a tunnel mouth. The tunnel itself is carved into terrain by WorldService. It has lantern/crystal accents and 1 chest mount point deep inside (given in model space).
- `Landmarks.Chest(cf, tier: "Common"|"Uncommon"|"Rare"|"Epic", parent)`: `Root` PrimaryPart, a `Lid` part (the service rotates it open), tier colouring/trim, a subtle glow on Rare/Epic.

Chest mount points are `Attachment`s named `ChestMount` parented to the landmark's PrimaryPart. WorldService spawns chests at them. Landmarks keep walkable interiors: door gaps ≥ 5 wide × 7 tall, no collision on clutter.
