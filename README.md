# Pedestrian Pursuit

**Pedestrian Pursuit** is an action-packed arcade racing game where your feet are the vehicle, your shoes are your engine, and every race is a chaotic sprint full of drifting, tricks, stomps, boosts, shortcuts, and comeback moments.

## Prototype Subtitle

**Pedestrian Pursuit: Sole Rush Prototype**

## Core Idea

Instead of driving a kart, bike, board, or hovercraft, players race using exaggerated foot-powered movement. Racers sprint, slide, stomp, wall-kick, grind, trick, and boost across colorful obstacle-course tracks.

## MVP Goal

The first playable version focuses on one thing: making movement feel amazing.

The MVP includes:

- One playable racer (**Dash**)
- Three shoe presets (Starter Soles, Speed Sneakers, Grip Soles)
- One test track (**Sneaker City Sprintway**)
- 3-lap race loop
- Sprinting, steering, jumping, sliding/stomping
- Foot drifting with boost on release
- Boost meter and pickups
- Item boxes with three items (Turbo Toes, Lace Trap, Sole Shield)
- Basic AI racer
- Race HUD and results screen

## Setup

1. Install [Godot 4.x](https://godotengine.org/download) (4.2+ recommended).
2. Clone this repository.
3. Open Godot and import the project folder (`pedestrian-pursuit`).
4. Press **F5** or click **Run Project** to launch.

The main scene is `scenes/main/MainMenu.tscn`. From the main menu, choose **Start Race** to enter a 3-lap race on Sneaker City Sprintway.

## Controls

| Action | Keyboard |
|---|---|
| Accelerate | W / Up |
| Steer | A/D or Left/Right |
| Brake | S / Down |
| Jump | Space |
| Drift | Shift |
| Slide/Stomp | Ctrl |
| Use Item | E |
| Boost | Q |
| Special | R |
| Pause | Esc |

## Development Status

Current phase: **MVP prototype** — Milestones 1–8 implemented.

### Implemented

- Repository scaffold and documentation
- Player movement (sprint, steer, jump, slide, drift, boost, stomp)
- Third-person camera
- Sneaker City Sprintway test track with terrain zones
- 3-lap race with checkpoints and countdown
- Drift charge and release boost
- Boost meter with pickups
- Three MVP items
- Race HUD (lap, position, boost, item, timer, speed)
- AI racer path following
- Results screen
- Debug overlay (F3)

### Known Issues

- Placeholder art only — capsule character and colored primitives
- No audio assets yet (hooks in place)
- AI uses simple path following without item usage
- Trick system grants boost on landing but no stumble penalty yet
- Wall-kick and rail grinding not implemented (future)
- Settings menu is a placeholder

## Project Structure

```
pedestrian-pursuit/
├── docs/           # Design and architecture documents
├── scenes/         # Godot scenes
├── scripts/        # GDScript source
├── data/           # JSON data for racers, shoes, items, tracks
├── assets/         # Art, audio, materials (placeholder)
└── tests/          # Unit and integration tests (future)
```

See [docs/TECHNICAL_ARCHITECTURE.md](docs/TECHNICAL_ARCHITECTURE.md) for details.

## Engine

Godot 4.x (GDScript)

## Design Rule

Pedestrian Pursuit is inspired by the joy, speed, and chaos of beloved arcade racers, but all characters, mechanics, tracks, items, code, and assets must be original.

## License

MIT License — see [LICENSE](LICENSE).
