# Wave E — Pedestrian Pursuit Alpha Depth (honest status)

Status: **Alpha progress, not content-complete, not RC.**

Date: 2026-08-08

## ADR-GAME-PP-001 targets vs this branch

| Target | Alpha state |
| --- | --- |
| ≥8 racers | Met (8 named runners in roster) |
| ≥8 tracks across ≥2 cups | Met (Sole Surge + Stride Circuit = 8 unique greybox courses) |
| ≥4 footwear | Met (Starter / Speed / Grip / Bounce Boots) |
| Items with counterplay | Met (6 items; warning_seconds + counterplay documented) |
| Modes Quick Race / Cup / Time Trial / Local MP | Entry points wired (Local MP is shared-screen Alpha, not polished splits) |

## What is real runtime depth

- Track JSON routes with unique layouts, checkpoints, shortcuts, rails, terrain, pickups
- Movement: foot drift tiers, Perfect Step window, boost, drafting, jump, slide/stomp, wall-kick scrape recovery, rail grind attach
- AI tiers (rookie/standard/ace) use look-ahead route planning; no invented top-speed cheats; soft recovery magnet only for Rookie when badly off-course
- `tools/ai_batch_sim.py` batch harness + `tests/test_content.py` / headless `TestRunner.gd`

## Explicitly not claimed

- Final art / audio (all cup tracks marked `REQUIRES_ART_PRODUCTION`)
- Content-complete launch polish or RC certification
- Online multiplayer
- Pixel-perfect Local MP split-screen presentation

## Smoke

```bash
python3 tools/validate_content.py
python3 tools/ai_batch_sim.py
python3 -m unittest tests/test_content.py
# Godot headless (Godot 4.5; same binary Anime Aggressors uses by default):
GODOT_BIN="$HOME/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot" \
  ./tools/run_godot_headless.sh
```

Post-merge headless evidence: `docs/PEDESTRIAN_MAIN_GODOT_HEADLESS_PASS.md`.  
Alpha-exit claim status: `docs/ALPHA_EXIT_STATUS.md` (**false**).
