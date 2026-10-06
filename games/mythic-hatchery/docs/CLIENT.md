> Historical handoff: implementation has changed. Read CONTRACTS.md, STATUS.md and STUDIO_TESTS.md for the current game.

# Pet Expedition: client

Everything the player sees is built in code under `src/client/` (no Studio GUIs, no uploaded images).
`Main.client.luau` starts each controller in its own `pcall`, then fires `ClientReady`.

## Layout
| Folder | What |
|---|---|
| `Core/State` | `State` snapshots, server clock (`State.Now()`), `Changed` / `TradeChanged` / `Notify` signals, helpers (busy pets, trade pets, boosts, settings). |
| `Core/Remote` | `Call` (pcall + error toast), `CallOnce` (ignores double taps), `Try` (returns the error), `Quiet`, `Fire`. |
| `Core/PetInfo` | Power, odds and variants straight from the shared `Logic` modules (PetMath, Hatch, Economy.HighestArea for gem pets), sorting, craft keys. |
| `Core/Breakables` | Index of `Breakable`-tagged models by `Id`, with cached bounds. |
| `Core/ModelCache` | Builds each `Models.Pet` / `Models.Egg` once, hands out clones. |
| `Core/Sounds` | Sound table (built-in `rbxasset://sounds/...`; swap `Id`s for licensed ones). `Sounds.MusicId` is nil until music is chosen. |
| `UI/Theme`, `UI/Kit` | Colours (rarities, tones), fonts, icons; helpers for labels, candy buttons, panels, bars, pills, tabs, auto UIScale. |
| `UI/Windows` | Screen layers, modal windows (one at a time), router (`Windows.Open("Shop", "Gems")`), confirm popup. `Windows.Lock` keeps the trade window open while a trade runs (backdrop/Esc ignored, other windows refused). |
| `UI/Toasts`, `UI/Viewport`, `UI/PetCard`, `UI/RewardText` | Toasts/banners, pet & egg pictures, pet tiles, reward one-liners. |
| `Controllers/*` | Hud, World (prompts, gates, Islands window), Farming (tap to target, HP bars, break/reward effects), PetRenderer, Hatch + HatchAnim, Inventory, Craft, Expeditions, Quests, IndexMenu, Rebirth, Shop, Trade, Settings, Notifications (Notify toasts + VIP chat tag), Tutorial. |

## Performance
State arrives up to ~5 times a second while farming. Every window compares a signature of what it shows and
rebuilds only when that changes; timers and progress bars update in place.

## Scaling
The UI is designed on a 900 x 560 reference canvas. `Kit.autoScale` adds a `UIScale` that fits it to the
screen minus the top bar, so phones get ~0.6x and big screens up to 1.4x.

## Keyboard (PC)
P Pets · M Shop · X Expeditions · J Quests · I Index · N Islands · T Trade · K Settings · Esc closes.

## Notes for Studio testing
- Unconfigured passes/products (Id 0) show "Test buy" in Studio (calls `DevPurchase`) and "Coming soon" live.
- Tapping a breakable works by raycast or, if its parts aren't queryable, by screen-space picking.
- Auto hatch stops when you walk more than 30 studs from the stand (the server allows 45).
