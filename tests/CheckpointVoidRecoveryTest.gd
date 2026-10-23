extends SceneTree

## Headless: void recovery returns the last accepted checkpoint transform.
## With no accepted gate, it returns the start-line fallback.
## It never returns a nearest-path point. No course geometry is loaded.

const _VoidRecovery = preload("res://scripts/player/VoidRecovery.gd")
const _START := Transform3D(Basis.IDENTITY, Vector3(4, 1.2, 4))
const _CHECKPOINT := Transform3D(Basis.IDENTITY, Vector3(25, 2, -15))
const _NEAREST_PATH := Transform3D(Basis.IDENTITY, Vector3(0, 1.05, 70))


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var before_gate := _VoidRecovery.choose(false, _CHECKPOINT, _START)
	if before_gate.origin.distance_to(_START.origin) > 0.01:
		failures.append("no-checkpoint respawn was %s, wanted start line" % str(before_gate.origin))
	if before_gate.origin.distance_to(_NEAREST_PATH.origin) < 1.0:
		failures.append("no-checkpoint respawn used the nearest path point")
	var after_gate := _VoidRecovery.choose(true, _CHECKPOINT, _START)
	if after_gate.origin.distance_to(_CHECKPOINT.origin) > 0.01:
		failures.append("accepted checkpoint was not restored, got %s" % str(after_gate.origin))
	if after_gate.origin.distance_to(_NEAREST_PATH.origin) < 1.0:
		failures.append("checkpoint respawn used the nearest path point")
	_expect_call_sites_do_not_snap(failures)
	if failures.is_empty():
		print("Checkpoint void recovery PASS — last gate, else start line")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect_call_sites_do_not_snap(failures: PackedStringArray) -> void:
	var player := FileAccess.get_file_as_string("res://scripts/player/PlayerController.gd")
	var scene := FileAccess.get_file_as_string("res://scripts/race/RaceScene.gd")
	var recover := _function_body(player, "func _recover_from_fall")
	var physics := _function_body(scene, "func _physics_process")
	var rescue := _function_body(scene, "func _rescue_fallen_onto_path")
	if recover.is_empty() or physics.is_empty() or rescue.is_empty():
		failures.append("could not read void-recovery functions")
		return
	if recover.find("snap_to_path") >= 0 or recover.find("snap_body_to_nearest_path") >= 0:
		failures.append("_recover_from_fall still snaps to the nearest path")
	if physics.find("snap_body_to_nearest_path") >= 0 or rescue.find("snap_to_path") >= 0:
		failures.append("RaceScene void recovery still snaps to the nearest path")
	if recover.find("_VoidRecovery.choose") < 0:
		failures.append("_recover_from_fall does not use the checkpoint/start choice")


func _function_body(source: String, header: String) -> String:
	var start := source.find(header)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + header.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)
