# Pedestrian Pursuit — Beta then Digital RC (Continuation IV)

**Branch:** `cursor/full-product-pedestrian-beta-rc`  
**Base:** `origin/main` @ `822d7eb` (#9)  
**Date:** 2026-08-08  
**Honesty note:** Draft PR opened with digital Beta/RC progress; full competitive AI matrix token not locked yet.

## Tokens

| Token | Earned? | Evidence |
| --- | --- | --- |
| `PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED` | **NOT YET** | Runner + subset smoke green (54/54 ok, no cheats); full 8×4×8×3 matrix evidence run still required |
| `PEDESTRIAN_BETA_CONTENT_COMPLETE_DIGITAL` | **YES (digital systems)** | BetaProductStateTest PASS + catalog validation + modes/roster/materials/grammar |
| `PEDESTRIAN_DIGITAL_RC_READY` | **PARTIAL (digital packaging)** | `tools/rc_packaging_check.sh` + ProgressionSave v2 + perf/online scaffolds; store/device RC not claimed |
| Visual / store RC | **NO** | Art/audio `REQUIRES_ART_PRODUCTION` |

Do **not** headline Godot headless restore as this continuation’s accomplishment — that landed in #9.

## What shipped

1. **Launch roster (not palette-only)** — per-runner gameplay JSON (`data/racers/*.json`) with distinct stats; RaceScene assigns `racer_id` from profile.
2. **Footwear materials AI understands** — `material_family` + `surface_affinities`; TerrainZone + AIPathFollower brake/line bias by shoe.
3. **Foot-racing grammar + tutorials** — `data/mechanics/foot_racing_grammar.json` + `TutorialDirector` + Tutorial mode.
4. **Cups / tracks digitally complete** — shortcuts, rails, exploit notes, denser procedural scenery; exact art inventory at `data/art/REQUIRES_ART_PRODUCTION_INVENTORY.json`.
5. **Modes** — Quick Race, Cup, Time Trial/Ghost, Local MP, Challenges, Progression, Tutorial; online private/dev architecture scaffold.
6. **RC digital** — ProgressionSave v2 migration, perf budgets, clean-install packaging check, version `0.3.0-beta-rc`.
7. **AI eval harness** — `tests/CompetitiveAiEvalRunner.gd` (real CourseTrack + AI physics; no teleport/speed cheats).

## Verify

```bash
python3 tools/validate_content.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
bash tools/rc_packaging_check.sh

GODOT_BIN="$HOME/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot" \
  ./tools/run_godot_headless.sh

# Full competitive AI matrix (required to earn COMPETITIVE_AI token):
GODOT_BIN="$HOME/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot" \
  PP_AI_EVAL_TIME_SCALE=14 PP_AI_EVAL_MAX_SEC=5 \
  "$GODOT_BIN" --headless --path . --script res://tests/CompetitiveAiEvalRunner.gd
```

## Gaps (honest)

1. Full 768-cell Godot AI matrix evidence not yet token-locked
2. Final character/track/audio art — `REQUIRES_ART_PRODUCTION`
3. Public online / ranked — architecture only (private/dev)
4. Human device FPS certification for store RC
5. Local MP split-screen camera polish
6. Editor playtest signoff pack
