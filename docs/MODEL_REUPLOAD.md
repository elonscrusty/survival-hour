# Model polish: re-upload list

Twenty models were reworked in `blender/assets/survival_wars.py` and re-exported. **Each one keeps the
exact outer size and pivot it was published with** (`tools/check_bounds.py` enforces this), so
`src/shared/AssetIds.luau` does not change and the game works with either the old or the new uploads.
The new detail only appears in game after the files below are uploaded as **new versions of the same
assets** (same IDs).

| What changed | Models |
|---|---|
| Chests | Plank bodies on feet, iron corner brackets, riveted hoop bands, lock hasp (rare tiers keep the glowing lock) |
| Storage | Locker: slate paint, double doors, louvres, hinges, handles. Safe: feet, door plate, hinges, dial and locking wheel |
| Walls | Scrap wall: weathered sheets with ribs and bolts, one faded red panel, second rail. Metal wall: rivets, seams, top beam |
| Workbench IV / V | Lower shelf with stock, vise, anvil, bellows, forge rim and coals, chimney cap, a pegged tool board. Tier V tools now hang on the board (they used to float) |
| POIs | Pickup truck (olive, open bed, glass, grille, rims, flat tyre, weeds), industrial yard (corrugated containers with doors, tank ladder, barrels, pallets, crates), bunker (moss patches instead of a green lid, door frame, lamp, vent, two sandbag courses), hunting blind (slatted screens with brush), cabin (stacked-stone chimney), mine entrance and large mine (sleepers under the rails, a real ore cart, name board, braces, lantern) |
| Held tools | Sledgehammer (forged head with striking faces and collar), crowbar (grip wrap, bare-steel claw), crossbow (butt plate, trigger guard, loaded bolt) |

## Files and the asset IDs to update

| File | Existing asset ID |
|---|---|
| `Export/Meshes/SW_Loot/SM_Chest_Common.fbx` | 79319112537729 |
| `Export/Meshes/SW_Loot/SM_Chest_Uncommon.fbx` | 74095620111628 |
| `Export/Meshes/SW_Loot/SM_Chest_Rare.fbx` | 72627129372313 |
| `Export/Meshes/SW_Loot/SM_Chest_VeryRare.fbx` | 94925186220032 |
| `Export/Meshes/SW_Base/SM_MetalLocker.fbx` | 99990612911999 |
| `Export/Meshes/SW_Base/SM_SurvivalSafe.fbx` | 76460121618816 |
| `Export/Meshes/SW_Base/SM_ScrapWall.fbx` | 86100239983828 |
| `Export/Meshes/SW_Base/SM_MetalWall.fbx` | 90222266864696 |
| `Export/Meshes/SW_Base/SM_Workbench_Level04.fbx` | 97752974757537 |
| `Export/Meshes/SW_Base/SM_Workbench_Level05.fbx` | 113154978546972 |
| `Export/Meshes/SW_POI/SM_POI_BrokenVehicle.fbx` | 89009731297133 |
| `Export/Meshes/SW_POI/SM_POI_Bunker.fbx` | 118663500247472 |
| `Export/Meshes/SW_POI/SM_POI_Cabin.fbx` | 83134859646780 |
| `Export/Meshes/SW_POI/SM_POI_HuntingBlind.fbx` | 133237980894908 |
| `Export/Meshes/SW_POI/SM_POI_IndustrialSite.fbx` | 106033038494664 |
| `Export/Meshes/SW_POI/SM_POI_MineEntrance.fbx` | 91304803137274 |
| `Export/Meshes/SW_POI/SM_POI_LargeMine.fbx` | 101627947420601 |
| `Export/Meshes/SW_Tools/SM_Crossbow.fbx` | 115589043201209 |
| `Export/Meshes/SW_Tools/SM_Crowbar.fbx` | 97004017024629 |
| `Export/Meshes/SW_Tools/SM_Sledgehammer.fbx` | 113856450054811 |

## Prompt for ChatGPT (paste as is)

> I re-exported 20 FBX models for my Roblox game Survival Hour. Each one is already uploaded; I need a
> **new version of the existing asset**, not a new asset, so the IDs stay the same.
> Use the Open Cloud Assets API update call (`PATCH https://apis.roblox.com/assets/v1/assets/{assetId}`,
> multipart with `request` JSON `{"assetId": <id>}` and `fileContent` = the FBX, content type
> `model/fbx`), with the same API key and creator (user kcdrewcarter) as before. Poll the returned
> operation until it is done. Files and IDs are in `docs/MODEL_REUPLOAD.md` in the repo (table
> "Files and the asset IDs to update"). Do not create any new assets and do not change any other
> model. When finished, give me a list of asset ID → new version number, and flag any that failed.
> After that, delete the API key.

If the update call is refused for any asset, upload that file as a new asset instead, and send the new
ID. Only in that case does `Roblox/uploaded_model_ids.json` need the new ID and
`python3 tools/gen_asset_ids.py` needs to run again.

## New model: camp shack (upload as a NEW asset)

| File | Asset ID |
|---|---|
| `Export/Meshes/Camp/SM_Camp_Hut.fbx` | new: send Claude the ID after uploading |

The log cabin behind each camp. Until it's uploaded the game keeps the old block shack.


## New models: animals (upload as NEW assets)

28 part meshes that give the wolf, bear, deer, rabbit, boar and bat a proper look
(`blender/assets/animals.py`, preview: `Renders/ContactSheet_Animals.png`). Each mesh sits on one part
of the in-game rig, so the existing walk / look-around / attack animation moves it. Upload each file as a
**new** model asset (same Open Cloud call and creator as the first upload), then send Claude the IDs:
they go into `Roblox/uploaded_model_ids.json` (keys `Animals/<name>`) and
`python3 tools/gen_asset_ids.py` regenerates `src/shared/AssetIds.luau`.

A species switches to meshes only when **all** of its files are uploaded (the deer needs both heads:
does and antlered bucks); until then it keeps the old block look.

| File | Asset ID |
|---|---|
| `Export/Meshes/Animals/SM_Wolf_Body.fbx` | new |
| `Export/Meshes/Animals/SM_Wolf_Head.fbx` | new |
| `Export/Meshes/Animals/SM_Wolf_LegF.fbx` | new |
| `Export/Meshes/Animals/SM_Wolf_LegB.fbx` | new |
| `Export/Meshes/Animals/SM_Wolf_Tail.fbx` | new |
| `Export/Meshes/Animals/SM_Bear_Body.fbx` | new |
| `Export/Meshes/Animals/SM_Bear_Head.fbx` | new |
| `Export/Meshes/Animals/SM_Bear_LegF.fbx` | new |
| `Export/Meshes/Animals/SM_Bear_LegB.fbx` | new |
| `Export/Meshes/Animals/SM_Bear_Tail.fbx` | new |
| `Export/Meshes/Animals/SM_Deer_Body.fbx` | new |
| `Export/Meshes/Animals/SM_Deer_Head.fbx` | new |
| `Export/Meshes/Animals/SM_Deer_Head_Antlered.fbx` | new |
| `Export/Meshes/Animals/SM_Deer_LegF.fbx` | new |
| `Export/Meshes/Animals/SM_Deer_LegB.fbx` | new |
| `Export/Meshes/Animals/SM_Deer_Tail.fbx` | new |
| `Export/Meshes/Animals/SM_Rabbit_Body.fbx` | new |
| `Export/Meshes/Animals/SM_Rabbit_Head.fbx` | new |
| `Export/Meshes/Animals/SM_Rabbit_LegF.fbx` | new |
| `Export/Meshes/Animals/SM_Rabbit_LegB.fbx` | new |
| `Export/Meshes/Animals/SM_Rabbit_Tail.fbx` | new |
| `Export/Meshes/Animals/SM_Boar_Body.fbx` | new |
| `Export/Meshes/Animals/SM_Boar_Head.fbx` | new |
| `Export/Meshes/Animals/SM_Boar_LegF.fbx` | new |
| `Export/Meshes/Animals/SM_Boar_LegB.fbx` | new |
| `Export/Meshes/Animals/SM_Boar_Tail.fbx` | new |
| `Export/Meshes/Animals/SM_Bat_Body.fbx` | new |
| `Export/Meshes/Animals/SM_Bat_Wing.fbx` | new |
