# Kinetic Sole original footwear — wave 1

Eight distinct original interpretations of existing registry vehicles, authored for the current Codex-owned Pedestrian integration. No third-party meshes, textures, fonts, logos or licensed character designs. Canonical IDs, families, movement archetypes, handling and collision rules remain unchanged. The existing Voltstep source and export are read-only references and their known hashes are checked before every run.

`author_wave1.py` is the editable geometry/material source. `python3 author_wave1.py --plan` checks the full 50-item registry and the eight source records without importing Blender or creating models. The source-only plan is not completed artwork.

When the shared heavy-operation slot is available, use Blender 4.0.2:

```sh
"/Applications/Blender 2.app/Contents/MacOS/Blender" --background --python art_source/footwear/wave1/author_wave1.py -- --ids all
```

Use `--ids reedline_circlers` or a comma-separated subset for a bounded retry. Each model receives its own unmerged, editable `.blend` under its registry-ID directory. Runtime GLBs and measured export/provenance data go only to `assets/models/footwear/wave1/`. Existing source files and runtime exports are not replaced. The `.gdignore` excludes editable Blender source from Godot's import scanner.

The eight designs have separate authored construction: street Circler ring stitching; long four-wheel inline fork and ratchet cuff; wide quad trucks and toe brake; separated cloud pods and air gap; scalloped aquatic fins and gills; tall ribbed frost galosh and snowglobe-look heel caps; closed-lacing Oxford/brogue details with two metal tap plates; upholstered sofa arms, tufted back, piping and wooden glide rails. Shared topology helpers do not supply one recolored common model.

All dimensions use meters, +X width, Blender −Y toe and Z up. The Y-up glTF export yields Godot +Z toe and Y up, matching Voltstep. Outsole contact is near Blender Z −0.06m. The source provides decorative manufacturing detail rather than changes to grounded racing physics. The galosh dome is opaque glazed geometry with inset flakes, not simulated transparent water/snow. Brogue dots are inset surface detail rather than drilled holes. Material roughness/metallic/emission are native PBR values; no external textures are required.

Inline and quad wheels retain named `WheelSpin_*` local-X root nodes and an illustrative one-second `WheelSpin` clip. Track names group the wheel animation at export. This is asset-level motion source; playback, looping, speed binding, contact correctness and race/garage behavior need actual Godot integration and assessment. Non-roller models inherit the existing runner's foot mounts and gait; no new character rig is claimed.

Runtime export consolidates static meshes while preserving separate wheel roots. Editable `.blend` files retain individual constructed objects and modifiers. The manifest reports actual bounds, triangle counts, hashes, Blender version and current acceptance state after export. Do not classify source code, a successful export or measured bounds as runtime visual acceptance. Distinct review and owner approval remain pending.

`HUMAN=false`, `RC2=false`, `V1=false`.

## Exported candidate checkpoint

All eight original models now have editable `.blend` sources and runtime GLBs. `SOURCE_PLAN.json` remains the earlier source-only preflight snapshot; `assets/models/footwear/wave1/WAVE1_MANIFEST.json` records the later actual exports and current unassessed-runtime status. `EXPORTED_GLB_INSPECTION.json` contains measurements read from the exported binary geometry and animation buffers, not just the generator's intended settings.

Both roller GLBs contain a `WheelSpin` animation with four rotation channels, sampled over one second. The current final meshes measure approximately 0.162–0.201m wide and 0.290–0.310m long; Godot Y contact is near −0.06m. Triangle counts span 1,466–5,500 per foot. Rollers use 17 material primitives per foot; the other shoes use 4–8. These are structural/size measurements, not actual-race performance or aesthetic clearance.

The first sandboxed Blender launch crashed in Metal startup before running Python. Its negative log is preserved as `EXPORT_FIRST_SANDBOX_STARTUP_FAILURE.log`. The authorized two-thread background retry exported all eight with Blender 4.0.2, exit 0; `EXPORT_SESSION.log` records it. The subsequent two-model fit correction widened only Inline/Oxford construction and also exited 0 (`FIT_CORRECTION_EXPORT.log`). First narrow fit studies remain under those models' `first_fit_study/` directories. The first generator is retained as `author_wave1_first_export.py`; `SOURCE_VERSIONS.json` maps both actual generator hashes to retained source files.

No render or Godot session was launched in this asset-authoring lane. The integration owner still needs actual race and garage inspection, material/import confirmation, speed-driven wheel animation, camera comparison, eight-racer performance measurements, distinct review and owner acceptance. These assets remain original exported art candidates until that assessment occurs.

The retained export logs include Weighted Normal warnings while objects are being constructed, before their final Auto Smooth assignment. The authoring code enables Auto Smooth on all meshes before saving the `.blend` and applying modifiers for export. Do not describe these as warning-free sessions or treat structural inspection as proof of final shading. Assess the resulting highlights and edges under actual game lighting before acceptance.
