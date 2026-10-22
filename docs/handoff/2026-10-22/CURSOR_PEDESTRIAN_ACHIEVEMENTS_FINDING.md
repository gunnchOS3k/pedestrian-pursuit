# Pedestrian Pursuit RC_GATE achievement count — no defect on current tip

Official V1 and RC2 remain NOT READY. This note does not change achievement rules, text, icons, unlock conditions, or visual identity.

## Sources

- Repo: `gunnchOS3k/pedestrian-pursuit` (`origin` = `https://github.com/gunnchOS3k/pedestrian-pursuit.git`)
- Isolated branch: `eng/cursor-v1-pedestrian-achievements`
- Base: `origin/main` `957ff95b89d0516855ea61ddba19224a0583c3f8` (Merge pull request #41 from gunnchOS3k/v1/tutorial-dismiss)
- Worktree: `.worktrees/cursor-v1-pedestrian-achievements`
- Dirty main checkout `release/v1-in-app-feedback` `0d561835878f39b67b45778adabbf7431f9c67d7` was not edited
- Cited artifact: `artifacts/game_rc_003/VP_PEDESTRIAN_GAME_RC_003_INDEPENDENT_RESULT.json` (generated 2026-08-14, verified tip `cef6d64dc7822eeb441118eb74f82d85c261d900`)
- No `AGENTS.md` in this checkout

## Reproduced command

Run on the isolated worktree at base `957ff95b89d0516855ea61ddba19224a0583c3f8`:

```
python3 tools/validate_game_rc_contracts.py
```

Exit code: `0`

```
GAME_RC_CONTRACTS_OK game=pedestrian-pursuit achievements=12 open_modes=['public_online']
```

The validator has no focused mode. It was not re-run with Godot, exports, or asset imports.

## Classification

No code defect on the current tip. Do not invent a gate count.

| Field | Value |
| --- | --- |
| `release/ACHIEVEMENTS.json` catalog length | 12 |
| `release/RC_GATE.json` `achievements.count` | 12 |
| `achievements.tested_count` | 12 |
| Validator rule | `int(gate.achievements.count or 0) == len(catalog)` |

Catalog ids, unchanged:

1. `pp.first_stride`
2. `pp.finish_line`
3. `pp.podium`
4. `pp.pause_and_breathe`
5. `pp.cup_complete`
6. `pp.time_trialist`
7. `pp.rail_runner`
8. `pp.mud_grip`
9. `pp.mileage`
10. `pp.stride_circuit`
11. `pp.hidden_hat_trick`
12. `pp.challenge_set`

## Historical failure (already repaired on main)

The cited artifact records `python3 tools/validate_game_rc_contracts.py → FAIL RC_GATE achievement count mismatch` against tip `cef6d64`. At that commit, `release/RC_GATE.json` has no `achievements` key, so the validator treats the count as `0` while the catalog length is `12` and appends `RC_GATE achievement count mismatch`.

That bookkeeping gap was closed by ancestor `7add16e074b0cd7abfa30b0753c924c3c20a63f5` (`fix(GAME-RC-003): restore RC_GATE achievements count + honest platform matrix`), which is contained in `957ff95`. This branch does not edit `release/RC_GATE.json` or `release/ACHIEVEMENTS.json`.

## Storage

`df -h` on this volume after the worktree: 460Gi size, 412Gi used, 15Gi available, 97% capacity. Below the 18 GiB heavy-export reserve. Python contract validation only.

## Claim boundary

`POLISHED_RELEASE_CANDIDATE`, `FEATURE_COMPLETE_RC`, and `HUMAN_PLAYTEST_VALIDATED` stay false in `release/RC_GATE.json`. This finding does not make Official V1 or RC2 ready. Portal ledger was not edited. B02 stays CRITICAL.
