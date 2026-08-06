# Runtime smoke notes — Pedestrian Pursuit

- Primary automated evidence: Python headless core-loop harness (`gate1/tools/core_loop_runner.py`).
- Optional Godot smoke (when binary available): `Godot --headless --path . -s res://tests/CupFlowTest.gd`
- Godot binary was not required for Gate 1 automated evidence pass in this environment.
