# Pedestrian Pursuit — Requirements-to-Evidence Matrix (RTM)

**Product:** Pedestrian Pursuit  
**Lane / PR:** `#46` `lane-b/course-build-fix`  
**Tip (stamp at authoring; re-check `git rev-parse HEAD`):** recover against remote tip  
**Schema:** local `gunnchos.rtm.v1` aligned to expected gunnchOS3k Product Verification Standard (PVS)

## Shared PVS reference

| Field | Value |
| --- | --- |
| Shared PVS in `thursday-open-lab-hub` | **not present** at authoring (searched docs/product + verification paths) |
| Fallback | Local RTM schema below; statuses remain honest until shared PVS lands |
| Cursor Complete | **NOT claimed** |

## Global honesty (must stay false)

| Gate | Status |
| --- | --- |
| `HUMAN_FUN_APPROVAL` | false |
| `HUMAN_COURSE_APPROVAL` | false |
| `RC2_READY` | false |
| `V1_0_0_RELEASE_AUTHORIZED` | false |
| `track_art_candidate ≠ human-approved` | true (32 candidates; 0 commercial approvals) |
| Mac MoltenVK / Metal | **false** (separate; see MoltenVK row) |
| Physical 8-human PartyLink | **false** (packet prepared only) |

## Matrix

| ID | Requirement | Evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| PP-RTM-01 | 32 championship tracks raceable | `data/tracks/*.json` (32), `tests/ChampionshipCatalogTest.gd`, `artifacts/championship/CATALOG_RESULT.json` | **PASS (digital)** | No catalog rebuild this pass; stamp only |
| PP-RTM-02 | 8 cups authored (Sole→Wonder) | `data/cups/*.json`, ChampionshipCatalogTest cup start loop | **PASS (digital)** | |
| PP-RTM-03 | 50 Kinetic Sole vehicles playable | `data/vehicles/vehicle_registry.json` (`vehicle_count=50`, `playable_count=50`, `stub_count=0`) | **PASS (digital)** | Shared movement archetypes — not 50 physics engines |
| PP-RTM-04 | Career / cup save-resume | `tests/ChampionshipCupCareerTest.gd` | **PASS (digital)** | Full-cup save/reload covered; human career fun not claimed |
| PP-RTM-05 | Wardrobe / creator cosmetics | `data/wardrobe/wardrobe_catalog.json`, `CreatorWardrobeRaceFlowTest.gd`, `RacerVisual.apply_wardrobe_outfit` | **PASS (digital)** | Cosmetic only; footwear vehicle owns handling |
| PP-RTM-06 | Lap honesty (independent 2-client) | `artifacts/independent_two_process/INDEPENDENT_CLIENTS_RACE_RESULT.json`, `tests/test_lap_honesty_gate.py` | **PASS (digital / headless GL)** | Not Metal |
| PP-RTM-07 | PartyLink seat honesty 2–8 | `tests/PartyLinkCapacityTest.gd`, `artifacts/multiplayer/EIGHT_HUMAN_PARTY_PACKET.md` | **PASS (digital contract)** | Bots ≠ humans; BeatLink sibling stays 2 |
| PP-RTM-08 | Physical 8-human PartyLink session | `artifacts/multiplayer/EIGHT_HUMAN_PARTY_PACKET.md` | **FAIL / not executed** | Prepare-only; do not invent participants |
| PP-RTM-09 | Mac MoltenVK / Metal race | `artifacts/moltenvk/MOLTENVK_METAL_STATUS.md` | **FAIL (separate)** | Darwin Metal SIGSEGV history; Linux Gate1 ≠ Metal |
| PP-RTM-10 | Accessibility baseline | `scripts/core/AccessibilitySettings.gd`, MainMenu a11y toggles (reduce motion, larger UI, auto-accel, colorblind HUD), CameraRig reduce-motion FOV | **PASS (digital baseline)** | Not human a11y certification |
| PP-RTM-11 | Racing-camera quality cups 1–8 | `artifacts/quality_review/EIGHT_CUP_RACING_CAMERA_QUALITY.md`, CameraRig + CourseTrack accents | **PASS (procedural candidate)** | Cups 3–8 now per-track chase + accent fills; still ≠ commercial |
| PP-RTM-12 | Footwear / wardrobe chase-cam polish | `RacerVisual` trail profile + family stripe | **PASS (procedural)** | Candidate VFX only |
| PP-RTM-13 | Owner playable review package | `artifacts/quality_review/OWNER_PLAYABLE_REVIEW_PACKAGE.json` | **READY for owner** | Cursor Complete not claimed |
| PP-RTM-14 | Main-integration merge | `artifacts/main_integration/MAIN_INTEGRATION_MERGE_PLAN.md` | **PLAN ONLY** | Never merge/reset/force-push without owner |

## Cursor-Complete gaps (honest)

1. Human fun / course / commercial track-art approvals  
2. Physical 8-human PartyLink evidence  
3. Mac MoltenVK / Metal pass  
4. Shared hub PVS binding (when published)  
5. Human a11y certification beyond digital toggles  
6. Owner sign-off on eight-cup racing-camera package  

## Non-claims

- Not catalog rebuild  
- Not FF-merge to `main`  
- Not HUMAN_FUN / HUMAN_COURSE / RC2 / V1  
- Candidate lighting/camera ≠ human-approved final art  
