# VXP311 Human Review Handoff

**Do not answer these on the owner's behalf.** Digital closure ≠ human validation.

## Curated 12-screen set
Copy or open from `artifacts/vxp311/capture/` (also staged under `artifacts/vxp311/human_review/` when packaged):

1. `main_menu_default.png`
2. `main_menu_focus_race.png`
3. `a11y_high_contrast_main_menu.png`
4. `runner_select.png`
5. `footwear_select.png`
6. `race_hud_normal.png`
7. `a11y_high_contrast_race_hud.png`
8. `local2p_race_hud.png`
9. `pause_menu.png` / `local2p_pause.png`
10. `results_podium.png`
11. `local2p_results.png`
12. `viewport_1600x900.png` (confirm sharpness vs 1280)

## Questions for human owner
1. Are podium glyphs readable as place markers (not placeholder text)?
2. Does high-contrast remain comfortable (not harsh neon on pure black)?
3. Can you identify P1 vs P2 without relying on color alone?
4. Any HUD overlap or clipping at 1366 / 1600 / Pixel-logical 960×540?
5. Does Local 2P pause/results copy feel correct for a couch session?
6. Any S1/S2 visual defects still open that digital tools should fix?

## Gates that stay false until humans act
- `VXP311_HUMAN_VISUAL_VALIDATION_PASS`
- `VXP311_HUMAN_FUN_VALIDATION_PASS`
- `VXP311_HUMAN_A11Y_VALIDATION_PASS`
- `VXP311_HUMAN_LOW_VISION_VALIDATION_PASS`
- `VXP311_PIXEL_PHYSICAL_CAPTURE_PASS`
