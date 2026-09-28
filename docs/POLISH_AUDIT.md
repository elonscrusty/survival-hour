# Survival Hour — Final Polish Audit

Audit of the whole project before the publish-ready polish pass (2026-09-28).
Categories follow the polish brief. **Fixed** = changed in this pass.
Nothing has been run in Roblox Studio yet: the Studio connection failed to start in this session. Everything below
comes from reading the code plus the automated checks: 136 logic tests, 34 model/lobby mock checks, the Roblox-API
type check and the Rojo build.

## WORKING
- Match loop: solo camps, 2 min day / 2 min night, snuffing from Night 3, sunrise protection, respawns while the fire
  burns, Final Life, elimination, placements, return to lobby (MatchService, LivesService, FireRules tests).
- Economy and progression match the spec: XP curve, Coins, Diamonds (a win gives exactly 2), class and power-up prices,
  cosmetic price bands, daily and weekly bonuses. Only Coin packs and cosmetic bundles are sold, so there's no pay-to-win
  (ProfileRules, Progression and Cosmetics tests).
- Persistence: session-locked profiles. A failed load disables saving (no blank overwrite). Receipts are idempotent
  and only acknowledged after a successful save. Schema v2 refunds the old powerups once (DataService, ProfileRules tests).
- Remotes: every client→server remote goes through `Util.Connect`, which is rate-limited per bucket and runs the
  handler in a pcall. Handlers type-check their payloads. Damage, yields, loot, crafting, storage, purchases, fire
  state and elimination are all decided on the server. Dev commands are Studio-only.
- Inventory, crafting (Tiers I–V), building (camp radius, stream clearance, no-build zones), storage breaching,
  traps, wildlife roles and night escalation, armour, bows and crossbows with a server-side minimum draw.

## WORKING BUT NEEDS POLISH (fixed in this pass)
- **Animation coverage**: mining, crafting, building/repair, feeding the fire and breaching had no pose. Heavy and
  light swings looked identical, and there were no hit, block-impact or guard-break reactions, no equip, landing or
  sprint lean, and no exhausted breathing. **Fixed**: `Controllers/Animation.luau` has a full procedural pass, and
  the server sends the matching action attributes (`Util.SetAction`, `HitAt`, `BlockHitAt`, `ActionHeavy`,
  `ActionVariant`).
- **Movement feel**: speed changes were instant. **Fixed**: sprint builds up over about 0.5 s and stopping is quicker;
  traps still stop you instantly.
- **Camera**: only the aim zoom changed the field of view. **Fixed**: a single eased FOV target (aim, a slight
  widen while sprinting, a brief damage punch), a tiny damage roll, and a drained/reddish screen tint when
  exhausted or badly hurt. There is no shake loop.
- **Campfire states**: only a text warning below 15% fuel. **Fixed**: an HUD fuel bar (orange → amber → pulsing red),
  a "LOW FUEL" / "CRITICAL!" label, a "YOUR FIRE IS DYING" banner below 5%, a starving deep-red flame (campfire
  cosmetics are left alone), and a spark flare when wood is added.
- **Day presentation**: **Fixed**: an afternoon step was added (dawn → day → afternoon → sunset → moonlit night).
  The timings are unchanged.
- **UI motion**: **Fixed**: panels pop in (0.14 s), buttons squash when pressed, notifications pop in and fade
  out, and currency counts up or down with a green/red flash.
- **Lobby profile**: was a single text line. **Fixed**: a profile card with level badge, name, loadout and XP bar,
  plus Coins and Diamonds pills.

## PARTIAL
- **Onboarding**: before this pass there was only a static how-to-play page. **Added**: a Survival Guide objective
  tracker for new accounts, driven by real state: gather → craft axe → chop → feed fire → Workbench II → build.
  There are also one-off contextual tips for the first night, Night 3 exposure, first death and Final Life.
- **Audio**: engine-bundled cues are used; licensed ambience, crackle and surface footsteps are still empty (silent)
  slots in `Sounds.luau`. Picking licensed audio needs the owner's account.
- **Animations** are procedural joint offsets, not authored KeyframeSequences, and haven't been checked visually in
  Studio. Remote players' bow draw is not shown (only the release).
- **Wildlife**: behaviour roles, stuck detection (jump, sidestep, give up and despawn) and night pressure all exist.
  The creature animation is procedural and needs a visual check.

## BROKEN (fixed in this pass)
- **Harvest and pour effects never showed.** The server fired `ResourceHit`, `ResourceBreak` and `PourStart`, but
  the client had no handler. **Fixed** with pooled emitters (no parts created per hit): bark and wood chips thrown
  back toward the swinger, stone fragments with sparks and dust, leaves, berries, spores, water and steam.
  Rocks, bushes and ore now jolt when struck.
- **Mining played the "gather" (hands) pose** because the channel sent `Gather` for pickaxe nodes. **Fixed**: it
  now sends `Mine`. Storage breaching now sends `Breach` (a heavy overhead) instead of `Chop`.

## MISSING (needs the owner or Studio)
- **Robux product IDs**: `Products.luau` IDs are 0 until the six products are created in Creator Hub. The
  experience has to be published first.
- **A Studio playtest of the full loop**, plus visual checks of meshes, poses, the lobby terrain and mobile layouts
  on real devices.
- **Licensed audio IDs.**

## PERFORMANCE RISK
- Effects now reuse one emitter per effect kind instead of creating a part per hit (fixed).
- Per-frame work is limited to one render step each for camera, animation and effects. Animation only runs for
  characters within 150 studs.
- The model loader runs in the background and never blocks server start.
- The lobby is a single Persistent model (small), and the match uses StreamingEnabled with Atomic models.
- Watch in Studio: decoration density on low-end mobile, and how many PointLights are active at night (lobby
  lanterns, fires).

## SECURITY / EXPLOIT RISK
- No client-authoritative gameplay values were found. Attack payloads only carry an aim direction, a heavy flag
  and a bow charge. The server clamps the charge to the elapsed draw time, and enforces cooldowns and a heavy
  wind-up.
- Placement is validated server-side (type checks, camp radius, collision, no-build zones, stream clearance).
- Purchases are only granted from `ProcessReceipt`. Lobby shop actions are validated against the profile.
- Remaining exposure: rate limits are per bucket. Keep an eye on `Interact` spam in live analytics.

## Priority used
Gameplay feel → reliability → visual polish → animation → audio → UI/UX → optimisation. See
`docs/IMPLEMENTATION_LOG.md` ("Final polish pass") for the change list.
