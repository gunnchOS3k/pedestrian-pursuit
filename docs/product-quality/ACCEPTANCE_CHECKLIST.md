# Acceptance Checklist — Pedestrian Pursuit / Sole Surge

| Gate | Status | Evidence |
|------|--------|----------|
| Animated runners (not capsules) | **PARTIAL** | `RacerVisual.gd` procedural humanoid + limb swing on player + 3 AI; capsule meshes hidden |
| Multiple AI runners | **PARTIAL** | RaceScene spawns 3 AI with path offsets |
| Wrong-way detection HUD | **PARTIAL** | `RaceHUD` WRONG WAY vs next checkpoint velocity |
| Cup standings | **PARTIAL** | `GameManager.cup_standings` + ResultsScreen lines |
| Sole Surge 4-course local cup | **PARTIAL** | Content validates; `CupFlowTest.gd` pass (4 rounds/standings accumulation). Physics playthrough of all four courses still required before APK |
| Mini-map | **PARTIAL** | `MiniMap.gd` wired into RaceHUD |
| Release APK / Pixel | **NOT TESTED** | ADB empty |
| PR | **No** | |

## Courses

1. `verdant_cascade_circuit`
2. `cloverwind_ranch`
3. `prism_apex`
4. `emberkeep_gauntlet`

`tools/validate_content.py` — PASS (2026-07-13)
