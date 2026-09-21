# VXP311 Before / After

## Evidence honesty
| Topic | VXP-3.1 (PR #26 tip) | VXP-3.1.1 |
| --- | --- | --- |
| Gate SHA | Trailed tip (`ab8111e` vs `6e63861`) | New VXP311 stamp + match policy |
| Digital closure | True without podium/local MP | Explicit AND of `digital_closure_parts` |
| Viewport IDs | Metadata often claimed 1280 for all | PNG IHDR must match requested |
| High contrast | NOT_IMPLEMENTED | Dedicated setting + captures |
| Local 2P presentation | Gate false / not captured | Required `local2p_*` surfaces |

## Presentation
| Surface | After |
| --- | --- |
| Podium | Texture glyphs + accessible text (validated in VXP311) |
| High contrast | Charcoal/paper/amber theme across menu/HUD/pause/results |
| Local 2P | HUD role hint, pause hint, P1/P2 results tags |

PNGs: `artifacts/vxp311/capture/` and mirrored `artifacts/vxp311/after/`.
