# Blender models wanted (for ChatGPT)

## Rules for every model (paste this part to ChatGPT too)
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
| Save as | What it is | Size (W × H × D) |
|---|---|---|
| SM_Lobby_ClassHall | Log cabin shop with 6 big lit windows (mannequins stand in them), a counter in the open doorway, neon "CLASSES" sign spot over the door, chimney | 40 × 16 × 15 |
| SM_Lobby_TradingPost | Market stall storefront: counter, awning, crates of goods ("TRADING POST") | 11 × 9 × 6 |
| SM_Lobby_Outfitter | Clothing stall: counter, rack of clothes, mirror ("OUTFITTER") | 11 × 9 × 6 |
| SM_Lobby_PartyBoard | Wooden notice board on posts with pinned notes ("PARTY BOARD") | 11 × 9 × 3 |
| SM_Lobby_HallOfFame | Stone plinth with trophies and a plaque board ("HALL OF FAME") | 11 × 9 × 6 |
| SM_Lobby_ChallengeBoard | Big framed chalkboard on two posts (text is drawn by the game) | 14 × 10.5 × 2.2 |
| SM_Lobby_ReadySign | Hanging wooden sign over the ready ring | 16 × 4 × 0.5 |
| SM_Lobby_LanternPole | Tall wooden lantern pole (string lights hang from it) | 1.4 × 9.5 × 1.4 |
| SM_Season_JackOLantern | Carved pumpkin (Halloween) | 1.6 × 1.4 × 1.6 |

Leave the front of boards and signs flat and plain: the game draws the text on them.

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

After ChatGPT uploads: send Claude the IDs for everything in sections A to F. Section G needs
nothing, because it uses the same IDs.
