# Technical Architecture — Pedestrian Pursuit

## Engine

Godot 4.x with GDScript and the OpenGL compatibility renderer. Target platforms include Android, PC, macOS, and Linux. The repository is currently authored in the 4.3 project format; a supported stable engine upgrade is a public-release gate.

## Autoloads

| Name | Script | Role |
|---|---|---|
| GameManager | `scripts/core/GameManager.gd` | Global state, race mode, settings |
| InputManager | `scripts/core/InputManager.gd` | Unified input actions |
| SceneLoader | `scripts/core/SceneLoader.gd` | Scene transitions |

## Scene Graph

```
MainMenu.tscn
  └── Start Cup / Practice → RaceScene.tscn
        ├── CourseTrack (built from validated JSON)
        ├── PlayerRacer
        ├── AIRacer(s)
        ├── RaceManager
        ├── RaceHUD
        ├── PauseMenu
        ├── ResultsScreen
        └── MobileControls (Android only)
```

## Core Systems

### Player

- `PlayerController` — movement, steering, gravity, terrain modifiers
- `MovementStats` — exported tuning from racer + shoe data
- `DriftSystem` — charge while drifting, boost on release
- `BoostSystem` — meter fill/spend, temporary speed multiplier
- `StompSystem` — air stomp and ground pulse
- `TrickSystem` — airborne trick input, landing boost
- `RacerStateMachine` — grounded/air/slide/drift states
- `CameraRig` — third-person follow camera

### Race

- `RaceManager` — countdown, race state, finish detection
- `LapManager` — per-racer lap and checkpoint tracking
- `Checkpoint` — ordered checkpoint triggers
- `StartFinishLine` — lap increment at start/finish
- `PositionTracker` — sort racers by progress

### Items

- `ItemManager` — random item roll, held item state
- `BaseItem` — abstract item behavior
- Concrete: TurboToes, LaceTrap, SoleShield

### AI

- `AIRacerController` — wraps movement for AI
- `AIPathFollower` — follows Path3D on track

### Tracks

- `TrackCatalog` — safe JSON loading, schema validation, and cup catalog
- `CourseTrack` — collision surface, race path, checkpoints, features, and themed scenery
- `TerrainZone` — base area modifier
- `SpeedLane`, `BouncePad` — specialized zones

## Data Layer

JSON files in `data/` loaded at runtime:

- `data/racers/dash.json`
- `data/shoes/*.json`
- `data/items/*.json`
- `data/cups/sole_surge_cup.json`
- `data/tracks/{verdant_cascade_circuit,cloverwind_ranch,prism_apex,emberkeep_gauntlet}.json`

Resource classes (`RacerData`, `ShoeData`, `ItemData`) parse player/item JSON; `TrackCatalog` validates cup and course JSON before scene construction.

## Input Actions

Defined in `project.godot` and queried via `InputManager`:

`move_left`, `move_right`, `accelerate`, `brake`, `jump`, `drift`, `slide`, `use_item`, `boost`, `special`, `pause`

## Extension Points

- Add racers/shoes/items via JSON without code changes
- Animation states in `RacerStateMachine` ready for skeletal mesh swap
- `TerrainZone` subclass for new surface types
- `BaseItem` subclass for new power-ups

## Testing

- `tools/validate_content.py` validates schemas, references, indices, geometry bounds, and feature placement without engine dependencies.
- `tests/test_content.py` locks cup order and original shipped identity.
- `tests/TestRunner.gd` loads and constructs all four courses in a headless Godot run.

## Debug

Press **F3** in race to toggle `DebugOverlay` (speed, state, drift charge, boost).
