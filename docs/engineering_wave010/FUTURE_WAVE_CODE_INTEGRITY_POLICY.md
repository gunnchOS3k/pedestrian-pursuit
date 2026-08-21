# Future-Wave Code Integrity Policy

Applies to every future substantive wave merge recommendation in the gunnchOS3k ecosystem.

## Merge recommendation checks (required)

Before recommending a substantive wave merge, verify:

1. **Production independence** — Production code exists and runs independently of proof machinery (tests, fixtures, evals, evidence harnesses).
2. **No proof imports** — Production modules do not import `tests`, `artifacts`, mutation harnesses, or code-health evaluators.
3. **Canonical runtime tested** — Where automatable, the canonical runtime path is exercised by tests.
4. **Meaningful assertions** — Requirement / behavior tests use meaningful behavioral assertions (not `assert True`, empty `pass`, or always-pass gates).
5. **Mutation / sabotage coverage** — Critical changed behavior has mutation or sabotage coverage that fails under broken production.
6. **Fixture honesty** — Fixtures are truthfully classified (test/fixture vs production/field evidence).
7. **No wave duplicate canonical** — No duplicate Wave-specific canonical implementation that replaces or forks the accepted production path.
8. **Complexity hotspots** — New major complexity hotspots are avoided or explicitly registered as findings.
9. **Architecture docs** — Codebase map / architecture docs are updated when architecture materially changes.

## Severity vs merge blocking

| Severity | Blocks every merge recommendation? |
|----------|-------------------------------------|
| **New S0** | Yes — authenticity failure must be closed or explicitly owner-accepted before merge recommendation |
| **New S1** | Yes — high authenticity/maintainability risk blocks merge recommendation until remediated or owner-accepted |
| **S2** | No — medium structural debt does not block every merge; remain tracked |

## Non-claims

This policy does **not** assert `FULL_MUTATION_TESTING_COMPLETE`, nor that all portal/WAIKE defects are eliminated. It gates future waves against introducing new S0/S1 debt and against production/proof coupling.
