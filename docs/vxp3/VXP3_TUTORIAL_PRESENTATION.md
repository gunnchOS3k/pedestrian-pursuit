# VXP-3 Tutorial Presentation

## Race
`TutorialCoach` shows non-blocking contextual tips (sprint, drift sparks, Perfect Step, boost, items, footwear).

## Pause
Tutorial Guide opens `TutorialDirector` grammar walkthrough (softened dim). Does not replace coach.

## Completion
- Coach tip `footwear_surfaces` dismissed → `ProgressionSave.mark_tutorial_done()`
- TutorialDirector finish still calls `mark_tutorial_done()` (idempotent)
- Production gate harness may also call `mark_tutorial_done()` as before

## Non-claims
Does not claim human tutorial comprehension validated.
