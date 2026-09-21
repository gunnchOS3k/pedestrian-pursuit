# VXP311 High Contrast

## Design
Dedicated `AccessibilitySettings.high_contrast` (default **false**).

Palette (not pure black + neon):
- Background `#141820`
- Panel `#222A38`
- Foreground `#F7F4EC`
- Accent `#E8A317`
- Focus ring `#F0D060`
- Warn `#E85D4C`

Applied through `Vxp3Brand` / `Vxp3Presentation` on Main Menu, Race HUD (incl. wrong-way / item-adjacent chrome), Pause, Results, and focus styles on primary CTAs.

## Persistence
Saved under `user://accessibility.cfg` key `a11y/high_contrast`.  
Configs **without** the key load as `false` (compatible with older saves).

## Captures
- `a11y_high_contrast_main_menu`
- `a11y_high_contrast_race_hud`
- `a11y_high_contrast_pause`
- `a11y_high_contrast_results`

## Still false
`VXP311_HUMAN_LOW_VISION_VALIDATION_PASS` / human a11y — owner visual review only.
