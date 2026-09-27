# Test Results & Test Plan

§0 records the first in-Studio pass (Play Solo, driven through Studio MCP). §1 lists the offline checks. §2 and §3 are the checklists for Studio and live servers. Multi-client, mobile and live-server items are still untested.

## 0. Studio Play Solo pass (2026-09-26)

Driven via Studio MCP: DEV remotes, prompt `InputHoldBegin/End`, injected clicks, server/client log reads and screenshots.

**Bugs found and fixed**

| Bug | Fix |
|-----|-----|
| Client Animation errored every frame ("C0 is read only"): character joints are `AnimationConstraint`s after Roblox's joint upgrade | `Animation.luau` pre-multiplies each joint's `Transform` in `PreSimulation` (works for Motor6D and AnimationConstraint) |
| Every model built with `place()`/`finish()` was half-buried: setting `Model.WorldPivot` does nothing once `PrimaryPart` is set, so the pivot was the primary part's centre. Walls showed ~2.5 of 9 studs, trees had no trunks, and wall colliders were jumpable | `Build.SetPivot` sets `PrimaryPart.PivotOffset`; used by Structures, Camp, Nature, LootModels, ItemModels |
| Gates couldn't open. `FromPart` loops skipped a level (`m.Parent:FindFirstAncestorOfClass`), so parts in nested models (a gate's Door, a held item in a character) never resolved | Fixed in BuildService, GatherService, WildlifeService and `Util.PlayerFromPart` |
| HUD team badges showed 0 alive until the first death | `MatchService.CheckOutcome()` runs once after spawning |
| 17 UI glyphs aren't in Gotham and drew as boxes (☾ ➶ ✕ ✦ ⌖ ♜ ⟲ ⟳ ⩘ ⊓ ⋀ ▮ ◍ ◗ ⌕ ⛨ ᚹ) | Replaced with glyphs verified to render |

**Passed (solo):** READY queue → local match in ~3.5 s; forest build 1.13 s; day/night + night lighting; victory screen with +10 ◆ and return to lobby; deaths 1–3 respawn at 5 s; 4th death opens the 20 s window; DEV revive escalates the tier; window lapse → eliminated + spectate bar; extinguish during window/respawn → instant elimination; death after fire out → eliminated; hand gathering, 30-unit cap + warning, axe chopping, tree stump → regrows at 90 s; all 12 non-structure recipes deduct exactly; the workbench upgrade pays from pack + storage and swaps the model; wall/gate/spikes/reinforced wall/storage/watchtower placement, end-to-end walls, and rejections (overlap, fire clearance, zone, distance); storage deposit/withdraw; watchtower paid from storage; gate opens (after fix); canteen fill → 10 s pour at night extinguishes an enemy fire, and release/walk-away/hit cancel it; "night only" by day; no Pour prompt on your own fire; care package (free drop 20–40 s after dawn, 4 s open, spills items); crates (1.5 s, restock at dawn); bandage +45 after 3 s, interrupted by damage; death bag keeps gear and is lootable; fire heals slowly; wolves (telegraph, lunge, leather drop) and bears (telegraph, charge, 30 dmg); animals avoid firelight and leave at dawn; bow and pistol consume ammo and hit; powerup buy/upgrade gating/equip (lobby only); Trailblazer, Scavenger, Hunter and Climber (vaults a 9-stud wall) abilities.

**Not yet covered:** anything needing 2+ clients (teammate revives, enemy structure damage, stealing, spikes, second raider, a real multi-team win, Sharpshooter mark), Craftsman, the mobile emulator, persistence with API access.

## 1. Executed checks (2026-09-26)

| Check | Command | Result |
|-------|---------|--------|
| Unit tests (Luau 0.740 CLI) | `cd tests; luau run.luau` | **89 passed, 0 failed** |
| Syntax compile of every `.luau` file | `python tools/check.py --luau <luau dir>` | 71 files, 0 errors |
| Unknown-global scan (typos / missing locals) | same script | 0 problems |
| Require-path resolution (`./`, `../`, `Shared.X`, `Logic.X`, `Models.X`) | same script | 0 problems |
| Remote names used vs `Net.Events` | same script | 0 problems |
| `ctx.Service.Function` calls vs functions defined | same script | 0 problems |
| Roblox-API-aware type check (luau-lsp 1.70.0 + Roblox `globalTypes.d.luau`) | `rojo sourcemap …; luau-lsp analyze --sourcemap … --definitions … src` | 20 warnings remain, all reviewed and judged harmless (below). No unknown members or methods on Roblox classes are reported. |
| Build | `rojo build default.project.json -o build/SurvivalHour.rbxlx` (Rojo 7.7.0) | builds (≈0.6 MB) |

Remaining luau-lsp warnings, and why they're harmless:

- *"Cannot call a value of type {…} in union"* (State, MatchService, PurchaseService): table-of-listeners inference limitation. The code iterates the list and calls each element.
- *"Folder? could be nil"* right after `Instance.new("Folder")`: the solver's inference. The value is never nil there.
- *"Cannot cast Model? into Instance"* inside `{ p.Character :: Instance }`: the character is checked non-nil just before.
- *"Type "Alive" cannot be compared with "Respawning""*: string-literal narrowing across a function call. The state really does change inside `ApplyRevive`.
- *Rect / Party exact-table* warnings: extra fields on tables passed to pure modules.
- `LoadCharacter` deprecated: only used as a fallback if `LoadCharacterAsync` errors.
- Unused `ctx` in Util and an implicit-return lint: cosmetic.

### What the unit tests cover

| Area | Tests | Key assertions |
|------|-------|----------------|
| Team assignment (`TeamAssignment.spec`) | 13 | 4 valid non-empty teams at 8 and 16 players; parties never split; impossible compositions (2×4, 5×3) keep queueing; the blocking party is skipped while older parties stay; oldest-first; spread ≤ 1; rebalance after a leaver; 60-party queue under 2 s |
| Lives (`LivesRules.spec`) | 12 | 3 free respawns → revive window; fire out ⇒ elimination; fire out during respawn and during the window; window expiry; tier escalation whatever the payer; underpaid tier rejected; one purchase lock; pending prompt never extends the window; credit lookup; outcomes |
| Inventory (`InventoryModel.spec`) | 8 | 30-unit cap; bad input rejected; all-or-nothing removal; slot swap/displace; armor worn; death drop keeps equipment; pouch caps; durability breakage |
| Storage (`StorageLedger.spec`) | 6 | deposit/withdraw; carry limit; capacity; simultaneous withdraw can't duplicate; combined payment is all-or-nothing |
| Rate limiting | 3 | burst/refill, per-player isolation, spam capped |
| Loot (`Loot.spec`) | 5 | odds sum to 100%; exactly 3 entries; guns sometimes (≈32%); 50k-roll distribution within 1% of weights; crates have no guns |
| Recipes | 4 | exactly 5 recipes per workbench level (the brief's 15); rope isn't an unlock; brief constraints (axe = stick + stone, canteen = leather + rope at L2, hammer = wood + stone, upgrades use all four materials) |
| Powerups | 5 | 6 powerups × 3 levels, the brief's prices, L2/L3 prices, modest passives, monotonic levels |
| Profile / receipts (`ProfileRules.spec`) | 10 | receipt idempotency; replay after reload; bounded memory; duplicate unlock refunded as diamonds; upgrade skip; diamond unlock/upgrade gating; win reward exactly once per match; corrupt data reconciled; equip requires ownership; credit consumption |
| Challenges (`ChallengeRules.spec`) | 7 | same wall counts once; per-match cap; one victim capped at 5 hits; teleport ≠ travel; target required; maxed powerup stops tracking |
| Placement (`PlacementRules.spec`) | 7 | zone edge; fire/workbench clearance; overlap incl. rotated and crossing walls; end-to-end walls allowed; limits |
| Map layout (`LayoutGen.spec`) | 9 | 12 raw seeds validate (Generate retries otherwise); fixed camps; identical resource and crate counts per sector; nodes stay in their sector; varies by seed; deterministic; each camp has a creek < 90 studs away and ≥ 12 resource nodes within 140 studs; drop points; rotation-symmetric heights |

## 2. Studio test plan (run before publishing)

Use Play Solo for single-player items, and **Test → Clients and Servers** (4–8 clients) for the rest. The DEV panel speeds everything up. Mark each item ✅/❌.

### Core loop
- [ ] Lobby loads; Ready ring and READY button both queue; after about 6 s a local match starts.
- [ ] The forest generates without errors in Output. Note the time it takes (target < 10 s).
- [ ] Day → Night → Day repeats at 120 s (or `StudioPhaseLength`). Lighting stays readable at night.
- [ ] With 2+ teams, eliminating one team leaves the others; the last team gets the victory screen and 10 ◆; everyone returns to the lobby.
- [ ] A 2-client test where one client leaves: the remaining team wins (abandoned team).

### Lives & fire
- [ ] Deaths 1–3 respawn after 5 s at your camp and the counter drops. The 4th death opens the 20 s revive window.
- [ ] DEV revive (simulated purchase) revives you. Tier 2 shows on the next death.
- [ ] A teammate sees the "needs a revive" card and can pay; the target sees "a teammate is buying…".
- [ ] Letting the window lapse eliminates you → spectator bar, cycle ◀ ▶.
- [ ] Extinguish your own fire (DEV) while respawning or in the window → instant elimination; the Revive button disappears.
- [ ] After the fire is out, any death eliminates.

### Raids
- [ ] Craft a canteen (DEV Lv2 + leather/rope) → fill at a creek ripple → at night hold Pour at an enemy fire. The progress bar runs 10 s, the arm pours with water particles, the fire goes out with steam, and the announcement plays.
- [ ] Releasing the key or tap cancels. Walking away cancels. Taking a hit cancels.
- [ ] A second raider gets "Another raider is already pouring". Daytime shows "Night only".
- [ ] Your own fire has no Pour prompt.

### Gathering, inventory, crafting, building, storage
- [ ] Gather twigs, rocks and ferns by prompt; chop small trees with an axe (swing or prompt). The pack fills to 30 and warns. Depleted nodes regrow later (trees grow from a sapling).
- [ ] Craft all 15 recipes plus rope. Level-locked recipes show 🔒. Materials are deducted exactly.
- [ ] Workbench upgrade pulls from pack + storage, applies to the whole team, and the model changes.
- [ ] Build walls (snap end-to-end), a gate (team-only open), spikes (hurt enemies), a reinforced wall, a watchtower (ladder) and storage. Red preview outside the zone, near the fire/bench/spawns, overlapping, or too far.
- [ ] An enemy damages walls: damage states darken and crack; destroyed walls spawn debris. Repair with the hammer uses wood/stone.
- [ ] Storage deposit/withdraw. Enemy steal takes 3 s; a hit interrupts it; carry limit respected; owners get the raid alert.
- [ ] Death drops a supply bag with your resources and keeps your gear; another player can loot it.

### Combat, wildlife, loot
- [ ] Spear/sword/axe/fists hit enemies, not teammates. Bow draw → release with the charge bar; arrows arc and hit. Guns hit-scan; ammo is consumed. The shield blocks frontal hits.
- [ ] Armor reduces damage and wears out.
- [ ] At night: wolves (lunge with a "!" warning), bears (roar → charge / swipe), bats (swoop) spawn away from players and never enter fire light. Leather drops on night kills. Animals leave at dawn.
- [ ] Free care package each dawn, with a map marker. Opening takes 4 s and damage interrupts it. 3 items spill onto the ground.
- [ ] A paid care package (DEV simulated) bought at night queues for dawn; several buys drop spaced out.
- [ ] Crates open in 1.5 s and disappear; new ones appear at dawn in different spots.
- [ ] A bandage heals 45 over 3 s and damage interrupts it. Standing at your fire heals slowly.

### Powerups & persistence
- [ ] Buy/equip each powerup with diamonds (Studio starts with 300 ◆; DEV +100). Equip is only possible in the lobby.
- [ ] Every ability works and shows a cooldown: Burst trail and speed; Sniff Out pillars; Track highlights (night); Scramble over a wall; Thrifty Repair free swings; Mark highlight after an arrow hit.
- [ ] Challenge progress bars advance (DEV "Complete challenges" enables upgrades).
- [ ] With `SaveInStudio = true` and API access on: diamonds, owned levels and the equipped powerup survive a rejoin.

### Mobile & UI
- [ ] Studio device emulator: iPhone SE (small), a modern phone (landscape), iPad, 1080p PC. Touch buttons are reachable and nothing overlaps the jump button. Panels fit and scroll. Prompt cards are tappable (hold for Pour).
- [ ] The bow on touch: hold ATTACK to draw, release to fire; aim assist nudges.

## 3. Live-server tests (need a published place and ≥ 8 accounts)

- [ ] 8 players (4 solo + 2 duos): 4 non-empty teams, parties together.
- [ ] 16 players: 4 × 4.
- [ ] A queue of 4+4 only (2 parties) keeps searching until more players queue.
- [ ] A player leaving during the teleport: the match rebalances or counts the team as abandoned.
- [ ] Purchase every product with real Robux (test account). Kill the server mid-purchase and rejoin: the purchase is granted exactly once.
- [ ] Buy a revive for a teammate who is eliminated before the receipt arrives → a Revive Credit appears in the shop.
- [ ] A player who leaves before the win doesn't get 10 ◆; eliminated players who stay do.
- [ ] Every player leaves a match: the server shuts down cleanly.
- [ ] Performance: 16 players, bases built, night wildlife, 3+ packages. Watch server heartbeat (≥ 55 Hz) and mobile FPS.
- [ ] Exploit smoke tests: remote spam gets rate-limited (see `Config.RateLimits`); `Attack` with a forged direction can't hit through walls beyond melee reach; `PlaceStructure` outside the zone is rejected; `StorageAction` from 50 studs away is rejected; `RequestRevive` for an enemy is rejected.
