# Pedestrian Pursuit — Godot headless pass (post-merge main)

**Token:** `PEDESTRIAN_MAIN_GODOT_HEADLESS_PASS`  
**Date:** 2026-08-08  
**Base SHA:** `451124c6e8106d995928e35d2a88d2f49706ad4e` (`origin/main`)

## Godot runtime

| Field | Value |
| --- | --- |
| Binary | `/Users/gunnchos/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot` |
| Version | `4.5.stable.official.876b29033` |
| Source | Same path used by Anime Aggressors (`tmp/aa-verify-project-report.json` / PR48 report) |
| Project features | Godot 4.5 + GL Compatibility (`project.godot`) |

## Suites (all PASS)

```bash
GODOT_BIN="$HOME/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot" \
  ./tools/run_godot_headless.sh
```

| Step | Result |
| --- | --- |
| `--import` | PASS |
| `--quit-after 2` startup | PASS |
| `tests/TestRunner.gd` (2 cups / 8 courses + lap/catalog floors) | PASS |
| `tests/G2C6RuntimeTest.gd` (device roles / a11y / telemetry) | PASS |
| `tests/CupFlowTest.gd` (cup points + save/load) | PASS |
| `tests/AlphaProductStateTest.gd` (modes, items, AI tiers, ghost, Local MP RaceScene, MainMenu) | PASS |

## Repair included in this pass

Godot 4.5 typed-inference parse failures blocked RaceScene script load:

- `scripts/items/ItemManager.gd` — explicit `Vector3` / `Node3D` casts in pulse-horn lambda
- `scripts/race/RaceManager.gd` — explicit `int` for place estimate
- `scripts/ai/AIRacerController.gd` — defensive `held_item_id` access when ItemManager script fails to attach

## Not claimed by this token

- Alpha exit / content-complete / RC
- Final art / audio (tracks remain `REQUIRES_ART_PRODUCTION`)
- Polished Local MP split-screen
- Signed Godot editor playtest on a display
