# Egg Farm

An original Roblox egg-farming tycoon. Walk around your farm in third person, spawn chickens,
collect eggs from their houses, carry them to the warehouse, and let your vehicles sell them.
Cash buys bigger houses, faster vehicles, workers, silos and upgrades. Reach the Farm Value goal to
REBIRTH onto the next egg's farm, all the way to PRESTIGE.

"Egg Farm" is a working name. See [Renaming](#renaming).

The functional structure follows the Roblox game Egg Empire. Every model, icon, sound, name and number is
original (see `docs/DESIGN.md` and `docs/REFERENCE_COVERAGE.md`).

## What's in the box
| Path | What |
|---|---|
| `build/EggFarm.rbxlx` | The game place (production adapters) |
| `build/EggFarm.Test.rbxlx` | The test place: memory saves, simulated checkout, DEV panel (F8) |
| `src/` | All Luau source (`shared`, `server`, `client`) |
| `test/` | Test-place-only scripts and fixtures |
| `tests/` | Unit tests for the Luau CLI (`tests/run.luau`) |
| `tools/` | `check.sh` (all offline checks), `setup_env.sh`, `sim.luau` (balance bot), `headless/` (offline mock harness) |
| `blender/`, `assets/` | Blender generator scripts, `.blend` sources, FBX/OBJ exports, icon PNGs, audio WAVs (`assets/MANIFEST.md`) |
| `vendor/ProfileStore/` | Saving library (Apache-2.0, pinned) |
| `docs/` | Design, architecture, reference research and coverage, test results, previews |

## Prerequisites
- Roblox Studio (to open and play the place).
- Optional, to rebuild from source: [Rojo 7.7.0](https://rojo.space). Linux checks also use the
  Luau CLI and luau-lsp 1.53.0 (`bash tools/setup_env.sh` downloads them).
- Optional, for models: Python 3.11 with `bpy` 5.0.1 (`EF_WITH_BPY=1 bash tools/setup_env.sh`).

## Open and play
1. Open `build/EggFarm.Test.rbxlx` in Studio (File → Open from File). Use the test place for
   playtesting: it never touches real DataStores and purchases are simulated.
2. Press Play. You spawn on your own plot and the tutorial starts: tap SPAWN, walk into the
   glowing ring at your coop, then into the warehouse ring, and watch your pickup sell the eggs.
3. In the test place, press F8 (or the DEV button) for shortcuts: cash, gold, jump to an egg,
   max the farm, fast-forward, simulate offline time, next UTC day, checkout success/cancel/fail,
   fail the next load/save, reset, kick to test rejoin.
4. For two-player tests: Studio → Test → Clients and Servers → 2 players.

Controls: WASD/stick to walk, F or gamepad R2 to spawn (hold to repeat), E for prompts,
Backspace/B to close menus. Touch: tap or hold the SPAWN button.

`build/EggFarm.rbxlx` is the real game. It saves through ProfileStore/DataStores. In Studio,
DataStores only work when the place is published and "Enable Studio Access to API Services" is on.
That is your decision; nothing here changes it. Without access, ProfileStore detects it and
runs on its own temporary in-memory store: Output says "Roblox API services unavailable - data
will not be saved", and you can still play. On a live server, a load that fails or conflicts kicks
the player instead of giving them a blank farm.

## Build and test from source
```bash
bash tools/check.sh          # type check + unit tests + both Rojo builds
bash tools/check.sh --quick  # skip the builds
luau tests/run.luau          # unit tests only (run from egg-farm/)
luau tools/sim.luau          # balance bot: minutes per egg, time to prestige
bash tools/headless/run.sh   # offline mock harness scenarios (see docs/HEADLESS_RESULTS.md)
rojo build default.project.json -o build/EggFarm.rbxlx
rojo build test.project.json -o build/EggFarm.Test.rbxlx
rojo serve test.project.json # live-sync into an open Studio place (Rojo plugin)
python3 blender/build.py     # regenerate models (+ blender/verify.py)
```

## Project structure
See `docs/ARCHITECTURE.md`. In short: `src/shared` holds the contract (`Types.luau`), the catalog
(`Data/*`) and pure rules (`Logic/*`, unit-tested); `src/server` owns all state (economy per player,
saves, plots, zones, commerce, fox); `src/client` shows it (HUD, menus, visuals). Clients only
send intents; the server prices, validates and applies everything.

## Customising
- Numbers: `src/shared/Data/*.luau`. Each file header says which values are design values. Re-run `tools/sim.luau` after changes.
- Codes: `src/server/Data/Codes.luau` (server only).
- Shop: create your own game passes and developer products on the Creator Dashboard, then put
  their IDs in `robuxId` in `src/shared/Data/Products.luau`. Until then Robux items say "not for sale yet".
- Audio: the game's own sounds are uploaded and wired in (`src/client/Controllers/Sound.luau`,
  IDs in `docs/ASSETS_UPLOADED.md`). Swap in other IDs you own or have licensed there.
- Models: the game builds its world from native parts. The Blender models are uploaded to your
  account (`docs/ASSETS_UPLOADED.md`, `src/shared/MeshIds.luau`) but not wired in yet: check one
  in Studio first.
- Server size: set Max Players to 8 in Game Settings (the map has 8 plots; a 9th player is told the server is full).

## Renaming
1. `src/shared/GameInfo.luau`: change `Name`, `ShortName`, `Tagline`.
2. Optionally change `"name"` in `default.project.json` and `test.project.json`, and the output
   file names in `tools/check.sh`.
3. Keep `SaveStoreName` unless you want everyone to start fresh. Changing it orphans existing saves.

## Status and limits
- Offline checks: type check, unit tests, both builds, headless mock scenarios. Results are in
  `docs/TEST_RESULTS.md` and `docs/HEADLESS_RESULTS.md`.
- **Not playtested in Roblox Studio.** Studio wasn't reachable from the build environment. The
  first Studio session should follow `docs/STUDIO_TESTS.md`.
- **Real DataStore saving is not validated.** It needs a published place with API access.
- **Live commerce is not configured.** There are no product IDs and nothing has been bought.
- Reference parity is not claimed. See `docs/REFERENCE_COVERAGE.md`.

## Licenses
See `LICENSES.md`.
