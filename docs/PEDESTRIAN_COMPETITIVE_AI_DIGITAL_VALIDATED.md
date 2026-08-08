# Competitive AI digital validation — Continuation V

**Token:** `PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED`  
**Date:** 2026-08-08  
**Godot:** 4.5.stable.official.876b29033  
**Command:** `env -u PP_AI_EVAL_SUBSET PP_AI_EVAL_TIME_SCALE=20 PP_AI_EVAL_MAX_SEC=5 Godot --headless --path . --script res://tests/CompetitiveAiEvalRunner.gd`

## Results

| Field | Value |
| --- | --- |
| subset | false |
| match_count | 768 |
| expected_count | 768 |
| ok_count | 768 |
| error_count | 0 |
| physics_cheats | 0 |
| tier_order_ok | true |
| avg_progress_ratio | ~0.822 |
| by_tier.rookie.avg_progress | ~0.782 (n=256) |
| by_tier.standard.avg_progress | ~0.831 (n=256) |
| by_tier.ace.avg_progress | ~0.852 (n=256) |
| wall_time_sec | ~747 |
| token_earned | true |

Full machine JSON (gitignored runtime path): `gate1/evidence/out/pp_competitive_ai_eval.json`.

## Matrix

8 launch racers × 4 footwear × 8 tracks × 3 tiers (`rookie` / `standard` / `ace`) = **768**.
