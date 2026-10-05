# Pet Race League

A Roblox game: hatch pets, ride them, train their Speed, Jump and Stamina, then race other players on obstacle tracks for coins, trophies and medals.

Built with Rojo and Luau. There are 33 3D models (15 pets, 3 eggs, 15 lobby and track props) made in Blender; see `models/renders/_sheet.png`. Until they're uploaded, the game draws everything with parts, so it's fully playable right away.

## Play it in Studio
1. Download `build/PetRaceLeague.rbxlx` and open it in Roblox Studio.
2. To test saving: Game Settings → Security → turn on **Enable Studio Access to API Services**. Without it the game still runs, but progress isn't saved.
3. Press **Play**. To test a race with several racers, use Test → Clients and Servers with 2-3 players.
4. Game Settings → Avatar: set **Avatar type to R15**. The riding maths assumes R15.

## How the game plays
| Area | What you do |
|---|---|
| Spawn | You start with a Pup and you're already riding it. |
| Eggs (north) | Meadow (100), Forest (450) and Sky (1500) eggs. Every 10th hatch of the same egg is Rare or better. |
| Speed Ring (east) | Ride through the 8 gates in order for Speed XP, plus a bonus for each full lap. |
| Jump Hurdles (west) | Jump the 2 to 8 stud walls for Jump XP. Taller walls give more XP. |
| Stamina Treadmill (south-west) | Keep running on the belt for Stamina XP. More Stamina gives more dashes that recharge faster. |
| Race Portal (south) | Stand on the pink pad and a race starts in 20 seconds. Solo races are allowed: you race the medal times. |

The 3 tracks rotate (Meadow Dash, Canyon Leap, Sky Steps). They have gaps, hurdles, ramps, steps, pillars, mud and boost pads. If you fall, you go back to your last checkpoint.

**Controls:** DASH button (or Shift / Q), RIDE/WALK button (or R), PETS menu, SHOP menu.

## Fairness and money
- Robux buys Coins, cosmetics (Rainbow Trail, Galaxy Paint) and the Big Barn pass (+36 pet slots). It never buys race speed directly.
- Rarity gives at most +10% stats. A fully trained Common beats an untrained Mythic easily (this is unit tested).
- Trophies only go up. Solo races give at most 3 trophies, so the leaderboard is earned by racing people.

## 3D models
- `blender/build.py` builds every model: `python3 blender/build.py` (needs `pip install bpy==5.0.1`). It writes `models/fbx/*.fbx`, previews in `models/renders/` and `models/catalog.json`.
- Pets are built from the same numbers as `src/shared/Pets.luau`, so the riding height matches the mesh.
- **Uploading:** make an Open Cloud API key with Assets read+write, then run `ROBLOX_API_KEY=... ROBLOX_USER_ID=... python3 tools/upload_models.py`. It uploads every FBX and fills in the ids in `src/shared/Models.luau`. Rebuild the place after that. Or give Claude the key in a session as an environment secret and it can run this for you.
- Publish the game from the same account that uploaded the models (Roblox only lets a game load its owner's models).
- `src/server/Services/AssetLoader.luau` loads them at server start. Anything missing falls back to parts.

## Owner to-do before publishing
- Create the products and game pass on the Creator Dashboard, then put the ids in `src/shared/Products.luau`. The Robux tab stays hidden until you do.
- Upload the 3D models (see above).
- Optional: add sounds and music (none are included yet).

## For developers
- `bash tools/check.sh` runs the type check, unit tests (`tests/*.spec.luau`) and the Rojo build. After rebuilding models, run `python3 tools/gen_models.py`.
- Tuning numbers: `src/shared/Config.luau`. Pets: `Pets.luau`. Eggs: `Eggs.luau`. Tracks: `Tracks.luau`. Cosmetics: `Cosmetics.luau`.
- Pure rules, unit tested: `src/shared/Logic/` (Hatch, PetStats, Profile, RaceRules, TrackLayout).
- Server services in `src/server/Services/`, started in the order listed in `Main.server.luau`.
- Client controllers in `src/client/Controllers/`. The UI is built in code (`src/client/UI.luau`).
