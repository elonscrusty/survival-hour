# Design Decisions (defaults chosen where the brief was open)

Anything **not** listed here is a fixed requirement from the brief. Tunable numbers live in
`src/shared/Config.luau` and the data modules (`Items`, `Recipes`, `Powerups`, `Loot`, `Products`).

## Places & servers
| # | Decision | Why |
|---|----------|-----|
| D1 | **One place file serves as both lobby and match.** A reserved server (`PrivateServerId ~= ""` and `PrivateServerOwnerId == 0`) runs in match mode. Any other server runs in lobby mode. | One publish and one place ID. Reserved servers can't be joined by strangers, so late joiners can't enter a match. |
| D2 | **Studio local mode:** in Studio the lobby server hosts the match in-process on a separate map area. The minimum player count and empty-team rules are relaxed by `Config.Dev`. | Lets you test the whole loop with Play Solo or a 2–8 player local test server. |
| D3 | The match manifest (players → teams) is written to a MemoryStore hash map keyed by the reserved server's `PrivateServerId`. Teleport data is not trusted. | Clients can forge teleport data. |
| D4 | Players who arrive but aren't in the manifest are sent back to the lobby. After a 60 s arrival timeout the match starts with whoever arrived. If a team ends up empty, it counts as abandoned, the same as a disconnect. If fewer than 2 teams have players, everyone goes back to the lobby to queue again. Teleport data is client-forgeable, so no queue priority is granted from it. | A disconnect during teleport is the same situation as a leaver, and the match can't get stuck. |

## Lives & deaths
| # | Decision |
|---|----------|
| D5 | **Every death while your fire burns uses one free respawn.** This covers player, animal, spike, fall and reset deaths, day or night. The brief's two named cases are included, and resetting or suiciding can never be used for a free teleport home. |
| D6 | Out of free respawns → a **20 s revive window** (`Config.Lives.ReviveWindow`). Revive prompts can only be opened during the window. When it ends, the player is eliminated whether or not a prompt is still open. |
| D7 | Only one revive purchase can be in flight for a given player (a 30 s lock). Teammates see "X is reviving you". |
| D8 | **Deferred credit:** if a revive receipt arrives when it can't be used (target eliminated, fire out, match over, payer left), the payer gets a *Revive Credit* of that price tier, stored in their profile. A credit of the needed tier or higher is spent automatically before any prompt is shown. The same approach applies to bandages and care packages bought outside a usable moment. |
| D9 | Revive tiers: 1st paid revive = tier 1, 2nd = tier 2, 3rd = tier 3, 4th and later = tier 4. Each tier is its own developer product. Suggested prices (R$): 25 / 50 / 100 / 150. |
| D10 | When regional pricing is on, a teammate revive counts as a gift. The server allows it only if the payer's price level ≥ the receiver's (`GetUsersPriceLevelsAsync`, checked at join and never cached across sessions). This can be switched off in config if regional pricing is disabled. |

## Inventory
| # | Decision |
|---|----------|
| D11 | Slots: Weapon 1, Weapon 2, Tool, Utility. **Armor is worn** and doesn't use a hand slot. **Bandages** go in a pouch (max 3). **Ammo** goes in a pouch (arrows 30, bullets 24). |
| D12 | Resource pack: **30 units total**, every resource weighs 1. No per-type caps beyond that. |
| D13 | Picking up equipment into a full slot swaps it: the held item is dropped where the new one was. |
| D14 | On death, all carried resources drop as one **Supply Bag** that anyone can loot. Equipment, ammo and bandages are kept. Bags despawn after 180 s. |

## Building, storage & raids
| # | Decision |
|---|----------|
| D15 | Build radius 55 studs from the fire. No building within 9 studs of the fire, 7 studs of the workbench front, or 6 studs of a spawn pad. Per-team limits: 40 walls+gates, 12 spikes, 2 watchtowers, 2 storage boxes. |
| D16 | Structures (walls, gates, towers, storage, the workbench structure itself is indestructible) take damage from enemy weapons only. Friendly fire is off for structures too. |
| D17 | Construction and workbench upgrades draw from the builder's pack first, then from the team's shared storage. Personal crafts (equipment) use only the crafter's pack. |
| D18 | Theft: choose a resource type, hold 3 s, take up to 10 units (limited by your free pack space). |
| D19 | **Pour exclusivity:** only one attacker can pour on a given fire at a time. Others see "Another raider is pouring". Progress resets on interruption. Several attackers can't speed up a pour. |
| D20 | A canteen holds one pour. Refilling happens at any stream (free, 1 s). |

## Map
| # | Decision |
|---|----------|
| D21 | 1000 × 1000 stud forest. Camps are fixed at N/E/S/W, 400 studs from the central clearing (≈25 s straight-line run at 16 studs/s, ≈30 s on the winding paths). |
| D22 | Each match picks a seed. One quarter sector (the forest around camp 1) is generated: route variant, ring-path radius, 2–3 feature modules (glade, rock outcrop, ruins, pond, thicket, fallen giant), resource nodes, crate spots, trees, rocks and brush. It is then **rotated 90°/180°/270°** for the other camps, so every clan gets exactly the same map while every match is different. A shallow ring creek surrounds the central stone circle and every camp has its own creek. A 4-stud flood-fill validates reachability, and the next seed is tried if validation fails. |
| D23 | Resource nodes and forest crates are distributed evenly per sector. |
| D24 | An enemy camp is revealed to your whole team when any teammate comes within 80 studs of that camp's fire. |

## Loot & monetisation
| # | Decision |
|---|----------|
| D25 | The free care package drops 20–40 s after each dawn at a validated drop point. |
| D26 | **Paid packages bought at night are queued for the next dawn.** The shop says this before purchase. Queued drops leave one at a time, 25 s apart, and never share a landing point. |
| D27 | Paid care packages count as **paid random items** under Roblox policy. The shop shows the full odds table before purchase. Players whose `PolicyService` data says `ArePaidRandomItemsRestricted` can't buy them; they still get the free daily package. |
| D28 | Permanent powerup unlocks and upgrade skips are **developer products** whose grants go into our DataStore. We don't use game passes, so all ownership lives in one place and diamonds and Robux follow the same path. |
| D29 | Robux can't buy match resources or match equipment, apart from bandages and care packages. |

## Powerups (values in TUNING.md)
| # | Decision |
|---|----------|
| D30 | Upgrade diamond prices: L2 = 0.8 × unlock price, L3 = 1.5 × unlock price. |
| D31 | Challenge progress is tracked for every **owned** powerup, not just the equipped one. Per-match caps and per-target limits stop farming. |
| D32 | Challenges need a real match (production only; Studio progress isn't saved unless `Config.Dev.SaveInStudio`). |

## Art, audio, animation fallbacks (honest)
| # | Decision |
|---|----------|
| D33 | Every model is **built procedurally from Roblox primitives and materials** by `ModelFactory`. There are no uploaded meshes. |
| D34 | Animations are **procedural** (Motor6D offsets driven by replicated action attributes, plus leg cycles for wildlife rigs). There are no uploaded KeyframeSequences. |
| D35 | Audio uses Roblox's engine-bundled `rbxasset://sounds/*` files where they fit. All other cues are listed in `Sounds.luau` with an empty asset ID for you to fill with licensed Creator Store audio. Silence is the fallback; we never use a made-up ID. |
| D36 | Icons are drawn in UI from primitives: a shaped badge, a colour and a glyph. |
