# Mac MoltenVK / Metal status (honest)

**Verdict:** `moltenvk_metal_pass = false`

## What passed

- Darwin **headless + opengl3** two-process race (appearance sync + lap honesty).
- Evidence: `artifacts/independent_two_process/INDEPENDENT_CLIENTS_RACE_RESULT.json`
- Log: `artifacts/independent_two_process/TWO_PROCESS_RACE.log`

## What did **not** pass

- Native Mac **Metal / MoltenVK** windowed or display-backed race.
- Historical symptom remains: `SIGSEGV` in `mvk::SPIRVToMSLConverter` when the Metal path is taken.
- Reconfirmed 2026-10-29 on Godot 4.7.1 (`a13da4feb`): even `--headless --display-driver headless --rendering-driver opengl3 --script` still aborted in `mvk::SPIRVToMSLConverter` on this Darwin host — do not treat local Mac script exit as Gate1 evidence.
- Headless GL (when it works) is packaging/smoke evidence only — **not** a Metal certificate.
- Linux Gate1 CI remains the authoritative Godot script gate.

## Operator rule

Do not claim Mac MoltenVK/Metal pass from Gate1 Linux CI, Windows Pilot, or Darwin headless GL. Re-test Metal only with an explicit display-backed Godot Metal run and a new dated evidence file.
