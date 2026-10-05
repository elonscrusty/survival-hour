# Studio playtest checklist

Open `build/PetRaceLeague.rbxlx`, set Avatar to R15, and turn on API access (Game Settings → Security). Tick each box as you go. If something fails, write down what you saw.

## 1. Spawn (solo Play)
- [ ] Tutorial cards show. "Let's go!" closes them, and they don't come back after you rejoin.
- [ ] You're riding a brown Pup. Your feet are on its back and it isn't sunk into the ground.
- [ ] Coins show 250. Trophies show 0. League shows Bronze.
- [ ] RIDE/WALK switches: walking makes the Pup follow next to you; riding puts you back on it.
- [ ] DASH (or Shift) gives a short speed burst. The dot under DASH empties, then refills after about 6 seconds.

## 2. Eggs
- [ ] Each egg has an odds board above it.
- [ ] Hold E on the Meadow Egg: the egg wobbles, flashes, and a spinning pet appears with its rarity. Coins go down by 100.
- [ ] "Ride it!" swaps you onto the new pet. "Again" hatches another egg.
- [ ] With fewer coins than the price, you get a red "You need X more coins" message.

## 3. Training (while riding)
- [ ] Speed Ring: ride through gate 1, 2, 3... "+5 Speed" pops up, and a full lap gives "Lap bonus!".
- [ ] Hurdles: jumping a wall gives Jump XP. The 2 to 4 stud walls are easy with a new pet.
- [ ] Treadmill: the belt pushes you back. Running on it gives Stamina XP about every 1.5 seconds.
- [ ] A level-up shows "Speed level 2!" and the PETS menu bars move.

## 4. Pets menu
- [ ] Cards show 3D pets with rarity-coloured borders, and the ridden pet says RIDING.
- [ ] Tap another pet, then Ride: you swap pets.
- [ ] Release asks "Sure? +5", then removes the pet and adds the coins. You can't release the pet you're riding.
- [ ] Type a nickname, tap Name: the card shows the new name.

## 5. Race (solo first, then Test → 2-3 players)
- [ ] Stand on the pink portal pad: the banner says "Race starts in 20...". Step off and it disappears.
- [ ] At 0 you're teleported to the track, frozen, then 3, 2, 1, GO!
- [ ] The top panel shows your place, timer, progress bar and medal times.
- [ ] Boost pads (yellow) make you faster and mud (brown) slows you.
- [ ] Falling in a gap shows "Oops!" and puts you back on the track just after the last checkpoint.
- [ ] Crossing FINISH shows the finish message. With other players, a "seconds left" warning appears.
- [ ] The results board shows places, times, medals, and your coins and trophies. After about 6 seconds you're back in the lobby.
- [ ] Races 2 and 3 use different tracks (Canyon Leap, Sky Steps).
- [ ] "Leave race" sends you back to the lobby.
- [ ] Resetting your character mid-race puts you back on the track at your checkpoint.

## 6. Shop
- [ ] Trails tab: buy Dust Trail (150), tap Use, and a trail follows your pet.
- [ ] Paint tab: if you can afford it, Gold Paint recolours the pet.
- [ ] Robux tab says "Robux shop opens soon!" until product ids are filled in.

## 7. Saving
- [ ] Stop and Play again: coins, pets, levels, trails and trophies are all still there.
- [ ] The leaderboard board near the portal lists your name after about a minute.

## 8. Pet collision (new)
- [ ] Riding into a lobby hurdle stops you: you have to jump it. Walking along the lane gives no Jump XP.
- [ ] On the track, hurdles and steps need jumps. Ramps and mud don't snag the pet.

## 9. 3D models (after running tools/upload_models.py)
- [ ] The output says "[AssetLoader] 33 models loaded, 0 failed".
- [ ] Pets, eggs, trees, gates, the portal and the race arches show as smooth models, sitting on the ground (not floating or sunk).
- [ ] The ridden pet sits under you correctly. Gold Paint makes it solid gold.

## 10. Daily, codes and sound
- [ ] DAILY has a red dot. Opening it shows "Day 1 streak", and Claim gives 50 coins (the dot goes away).
- [ ] Three quests show progress bars. Ride 20 speed gates or finish races and the bar fills, then "+coins" claims it.
- [ ] Type LAUNCH and tap Redeem: +300 coins. Typing it again says "already used". You can type a code while riding the gates without it being wiped.
- [ ] On a phone, the DAILY menu scrolls so the code box and the Sound button can be reached.
- [ ] Buttons click, coins chime, the countdown beeps and a fall plays a sound. "Sound: OFF" silences everything and stays off after you rejoin.

## 11. Look and animation
- [ ] The lobby is bright and colourful (bloom on neon, sun rays), and pets have a dark cartoon outline.
- [ ] Riding: your character sits on the pet's back behind its head (not standing, not floating).
- [ ] Standing still: the pet breathes, blinks, looks around, wags its tail and twitches its ears.
- [ ] Running: the legs trot in diagonal pairs, the body bounces and leans forward, ears sweep back, dust puffs at the feet.
- [ ] Jumping: the legs tuck and wings spread. On landing the pet squashes down and puffs dust.
- [ ] Levelling up a stat makes your pet hop happily. Winning a race does too.
- [ ] Hatching: the new pet hops excitedly in the reveal window. The PETS menu previews idle and blink.
- [ ] Legendary/Mythic pets sparkle.
- [ ] After uploading models: if mesh pets bend the wrong way, flip the signs in `BONE_AXIS` (`src/client/Controllers/PetAnimator.luau`).
