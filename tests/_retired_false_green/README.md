# Retired false-green Godot `--script` smokes

`AlphaProductStateTest.gd` and `DigitalRcProductStateTest.gd` previously printed PASS
while Godot reported `SCRIPT ERROR` / `Compilation failed` because `--script` does not
load project autoloads.

They are superseded by `scripts/rc/ProductionGateHarness.gd` (`-- --production-gate`).

The files remain under `tests/` as hard-fail shims so accidental CI invocation cannot
false-green. Full historical bodies are preserved in this directory.
