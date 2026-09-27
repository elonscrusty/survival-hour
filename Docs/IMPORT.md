# Importing Survival Hour into Roblox Studio

> **Status:** these steps follow Roblox's current Creator Hub docs (Export settings, Blender guide,
> Meshes, Texture specifications, Rigid accessory specifications, General specifications).
> The files were **not** imported into Roblox Studio while building this pack, because Studio wasn't
> available. Import one asset from each group below and check it before bulk-importing. See
> `Docs/QA_REPORT.md` for what *was* verified.

## Quick start: one-paste setup

1. **Home → Import 3D** and select **every** `.fbx` in `Export/Meshes/*` (all category folders) and
   `Export/Rigs/*`. Set **World Forward = Front**, **World Up = Top**, **Scale Unit = Stud**.
2. Optional, for full-quality textures: upload the 8 PNGs in `Textures/` (Asset Manager → Import) and
   paste their ids into the `TEXTURES` table at the top of the script. Leave them blank to keep the
   preview texture already embedded in each file.
3. Open **View → Command Bar**, paste all of `Roblox/SurvivalHour_CommandBarSetup.lua`, press Enter.

The script finishes everything below in one pass:
- sets pivots, attachments and collision (invisible box Parts; decor and effects don't collide)
- builds Tools for held items and Accessories for armour
- places doors, lids and gun parts
- adds an AnimationController, Animator and hitboxes to each animal
- files everything under **ServerStorage › SurvivalHour › <Category>**, and lays out a showcase copy
  in **Workspace › SurvivalHour_Showcase**

It prints any assets it couldn't find, and **Ctrl+Z** undoes the whole run. It compiles with the official
Luau compiler and passed a smoke test against a mock of the Roblox API
(`blender/tests/run_setup_smoke.py`), but it **hasn't been run in real Studio yet**. If it errors, copy
the Output window text back to Claude. Animations still need importing through the Animation Editor
(section 6).

## Survival Wars expansion (57 new assets)

The Survival Wars update adds five folders under `Export/Meshes/`: `SW_Landscape`
(cliff faces, cave entrance and interior pieces, riverbanks, modular ground sections,
trail strips, roots, flowers, sapling, spruces, aspen, scrap pile, ore seams),
`SW_POI` (14 points of interest), `SW_Loot` (4 chest tiers), `SW_Tools` (pickaxes,
iron axe, crowbar, sledgehammer, hunting bow, crossbow) and `SW_Base` (storage tiers,
scrap/metal walls, wooden floor, traps, Workbench IV/V).

The game already runs without them: every model falls back to its procedural look
until the mesh is in the library. To add them:

1. Import the `.fbx` files from those five folders (same importer settings as below).
2. Run `Roblox/SurvivalHour_Paste.lua` again (it skips assets that are already set up).
3. Select `ServerStorage.SurvivalHour` → right-click → **Save to File…** →
   overwrite `SurvivalHourAssets.rbxm` in the project, then rebuild with Rojo.

## 1. How the files were exported

The exporter (`blender/sh/pipeline.py → export_fbx`) uses Roblox's documented Blender FBX settings:

| Setting | Value | Why |
|---|---|---|
| Scene units | Unit System **None**, 1 unit = 1 stud | Roblox Blender guide, "Configure units" |
| Apply Scalings | **FBX Unit Scale** | Roblox's recommended way to keep scale |
| Forward / Up | **Z Forward / Y Up** | Roblox Blender guide, export settings |
| Path Mode / Embed Textures | **Copy / on** | Roblox export settings |
| Add Leaf Bones | **off** | Roblox export settings |
| Bake Animation | off for meshes, **on** only for `A_*.fbx` clips | Roblox export settings |
| Transforms | Every object at the origin with identity rotation/scale | "Apply transforms" |

With these settings, an asset's front (modelled facing Blender -Y) becomes Roblox **-Z (LookVector)**,
Blender +Z becomes Roblox +Y, and Blender +X becomes Roblox -X. `verify_exports.py` checks this on the
pistol, rifle and spear.

## 2. Importer settings (Studio → Home → Import 3D)

For every file:

- **File Transform → World Forward: Front**, **World Up: Top** (keeps the Blender orientation).
- **File Geometry → Scale Unit: Stud** (models are authored in studs).
- The reference dummy `SM_Reference_Dummy_R15` should come in about **5.25 studs tall**. If it doesn't,
  the scale unit is wrong.

Groups:

| Group | Files | Importer notes |
|---|---|---|
| Static props, structures | `Export/Meshes/<Category>/SM_*.fbx` | One MeshPart each. `<Name>_Att` children become Attachments. |
| Moving parts | `SM_*_Door`, `_Lid`, `_Slide`, `_Pump`, `_Bolt`, `_Panel` | Separate MeshParts; place with `Setup.PlaceParts`. |
| Collision proxies | `Export/Collision/**/COL_*.fbx` | Optional: the same boxes are in the Luau data; `Setup.BuildCollision` makes them from Parts. |
| Lower-detail | `Export/LOD/**/SM_*_LOD1.fbx` | Swap in by distance with your own script or StreamingEnabled models. Roblox's automatic `RenderFidelity` still applies to all meshes. |
| Rigs | `Export/Rigs/SK_Wolf.fbx`, `SK_Bear.fbx`, `SK_Bat.fbx` | Import as a model with its rig. Check bones in the importer preview. |
| Animations | `Export/Animations/<Creature>/A_*.fbx` | One clip per file (Roblox allows a single animation track per FBX). |
| Armour | `Export/Meshes/Armor/ACC_*.fbx` | Rigid accessories. Wrap with `Setup.MakeAccessory`. |

## 3. Textures (one shared atlas)

Every mesh uses the same UV atlas, so the whole pack needs only one texture set.

1. Upload these from `Textures/` (Asset Manager → Import), all 1024×1024:
   - `T_SurvivalAtlas_Color_Neutral.png` (and `_Red`, `_Blue`, `_Yellow`, `_Purple` for teams)
   - `T_SurvivalAtlas_Normal.png` (OpenGL, tangent space, as Roblox requires)
   - `T_SurvivalAtlas_Roughness.png`
   - `T_SurvivalAtlas_Metalness.png`
2. Each FBX embeds only a **256 px colour preview** (`T_SurvivalAtlas_Color_Embed256.png`). This keeps
   files small, so meshes aren't blank on import. For final quality, add a SurfaceAppearance.
3. Make one SurfaceAppearance per team in **ReplicatedStorage › SurvivalHourAtlas**. Game scripts can't
   change SurfaceAppearance texture ids at runtime, so set them up once from the Command Bar:

```lua
local ids = { -- paste your uploaded asset ids
	Neutral = "rbxassetid://0", Red = "rbxassetid://0", Blue = "rbxassetid://0",
	Yellow = "rbxassetid://0", Purple = "rbxassetid://0",
}
local normal, rough, metal = "rbxassetid://0", "rbxassetid://0", "rbxassetid://0"
local folder = Instance.new("Folder"); folder.Name = "SurvivalHourAtlas"
for team, id in ids do
	local sa = Instance.new("SurfaceAppearance"); sa.Name = team
	sa.ColorMap = id; sa.NormalMap = normal; sa.RoughnessMap = rough; sa.MetalnessMap = metal
	sa.Parent = folder
end
folder.Parent = game:GetService("ReplicatedStorage")
```

4. Call `Setup.ApplyAtlas(model, "Red")` (etc.) on a team's camp to switch its accent colour. Only the
   `team_cloth` and `team_paint` tiles differ between the five colour maps: restrained accents on
   banners, workbench cloth, the campfire stake, arrow fletching, bedroll and shield band.

## 4. Scripts

Copy `Roblox/SurvivalHourAssetData.lua` and `Roblox/SurvivalHourSetup.lua` into two ModuleScripts
named `SurvivalHourAssetData` and `SurvivalHourSetup` in the same folder.

```lua
local Setup = require(ReplicatedStorage.SurvivalHour.SurvivalHourSetup)
Setup.PrepareStatic(workspace.SM_WoodenWall)        -- pivot, attachments, collision boxes
local tool = Setup.MakeTool(workspace.SM_StoneAxe)  -- Tool with Grip at the modelled grip point
local acc = Setup.MakeAccessory(workspace.ACC_Armor_Helmet)
```

Why the helpers matter: Roblox puts an imported MeshPart's CFrame at the centre of its bounding box.
The data stores each asset's authored origin (building anchor, grip, hinge) as `OriginOffset`.
`SetPivot`, `MakeTool` and `PlaceParts` use it so snapping, grips and hinges line up.

## 5. Group-specific notes

- **Walls and gates** snap every 8 studs along their local X. Each piece owns its **left** post; close a
  run or corner with `SM_WallPost`. `SM_ReinforcedWall` uses the same footprint and pivot, so it can
  replace a wooden wall in place.
- **Gate**: anchor `SM_Gate`, then hinge `SM_Gate_Door` about its pivot (HingeConstraint or a CFrame
  tween around `Hinge`). The opening is 6.6 × 7.2 studs.
- **Watchtower**: use the collision boxes, not mesh collision, so the 2.8 × 2.4 hatch stays open. Put an
  invisible **TrussPart** in the climb volume (`catalog.json → SM_Watchtower.meta.climb_volume`, in
  front of the ladder) so every avatar type climbs reliably.
- **Campfire states**: swap `SM_Campfire_Burning` / `_Extinguished` / `_ColdWet`; all three share the pivot
  and attachments. Add `SM_Campfire_Flames` (Material **Neon**) for the burning state, and show
  `SM_Campfire_WaterTarget` to players holding water nearby. Fire/Smoke/Light/Extinguish attachments are
  set up for Fire/Smoke/ParticleEmitter/PointLight instances.
- **Effects** (flames, water surfaces, parachute, target ring): CanCollide/CanQuery/CanTouch off.
  Suggested water: Material Glass or SmoothPlastic, Transparency ≈ 0.35. This is the only suggested
  transparency in the pack.
- **Foliage and decor** (grass, ferns, bushes, fibre, litter, branches): CanCollide off so nothing
  catches players. Trees collide only on their trunk box.
- **Care package**: `ItemSpawn1-3` sit 5 studs in front of the crate (fanned ±50°), clear of the open
  lid, so the three released items stay visible. The parachute canopy and lines are separate from the
  crate: hide or tween them away on landing.
- **Firearms**: `Grip` = origin, `Muzzle`, `ShellEject` (right side), `SecondHand` for long guns. Moving
  parts: `SM_Pistol_Slide` (slides +Z), `SM_Shotgun_Pump` (+Z), `SM_Rifle_Bolt` (rotate, then +Z).
- **Armour**: rigid accessories fitted to Classic-scale block proportions. Rigid accessories don't
  deform; check the fit on your game's avatar scale (Rthro Normal is taller), and adjust the Accessory
  attachment offsets if needed.

## 6. Rigs and animations

1. Import `SK_<Creature>.fbx` (rig + skinned mesh). Check in the preview that the bone count matches
   `Docs/RIGS_ANIMATIONS.md`.
2. `Setup.PrepareRig(model)` adds an AnimationController and Animator if the importer didn't.
3. Import each `A_<Creature>_<Clip>.fbx` in the **Animation Editor** on that rig (⋯ → Import → From FBX
   Animation), then publish it and use the returned id with `Animator:LoadAnimation`.
4. Loop the Idle/Walk/Run/Fly clips in script (`AnimationTrack.Looped = true`).
5. Hitboxes: invisible, CanCollide-off Parts attached to the matching bone with a RigidConstraint
   (a Bone is an Attachment), using the sizes in `Docs/RIGS_ANIMATIONS.md`. The body box follows
   `Hips` and the head box follows `Head`. Use the movement collider (one box) for pathfinding and
   physics.
