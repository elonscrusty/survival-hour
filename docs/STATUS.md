# Project Status

_Last updated: 2026-09-27_

## Where things stand

Survival Wars continuation, **all seven phases implemented** (see [IMPLEMENTATION_LOG.md](IMPLEMENTATION_LOG.md) and
[SPEC_AUDIT.md](SPEC_AUDIT.md)). The game is source (a Rojo project) and builds into `build/SurvivalHour.rbxlx`.

Checks:
- Pure logic has **131 unit tests** (`tests/run.luau`).
- Model builders and the lobby refuge are checked against a mocked Roblox API plus a fake mesh library
  (**34 checks**, `tests/skins/bundle.py`).
- Every service passes the Roblox-API type check with no new diagnostics.

**No Roblox Studio or live-server playtest has happened yet.** Every tunable number (economy, yields, damage,
XP and Coins) is a working target. Playtest before treating any of them as final.

| Phase | Status |
|---|---|
| 1. Core match rules: solo, fire fuel/levels, respawns, snuffing from Night 3, sunrise protection, non-pay-to-win | Implemented, rules tested |
| 2. Workbench I–V, crude tools, exact yields, tool tiers, stamina, healing | Implemented, tested |
| 3. Slot inventory / backpacks, storage tiers and breaching, traps, building tiers | Implemented, tested |
| 4. Wildlife roles and night escalation, melee light/heavy/block, bows/crossbow/headshots, armour | Implemented, tested |
| 5. POIs by rarity, caves, chests, ore/scrap, layered forest, Blender world kit (57 assets) | Implemented, tested (mock) |
| 6. XP/levels, Coins/cosmetics, Diamonds, classes, power-ups, Coin packs, leaderboards | Implemented, tested |
| 7. Forest-refuge lobby, title screen, dawn/sunset/moonlit lighting, audio hooks, docs | Implemented, lobby tested (mock) |

## Honest list of fallbacks and gaps

- **Meshes need a Studio import.** New meshes appear only after the FBX files are imported and
  `SurvivalHourAssets.rbxm` is re-saved ([Docs/IMPORT.md](../Docs/IMPORT.md)). Until then everything shows its
  procedural look.
- **Animations** are procedural joint offsets, including emotes and victory poses. They need a visual check in Studio.
- **Audio:** engine-bundled cues only. Ambience (lobby, day, night, cave), crackle and surface footsteps are silent
  slots waiting for licensed asset IDs.
- **Icons** are UI primitives and glyphs. There are no image assets.
- **Leaderboards** only fill on live servers (or in Studio with `SaveInStudio`).
- **Robux products** are all `ProductId = 0` until they're created in Creator Hub. Studio simulates purchases.
- The Roblox-side services have static checks only; live MemoryStore/Teleport paths need a real test.

## How to resume work

1. Read [GDD.md](GDD.md), [DECISIONS.md](DECISIONS.md) and this file.
2. Tools: Rojo 7.7 (`rojo build` / `rojo serve`), the Luau CLI for `tests/run.luau`, `python tests/skins/bundle.py` for the model/lobby mock checks, and `luau-lsp analyze` with the Roblox definitions gives API-aware type checks.
3. Open the place in Studio and work through TESTING.md §2. Fix what breaks, then tune numbers in `Config.luau` / the data modules and regenerate the meta tuning tables with `luau tools/gen_meta_tuning.luau`.

## File map

```
default.project.json        Rojo project (one place: lobby + match)
src/shared/                 ReplicatedStorage.Shared
  Config, Items, Recipes, Resources, Loot, Products, Sounds, Net,
  Classes, Perks, Cosmetics, Progression
  Logic/                    pure, unit-tested rules (team packing, lives, inventory, storage,
                            placement, layout generator, profile/receipts, fire, wildlife, combat, RNG, rate limits)
  Models/                   procedural models + mesh skins (nature, flora, decor, camp, structures,
                            items, loot, animals, landmarks/POIs, lobby refuge)
src/server/                 ServerScriptService.Server
  Main.server.luau          boot + mode selection
  Services/                 Data, Purchase, World, Lobby, Matchmaking, Match, Camp, Lives,
                            Inventory, Channel, Combat, Gather, Craft, Build, Storage,
                            Stamina, Wildlife, Loot, Cosmetic, Powerup (classes/perks/rewards), Dev, Util
src/client/                 StarterPlayerScripts.Client
  Main.client.luau, State, UI/ (Theme, UI helpers)
  Controllers/              Input, Camera, Hud, Panels, Inventory, Craft, Build, Storage, Shop,
                            Lobby, Map, Combat, Animation, Creatures, Effects, Prompts,
                            Spectate, Notifications, Sound, Dev
src/character/Health        disables default health regen
tests/                      Luau CLI unit tests (run.luau + *.spec.luau)
tools/gen_meta_tuning.luau  generates the class/power-up/progression/cosmetic/product tables
docs/                       GDD, DECISIONS, TUNING, SETUP, TESTING, STATUS
build/SurvivalHour.rbxlx    built place
```
