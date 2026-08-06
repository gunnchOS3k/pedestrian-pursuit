# Gate 1 — Core Loop (Workstream E)

Branch: `cursor/gate-1-integrated-development-platform`

## Statuses
- `CORE_LOOP_IMPLEMENTED`
- `CORE_LOOP_AUTOMATED_EVIDENCE_PASS`
- `PHYSICAL_PLAYTEST_PENDING`

## Run automated evidence
See repo-specific runners under `gate1/tools/`.

## Schema
`gate1/contracts/game_core_loop.schema.json` (local copy of field-kit contract).

Required event fields: game, build_id, commit, platform, session_id, step, timestamp, result, state_checksum, evidence_type.

App launch alone is **not** core-loop completion.
