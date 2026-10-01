# Licenses and provenance

## Egg Farm's own work
All Luau source, Blender generation scripts, generated models (.blend / .fbx / .obj), UI icon
artwork and synthesized audio in this folder are original work created for this project.
No assets, code, product IDs, names of products, icons or audio were taken from Egg Empire or any
other game. Reference research notes (`docs/REFERENCE_RESEARCH.md`) contain facts and links only;
no reference screenshots or media are stored in this repository.

## Third-party code shipped in the game
| Component | Version | Source | License | Where | Modifications |
|---|---|---|---|---|---|
| ProfileStore (MAD STUDIO, loleris) | git commit `45c9847cbcf1fc260369c50eb335aba7c35aecdd` (2025-07-31) | https://github.com/MadStudioRoblox/ProfileStore | Apache-2.0 (`vendor/ProfileStore/LICENSE`; the project has no NOTICE file) | `vendor/ProfileStore/ProfileStore.luau` → `ServerScriptService.Vendor.ProfileStore` | None. Used unmodified through `src/server/Persistence/ProfileStoreAdapter.luau`. |

Review notes (ProfileStore): read the source and README before use. It provides session locking,
autosave, BindToClose flushing and a mock store; it makes no network calls besides Roblox
DataStore/MessagingService APIs and has no telemetry. Data rules respected by FarmState: no mixed
tables, no sparse numeric tables, no Instances or userdata.

## Tools used to build (not shipped)
| Tool | License | Use |
|---|---|---|
| Rojo 7.7.0 | MPL-2.0 | building the .rbxlx places |
| Luau CLI | MIT | running unit tests |
| luau-lsp 1.53.0 | MIT | type checking |
| Blender `bpy` 5.0.1 | GPL-2.0-or-later (tool only; generated output is ours) | generating models and renders |
| Pillow | HPND (MIT-CMU) | drawing icon PNGs |
| NumPy | BSD-3-Clause | synthesizing audio |
