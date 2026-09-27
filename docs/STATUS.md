# Project Status

_Last updated: 2026-09-26_

## Where things stand

The whole game is implemented as source (Rojo project) and builds into `build/SurvivalHour.rbxlx`. Pure game logic is unit-tested (89 tests). All code passes syntax, reference and Roblox-API type checks. **No Roblox Studio or live-server playtest has happened yet.** Expect some tuning and runtime fixes during the first Studio session; see [TESTING.md](TESTING.md) §2.

| Stage (from the brief) | Status |
|---|---|
| 1. Core match loop: 4 teams, day/night, campfires, lives, win detection | Implemented; rules unit-tested; not yet run in Studio |
| 2. Gathering, inventory, crafting, workbenches, construction, storage | Implemented; inventory/storage/placement/recipes unit-tested |
| 3. Combat, wildlife, healing, loot, campfire raids | Implemented; loot odds unit-tested |
| 4. Lobby, parties, matchmaking, persistence, powerups, purchases | Implemented; team packing, receipts, challenges and profile rules unit-tested; MemoryStore/Teleport paths need a live test |
| 5. Art, animation, audio, UI, optimisation | Procedural models + procedural animation + complete UI; audio uses engine-bundled sounds with slots for licensed assets |

## Honest list of fallbacks and gaps

- **Models** are built at runtime from Roblox primitives (`src/shared/Models`) and, when the mesh library is present, dressed with the uploaded 3D asset pack (`SurvivalHourAssets.rbxm`, see [MESH_SKINS.md](MESH_SKINS.md)). Wildlife, worn armour and a few landmarks are still procedural.
- **Animations** are procedural joint offsets (`Controllers/Animation.luau`, `Controllers/Creatures.luau`), not authored KeyframeSequences. The joint axis conventions (R15 vs R6) were written from API knowledge and **need a visual check in Studio**. Swap signs in `raise()` if an arm moves the wrong way.
- **Audio**: only Roblox's engine-bundled sounds are used (`rbxasset://sounds/...`: jump, landing, swim, splash, explosion, ouch/oof, slider). Crackle, ambience and plane-drone cues are silent until you add licensed asset IDs in `Sounds.luau`.
- **Icons** are drawn with UI primitives (shaped badge + glyph). There are no image assets.
- **Climber's passive climb bonus** is applied client-side while the humanoid is climbing (`Camera.luau`), because characters are client-simulated. It needs a feel check on the watchtower ladder.
- **Queue priority** after a failed or empty match isn't implemented (teleport data can be forged, so it isn't trusted); players simply ready up again.
- **Matchmaking status** in live lobbies counts queued players from the first 100 queue entries.
- The pure logic has thorough tests; the Roblox-side services only have static checks.

## How to resume work

1. Read [GDD.md](GDD.md), [DECISIONS.md](DECISIONS.md) and this file.
2. Tools: Rojo 7.7 (`rojo build` / `rojo serve`), the Luau CLI for `tests/run.luau`, and `python tools/check.py --luau <luau dir>` for static checks. `luau-lsp analyze` with the Roblox definitions gives API-aware type checks.
3. Open the place in Studio and work through TESTING.md §2. Fix what breaks, then tune numbers in `Config.luau` / the data modules and regenerate the tuning tables with `luau tools/gen_tuning.luau`.

## File map

```
default.project.json        Rojo project (one place: lobby + match)
src/shared/                 ReplicatedStorage.Shared
  Config, Items, Recipes, Powerups, Loot, Products, Sounds, Net
  Logic/                    pure, unit-tested rules (team packing, lives, inventory, storage,
                            placement, layout generator, profile/receipts, challenges, RNG, rate limits)
  Models/                   procedural models (nature, camp, structures, items, loot, animals)
src/server/                 ServerScriptService.Server
  Main.server.luau          boot + mode selection
  Services/                 Data, Purchase, World, Lobby, Matchmaking, Match, Camp, Lives,
                            Inventory, Channel, Combat, Gather, Craft, Build, Storage,
                            Wildlife, Loot, Powerup, Dev, Util
src/client/                 StarterPlayerScripts.Client
  Main.client.luau, State, UI/ (Theme, UI helpers)
  Controllers/              Input, Camera, Hud, Panels, Inventory, Craft, Build, Storage, Shop,
                            Lobby, Map, Combat, Animation, Creatures, Effects, Prompts,
                            Spectate, Notifications, Sound, Dev
src/character/Health        disables default health regen
tests/                      Luau CLI unit tests (run.luau + *.spec.luau)
tools/check.py              static checks; tools/gen_tuning.luau generates the tuning tables
docs/                       GDD, DECISIONS, TUNING, SETUP, TESTING, STATUS
build/SurvivalHour.rbxlx    built place
```
