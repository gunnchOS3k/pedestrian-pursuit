# Acceptance vs production race duration

| Setting | Production default | Acceptance (`accept_test_mode`) |
|---------|--------------------|----------------------------------|
| Laps | Course `lap_count` (typically 3) | `GameManager.accept_force_laps = 1` |
| Auto-accelerate | `false` | `true` |
| Path assist | off | `AcceptPathFollower` + checkpoint walk for finishability |

Selected only when `tests/accept_visible_cup.gd` sets `GameManager.accept_test_mode = true`.
These flags default to off and are cleared at the end of the acceptance driver.
They are **not** production defaults and must not be committed as enabled in export presets.
