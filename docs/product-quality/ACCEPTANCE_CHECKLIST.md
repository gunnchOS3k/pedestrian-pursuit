# Acceptance Checklist — Pedestrian Pursuit

**Branch:** `cursor/product-quality-mobile-pass`  
**Date:** 2026-07-13

## Gates

| Gate | Status | Evidence |
|------|--------|----------|
| Cup state harness (4 rounds + save/load) | **PASS** | `docs/product-quality/evidence/local-cup/` |
| Visible Sole Surge cup (4 courses) | **PASS** | `docs/product-quality/evidence/visible-cup/` — verdant / ranch / prism / ember + final standings |
| Points / standings | **PASS** | `visible-cup.log` — 40 pts player |
| Signed Android RC + 16 KB | **NOT STARTED** | next controlled toolchain pass |
| Pixel full-cup | **NOT TESTED** | requires Android RC |
| PR ready | **No** | awaiting Android gates + verifier |

## Driver

```bash
/Applications/Godot-4.3.app/Contents/MacOS/Godot --path . -s res://tests/accept_visible_cup.gd
```

Log reports: `PASS points=40 standings=1. You — 40 pts | …`


## Godot 4.5 / 16 KB (2026-07-13)

- Editor 4.5.stable + matching templates: PASS
- CupFlowTest: PASS
- Signed internal RC 0.3.0 (4): built; 16 KB ELF align PASS; cert fingerprint recorded
- Pixel install: blocked on physical USB reconnect


## Visible cup 2026-07-14 (Godot 4.5)

- Driver: `tests/accept_visible_cup.gd` with `accept_test_mode` (1 lap; cleared after run)
- RESULT: failed=0, points=40, standings You — 40 pts
- Evidence: `docs/product-quality/evidence/visible-cup/` (per-course + results + final standings)
- Duration override docs: `ACCEPTANCE_TEST_DURATION.md`
- Limitation: finish uses acceptance checkpoint-assist after GO (not free-drive human play); courses show distinct authored environments in screenshots
