# Testing report

Date: 2026-10-01. Environment: Linux cloud container (no Roblox Studio, no Windows, no GPU). Every result below comes from commands that were actually run. Raw output is in `docs/evidence/`.

## Summary

| check | tool / version | command | result |
|---|---|---|---|
| Catalog regeneration | Python 3.11 | `python3 tools/gen_catalog.py` | ok (123 values, 61 unresolved) |
| Type check | luau-lsp 1.53.0 | in `tools/check.sh` | 0 diagnostics |
| Unit tests (pure rules) | Luau CLI | `cd tests && luau run.luau` | **98 passed, 0 failed** (`evidence/unit_tests.txt`) |
| Place build | Rojo 7.7.0 | `rojo build default.project.json -o build/SellHotDogs.rbxlx` | ok |
| Headless end-to-end smoke test of the built place | Lune 0.10.4 | `lune run tools/smoke/smoke.luau` | **83 passed, 0 failed, 0 script errors** (`evidence/smoke_report.md`, `evidence/smoke_log.txt`) |
| Top-down render of the fully built plot | Lune dump + PIL | `python3 tools/smoke/render_map.py` | `evidence/plot_map_full.png` |
| Blender assets | bpy 5.0.1 | `python3 tools/blender/build_assets.py` | 22/22 built and exported; sizes within ±15 %; `assets/renders/contact_sheet.png` |
| Code review | separate reviewer pass | read-only review of server and logic | 8 findings, all fixed and covered by tests (see REVIEW.md) |
| **Roblox Studio playtest** | | | **NOT RUN.** Studio is unavailable here. The Studio MCP failed to start (`cmd.exe` not found). |

All of it in one command: `bash tools/check.sh` (`evidence/check_output.txt`).

## What the headless smoke test is (and is not)

`tools/smoke/engine.luau` loads the **built `.rbxlx`** and runs its **real server and client scripts** under Lune.

- **What Lune provides:** Roblox's instance model. Every class name, property name and enum value the scripts use is checked against Roblox's API, so typos and invalid properties fail.
- **What the harness adds:** signals, RemoteEvents that pass copied data like the network does, players and characters, and a frame clock.
- **How it plays:** it presses the real UI buttons by firing `Activated`, and "steps on" pads by firing `Touched`.

It is **not** Studio:

- No physics, collisions, rendering or camera.
- No real touch input, network latency or DataStores.
- No deferred-signal timing.

`BasePart.Position` is mirrored from CFrame by the harness. A few setups write the server profile directly to reach late-game states quickly; these are marked `SETUP` in the script.

### Coverage

Each item below was asserted. The full table is in `evidence/smoke_report.md`.

**Clean start**
- $1.00 start (hypothesis), then buying the stand by stepping on its pad.
- Stand and opening pads appear; Bun Rack stays hidden.

**Manual cycle and purchases**
- **Manual cycle:** no grant mid-cycle, exactly $1.00 after one second, and the wallet equals server cash.
- **Repeated clicks:** they pay once.
- **Condiment Station:** exactly $6.20, then output $2.00.
- **Unaffordable purchase:** rejected with no deduction.
- **Blue Upgrade:** exactly $5.10.

**Invalid input**
- 14 hostile or invalid requests changed nothing: NaN/negative bulk, unknown ids, wrong types, locked actions and fake products.
- Five simultaneous purchase requests (remote + touch) for the same pad deduct once.

**Automation and pickups**
- The register automates the stand.
- A pickup spawns. A far touch is ignored; a near touch pays once.

**Manage panel and mock Robux**
- The Manage panel is locked before the power.
- Powers cards show investor and test-buy buttons. The red ✕ closes the panel.
- Mock receipt grants once. A duplicate delivery adds nothing. A cancelled purchase grants nothing. An already-owned pass is not re-sold.
- Remote upgrade from the Manage panel works from 5,000 studs away.

**Late game**
- Remote Buy walks the entire ladder: all 8 businesses and every pad.
- All buildings appear, and the staircase appears.
- Fast production (42^12 speed) stays at ≤ 12 client messages per second.
- The wallet formats 3e564.

**Prestige and resets**
- **Investors dialog:** Rebirth asks for confirmation; Cancel keeps everything. Rebirth then grants 20 investors, resets the run, keeps the Robux power and clears the plot.
- **Powers bought with investors:** rejected when short. Run Faster costs 400 and sets WalkSpeed to 24. Stack unlocks x5.
- **Forever Purchase:** token granted; "nvm" spends nothing; "Yes" consumes exactly one; a second use is refused. The pad survives evolution and ascension.
- **Evolution:** investors and investor powers reset; Robux and Forever pads are kept.
- **Ascension:** evolutions reset, +1 token, the stand pad shows $3.33 (x3.33 price).

**Names**
- Filtered word, too-long name and a filter outage (fails closed) are all rejected.
- A good name is saved and shown on the plot sign.

**Phone**
- An offer arrives. The Raise chain ends cleanly.
- Accept pays the exact amount once.

**DogDash**
- Locked without its pad. A race takes a 10% bet, cheering works, and it settles.
- Prestige is refused while a race is running.
- Leaving mid-race settles the race before the save.

**Saves and sessions**
- Saved on leave. The plot is released.
- Rejoin restores progress, and offline income = 100% of automated income × elapsed (±1 %). The claim pays once.
- A failed load gives a temporary profile with saving off, and the stored save is untouched.
- A failed save on leave keeps the previous save.
- Two players get separate plots and separate data.
- The Studio dev hook works.

### Unit tests (98)

- BigNum: arithmetic, 10^564 range, sanitising, cents.
- Format: names to centillion, scientific beyond, rounding carry.
- Economy: every observed price and multiplier, and the derived level outputs matching the N 00:48–00:59 labels.
- Game: opening sequence, bulk/max, automation, aggregation, offline, pickups, powers, isolation.
- Prestige: every reset boundary, Forever eligibility, x2 investors, Rebirth Without Reset, settling unclaimed offline income.
- Profile: migration v1→v2, corrupt/newer/negative rejection, clamping.
- Receipts: duplicates, unknown products, caps, time-skip banking.
- Phone: all outcomes.
- DogDash: cap, decay, and expected return < 1 with maximum cheering.
- Names.

## Not tested (needs Carter's PC or a live experience)

- **Anything visual in Roblox Studio:**
  - lighting
  - model look and grounding
  - collisions and walking
  - camera obstruction
  - billboard readability
  - safe areas
  - phone/tablet emulator layouts
  - scrolling feel
  - effects and sound
  - actual frame rate
- **No screenshots or captures of the running game exist.** The only images are Blender previews, the contact sheet, and the schematic plot map.
- Real touch input; gamepad.
- Real `DataStoreService` persistence across servers; the session lock under contention.
- Real `MarketplaceService` purchases. None exist and none were made.
- Mesh import of the Blender assets.
- Whether the engine-bundled sound paths play.
- Roblox text filter behaviour on real strings. The harness filter is a stand-in.
- Deferred signal behaviour in a live server.

**Next step:** run `docs/STUDIO_TEST_PLAN.md` on desktop and in the Device emulator, and save screenshots to `docs/evidence/studio/`.
