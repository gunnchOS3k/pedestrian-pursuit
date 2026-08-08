# Pedestrian Pursuit — Continuation VI (Digital RC)

**Branch:** `cursor/full-product-continuation-vi-digital-rc`  
**Base:** `origin/main` @ `ce0687d` (#11)  
**Date:** 2026-08-08  
**Honesty note:** Competitive AI 768 matrix retained. Final **procedural/original** launch art+audio lands digital RC. Physical device FPS stays a **separate** pending token — it does **not** keep digital RC partial.

## Tokens

| Token | Earned? | Evidence |
| --- | --- | --- |
| `PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED` | **YES** | retained from #11 — 768/768, cheats=0 |
| `PEDESTRIAN_BETA_CONTENT_COMPLETE_DIGITAL` | **YES** | retained |
| `PEDESTRIAN_DIGITAL_RC_READY` | **YES** | launch art/audio + packaging + Local MP + AI + offline + crash/input profiles |
| `PEDESTRIAN_PHYSICAL_PERFORMANCE_PENDING` | **YES** (pending token) | device FPS cert still required for store physical RC — tracked separately |
| Visual / store physical RC | **NO** | awaits human device FPS certification |

## What shipped (Continuation VI)

1. **Launch art pack** — racers, 8 tracks, footwear, items, HUD/menu/cup/results, VFX sheets (`tools/art/generate_launch_assets.py`)
2. **Launch audio pack** — music beds, ambience, footsteps, item/UI SFX (`tools/audio/generate_procedural_audio.py`) + `AudioDirector`
3. **No launch greybox tags** — all tracks `art_status=LAUNCH_PROCEDURAL_FINAL`
4. **Visual QA** — contact sheets under `gate1/evidence/visual_qa/` + `data/art/provenance.json`
5. **Packaging** — clean install / save migrate / update-rollback / offline / crash breadcrumbs / input profiles / Local MP / AI

## Verify

```bash
python3 tools/art/generate_launch_assets.py
python3 tools/audio/generate_procedural_audio.py
bash tools/rc_packaging_check.sh

GODOT_BIN="$HOME/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot" \
  ./tools/run_godot_headless.sh
```

## Gaps (honest)

1. Public online / ranked — architecture only (private/dev)
2. Human device FPS certification — `PEDESTRIAN_PHYSICAL_PERFORMANCE_PENDING`
3. Optional future human-painted hero meshes beyond procedural-final launch presentation
