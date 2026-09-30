# Model polish: re-upload list

## New lobby plaza models (upload as NEW assets, then send Claude the IDs)

| File | What |
|---|---|
| `Export/Meshes/Lobby/SM_Lobby_Lodge.fbx` | Log lodge: Camp Store + Classes |
| `Export/Meshes/Lobby/SM_Lobby_Leaderboard.fbx` | Roofed leaderboard (used 3 times) |
| `Export/Meshes/Lobby/SM_Lobby_QuestBoard.fbx` | Daily Challenges board |
| `Export/Meshes/Lobby/SM_Lobby_BigLog.fbx` | Big log seat |
| `Export/Meshes/Lobby/SM_Lobby_Fence.fbx` | Fence segment |
| `Export/Meshes/Lobby/SM_Lobby_FenceLantern.fbx` | Fence lantern post |

Twenty-three models were reworked in `blender/assets/survival_wars.py` and `blender/assets/camp.py` and re-exported. **Each one keeps the
exact outer size and pivot it was published with** (`tools/check_bounds.py` enforces this), so
`src/shared/AssetIds.luau` does not change and the game works with either the old or the new uploads.
The new detail only appears in game after the files below are uploaded as **new versions of the same
assets** (same IDs).

| What changed | Models |
|---|---|
| Chests | Plank bodies on feet, iron corner brackets, riveted hoop bands, lock hasp (rare tiers keep the glowing lock) |
| Storage | Locker: slate paint, double doors, louvres, hinges, handles. Safe: feet, door plate, hinges, dial and locking wheel |
| Walls | Scrap wall: weathered sheets with ribs and bolts, one faded red panel, second rail. Metal wall: rivets, seams, top beam |
| Workbenches I-V (reworked again as a set, so each tier reads as an upgrade) | I: split-log top on rooted stumps, pegs and rope lashing, knapping stone, stone hammer, stone axe stuck in the top, hide, team cloth throw, firewood. II: nailed plank top, leg vise, braced legs, stocked shelf, hand plane and shavings, team-painted tool board with saw, hammers, chisels, square and rope. III: iron-banded beam top with rivets, anvil on a banded stump, quench bucket, tongs, crank grindstone, tool rack with shelves of ingots and a team banner with an anvil emblem. IV: iron-strapped plank bench, engineer's vise, anvil, grindstone, team tool board with an iron guild plaque, stone forge with glowing coals, ash-pit glow, bellows, quench trough, hood on iron posts and chimney. V: IV upgraded to a riveted steel top with brass corners, brass-pulled drawers, steel tools and vise, brass plaque, iron-banded forge with crucible, lantern, metal hood, team pennant and chimney rain cap |
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
| `Export/Meshes/Camp/SM_Workbench_Level01.fbx` | 124461291296913 |
| `Export/Meshes/Camp/SM_Workbench_Level02.fbx` | 73246854612819 |
| `Export/Meshes/Camp/SM_Workbench_Level03.fbx` | 89873222733176 |
| `Export/Meshes/SW_Base/SM_Workbench_Level04.fbx` (changed again) | 97752974757537 |
| `Export/Meshes/SW_Base/SM_Workbench_Level05.fbx` (changed again) | 113154978546972 |
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

> I re-exported 23 FBX models for my Roblox game Survival Hour. Each one is already uploaded; I need a
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


## New models: animals (upload as NEW assets)

Done: these IDs are in `src/shared/AssetIds.luau`. For the owner-model look, see the last section.

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

## Animals: owner models (upload as NEW VERSIONS, same IDs)

The 28 animal part meshes now use the owner's six blocky animal models
(`blender/source_models/animals/*_Basic.blend`, split by `blender/assets/animals.py`): grey wolf
with a cream chest and dark paws, brown bear with a tan muzzle, warm brown deer with cream patches
and antlers, pale rabbit, russet boar with a dark mane and ivory tusks, charcoal bat with lighter
wings and amber eyes. Each part is fitted to its **exact published size and pivot**
(`tools/check_bounds.py` passes), so `src/shared/AssetIds.luau` does not change and the rigs and
animations stay as they are. Colours are flat picks from the existing atlas (it has no pink, so the
rabbit's inner ears are warm brown). Preview: `Renders/ContactSheet_Animals.png`,
`Renders/Animals/*.png`.

| File | Existing asset ID |
|---|---|
| `Export/Meshes/Animals/SM_Wolf_Body.fbx` | 72634194885985 |
| `Export/Meshes/Animals/SM_Wolf_Head.fbx` | 74141736270655 |
| `Export/Meshes/Animals/SM_Wolf_LegF.fbx` | 107102943356409 |
| `Export/Meshes/Animals/SM_Wolf_LegB.fbx` | 121528125856892 |
| `Export/Meshes/Animals/SM_Wolf_Tail.fbx` | 120725435653489 |
| `Export/Meshes/Animals/SM_Bear_Body.fbx` | 137138480859421 |
| `Export/Meshes/Animals/SM_Bear_Head.fbx` | 139353492259250 |
| `Export/Meshes/Animals/SM_Bear_LegF.fbx` | 117419541941087 |
| `Export/Meshes/Animals/SM_Bear_LegB.fbx` | 129474877972020 |
| `Export/Meshes/Animals/SM_Bear_Tail.fbx` | 118815588769713 |
| `Export/Meshes/Animals/SM_Deer_Body.fbx` | 130632780638215 |
| `Export/Meshes/Animals/SM_Deer_Head.fbx` | 133188122555894 |
| `Export/Meshes/Animals/SM_Deer_Head_Antlered.fbx` | 127805609599256 |
| `Export/Meshes/Animals/SM_Deer_LegF.fbx` | 131027930304623 |
| `Export/Meshes/Animals/SM_Deer_LegB.fbx` | 109544530847498 |
| `Export/Meshes/Animals/SM_Deer_Tail.fbx` | 89653479463814 |
| `Export/Meshes/Animals/SM_Rabbit_Body.fbx` | 96976254095719 |
| `Export/Meshes/Animals/SM_Rabbit_Head.fbx` | 115840535372266 |
| `Export/Meshes/Animals/SM_Rabbit_LegF.fbx` | 119677472378572 |
| `Export/Meshes/Animals/SM_Rabbit_LegB.fbx` | 82742530078883 |
| `Export/Meshes/Animals/SM_Rabbit_Tail.fbx` | 126615622631395 |
| `Export/Meshes/Animals/SM_Boar_Body.fbx` | 130297488397550 |
| `Export/Meshes/Animals/SM_Boar_Head.fbx` | 101874426230199 |
| `Export/Meshes/Animals/SM_Boar_LegF.fbx` | 135834037251825 |
| `Export/Meshes/Animals/SM_Boar_LegB.fbx` | 133496966430325 |
| `Export/Meshes/Animals/SM_Boar_Tail.fbx` | 76673408440422 |
| `Export/Meshes/Animals/SM_Bat_Body.fbx` | 97702486845443 |
| `Export/Meshes/Animals/SM_Bat_Wing.fbx` | 112807529368495 |

Upload these 28 as **new versions of the existing assets** (Open Cloud
`PATCH .../assets/v1/assets/{assetId}`), no new assets. The ChatGPT prompt above works as is: tell
it to use this table instead.
