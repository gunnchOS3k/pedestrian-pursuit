# Character Performance Report — Pedestrian Pursuit

**Build:** `0.3.1` / versionCode `5`
**APK:** `build/android/pedestrian-pursuit-release.apk`
**SHA-256:** `d9d109b97a210d8d371c754bfcf10b35729816954ab8dcf82c4654268fa6796e`
**Device:** Pixel expected serial `27211JEGR06194` — **not attached** at measurement time (2026-07-15).

## Status

| Signal | Result |
| --- | --- |
| Signed non-debug APK produced from character-life branch | PASS |
| Package `com.gunnchos.pedestrianpursuit` | PASS |
| 16 KB ELF LOAD alignment (arm64) | PASS |
| Full 4-course Pixel cup profiling | **BLOCKED** — no device |
| Low / Medium / High quality presets exercised on device | **BLOCKED** — no device |

## Quality tiers (intended)

| Tier | Reductions | Preserved |
| --- | --- | --- |
| Low | Particle trails, shadows, secondary cloth/scarf motion, lighter post | Rear silhouette, face, gait identity, footwear shape |
| Medium | Balanced VFX | Full roster readability from chase camera |
| High | Full boost/landing dust + secondary motion | Full personality presentation |

## Headless / workstation notes

- Runners are stylized procedural bodies driven by `RunnerProfile` gait params — cheaper than unique skinned GLBs.
- Content validator PASS for Sole Surge Cup route data.
- Device cup FPS remains required before performance PASS.

## Next measurement checklist (when Pixel reconnects)

1. Install current SHA APK; confirm no compatibility / debuggable warnings.
2. Complete Verdant → Farm → Prism → Volcanic cup with touch controls.
3. Record avg/min FPS, spikes, memory, thermal, load times per course.
4. Repeat on Low / Medium / High.
5. Attach captures under `docs/product-quality/evidence/pixel-performance/`.
