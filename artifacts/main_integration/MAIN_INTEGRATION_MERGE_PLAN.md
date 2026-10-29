# Main-integration ancestry / merge PLAN (owner approval required)

**Do not merge, retarget, force-push, or reset.** This file is a plan only.

## Current lane

| Item | Value |
| --- | --- |
| PR | #46 `lane-b/course-build-fix` |
| Tip (at plan authoring) | stamp with `git rev-parse HEAD` after FF-push (PVS RTM + env deepen atop `8c3ac55`) |
| Prior camera checkpoint | `8c3ac55817dc4b21b3c08f8b2c0a159a2c3c7112` (cups 3–8 chase/accent — do not repeat) |
| RTM | `artifacts/quality_review/REQUIREMENTS_TO_EVIDENCE_MATRIX.json` (`GUNNCHOS3K_PVS@1.0.0`, pin `45b456617002569c33a5a27fe30d5cf8be5a7032`) |
| Owner package | `artifacts/quality_review/OWNER_PLAYABLE_REVIEW_PACKAGE.json` |
| Base | `lane-b/course-gameplay-fix-cup-resume` (do not retarget) / eventual `main` only with owner |
| Policy | recover latest; preserve newer; never reset/clean/force-push/merge |

## Ancestry check (operator)

```bash
git fetch origin main lane-b/course-build-fix lane-b/course-gameplay-fix-cup-resume
git merge-base --is-ancestor origin/main HEAD && echo "main is ancestor of tip" || echo "diverged — rebase/merge needs owner choice"
git log --oneline origin/main..HEAD | head -40
git log --oneline HEAD..origin/main | head -20
```

## Preferred non-destructive path (when owner approves)

1. Confirm Gate1 + Windows green on **exact tip SHA**.
2. Prefer **FF merge** of `lane-b/course-build-fix` → `main` only if tip is a fast-forward from `main`.
3. If diverged: owner chooses **merge commit** (preserve history) vs explicit rebase — agent must not invent rebase without approval.
4. Do **not** retarget PR base; do **not** squash-force; do **not** delete lane until post-merge verification.

## Exact-head CI (prior tip)

| Check | SHA | Run | Conclusion |
| --- | --- | --- | --- |
| Gate 1 | `8c3ac55817dc4b21b3c08f8b2c0a159a2c3c7112` | `40935904745` | success |
| Windows Pilot 0 | `8c3ac55817dc4b21b3c08f8b2c0a159a2c3c7112` | `40935904630` | success |

Re-check Gate1 + Windows on the new tip after FF-push before any merge.

## Post-merge verification checklist

- [ ] Gate1 on `main` tip
- [ ] Windows Pilot on `main` tip
- [ ] Championship catalog still 32 raceable / 32 track_art_candidate / HUMAN_* false
- [ ] 2-client Gate1 honesty still true; 8-human physical still false
- [ ] MoltenVK still reported false unless new Metal evidence landed
- [ ] RTM still validates `GUNNCHOS3K_PVS@1.0.0` with `independent_review=not_started`

## Blockers for merge today

- Owner approval of this plan
- Live CI green confirmation on the tip about to merge (re-check after any new push)
- HUMAN_FUN / COURSE / RC2 / V1 remain false (expected — not merge blockers, honesty gates)
