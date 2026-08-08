# Pedestrian Pursuit

**Pedestrian Pursuit** is an original arcade foot racer: sprint, drift, jump, stomp, trick, boost, and use shoe-themed items through obstacle-course tracks without a vehicle.

Version 0.2 adds the complete **Sole Surge Cup**, a four-course championship with round-to-round results and points:

| Round | Course | Identity | Signature play |
|---|---|---|---|
| 1 | Verdant Cascade Circuit | Misty garden waterways | Broad turns, shallow runoff, forgiving boosts |
| 2 | Cloverwind Ranch | Windy clover ranch | Timber landmarks, muddy switchback, jump line |
| 3 | Prism Apex | Luminous orbital ribbon | Narrow sectors, sparse rails, precision boosts |
| 4 | Emberkeep Gauntlet | Volcanic forge fortress | Basalt turns, ash zones, forge vents |

Every shipped course name, route, color system, set piece, and gameplay configuration is original. The project uses broad arcade-racing motifs only; it does not include third-party characters, brands, assets, course names, or copied layouts.

## Current gameplay

- Four-round cup and single-course practice selection
- Three-lap ordered-checkpoint race flow with countdown and results
- Player sprinting, steering, jumping, sliding/stomping, drifting, tricks, and boosts
- Turbo Toes, Lace Trap, and Sole Shield items
- Data-driven courses with collision, guard rails, terrain zones, bounce pads, item boxes, and boost pickups
- AI path following with per-course closed routes
- Fall recovery at the last accepted checkpoint
- Keyboard, controller, and multi-touch Android controls
- Mobile-friendly OpenGL compatibility renderer

The current 3D presentation uses **procedural-final launch assets** (original racers/tracks/footwear/items/UI/VFX + synthesized audio). Digital RC packaging is complete; human device FPS certification remains a separate pending token.

## Run locally

1. Install Godot 4.x. The project is currently authored in the Godot 4.3 format.
2. Import this repository's `project.godot`.
3. Press **F5** and choose **Start Four-Course Cup**.

Desktop controls:

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
| Trick | T |
| Pause | Esc |

Android builds display simultaneous multi-touch controls for these actions automatically.

## Validate

Run the dependency-free content tests:

```bash
python3 tools/validate_content.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
bash tools/rc_packaging_check.sh
```

With Godot 4.5 available, run the full headless suite (import, startup, courses, G2-C6, cup save, modes/items/AI/ghost/Local MP, Beta product state, AI eval subset):

```bash
GODOT_BIN="$HOME/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot" \
  ./tools/run_godot_headless.sh
```

Full competitive AI matrix (8 racers × 4 shoes × 8 tracks × 3 tiers):

```bash
GODOT_BIN="$HOME/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot" \
  PP_AI_EVAL_TIME_SCALE=20 PP_AI_EVAL_MAX_SEC=5 \
  "$GODOT_BIN" --headless --path . --script res://tests/CompetitiveAiEvalRunner.gd
```

Evidence summary: [docs/PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED.md](docs/PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED.md).  
Digital RC status: [docs/PEDESTRIAN_DIGITAL_RC_STATUS.md](docs/PEDESTRIAN_DIGITAL_RC_STATUS.md).

Local MP (couch): P1 WASD + gamepad 0; P2 arrow keys + gamepad 1; vertical split cameras; Esc/Start pauses; career XP not written for the session.
Or a single course smoke:

```bash
godot --headless --path . --script res://tests/TestRunner.gd
```

## Android device build

The checked-in `Android Device` export preset targets a signed debug APK for ARM64 devices. Configure Godot's Java 17 and Android SDK paths, connect and authorize the phone with USB debugging, then run:

```bash
tools/android/build_and_install.sh
```

Set `GODOT_BIN` and/or `ANDROID_SERIAL` when the editor is outside the normal application path or more than one device is attached. See [docs/ANDROID_BUILD.md](docs/ANDROID_BUILD.md) for setup, release signing, AAB guidance, and troubleshooting.

## Architecture

- `data/cups/` — cup order and scoring
- `data/tracks/` — versioned course definitions
- `scripts/data/TrackCatalog.gd` — safe loading and runtime validation
- `scripts/tracks/CourseTrack.gd` — reusable course construction
- `scripts/race/` — countdown, checkpoints, laps, positions, and race orchestration
- `scripts/player/` — movement and recovery systems
- `scripts/ui/` — menu, HUD, results, pause, and mobile controls
- `tests/` — dependency-free data tests and Godot construction smoke test

See [docs/TECHNICAL_ARCHITECTURE.md](docs/TECHNICAL_ARCHITECTURE.md) and [docs/COURSE_CONTENT.md](docs/COURSE_CONTENT.md).

## Release gates

Before a public production release: upgrade and certify on a currently supported Godot stable version, replace placeholder presentation with licensed production assets, profile all four courses on representative low/mid/high Android devices, add audio and accessibility settings, complete full race/cup device QA, and generate a privately stored release keystore for the Play Store AAB.

## License

MIT License — see [LICENSE](LICENSE).
