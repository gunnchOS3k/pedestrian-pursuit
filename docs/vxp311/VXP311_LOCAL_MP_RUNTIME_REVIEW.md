# VXP311 Local MP Runtime Review

## Scope
Capture-driver only. **No MP rule changes.**

## Required REAL_RUNTIME surfaces
| ID | Intent |
| --- | --- |
| `local2p_race_hud` | Split-session HUD with non-color-only P1/P2 identity cues (`RoleHint` text). |
| `local2p_pause` | Pause with Local MP hint (either player may pause; career save unchanged). |
| `local2p_results` | Results titled for Local MP with `(P1)` / `(P2)` in field lines. |

## How capture enables Local MP
`GameManager.start_local_mp(track, 2)` then load `RaceScene.tscn` — same production path as the Local 2P menu button.

## Gate
`VXP311_LOCAL_MP_RUNTIME_PRESENTATION_PASS` stays false until all three surfaces validate as `REAL_RUNTIME_CAPTURE` with non-trivial PNGs.
