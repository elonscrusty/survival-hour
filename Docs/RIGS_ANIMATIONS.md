# Rigs and animations

Each creature is one skinned mesh plus an armature. Following Roblox's rigging specs, the root bone `Root` is at (0,0,0) and has no skin influence, each vertex has at most 4 influences (these rigs use 3 or fewer), and bones rest at identity. Roblox allows one animation track per FBX, so every clip is its own file under `Export/Animations/<Creature>/`. Clips are 30 fps.

## `SK_Wolf`

Pack hunter. Fast, low HP. Idle/Walk/Run/Alert/Attack/Hit/Death/Howl.

- Mesh: 1986 tris, 1 material. 23 bones, max 3 influences/vertex, Root has no influence. Front faces -Z.
- Rig file: `Export/Rigs/SK_Wolf.fbx`
- Hitboxes (`Export/Collision/Wildlife/COL_Wolf_Hitboxes.fbx`): Body 1.4 × 1.7 × 4.2 at (0.0, 2.4, 0.2), Head 0.9 × 0.9 × 1.5 at (0.0, 3.4, -2.3)
- Movement collider suggestion: 1.5 × 3.7 × 6.4 at (0.0, 1.9, 0.2)
- Bones: `Root`, `Hips`, `Spine`, `Neck`, `Head`, `Jaw`, `Ear_L`, `FrontUpperLeg_L`, `FrontLowerLeg_L`, `FrontPaw_L`, `HindUpperLeg_L`, `HindLowerLeg_L`, `HindFoot_L`, `Ear_R`, `FrontUpperLeg_R`, `FrontLowerLeg_R`, `FrontPaw_R`, `HindUpperLeg_R`, `HindLowerLeg_R`, `HindFoot_R`, `Tail1`, `Tail2`, `Tail3`

| Clip | Frames | Seconds | Loop | File |
|---|---|---|---|---|
| Idle | 60 | 2.0 | yes | `Export/Animations/Wolf/A_Wolf_Idle.fbx` |
| Walk | 36 | 1.2 | yes | `Export/Animations/Wolf/A_Wolf_Walk.fbx` |
| Run | 20 | 0.67 | yes | `Export/Animations/Wolf/A_Wolf_Run.fbx` |
| Alert | 30 | 1.0 | no | `Export/Animations/Wolf/A_Wolf_Alert.fbx` |
| Attack | 26 | 0.87 | no | `Export/Animations/Wolf/A_Wolf_Attack.fbx` |
| Hit | 16 | 0.53 | no | `Export/Animations/Wolf/A_Wolf_Hit.fbx` |
| Death | 46 | 1.53 | no | `Export/Animations/Wolf/A_Wolf_Death.fbx` |
| Howl | 70 | 2.33 | no | `Export/Animations/Wolf/A_Wolf_Howl.fbx` |

## `SK_Bear`

Heavy threat: slow, tanky. Idle/Walk/Run/Alert/Attack(swipe)/Hit/Death/RearUp.

- Mesh: 1980 tris, 1 material. 21 bones, max 3 influences/vertex, Root has no influence. Front faces -Z.
- Rig file: `Export/Rigs/SK_Bear.fbx`
- Hitboxes (`Export/Collision/Wildlife/COL_Bear_Hitboxes.fbx`): Body 2.9 × 2.9 × 5.6 at (0.0, 3.1, 0.2), Head 1.6 × 1.6 × 2.0 at (0.0, 3.6, -3.6)
- Movement collider suggestion: 3.0 × 5.2 × 9.0 at (0.0, 2.6, -0.3)
- Bones: `Root`, `Hips`, `Spine`, `Neck`, `Head`, `Jaw`, `Ear_L`, `FrontUpperLeg_L`, `FrontLowerLeg_L`, `FrontPaw_L`, `HindUpperLeg_L`, `HindLowerLeg_L`, `HindFoot_L`, `Ear_R`, `FrontUpperLeg_R`, `FrontLowerLeg_R`, `FrontPaw_R`, `HindUpperLeg_R`, `HindLowerLeg_R`, `HindFoot_R`, `Tail1`

| Clip | Frames | Seconds | Loop | File |
|---|---|---|---|---|
| Idle | 60 | 2.0 | yes | `Export/Animations/Bear/A_Bear_Idle.fbx` |
| Walk | 36 | 1.2 | yes | `Export/Animations/Bear/A_Bear_Walk.fbx` |
| Run | 20 | 0.67 | yes | `Export/Animations/Bear/A_Bear_Run.fbx` |
| Alert | 30 | 1.0 | no | `Export/Animations/Bear/A_Bear_Alert.fbx` |
| Hit | 16 | 0.53 | no | `Export/Animations/Bear/A_Bear_Hit.fbx` |
| Death | 46 | 1.53 | no | `Export/Animations/Bear/A_Bear_Death.fbx` |
| Attack | 30 | 1.0 | no | `Export/Animations/Bear/A_Bear_Attack.fbx` |
| RearUp | 72 | 2.4 | no | `Export/Animations/Bear/A_Bear_RearUp.fbx` |

## `SK_Bat`

Night swarm flyer. Pivot = body centre (hovers; not ground-based). Idle(hover)/Fly/FastFly/Alert/Attack(dive)/Hit/Death(fall).

- Mesh: 1004 tris, 1 material. 18 bones, max 3 influences/vertex, Root has no influence. Front faces -Z.
- Rig file: `Export/Rigs/SK_Bat.fbx`
- Hitboxes (`Export/Collision/Wildlife/COL_Bat_Hitboxes.fbx`): Body 1.2 × 0.8 × 1.6 at (0.0, 0.0, 0.0)
- Movement collider suggestion: 5.4 × 1.0 × 1.8 at (0.0, 0.0, 0.2)
- Bones: `Root`, `Body`, `Head`, `Jaw`, `Ear_L`, `UpperArm_L`, `Forearm_L`, `Finger1_L`, `Finger2_L`, `Finger3_L`, `Leg_L`, `Ear_R`, `UpperArm_R`, `Forearm_R`, `Finger1_R`, `Finger2_R`, `Finger3_R`, `Leg_R`

| Clip | Frames | Seconds | Loop | File |
|---|---|---|---|---|
| Idle | 24 | 0.8 | yes | `Export/Animations/Bat/A_Bat_Idle.fbx` |
| Fly | 24 | 0.8 | yes | `Export/Animations/Bat/A_Bat_Fly.fbx` |
| FastFly | 24 | 0.8 | yes | `Export/Animations/Bat/A_Bat_FastFly.fbx` |
| Alert | 30 | 1.0 | no | `Export/Animations/Bat/A_Bat_Alert.fbx` |
| Attack | 26 | 0.87 | no | `Export/Animations/Bat/A_Bat_Attack.fbx` |
| Hit | 16 | 0.53 | no | `Export/Animations/Bat/A_Bat_Hit.fbx` |
| Death | 40 | 1.33 | no | `Export/Animations/Bat/A_Bat_Death.fbx` |

