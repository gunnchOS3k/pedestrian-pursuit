# Pedestrian Pursuit — Alpha-exit status (honest)

**Alpha exit claimed:** **false**  
**Date:** 2026-08-08  
**Branch focus:** post-merge Godot validation + first Alpha-exit gap work

## Gate snapshot

| Gate | State |
| --- | --- |
| Godot headless on main (`PEDESTRIAN_MAIN_GODOT_HEADLESS_PASS`) | **PASS** (see `docs/PEDESTRIAN_MAIN_GODOT_HEADLESS_PASS.md`) |
| Wave E content floors (8 tracks / 2 cups / 4 shoes / 6 items / 8 runners) | Met in data + headless build |
| Tutorial / How to Play | **Started** — Main Menu overlay (not a full first-run coach) |
| Settings / a11y | Present (reduce motion, larger UI, auto-accel, colorblind HUD) + persist smoke |
| Progression polish | Cup save/resume wired; no career unlock tree / reward cadence polish |
| Local MP presentation | Shared-screen Alpha entry only — not split polish |
| Art / audio | **REQUIRES_ART_PRODUCTION** on cup tracks |
| Editor playtest signoff | Not claimed |

## Remaining Alpha-exit gaps (non-exhaustive)

1. True first-run tutorial (practice lane, gated prompts, not just a How to Play panel)
2. Progression polish (unlock surfacing, cup trophy summary, TT PB board UX)
3. Local MP camera / input clarity for shared screen
4. Final greybox→art pass + audio (explicitly out of “code green”)
5. Displayed Godot editor playtest evidence pack

Do not treat Wave E depth or headless green as Alpha exit.
