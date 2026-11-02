# Cloverwind Ranch + Mira Lane — before / after

Art direction: **KINETIC SOLE** (`docs/vxp3/VXP3_BRAND_SYSTEM.md`). Original only.

## Before
- Ranch scenery: flat grass box, four hay cylinders, two timber crosses.
- Track materials: flat packed dirt, no dusty warm read.
- Mud / barn alley present in data only — no barn collision landmark.
- Mira Lane footwear: generic Kinetic Sole stack without Grip Green mud read.
- Capture path could write near-black early PNGs.

## After (this pass)
- Cloverwind: sunlit ranch lighting, clover field patches, hay stacks, timber fence ring, timber race gates, barn with collision, mud switchback read, windmill landmark, Grip Green start arch, dust particles.
- Mira Lane: larger Lanewind Tempo Flats silhouette, Midsole Yellow midsole, sky upper, Grip Green tread bars + heel wing for mud readability.
- Capture: wait for WorldEnvironment, reject frames with mean luma under 18, footwear rim light, sole close-up camera.
- HUD chip uses Grip Green on `windy_ranch`.
- Integrated through `CourseTrack` → real `RaceScene` (not a showcase scene).

## Runtime evidence
- Headless capture: `tests/KineticSoleCloverwindCapture.gd`
- Output: `artifacts/kinetic_sole_cloverwind/` (`01`–`04` PNGs + `CAPTURE_RUN.json`)
- Gate 1 must still print `INDEPENDENT_CLIENTS_RACED=true` after this art pass.

## Not claimed
- Not Prism Apex / Emberkeep / Stride Circuit courses.
- Not eight-player online (two-client PASS ≠ 8p).
- Not human course / fun approval.
- Not V1.
