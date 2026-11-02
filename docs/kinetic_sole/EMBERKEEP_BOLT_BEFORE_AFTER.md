# Emberkeep Gauntlet + Bolt Harbor — before / after

Art direction: **KINETIC SOLE** (`docs/vxp3/VXP3_BRAND_SYSTEM.md`). Original only.

## Before
- Ember scenery: flat magma box and four tower stubs with orange caps.
- No citadel collision, forge vents, ash hazard read, or courtyard gate.
- Bolt Harbor footwear: generic Kinetic Sole stack without Harborclimb iron plates.
- Capture path not wired for Emberkeep.

## After (this pass)
- Emberkeep: ash/forge lighting, magma undercroft, basalt towers with collision, EmberkeepCitadel landmark, forge vents beside forge_vent_cut (off chord), hot ash terrain read, courtyard speed gate, Kinetic Orange start arch, ember particles.
- Bolt Harbor: larger Harborclimb Irons silhouette, Midsole Yellow midsole, clay upper, Kinetic Orange tread + blocky heel plates.
- Capture: WorldEnvironment wait, luma reject under 18, footwear rim, sole close-up + citadel landmark.
- HUD chip uses Kinetic Orange on `ember_fortress`.
- Integrated through `CourseTrack` → real `RaceScene`.

## Runtime evidence
- Headless capture: `tests/KineticSoleEmberkeepCapture.gd`
- Output: `artifacts/kinetic_sole_emberkeep/` (`01`–`04` PNGs + `CAPTURE_RUN.json`)
- Gate 1 must still print `INDEPENDENT_CLIENTS_RACED=true` after this art pass.

## Not claimed
- Not Stride Circuit courses (Tideglass → Mirage).
- Not eight-player online (two-client PASS ≠ 8p).
- Not human course / fun approval.
- Not V1.
