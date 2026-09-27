# Pivots, attachments and collision

All positions below are in the asset's own Roblox space (studs; X right, Y up, -Z front). Attachment objects are exported as `<Name>_Att` meshes, which Roblox's importer turns into `Attachment` instances. `Roblox/SurvivalHourAssetData.lua` has the same data as CFrames, so `SurvivalHourSetup.lua` can rebuild any that are missing.

## Reference

### `SM_Reference_Dummy_R15`
- Pivot: Between the feet, on the ground.
- Collision: CollisionFidelity **Box**

## Forest kit

### `SM_Tree_Pine_Medium01`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 2.0 × 2.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Pine_Medium01.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Pine_Medium02`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 2.0 × 2.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Pine_Medium02.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Pine_Large01`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 3.0 × 3.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Pine_Large01.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Pine_Small01`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 1.5 × 1.5 studs (X × Z)
- Attachments: `HarvestHit_Att` (0.00, 1.10, -0.50)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Pine_Small01.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Oak_Medium01`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 2.0 × 2.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Oak_Medium01.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Oak_Medium02`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 2.0 × 2.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Oak_Medium02.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Oak_Large01`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 3.5 × 3.5 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Oak_Large01.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Oak_Small01`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 1.5 × 1.5 studs (X × Z)
- Attachments: `HarvestHit_Att` (0.00, 1.00, -0.47)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Oak_Small01.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Birch_Medium01`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 1.5 × 1.5 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Birch_Medium01.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Birch_Small01`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 1.2 × 1.2 studs (X × Z)
- Attachments: `HarvestHit_Att` (0.00, 1.00, -0.37)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Birch_Small01.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Dead_Large01`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 2.5 × 2.5 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Dead_Large01.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Pine_Small01_Stump`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 3.0 × 3.1 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Pine_Small01_Stump.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Oak_Small01_Stump`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 3.2 × 2.9 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Oak_Small01_Stump.fbx`; fallback CollisionFidelity **Box**

### `SM_Tree_Birch_Small01_Stump`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 2.9 × 2.7 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Tree_Birch_Small01_Stump.fbx`; fallback CollisionFidelity **Box**

### `SM_Stump_Old01`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 4.1 × 4.1 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Stump_Old01.fbx`; fallback CollisionFidelity **Box**

### `SM_Stump_Old02`
- Pivot: Base of the trunk at ground level (Z=0 is the ground).
- Footprint: 3.7 × 3.7 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Stump_Old02.fbx`; fallback CollisionFidelity **Box**

### `SM_FallenLog01`
- Pivot: Centre on the ground.
- Footprint: 8.0 × 1.8 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_FallenLog01.fbx`; fallback CollisionFidelity **Box**

### `SM_FallenLog02_Hollow`
- Pivot: Centre on the ground.
- Footprint: 10.0 × 2.8 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_FallenLog02_Hollow.fbx`; fallback CollisionFidelity **Box**

### `SM_Branch01`
- Pivot: Centre on the ground.
- Footprint: 4.5 × 3.0 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Branch02`
- Pivot: Centre on the ground.
- Footprint: 3.6 × 2.9 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Sticks_Loose01`
- Pivot: Centre on the ground.
- Footprint: 1.9 × 3.1 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Rock_Small01`
- Pivot: Centre on the ground.
- Footprint: 1.8 × 1.3 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Rock_Small02`
- Pivot: Centre on the ground.
- Footprint: 2.5 × 1.7 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Rock_Small03`
- Pivot: Centre on the ground.
- Footprint: 2.8 × 2.4 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Boulder01`
- Pivot: Centre on the ground.
- Footprint: 9.5 × 6.7 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Boulder01.fbx`; fallback CollisionFidelity **Hull**

### `SM_Boulder02`
- Pivot: Centre on the ground.
- Footprint: 6.8 × 5.9 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Boulder02.fbx`; fallback CollisionFidelity **Hull**

### `SM_Boulder03`
- Pivot: Centre on the ground.
- Footprint: 6.9 × 5.5 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Boulder03.fbx`; fallback CollisionFidelity **Hull**

### `SM_StoneDeposit01`
- Pivot: Centre on the ground.
- Footprint: 6.0 × 4.2 studs (X × Z)
- Attachments: `HarvestHit_Att` (0.00, 1.20, -2.10)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_StoneDeposit01.fbx`; fallback CollisionFidelity **Hull**

### `SM_StoneDeposit01_Depleted`
- Pivot: Centre on the ground.
- Footprint: 4.4 × 4.5 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_StoneDeposit01_Depleted.fbx`; fallback CollisionFidelity **Box**

### `SM_FiberPlant01`
- Pivot: Centre on the ground.
- Footprint: 1.9 × 1.9 studs (X × Z)
- Attachments: `HarvestHit_Att` (0.00, 1.20, 0.00)
- Collision: CollisionFidelity **Box**

### `SM_FiberPlant01_Harvested`
- Pivot: Centre on the ground.
- Footprint: 0.5 × 0.8 studs (X × Z)
- Collision: CollisionFidelity **Box**

### `SM_Grass_Clump01`
- Pivot: Centre on the ground.
- Footprint: 1.2 × 1.4 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Grass_Clump02`
- Pivot: Centre on the ground.
- Footprint: 2.6 × 1.3 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Grass_Clump03`
- Pivot: Centre on the ground.
- Footprint: 1.3 × 1.1 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Bush01`
- Pivot: Centre on the ground.
- Footprint: 2.9 × 3.4 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Bush02`
- Pivot: Centre on the ground.
- Footprint: 4.5 × 4.5 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Bush03_Berry`
- Pivot: Centre on the ground.
- Footprint: 3.3 × 3.1 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Fern01`
- Pivot: Centre on the ground.
- Footprint: 4.0 × 3.9 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Fern02`
- Pivot: Centre on the ground.
- Footprint: 2.8 × 2.9 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Mushrooms01`
- Pivot: Centre on the ground.
- Footprint: 1.5 × 1.0 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Mushrooms02_Glow`
- Pivot: Centre on the ground.
- Footprint: 1.0 × 0.5 studs (X × Z)
- Attachments: `Glow_Att` (0.00, 0.50, 0.00)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_LeafLitter01`
- Pivot: Centre on the ground.
- Footprint: 6.1 × 5.0 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Pinecones01`
- Pivot: Centre on the ground.
- Footprint: 1.7 × 2.2 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_MossPatch01`
- Pivot: Centre on the ground.
- Footprint: 4.7 × 3.6 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Landmark_StandingStones`
- Pivot: Centre of the ring on the ground.
- Footprint: 20.0 × 20.0 studs (X × Z)
- Collision: 7 box(es) → `Export/Collision/Forest/COL_Landmark_StandingStones.fbx`; fallback CollisionFidelity **Hull**

### `SM_Landmark_AntlerTotem`
- Pivot: Base on the ground.
- Footprint: 3.0 × 3.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Landmark_AntlerTotem.fbx`; fallback CollisionFidelity **Box**

### `SM_Landmark_GiantLog`
- Pivot: Centre on the ground.
- Footprint: 22.0 × 7.0 studs (X × Z)
- Collision: 3 box(es) → `Export/Collision/Forest/COL_Landmark_GiantLog.fbx`; fallback CollisionFidelity **Default**

### `SM_Clearing_GroundPatch`
- Pivot: Centre on the ground (top surface at Z=0.05).
- Footprint: 40.0 × 40.0 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Camp_LogBench`
- Pivot: Centre on the ground.
- Footprint: 5.0 × 1.4 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Camp_LogBench.fbx`; fallback CollisionFidelity **Box**

### `SM_Camp_FirewoodStack`
- Pivot: Centre on the ground.
- Footprint: 3.2 × 1.6 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Camp_FirewoodStack.fbx`; fallback CollisionFidelity **Box**

### `SM_Camp_DryingRack`
- Pivot: Centre on the ground.
- Footprint: 4.5 × 2.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Camp_DryingRack.fbx`; fallback CollisionFidelity **Box**

### `SM_Camp_Lantern`
- Pivot: Base of the post on the ground.
- Footprint: 1.0 × 1.0 studs (X × Z)
- Attachments: `Light_Att` (-0.90, 4.30, 0.00)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Camp_Lantern.fbx`; fallback CollisionFidelity **Box**

### `SM_Camp_Bedroll`
- Pivot: Centre on the ground.
- Footprint: 2.0 × 5.0 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Camp_Barrel`
- Pivot: Centre on the ground.
- Footprint: 2.0 × 2.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Camp_Barrel.fbx`; fallback CollisionFidelity **Hull**

### `SM_Camp_ChoppingBlock`
- Pivot: Centre on the ground.
- Footprint: 2.0 × 2.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Camp_ChoppingBlock.fbx`; fallback CollisionFidelity **Box**

### `SM_Camp_TeamBanner`
- Pivot: Base of the pole on the ground.
- Footprint: 2.0 × 1.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Forest/COL_Camp_TeamBanner.fbx`; fallback CollisionFidelity **Box**

## Stream kit

### `SM_Stream_Straight`
- Pivot: Centre of the piece at original ground level (bank tops at +1.2, bed at -1.6).
- Footprint: 24.0 × 16.0 studs (X × Z)
- Collision: CollisionFidelity **Default** (or CanCollide off for decor)

### `SM_Stream_Bend90`
- Pivot: Centre of the piece at original ground level (bank tops at +1.2, bed at -1.6).
- Footprint: 28.0 × 28.0 studs (X × Z)
- Collision: CollisionFidelity **Default** (or CanCollide off for decor)

### `SM_Stream_PoolEnd`
- Pivot: Centre of the piece at original ground level (bank tops at +1.2, bed at -1.6).
- Footprint: 24.0 × 24.0 studs (X × Z)
- Attachments: `Refill_Att` (0.00, -0.60, 7.00)
- Collision: CollisionFidelity **Default** (or CanCollide off for decor)

### `SM_Stream_Water_Straight`
- Pivot: Centre of the piece at original ground level (bank tops at +1.2, bed at -1.6).
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Stream_Water_Bend90`
- Pivot: Centre of the piece at original ground level (bank tops at +1.2, bed at -1.6).
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Stream_Water_PoolEnd`
- Pivot: Centre of the piece at original ground level (bank tops at +1.2, bed at -1.6).
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_StreamRocks01`
- Pivot: Centre on the bed.
- Footprint: 3.2 × 3.4 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_StreamRocks02`
- Pivot: Centre on the bed.
- Footprint: 7.6 × 2.2 studs (X × Z)
- Collision: 3 box(es) → `Export/Collision/Stream/COL_StreamRocks02.fbx`; fallback CollisionFidelity **Box**

### `SM_StreamRocks03`
- Pivot: Centre on the bed.
- Footprint: 3.0 × 4.2 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

## Starting camp

### `SM_Campfire_Burning`
- Pivot: Centre of the fire pit on the ground.
- Footprint: 6.4 × 6.4 studs (X × Z)
- Attachments: `Fire_Att` (0.00, 0.60, 0.00), `Smoke_Att` (0.00, 3.60, 0.00), `Light_Att` (0.00, 2.40, 0.00), `Extinguish_Att` (0.00, 1.20, 0.00), `WaterTarget_Att` (0.00, 0.20, 0.00), `TeamFlag_Att` (-2.10, 6.30, 2.60)
- Collision: 1 box(es) → `Export/Collision/Camp/COL_Campfire_Burning.fbx`; fallback CollisionFidelity **Box**

### `SM_Campfire_Extinguished`
- Pivot: Centre of the fire pit on the ground.
- Footprint: 6.4 × 6.4 studs (X × Z)
- Attachments: `Fire_Att` (0.00, 0.60, 0.00), `Smoke_Att` (0.00, 3.60, 0.00), `Light_Att` (0.00, 2.40, 0.00), `Extinguish_Att` (0.00, 1.20, 0.00), `WaterTarget_Att` (0.00, 0.20, 0.00), `TeamFlag_Att` (-2.10, 6.30, 2.60)
- Collision: 1 box(es) → `Export/Collision/Camp/COL_Campfire_Extinguished.fbx`; fallback CollisionFidelity **Box**

### `SM_Campfire_ColdWet`
- Pivot: Centre of the fire pit on the ground.
- Footprint: 6.4 × 6.4 studs (X × Z)
- Attachments: `Fire_Att` (0.00, 0.60, 0.00), `Smoke_Att` (0.00, 3.60, 0.00), `Light_Att` (0.00, 2.40, 0.00), `Extinguish_Att` (0.00, 1.20, 0.00), `WaterTarget_Att` (0.00, 0.20, 0.00), `TeamFlag_Att` (-2.10, 6.30, 2.60)
- Collision: 1 box(es) → `Export/Collision/Camp/COL_Campfire_ColdWet.fbx`; fallback CollisionFidelity **Box**

### `SM_Campfire_Flames`
- Pivot: Centre of the fire pit on the ground (same as the campfire).
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Campfire_WaterTarget`
- Pivot: Centre of the fire pit on the ground (same as the campfire).
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Workbench_Level01`
- Pivot: Bottom centre on the ground. Players work from the front (-Z). Craft_Att = work surface, Prompt_Att = ProximityPrompt / UI anchor.
- Footprint: 6.0 × 3.0 studs (X × Z)
- Attachments: `Craft_Att` (0.00, 2.75, 0.00), `Prompt_Att` (0.00, 3.60, -1.60)
- Collision: 1 box(es) → `Export/Collision/Camp/COL_Workbench_Level01.fbx`; fallback CollisionFidelity **Box**

### `SM_Workbench_Level02`
- Pivot: Bottom centre on the ground. Players work from the front (-Z). Craft_Att = work surface, Prompt_Att = ProximityPrompt / UI anchor.
- Footprint: 7.0 × 3.5 studs (X × Z)
- Attachments: `Craft_Att` (0.00, 3.00, -0.40), `Prompt_Att` (0.00, 4.20, -1.90)
- Collision: 2 box(es) → `Export/Collision/Camp/COL_Workbench_Level02.fbx`; fallback CollisionFidelity **Box**

### `SM_Workbench_Level03`
- Pivot: Bottom centre on the ground. Players work from the front (-Z). Craft_Att = work surface, Prompt_Att = ProximityPrompt / UI anchor.
- Footprint: 8.0 × 4.0 studs (X × Z)
- Attachments: `Craft_Att` (0.00, 3.10, -0.50), `Prompt_Att` (0.00, 4.30, -2.10)
- Collision: 3 box(es) → `Export/Collision/Camp/COL_Workbench_Level03.fbx`; fallback CollisionFidelity **Box**

## Workbench level 1 craftables

### `SM_WoodenWall`
- Pivot: Bottom centre of the 8-stud span, on the ground. Snap pieces 8 studs apart along X; the left post (x=-4) belongs to this piece, the right end meets the next piece's post.
- Footprint: 8.0 × 1.5 studs (X × Z)
- Attachments: `SnapLeft_Att` (4.00, 0.00, 0.00), `SnapRight_Att` (-4.00, 0.00, 0.00)
- Collision: 1 box(es) → `Export/Collision/Crafting_L1/COL_WoodenWall.fbx`; fallback CollisionFidelity **Box**

### `SM_WoodenWall_Damaged`
- Pivot: Bottom centre of the 8-stud span, on the ground. Snap pieces 8 studs apart along X; the left post (x=-4) belongs to this piece, the right end meets the next piece's post.
- Footprint: 8.0 × 1.5 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Crafting_L1/COL_WoodenWall_Damaged.fbx`; fallback CollisionFidelity **Box**

### `SM_WallPost`
- Pivot: Post centre on the ground.
- Footprint: 1.4 × 1.4 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Crafting_L1/COL_WallPost.fbx`; fallback CollisionFidelity **Box**

### `SM_StoneAxe`
- Pivot: Grip point (RightGripAttachment). Handle runs up +Y, striking side faces forward (-Z). Default Tool.Grip = identity.
- Attachments: `Hit_Att` (0.00, 2.30, -0.85)
- Collision: CollisionFidelity **Box**

### `SM_StorageBox`
- Pivot: Bottom centre on the ground.
- Footprint: 3.0 × 2.0 studs (X × Z)
- Attachments: `Prompt_Att` (0.00, 2.20, -1.40), `Contents_Att` (0.00, 0.90, 0.00)
- Collision: 1 box(es) → `Export/Collision/Crafting_L1/COL_StorageBox.fbx`; fallback CollisionFidelity **Box**
- Part `SM_StorageBox_Lid` rests at (0.00, 1.80, 1.05): Hinge line along the back top edge. Rotate about the part's X axis to open (~-100 deg).

### `SM_StorageBox_Damaged`
- Pivot: Bottom centre on the ground.
- Footprint: 3.0 × 2.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Crafting_L1/COL_StorageBox_Damaged.fbx`; fallback CollisionFidelity **Box**
- Part `SM_StorageBox_Lid_Damaged` rests at (0.00, 1.80, 1.05): Hinge line along the back top edge. Rotate about the part's X axis to open (~-100 deg).

### `SM_Spear`
- Pivot: Grip point (RightGripAttachment). Points forward along -Z (LookVector), up is +Y. Default Tool.Grip = identity.
- Attachments: `Tip_Att` (0.00, 0.00, -4.85), `SecondHand_Att` (0.00, 0.00, 1.40)
- Collision: CollisionFidelity **Box**

### `SM_RepairHammer`
- Pivot: Grip point (RightGripAttachment). Handle runs up +Y, striking side faces forward (-Z). Default Tool.Grip = identity.
- Attachments: `Hit_Att` (0.00, 2.10, -1.00)
- Collision: CollisionFidelity **Box**

### `SM_Debris_Splinters`
- Pivot: Centre.
- Collision: CollisionFidelity **Box**

### `SM_Debris_LogChunk`
- Pivot: Centre.
- Collision: CollisionFidelity **Hull**

### `SM_Debris_MetalBand`
- Pivot: Centre.
- Collision: CollisionFidelity **Box**

## Workbench level 2 craftables

### `SM_Canteen`
- Pivot: Grip point (RightGripAttachment). Points forward along -Z (LookVector), up is +Y. Default Tool.Grip = identity.
- Attachments: `Pour_Att` (0.00, 1.40, -0.82)
- Collision: CollisionFidelity **Box**

### `SM_Bow`
- Pivot: Grip. Bow stands along +Y (Roblox), string toward the player (+Z), arrows fly along -Z.
- Attachments: `Nock_Att` (0.00, 0.10, 0.18), `ArrowRest_Att` (0.00, 0.12, -0.15)
- Collision: CollisionFidelity **Box**

### `SM_Arrow`
- Pivot: Centre of the shaft. Tip points -Z (flight direction).
- Attachments: `Tip_Att` (0.00, 0.00, -1.55), `Nock_Att` (0.00, 0.00, 1.50)
- Collision: CollisionFidelity **Box**

### `SM_ArrowBundle`
- Pivot: Centre on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Gate`
- Pivot: Bottom centre of the 8-stud span, on the ground. Snap pieces 8 studs apart along X; the left post (x=-4) belongs to this piece, the right end meets the next piece's post.
- Footprint: 8.0 × 1.5 studs (X × Z)
- Attachments: `Hinge_Att` (3.35, 0.05, 0.00), `SnapLeft_Att` (4.00, 0.00, 0.00), `SnapRight_Att` (-4.00, 0.00, 0.00)
- Collision: 2 box(es) → `Export/Collision/Crafting_L2/COL_Gate.fbx`; fallback CollisionFidelity **Box**
- Part `SM_Gate_Door` rests at (3.35, 0.05, 0.00): Hinge axis: bottom of the hinge edge. Rotate about the part's Y (up) axis. Closed = placement in SM_Gate.

### `SM_Gate_Door_Damaged`
- Pivot: Hinge axis, same as SM_Gate_Door.
- Collision: 1 box(es) → `Export/Collision/Crafting_L2/COL_Gate_Door_Damaged.fbx`; fallback CollisionFidelity **Box**

### `SM_Spikes`
- Pivot: Bottom centre of the 8-stud span, on the ground. Snap pieces 8 studs apart along X; the left post (x=-4) belongs to this piece, the right end meets the next piece's post.
- Footprint: 8.0 × 3.2 studs (X × Z)
- Attachments: `HurtZone_Att` (0.00, 1.30, -0.40)
- Collision: 1 box(es) → `Export/Collision/Crafting_L2/COL_Spikes.fbx`; fallback CollisionFidelity **Box**

### `SM_Spikes_Damaged`
- Pivot: Bottom centre of the 8-stud span, on the ground. Snap pieces 8 studs apart along X; the left post (x=-4) belongs to this piece, the right end meets the next piece's post.
- Footprint: 8.0 × 3.2 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Crafting_L2/COL_Spikes_Damaged.fbx`; fallback CollisionFidelity **Box**

## Workbench level 3 craftables

### `SM_ReinforcedWall`
- Pivot: Bottom centre of the 8-stud span, on the ground. Snap pieces 8 studs apart along X; the left post (x=-4) belongs to this piece, the right end meets the next piece's post.
- Footprint: 8.0 × 1.6 studs (X × Z)
- Attachments: `SnapLeft_Att` (4.00, 0.00, 0.00), `SnapRight_Att` (-4.00, 0.00, 0.00)
- Collision: 1 box(es) → `Export/Collision/Crafting_L3/COL_ReinforcedWall.fbx`; fallback CollisionFidelity **Box**

### `SM_ReinforcedWall_Damaged`
- Pivot: Bottom centre of the 8-stud span, on the ground. Snap pieces 8 studs apart along X; the left post (x=-4) belongs to this piece, the right end meets the next piece's post.
- Footprint: 8.0 × 1.6 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Crafting_L3/COL_ReinforcedWall_Damaged.fbx`; fallback CollisionFidelity **Box**

### `SM_Watchtower`
- Pivot: Bottom centre of the 8 x 8 footprint on the ground.
- Footprint: 8.0 × 8.0 studs (X × Z)
- Attachments: `TeamFlag_Att` (0.00, 22.20, 0.00), `Lookout_Att` (0.00, 10.20, 1.00)
- Collision: 11 box(es) → `Export/Collision/Crafting_L3/COL_Watchtower.fbx`; fallback CollisionFidelity **Box**
- Climb volume (TrussPart): see catalog.json `meta.climb_volume`

### `SM_Sword`
- Pivot: Grip point (RightGripAttachment). Handle runs up +Y, striking side faces forward (-Z). Default Tool.Grip = identity.
- Attachments: `Trail0_Att` (0.00, 0.80, -0.05), `Trail1_Att` (0.00, 3.60, -0.05), `Hit_Att` (0.00, 2.60, -0.20)
- Collision: CollisionFidelity **Box**

### `SM_Shield`
- Pivot: Hand grip behind the boss. Face points -Z (forward). Weld to LeftHand, or use as a Tool.
- Attachments: `Grip_Att` (0.00, 0.00, 0.00)
- Collision: CollisionFidelity **Box**

## Level 3 armour (rigid R15 accessories)

### `ACC_Armor_Helmet`
- Pivot: HatAttachment (origin). Front faces -Z.
- Attachments: `HatAttachment_Att` (0.00, 0.00, 0.00)
- Collision: CollisionFidelity **Box**

### `ACC_Armor_Chest`
- Pivot: BodyFrontAttachment (origin). Front faces -Z.
- Attachments: `BodyFrontAttachment_Att` (0.00, 0.00, 0.00)
- Collision: CollisionFidelity **Box**

### `ACC_Armor_Back`
- Pivot: BodyBackAttachment (origin). Front faces -Z.
- Attachments: `BodyBackAttachment_Att` (0.00, 0.00, 0.00)
- Collision: CollisionFidelity **Box**

### `ACC_Armor_ShoulderL`
- Pivot: LeftShoulderAttachment (origin). Front faces -Z.
- Attachments: `LeftShoulderAttachment_Att` (0.00, 0.00, 0.00)
- Collision: CollisionFidelity **Box**

### `ACC_Armor_ShoulderR`
- Pivot: RightShoulderAttachment (origin). Front faces -Z.
- Attachments: `RightShoulderAttachment_Att` (0.00, 0.00, 0.00)
- Collision: CollisionFidelity **Box**

### `ACC_Armor_Belt`
- Pivot: WaistCenterAttachment (origin). Front faces -Z.
- Attachments: `WaistCenterAttachment_Att` (0.00, 0.00, 0.00)
- Collision: CollisionFidelity **Box**

## Resource pickups

### `SM_Pickup_Stick`
- Pivot: Centre, resting on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Pickup_Stone`
- Pivot: Centre, resting on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Pickup_Wood`
- Pivot: Centre, resting on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Pickup_Fiber`
- Pivot: Centre, resting on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Pickup_Rope`
- Pivot: Centre, resting on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Pickup_Leather`
- Pivot: Centre, resting on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Pickup_Ammo`
- Pivot: Centre, resting on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Pickup_Bandage`
- Pivot: Centre, resting on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Pickup_Diamond`
- Pivot: Centre of the gem.
- Collision: CollisionFidelity **Box**

## Loot and special equipment

### `SM_CarePackage_Crate`
- Pivot: Bottom centre on the ground. Lid hinges on the back top edge.
- Footprint: 4.0 × 4.0 studs (X × Z)
- Attachments: `ItemSpawn1_Att` (3.83, 0.10, -3.21), `ItemSpawn2_Att` (0.00, 0.10, -5.00), `ItemSpawn3_Att` (-3.83, 0.10, -3.21), `ParachuteLink_Att` (0.00, 3.80, 0.00), `Smoke_Att` (-1.60, 3.90, -1.60), `Prompt_Att` (0.00, 2.40, -2.60)
- Collision: 1 box(es) → `Export/Collision/Loot/COL_CarePackage_Crate.fbx`; fallback CollisionFidelity **Box**
- Part `SM_CarePackage_Lid` rests at (0.00, 3.40, 2.00): Hinge along the back top edge. Rotate about the part's X axis to open.

### `SM_Parachute_Canopy`
- Pivot: Line convergence point (= crate ParachuteLink_Att). Canopy floats 12-16 studs above it.
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Parachute_Lines`
- Pivot: Line convergence point (= crate ParachuteLink_Att).
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_Beacon`
- Pivot: Centre on the ground.
- Footprint: 2.5 × 2.5 studs (X × Z)
- Attachments: `Light_Att` (0.00, 3.45, 0.00), `Smoke_Att` (0.00, 3.90, 0.00)
- Collision: 1 box(es) → `Export/Collision/Loot/COL_Beacon.fbx`; fallback CollisionFidelity **Box**

### `SM_LandingMarker`
- Pivot: Centre on the ground.
- Footprint: 10.0 × 10.0 studs (X × Z)
- Collision: CollisionFidelity **Box** (or CanCollide off for decor)

### `SM_SupplyCrate_Small01`
- Pivot: Bottom centre on the ground.
- Footprint: 1.8 × 1.8 studs (X × Z)
- Attachments: `Prompt_Att` (0.00, 1.50, -1.70), `Contents_Att` (0.00, 0.75, 0.00)
- Collision: 1 box(es) → `Export/Collision/Loot/COL_SupplyCrate_Small01.fbx`; fallback CollisionFidelity **Box**
- Part `SM_SupplyCrate_Small01_Lid` rests at (0.00, 1.50, 0.90): Hinge along the back top edge.

### `SM_SupplyCrate_Small02`
- Pivot: Bottom centre on the ground.
- Footprint: 3.2 × 1.4 studs (X × Z)
- Attachments: `Prompt_Att` (0.00, 1.10, -1.50), `Contents_Att` (0.00, 0.55, 0.00)
- Collision: 1 box(es) → `Export/Collision/Loot/COL_SupplyCrate_Small02.fbx`; fallback CollisionFidelity **Box**
- Part `SM_SupplyCrate_Small02_Lid` rests at (0.00, 1.10, 0.70): Hinge along the back top edge.

### `SM_SupplyCrate_Small03`
- Pivot: Bottom centre on the ground.
- Footprint: 2.2 × 1.6 studs (X × Z)
- Attachments: `Prompt_Att` (0.00, 1.30, -1.60), `Contents_Att` (0.00, 0.65, 0.00)
- Collision: 1 box(es) → `Export/Collision/Loot/COL_SupplyCrate_Small03.fbx`; fallback CollisionFidelity **Box**
- Part `SM_SupplyCrate_Small03_Lid` rests at (0.00, 1.30, 0.80): Hinge along the back top edge.

### `SM_Bandage_Held`
- Pivot: Grip point (RightGripAttachment). Roll in the hand, strip hanging forward.
- Collision: CollisionFidelity **Box**

### `SM_Ammo_Pistol`
- Pivot: Centre on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Ammo_Shotgun`
- Pivot: Centre on the ground.
- Collision: CollisionFidelity **Box**

### `SM_Ammo_Rifle`
- Pivot: Centre on the ground.
- Collision: CollisionFidelity **Box**

## Firearms

### `SM_Pistol`
- Pivot: Grip point (RightGripAttachment). Barrel along -Z (LookVector), up +Y. Default Tool.Grip = identity.
- Attachments: `Grip_Att` (0.00, 0.00, 0.00), `Muzzle_Att` (0.00, 0.47, -1.08), `ShellEject_Att` (0.20, 0.52, -0.10)
- Collision: CollisionFidelity **Box**
- Part `SM_Pistol_Slide` rests at (0.00, 0.47, 0.00): Slide at rest. Animate along +Z (backwards) ~0.3 studs per shot.

### `SM_Shotgun`
- Pivot: Grip point (RightGripAttachment). Barrel along -Z (LookVector), up +Y. Default Tool.Grip = identity.
- Attachments: `Grip_Att` (0.00, 0.00, 0.00), `Muzzle_Att` (0.00, 0.42, -3.60), `ShellEject_Att` (0.20, 0.45, -0.45), `SecondHand_Att` (0.00, 0.22, -1.50)
- Collision: CollisionFidelity **Box**
- Part `SM_Shotgun_Pump` rests at (0.00, 0.22, -1.90): Pump at rest. Slide along +Z 0.6 studs and back to cycle.

### `SM_Rifle`
- Pivot: Grip point (RightGripAttachment). Barrel along -Z (LookVector), up +Y. Default Tool.Grip = identity.
- Attachments: `Grip_Att` (0.00, 0.00, 0.00), `Muzzle_Att` (0.00, 0.52, -3.40), `ShellEject_Att` (0.20, 0.60, 0.05), `SecondHand_Att` (0.00, 0.20, -1.40)
- Collision: CollisionFidelity **Box**
- Part `SM_Rifle_Bolt` rests at (0.00, 0.52, 0.35): Bolt axis at rest. Rotate 60 deg about -Z (lift handle), then slide +Z 0.5 studs.

## Wildlife (rigged)

### `SK_Wolf`
- Pivot: Root bone at the origin: between the feet on the ground (Bat: body centre).
- Collision: 2 box(es) → `Export/Collision/Wildlife/COL_Wolf_Hitboxes.fbx`; fallback CollisionFidelity **Use the hitbox parts (CanCollide off on the skinned mesh).**

### `SK_Bear`
- Pivot: Root bone at the origin: between the feet on the ground (Bat: body centre).
- Collision: 2 box(es) → `Export/Collision/Wildlife/COL_Bear_Hitboxes.fbx`; fallback CollisionFidelity **Use the hitbox parts (CanCollide off on the skinned mesh).**

### `SK_Bat`
- Pivot: Root bone at the origin: between the feet on the ground (Bat: body centre).
- Collision: 1 box(es) → `Export/Collision/Wildlife/COL_Bat_Hitboxes.fbx`; fallback CollisionFidelity **Use the hitbox parts (CanCollide off on the skinned mesh).**

## Lobby kit

### `SM_Lobby_GatheringArea`
- Pivot: Centre on the ground (deck top at 0.6).
- Footprint: 30.0 × 30.0 studs (X × Z)
- Attachments: `Light1_Att` (-8.49, 6.50, 8.49), `Light2_Att` (8.49, 6.50, 8.49), `Light3_Att` (8.49, 6.50, -8.49), `Light4_Att` (-8.49, 6.50, -8.49), `FirePit_Att` (0.00, 0.70, 0.00), `Spawn_Att` (0.00, 0.60, -6.00)
- Collision: 1 box(es) → `Export/Collision/Lobby/COL_Lobby_GatheringArea.fbx`; fallback CollisionFidelity **Default**

### `SM_Lobby_ReadyStation`
- Pivot: Centre of the ready pad on the ground.
- Footprint: 9.0 × 5.0 studs (X × Z)
- Attachments: `Pad_Att` (0.00, 0.40, 0.00), `SignMount_Att` (0.00, 6.30, 0.00)
- Collision: 3 box(es) → `Export/Collision/Lobby/COL_Lobby_ReadyStation.fbx`; fallback CollisionFidelity **Box**

### `SM_Lobby_PartyArea`
- Pivot: Centre on the ground (platform top 0.5).
- Footprint: 14.0 × 14.0 studs (X × Z)
- Attachments: `Seat1_Att` (-2.97, 2.20, 2.97), `Seat2_Att` (2.97, 2.20, 2.97), `Seat3_Att` (2.97, 2.20, -2.97), `Seat4_Att` (-2.97, 2.20, -2.97), `TotemTop_Att` (0.00, 8.20, 0.00)
- Collision: 1 box(es) → `Export/Collision/Lobby/COL_Lobby_PartyArea.fbx`; fallback CollisionFidelity **Box**

### `SM_Lobby_PowerupStand`
- Pivot: Centre on the ground.
- Footprint: 3.0 × 3.0 studs (X × Z)
- Attachments: `Emblem_Att` (0.00, 4.40, -0.05), `Plaque_Att` (0.00, 0.62, -1.32)
- Collision: 1 box(es) → `Export/Collision/Lobby/COL_Lobby_PowerupStand.fbx`; fallback CollisionFidelity **Box**

### `SM_Lobby_ShopDisplay`
- Pivot: Bottom centre on the ground.
- Footprint: 10.0 × 6.0 studs (X × Z)
- Attachments: `Item1_Att` (3.00, 3.60, -2.30), `Item2_Att` (0.00, 3.60, -2.30), `Item3_Att` (-3.00, 3.60, -2.30), `SignMount_Att` (0.00, 5.20, -3.30)
- Collision: 2 box(es) → `Export/Collision/Lobby/COL_Lobby_ShopDisplay.fbx`; fallback CollisionFidelity **Box**

### `SM_Sign_Post`
- Pivot: Base of the post on the ground.
- Footprint: 4.0 × 1.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Lobby/COL_Sign_Post.fbx`; fallback CollisionFidelity **Box**
- Part `SM_Sign_Post_Panel` rests at (0.00, 3.60, -0.10): Panel centre. Front (-Z) face is the UI surface; use SurfaceGui Face=Front.

### `SM_Sign_Hanging`
- Pivot: Top hook point (hang from beams/arches).
- Footprint: 4.5 × 0.3 studs (X × Z)
- Collision: CollisionFidelity **Box**
- Part `SM_Sign_Hanging_Panel` rests at (0.00, -2.20, 0.00): Panel centre. Front (-Z) face is the UI surface; use SurfaceGui Face=Front.

### `SM_Sign_Board`
- Pivot: Bottom centre on the ground.
- Footprint: 11.0 × 2.0 studs (X × Z)
- Collision: 1 box(es) → `Export/Collision/Lobby/COL_Sign_Board.fbx`; fallback CollisionFidelity **Box**
- Part `SM_Sign_Board_Panel` rests at (0.00, 5.00, 0.00): Panel centre. Front (-Z) face is the UI surface; use SurfaceGui Face=Front.

### `SM_Sign_Plaque`
- Pivot: Plaque centre.
- Footprint: 1.8 × 0.3 studs (X × Z)
- Collision: CollisionFidelity **Box**
- Part `SM_Sign_Plaque_Panel` rests at (0.00, 0.00, 0.00): Panel centre. Front (-Z) face is the UI surface; use SurfaceGui Face=Front.

### `SM_Emblem_Trailblazer`
- Pivot: Medallion centre. Face points -Z. Sits at SM_Lobby_PowerupStand Emblem_Att.
- Footprint: 2.6 × 0.5 studs (X × Z)
- Collision: CollisionFidelity **Box**

### `SM_Emblem_Scavenger`
- Pivot: Medallion centre. Face points -Z. Sits at SM_Lobby_PowerupStand Emblem_Att.
- Footprint: 2.6 × 0.5 studs (X × Z)
- Collision: CollisionFidelity **Box**

### `SM_Emblem_Hunter`
- Pivot: Medallion centre. Face points -Z. Sits at SM_Lobby_PowerupStand Emblem_Att.
- Footprint: 2.6 × 0.5 studs (X × Z)
- Collision: CollisionFidelity **Box**

### `SM_Emblem_Climber`
- Pivot: Medallion centre. Face points -Z. Sits at SM_Lobby_PowerupStand Emblem_Att.
- Footprint: 2.6 × 0.5 studs (X × Z)
- Collision: CollisionFidelity **Box**

### `SM_Emblem_Craftsman`
- Pivot: Medallion centre. Face points -Z. Sits at SM_Lobby_PowerupStand Emblem_Att.
- Footprint: 2.6 × 0.5 studs (X × Z)
- Collision: CollisionFidelity **Box**

### `SM_Emblem_Sharpshooter`
- Pivot: Medallion centre. Face points -Z. Sits at SM_Lobby_PowerupStand Emblem_Att.
- Footprint: 2.6 × 0.6 studs (X × Z)
- Collision: CollisionFidelity **Box**

