extends SceneTree

## RETIRED false-green smoke — do not use as product evidence.
## Superseded by scripts/rc/ProductionGateHarness.gd (-- --production-gate).
## Historical body: tests/_retired_false_green/DigitalRcProductStateTest.gd


func _initialize() -> void:
	push_error("DigitalRcProductStateTest.gd RETIRED: false-green --script smoke superseded by ProductionGateHarness")
	print("FAIL DigitalRcProductStateTest.gd RETIRED_FALSE_GREEN — use -- --production-gate")
	quit(1)
