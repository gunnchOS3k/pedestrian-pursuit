# VXP-3.1.1 — Evidence Truth, Viewport, Local 2P & Accessibility Closure

Stacked draft lane on VXP-3.1 (PR #26). **Does not mutate** historical `artifacts/vxp31/*` gate or capture manifests.

## Goals
1. Gate SHA / digital closure mean what they say.
2. Viewport evidence records **actual PNG dimensions**.
3. Podium glyph gate validated from real presentation + capture.
4. Local 2P runtime presentation captured (HUD / pause / results).
5. Dedicated high-contrast runtime mode (designed palette, persisted).
6. `VXP311_DIGITAL_CLOSURE_PASS` = transparent AND of listed parts.

## Make targets
```bash
make vxp311-structural
make vxp311-capture
make vxp311-gates
```

## Artifacts
- `artifacts/vxp311/manifests/VXP311_CAPTURE_MANIFEST.json`
- `artifacts/vxp311/reports/VXP311_GATES.json`
- `artifacts/vxp311/reports/VXP311_EVIDENCE_INTEGRITY.json`
- `artifacts/vxp311/reports/VXP311_VISUAL_DEFECT_LEDGER.json`

## Human validation
See `VXP311_HUMAN_REVIEW_HANDOFF.md`. Human / Pixel / historical-rights remain **false** until owners act. Do not start the next broad VXP lane from this packet.
