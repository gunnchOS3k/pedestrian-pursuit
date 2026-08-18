# pedestrian-pursuit

Original arcade **foot racer** (Sole Surge Cup) for gunnchOS3k — Godot 4 gameplay with digital RC packaging.

> **Current release/state:** `INTEGRATED` game repo — digital RC packaging ≠ human device FPS certification; ≠ automatic Lab production runtime PASS.

Ecosystem portal: [gunnchos-research-portal](https://github.com/gunnchOS3k/gunnchos-research-portal) · Product charter: [gunnchOS3k_PRODUCT_CHARTER.md](https://github.com/gunnchOS3k/gunnchos-7gc-ai-ran-field-kit/blob/main/program/charter/gunnchOS3k_PRODUCT_CHARTER.md)

## What is this?

Pedestrian Pursuit Godot project: four-course cup, items, AI, local MP, Android export paths.

## Why does it exist?

A first-party athletic arcade experience for handheld/Student play journeys.

## Where does it fit?

Product Charter **layer 9**. Device Lab may package it; this README does not assert Lab 10/10 tokens.

## What is real today?

- Godot 4.3-authored project with cup + practice modes
- Dependency-free content tests + optional headless Godot suite
- Digital RC packaging scripts

## What is simulated / modelled?

- Procedural-final launch presentation assets where documented
- Competitive AI eval at time-scaled headless settings

## What is physical / external pending?

- Human device FPS certification
- Device Lab production-runtime earn on arbitrary hosts

## Try / inspect in 5 minutes

```bash
# Install Godot 4.x, import project.godot, press F5 → Start Four-Course Cup
python3 tools/validate_content.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## Architecture

`data/cups/` cup order; Godot scenes/scripts; `tools/` validators; Android export docs.

## Repo map

| Path | Role |
|---|---|
| `project.godot` | Game entry |
| `data/` | Courses/cups |
| `tools/` | Validators / RC / Android |
| `docs/` | Digital RC + AI eval notes |

## Interfaces

Packaging toward device-os Lab; input: keyboard/controller/touch.

## Tests

```bash
python3 tools/validate_content.py
bash tools/rc_packaging_check.sh
# Optional if Godot installed:
# ./tools/run_godot_headless.sh
```

## Evidence

[docs/PEDESTRIAN_DIGITAL_RC_STATUS.md](docs/PEDESTRIAN_DIGITAL_RC_STATUS.md), [docs/PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED.md](docs/PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED.md).

## Known gaps

Device FPS certification; Lab production runtime tokens; broader content.

## Beginner path

Run on foot, drift, trick, finish the cup — no cars.

## Intern path

Pass content validators; tweak one course JSON; re-run tests.

## Expert path

Headless AI matrix + RC packaging honesty vs human certification.

## Contribution path

Courses, AI, validators, Android docs. Keep originality/legal boundary.

## Current release / state

**INTEGRATED** digitally. `game_repo_not_lab_runtime_proof`.

## Claim boundary

No commercial 6G · digital RC ≠ human FPS cert · Cursor DRAFT-only.

---

## Retained detail (post–Cycle 3A front door)

Full prior README: [docs/history/README_PRE_WP012.md](docs/history/README_PRE_WP012.md).

Controls and Android build notes remain in that history file and under `docs/ANDROID_BUILD.md`.
