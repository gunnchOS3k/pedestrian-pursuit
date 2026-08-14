# ADR-GAME-PP-001 — Launch-scope exclusions (GAME-RC-003)

## Status
Accepted for digital launch-scope honesty (GAME-RC-003).

## Context
Pedestrian Pursuit ships 8 launch cup courses across two cups, tutorial, items, CPU, progression, achievements, settings, and a11y. Residual items must not silently count as launch gaps.

## Decision
The following are **explicitly excluded** from launch-required content:

| Item | Decision |
|------|----------|
| `sneaker_city_sprintway` | OUT OF LAUNCH CUP SET — present on disk as leftover; not a Sole Surge / Stride Circuit course |
| Human-painted hero meshes | OUT OF LAUNCH SCOPE — procedural-final art is the launch bar |
| Public online matchmaking | OUT OF LAUNCH SCOPE — OnlineArchitecture is private/dev scoped |
| Physical device FPS certification | PHYSICAL_PENDING — tracked separately as PEDESTRIAN_PHYSICAL_PERFORMANCE_PENDING |
| Challenge rail-attach / perfect-step windows | PARTIAL instrumentation — finish awards challenge flag; window scoring remains OPEN polish |

## Consequences
- `PEDESTRIAN_CONTENT_FEATURE_COMPLETE_DIGITAL` may be earned against the closed launch checklist.
- `FEATURE_COMPLETE_RC` / `POLISHED_RELEASE_CANDIDATE` remain false.
- CONTENT_MANIFEST keeps excluded items OPEN with notes.
