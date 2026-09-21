# VXP-3 — Pedestrian Pursuit Brand, Race Chrome & Player Presentation

Product name remains **Pedestrian Pursuit**. Internal art-direction label: **KINETIC SOLE** (not player-facing).

Concept: Footwear is the machine. The runner is the vehicle.

## What shipped
- Original brand pack under `assets/branding/vxp3/`
- Presentation theme helpers under `scripts/ui/vxp3/`
- Main menu recomposition, race HUD chrome, pause/results/toast skins
- Contextual `TutorialCoach` (non-blocking); Tutorial Guide on Pause
- Capture + gate tooling under `tools/vxp3/` and `artifacts/vxp3/`

## Honest limits
- `VXP3_CUSTOM_FONT_PENDING=true` (no cleared custom font bundled)
- `VXP3_PIXEL_PHYSICAL_CAPTURE_PASS=false` unless physical Pixel evidence exists
- Human visual / fun / a11y validation are **questions only** — not PASS
- Quarantined `assets/branding/launcher-icon.png` remains ledger_only (license null) — not promoted

## Commands
```bash
make vxp3-gates
make vxp3-capture
make headless-smoke
make stream-c-exhaust
```
