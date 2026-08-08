# Pedestrian Pursuit — Continuation V (digital closure)

**Branch:** `cursor/full-product-continuation-v-pedestrian-closure`  
**Base:** `origin/main` @ `c8db661` (#10)  
**Date:** 2026-08-08  
**Honesty note:** Full competitive AI matrix locked (`PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED`). Digital RC stays **PARTIAL** while art/audio/device cert remain open.

## Tokens

| Token | Earned? | Evidence |
| --- | --- | --- |
| `PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED` | **YES** | Full 8×4×8×3=768 Godot matrix, subset=false, ok=768, cheats=0, tier_order_ok; evidence `gate1/evidence/out/pp_competitive_ai_eval.json` |
| `PEDESTRIAN_BETA_CONTENT_COMPLETE_DIGITAL` | **YES** | retained from #10 + Local MP polish regressions |
| `PEDESTRIAN_DIGITAL_RC_READY` | **PARTIAL** | packaging + Local MP polish digital-complete; art/audio + device FPS still block store RC |
| Visual / store RC | **NO** | `data/art/REQUIRES_ART_PRODUCTION_INVENTORY.json` |

## What shipped (Continuation V)

1. **Full competitive AI matrix run** — 8×4×8×3=768, no subset env (evidence run / token print).
2. **Local MP polish** — vertical split cameras (`LocalMPSplitDirector`), P1 WASD/pad0 + P2 arrows/pad1, P1/P2 results tags, pause hint + either-player pause, a11y HUD scale/markers, career XP skipped for couch sessions.
3. **AI human control fix** — `AIRacerController` skips AI brain when `is_player` (P2 no longer AI-steered).
4. **Art honesty** — inventory updated with procedural digital-complete + greybox-cleared-for-digital-launch; cascade scenery densified; no fake finished audio banks.

## Verify

```bash
python3 tools/validate_content.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
bash tools/rc_packaging_check.sh

GODOT_BIN="$HOME/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot" \
  ./tools/run_godot_headless.sh

# Full competitive AI matrix (required to earn COMPETITIVE_AI token):
GODOT_BIN="$HOME/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot" \
  PP_AI_EVAL_TIME_SCALE=20 PP_AI_EVAL_MAX_SEC=5 \
  "$GODOT_BIN" --headless --path . --script res://tests/CompetitiveAiEvalRunner.gd
```

## Gaps (honest)

1. Final character/track/audio art — `REQUIRES_ART_PRODUCTION` (blocks full `PEDESTRIAN_DIGITAL_RC_READY`)
2. Public online / ranked — architecture only (private/dev)
3. Human device FPS certification for store RC
4. Editor playtest signoff pack
