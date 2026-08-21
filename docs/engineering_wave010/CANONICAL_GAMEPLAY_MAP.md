# Wave010 Canonical Gameplay Map

Pinned start: `PEDESTRIAN_ACCEPTED_MAIN_START_SHA=3f8fdb5f0f2f6459e42cd38cf0e067084a7a0791`  
Field-kit gate: `#115 MERGED` → `FIELD_KIT_ACCEPTED_MAIN_SHA=07ec12ad281dbb093c51195c2acd46c616887126`

Doctrine: deepen accepted systems only. No Wave-specific PlayerController / ItemManager / RaceManager / AI forks.

## System inventory (accepted main)

| System | Path | Role |
|--------|------|------|
| PlayerController | `scripts/player/PlayerController.gd` | Feet/body vehicle grammar |
| RacerStateMachine | `scripts/player/RacerStateMachine.gd` | GROUNDED/DRIFT/SLIDE/AIR/STOMP |
| MovementStats | `scripts/player/MovementStats.gd` | Racer+shoe runtime stats |
| DriftSystem | `scripts/player/DriftSystem.gd` | Spark tiers → boost |
| BoostSystem | `scripts/player/BoostSystem.gd` | Meter spend / external boost |
| StompSystem | `scripts/player/StompSystem.gd` | Ground pulse / air stomp |
| TrickSystem | `scripts/player/TrickSystem.gd` | Airborne risk/reward |
| DraftingSystem | `scripts/player/DraftingSystem.gd` | Slipstream comeback tool |
| RailGrindSystem | `scripts/player/RailGrindSystem.gd` | Skill rail capture |
| SpecialAbilitySystem | `scripts/player/SpecialAbilitySystem.gd` | Per-racer active |
| ItemManager | `scripts/items/ItemManager.gd` | Hold/use/counterplay |
| RaceScene / RaceManager | `scripts/race/*` | Scene + countdown/laps |
| LapManager | `scripts/race/LapManager.gd` | Ordered checkpoints |
| CourseTrack | `scripts/tracks/CourseTrack.gd` | Data-built courses |
| TerrainZone / ShoeData | tracks + data | Surface affinity |
| AIRacerController / AIPathFollower | `scripts/ai/*` | Tiered route AI |
| RacerData / RunnerProfile | `scripts/data/*` | Distinct racers |
| TelemetryBus | `scripts/core/TelemetryBus.gd` | Observability |
| GhostRecorder / GhostPlayer | `scripts/race/*` | Time-trial mastery |
| MobileControls / InputManager | ui + core | Input integrity |
| CompetitiveAiEvalRunner | `tests/CompetitiveAiEvalRunner.gd` | Seeded AI matrix |

## GAME-PP classification at Wave010 start

| Req | Title | Classification | Notes |
|-----|-------|----------------|-------|
| GAME-PP-001 | Sprinting | PRESENT_SHALLOW | Accel/coast present; cadence/momentum windows thin |
| GAME-PP-002 | Foot drifting | PRESENT_SHALLOW | Four spark tiers exist; min-speed/overcommit risk thin |
| GAME-PP-003 | Jumping | PRESENT_SHALLOW | Impulse + air control; coyote/buffer missing |
| GAME-PP-004 | Sliding | PRESENT_SHALLOW | State + speed mult; hazard/profile depth thin |
| GAME-PP-005 | Wall interaction | PRESENT_SHALLOW | Scrape + kick + cooldown; mastery feedback thin |
| GAME-PP-006 | Rail grinding | PRESENT_SHALLOW | Proximity attach; angle/exit/jump thin |
| GAME-PP-007 | Stomping | PRESENT_SHALLOW | Air/ground exist; recovery cost thin |
| GAME-PP-008 | Tricks | PRESENT_SHALLOW | Single trick; combo/fail penalty missing |
| GAME-PP-009 | Boost management | PRESENT_SHALLOW | Meter + sources; attribution/stacking thin |
| GAME-PP-010 | Items | PRESENT_SUBSTANTIAL | Counterplay present; position weighting fair-but-shallow |
| GAME-PP-011 | Shortcuts | MISSING_DEPTH | Data `shortcut_routes` authored; runtime gates not built |
| GAME-PP-012 | Terrain | PRESENT_SHALLOW | Zones + affinity; accel/drift/slide coupling thin |
| GAME-PP-013 | Distinct racers | PRESENT_SUBSTANTIAL | 8 racers + abilities; balance matrix missing |
| GAME-PP-014 | Fair comeback | MISSING_DEPTH | Drafting exists; no explicit fair policy / eval |
| GAME-PP-015 | Competitive mastery | PRESENT_SHALLOW | Ghost/AI/tutorial exist; mastery eval missing |

## Hard rules for this wave

- Do not use ProductionGateHarness / accept_force_laps / fake checkpoint stepping as gameplay proof.
- Competitive modes: `HIDDEN_RUBBER_BANDING=false`, `FORCED_FINISH_ORDER=false`.
- Assists remain explicit and disableable via GameManager.
