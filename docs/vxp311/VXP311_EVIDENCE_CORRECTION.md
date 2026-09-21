# VXP311 Evidence Correction

## Live audit (PR #26 head `6e63861`)
| Issue | Finding |
| --- | --- |
| Gate SHA | Committed `VXP31_GATES.json` still stamped `ab8111e…` while tip is `6e63861…` (trails). Not rewritten here. |
| Podium gate | `VXP31_PODIUM_FINAL_GLYPH_PASS=false` while ledger VD-001 FIXED — emitter scanned `ResultsScreen.gd` for `PodiumRow` (lives in `Vxp3Presentation.gd`). |
| Digital closure | `VXP31_DIGITAL_CLOSURE_PASS=true` without requiring podium or local MP. |
| Viewport metadata | Manifest listed `resolution: 1280x720` for 1366/1600/pixel IDs even when PNG IHDR differed. |
| High contrast | Explicitly `NOT_IMPLEMENTED`. |

## Correction policy
- **New** `artifacts/vxp311/**` evidence only.
- Historical VXP31 gate/manifest files are left as-is (honest history).
- `digital_closure_parts` lists every AND input with no hidden exclusions.
- Human / Pixel physical / historical-rights stay false.
