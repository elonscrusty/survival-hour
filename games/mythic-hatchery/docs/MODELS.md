> Historical handoff: implementation has changed. Read CONTRACTS.md, STATUS.md and STUDIO_TESTS.md for the current game.

# Pet Expedition: models and world

Everything visual is built at runtime from Roblox primitives (no uploaded meshes), so it works in Studio straight away.
Style: blocky voxel toys, following the owner's reference pictures in `reference/` (summary in `reference/ART_DIRECTION.md`).

## Pipeline
- `models/gen_models.py` is the single source of truth. Running `python3 models/gen_models.py` writes
  `src/shared/Models/ModelData.luau` (pets, eggs, breakables, props) and `src/shared/Models/WorldData.luau` (layout).
  Never edit those two files by hand.
  - `models/lib.py`: geometry helpers (ellipsoids, cylinders, wedges, eyes, cones, crystals, transforms).
  - `models/pets.py`: all 41 pets as blocky toys (box head bigger than the body, box ears/legs/paws, flat disc face).
  - `models/eggs.py`: the 7 eggs and their themed pedestals.
  - `models/voxel.py`: blocky decorations, island landmarks, hub set pieces, Pet Ring dressing.
  - `models/items.py`: breakables per island theme, gates, signs and the prop registry.
  - `models/world.py`: island layout (stepped cliffs, waterfalls, rocks in the water), rope bridges, gates, walls, zones,
    the Meadow hub, the Pet Ring and the decoration scatter.
- Ids come from `src/shared/{Pets,Eggs,Areas}.luau`; the generator stops if a pet or egg has no model.
- `models/render.py` (needs bpy and Pillow) renders the same data to `renders/`: `pets/`, `eggs/`, `breakables/`,
  `props/`, `world/`, the sheets, and `marketing/` (icon and thumbnails).
  `python3 models/render.py --only pets --ids Puppy,Fox` for a quick look.

## Runtime (`Models/init.luau`)
- `Models.Pet(id, variant, shiny)`, `Models.Egg(id, scale?)`, `Models.Breakable(kind, area)`, `Models.Prop(name, scale?)`.
- Templates are cached; each call returns a clone. PrimaryPart `Root` is an invisible bounding box; pivot is the
  bottom centre, facing -Z.
- Golden: gold Foil recolour (eyes, blush, mouth and collar kept). Rainbow: horizontal bands (red, orange, yellow,
  green, blue, purple, each 15% of the pet height); each part has a `RainbowHue` attribute and the model has
  `Rainbow = true`, so the client can cycle hues; the cream face patch stays. Shiny: slight warm tint plus a gold
  `ShinySparkles` ParticleEmitter on Root, model attribute `Shiny = true`.
- Part names: `Eye` (face details, never recoloured), `Collar` (kept on Golden/Rainbow), `Face` (kept on Rainbow),
  `Body`, `Glow` (neon accents).

## World (`Models/World.luau`)
- Six round islands along +X, 320 studs apart (Meadow radius 150, others 125), ground top y = 0, Terrain water at y = -16.
- Each island has a landmark on its north edge, outside the breakable zones (Grove giant mushroom, Frost peaks with an
  ice fall, Coral lagoon with palms, Volcano with a lava river, Starfall swirl portal with planets); Meadow has the windmill.
- Invisible walls ring each island and line each bridge, so the gates are the only way forward.
- Gate barriers sit on the bridge just before each locked island. Egg stands are just past each gate; the Meadow hub
  (around the spawn) has the Meadow and Prism egg stands, Expedition Board, Craft Machine, Rebirth Statue and Index Book.
- Two breakable zones per island (north and south of the path), kept clear of decorations.
- Pet Ring next to the hub (sand floor, stepping stones, red posts with glowing balls, ropes, a "PET RING" arch).
- About 4,800 parts in total.
