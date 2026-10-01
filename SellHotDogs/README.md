# Sell Hot Dogs

A hot-dog adaptation of the Roblox tycoon *Sell Lemons* by BloxByte Games. The code, models, sounds and UI are original. The source game is used only as a reference for rules and flows. Every rule number is tagged in `catalog/economy.json` with how sure we are of it.

**Status:** playable locally in Roblox Studio (local place `build/SellHotDogs.rbxlx`). It has **not yet been opened in Roblox Studio**: this was built in a Linux cloud container where Studio cannot run. The testing that was done is listed in [`docs/TESTING.md`](docs/TESTING.md).

## Open and play (Windows, Roblox Studio)

1. Open `build/SellHotDogs.rbxlx` in Roblox Studio (File → Open from File). This is a separate local place. It is not published and has no API access or Robux products.
2. Press **Play** (F5). You spawn by the road on your own plot.
3. Step on the yellow **Hot Dog Stand – $1.00** circle, then press the green **CLICK** bar over the stand (or `E` when close).
4. To test phones/tablets, use Studio's **Device emulator** (Test → Device). For several players, use **Test → Clients and Servers → 2 players**.
5. Studio-only test tools: the **Shop** tab shows **TEST BUY** buttons. These run the real receipt code with fake receipts and never charge Robux.

The checklist to walk through is [`docs/STUDIO_TEST_PLAN.md`](docs/STUDIO_TEST_PLAN.md).

## Rebuild from source

Tools (all free; the versions used are the ones listed):

| tool | version | used for |
|---|---|---|
| [Rojo](https://rojo.space) | 7.7.0 | `rojo build default.project.json -o build/SellHotDogs.rbxlx` (or `rojo serve` + Studio plugin for live sync) |
| Luau CLI | latest release | unit tests: `cd tests && luau run.luau` |
| luau-lsp | 1.53.0 + its `globalTypes.d.luau` | type check |
| [Lune](https://lune-org.github.io) | 0.10.4 | headless smoke test: `lune run tools/smoke/smoke.luau` |
| Python 3.11 | | `tools/gen_catalog.py`, `tools/audio/gen_sfx.py` |
| Blender `bpy` | 5.0.1 (pip) | `python3 tools/blender/build_assets.py` (models, exports, renders) |

`bash tools/check.sh` runs everything: catalog regeneration, type check, unit tests, build and smoke test. Set `SHD_TOOLS` to the folder holding `luau/`, `rojo/`, `lsp/`, `lune/` and `globalTypes.d.luau`.

On Carter's PC, Rojo 7.7.0 is at `C:\Users\myson\Documents\Codex\tools\rojo\rojo.exe` (from the handoff; not checked from here):

```
cd "C:\path\to\SellHotDogs"
C:\Users\myson\Documents\Codex\tools\rojo\rojo.exe build default.project.json -o build\SellHotDogs.rbxlx
```

## Layout

```
catalog/economy.json        every number, with evidence status and source (single source of truth)
src/shared/Catalog.luau     generated from the JSON (python3 tools/gen_catalog.py)
src/shared/Logic/           pure rules, unit-tested: BigNum, Format, Economy, Game, Profile, Phone, Dash, Names
src/shared/                 Config (runtime switches), Products (Robux IDs, empty), Layout (plot geometry), Net
src/server/Services/        Data+Store (saves), World+Models (plots, native-part models), GameService (loop, actions), Extras (pickups, phone, DogDash, names, Robux)
src/client/                 HUD, world controls, panels, dialogs, phone, DogDash, effects; UI kit
assets/                     original Blender .blend, FBX/OBJ exports, renders, synthesised audio (assets/ASSETS.md)
tests/                      103 unit tests (Luau CLI)
tools/smoke/                Lune mini-engine + 91-check headless playthrough of the built place
docs/                       catalog, research register, testing report, save schema, live setup, Studio plan, review
```

## First playable milestone vs. the complete request

| Feature | State |
|---|---|
| Separate local place, roadside plot, original art direction | **Done** (native-part world). Blender meshes exist but are **not imported** (needs Carter's account). |
| Opening: $1 stand, 1 s manual cycle paying $1.00, server-authoritative cash | **Done**, tested headless |
| Observed early upgrades: Condiment Station $6.20 x2, Bun Rack $82.50 x3, Cash Register $100 automation, Billboard $785 x3 speed, stand upgrades $5.10 → $7.65 → $11.00 → $19.00 | **Done**; repeat-upgrade formula after the 4th is a **placeholder** (unknown) |
| Eight businesses (Stand, DogDash, Delivery Depot, Hot Dog Trading, Test Kitchen Labs, Kitchen Robotics, Hot Dog Republic, HotDogX), unlock order, pads, managers | **Done** with secondary-source prices; later businesses' base output/cycle and most of their upgrades are **placeholders/unknown** |
| Ingredient racks and pickups, Expert Collector | **Done**; quantities **placeholder** |
| Manage, Powers (Run Faster, Stack Upgrade + bulk/max, Remote Buy, Expert Collector), Speed Up Time | **Done**; tier costs beyond tier 1 **placeholder** |
| Phone offers: accept / raise / decline, better/final offers, walk-away, expiry | **Done**; odds and amounts **placeholder** |
| DogDash the Game (4 racers, bet, cheer) | **Done**; payout/price **placeholder** |
| Business name editing with Roblox text filter (fails closed) | **Done** |
| Alien Investors + Rebirth, x2 Investors, Rebirth Without Reset | **Done**; award formula **placeholder** |
| Void Evolution (x42 speed each, recipe change), Ascension (x7.77 cash, x3.33 prices, +1 Forever token, staircase) | **Done**; thresholds after the first evolution **placeholder** |
| Forever Purchase target selection (Yes / nvm / Cancel, single consumption) | **Done** |
| Offline income (100% of automated income, claim popup, no cap) | **Done** |
| Versioned saves, failed-load protection, mock storage, idempotent receipts, mock purchases | **Done** (mock storage only). Real DataStore code exists but is **untested**. |
| Studio playtest on desktop/phone/tablet, screenshots | **Not done**: Studio was unavailable. Use the Studio test plan. |
| Mesh import, live Robux products, publishing | **Not done** (outside this handoff's authorisation). See `docs/LIVE_SETUP.md`. |

## Pass 2 (owner checklist)

| Item | State |
|---|---|
| Smaller HUD (wallet + name about 1/3 of the old area), next-unlock bar | **Done** |
| Every building, upgrade, decoration, customer and sky object has its own original Blender model (87 models) | **Done** in Blender. **Not visible in game until uploaded** (`tools/upload_assets.py` with Carter's Open Cloud key); native stand-ins until then |
| Picture icons (87 renders) | **Done**; shown as live 3D previews until uploaded |
| Decor shop: 12 looks-only decorations, designed placements (sets of planters, lamps, balloons, topiaries…), kept forever | **Done** |
| More UI animation (pop-ins, hover/press, pulses, wiggles, banners, confetti) | **Done** |
| More detailed sky: 3D clouds, blimp, balloons, birds, cloud puffs, road traffic; painted skybox once uploaded | **Done** |
| Progress feels rewarding: grow-in builds with confetti, x2 CASH / LEVEL UP bursts, milestone banners, level-milestone props, customers that multiply | **Done** |

## Key documents

- [`docs/REVIEW.md`](docs/REVIEW.md): short review report (what works, what was tested, blockers, fidelity gaps, files created)
- [`docs/CATALOG.md`](docs/CATALOG.md): every economy value with status and source, plus the **Unresolved** list
- [`docs/RESEARCH.md`](docs/RESEARCH.md): reference URLs and timestamps, what was and wasn't verified this session
- [`docs/TESTING.md`](docs/TESTING.md): test report; raw evidence in `docs/evidence/`
- [`docs/SAVE_SCHEMA.md`](docs/SAVE_SCHEMA.md): save format, migration, mock storage and receipts
- [`docs/LIVE_SETUP.md`](docs/LIVE_SETUP.md): steps for publishing, DataStores, Robux products and mesh upload (none performed)
- [`assets/ASSETS.md`](assets/ASSETS.md): models, audio, provenance, import steps
