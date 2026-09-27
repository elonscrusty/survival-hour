# Survival Hour: model catalog

Generated from `Roblox/catalog.json` by `blender/make_docs.py`. Sizes are Roblox studs (X width × Y height × Z depth), measured on the exported mesh. Every mesh uses **1 material** (the shared atlas). *Tris* is after triangulation; *LOD1* is the lower-detail file where one exists.
**203 assets** (+ 14 separate moving parts), 105,454 triangles in total.


Kinds: **Accessory**: Rigid R15 accessory (armor piece).; **Debris**: Lightweight destruction debris: unanchored, short lifetime, CanCollide on, CanTouch off.; **Effect**: Effect mesh (flames, water surface, target ring): no collision.; **Equippable**: Held item: put in a Tool, rename to Handle.; **Harvestable**: Static world prop players harvest; pair with its Depleted variant.; **Lobby**: Lobby prop.; **MovingPart**: Separate moving piece of another asset (door, lid, slide, bolt).; **Pickup**: Small dropped/world pickup and inventory icon model.; **Projectile**: Projectile mesh fired by a weapon (no collision; use raycasts).; **Reference**: Scale reference; not for gameplay.; **Rig**: Skinned, rigged character mesh with animations.; **Structure**: Player-placed building piece (anchored, collidable).; **WorldProp**: Static world prop (anchor it).

## Reference

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Reference_Dummy_R15` | Reference | 4.0 × 5.2 × 1.2 | 500 | — |  | Scale reference: block R15 proportions, 5.25 studs tall, faces -Z (Roblox front). |

## Forest kit

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Tree_Pine_Medium01` | WorldProp | 11.6 × 20.5 × 11.4 | 852 | 354 |  | Common medium pine. |
| `SM_Tree_Pine_Medium02` | WorldProp | 8.1 × 17.5 × 10.0 | 768 | 306 |  | Medium pine, narrower. |
| `SM_Tree_Pine_Large01` | WorldProp | 17.5 × 32.4 × 15.4 | 1020 | 450 |  | Tall landmark pine. |
| `SM_Tree_Pine_Small01` | Harvestable | 6.7 × 10.5 × 7.2 | 692 | 266 |  | Harvestable small pine: gives wood. Axe notch = harvest cue. |
| `SM_Tree_Oak_Medium01` | WorldProp | 15.0 × 15.9 × 15.3 | 1980 | 380 |  | Medium broadleaf tree. |
| `SM_Tree_Oak_Medium02` | WorldProp | 14.0 × 14.7 × 12.9 | 3952 | 488 |  | Medium broadleaf tree, wider crown. |
| `SM_Tree_Oak_Large01` | WorldProp | 21.6 × 24.7 × 20.0 | 6644 | 836 |  | Large old broadleaf: clearing centrepiece. |
| `SM_Tree_Oak_Small01` | Harvestable | 5.7 × 8.9 × 6.3 | 976 | 280 |  | Harvestable small broadleaf: gives wood. |
| `SM_Tree_Birch_Medium01` | WorldProp | 5.3 × 18.1 × 6.6 | 810 | 220 |  | Pale birch: breaks up the darker pines. |
| `SM_Tree_Birch_Small01` | Harvestable | 4.4 × 10.7 × 4.0 | 818 | 228 |  | Harvestable small birch: gives wood. |
| `SM_Tree_Dead_Large01` | WorldProp | 16.3 × 20.1 × 15.6 | 1100 | 380 |  | Gnarled dead tree for the mysterious deep-forest mood. |
| `SM_Tree_Pine_Small01_Stump` | Harvestable | 3.0 × 1.2 × 3.1 | 214 | — |  | Depleted state of SM_Tree_Pine_Small01 (fresh cut + chips). |
| `SM_Tree_Oak_Small01_Stump` | Harvestable | 3.2 × 1.1 × 2.9 | 214 | — |  | Depleted state of SM_Tree_Oak_Small01. |
| `SM_Tree_Birch_Small01_Stump` | Harvestable | 2.9 × 1.1 × 2.7 | 214 | — |  | Depleted state of SM_Tree_Birch_Small01. |
| `SM_Stump_Old01` | WorldProp | 4.1 × 2.2 × 4.1 | 234 | — |  | Old mossy stump (decor). |
| `SM_Stump_Old02` | WorldProp | 3.7 × 3.9 × 3.7 | 190 | — |  | Broken tall stump (decor). |
| `SM_FallenLog01` | WorldProp | 8.1 × 2.3 × 1.8 | 162 | 62 |  | Fallen log; players can hop over it. |
| `SM_FallenLog02_Hollow` | WorldProp | 10.9 × 3.1 × 2.7 | 218 | 94 |  | Large hollow log, mossy; broken end. |
| `SM_Branch01` | WorldProp | 4.5 × 0.5 × 3.0 | 112 | — |  | Fallen branch (decor, CanCollide off). |
| `SM_Branch02` | WorldProp | 3.6 × 0.5 × 2.9 | 332 | — |  | Forked fallen branch with leaves (decor, CanCollide off). |
| `SM_Sticks_Loose01` | WorldProp | 1.9 × 0.3 × 3.1 | 96 | — |  | Scatter of loose sticks (decor). Pickup version: SM_Pickup_Stick. |
| `SM_Rock_Small01` | WorldProp | 1.8 × 0.6 × 1.3 | 80 | — |  | Small rock (decor). |
| `SM_Rock_Small02` | WorldProp | 2.5 × 0.7 × 1.7 | 160 | — |  | Small mossy rock pair (decor). |
| `SM_Rock_Small03` | WorldProp | 2.8 × 0.3 × 2.4 | 80 | — |  | Flat stepping-stone rock (decor). |
| `SM_Boulder01` | WorldProp | 9.5 × 3.5 × 6.7 | 640 | 160 |  | Large boulder; blocks movement. |
| `SM_Boulder02` | WorldProp | 6.8 × 4.8 × 5.9 | 720 | 180 |  | Tall split boulder. |
| `SM_Boulder03` | WorldProp | 6.9 × 2.2 × 5.5 | 420 | 180 |  | Low, wide mossy boulder cluster. |
| `SM_StoneDeposit01` | Harvestable | 6.0 × 2.5 × 4.2 | 592 | 232 |  | Harvestable stone: pale quartz veins + flat chipped face = 'mine me'. Gives Rock/Stone. |
| `SM_StoneDeposit01_Depleted` | Harvestable | 4.4 × 0.8 × 4.5 | 180 | — |  | Depleted stone deposit: low rubble. |
| `SM_FiberPlant01` | Harvestable | 1.9 × 3.8 × 1.9 | 600 | 174 |  | Harvestable plant fibre: tall pale-gold stalks with seed heads. Gives Plant Fiber. |
| `SM_FiberPlant01_Harvested` | Harvestable | 0.5 × 0.7 × 0.8 | 100 | — |  | Cut stubble left after harvesting fibre. |
| `SM_Grass_Clump01` | WorldProp | 1.2 × 1.5 × 1.4 | 140 | 70 |  | Grass clump (repeat freely; CanCollide/CanQuery off). |
| `SM_Grass_Clump02` | WorldProp | 2.6 × 1.2 × 1.3 | 240 | 120 |  | Wide grass patch. |
| `SM_Grass_Clump03` | WorldProp | 1.3 × 2.0 × 1.1 | 160 | 80 |  | Tall dry grass. |
| `SM_Bush01` | WorldProp | 2.9 × 2.0 × 3.4 | 416 | 68 |  | Round shrub (CanCollide off: players push through). |
| `SM_Bush02` | WorldProp | 4.5 × 2.8 × 4.5 | 496 | 88 |  | Wide low shrub. |
| `SM_Bush03_Berry` | WorldProp | 3.3 × 1.8 × 3.1 | 656 | 308 |  | Berry shrub (decor; red berries add colour). |
| `SM_Fern01` | WorldProp | 4.0 × 0.7 × 3.9 | 420 | 300 |  | Fern (CanCollide off). |
| `SM_Fern02` | WorldProp | 2.8 × 0.7 × 2.9 | 300 | 240 |  | Small fern. |
| `SM_Mushrooms01` | WorldProp | 1.5 × 0.9 × 1.0 | 260 | — |  | Cluster of pale mushrooms (decor). |
| `SM_Mushrooms02_Glow` | WorldProp | 1.0 × 0.7 × 0.5 | 176 | — |  | Faintly glowing mushrooms for night mood (set cap faces' part Material Neon, or add a small PointLight at Glow_Att). |
| `SM_LeafLitter01` | WorldProp | 6.1 × 0.2 × 5.0 | 320 | — |  | Leaf-litter mound to break up flat ground (CanCollide off). |
| `SM_Pinecones01` | WorldProp | 1.7 × 0.3 × 2.2 | 120 | — |  | Pinecone scatter under pines (decor). |
| `SM_MossPatch01` | WorldProp | 4.7 × 0.2 × 3.6 | 80 | — |  | Low moss patch for rocks/roots (CanCollide off). |
| `SM_Landmark_StandingStones` | WorldProp | 17.3 × 7.9 × 17.8 | 1060 | 580 |  | Ring of old mossy standing stones: navigation landmark / mystery spot. |
| `SM_Landmark_AntlerTotem` | WorldProp | 3.3 × 8.9 × 1.2 | 436 | — |  | Weathered wooden totem with antlers and cloth ties: eerie, not gory. |
| `SM_Landmark_GiantLog` | WorldProp | 22.8 × 8.6 × 7.4 | 436 | 320 |  | Huge fallen trunk players can walk through (tunnel 4 studs wide, 5.5 tall). |
| `SM_Clearing_GroundPatch` | WorldProp | 40.0 × 0.7 × 40.0 | 1152 | — |  | Worn dirt clearing under a camp: lay over terrain (CanCollide off). |
| `SM_Camp_LogBench` | WorldProp | 5.0 × 1.9 × 1.3 | 132 | — |  | Split-log bench (seat height 1.6). |
| `SM_Camp_FirewoodStack` | WorldProp | 2.6 × 1.8 × 1.5 | 180 | — |  | Stacked split firewood. |
| `SM_Camp_DryingRack` | WorldProp | 4.6 × 4.2 × 1.4 | 180 | — |  | Pole drying rack with a stretched hide (no gore). |
| `SM_Camp_Lantern` | WorldProp | 1.4 × 5.3 × 0.6 | 190 | — |  | Lantern on a post. Glow part: add PointLight at Light_Att (warm, Range 16). |
| `SM_Camp_Bedroll` | WorldProp | 1.8 × 0.7 × 4.6 | 212 | — | yes | Rolled-out bedroll with pillow roll (decor, CanCollide off). |
| `SM_Camp_Barrel` | WorldProp | 2.0 × 2.5 × 2.0 | 304 | — |  | Water barrel (decor / cover). |
| `SM_Camp_ChoppingBlock` | WorldProp | 3.8 × 1.7 × 3.8 | 238 | — |  | Chopping stump with split wood around it. |
| `SM_Camp_TeamBanner` | WorldProp | 2.3 × 9.4 × 0.4 | 104 | — | yes | Tall team banner for camp edges (team colour via atlas variant). |

<details><summary>Notes</summary>

- `SM_Tree_Pine_Medium01`: Collide with the trunk only (collision box / COL_ file). Needles: CanCollide off.
- `SM_Tree_Pine_Small01`: Swap for SM_Tree_Pine_Small01_Stump when depleted.
- `SM_Tree_Oak_Small01`: Swap for SM_Tree_Oak_Small01_Stump when depleted.
- `SM_Tree_Birch_Small01`: Swap for SM_Tree_Birch_Small01_Stump when depleted.
- `SM_StoneDeposit01`: Swap for SM_StoneDeposit01_Depleted when empty.
- `SM_FiberPlant01`: CanCollide off. Swap for SM_FiberPlant01_Harvested.
- `SM_Landmark_GiantLog`: Use CollisionFidelity Default or the provided wall boxes so the tunnel stays open.

</details>

## Stream kit

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Stream_Straight` | WorldProp | 24.0 × 4.0 × 16.0 | 1356 | — |  | Straight stream bank piece (flow along Z). |
| `SM_Stream_Bend90` | WorldProp | 28.0 × 3.8 × 28.0 | 1736 | — |  | 90-degree bend: enters at the -Z end like the straight piece, exits facing +X (Roblox). |
| `SM_Stream_PoolEnd` | WorldProp | 24.0 × 3.8 × 24.0 | 2576 | — |  | Stream end: a small spring pool. Connects at its -Z end. |
| `SM_Stream_Water_Straight` | Effect | 10.5 × 0.1 × 16.0 | 176 | — |  | Water surface for the straight piece. Suggested: Material Glass or SmoothPlastic, Transparency 0.35, CanCollide off. |
| `SM_Stream_Water_Bend90` | Effect | 21.2 × 0.1 × 21.2 | 256 | — |  | Water surface for the bend. |
| `SM_Stream_Water_PoolEnd` | Effect | 12.4 × 0.1 × 21.2 | 172 | — |  | Water surface for the pool end. |
| `SM_StreamRocks01` | WorldProp | 3.2 × 0.6 × 3.4 | 400 | — |  | Smooth streambed stones (place on the bed at Y=-1.6). |
| `SM_StreamRocks02` | WorldProp | 7.6 × 1.6 × 2.2 | 240 | — |  | Stepping stones across the stream (tops above the water line when placed on the bed). |
| `SM_StreamRocks03` | WorldProp | 3.0 × 0.2 × 4.2 | 240 | — |  | Pebble spread for shallows. |

<details><summary>Notes</summary>

- `SM_Stream_Straight`: Snaps to other stream pieces every 16 studs along the flow. Add SM_Stream_Water_Straight.
- `SM_Stream_Bend90`: Pair with SM_Stream_Water_Bend90.
- `SM_Stream_PoolEnd`: Pair with SM_Stream_Water_PoolEnd. Good spot for the canteen refill interaction.

</details>

## Starting camp

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Campfire_Burning` | Structure | 6.8 × 6.5 × 6.4 | 1202 | 400 | yes | Team campfire, lit. Show SM_Campfire_Flames on top (Material Neon) plus Fire/Smoke/Light effects. |
| `SM_Campfire_Extinguished` | Structure | 7.0 × 6.5 × 6.6 | 1378 | 448 | yes | Just put out: charred, collapsed logs over ash. Emit steam from Extinguish_Att for a few seconds. |
| `SM_Campfire_ColdWet` | Structure | 7.0 × 6.5 × 6.8 | 1254 | 428 | yes | Cold / soaked state: dark wet logs and a puddle. Relight to return to Burning. |
| `SM_Campfire_Flames` | Effect | 2.5 × 4.9 × 2.4 | 48 | — |  | Flame body for the burning state. Set Material = Neon, CanCollide/CanQuery off; scale Y 0.8-1.1 in a loop for flicker. |
| `SM_Campfire_WaterTarget` | Effect | 6.4 × 0.4 × 6.4 | 272 | — |  | Pour-zone ring shown to a player holding water near an enemy fire. Material Neon, Transparency ~0.4, CanCollide off. |
| `SM_Workbench_Level01` | Structure | 6.0 × 3.5 × 2.4 | 460 | — | yes | Starting workbench: crude split-log table on stumps with stone tools. Crafts L1 items. |
| `SM_Workbench_Level02` | Structure | 7.0 × 6.4 × 3.6 | 692 | — | yes | Level 2: plank bench with vise, shelf, hanging saw/hammer and a painted team backboard. |
| `SM_Workbench_Level03` | Structure | 10.1 × 7.8 × 3.5 | 1040 | — | yes | Level 3: iron-banded timber bench, anvil, grinding wheel, tool rack, team banner. |

<details><summary>Notes</summary>

- `SM_Campfire_Burning`: Attachments: Fire_Att (flame emitter base), Smoke_Att (smoke column), Light_Att (PointLight, warm, Range ~28), Extinguish_Att (steam burst), WaterTarget_Att (centre of the pour zone, radius 2.3), TeamFlag_Att (top of the team stake: put a Highlight or Billboard marker here so the fire reads through walls).
- `SM_Campfire_Extinguished`: Attachments: Fire_Att (flame emitter base), Smoke_Att (smoke column), Light_Att (PointLight, warm, Range ~28), Extinguish_Att (steam burst), WaterTarget_Att (centre of the pour zone, radius 2.3), TeamFlag_Att (top of the team stake: put a Highlight or Billboard marker here so the fire reads through walls).
- `SM_Campfire_ColdWet`: Attachments: Fire_Att (flame emitter base), Smoke_Att (smoke column), Light_Att (PointLight, warm, Range ~28), Extinguish_Att (steam burst), WaterTarget_Att (centre of the pour zone, radius 2.3), TeamFlag_Att (top of the team stake: put a Highlight or Billboard marker here so the fire reads through walls).
- `SM_Workbench_Level01`: Team accent: cloth throw on the right end (team atlas variant).
- `SM_Workbench_Level02`: Team accent: painted backboard (team_paint).
- `SM_Workbench_Level03`: Team accent: banner hanging from the rack. Metal parts share the atlas (Metalness map).

</details>

## Workbench level 1 craftables

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_WoodenWall` | Structure | 8.6 × 10.1 × 1.6 | 872 | 588 |  | Workbench L1. Sharpened log palisade; 7.6 studs tall blocks players. |
| `SM_WoodenWall_Damaged` | Structure | 8.6 × 10.1 × 1.6 | 706 | 470 |  | Swap in below ~40% health: broken logs, a gap, a fallen rail. |
| `SM_WallPost` | Structure | 1.4 × 10.1 × 1.4 | 148 | — |  | End cap for wall/gate runs and corners (the missing right-hand post). |
| `SM_StoneAxe` | Equippable | 0.5 × 3.5 × 1.6 | 528 | — |  | Workbench L1 tool: chops trees. Tool > Handle. |
| `SM_StorageBox` | Structure | 3.1 × 1.8 × 2.0 | 816 | — |  | Workbench L1: shared team chest. Lid is SM_StorageBox_Lid (hinged). |
| ↳ `SM_StorageBox_Lid` | MovingPart | 3.1 × 0.5 × 2.3 | 244 | — | | Hinge line along the back top edge. Rotate about the part's X axis to open (~-100 deg). |
| `SM_StorageBox_Damaged` | Structure | 3.1 × 1.8 × 2.0 | 784 | — |  | Damaged chest body (broken front plank). Uses SM_StorageBox_Lid_Damaged. |
| ↳ `SM_StorageBox_Lid_Damaged` | MovingPart | 3.1 × 0.5 × 2.3 | 244 | — | | Hinge line along the back top edge. Rotate about the part's X axis to open (~-100 deg). |
| `SM_Spear` | Equippable | 0.5 × 1.0 × 7.2 | 270 | — | yes | Workbench L1: wooden spear with knapped stone point. Thrust forward along -Z. |
| `SM_RepairHammer` | Equippable | 0.8 × 3.2 × 1.5 | 362 | — |  | Workbench L1: wood-and-stone repair mallet for structures. |
| `SM_Debris_Splinters` | Debris | 1.6 × 0.2 × 1.6 | 32 | — |  | Spawn 2-4 copies when a wooden structure takes a hit or breaks; despawn after ~4 s. |
| `SM_Debris_LogChunk` | Debris | 2.1 × 1.0 × 0.9 | 42 | — |  | Broken log section for wall/gate destruction (spawn 3-5). |
| `SM_Debris_MetalBand` | Debris | 2.0 × 0.3 × 0.2 | 52 | — |  | Bent iron band + bolts for reinforced wall / L3 destruction. |

<details><summary>Notes</summary>

- `SM_WoodenWall`: Use COL_WoodenWall (one box) or CollisionFidelity Box. Rails sit on the inside (+Z).
- `SM_StorageBox`: Prompt_Att for the open prompt. Items render at Contents_Att.

</details>

## Workbench level 2 craftables

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Canteen` | Equippable | 1.1 × 1.7 × 1.4 | 418 | — |  | Workbench L2: leather canteen with rope strap. Pour_Att at the spout (tilt forward to pour on fires). |
| `SM_Bow` | Equippable | 0.3 × 4.6 × 0.5 | 234 | — |  | Workbench L2: handmade wooden bow with a visible string. |
| `SM_Arrow` | Projectile | 0.2 × 0.9 × 3.0 | 90 | — | yes | Arrow projectile (one team-coloured fletching). Tip_Att at the point. |
| `SM_ArrowBundle` | Pickup | 0.5 × 1.1 × 3.0 | 636 | — | yes | Arrow ammo pickup: six arrows tied with rope. |
| `SM_Gate` | Structure | 8.9 × 11.0 × 1.4 | 160 | 84 |  | Workbench L2: gate frame. Door is SM_Gate_Door (hinged on the left post). 6.6 x 7.2 opening. |
| ↳ `SM_Gate_Door` | MovingPart | 6.7 × 7.5 × 0.7 | 508 | — | | Hinge axis: bottom of the hinge edge. Rotate about the part's Y (up) axis. Closed = placement in SM_Gate. |
| `SM_Gate_Door_Damaged` | MovingPart | 6.7 × 7.5 × 0.9 | 514 | — |  | Damaged door: broken plank, sagging brace. |
| `SM_Spikes` | Structure | 8.0 × 2.6 × 3.5 | 252 | 132 |  | Workbench L2: sharpened stake barrier. Stakes point outward (-Z) and up. Damages on touch. |
| `SM_Spikes_Damaged` | Structure | 8.0 × 2.6 × 3.5 | 292 | — |  | Damaged spikes: snapped stakes. |

<details><summary>Notes</summary>

- `SM_Bow`: String is modelled straight (rest). For a draw pose, move Nock_Att back; the string mesh does not bend.
- `SM_Gate`: Anchor the frame; hinge the door with a HingeConstraint or tween its CFrame about Hinge_Att.
- `SM_Spikes`: Use the collision box as a CanTouch hurt zone; keep CanCollide on so it blocks.

</details>

## Workbench level 3 craftables

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_ReinforcedWall` | Structure | 9.1 × 10.1 × 1.7 | 948 | 484 |  | Workbench L3: squared timber on a stone footing, iron bands, capped beams. |
| `SM_ReinforcedWall_Damaged` | Structure | 9.1 × 10.1 × 1.7 | 948 | 484 |  | Damaged reinforced wall: two beams broken, middle band bent out. |
| `SM_Watchtower` | Structure | 9.1 × 22.6 × 9.1 | 1100 | 510 | yes | Workbench L3: platform at 10 studs, ladder on the front (-Z) through a 2.8 x 2.4 hatch, 3.5-stud railing, 6.5 studs head room under the roof. |
| `SM_Sword` | Equippable | 0.3 × 4.4 × 0.9 | 212 | — |  | Workbench L3: broad single-edged survival sword with a saw-backed spine. Blade up, edge forward. |
| `SM_Shield` | Equippable | 2.9 × 2.9 × 0.7 | 730 | — | yes | Workbench L3: round plank shield, iron rim and boss, leather arm straps, team-painted band. |

<details><summary>Notes</summary>

- `SM_ReinforcedWall`: Same 8-stud snapping as SM_WoodenWall, so it upgrades in place.
- `SM_Watchtower`: Put an invisible TrussPart in the Climb volume (see catalog 'meta.climb_volume') so every avatar can climb. Use the collision boxes (not mesh collision) so the hatch stays open.
- `SM_Sword`: Trail_Att0/Trail_Att1 span the blade for a Trail effect on swings.
- `SM_Shield`: For the left arm: weld Grip_Att to LeftGripAttachment (rotate 90 deg about Y if it faces sideways).

</details>

## Level 3 armour (rigid R15 accessories)

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `ACC_Armor_Helmet` | Accessory | 1.6 × 1.3 × 1.7 | 576 | — | yes | Leather cap with iron brow band, nasal guard and cheek flaps; team-coloured tail. |
| `ACC_Armor_Chest` | Accessory | 2.2 × 1.9 × 1.3 | 428 | — |  | Leather cuirass with three riveted iron lames and shoulder straps. |
| `ACC_Armor_Back` | Accessory | 2.1 × 2.0 × 0.5 | 112 | — | yes | Back plate with a short team-coloured cape. |
| `ACC_Armor_ShoulderL` | Accessory | 1.6 × 1.0 × 1.2 | 544 | — |  | Left layered iron pauldron (moves with the arm). |
| `ACC_Armor_ShoulderR` | Accessory | 1.6 × 1.0 × 1.2 | 544 | — |  | Right layered iron pauldron (moves with the arm). |
| `ACC_Armor_Belt` | Accessory | 2.2 × 1.0 × 1.3 | 376 | — |  | Wide belt with brass buckle, side pouch and leather tassets over the hips. |

<details><summary>Notes</summary>

- `ACC_Armor_Helmet`: Accessory > Handle (this mesh) > Attachment 'HatAttachment' at the origin.
- `ACC_Armor_Chest`: Accessory > Handle (this mesh) > Attachment 'BodyFrontAttachment' at the origin.
- `ACC_Armor_Back`: Accessory > Handle (this mesh) > Attachment 'BodyBackAttachment' at the origin.
- `ACC_Armor_ShoulderL`: Accessory > Handle (this mesh) > Attachment 'LeftShoulderAttachment' at the origin.
- `ACC_Armor_ShoulderR`: Accessory > Handle (this mesh) > Attachment 'RightShoulderAttachment' at the origin.
- `ACC_Armor_Belt`: Accessory > Handle (this mesh) > Attachment 'WaistCenterAttachment' at the origin.

</details>

## Resource pickups

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Pickup_Stick` | Pickup | 1.7 × 0.5 × 0.5 | 96 | — |  | Stick: three thin sticks tied with fibre (long, thin, crossed). |
| `SM_Pickup_Stone` | Pickup | 1.4 × 0.7 × 0.9 | 160 | — |  | Rock/stone: two veined chunks (matches the stone deposits). |
| `SM_Pickup_Wood` | Pickup | 1.1 × 0.9 × 1.3 | 72 | — |  | Wood: stack of chunky split logs with bright end grain. |
| `SM_Pickup_Fiber` | Pickup | 0.5 × 0.3 × 1.7 | 174 | — |  | Plant fibre: pale-gold bundle tied at the waist, fanned ends. |
| `SM_Pickup_Rope` | Pickup | 1.6 × 0.4 × 1.2 | 606 | — |  | Rope: flat coil with a trailing end. |
| `SM_Pickup_Leather` | Pickup | 1.3 × 0.5 × 1.3 | 204 | — |  | Leather: folded hides with stitched edges, tied with cord. |
| `SM_Pickup_Ammo` | Pickup | 1.2 × 0.8 × 0.8 | 506 | — |  | Generic ammunition: open wooden case of brass cartridges. |
| `SM_Pickup_Bandage` | Pickup | 0.6 × 0.8 × 1.5 | 140 | — |  | Bandage: white roll with a loose tail and a red cross-free band (no medical symbols). |
| `SM_Pickup_Diamond` | Pickup | 1.3 × 1.0 × 1.3 | 48 | — |  | Diamond currency: large faceted gem (world drop, shop and UI icon model). |

<details><summary>Notes</summary>

- `SM_Pickup_Diamond`: Suggested: Material Glass or Neon rim light; spin slowly.

</details>

## Loot and special equipment

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_CarePackage_Crate` | Structure | 4.5 × 3.4 × 4.5 | 692 | — |  | Main air-dropped care package. Lid = SM_CarePackage_Lid (hinged; rotate ~-110 deg or detach). |
| ↳ `SM_CarePackage_Lid` | MovingPart | 4.2 × 0.5 × 4.4 | 130 | — | | Hinge along the back top edge. Rotate about the part's X axis to open. |
| `SM_Parachute_Canopy` | Effect | 14.0 × 4.4 × 14.0 | 320 | — |  | Parachute canopy, separate from lines and crate. CanCollide off. Alternating orange/cream gores. |
| `SM_Parachute_Lines` | Effect | 13.9 × 12.4 × 13.9 | 164 | — |  | Suspension lines + riser (separate so they can be hidden/cut on landing). CanCollide off. |
| `SM_Beacon` | WorldProp | 1.8 × 5.1 × 2.0 | 130 | — |  | Drop-zone beacon: tripod with a red lamp. Light_Att for a pulsing red PointLight; Smoke_Att for signal smoke. |
| `SM_LandingMarker` | WorldProp | 8.0 × 0.3 × 8.0 | 344 | — |  | Ground X of orange cloth pinned with stones: marks where the package will land (CanCollide off). |
| `SM_SupplyCrate_Small01` | Structure | 1.9 × 1.5 × 1.9 | 80 | — |  | Small unmarked forest supply crate (lid SM_SupplyCrate_Small01_Lid). |
| ↳ `SM_SupplyCrate_Small01_Lid` | MovingPart | 1.9 × 0.2 × 1.9 | 56 | — | | Hinge along the back top edge. |
| `SM_SupplyCrate_Small02` | Structure | 3.3 × 1.1 × 1.5 | 80 | — |  | Long supply crate (weapons-length; lid SM_SupplyCrate_Small02_Lid). |
| ↳ `SM_SupplyCrate_Small02_Lid` | MovingPart | 3.3 × 0.2 × 1.5 | 56 | — | | Hinge along the back top edge. |
| `SM_SupplyCrate_Small03` | Structure | 3.7 × 1.3 × 3.4 | 160 | — |  | Rope-bound supply chest half-sunk in moss (lid SM_SupplyCrate_Small03_Lid). |
| ↳ `SM_SupplyCrate_Small03_Lid` | MovingPart | 2.3 × 0.2 × 1.7 | 56 | — | | Hinge along the back top edge. |
| `SM_Bandage_Held` | Equippable | 0.5 × 1.5 × 0.7 | 140 | — |  | Held-use bandage (play while healing). |
| `SM_Ammo_Pistol` | Pickup | 0.9 × 0.8 × 0.6 | 176 | — |  | Pistol ammo pickup: small leather-strapped box with short rounds on top. |
| `SM_Ammo_Shotgun` | Pickup | 1.1 × 0.9 × 0.7 | 268 | — |  | Shotgun shells: fat red shells with brass bases in a leather pouch. |
| `SM_Ammo_Rifle` | Pickup | 1.3 × 1.0 × 0.6 | 206 | — |  | Rifle ammo: long rounds on a metal stripper clip atop a wooden box. |

<details><summary>Notes</summary>

- `SM_CarePackage_Crate`: ItemSpawn1-3_Att sit 5 studs out in front so the three released items stay visible. ParachuteLink_Att = where SM_Parachute_Lines attaches (top centre).

</details>

## Firearms

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Pistol` | Equippable | 0.3 × 1.1 × 1.4 | 186 | — |  | Sidearm. Slide is SM_Pistol_Slide (recoils +Z about 0.3 studs). |
| ↳ `SM_Pistol_Slide` | MovingPart | 0.3 × 0.3 × 1.5 | 168 | — | | Slide at rest. Animate along +Z (backwards) ~0.3 studs per shot. |
| `SM_Shotgun` | Equippable | 0.3 × 1.1 × 5.7 | 398 | — |  | Pump shotgun. Fore-end is SM_Shotgun_Pump (slides +Z 0.6 studs to cycle). |
| ↳ `SM_Shotgun_Pump` | MovingPart | 0.3 × 0.3 × 1.2 | 276 | — | | Pump at rest. Slide along +Z 0.6 studs and back to cycle. |
| `SM_Rifle` | Equippable | 0.3 × 1.2 × 5.7 | 582 | — |  | Bolt-action hunting rifle. Bolt is SM_Rifle_Bolt (lift and pull back +Z 0.5 studs). |
| ↳ `SM_Rifle_Bolt` | MovingPart | 0.5 × 0.4 × 0.8 | 134 | — | | Bolt axis at rest. Rotate 60 deg about -Z (lift handle), then slide +Z 0.5 studs. |

<details><summary>Notes</summary>

- `SM_Pistol`: Muzzle_Att: flash/raycast origin. ShellEject_Att: casing particles, right side.
- `SM_Shotgun`: SecondHand_Att on the pump for the left hand.
- `SM_Rifle`: Longest gun: 4.6 studs. SecondHand_Att under the fore-stock.

</details>

## Wildlife (rigged)

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SK_Wolf` | Rig | 1.6 × 4.0 × 6.5 | 1986 | — |  | Pack hunter. Fast, low HP. Idle/Walk/Run/Alert/Attack/Hit/Death/Howl. |
| `SK_Bear` | Rig | 3.1 × 4.7 × 7.9 | 1980 | — |  | Heavy threat: slow, tanky. Idle/Walk/Run/Alert/Attack(swipe)/Hit/Death/RearUp. |
| `SK_Bat` | Rig | 5.2 × 0.7 × 1.9 | 1004 | — |  | Night swarm flyer. Pivot = body centre (hovers; not ground-based). Idle(hover)/Fly/FastFly/Alert/Attack(dive)/Hit/Death(fall). |

<details><summary>Notes</summary>

- `SK_Wolf`: 23 bones, max 3 influences/vertex, Root has no influence. Front faces -Z.
- `SK_Bear`: 21 bones, max 3 influences/vertex, Root has no influence. Front faces -Z.
- `SK_Bat`: 18 bones, max 3 influences/vertex, Root has no influence. Front faces -Z.

</details>

## Lobby kit

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Lobby_GatheringArea` | Lobby | 26.0 × 7.3 × 26.0 | 1464 | — |  | Central gathering deck (radius 13) with a stone fire pit and log seating ring. |
| `SM_Lobby_ReadyStation` | Lobby | 8.9 × 8.7 × 5.4 | 664 | — |  | Ready-up arch over a glowing stone pad. Stand on Pad_Att to ready up. |
| `SM_Lobby_PartyArea` | Lobby | 14.1 × 8.0 × 14.0 | 532 | — |  | Party gathering platform: four stump seats around a lantern totem. |
| `SM_Lobby_PowerupStand` | Lobby | 2.9 × 4.0 × 3.0 | 276 | — |  | Pedestal for one powerup emblem (Emblem_Att), with a blank plaque slot (Plaque_Att). |
| `SM_Lobby_ShopDisplay` | Lobby | 10.0 × 7.4 × 6.9 | 636 | — |  | Market stall: counter, shelves, striped awning, three display plinths (Item1-3_Att). |
| `SM_Sign_Post` | Lobby | 4.0 × 5.1 × 0.5 | 68 | — |  | Signpost with a 3.5 x 1.8 blank panel (SM_Sign_Post_Panel). |
| ↳ `SM_Sign_Post_Panel` | MovingPart | 3.5 × 1.8 × 0.2 | 12 | — | | Panel centre. Front (-Z) face is the UI surface; use SurfaceGui Face=Front. |
| `SM_Sign_Hanging` | Lobby | 4.5 × 3.4 × 0.3 | 72 | — |  | Hanging sign on ropes with a 4 x 2 blank panel (SM_Sign_Hanging_Panel). |
| ↳ `SM_Sign_Hanging_Panel` | MovingPart | 4.0 × 2.0 × 0.2 | 12 | — | | Panel centre. Front (-Z) face is the UI surface; use SurfaceGui Face=Front. |
| `SM_Sign_Board` | Lobby | 12.0 × 9.3 × 1.6 | 112 | — |  | Large notice board with roof: 9 x 4.5 blank panel (SM_Sign_Board_Panel) for leaderboards / shop. |
| ↳ `SM_Sign_Board_Panel` | MovingPart | 9.0 × 4.5 × 0.2 | 12 | — | | Panel centre. Front (-Z) face is the UI surface; use SurfaceGui Face=Front. |
| `SM_Sign_Plaque` | Lobby | 1.8 × 0.9 × 0.3 | 48 | — |  | Small blank plaque (SM_Sign_Plaque_Panel) for powerup names/prices on the stands. |
| ↳ `SM_Sign_Plaque_Panel` | MovingPart | 1.3 × 0.5 × 0.2 | 12 | — | | Panel centre. Front (-Z) face is the UI surface; use SurfaceGui Face=Front. |
| `SM_Emblem_Trailblazer` | Lobby | 2.6 × 2.6 × 0.5 | 468 | — |  | Trailblazer (movement/sprint): winged boot with speed streaks. |
| `SM_Emblem_Scavenger` | Lobby | 2.6 × 2.6 × 0.5 | 604 | — |  | Scavenger (gathering/finding crates): magnifying glass over a sparkle. |
| `SM_Emblem_Hunter` | Lobby | 2.6 × 2.6 × 0.5 | 600 | — |  | Hunter (tracking/fighting animals): paw print with three claw slashes. |
| `SM_Emblem_Climber` | Lobby | 2.6 × 2.6 × 0.5 | 602 | — |  | Climber (climbing/crossing walls): grappling hook with rope coil. |
| `SM_Emblem_Craftsman` | Lobby | 2.6 × 2.6 × 0.5 | 440 | — |  | Craftsman (building/repairs): hammer over an anvil. |
| `SM_Emblem_Sharpshooter` | Lobby | 2.6 × 2.6 × 0.6 | 782 | — |  | Sharpshooter (aiming/archery): target rings pierced by an arrow. |

<details><summary>Notes</summary>

- `SM_Lobby_GatheringArea`: Fire pit: reuse SM_Campfire_Flames at FirePit_Att. Spawn_Att marks the spawn centre.
- `SM_Lobby_ReadyStation`: Glow ring: set to Neon via a separate part if desired, or add a SurfaceLight at Pad_Att. Mount SM_Sign_Hanging_Panel at SignMount_Att for the countdown UI.
- `SM_Lobby_PartyArea`: Seat1-4_Att: party member spots (use Seats). TotemTop_Att: party banner / UI.
- `SM_Lobby_PowerupStand`: Put an SM_Emblem_* at Emblem_Att; mount SM_Sign_Plaque_Panel at Plaque_Att for the name/price UI.
- `SM_Lobby_ShopDisplay`: Mount SM_Sign_Board_Panel at SignMount_Att for shop UI.
- `SM_Emblem_Trailblazer`: No text. Can double as a 3D icon for the powerup UI.
- `SM_Emblem_Scavenger`: No text. Can double as a 3D icon for the powerup UI.
- `SM_Emblem_Hunter`: No text. Can double as a 3D icon for the powerup UI.
- `SM_Emblem_Climber`: No text. Can double as a 3D icon for the powerup UI.
- `SM_Emblem_Craftsman`: No text. Can double as a 3D icon for the powerup UI.
- `SM_Emblem_Sharpshooter`: No text. Can double as a 3D icon for the powerup UI.

</details>

## Survival Wars: landscape, cave and forest-variety kit

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Cliff_Face01` | WorldProp | 24.8 × 26.4 × 9.7 | 1040 | 320 |  | Modular cliff face for the map rim (20 wide x 26 tall). Tile along X; rotate/flip for variety. |
| `SM_Cliff_Face02` | WorldProp | 24.6 × 23.6 × 9.7 | 644 | 216 |  | Cliff face variant with a ledge and hanging roots. |
| `SM_CaveEntrance` | WorldProp | 20.9 × 15.4 × 9.8 | 972 | 288 |  | Rock arch that frames a cave mouth. Opening faces Blender -Y (the forest); the tunnel runs along +Y (into the cliff). WorldService carves the tunnel into terrain. |
| `SM_CaveTunnel_Segment` | WorldProp | 14.8 × 12.9 × 12.4 | 752 | 196 |  | Modular cave interior piece (8 studs long, 11 wide, 10 tall), open front/back. Chain along +Y to line a tunnel carved in terrain. |
| `SM_CaveChamber_End` | WorldProp | 19.4 × 15.9 × 20.2 | 920 | 240 |  | Dome that caps a cave tunnel (dead end / chamber), with glowing crystals. |
| `SM_Riverbank_Straight` | WorldProp | 16.0 × 2.1 × 10.1 | 728 | 728 |  | Riverbank strip (16 long): grass/moss -> mud -> rocks -> water edge (at -Y). Lines stream edges; water stays terrain water. |
| `SM_Riverbank_Bend` | WorldProp | 13.8 × 2.1 × 12.6 | 728 | 728 |  | Curved riverbank strip (45-degree bend). |
| `SM_Ground_Forest01` | WorldProp | 32.0 × 2.5 × 32.0 | 1152 | 1152 |  | Modular 32x32 forest-floor section (moss, leaf litter, dirt, grass). Edges are flat at Z=0 so sections tile seamlessly; used for hand-built areas (lobby, set pieces). |
| `SM_Ground_Clearing01` | WorldProp | 32.0 × 2.7 × 32.0 | 1392 | 1392 |  | Modular 32x32 camp-clearing section: packed earth centre, grass edge, a stone ring. |
| `SM_Trail_Segment01` | WorldProp | 5.0 × 0.7 × 12.0 | 144 | — |  | Dirt trail strip with a log edge and stones (12 long). Decal-like; sits 0.05 above ground. |
| `SM_Roots01` | WorldProp | 5.0 × 0.6 × 4.8 | 130 | — |  | Surface roots (decor, no collision). |
| `SM_Roots02` | WorldProp | 4.9 × 0.9 × 2.7 | 108 | — |  | Arching roots (decor, no collision). |
| `SM_Flowers01` | WorldProp | 2.5 × 1.0 × 2.3 | 308 | — |  | Wildflower clump (warm). |
| `SM_Flowers02` | WorldProp | 2.4 × 1.0 × 2.4 | 308 | — |  | Wildflower clump (cool). |
| `SM_Sapling01` | WorldProp | 2.5 × 5.1 × 2.4 | 266 | — |  | Young tree (5 studs). |
| `SM_Tree_Spruce01` | WorldProp | 12.2 × 20.4 × 12.0 | 166 | 84 |  | Narrow dark spruce (20 studs). |
| `SM_Tree_Spruce02` | WorldProp | 14.4 × 24.4 × 14.2 | 198 | 100 |  | Broad old spruce (24 studs). |
| `SM_Tree_Aspen01` | WorldProp | 7.7 × 19.2 × 7.5 | 598 | 160 |  | Slim pale aspen with a high round crown (18 studs). |
| `SM_ScrapPile01` | Harvestable | 4.3 × 2.1 × 3.8 | 220 | — |  | Scrap Pile resource node (pickaxe). Yield mesh; hide when mined out. |
| `SM_OreDeposit_Coal` | Harvestable | 5.2 × 3.6 × 4.5 | 200 | — |  | Coal seam node (Stone Pickaxe+). |
| `SM_OreDeposit_Iron` | Harvestable | 5.4 × 3.3 × 4.6 | 200 | — |  | Iron deposit node (Stone Pickaxe+). Rich veins use this mesh at 1.3x with a glow. |

<details><summary>Notes</summary>

- `SM_Cliff_Face01`: Visual only. The rim is voxel terrain; collision stays on the terrain (simplified).
- `SM_Ground_Forest01`: Collision: the flat top (box). Small bumps are visual only.

</details>

## Survival Wars: points of interest

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_POI_Campsite` | Structure | 18.5 × 3.7 × 15.0 | 436 | 316 |  | Abandoned campsite (common POI): two tents, fire pit, log seats, crate, backpack. |
| `SM_POI_Shed` | Structure | 9.0 × 7.8 × 7.0 | 724 | — |  | Tool shed (common POI), 8x6, lean-to tin roof. |
| `SM_POI_HuntingBlind` | Structure | 6.4 × 8.6 × 6.9 | 256 | — |  | Raised hunting blind (common POI): platform at 6 studs, camouflage screens, ladder at +Y. |
| `SM_POI_BrokenVehicle` | Structure | 15.1 × 5.3 × 9.4 | 368 | 176 |  | Rusted pickup truck (common POI), tilted into a ditch; scrap piles nearby are separate nodes. |
| `SM_POI_SmallCabin` | Structure | 10.9 × 11.6 × 10.9 | 1040 | 472 |  | Small log cabin (common POI), 10x8 with windows, porch, stove pipe. |
| `SM_POI_Cabin` | Structure | 14.9 × 12.8 × 13.4 | 1204 | 580 |  | Log cabin (uncommon POI), 14x10, stone chimney, porch. |
| `SM_POI_RangerStation` | Structure | 15.6 × 12.8 × 22.1 | 1428 | 796 | yes | Ranger station (uncommon POI): green office 14x11 + lookout on stilts behind, flagpole. |
| `SM_POI_LoggingCamp` | Structure | 19.1 × 9.4 × 24.0 | 960 | 448 |  | Logging camp (uncommon POI): small shed, stacked logs, sawhorse. |
| `SM_POI_AbandonedHouse` | Structure | 16.5 × 14.0 × 17.6 | 1238 | 704 |  | Ruined two-room house (uncommon POI): collapsed side wall and half the roof. |
| `SM_POI_MineEntrance` | Structure | 15.7 × 8.5 × 20.6 | 596 | 204 |  | Timbered mine mouth in a rock mound (uncommon POI), rails and a cart outside. |
| `SM_POI_Bunker` | Structure | 14.6 × 8.7 × 14.9 | 912 | 544 |  | Half-buried concrete bunker (rare POI): thick walls, mossy slab, sandbags. |
| `SM_POI_Outpost` | Structure | 26.6 × 9.4 × 20.6 | 722 | 504 |  | Abandoned outpost (rare POI): palisade ring open at +Y, tents, small watch deck, fire pit. |
| `SM_POI_IndustrialSite` | Structure | 34.9 × 10.6 × 22.5 | 312 | 180 |  | Derelict industrial yard (rare POI): steel shed, two containers, fuel tank, barrels. |
| `SM_POI_LargeMine` | Structure | 19.4 × 14.8 × 20.9 | 776 | 324 |  | Large mine (rare POI): mine mouth + wooden headframe with wheel + ore shed. |

## Survival Wars: POI chests

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Chest_Common` | Structure | 3.4 × 2.4 × 2.5 | 144 | — |  | Common POI chest body (lid stays procedural so it can open). |
| `SM_Chest_Uncommon` | Structure | 3.4 × 2.4 × 2.5 | 144 | — |  | Uncommon POI chest body (painted green, iron trim). |
| `SM_Chest_Rare` | Structure | 3.4 × 2.4 × 2.5 | 156 | — |  | Rare POI chest body (blue, brass trim, glowing lock). |
| `SM_Chest_VeryRare` | Structure | 3.4 × 2.4 × 2.5 | 156 | — |  | Very Rare POI chest body (purple, gold trim, glowing lock). |

## Survival Wars: tiered and breaching tools, bows

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_Pickaxe_Stone` | Equippable | 0.5 × 3.6 × 2.2 | 332 | — |  | Crude/Stone Pickaxe (tinted by tier in game). Tool > Handle. |
| `SM_Pickaxe_Iron` | Equippable | 0.3 × 3.6 × 2.6 | 180 | — |  | Iron/Steel Pickaxe. Tool > Handle. |
| `SM_Axe_Iron` | Equippable | 0.3 × 3.6 × 1.6 | 136 | — |  | Iron/Steel Axe. Tool > Handle. |
| `SM_Crowbar` | Equippable | 0.1 × 3.5 × 0.9 | 60 | — |  | Crowbar (breaching tool). Tool > Handle. |
| `SM_Sledgehammer` | Equippable | 0.6 × 4.2 × 1.5 | 156 | — |  | Sledgehammer (breaching tool, heavy vs walls). Tool > Handle. |
| `SM_HuntingBow` | Equippable | 0.3 × 4.8 × 0.8 | 96 | — |  | Hunting Bow (Tier III). Draw along -Z. |
| `SM_Crossbow` | Equippable | 3.2 × 0.9 × 3.0 | 126 | — |  | Crossbow (Tier IV). Points along -Z; bolts. |

## Survival Wars: storage tiers, walls, floor, traps, Workbench IV/V

| Name | Kind | Size (studs) | Tris | LOD1 | Team | Use |
|---|---|---|---|---|---|---|
| `SM_ReinforcedChest` | Structure | 6.2 × 4.3 × 4.3 | 124 | — |  | Reinforced Chest storage (Tier II, 20 stacks). |
| `SM_MetalLocker` | Structure | 4.0 × 7.0 × 3.2 | 92 | — |  | Metal Locker storage (Tier III, 30 stacks). |
| `SM_SurvivalSafe` | Structure | 4.5 × 5.0 × 4.8 | 100 | — |  | Survival Safe storage (Tier IV, 45 stacks). |
| `SM_ScrapWall` | Structure | 10.5 × 10.4 × 1.4 | 108 | — |  | Scrap Wall (Tier III): corrugated sheets on a timber frame, 10 wide. |
| `SM_MetalWall` | Structure | 10.8 × 11.0 × 2.6 | 288 | — |  | Metal Wall (Tier IV): riveted plates between beams, 10 wide. |
| `SM_WoodFloor` | Structure | 10.0 × 1.0 × 10.0 | 376 | — |  | Wooden Floor (Tier I), 10x10 platform. |
| `SM_BearTrap` | Structure | 2.6 × 0.6 × 1.8 | 360 | — |  | Bear Trap (Tier III), set. |
| `SM_Snare` | Structure | 3.1 × 3.2 × 2.5 | 138 | — |  | Snare (Tier II): rope loop on a bent sapling. |
| `SM_TripwireAlarm` | Structure | 7.9 × 1.4 × 0.5 | 96 | — |  | Tripwire Alarm (Tier II): stakes, wire and can rattle. |
| `SM_Workbench_Level04` | Structure | 12.1 × 7.7 × 4.0 | 160 | — |  | Workbench Tier IV: stone forge with coals and chimney beside the bench. |
| `SM_Workbench_Level05` | Structure | 12.2 × 7.7 × 4.1 | 208 | — |  | Workbench Tier V: steel-plated top, tool rack and forge. |

