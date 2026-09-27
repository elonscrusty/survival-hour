# Tuning Reference

All values are **initial defaults** that still need live playtesting. Where they live:

| What | File |
|------|------|
| Match timing, lives, build zone, storage, gather, wildlife, loot timing, camera, rate limits, lighting | `src/shared/Config.luau` |
| Items and weapon stats | `src/shared/Items.luau` |
| Recipes, workbench upgrades, repair | `src/shared/Recipes.luau` |
| Powerups, levels, challenges, prices | `src/shared/Powerups.luau` |
| Loot tables | `src/shared/Loot.luau` |
| Robux products | `src/shared/Products.luau` |
| Wildlife species stats | `src/server/Services/WildlifeService.luau` (`WildlifeService.Species`) |

The recipe, loot, powerup and product tables below are generated from the code by `tools/gen_tuning.luau`, so they match the modules exactly.

## Match & lives

| Setting | Value |
|---------|-------|
| Teams / max per team / max players / min players | 4 / 4 / 16 / 8 |
| Day / night length | 120 s / 120 s, repeating with no time limit |
| Intro countdown | 12 s (no damage) |
| Free respawns | 3, with a 5 s delay |
| Revive window after the last free respawn | 20 s (purchase lock 30 s) |
| Revive tiers | 1st / 2nd / 3rd / 4th+ paid revive → products `Revive1..4` |
| Spawn protection | 3 s |
| Win reward | 10 ◆ |
| Healing at your own burning fire | +2 HP/s within 24 studs, after 5 s without damage |
| Bandage | +45 HP, 3 s use, interrupted by damage |

## Inventory

| Setting | Value |
|---------|-------|
| Resource pack | 30 units in total (every resource weighs 1) |
| Slots | Weapon ×2, Tool ×1, Utility ×1, worn Armor |
| Bandage pouch | 3 |
| Ammo pouch | 30 arrows, 24 bullets |
| Dropped items / supply bags despawn | 180 s |

## Weapons & tools

| Item | Damage | Cooldown | Range | Durability | vs structures | Notes |
|------|--------|----------|-------|------------|---------------|-------|
| Fists | 8 | 0.6 s | 5.5 | ∞ | ×0.25 | always available |
| Spear | 22 | 0.9 s | 9.5 | 90 hits | ×0.6 | ×1.15 vs animals |
| Sword | 32 | 0.75 s | 7.5 | 200 | ×1.0 | |
| Shield | 6 (bash) | 0.8 s | 5 | absorbs 400 | ×0.2 | hold Aim to block 70% of frontal damage |
| Bow | 28 × (0.4–1.0 by draw) | 0.35 s + 0.6 s draw | ~220 | 150 shots | ×0.4 | arrows travel 105–190 studs/s with gravity |
| Flintlock Pistol | 30 | 0.5 s | 130 | 60 shots | ×0.5 | loot only, 2.2° spread |
| Hunting Rifle | 55 | 1.4 s | 260 | 30 shots | ×0.5 | loot only, 0.6° spread |
| Stone Axe | 12 | 0.7 s | 6.5 | 150 | ×2.0 | chops small trees (1 wood per chop, 3 per tree) |
| Repair Hammer | 7 | 0.8 s | 7 | 200 | ×0.3 | repairs 10% HP per swing on your clan's structures |
| Leather Armor | — | — | — | absorbs 300 | — | worn; −25% incoming damage |

Melee reach gets an extra 3-stud allowance for latency. Every hit is found by the server from server-side positions.

## Structures

| Structure | HP | Footprint (studs) | Clan limit |
|-----------|----|-------------------|------------|
| Wooden Wall | 250 | 10 × 9 × 1.6 | 40 (shared with gates and reinforced walls) |
| Gate (clan-only door) | 300 | 10 × 9 × 1.6 | shared with walls |
| Reinforced Wall | 700 | 10 × 10 × 2.4 | shared with walls |
| Spikes (15 dmg/s to enemies) | 120 | 8 × 3 × 3 | 12 |
| Watchtower | 500 | 8 × 16 × 8 | 2 |
| Storage Box (200 units) | 400 | 6 × 4 × 4 | 2 |

Build zone: 55 studs around your fire. Clearances: 9 studs around the fire, 7 in front of the workbench, 6 around each spawn pad. Max placement distance from you: 28 studs.

## Wildlife (night only)

| Species | HP | Damage | Speed | Attack tell | Leather |
|---------|----|--------|-------|-------------|---------|
| Wolf (packs of 2–3) | 60 | 12 | 21 | 0.45 s crouch, then lunge | 1 |
| Bear | 220 | 30 | 13 (charges at 25) | 0.8 s roar, then charge; 0.5 s raised-paw swipe | 3 |
| Bat (swarms of 3–4) | 25 | 6 | 24 (flying) | 0.35 s screech, then swoop | 1 |

At most 14 animals at once (7 wolves, 3 bears, 8 bats). They spawn 60–170 studs from players, never inside burning-fire light (45 studs), leave at dawn, and despawn beyond 260 studs from every player.

## Raids & interactions

| Interaction | Time | Range | Interrupted by |
|-------------|------|-------|----------------|
| Pour water (hold) | 10 s | 12 | damage, release, leaving range, dawn, fire already out; one raider per fire |
| Steal from storage | 3 s | 10 | damage, leaving range (takes up to 10 units) |
| Open care package | 4 s | 10 | damage, leaving range |
| Open forest crate | 1.5 s | 8 | damage, leaving range |
| Hand gather | 0.9 s ÷ Scavenger bonus | 11 | damage |
| Fill canteen | 1 s | 8 | leaving range |

Crates: 3 per sector + 3 in the centre, restocked each dawn at different spots. Care packages: free one 20–40 s after each dawn; paid calls queue and drop at least 25 s apart.

### Recipes

| # | Recipe | Result | Workbench | Kind | Cost |
|---|--------|--------|-----------|------|------|
| 0 | Rope | Rope | anywhere | Resource | 3 Plant |
| 1 | StoneAxe | StoneAxe | Lv 1 | Equipment | 1 Stick, 1 Stone |
| 2 | StorageBox | StorageBox | Lv 1 | Structure | 2 Stone, 10 Wood |
| 3 | WoodWall | WoodWall | Lv 1 | Structure | 4 Wood |
| 4 | Spear | Spear | Lv 1 | Equipment | 3 Stick, 2 Stone |
| 5 | RepairHammer | RepairHammer | Lv 1 | Equipment | 2 Stone, 2 Wood |
| 6 | Canteen | Canteen | Lv 2 | Equipment | 2 Leather, 1 Rope |
| 7 | Bow | Bow | Lv 2 | Equipment | 2 Rope, 3 Wood |
| 8 | Arrows | Arrow ×6 | Lv 2 | Ammo | 2 Stick, 1 Stone |
| 9 | Gate | Gate | Lv 2 | Structure | 1 Rope, 6 Wood |
| 10 | Spikes | Spikes | Lv 2 | Structure | 2 Stick, 3 Wood |
| 11 | Armor | Armor | Lv 3 | Equipment | 4 Leather, 2 Rope, 3 Stone |
| 12 | Sword | Sword | Lv 3 | Equipment | 1 Leather, 6 Stone, 2 Wood |
| 13 | ReinforcedWall | ReinforcedWall | Lv 3 | Structure | 6 Stone, 4 Wood |
| 14 | Watchtower | Watchtower | Lv 3 | Structure | 4 Rope, 4 Stone, 12 Wood |
| 15 | Shield | Shield | Lv 3 | Equipment | 2 Leather, 1 Rope, 5 Wood |

### Workbench upgrades (shared by the clan; pack first, then team storage)

| To level | Cost |
|----------|------|
| 2 | 3 Leather, 4 Rope, 15 Stone, 20 Wood |
| 3 | 6 Leather, 8 Rope, 30 Stone, 40 Wood |

Repair: each hammer swing restores 10% of max HP and costs 1 Wood (wooden structures) or 1 Stone (reinforced wall).

### Care package odds (each of the 3 entries rolled independently)

| Entry | Contents | Chance |
|-------|----------|--------|
| Pistol | Flintlock Pistol + 12 bullets | 8.0% |
| Rifle | Hunting Rifle + 6 bullets | 4.0% |
| Sword | Sword | 8.0% |
| Bow | Bow + 6 arrows | 10.0% |
| Arrows | 12 arrows | 14.0% |
| Bullets | 12 bullets | 8.0% |
| Bandages | 2 bandages | 18.0% |
| Armor | Leather Armor | 6.0% |
| Shield | Shield | 6.0% |
| Leather | 3 leather | 8.0% |
| Rope | 3 rope | 10.0% |

Chance a package contains at least one gun: 31.9%.

### Forest crate odds (one roll)

| Entry | Contents | Chance |
|-------|----------|--------|
| Bandage | 1 bandage | 35.0% |
| Arrows | 6 arrows | 25.0% |
| Bundle | 3 sticks, 3 stone, 3 wood | 20.0% |
| Rope | 2 rope | 12.0% |
| Bullets | 6 bullets | 8.0% |

### Powerups

| Powerup | Unlock ◆ | L2 ◆ | L3 ◆ | L2 challenge | L3 challenge | Per-match cap |
|---------|---------|------|------|--------------|--------------|---------------|
| Trailblazer | 100 | 80 | 150 | Travel 8,000 studs in matches | Travel 30,000 studs in matches | 2500 |
| Craftsman | 125 | 100 | 188 | Repair 3,000 structure HP of enemy damage | Repair 12,000 structure HP of enemy damage | 1500 |
| Hunter | 150 | 120 | 225 | Kill 20 animals at night | Kill 75 animals at night | 15 |
| Scavenger | 175 | 140 | 263 | Open 15 forest crates | Open 50 forest crates | 8 |
| Climber | 200 | 160 | 300 | Scramble over 10 different enemy walls | Scramble over 40 different enemy walls | 6 |
| Sharpshooter | 250 | 200 | 375 | Land 25 arrow hits on enemies from 40+ studs | Land 100 arrow hits on enemies from 40+ studs | 20 |

**Trailblazer** (Burst)

| Level | Passive | Ability |
|-------|---------|---------|
| 1 | +4% move speed | Burst: +35% speed for 2.5s and ignore brush slowdown. Cooldown 30s. |
| 2 | +6% move speed | Burst: +35% speed for 3s and ignore brush slowdown. Cooldown 26s. |
| 3 | +8% move speed | Burst: +40% speed for 3.5s and ignore brush slowdown. Cooldown 22s. |

**Craftsman** (Thrifty Repair)

| Level | Passive | Ability |
|-------|---------|---------|
| 1 | +15% repair speed | Thrifty Repair: your next 4 repair swings within 20s cost no resources. Cooldown 90s. |
| 2 | +25% repair speed | Thrifty Repair: your next 5 repair swings within 20s cost no resources. Cooldown 75s. |
| 3 | +35% repair speed | Thrifty Repair: your next 6 repair swings within 20s cost no resources. Cooldown 60s. |

**Hunter** (Track)

| Level | Passive | Ability |
|-------|---------|---------|
| 1 | +10% damage to animals | Track: at night, highlight animals within 80 studs for 8s. Cooldown 40s. |
| 2 | +15% damage to animals | Track: at night, highlight animals within 110 studs for 8s. Cooldown 35s. |
| 3 | +20% damage to animals | Track: at night, highlight animals within 140 studs for 10s. Cooldown 30s. |

**Scavenger** (Sniff Out)

| Level | Passive | Ability |
|-------|---------|---------|
| 1 | +10% gathering speed | Sniff Out: reveal unmarked crates within 60 studs for 8s. Cooldown 45s. |
| 2 | +15% gathering speed | Sniff Out: reveal unmarked crates within 80 studs for 8s. Cooldown 40s. |
| 3 | +20% gathering speed | Sniff Out: reveal unmarked crates within 100 studs for 10s. Cooldown 35s. |

**Climber** (Scramble)

| Level | Passive | Ability |
|-------|---------|---------|
| 1 | +15% climbing speed | Scramble: vault over a wall up to 11 studs tall in front of you. Cooldown 45s. |
| 2 | +25% climbing speed | Scramble: vault over a wall up to 11 studs tall in front of you. Cooldown 38s. |
| 3 | +35% climbing speed | Scramble: vault over a wall up to 12 studs tall in front of you. Cooldown 30s. |

**Sharpshooter** (Mark)

| Level | Passive | Ability |
|-------|---------|---------|
| 1 | -15% bow spread, 5% faster draw | Mark: an arrow hit on an enemy reveals them to your team for 3s. Internal cooldown 20s. |
| 2 | -25% bow spread, 8% faster draw | Mark: an arrow hit on an enemy reveals them to your team for 4s. Internal cooldown 16s. |
| 3 | -35% bow spread, 10% faster draw | Mark: an arrow hit on an enemy reveals them to your team for 5s. Internal cooldown 12s. |

### Developer products (create these in Creator Hub)

| Key | Kind | Suggested price (R$) | Grants |
|-----|------|----------------------|--------|
| `Bandage` | Bandage | 15 | 1 bandage |
| `CarePackage` | CarePackage | 75 | one public care package call |
| `Diamonds100` | Diamonds | 99 | 100 diamonds |
| `Diamonds300` | Diamonds | 279 | 300 diamonds |
| `Diamonds800` | Diamonds | 699 | 800 diamonds |
| `Revive1` | Revive | 25 | revive at tier 1 |
| `Revive2` | Revive | 50 | revive at tier 2 |
| `Revive3` | Revive | 100 | revive at tier 3 |
| `Revive4` | Revive | 150 | revive at tier 4 |
| `Unlock_Climber` | Unlock | 179 | permanent Climber unlock |
| `Unlock_Craftsman` | Unlock | 119 | permanent Craftsman unlock |
| `Unlock_Hunter` | Unlock | 139 | permanent Hunter unlock |
| `Unlock_Scavenger` | Unlock | 159 | permanent Scavenger unlock |
| `Unlock_Sharpshooter` | Unlock | 219 | permanent Sharpshooter unlock |
| `Unlock_Trailblazer` | Unlock | 99 | permanent Trailblazer unlock |
| `Upgrade_Climber_2` | Upgrade | 149 | Climber level 2 (skips challenge) |
| `Upgrade_Climber_3` | Upgrade | 279 | Climber level 3 (skips challenge) |
| `Upgrade_Craftsman_2` | Upgrade | 99 | Craftsman level 2 (skips challenge) |
| `Upgrade_Craftsman_3` | Upgrade | 179 | Craftsman level 3 (skips challenge) |
| `Upgrade_Hunter_2` | Upgrade | 109 | Hunter level 2 (skips challenge) |
| `Upgrade_Hunter_3` | Upgrade | 199 | Hunter level 3 (skips challenge) |
| `Upgrade_Scavenger_2` | Upgrade | 129 | Scavenger level 2 (skips challenge) |
| `Upgrade_Scavenger_3` | Upgrade | 239 | Scavenger level 3 (skips challenge) |
| `Upgrade_Sharpshooter_2` | Upgrade | 179 | Sharpshooter level 2 (skips challenge) |
| `Upgrade_Sharpshooter_3` | Upgrade | 329 | Sharpshooter level 3 (skips challenge) |
| `Upgrade_Trailblazer_2` | Upgrade | 79 | Trailblazer level 2 (skips challenge) |
| `Upgrade_Trailblazer_3` | Upgrade | 149 | Trailblazer level 3 (skips challenge) |

