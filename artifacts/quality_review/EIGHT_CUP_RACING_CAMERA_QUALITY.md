# Eight-cup racing-camera quality review (procedural — not commercial final)

**HUMAN_FUN_APPROVAL / HUMAN_COURSE_APPROVAL / RC2_READY / V1_0_0_RELEASE_AUTHORIZED:** all **false**

Candidate counts are inventory, not the milestone. This pass deepens racing-camera readability for **all eight cups**, with cups 3–8 now matching cups 1–2 per-track chase + accent lighting.

## Cup status (honest)

| Cup | Geometry | Lighting / camera | Landmarks / hazards | Art claim |
| --- | --- | --- | --- | --- |
| Sole Surge | championship_upgraded | theme fills + per-track chase | cascade/ranch/prism/ember authored | track_art_candidate only |
| Stride Circuit | championship_upgraded | Harbor/NeonYard/Ridge/Mesa fills + chase | pier/gantry/cairn/mesa + collision rocks | track_art_candidate only |
| Metro Motion | elevated | MetroFill + per-track accent + chase | Billboard/Pulse/Canyon/Spiral | candidate |
| Kinetic Coast | elevated | CoastFill + per-track accent + chase | pier/cliff/bridge/spire | candidate |
| Neon Night | elevated | NeonFill/Bounce + per-track accent + chase | canopy/gates/overpass/gantry | candidate |
| Skyline Relay | elevated | SkylineFill + per-track accent + chase | rooftop/bridge/antenna/obs | candidate |
| Archive Relay | elevated | ArchiveFill + per-track accent + chase | foyer/shelves/vault | candidate |
| World Wonder | elevated | WonderFill + per-track accent + chase | falls/aurora/origami/crown | candidate |

## Cups 3–8 per-track chase IDs (this pass)

| Track | `camera_identity` | Accent light |
| --- | --- | --- |
| sneaker_city_sprintway | sneaker_city_chase | SneakerCityAccent |
| metro_pulse_loop | metro_pulse_chase | MetroPulseAccent |
| crosswalk_canyon | crosswalk_chase | CrosswalkAccent |
| transit_spiral | transit_chase | TransitSpiralAccent |
| saltline_boardwalk | saltline_chase | SaltlineAccent |
| cliffside_draft | cliffside_chase | CliffsideAccent |
| tidal_bridge_run | tidal_chase | TidalAccent |
| seaglass_switchback | seaglass_chase | SeaglassAccent |
| lantern_corridor | lantern_chase | LanternAccent |
| mirror_boulevard | mirror_chase | MirrorAccent |
| afterglow_overpass | afterglow_chase | AfterglowAccent |
| signal_storm_yard | signal_storm_chase | SignalStormAccent |
| rooftop_ribbon | rooftop_chase | RooftopAccent |
| skybridge_sprint | skybridge_chase | SkybridgeAccent |
| antenna_ascent | antenna_chase | AntennaAccent |
| cloud_deck_circuit | cloud_deck_chase | CloudDeckAccent |
| marble_foyer_loop | foyer_chase | FoyerAccent |
| stack_corridor | stack_chase | StackAccent |
| gallery_grand_oval | gallery_chase | GalleryAccent |
| vault_gate_gauntlet | vault_chase | VaultAccent |
| cascade_colossus | colossus_chase | ColossusAccent |
| aurora_amphitheater | aurora_chase | AuroraAccent |
| origami_orchard | origami_chase | OrigamiAccent |
| horizon_crown_finale | crown_chase | CrownAccent |

## Footwear / wardrobe (chase-cam)

- Kinetic Sole trail tint + density profile by `material_family` / archetype
- Side family stripe for crowded-field ID at gameplay FOV
- Wardrobe garments remain cosmetic; footwear vehicle owns handling
- `visual_lod` still budgets particles for 8-racer fields (does not claim 8p physical)

## Follow-on env / racing-feel (non-camera)

Camera identities + accents for cups 3–8 were already landed at `8c3ac55` and are **not repeated**. Subsequent env work:

- Data landmark IDs for cups 3–8 now sculpt distinct silhouettes in `CourseTrack._sculpt_landmark` (was default box).
- Pickup / rail / bounce density on cups 3–8 raised toward Stride levels (no catalog rebuild).
- Global boost FOV/spring punch strengthened in `CameraRig` without retuning per-track chase tables.

## Explicit non-claims

- Not palette-swap “final art.”
- Not human commercial track/footwear approval.
- Footage/builds reviewed digitally only; no fabricated human fun pass.
- `track_art_candidate` ≠ human-approved.
