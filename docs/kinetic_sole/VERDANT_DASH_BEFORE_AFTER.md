# Verdant Cascade + Dash Reed — before / after

Art direction: **KINETIC SOLE** (`docs/vxp3/VXP3_BRAND_SYSTEM.md`). Original only.

## Before (pre-pass on `bd9baac`)
- Verdant scenery: one flat backdrop box, one water cylinder, five cascade columns, four trunk+sphere trees.
- Track materials: flat roughness 0.78, no wet/moss read.
- Dash Reed footwear: single accent sole box + dark heel.
- Pose hooks covered start/boost/stumble/finish; jump/trick/drift lacked dedicated body language.
- HUD: default label colors; no runner chip.

## After (this pass)
- Verdant: misty fog/glow lighting, runoff basin, layered canopy trees, cliff terrace with real shelf collision, stone bridge landmark, Kinetic Sole start arch, lanterns, mist particles, wet track materials.
- Dash Reed: outsole / midsole yellow / kinetic orange upper / tread bars / speed chevron / heel flare + boost speed trail.
- Presentation poses for jump, trick, and drift wired from existing gameplay actions (physics unchanged).
- HUD: boost cyan, midsole-yellow speed label, high-speed heat modulate, `KINETIC SOLE · Dash Reed` chip.
- Camera: slightly more aggressive FOV / look-ahead for sense of speed (reduce-motion still respected).

## Runtime evidence
- Headless capture script: `tests/KineticSoleVerdantCapture.gd`
- Output directory: `artifacts/kinetic_sole_verdant/` (`01`–`04` PNGs + `CAPTURE_RUN.json`)
- Gate 1 must still print `INDEPENDENT_CLIENTS_RACED=true` after this art pass.

## Not claimed
- Not all eight courses.
- Not human fun approval.
- Not V1 / RC2.
