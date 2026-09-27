# Mesh skins: the 3D asset pack in the game

The game's models are still built by the procedural builders in `src/shared/Models`. Every
builder now also calls `Skins.luau`, which adds a mesh from the asset pack and hides the
procedural parts. The hidden parts keep doing their job:
- collision and queries
- proximity prompts and effects (fire, light, smoke)
- anything a service looks up by name, such as `Top`, `Stump`, `FireCore`, `Door`, `Ladder` or `Hurt`

The meshes themselves never collide and can't be clicked, so gameplay rules are unchanged.

- **Library:** `SurvivalHourAssets.rbxm` → `ReplicatedStorage.SurvivalHourAssets` (see
  `default.project.json`). The client also reads it, for held items and arrows.
- **Off switch:** set the `MeshSkins` attribute on ReplicatedStorage to `false`, or remove the
  library. Every skin call becomes a no-op and the old look returns.
- **Tests:** `python tests/skins/bundle.py` runs every skinned builder against a Roblox API mock
  and a fake library generated from the pack catalog. It currently passes 23 of 23 checks.

## What gets which mesh

| Game model | Mesh | Notes |
|---|---|---|
| `Nature.Pine / Oak / Birch` (decor) | `SM_Tree_Pine_*`, `SM_Tree_Oak_*`, `SM_Tree_Birch_Medium01` | variant picked by position, scaled to the old height |
| `Nature.Bush`, `BigRock`, `GrassClump`, `FallenGiant` | bushes, boulders, grass, `SM_Landmark_GiantLog` | |
| `Flora.ResourceTree` (Small/Medium/Large × Pine/Oak/Birch), `DeadTree` | matching tree mesh inside `Top` (it falls when chopped) + stump mesh tagged `SkinStump` | `GatherService` shows the stump once the tree isn't standing |
| `Flora.RockPile` | `SM_StoneDeposit01` (Yield) + `SM_StoneDeposit01_Depleted` | depleted rubble stays when mined out |
| `Flora.FibrePlant` | `SM_FiberPlant01` (Yield) + `_Harvested` | |
| `Flora.TwigPile`, `MushroomPatch`, `LooseStones`, `BerryBush` | sticks, mushrooms, river stones, bush | berries stay procedural (they are the yield) |
| `Camp.Campfire` / `Camp.Extinguish` | `SM_Campfire_Burning` → `SM_Campfire_Extinguished` | fire, light, sparks and the team SafeRing are kept |
| `Camp.Workbench(level)` | `SM_Workbench_Level01/02/03` | |
| `Camp.Lantern` | `SM_Camp_Lantern` | |
| `Structures.WoodWall / ReinforcedWall` | `SM_WoodenWall`, `SM_ReinforcedWall` | stretched from the pack's 8-stud grid to this game's 10 studs |
| `Structures.Gate` | `SM_Gate` + door mesh inside the `Door` model + an extra `SM_WallPost` | the door mesh moves with `SetGateOpen` |
| `Structures.Spikes`, `StorageBox` | `SM_Spikes`, `SM_StorageBox` (with lid) | team crest plate stays |
| `Structures.Watchtower` | `SM_Watchtower`, raised to the 12-stud floor, turned so the hatch lines up | climbable `Ladder` truss moved under the mesh ladder (invisible) |
| `Structures.ApplyDamageState` | swaps to `*_Damaged` below 66% health, back when repaired | walls, reinforced walls, spikes, storage box |
| `ItemModels.Held` | pack tool meshes welded to `Handle` | per-item frame correction, e.g. axe, hammer and sword hafts turned to -Z |
| `ItemModels.Pickup` (resources) | `SM_Pickup_*` | tools and weapons use their held mesh |
| `LootModels.CarePackage` | crate + lid; canopy and lines inside `Parachute` | `Land()` removes the parachute meshes with it |
| `LootModels.ForestCrate` | `SM_SupplyCrate_Small01/02/03` | |

## Still procedural (not skinned yet)

- **Wolf, bear and bat:** the game animates them with Motor6D joints, while the pack's rigs are
  skinned meshes with bones and FBX animation clips. Skinning them means driving the bones from
  the creature animator, or uploading the clips.
- **Armour** (the worn `Armor` item): the pack has a 6-piece R15 accessory set, which needs an
  accessory-equip path in InventoryService.
- **Standing stones, ruins, spawn pads, banners, huts, flowers:** no matching mesh in the pack, or
  the procedural version carries team text and colours.
- **Lobby props** are now placed (Phase 7, `Models/Refuge.luau`): the gathering deck, shop stalls
  (Trading Post, Outfitter), party area, ready arch, class stands, signposts, the Hall of Fame board
  and forest-floor ground sections. The emblems (`SM_Emblem_*`) belong to the retired powerups and
  aren't used.

## Needs checking in Studio

Everything above is verified with the mock and the type checker, not in Studio. Worth a look on the
first playtest:
- **Wall and gate stretch:** check the visual thickness against the colliders.
- **Watchtower:** check the hatch and ladder alignment with the invisible truss.
- **Held-item angles:** axe, hammer and sword use a rotation correction; the shield is turned 90°.
- **Tree scale:** compare the chop hit area (`Root`, `Stump`) with the visible trunk.
- **Lobby refuge:** ground-section height (pivot at the walkable surface), the gathering deck around the
  procedural fire, and the sign-panel text lining up with `SM_Sign_Post_Panel` / `SM_Sign_Board_Panel`.
