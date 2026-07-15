# Pedestrian Pursuit Pixel — 0.3.9

## Artifact
- APK: `build/android/pedestrian-pursuit-release.apk`
- versionName `0.3.9` / versionCode `13`
- SHA-256: `a19bda82cfba9050677bb476ef90708db3de2f178add91d256a2d2f944e6e828`
- Package: `com.gunnchos.pedestrianpursuit`

## Root cause of Lap 1 forever (0.3.6–0.3.8)
Player repeatedly drove off the racing line, fell into the void, and recovered to the start line without ever registering checkpoint order. Path-follower closest-point lookups yanked assist backward.

## Fix (0.3.9)
- Arcade `AIPathFollower`: speed-based forward progress + lateral magnet onto the racing line (Android soft-assist + AI).
- Distance-polled checkpoints (`Checkpoint.gd`) in addition to Area3D enters.
- Soft Android RUN assist (player still holds accelerate; no `accept_force_laps` / no fake gate stepping for production).
- Fake accept checkpoint stepping gated to `accept_force_laps > 0` only.

## Pixel evidence (serial 27211JEGR06194)
| Shot | Result |
|------|--------|
| `v039-end.png` | Course 1 Race Complete — Verdant Cascade, 01:30.62 |
| `v039c2-end-center.png` | Course 2 of 4 — Cloverwind Ranch results, 15 pts |
| `v039c3-end-center.png` | Course 3 of 4 — 18 pts, 04:50.61 total |
| `v039-cup-final.png` | **Cup Complete!** Emberkeep Gauntlet — Course 4 of 4, 23 pts, 06:39.25 total |
| `pp-v039-laps.mp4` | Course 1 drive recording |

Lap HUD progression on course 1: Lap 1 → 2 → 3 proven (`v039-t30/60/90-hud.png`).

## Status labels
- **Implemented + compiled + Pixel-tested (full 4-course × 3-lap cup):** yes for 0.3.9 Sole Surge Cup with RUN holds + soft path assist.
- **Not claimed:** production-ready; independent verifier; AI place accuracy (HUD pos vs results list mismatch noted); desktop autotest verified beyond headless first-lap probe.

Awaiting Edmund Gunn Jr. for merge / production-ready.
