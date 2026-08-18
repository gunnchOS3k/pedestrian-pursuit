# Human playtest packet — Pedestrian Pursuit

**Status:** `HUMAN_QA_PENDING`

Automated tests and Device Lab notes are not human playtests. Do not fabricate participant evidence. Do not call this product a finished vertical slice.

## Why blocked

No signed human session exists on this branch for Pedestrian Pursuit.

## Prerequisite

A real player (not the CI agent) on desktop and, separately, on an **authorized** Pixel 6a.

## Journey to run

1. Godot 4: import `project.godot`, F5.
2. Start Four-Course Cup: Verdant Cascade → Cloverwind Ranch → Prism Apex → Emberkeep Gauntlet.
3. Practice a single course; confirm checkpoints, laps, fall recovery, items, AI field.
4. Local MP: split screen, P1/P2 controls.
5. Mobile overlay (touch) if on a touch display.
6. Results screen and return to menu. Pause/resume must unpause the tree.


## Record (no PII in public git)

Date, device, duration, crashes, unplayable steps. Store anonymized notes under `artifacts/human_qa/` privately if needed.

## Status transition

Documented playtest may drop “unsigned playtest” language. It does **not** become telecom/RQ evidence unless imported into a frozen experiment. Pixel 6a remains blocked until `docs/PIXEL_6A_ACCEPTANCE.md` is no longer unauthorized.
