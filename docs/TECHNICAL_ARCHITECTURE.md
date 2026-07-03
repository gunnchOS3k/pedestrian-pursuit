# Technical Architecture — Pedestrian Pursuit

## Engine

Godot 4.x with GDScript. Target platforms: PC, macOS, Linux.

## Autoloads

| Name | Script | Role |
|---|---|---|
| GameManager | `scripts/core/GameManager.gd` | Global state, race mode, settings |
| InputManager | `scripts/core/InputManager.gd` | Unified input actions |
| SceneLoader | `scripts/core/SceneLoader.gd` | Scene transitions |

## Scene Graph

```
MainMenu.tscn
  └── Start Race → RaceScene.tscn
        ├── SneakerCitySprintway (track)
        ├── PlayerRacer
        ├── AIRacer(s)
        ├── RaceManager
        ├── RaceHUD
        ├── PauseMenu
        └── ResultsScreen
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

- `TerrainZone` — base area modifier
- `SpeedLane`, `BouncePad` — specialized zones

## Data Layer

JSON files in `data/` loaded at runtime:

- `data/racers/dash.json`
- `data/shoes/*.json`
- `data/items/*.json`
- `data/tracks/sneaker_city_sprintway.json`

Resource classes (`RacerData`, `ShoeData`, `ItemData`) parse JSON into typed dictionaries.

## Input Actions

Defined in `project.godot` and queried via `InputManager`:

`move_left`, `move_right`, `accelerate`, `brake`, `jump`, `drift`, `slide`, `use_item`, `boost`, `special`, `pause`

## Extension Points

- Add racers/shoes/items via JSON without code changes
- Animation states in `RacerStateMachine` ready for skeletal mesh swap
- `TerrainZone` subclass for new surface types
- `BaseItem` subclass for new power-ups

## Testing

`tests/unit/` and `tests/integration/` reserved for GUT or custom test runners.

## Debug

Press **F3** in race to toggle `DebugOverlay` (speed, state, drift charge, boost).
