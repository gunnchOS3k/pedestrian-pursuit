# VXP311 Accessibility Regression

## Covered digitally
| Mode | Status |
| --- | --- |
| Larger UI | Existing + capture |
| Colorblind-safe HUD markers | Existing + capture |
| Reduce motion | Existing + capture |
| High contrast | **New** dedicated flag + captures |

## Tests
- `tests/G2C6RuntimeTest.gd` — HC persistence + legacy missing-key default
- Production gate harness — `settings_a11y_high_contrast` step

## Human
Low-vision / human a11y validation remain **false**. Questions for owners are in `VXP311_HUMAN_REVIEW_HANDOFF.md` (unanswered).
