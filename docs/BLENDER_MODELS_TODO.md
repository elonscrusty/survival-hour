# Blender models wanted (for ChatGPT)

## Rules for every model (paste this part to ChatGPT too)
### Make them smooth and "Roblox-looking" (tell ChatGPT exactly this)
- **Bevel every edge**: add a Bevel modifier (width 0.08 to 0.15 studs, 3 segments), so nothing
  has a sharp corner. Small parts get 0.03 to 0.05.
- **Shade Smooth**, with "Smooth by Angle" (auto smooth) at 30°, so the bevels look soft and
  rounded, not faceted.
- Round shapes use enough sides: cylinders 16 to 24 sides, spheres 16 × 12. Organic shapes (leaves,
  bushes, rocks, animals) get one Subdivision Surface level before applying.
- **Big, simple, chunky forms**, like a toy: slightly oversized handles, heads and details, and
  nothing thinner than 0.2 studs.
- **Flat solid colours** (one colour per part, bright but not neon), with no photo textures, noise,
  wood grain or dirt. At most a soft two-tone (a lighter top, darker underside).
- Material: plain Principled BSDF, Roughness 0.5 to 0.6, Metallic 0 (0.3 at most for metal).
- Apply all modifiers before exporting the FBX.

- Style: simple, chunky, clean Roblox low-poly (like the new trees, animals and "99 Nights in the
  Forest"), flat colours, soft bevels, readable from far away. Under ~3,000 triangles each.
- Units: 1 Blender unit = 1 Roblox stud. **Z is up. The front faces -Y.**
- Pivot / origin: **bottom centre, sitting on the ground (Z = 0)**. Exception: hand-held items
  (section A): origin **at the grip** (where the hand holds it), with the item pointing up +Z.
- **Size: match the size given (width X × height Z × depth Y) as closely as possible.** For
  "restyle" items it must be EXACT, because they replace an existing upload.
- One FBX per model, named exactly as in "Save as" (e.g. `SM_Axe_Steel.fbx`). Mesh only: no
  floors, lights, cameras or armatures. Apply all transforms before export.
- Upload: **NEW** models → new assets, then send Claude the IDs. **RESTYLE** models → upload as a
  new version of the existing asset (same ID), nothing to send.
- "Icon" is the picture Astra already made; use it as the look reference.

---

## A. Hand-held items that still borrow another model (NEW)
| Save as | What it is | Size (W × H × D) | Icon |
|---|---|---|---|
| SM_Axe_Crude | Crude axe: stick handle, sharp stone lashed with fibre | 0.3 × 3.6 × 1.6 | axe_crude.png |
| SM_Axe_Steel | Steel axe: polished steel head, wrapped grip | 0.3 × 3.6 × 1.6 | axe_steel.png |
| SM_Pickaxe_Crude | Crude pickaxe: stick + two stone points lashed on | 0.3 × 3.6 × 2.6 | pickaxe_crude.png |
| SM_Pickaxe_Steel | Steel pickaxe | 0.3 × 3.6 × 2.6 | pickaxe_steel.png |
| SM_Bow_Hunting_Crude | Crude bow (bent branch + string) | 0.3 × 4.2 × 1.0 | weapon_crude_bow.png |
| SM_Spear_Crude | Crude spear: sharpened stick | 0.3 × 6 × 0.3 | weapon_crude_spear.png |
| SM_BreachingCharge | Breaching charge (bundle with fuse) | 1.0 × 0.8 × 0.6 | explosive_breaching_charge.png |
| SM_FirstAidKit | First aid kit (small pouch with a cross) | 1.0 × 0.7 × 0.5 | healing_first_aid_kit.png |
| SM_Medkit | Medkit (bigger hard case with a cross) | 1.4 × 1.0 × 0.6 | healing_medkit.png |
| SM_Bolt | Crossbow bolt (short, fat arrow) | 0.15 × 1.6 × 0.15 | ammo_bolts.png |

## B. Resources dropped on the ground (NEW)
All about 1.3 × 0.7 × 1.3, a small readable pile or bundle.
| Save as | What it is | Icon |
|---|---|---|
| SM_Pickup_Berries | Handful of berries on leaves | resource_berries.png |
| SM_Pickup_Mushroom | Two or three mushrooms | resource_mushroom.png |
| SM_Pickup_Scrap | Pile of scrap metal bits | resource_scrap.png |
| SM_Pickup_Iron | Iron ore chunks / small ingot | resource_iron.png |
| SM_Pickup_Coal | Lumps of coal | resource_coal.png |
| SM_Pickup_RareComponent | Glowing gear/part | resource_rare_component.png |

## C. Worn backpacks (NEW), on the back, about 1.8 × 2.2 × 1.0 (bigger packs slightly bigger)
| Save as | Icon |
|---|---|
| SM_Backpack_Fibre | backpack_fibre_pack.png |
| SM_Backpack_Hide | backpack_hide_pack.png |
| SM_Backpack_ScrapFrame | backpack_scrap_frame_pack.png |
| SM_Backpack_IronFrame | backpack_iron_frame_pack.png |
| SM_Backpack_Expedition | backpack_expedition_pack.png |

## D. Build pieces with no model yet (NEW)
| Save as | What it is | Size (W × H × D) | Icon |
|---|---|---|---|
| SM_ReinforcedDoor | Reinforced wooden door in a frame | 10 × 9 × 1.6 | build_reinforced_door.png |
| SM_WindowWall | Wooden wall with a window hole | 10 × 10 × 2.4 | build_window_wall.png |
| SM_HeavyGate | Heavy iron-strapped gate | 10 × 9 × 1.6 | build_heavy_gate.png |
| SM_AdvancedAlarm | Post with a bell/siren alarm | 1.5 × 5 × 1.5 | build_advanced_alarm.png |

## E. Camp (NEW)
| Save as | What it is | Size (W × H × D) |
|---|---|---|
| SM_Camp_SpawnPad | Wooden spawn platform with a team-colour mark | 5 × 0.4 × 5 |

## F. Lobby buildings and storefronts (NEW)
Each storefront is a small open-front stall/building the player walks up to; the game puts the
shop's name and a "press E" prompt on it. Leave a flat, plain sign board on each (the game draws
the text), and keep the counter at waist height (about 3.5 studs) at the front.
| Save as | What it is | Size (W × H × D) |
|---|---|---|
| SM_Lobby_ClassHall | Log cabin shop with 6 big lit windows (mannequins stand in them), a counter in the open doorway, flat sign board over the door, chimney | 40 × 16 × 15 |
| SM_Lobby_TradingPost | Coin shop: wooden market stall, striped awning, counter with coin sacks, crates and barrels of goods | 11 × 9 × 6 |
| SM_Lobby_Outfitter | Locker/cosmetics shop: clothes stall with a rack of outfits, hats on hooks, a standing mirror, fabric awning | 11 × 9 × 6 |
| SM_Lobby_PowerUpShrine | Power-up shop: small stone shrine with glowing crystals and shelves of potion jars | 10 × 9 × 6 |
| SM_Lobby_RobuxShop | Premium shop: fancier stall with gold trim, treasure chest on the counter, gem display | 11 × 9 × 6 |
| SM_Lobby_PartyBoard | Wooden notice board on posts with pinned notes | 11 × 9 × 3 |
| SM_Lobby_HallOfFame | Stone plinth with trophies, medals and a plaque board | 11 × 9 × 6 |
| SM_Lobby_ChallengeBoard | Big framed chalkboard on two posts (text drawn by the game) | 14 × 10.5 × 2.2 |
| SM_Lobby_ReadySign | Hanging wooden sign over the ready ring | 16 × 4 × 0.5 |
| SM_Lobby_ReadyArch | Log arch over the ready ring with lantern hooks | 18 × 10 × 2 |
| SM_Lobby_LanternPole | Tall wooden lantern pole (string lights hang from it) | 1.4 × 9.5 × 1.4 |
| SM_Lobby_Bench | Log bench for the lobby | 5 × 1.8 × 1.6 |
| SM_Lobby_FlowerBox | Planter box full of flowers (for under windows and along paths) | 4 × 1.2 × 1.2 |
| SM_Season_JackOLantern | Carved pumpkin (Halloween) | 1.6 × 1.4 × 1.6 |

## H. Everything people can buy (cosmetics)
These are what the Locker sells. Most are 3D models; a few are PNG images or animations.

### H1. Nameplates: PNG images (NEW, upload as Images/Decals)
The coloured tag floating over a player's head, showing their title and level. The game shows it
on a billboard, so it must look right from the front and the back: **make it symmetrical with no
text or arrows**, and make the art identical on both halves so it reads the same from either side.
**512 × 128 PNG, transparent background, a plate shape with a clear empty middle for the text.**
Save as `nameplate_<name>.png`:
| Save as | Look |
|---|---|
| nameplate_bark.png | Bark / rough wood plank |
| nameplate_moss.png | Mossy stone |
| nameplate_silver.png | Polished silver with rivets |
| nameplate_gold.png | Shiny gold with gem studs |
| nameplate_ember.png | Dark metal with glowing ember cracks |
| nameplate_seasoned.png | Weathered leather with stitching (earned: 25 wins) |
| nameplate_centurion.png | Red and gold banner (earned: 100 wins) |
| nameplate_veteran.png | Steel blue with stars (level 50) |
| nameplate_legend.png | Gold laurel wreath frame (level 100) |
| nameplate_ghostly.png | Pale see-through ghostly green (Halloween) |

### H2. Outfits: Roblox clothing PNGs (NEW)
Each outfit is a Roblox **Shirt + Pants** pair on the standard 585 × 559 clothing template.
Save as `outfit_<name>_shirt.png` and `outfit_<name>_pants.png`:
Woodsman Plaid (red plaid shirt, dark jeans), Ranger Greens (olive ranger shirt with badge, khaki
pants), Autumn Hunter (orange hunting vest over brown), Night Stalker (black hooded gear), Ember
Warden (dark coat with glowing ember trim), Pumpkin Patch (orange and black Halloween overalls).

### H3. Backpack skins: 3D (NEW), worn on the back, about 1.8 × 2.2 × 1.0
| Save as | Look |
|---|---|
| SM_BackpackSkin_Canvas | Canvas pack with leather straps |
| SM_BackpackSkin_LeafCamo | Leaf camouflage pack with twigs tucked in |
| SM_BackpackSkin_Royal | Purple and gold royal pack |

### H4. Tool skins: 3D grip wraps (NEW), a wrap that slides over any tool handle
Short tube, about 0.35 × 0.9 × 0.35, open in the middle. Save as `SM_ToolSkin_<name>`:
Copper Wrap (copper wire coils), Moss Grip (mossy cloth), Frostbite (icy crystals), Gilded
(gold bands with a gem).

### H5. Campfire skins: 3D (NEW), same size as the campfire, 6.8 × 6.5 × 6.4
The stone ring and logs in a new style; the game adds the flames in the matching colour.
| Save as | Look |
|---|---|
| SM_CampfireSkin_Blue | Blue-grey stones, pale logs (blue flame) |
| SM_CampfireSkin_Spirit | White runestones (spirit flame) |
| SM_CampfireSkin_Void | Black obsidian stones (purple void flame) |
| SM_CampfireSkin_JackOFlame | Ring of carved pumpkins (Halloween) |

### H6. Workbench and storage skins: 3D trims (NEW)
| Save as | What it is | Size |
|---|---|---|
| SM_WorkbenchSkin_Oak | Oak plate that sits on top of the workbench | 6 × 0.3 × 2.4 |
| SM_WorkbenchSkin_Ironbound | Iron-bound plate for the workbench top | 6 × 0.3 × 2.4 |
| SM_StorageSkin_MossyCrest | Mossy stone crest badge fixed to storage fronts | 1.4 × 1.4 × 0.2 |
| SM_StorageSkin_GoldCrest | Gold crest badge for storage fronts | 1.4 × 1.4 × 0.2 |

### H7. Victory poses and elimination effects
- Victory pose props (3D, NEW): `SM_Victory_Torch` (held torch, 0.4 × 2.5 × 0.4, grip pivot),
  `SM_Victory_LogThrone` (log throne to sit on, 3 × 4 × 3). "Axe on Shoulder" uses the player's axe.
- Elimination effects (PNG particles, 128 × 128 transparent): `fx_ember.png` (glowing ember),
  `fx_leaf.png` (single leaf), `fx_star.png` (sparkle star).
- Emotes and victory poses also need **animations**, not models: use the ChatGPT animation prompt
  from before (EmoteWave, EmoteFlex, EmoteWarmHands, EmotePumpkinCheer, VictoryTorch, VictoryAxe,
  VictoryThrone).

## G. Nature and props RESTYLE (same name, EXACT size, upload as new versions)
Make these match the new tree style (clean, chunky, flat colours).
| Save as | What it is | Exact size (W × H × D) |
|---|---|---|
| SM_Flowers01 | Flower patch | 2.53 × 1.04 × 2.31 |
| SM_Flowers02 | Flower patch (other colours) | 2.44 × 1.03 × 2.37 |
| SM_Bush01 | Bush | 2.85 × 2.02 × 3.44 |
| SM_Bush02 | Big bush | 4.54 × 2.75 × 4.53 |
| SM_Bush03_Berry | Berry bush | 3.26 × 1.84 × 3.14 |
| SM_Fern01 | Fern | 3.98 × 0.74 × 3.94 |
| SM_Fern02 | Small fern | 2.75 × 0.74 × 2.85 |
| SM_Grass_Clump01 | Grass tuft | 1.23 × 1.47 × 1.35 |
| SM_Grass_Clump02 | Wide grass tuft | 2.6 × 1.17 × 1.28 |
| SM_Grass_Clump03 | Tall grass tuft | 1.34 × 2.03 × 1.14 |
| SM_Boulder01 | Boulder | 9.54 × 3.49 × 6.65 |
| SM_Boulder02 | Boulder | 6.82 × 4.77 × 5.87 |
| SM_Boulder03 | Flat boulder | 6.86 × 2.25 × 5.46 |
| SM_Rock_Small01 | Small rock | 1.81 × 0.61 × 1.29 |
| SM_Rock_Small02 | Small rock | 2.53 × 0.72 × 1.69 |
| SM_Rock_Small03 | Flat pebbles | 2.8 × 0.29 × 2.35 |
| SM_Mushrooms01 | Mushroom cluster | 1.47 × 0.93 × 1.02 |
| SM_Mushrooms02_Glow | Glowing mushrooms | 1.03 × 0.65 × 0.49 |
| SM_FallenLog01 | Fallen log | 8.06 × 2.29 × 1.78 |
| SM_FallenLog02_Hollow | Hollow fallen log | 10.88 × 3.11 × 2.74 |
| SM_Stump_Old01 | Old stump | 4.11 × 2.18 × 4.11 |
| SM_Stump_Old02 | Tall old stump | 3.74 × 3.88 × 3.74 |
| SM_Sapling01 | Sapling | 2.46 × 5.07 × 2.41 |
| SM_Roots01 | Surface roots | 4.97 × 0.57 × 4.82 |
| SM_Roots02 | Surface roots | 4.86 × 0.93 × 2.72 |
| SM_Pinecones01 | Pinecones | 1.67 × 0.3 × 2.24 |
| SM_Branch01 | Fallen branch | 4.55 × 0.48 × 3.01 |
| SM_Branch02 | Fallen branch | 3.65 × 0.53 × 2.9 |
| SM_Sticks_Loose01 | Stick pile (gatherable) | 1.85 × 0.28 × 3.06 |
| SM_StoneDeposit01 | Stone deposit (mineable) | 5.99 × 2.48 × 4.24 |
| SM_StoneDeposit01_Depleted | Mined-out stone | 4.38 × 0.75 × 4.48 |
| SM_OreDeposit_Coal | Coal deposit | 5.23 × 3.59 × 4.49 |
| SM_OreDeposit_Iron | Iron deposit | 5.37 × 3.26 × 4.56 |
| SM_ScrapPile01 | Scrap pile | 4.33 × 2.09 × 3.75 |
| SM_FiberPlant01 | Fibre plant (gatherable) | 1.93 × 3.79 × 1.95 |
| SM_FiberPlant01_Harvested | Harvested fibre plant | 0.52 × 0.65 × 0.81 |
| SM_Camp_Lantern | Lantern on a post | 1.36 × 5.3 × 0.64 |
| SM_Camp_TeamBanner | Team banner on a pole | 2.29 × 9.4 × 0.39 |
| SM_Chest_Common | Wooden chest | 3.4 × 2.4 × 2.47 |
| SM_Chest_Uncommon | Better chest | 3.4 × 2.4 × 2.47 |
| SM_Chest_Rare | Rare chest | 3.4 × 2.4 × 2.53 |
| SM_Chest_VeryRare | Very rare chest (glowing lock) | 3.4 × 2.4 × 2.53 |
| SM_CarePackage_Crate | Air-dropped supply crate | 4.45 × 3.41 × 4.45 |
| SM_SupplyCrate_Small01 | Small supply crate | 1.86 × 1.52 × 1.9 |


## I. Armour (worn, NEW)
Worn on the character over the avatar. Make one of each shape per material; keep them chunky
and low-poly. Head ~1.4 × 1.2 × 1.4, chest ~2.2 × 2.2 × 1.3, legs = two leg guards ~0.9 × 1.8 × 0.9 each
in one model spaced 1 stud apart. Save as `SM_Armor_<Material>_<Piece>`:

| Material | Save as (Head / Chest / Legs) | Icons |
|---|---|---|
| Hide | SM_Armor_Hide_Head / SM_Armor_Hide_Chest / SM_Armor_Hide_Legs | armour_hide_helmet / _chestpiece / _leggings.png |
| Reinforced Hide | SM_Armor_ReinforcedHide_Head / SM_Armor_ReinforcedHide_Chest / SM_Armor_ReinforcedHide_Legs | armour_reinforced_hide_helmet / _chestpiece / _leggings.png |
| Scrap | SM_Armor_Scrap_Head / SM_Armor_Scrap_Chest / SM_Armor_Scrap_Legs | armour_scrap_helmet / _chestpiece / _leggings.png |
| Iron | SM_Armor_Iron_Head / SM_Armor_Iron_Chest / SM_Armor_Iron_Legs | armour_iron_helmet / _chestpiece / _leggings.png |
| Tactical | SM_Armor_Tactical_Head / SM_Armor_Tactical_Chest / SM_Armor_Tactical_Legs | armour_tactical_helmet / _chestpiece / _leggings.png |
| Leather Vest | SM_Armor_LeatherVest (chest only) | armour_leather_vest.png |

## J. Everything else 3D: RESTYLE to the new look (same name, EXACT size, new version)
These already exist in the game. Remake each in the new clean chunky style at exactly this size.

### Held items (weapons & tools)
| Save as | Exact size (W × H × D) |
|---|---|
| SM_Axe_Iron | 0.31 × 3.61 × 1.58 |
| SM_Bandage_Held | 0.45 × 1.46 × 0.73 |
| SM_Crossbow | 3.21 × 0.95 × 3.05 |
| SM_Crowbar | 0.17 × 3.5 × 0.88 |
| SM_HuntingBow | 0.3 × 4.84 × 0.77 |
| SM_Pickaxe_Iron | 0.31 × 3.61 × 2.62 |
| SM_Pickaxe_Stone | 0.47 × 3.61 × 2.2 |
| SM_Pistol | 0.28 × 1.05 × 1.41 |
| SM_Rifle | 0.34 × 1.24 × 5.69 |
| SM_Shotgun | 0.33 × 1.08 × 5.67 |
| SM_Sledgehammer | 0.6 × 4.2 × 1.5 |

### Pickups on the ground
| Save as | Exact size (W × H × D) |
|---|---|
| SM_Ammo_Pistol | 0.9 × 0.75 × 0.62 |
| SM_Ammo_Rifle | 1.3 × 0.96 × 0.6 |
| SM_Ammo_Shotgun | 1.1 × 0.95 × 0.7 |
| SM_Pickup_Ammo | 1.25 × 0.81 × 0.85 |
| SM_Pickup_Bandage | 0.55 × 0.77 × 1.47 |
| SM_Pickup_Fiber | 0.54 × 0.31 × 1.66 |
| SM_Pickup_Leather | 1.3 × 0.49 × 1.29 |
| SM_Pickup_Rope | 1.56 × 0.36 × 1.23 |
| SM_Pickup_Stick | 1.7 × 0.47 × 0.52 |
| SM_Pickup_Stone | 1.41 × 0.69 × 0.92 |
| SM_Pickup_Wood | 1.07 × 0.93 × 1.3 |

### Build pieces, storage & camp
| Save as | Exact size (W × H × D) |
|---|---|
| SM_BearTrap | 2.56 × 0.55 × 1.76 |
| SM_Campfire_Burning | 6.81 × 6.5 × 6.44 |
| SM_Campfire_ColdWet | 6.96 × 6.5 × 6.76 |
| SM_Campfire_Extinguished | 6.96 × 6.5 × 6.62 |
| SM_MetalLocker | 4 × 7 × 3.2 |
| SM_MetalWall | 10.8 × 11 × 2.6 |
| SM_ReinforcedChest | 6.2 × 4.3 × 4.3 |
| SM_ScrapWall | 10.46 × 10.4 × 1.36 |
| SM_Snare | 3.14 × 3.25 × 2.46 |
| SM_SupplyCrate_Small02 | 3.26 × 1.12 × 1.51 |
| SM_SupplyCrate_Small03 | 3.73 × 1.31 × 3.36 |
| SM_SurvivalSafe | 4.5 × 5 × 4.8 |
| SM_TripwireAlarm | 7.91 × 1.4 × 0.53 |
| SM_WoodFloor | 10 × 1 × 10.02 |

### Places to explore (POIs)
| Save as | Exact size (W × H × D) |
|---|---|
| SM_POI_AbandonedHouse | 16.48 × 13.98 × 17.62 |
| SM_POI_BrokenVehicle | 15.12 × 5.36 × 9.42 |
| SM_POI_Bunker | 14.6 × 8.68 × 14.92 |
| SM_POI_Cabin | 14.87 × 12.84 × 13.4 |
| SM_POI_Campsite | 18.46 × 3.71 × 15.03 |
| SM_POI_HuntingBlind | 6.4 × 8.6 × 6.9 |
| SM_POI_IndustrialSite | 34.95 × 10.61 × 22.5 |
| SM_POI_LargeMine | 19.35 × 14.81 × 20.95 |
| SM_POI_LoggingCamp | 19.11 × 9.42 × 24 |
| SM_POI_MineEntrance | 15.71 × 8.47 × 20.56 |
| SM_POI_Outpost | 26.56 × 9.36 × 20.6 |
| SM_POI_RangerStation | 15.56 × 12.84 × 22.1 |
| SM_POI_Shed | 9 × 7.83 × 6.96 |
| SM_POI_SmallCabin | 10.87 × 11.6 × 10.9 |

### World props, caves & cliffs
| Save as | Exact size (W × H × D) |
|---|---|
| SM_Camp_Barrel | 2 × 2.53 × 2 |
| SM_Camp_Bedroll | 1.8 × 0.71 × 4.6 |
| SM_Camp_ChoppingBlock | 3.8 × 1.7 × 3.84 |
| SM_Camp_DryingRack | 4.6 × 4.23 × 1.41 |
| SM_Camp_FirewoodStack | 2.65 × 1.76 × 1.5 |
| SM_Camp_LogBench | 5 × 1.89 × 1.26 |
| SM_CaveChamber_End | 19.37 × 15.88 × 20.19 |
| SM_CaveEntrance | 20.87 × 15.4 × 9.75 |
| SM_CaveTunnel_Segment | 14.75 × 12.95 × 12.4 |
| SM_Cliff_Face01 | 24.8 × 26.38 × 9.71 |
| SM_Cliff_Face02 | 24.62 × 23.56 × 9.66 |
| SM_Landmark_AntlerTotem | 3.32 × 8.86 × 1.19 |
| SM_Landmark_GiantLog | 22.8 × 8.6 × 7.43 |
| SM_Landmark_StandingStones | 17.26 × 7.9 × 17.79 |

### Effect
| Save as | Exact size (W × H × D) |
|---|---|
| SM_Campfire_Flames | 2.47 × 4.9 × 2.42 |
| SM_Campfire_WaterTarget | 6.4 × 0.44 × 6.4 |
| SM_Parachute_Canopy | 14 × 4.4 × 14 |
| SM_Parachute_Lines | 13.89 × 12.44 × 13.89 |

### Lobby
| Save as | Exact size (W × H × D) |
|---|---|
| SM_Sign_Board | 12 × 9.3 × 1.6 |
| SM_Sign_Hanging | 4.5 × 3.44 × 0.34 |
| SM_Sign_Plaque | 1.8 × 0.94 × 0.34 |
| SM_Sign_Post | 4 × 5.1 × 0.54 |

After ChatGPT uploads: send Claude the IDs for everything in sections A to F, H and I (the game
needs a little code to use the H items). Sections G and J need nothing, because they use the same IDs.
