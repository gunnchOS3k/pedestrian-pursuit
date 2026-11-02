# Prism Apex + Solen Pike — before / after

Art direction: **KINETIC SOLE** (`docs/vxp3/VXP3_BRAND_SYSTEM.md`). Original only.

## Before
- Prism scenery: sparse outer star spheres and three cyan cylinders.
- No apex spire collision, boost gates, or ribbon-cut frame.
- Solen Pike footwear: generic Kinetic Sole stack without Ghost Violet railfins.
- Capture path not wired for Prism.

## After (this pass)
- Prism: void floor + luminous basin, crystal pillars with collision, PrismApexSpire landmark, precision boost gates on speed-lane indices, ribbon-cut side rails (off chord), Ghost Violet start arch, shard particles, dark void lighting with cyan/violet fill.
- Solen Pike: larger Pikeapex Railfins silhouette, Midsole Yellow midsole, Ghost Violet upper, Boost Cyan tread + razor heel fins.
- Capture: WorldEnvironment wait, luma reject under 18, footwear rim, sole close-up + apex landmark shots.
- HUD chip uses Ghost Violet on `prism_void`.
- Integrated through `CourseTrack` → real `RaceScene`.

## Runtime evidence
- Headless capture: `tests/KineticSolePrismCapture.gd`
- Output: `artifacts/kinetic_sole_prism/` (`01`–`04` PNGs + `CAPTURE_RUN.json`)
- Gate 1 must still print `INDEPENDENT_CLIENTS_RACED=true` after this art pass.

## Not claimed
- Not Emberkeep / Stride Circuit courses.
- Not eight-player online (two-client PASS ≠ 8p).
- Not human course / fun approval.
- Not V1.
