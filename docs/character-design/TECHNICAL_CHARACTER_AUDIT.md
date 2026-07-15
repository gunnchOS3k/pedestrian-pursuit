# Technical Character Audit

Branch: `cursor/character-life-and-final-product-pass`  
Date: 2026-07-15

## Anime Aggressors

| Check | Status | Notes |
| --- | --- | --- |
| Skeleton hierarchy | PARTIAL | Shared proxy GLB hierarchy per fighter; accessories differ |
| Bone naming | PASS | Blender-generated sensible names |
| Root motion | N/A | Combat is 2D physics; 3D is presentation SubViewport |
| Mesh weighting | PASS (proxy) | Blockout weights; no collapse observed in smoke |
| Shoulder/elbow/hip/knee | PARTIAL | Blockout acceptable; not production skinning |
| Foot contact | PARTIAL | No IK; presentation-only feet |
| Facial rig | PARTIAL | Expression chip + glyph overlays (mobile-readable); not blendshapes |
| Animation looping | PASS | Idle/walk/run/fall/aura_charge loop flags |
| Transitions | PARTIAL | 0.08 blend; personality via speed_scale |
| Model scale | PASS | Orthogonal viewport sized consistently |
| Collision alignment | PASS | Separate 2D hurt/hit boxes |
| Materials | PASS | Per-fighter colors; no placeholder checker |
| Diagnostic labels | PASS | PROXY watermark forced off in release presentation |
| Select silhouettes | PASS (vector) | Distinct `FighterSilhouetteCard` shapes per fighter |
| Title cameo | PASS (code) | Boot rotates fighters with silhouette + model preview |

## Pedestrian Pursuit

| Check | Status | Notes |
| --- | --- | --- |
| Modular runners | PASS | Procedural limb/accent topology by archetype |
| Rear readability | PASS (code) | Jacket panel / scarf / backpack / kinetic ring accents |
| Foot sliding | PARTIAL | Cadence synced to speed; no grounded IK |
| Gait identity | PASS | Stride/cadence/lean/bounce scales driven by profile |
| Selection UI | PASS | MainMenu RunnerPicker + SubViewport preview |
| Stumble/recovery | PARTIAL | Distinct pose branches; not skinned dance |
| Podium | PARTIAL | Medal text + finish body poses; no elevated stage mesh |

## Open defects to watch on Pixel

1. Foot contact without IK at high speed.
2. Anime proxy mesh still shared anatomy — silhouette cards + accessories carry distinctness until unique finals ship.
3. Secondary cloth is baked/procedural only (no cloth sim).
