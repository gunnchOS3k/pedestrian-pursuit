# VXP-3.3 Owner Physical Review (Edmund)

Installed build: `com.gunnchos.pedestrianpursuit` **0.3.10 (14)** — left on Main Menu.

## Blockers to re-test (do not merge until PASS)
1. Start race → release all fingers → wait 10s: runner settles once; no sky bounce loop.
2. Neutral hands-off: no autonomous hard-right turn.
3. Left → release neutral; Right → release neutral.
4. RUN / JUMP land / DRIFT / BOOST feel intentional only.
5. Pause/resume and Home/fg do not leave sticky steer.

## Engineering note
Digital regressions + Pixel install evidence are recorded under `artifacts/vxp33/`.
`HUMAN_FUN` / `HUMAN_CONTROL_FEEL` / `MERGE_AUTHORIZED` stay false until you sign off.
