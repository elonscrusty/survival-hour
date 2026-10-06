# Mythic Hatchery status

Updated October 6, 2026. The approved battle/habitat conversion is connected across shared logic,
saved profiles, server services, phone UI and primitive world/creature models. The place builds for Studio.

## Implemented
- Independent hatch rolls, incubation seed/luck snapshots, paid hatch slots, skips and fused eggs.
- Battle-only levels/XP, species/element moves, real-time commands, teams3/oneactive, shared move cooldown,
  separate swaps, strength matching, useful participation rewards, points, forfeit/timeout and dedupe.
- Online/offline habitat income with storage caps, manual collection, slot upgrades/unlocks, busy rules,
  prospective permanent multipliers and temporary boost expiry.
- Persisted ride/fly starter; server-owned mounted movement with validated input, altitude/speed guards.
- Fusion, potions, cosmetics, companion followers, eleven creature silhouettes and five element palettes.
- Connected six-region world, natural gate barriers, eight habitat plots and separate simultaneous matches.
- Phone menus and compact battle controls; odds, teams, habitats, riding/flying, fusion, shops, rewards,
  Index, expeditions, purchases and creature-only trades.
- Existing session locking, retry/backoff, receipt dedupe, autosave/close save and journaled atomic trades.
- Studio tools and zero-id simulated purchases; policy restrictions on gem eggs/paid luck/trading.

## Visual and onboarding repair
- Rebuilt the eleven creature silhouettes with expressive faces, shaped wings and five restrained element palettes.
- Replaced tall rectangular hub walls with natural ridges, garden plots, a roofed hatchery and visible arena.
- World visible on entry; a single objective guides egg buying, incubation, habitat assignment and collection.
- Creature viewport cards, hatch reveals, and validated attack/guard/heal/swap presentation.
- Portrait battles retain visible creatures above commands; all egg odds precede purchasing.
- `models/preview.py` and `models/ui_preview.py` generate geometry and layout previews; these are not Studio screenshots.

## Validation and review
The current check suite runs strict Luau analysis, 135 Luau tests, two Python build-transform tests,
Rojo build and place-source verification. Reviews found and corrected slot-key/save bugs, paid-slot loss,
gate collision with server-owned mounts, quest wiring, cosmetics transfer, boost expiry, Neon income,
concurrent battle cameras and inaccessible retained menus. Generated data uses explicit strict table types.

No Roblox Studio playtest has been performed here. Physics, touch layout, multiplayer replication,
live DataStore failure recovery and Marketplace receipt behaviour still require the checklist in STUDIO_TESTS.md.
A successful build and CLI tests establish static/unit validation, not a released or playtested game.

## Provisional settings
Gameplay.luau: levelcap50, move cooldown2s, swap cooldown8s, prices/rates/rewards/matchratio awaiting balance.
Fused hatchlings start at level1, no minimum fusion level. Product ids remain0. Map has eight plots;
configure maximumplayers8 for the current map. The legacy MoreEquip pass adds followers, never a fourth PvP fighter.
Growth2x/BoostGrowth save keys mean2xBattleXP. AutoFarm/RingChampion are removed from the unconfigured catalogue.

## Development
Run `bash tools/check.sh --quick` while editing and `bash tools/check.sh` to generate
`build/MythicHatchery.rbxlx`. `bash tools/serve.sh` serves the staged Roblox project.
Pure source relative requires support CLI tests; runtime staging converts these to ModuleScript Instance requires.
Read CONTRACTS.md for current behaviour; older architecture handoffs are marked historical.
