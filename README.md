# Survival Hour

A competitive solo Roblox forest survival game (Survival Wars rules): gather, craft, build, explore caves and ruins, hunt, and snuff enemy campfires. While your fire burns you respawn; the last survivor wins. Between matches you level up and earn Coins (cosmetics) and Diamonds (classes and power-ups).

- **Open it:** `build/SurvivalHour.rbxlx` in Roblox Studio, then press Play and ready up (a Studio local match starts automatically).
- **Rebuild:** run `rojo build default.project.json -o build/SurvivalHour.rbxlx`.
- **Test logic:** run `cd tests` then `luau run.luau`. Mesh skins and lobby: `python tests/skins/bundle.py`.
- **Regenerate meta tuning tables:** `luau tools/gen_meta_tuning.luau`.

Docs:

| Doc | What's in it |
|-----|--------------|
| [docs/GDD.md](docs/GDD.md) | Game design summary |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Defaults we chose where the brief was open |
| [docs/TUNING.md](docs/TUNING.md) | Every recipe, cost, stat, odd, price, class, power-up, XP and cosmetic value |
| [docs/SETUP.md](docs/SETUP.md) | Studio testing, publishing, product IDs, data stores, audio |
| [docs/TESTING.md](docs/TESTING.md) | What was verified, and the Studio/live test plan |
| [docs/STATUS.md](docs/STATUS.md) | Current state, known gaps, how to resume |
| [docs/MESH_SKINS.md](docs/MESH_SKINS.md) | How the 3D asset pack meshes are wired into the game |
| [docs/SPEC_AUDIT.md](docs/SPEC_AUDIT.md) | Survival Wars spec: what's done / partial / missing |
| [docs/IMPLEMENTATION_LOG.md](docs/IMPLEMENTATION_LOG.md) | What changed in each Survival Wars phase |

## 3D asset pack

The game's models (forest, camps, craftables, wildlife, lobby) are in this repo:
[Docs/ASSET_PACK.md](Docs/ASSET_PACK.md) gives an overview, and [Docs/IMPORT.md](Docs/IMPORT.md)
covers importing into Studio.
