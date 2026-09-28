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

## Trees: simpler "99 Nights" look (re-upload, SAME asset IDs)

Every tree and the three harvest stumps were redone in a clean, chunky low-poly style: straight
tapered trunks, pines/spruces as 3-5 stacked rounded cones in flat greens (lighter tips, darker
undersides), oaks as 3-4 big soft lumps on a thick trunk, birch/aspen as a white trunk with dark marks
under a tall rounded crown, the dead tree as a bare trunk with four thick forked branches, and stumps
with a clean cut top, root nubs and chips. Colours are flat picks from the existing texture atlas, so
the atlas does not change. Each model keeps its **exact published size and pivot**
(`tools/check_bounds.py` passes), so `src/shared/AssetIds.luau` does not change. Preview:
`Renders/Preview_TreeBeforeAfter.png`, `Renders/Preview_TreeMix.png`.

| File | Existing asset ID |
|---|---|
| `Export/Meshes/Forest/SM_Tree_Pine_Small01.fbx` | 111873807466339 |
| `Export/Meshes/Forest/SM_Tree_Pine_Medium01.fbx` | 77229859134923 |
| `Export/Meshes/Forest/SM_Tree_Pine_Medium02.fbx` | 119682051803520 |
| `Export/Meshes/Forest/SM_Tree_Pine_Large01.fbx` | 87910798610678 |
| `Export/Meshes/Forest/SM_Tree_Oak_Small01.fbx` | 82141594475205 |
| `Export/Meshes/Forest/SM_Tree_Oak_Medium01.fbx` | 77801315546713 |
| `Export/Meshes/Forest/SM_Tree_Oak_Medium02.fbx` | 125738669214390 |
| `Export/Meshes/Forest/SM_Tree_Oak_Large01.fbx` | 101790810639448 |
| `Export/Meshes/Forest/SM_Tree_Birch_Small01.fbx` | 139651902303022 |
| `Export/Meshes/Forest/SM_Tree_Birch_Medium01.fbx` | 91019597566936 |
| `Export/Meshes/Forest/SM_Tree_Dead_Large01.fbx` | 104187717812981 |
| `Export/Meshes/Forest/SM_Tree_Pine_Small01_Stump.fbx` | 136745938202045 |
| `Export/Meshes/Forest/SM_Tree_Oak_Small01_Stump.fbx` | 99865726662230 |
| `Export/Meshes/Forest/SM_Tree_Birch_Small01_Stump.fbx` | 84165405557090 |
| `Export/Meshes/SW_Landscape/SM_Tree_Spruce01.fbx` | 100042706682519 |
| `Export/Meshes/SW_Landscape/SM_Tree_Spruce02.fbx` | 93555666107911 |
| `Export/Meshes/SW_Landscape/SM_Tree_Aspen01.fbx` | 140600945899866 |

Upload these 17 the same way as the table above (Open Cloud `PATCH .../assets/v1/assets/{assetId}`,
new version of the existing asset, no new assets). The ChatGPT prompt above works as is: tell it to
use this table instead.
