# Mythic Hatchery: Studio playtest

Open the supplied `MythicHatchery_Revised.rbxlx` on a PC in Roblox Studio. Keep Output open.
The game builds its world and models at runtime. Source changes rebuild with `bash tools/check.sh`;
Rojo live development uses `bash tools/serve.sh`, which stages Roblox-compatible module requires.

## First session and phone layout
- Start Play. Confirm no red Output errors; six continuous regions, eight habitat plots and the arena appear.
- New data: 250 coins, one level1 Common Nature Dragon with Ride/Fly; no repeated starter on rejoin.
- Use Device Emulator for a narrow portrait phone and a landscape phone. Buttons remain readable/tappable.
- Confirm the world is visible on entry and the objective guides you to the egg stand. Open and close each dock menu.
- Ride and fly the starter; move, ascend, descend, stop, land, dismount and respawn.
- Buy two Meadow eggs at its stand, incubate them and wait or Studio-test gems to skip. All three odds tables
  show before buying, including the objective shortcut. Incubate from the bag action. Hatch reveals show the new creature and close with Keep Creature or X. Hatch two more creatures and select a team of three.

## Habitats and saving
- Assign a creature to a slot. Coins accumulate and cap; tap collect. Upgrade raises rate/cap, unlock adds a slot.
- Assigned creatures cannot battle, ride, fuse, trade or start expeditions. Remove restores availability.
- Rejoin after offline time. Income respects cap; active Coins boost expires correctly during offline time.
- Test VIP/rebirth/Coins boosts and Neon income bonuses; buying a boost does not retroactively multiply old coins.
- Studio-test HatchSlots pass, incubate slots4/5, save/rejoin; eggs/timers remain and both slots are shown.
- Studio saves use a separate store. Test persistence with API access enabled and offline fallback disabled.

## Multiplayer battle
Use Studio's server test with at least two clients, giving each three similarly strong available creatures.
- Queue voluntarily; mismatched teams wait. Commands and swaps work only for the owner's active team.
- Species/element moves, shared2s cooldown, separate8s swaps, automatic replacement after knockout.
- Level up: two initial moves, then more unlocked moves; every unlocked move stays accessible.
- Useful contribution controls XP; creatures that never enter receive none. No habitat/expedition XP.
- Win/loss/draw, immediate recovery, point changes, timeout, disconnect/forfeit and reward dedupe.
- Repeated opponents and idle forfeits do not farm positive rewards. Test two simultaneous matches and cameras.
- On portrait phone, creatures remain visible above battle commands. Queue and close the menu; commands reopen when matched. Check attack, guard, heal, swap and final knockout effects. Results retain the arena briefly; camera restores when the battle ends.

## World and retained systems
- World prompts open eggs/hatchery/fusion/shop/arena menus. Purchased gates let walkers AND server-owned mounts
  through; unowned regions return intruders, including high fliers. Teleport only reaches owned regions.
- Fusion confirmation warns both creatures/potions/cosmetics are lost. Both are consumed once; hatch fused egg.
- Potions, owned cosmetics, companion followers, lock/release, expedition start/skip/claim.
- Daily/playtime/quests/Index claim once. Hatch/fuse/battle/coin/expedition quests advance.
- Trade only creatures: changes reset ready/countdown; busy/locked creatures refused; cosmetic outfits stripped,
  Level/Xp/potions preserved. Disconnect/rejoin during settlement should resolve the journal once.
- Store Studio test buys grant correctly. Live Id0 items unavailable. Policy restrictions disable gem eggs/paid
  luck/trading as appropriate. Configure real ids before testing receipts with real purchases.

Record failures with Output errors and the steps that caused them. CLI tests and a successful Rojo build
cannot verify Roblox physics, GUI touch input, Marketplace receipts or live DataStore/replication behaviour.
