# Manual Device Runbook — Pedestrian Pursuit (Gate 1)

Statuses target: `CORE_LOOP_IMPLEMENTED` · `CORE_LOOP_AUTOMATED_EVIDENCE_PASS` · `PHYSICAL_PLAYTEST_PENDING`

## Preconditions
- Branch: `cursor/gate-1-integrated-development-platform`
- Device charged; screen recording permission granted
- Log collector ready: `gate1/tools/log_collector.*`

## Core loop (must complete — launch alone is insufficient)
1. Launch
2. Select racer + course
3. Start race
4. Movement
5. Drift/boost or mastery
6. Item and/or obstacle interaction
7. Finish
8. Results
9. Restart/rematch

## Pass criteria
- Every step above observed on device
- JSONL events collected (or manual checklist signed) with schema fields present
- Save/results screen captured; rematch/restart verified
- Accessibility spot-checks completed (`gate1/evidence/accessibility_checks.json`)

## Fail criteria
- Soft-lock, crash, missing results, or inability to rematch/restart
- Using copyrighted ripped audio (Beat Link) or claiming complete species coverage (Archive of Life)
