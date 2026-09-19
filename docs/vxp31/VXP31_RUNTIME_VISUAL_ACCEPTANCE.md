# Runtime Visual Acceptance

Evidence class required: `REAL_RUNTIME_CAPTURE` — Godot loads the project, executes real scenes, PNG from rendered viewport.

Fixture boards from VXP-3 are `DETERMINISTIC_FIXTURE_CAPTURE` only and do **not** satisfy VXP-3.1 journey gates.

Driver: `tools/vxp31/visual_surface_driver.gd` via `--vxp31-capture` only.
Output: `artifacts/vxp31/capture/*.png`
Manifest: `artifacts/vxp31/manifests/VXP31_REAL_RUNTIME_CAPTURE_MANIFEST.json`

High-contrast dedicated mode: `NOT_IMPLEMENTED` (VXP-3 approximates via larger UI + colorblind markers only).
