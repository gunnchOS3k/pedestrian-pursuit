# Pedestrian Pursuit — Mac Metal / MoltenVK physical review build packet

**Status:** prepare-only. `moltenvk_metal_pass = false`. Not a certificate.

## Purpose

Give a human operator a reproducible display-backed Metal review path on Darwin.
This packet does **not** claim a pass from Gate1 Linux, Windows Pilot, or Darwin headless GL.

## Historical failure (honest)

- Symptom: `SIGSEGV` in `mvk::SPIRVToMSLConverter` when the Metal / MoltenVK path is taken.
- Reconfirmed historically on Godot 4.7.1 (`a13da4feb`).
- Headless + `--rendering-driver opengl3` is packaging/smoke only — **not** Metal.

## Required machine

- macOS host with GPU display (not SSH-only headless if Metal path is under test)
- Godot 4.7.1 stable official (`a13da4feb`) matching CI/project features
- Pedestrian tip under review (record exact SHA below)

## Build / launch steps (operator)

1. Check out exact tip SHA (fill after export): `________________`
2. Confirm `project.godot` features include Godot 4.5+ / 4.7 as shipped.
3. Launch **windowed** (no `--headless`), prefer default Metal backend:
   ```bash
   godot --path . --rendering-driver metal
   ```
   If the binary rejects `metal`, launch without forcing opengl3 and record the active driver from the Godot log banner.
4. Enter Solo / PartyLink / Cup race on `verdant_cascade_circuit`, complete ≥1 lap with visible chase camera.
5. Capture:
   - screenshot of race in progress
   - Godot console log (must show renderer = Metal / Vulkan-via-MoltenVK as applicable)
   - process exit code (0 vs SIGSEGV)
6. Store under `artifacts/moltenvk/human_review/<date>/` privately; do not invent a pass.

## Negative / expected-fail documentation

If SIGSEGV recurs in `SPIRVToMSLConverter`, attach the crash report and keep `moltenvk_metal_pass=false`.
Do not reinterpret Windows Pilot or Gate1 green as Metal green.

## Explicit non-claims

- Not COURSE_ACCEPTED / HUMAN / RC2 / V1
- Not 8-human physical PartyLink
- Not commercial art approval
- Candidate racing camera / env / vehicle art remains candidate ≠ commercial
