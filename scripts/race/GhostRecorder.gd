extends Node

## Records player transforms during Time Trial for ghost replay.

const GHOST_PATH := "user://time_trial_ghost_%s.json"

var recording: bool = false
var _samples: Array = []
var _elapsed: float = 0.0
var _track_id: String = ""
var _interval: float = 0.05
var _accum: float = 0.0


func clear_saved(track_id: String) -> bool:
	## Removes persisted ghost for a track (test + rematch hygiene).
	var path := GHOST_PATH % track_id
	if not FileAccess.file_exists(path):
		return true
	var abs_path := ProjectSettings.globalize_path(path)
	var err := DirAccess.remove_absolute(abs_path)
	return err == OK


func begin(track_id: String) -> void:
	_track_id = track_id
	_samples.clear()
	_elapsed = 0.0
	_accum = 0.0
	recording = true


func tick(delta: float, body: Node3D) -> void:
	if not recording or body == null:
		return
	_elapsed += delta
	_accum += delta
	if _accum < _interval:
		return
	_accum = 0.0
	var xf := body.global_transform
	_samples.append({
		"t": snappedf(_elapsed, 0.001),
		"x": snappedf(xf.origin.x, 0.01),
		"y": snappedf(xf.origin.y, 0.01),
		"z": snappedf(xf.origin.z, 0.01),
		"bx": snappedf(-xf.basis.z.x, 0.001),
		"by": snappedf(-xf.basis.z.y, 0.001),
		"bz": snappedf(-xf.basis.z.z, 0.001),
	})


func finish_and_save(final_time: float) -> bool:
	recording = false
	if _track_id.is_empty() or _samples.is_empty():
		return false
	var best := _load_best_time(_track_id)
	if best > 0.0 and final_time > best:
		# Keep prior ghost if this run is slower.
		return false
	var payload := {
		"track_id": _track_id,
		"time": final_time,
		"samples": _samples,
	}
	var file := FileAccess.open(GHOST_PATH % _track_id, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	return true


func load_samples(track_id: String) -> Array:
	var path := GHOST_PATH % track_id
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var samples = parsed.get("samples", [])
	return samples if samples is Array else []


func _load_best_time(track_id: String) -> float:
	var path := GHOST_PATH % track_id
	if not FileAccess.file_exists(path):
		return -1.0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1.0
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1.0
	return float(parsed.get("time", -1.0))
