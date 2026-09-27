# Survival Wars: Master Continuation Spec audit

Audit of the existing build against *Survival Wars: Master Continuation Specification* (Sep 2026).
Status key: ✅ already satisfied · 🟡 needs improvement / exists but differs · ❌ missing.
The "Phase" column is the implementation order in [IMPLEMENTATION_LOG.md](IMPLEMENTATION_LOG.md).

Audited against: `src/` (Rojo project, ~19k lines), `docs/` (GDD, DECISIONS, TUNING, OVERHAUL), the Blender
asset pack (`blender/`, `Export/`, `SurvivalHourAssets.rbxm`) and the mesh-skin integration
([MESH_SKINS.md](MESH_SKINS.md)). Status reflects code and static checks; **nothing has been playtested in
Studio yet**.

## Core / match
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Core loop gather → craft → build → loot → hunt → raid → survive | 🟡 | Loop exists (teams), missing pickaxe/scrap/iron tiers, POIs, fuel | 1–4 |
| Min 4 **solo** players, each with own camp + pre-placed Campfire + Tier I Workbench | ✅ | Phase 1: solo teams-of-one, 4 players / 4 camps | 1 |
| Don't block future teams | ✅ | Team framework exists; solo = teams of one (config) | 1 |
| PvP active immediately | ✅ | Combat on from match start (verify intro countdown) | 1 |
| Last survivor wins | ✅ | Last team-of-one standing | 1 |
| Grindy, costly progression | ✅ | Phase 2 spec costs (tune after playtests) | 2 |
| Centralised balance; server-authoritative damage/harvest/loot/fire/raids/currency/ownership | ✅ | `Config.luau` + data modules; services are server-side | – |

## Day / night
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Day 2 min, Night 2 min | ✅ | `DayLength = 120`, `NightLength = 120` | – |
| Sunrise: 15 s invincibility for players alive at that moment; they can't deal damage | ✅ | Phase 1 | 1 |
| Night 3 start: enemy campfire protection ends permanently | ✅ | Phase 1 | 1 |

## Campfire
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Burning fire = respawns | ✅ | Phase 1: unlimited while burning | 1 |
| Fire out = owner on final life; next death eliminates | ✅ | Any death with fire out eliminates | – |
| Fire cannot be relit | ✅ | Never relights | – |
| **Fuel**: 0% extinguishes permanently (even Nights 1–2); start ~50%; L1 full ≈ 8 min; 1 Wood ≈ +2% | ✅ | Phase 1 | 1 |
| Nights 1–2: no manual snuffing; PvP / theft / raids still active. Night 3+: fires vulnerable day and night | ✅ | Phase 1 | 1 |
| Snuff times L1–L5 = 8/10/12/15/20 s; damage/move/release cancels; owner warned with direction (no wallhack) | ✅ | Phase 1 (still needs a filled canteen, D37) | 1 |
| Fire upgrades L2–L5 with Wood/Stone/Scrap/Iron/Rare costs; full fuel 8→12 min; visual evolution | 🟡 | Phase 1 logic + effect scaling done; Scrap/Iron/Rare have no source yet; mesh variants per level later | 1 / 5 |

## Workbench
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Pre-placed; can't be moved/damaged/destroyed/stolen/downgraded/used by enemies; usable after fire dies | ✅ | Indestructible, owner-only prompt, no fire check | – |
| Tiers I–V with the spec costs; unlock recipes only; visual evolution; reset per match | ✅ | Phase 2 (Tier IV/V visuals procedural on the L3 mesh) | 2 |

## Start / resources / tools
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Start with no axe/pickaxe/weapon; hand-gather sticks, loose stones, fibre, berries | ✅ | Hand gathering exists | – |
| Crude Axe / Crude Pickaxe / Crude Spear recipes (sticks+stone+fibre) | ✅ | Phase 2 | 2 |
| Small tree = exactly 4 Wood (Crude Axe+); Large = exactly 16 (Stone Axe+) | ✅ | Phase 2 | 2 |
| Small stone = 3 Stone (Crude Pickaxe+); Large = 12 (Stone Pickaxe+); loose → hands | ✅ | Phase 2 | 2 |
| Tool tiers Crude/Stone/Iron/Steel with durability ≈ 40/100/225/450 hits; break at 0 | ✅ | Phase 2 | 2 |
| Renewable resources respawn | ✅ | `ResourceRules` respawn | – |

## Death / drops / elimination
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Only materials drop on death, as one optimised loot bag | ✅ | Supply Bag of resources (D14) | – |
| Respawn timers 8/12/16/20 s cap; respawn at fire with ~3 s protection (can't deal damage) | ✅ | Phase 1 | 1 |
| Restricted spectator (no free camera) | 🟡 | Spectate controller exists; verify it's restricted | 1 |

## Storage / inventory
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Storage breach unlocks (not deletes); owner repairs/resecures | 🟡 | 3 s steal channel takes 10 units | 3 |
| Crate / Reinforced Chest / Metal Locker / Survival Safe (12/20/30/40–50 stacks); cap 1–5 by bench tier | ❌ | One StorageBox, capacity 200 units, limit 2 | 3 |
| Breaching tools: Crowbar → Sledgehammer → Breaching Charge | ❌ | – | 3 |
| ~6 starting slots; packs 10/16/24/32/40; stack sizes (Wood 32, Stone 24, …) | ❌ | 4 equipment slots + 30-unit resource pack | 3 |

## Building / raids / traps
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Build only in own camp radius; no cave/river blocking or map spam | 🟡 | 55-stud radius ✅; verify river/cave rules | 3 |
| Tier I–V structures (walls, doors, floors, windows, scrap/heavy defences) | 🟡 | Wood/Reinforced wall, Gate, Spikes, Watchtower, Storage | 3 |
| Traps: Tripwire Alarm, Snare, Spike Barricade, Bear Trap, Advanced Alarm; cap 2–6; no turrets | 🟡 | Spikes only | 3 |

## Wildlife / combat
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Deer, Bears, Rabbits, Boar, Wolves with distinct behaviour | 🟡 | Wolf, Bear, Bat (no deer/rabbit/boar) | 4 |
| Night escalation (pressure, not HP inflation) | 🟡 | Spawn at night only | 4 |
| Health 100; Stamina 100; no fast regen | ✅ | Phase 2 (sprint uses stamina; melee costs come in Phase 4) | 2 |
| Healing takes time, interruptible: Bandage ~20 / First Aid ~50 / Medkit ~100 | ✅ | Phase 2 | 2 |
| Melee Light / Heavy / Block with stamina and guard break | ❌ | Single attack | 4 |
| Ranged: Crude Bow II, Hunting Bow III, Crossbow III/IV; headshots | 🟡 | Bow + Pistol + Rifle; no headshots | 4 |
| Armour Head/Chest/Legs, Hide → Tactical, ≤ 45–50 % full set | 🟡 | One "Leather Armor", 25 % | 4 |

## Caves / houses / POIs / loot
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Randomised caves, cabins, ranger structures, campsites, ruins, mines… with rarity | 🟡 | LayoutGen has modules (ruins, glade, pond…); OVERHAUL plans cabins/caves; `Landmarks.luau` missing | 5 |
| Chest tiers Common → Very Rare, best one-time per match | 🟡 | Forest crates + care packages; tiered chests planned | 5 |

## Meta: XP, coins, diamonds, classes, power-ups, Robux
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Account XP / Level 100 cosmetic progression | ❌ | – | 6 |
| Coins (cosmetics) with the listed rewards and price bands; cosmetics catalogue | ❌ | – | 6 |
| Non-pay-to-win Robux (coin packs, cosmetic bundles only) | 🟡 | Phase 1: all gameplay products off sale; Coin packs come in Phase 6 | 6 |
| Diamonds: win = exactly 2 | ✅ | Phase 1 | – |
| Classes: Survivor (free) + Lumberjack 40 … Tracker 200; one per match | ❌ | – | 6 |
| Power-ups: Strong Back 40 … Second Wind 200; one equipped; no mid-match swap | 🟡 | 6 different powerups with 3 levels | 6 |

## Lobby / UI / art / world / audio / performance
| Requirement | Status | Current build | Phase |
|---|---|---|---|
| Aesthetic forest-refuge lobby with integrated play/shop/cosmetics/loadout/leaderboards | 🟡 | Functional lobby; pack has lobby props not yet placed | 7 |
| Cohesive custom UI, cinematic menu | 🟡 | Complete functional UI (primitive icons) | 7 |
| Blender assets for important props | ✅ | 146-asset pack integrated via mesh skins | – |
| **Blender modular forest ground/landscape** (rivers, cliffs, cave mouths, clearings) | ❌ | Roblox terrain generated at runtime | 5 |
| Lush varied forest (many variants) | 🟡 | Flora has many procedural variants + mesh skins | 5 |
| Lighting: day / sunset / moonlit night / fog | 🟡 | Day + night presets | 7 |
| Audio (ambience, surfaces, …) | 🟡 | Engine sounds + empty slots | 7 |
| Optimisation (streaming, LOD, collisions) | 🟡 | StreamingEnabled, atomic models; LOD meshes exported but unused | 5 |

## Conflicts that change existing behaviour
1. **Paid revives, paid care packages, paid bandages and Robux powerup unlocks** are pay-to-win under the
   spec's Robux rules. They'll be removed from sale (the code paths stay but are disabled in `Products.luau`).
2. **Teams of 4 → solo.** Implemented as teams of one (`Config.Match.MaxPerTeam = 1`), so teams can come back
   with a config change.
3. **Unlimited respawns while the fire burns** replace 3 free respawns + revive window.
4. **Win reward** drops from 10 to exactly 2 Diamonds.
5. **Powerups** are redesigned: 10 single-level spec power-ups plus 7 classes replace the 6 three-level powerups.
