# Mac MoltenVK / Metal status (honest)

**Verdict (this tip / this machine):** `moltenvk_metal_pass = true` for **Verdant display-backed Metal observe** on Apple M2 / Godot 4.7.1.

**Still false:** COURSE_ACCEPTED / HUMAN / RC2 / V1; physical 8-human PartyLink; commercial art.

## What passed (S7)

- Darwin **Metal 4.0 Forward+** (Apple M2) windowed Godot launch (not `--headless`, not forced `opengl3`).
- `VerdantRaceSceneObserve` on `verdant_cascade_circuit`: COMPLETED_LAPS=3, RESULTS_PATH=true, FINISH_TRIGGER=true, REACQUIRE=0, TELEPORT_FALSE_FINISH=false.
- Evidence: packet `shift-s7-pedestrian-continue-20261030/moltenvk-metal-observe.log` (+ short boot `moltenvk-metal-probe.log`).

## What this is **not**

- Not a claim that every historical MoltenVK/SPIRV crash is gone on every Mac.
- Historical `SIGSEGV` in `mvk::SPIRVToMSLConverter` remains documented; this tip re-tested without that crash on M2.
- Not Gate1 Linux green ⇒ Metal; Gate1 content/Windows remain separate CI surfaces.
- Headless GL remains packaging/smoke only when Metal is not the active driver.

## Operator rule

Re-test Metal on the exact tip under review with `--rendering-driver metal` (no headless). Keep COURSE/HUMAN/RC2/V1 false until owner authority.
