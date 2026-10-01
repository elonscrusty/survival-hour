# Uploaded assets

Uploaded on 2026-10-01 with `tools/upload_assets.py` (Roblox Open Cloud) to the owner's account
(user kcdrewcarter, id 20194281). All are original files from this repo. IDs are also in
`assets/uploaded_ids.json` (source of truth) and, for models, `src/shared/MeshIds.luau`.

## In use
- **Sounds**: wired into `src/client/Controllers/Sound.luau` (click, buy, coin, collect, deposit, error, rebirth, claim, spawn, music loop). New audio can sit in Roblox moderation for a while; until it is approved it just stays silent.

## Not in use yet (check first)
- **Models**: the world still uses the native-part models. The FBX files have one colour per material and no baked vertex colours, and it was not possible to check here how Roblox imported them; they may appear untextured/grey. To check: Studio → Toolbox → My Models (or Creator Hub → Development Items → Models) → insert e.g. "EggFarm RedBarn" and look at it. If they look right, ask Claude to wire them in (a loader that swaps the native models for these meshes, with the native ones kept as fallback). If colours are missing, Claude can re-export with baked vertex colours and upload new versions.

## Sounds

| Cue | Asset ID |
|---|---|
| buy | 103660128190074 |
| claim | 132065374514937 |
| click | 136798835886474 |
| coin | 100010426391431 |
| collect | 100239935293288 |
| deposit | 100640206640863 |
| error | 78092452569613 |
| music_loop | 126863563287348 |
| rebirth | 79787407230468 |
| spawn | 126269574955280 |

## Models

| Model | Asset ID |
|---|---|
| BigBarn | 74142689261072 |
| BoxTruck | 74075539204012 |
| Bush | 71212044639301 |
| Chicken | 89471845245471 |
| ChickenBrown | 110991131752790 |
| DeliveryVan | 111612678581803 |
| Egg | 102736328607158 |
| EggCrate | 98340986763807 |
| EggFactory | 136212781192172 |
| EggHauler | 125441674419878 |
| Egg_cactus | 82385284617507 |
| Egg_clover | 134352149503274 |
| Egg_crystal | 78263702825440 |
| Egg_farm | 137540513475853 |
| Egg_frost | 105814931500872 |
| Egg_honey | 130462521030329 |
| Egg_magma | 127140014212649 |
| Egg_nebula | 131702550598895 |
| Egg_seashell | 101090588276696 |
| Egg_sunburst | 103541917627177 |
| FarmPickup | 124955977925945 |
| Farmhand | 118013896885529 |
| Fence | 129615120969347 |
| Fox | 94449518854050 |
| HenHouse | 87373276703999 |
| HenTower | 97048503860334 |
| LittleCoop | 71610074113187 |
| MegaDome | 102206923499946 |
| PoultryHall | 71415938335487 |
| RedBarn | 111310604022578 |
| RoboPicker | 112514153421701 |
| Rock | 71369001219506 |
| Signboard | 85644818190100 |
| Silo | 91630184468055 |
| SkyRoost | 78003371981465 |
| Tree | 112127479037255 |
| TwinCoop | 81008097930041 |
| Warehouse | 109525572703812 |
