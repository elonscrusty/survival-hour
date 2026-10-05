# Pet Expedition: server notes

Entry: `src/server/Main.server.luau` calls `Net.Init()`, requires every service in `ORDER`, runs each
`Init(ctx)` (services reach each other as `ctx.<Name>`), then spawns each `Start()`.

## Services (`src/server/Services/`)
| Service | Job |
|---|---|
| `Util` | join/leave hooks, remote wrapper (`Util.Function` / `Util.Event`: per-player per-remote token bucket from `Util.Limits`, refuses until the profile is loaded, pcall, `{ ok = false, err }` on failure), validation, `Notify` / `Toast` |
| `DataService` | DataStore `Config.DataStoreName`, key `p_<UserId>`, session lock via UpdateAsync, autosave, save on leave + BindToClose, `SaveNow`, Studio memory fallback, "Failed" sessions never save |
| `StateService` | coalesced `State` pushes (0.2 s), `Pets` / `Vip` / `Target` attributes, leaderstats, Premium / group / PolicyService flags, `SetSetting`, `ClientReady`, coin and luck multipliers |
| `WorldService` | `World.Build()`, area tracking (sends players found deep inside a locked island back), `OpenGate`, `Teleport` |
| `HatchService` | `HatchEgg` (cooldown, Triple Hatch pass, gem-egg policy, distance to the egg stand, storage, price, luck) |
| `PetService` | equip / equip best / unequip all / delete / lock / craft, pet XP and `LevelUp` |
| `BreakableService` | spawns breakables per island zone, `SetTarget`, damage ticks, reward split by damage, respawn, Auto Farm |
| `ExpeditionService` | start / claim / skip |
| `RewardService` | daily, playtime (per server session), quests, Index, `Discovered` |
| `RebirthService` | rebirth |
| `BoostService` | personal boosts, server luck (this server only) |
| `PurchaseService` | ProcessReceipt (dedupe by PurchaseId, granted only after a successful save), passes, Studio `DevPurchase` |
| `TradeService` | requests (timeout, cooldown, account age, policy), offers, ready + countdown, atomic swap, both saved right after, cancel on leave |

## Pure rules (`src/shared/Logic/`, unit tested in `tests/`)
`Rng`, `Schema` (profile shape, caps), `PetMath`, `Hatch`, `Economy` (currency, multipliers, boosts, gates,
rebirth), `Inventory`, `Expedition`, `Rewards`, `Profile` (defaults, sanitising, PlayerState), `Trade`,
`RateLimiter`.

## Rules worth knowing
- New players: 150 coins, Meadow open. Coins cap 1e15, gems 1e12.
- Pets on expeditions are busy (no equip / delete / craft / trade). Pets offered in an open trade can't be
  deleted, crafted or sent on expeditions. Locked pets can't be deleted, crafted or traded.
- Traded pets get fresh uids from the receiver and arrive unlocked.
- Expedition claims are refused (nothing paid) if the found pets wouldn't fit in storage.
- Gem eggs and trading stay off until PolicyService answers (allowed in Studio if it can't answer).
- Playtime gifts are per server session (rejoining restarts them), as `Config.PlaytimeGifts` describes.
