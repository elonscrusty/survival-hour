# Pet Expedition: models and world

Everything visual is built at runtime from Roblox primitives (no uploaded meshes), so it works in Studio straight away.

## Pipeline
- `models/gen_models.py` is the single source of truth. Running `python3 models/gen_models.py` writes
  `src/shared/Models/ModelData.luau` (pets, eggs, breakables, props) and `src/shared/Models/WorldData.luau` (layout).
  Never edit those two files by hand.
  - `models/lib.py`: geometry helpers (ellipsoids, cylinders, wedges, eyes, cones, crystals, transforms).
  - `models/pets.py`: all 41 pets, built from archetypes (quadruped, bunny, dragon, unicorn, birds, sea creatures...).
  - `models/items.py`: eggs, breakables per island theme, decorations and interactable bodies.
  - `models/world.py`: island layout, bridges, gates, walls, zones, decoration scatter.
- Ids come from `src/shared/{Pets,Eggs,Areas}.luau`; the generator stops if a pet or egg has no model.
- `models/render.py` (needs bpy and Pillow) renders the same data to `renders/`: `pets/`, `eggs/`, `breakables/`,
  `props/`, `world/`, the sheets, and `marketing/` (icon and thumbnails).
  `python3 models/render.py --only pets --ids Puppy,Fox` for a quick look.

## Runtime (`Models/init.luau`)
- `Models.Pet(id, variant, shiny)`, `Models.Egg(id, scale?)`, `Models.Breakable(kind, area)`, `Models.Prop(name, scale?)`.
- Templates are cached; each call returns a clone. PrimaryPart `Root` is an invisible bounding box; pivot is the
  bottom centre, facing -Z.
- Golden: gold Foil recolour (eyes kept). Rainbow: hue stripes by height; each part has a `RainbowHue` attribute and
  the model has `Rainbow = true`, so the client can cycle hues. Shiny: pastel tint plus a `ShinySparkles`
  ParticleEmitter on Root, model attribute `Shiny = true`.
- Part names: `Eye` (kept on variants), `Body`, `Glow` (neon accents).

## World (`Models/World.luau`)
- Six round islands along +X, 320 studs apart (Meadow radius 150, others 125), ground top y = 0, Terrain water at y = -8.
- Invisible walls ring each island and line each bridge, so the gates are the only way forward.
- Gate barriers sit on the bridge just before each locked island. Egg stands are just past each gate; the Meadow hub
  (around the spawn) has the Meadow and Prism egg stands, Expedition Board, Craft Machine, Rebirth Statue and Index Book.
- Two breakable zones per island (north and south of the path), kept clear of decorations.
- About 5,000 parts in total.
