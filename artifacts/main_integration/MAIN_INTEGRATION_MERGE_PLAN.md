# Main-integration ancestry / merge PLAN (owner approval required)

**Do not merge, retarget, force-push, or reset.** This file is a plan only.

## Current lane

| Item | Value |
| --- | --- |
| PR | #46 `lane-b/course-build-fix` |
| Tip (at plan authoring) | recover against remote tip; verify with `git rev-parse HEAD` (post cups 3–8 chase deepen) |
| RTM | `artifacts/quality_review/REQUIREMENTS_TO_EVIDENCE_MATRIX.md` (plan-only companion) |
| Owner package | `artifacts/quality_review/OWNER_PLAYABLE_REVIEW_PACKAGE.json` |
| Base | `main` (do not retarget) |
| Policy | recover latest; preserve newer; never reset/clean/force-push/merge |

## Ancestry check (operator)

```bash
git fetch origin main lane-b/course-build-fix
git merge-base --is-ancestor origin/main HEAD && echo "main is ancestor of tip" || echo "diverged — rebase/merge needs owner choice"
git log --oneline origin/main..HEAD | head -40
git log --oneline HEAD..origin/main | head -20
```

## Preferred non-destructive path (when owner approves)

1. Confirm Gate1 + Windows green on tip SHA.
2. Prefer **FF merge** of `lane-b/course-build-fix` → `main` only if tip is a fast-forward from `main`.
3. If diverged: owner chooses **merge commit** (preserve history) vs explicit rebase — agent must not invent rebase without approval.
4. Do **not** retarget PR base; do **not** squash-force; do **not** delete lane until post-merge verification.

## Post-merge verification checklist

- [ ] Gate1 on `main` tip
- [ ] Windows Pilot on `main` tip
- [ ] Championship catalog still 32 raceable / 32 track_art_candidate / HUMAN_* false
- [ ] 2-client Gate1 honesty still true; 8-human physical still false
- [ ] MoltenVK still reported false unless new Metal evidence landed

## Blockers for merge today

- Owner approval of this plan
- Live CI green confirmation on the tip about to merge (re-check after any new push)
- HUMAN_FUN / COURSE / RC2 / V1 remain false (expected — not merge blockers, honesty gates)
